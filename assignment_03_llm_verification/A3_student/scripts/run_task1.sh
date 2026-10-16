#!/usr/bin/env bash
python3 harness/run.py \
    --tests harness/task1_tests \
    --core core/datapath_pipelined.sv
