#!/usr/bin/env bash
python3 agent/run_agent.py \
    --provider tamu \
    --model protected.Claude-Opus-5 \
    --max-tokens 16384 \
    --out results \
    --core core \
    --max-calls 20 \
    --stop-after task2
