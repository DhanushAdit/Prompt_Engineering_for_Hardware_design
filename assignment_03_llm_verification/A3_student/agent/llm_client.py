"""LLM provider adapter with strict call-budget accounting and redacted logs."""

from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Dict, Optional


DEFAULT_TAMU_ENDPOINT = "https://chat-api.tamu.ai"
DEFAULT_MODEL = "protected.Claude-Opus-5"
DEFAULT_MAX_TOKENS = 16384
DEFAULT_TEMPERATURE = 0.0


def load_dotenv(package_root: Path) -> None:
    """Load simple KEY=VALUE entries without printing or overwriting credentials."""
    env_file = package_root / ".env"
    if not env_file.is_file():
        return
    placeholders = {"", "your_key", "your_tamu_key_here", "changeme", "sk-..."}
    for raw in env_file.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and value not in placeholders and key not in os.environ:
            os.environ[key] = value


class CallBudgetExceeded(RuntimeError):
    pass


class LLMClient:
    """OpenAI-compatible chat client used by TAMU AI Chat and optional OpenAI runs."""

    def __init__(
        self,
        provider: str,
        model: str,
        max_calls: int,
        log_dir: Path,
        max_tokens: int = DEFAULT_MAX_TOKENS,
        temperature: float = DEFAULT_TEMPERATURE,
        timeout: int = 180,
    ) -> None:
        if max_calls < 1:
            raise ValueError("--max-calls must be at least 1")
        if provider not in {"tamu", "openai"}:
            raise ValueError("provider must be 'tamu' or 'openai'")

        self.provider = provider
        self.model = model
        self.max_calls = max_calls
        self.max_tokens = max_tokens
        self.temperature = temperature
        self.timeout = timeout
        self.calls_used = 0
        self.total_usage: Dict[str, int] = {}
        self.log_dir = Path(log_dir)
        self.log_dir.mkdir(parents=True, exist_ok=True)

        if provider == "tamu":
            self.api_key = os.getenv("TAMUS_AI_CHAT_API_KEY", "")
            self.endpoint = os.getenv("TAMUS_AI_CHAT_API_ENDPOINT", DEFAULT_TAMU_ENDPOINT).rstrip("/")
            self.url = self.endpoint + "/openai/chat/completions"
        else:
            self.api_key = os.getenv("OPENAI_API_KEY", "")
            self.url = "https://api.openai.com/v1/chat/completions"

        if not self.api_key:
            variable = "TAMUS_AI_CHAT_API_KEY" if provider == "tamu" else "OPENAI_API_KEY"
            raise RuntimeError(f"{variable} is not configured")

    @property
    def calls_remaining(self) -> int:
        return self.max_calls - self.calls_used

    def _api_model(self) -> str:
        if self.provider == "tamu" and not self.model.startswith("protected."):
            return "protected." + self.model
        return self.model

    def _write_log(self, call_number: int, record: Dict[str, Any]) -> None:
        path = self.log_dir / f"call_{call_number:03d}.json"
        path.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    def generate(self, system_prompt: str, user_prompt: str, purpose: str) -> Dict[str, Any]:
        """Make one request. Failed requests still consume and log one call."""
        if self.calls_used >= self.max_calls:
            raise CallBudgetExceeded(
                f"LLM call budget exhausted ({self.calls_used}/{self.max_calls})"
            )

        self.calls_used += 1
        call_number = self.calls_used
        payload: Dict[str, Any] = {
            "model": self._api_model(),
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "max_tokens": self.max_tokens,
            "temperature": self.temperature,
            "stream": False,
        }
        started = time.time()
        record: Dict[str, Any] = {
            "call": call_number,
            "purpose": purpose,
            "provider": self.provider,
            "requested_model": self.model,
            "settings": {
                "max_tokens": self.max_tokens,
                "temperature": self.temperature,
                "timeout_seconds": self.timeout,
            },
            "system_prompt": system_prompt,
            "user_prompt": user_prompt,
        }

        request = urllib.request.Request(
            self.url,
            data=json.dumps(payload).encode("utf-8"),
            method="POST",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
                "Accept": "application/json",
                "User-Agent": "ecen689-a3-verification-agent/1.0",
            },
        )

        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                raw_text = response.read().decode("utf-8")
            parsed = json.loads(raw_text)
            choice = parsed["choices"][0]
            message = choice["message"]
            content_value = message.get("content", "")
            if isinstance(content_value, str):
                content = content_value
            elif isinstance(content_value, list):
                blocks = []
                for block in content_value:
                    if isinstance(block, str):
                        blocks.append(block)
                    elif isinstance(block, dict):
                        text = block.get("text") or block.get("content")
                        if isinstance(text, str):
                            blocks.append(text)
                content = "".join(blocks)
            else:
                content = ""
            if not content.strip():
                record["provider_response"] = parsed
                raise ValueError("provider returned empty message content")
            result = {
                "content": content,
                "model": parsed.get("model", self.model),
                "usage": parsed.get("usage", {}),
                "finish_reason": choice.get("finish_reason"),
            }
            if isinstance(result["usage"], dict):
                for key, value in result["usage"].items():
                    if isinstance(value, int):
                        self.total_usage[key] = self.total_usage.get(key, 0) + value
            record.update(result)
            record["elapsed_seconds"] = round(time.time() - started, 3)
            record["status"] = "ok"
            self._write_log(call_number, record)
            return result
        except urllib.error.HTTPError as error:
            body = error.read().decode("utf-8", "replace")
            message = f"HTTP {error.code}: {body[:2000]}"
        except urllib.error.URLError as error:
            message = f"request failed: {error.reason}"
        except (json.JSONDecodeError, KeyError, IndexError, TypeError, ValueError) as error:
            message = f"invalid provider response: {error}"
        except Exception as error:  # timeout/socket failures vary by Python version
            message = f"provider call failed: {type(error).__name__}: {error}"

        record["elapsed_seconds"] = round(time.time() - started, 3)
        record["status"] = "error"
        record["error"] = message
        self._write_log(call_number, record)
        raise RuntimeError(message)
