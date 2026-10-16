#!/usr/bin/env bash
python3 harness/run.py \
    --tests results/tests \
    --assertions results/assertions.sv \
    --core core/datapath_pipelined.sv
