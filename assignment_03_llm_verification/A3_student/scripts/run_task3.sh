#!/usr/bin/env bash
python3 agent/coverage_loop.py \
    --provider tamu \
    --out results \
    --core core \
    --max-calls 20 \
    --model protected.Claude-Opus-5 \
    --max-tokens 16384
