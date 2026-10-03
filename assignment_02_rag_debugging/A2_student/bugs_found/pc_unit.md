# `pc_unit`

**Buggy code:**

```systemverilog
PCPlus4 = PC + 32'd2;
```

RV32I instructions advance by four bytes, so the required expression is `PC + 32'd4`. Because the sequential PC update uses `PCPlus4`, every fall-through step advances by two bytes and the error accumulates.

**Evidence:** All 30 vectors failed; the first showed `PCPlus4=2` while the expected value was `4`.

**Repair run:** Iteration 0: `sim_fail`; iteration 1: `pass`. Repairs used: **1**.
