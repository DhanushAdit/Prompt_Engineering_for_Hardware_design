#!/usr/bin/env bash
python3 harness/run.py \
    --tests results/tests \
    --core core/datapath_pipelined.sv
