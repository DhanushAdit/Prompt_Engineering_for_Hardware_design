# `datapath`

**Buggy code:**

```systemverilog
assign ALUB = ALUSrcBD ? rd2 : ImmExtD;
```

The required selection is `ALUSrcBD ? ImmExtD : rd2`. With the buggy mux, immediate-based instructions such as `addi`, loads, and stores use the second register operand instead of the immediate, producing incorrect addresses or results.

**Evidence:** The seeded integration run timed out at `PC=00000140` on the first sample program, consistent with incorrect immediate-based ALU addresses and results.

**Repair run:** Iteration 0: `sim_fail`; iteration 1: `pass`. Repairs used: **1**.
