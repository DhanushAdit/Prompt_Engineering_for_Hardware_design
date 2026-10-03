# `branch_unit`

**Buggy code:**

```systemverilog
3'b000: BranchCond = (A != B);  // BEQ should use A == B
3'b001: BranchCond = (A == B);  // BNE should use A != B
```

The branch condition is then used by `PCSrc`, so equality branches redirect when they should fall through and inequality branches do the opposite.

**Evidence:** 14 of 40 vectors failed, covering equality and inequality branch cases.

**Repair run:** Iteration 0: `sim_fail`; iteration 1: `pass`. Repairs used: **1**.
