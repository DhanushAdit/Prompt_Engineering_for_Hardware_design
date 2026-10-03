# `memory_access`

**Buggy code:**

```systemverilog
3'b000: LoadData = {24'b0, sel_byte};
```

LB is signed and must replicate the selected byte's sign bit: `{{24{sel_byte[7]}}, sel_byte}`. The buggy zero-extension turns negative byte values such as `8'hFF` into `32'h000000FF` instead of `32'hFFFFFFFF`.

**Evidence:** 6 of 44 vectors failed; values such as `000000FF` and `00000080` were produced where `FFFFFFFF` and `FFFFFF80` were expected.

**Repair run:** Iteration 0: `sim_fail` (return code 255); iteration 1: `pass`. Repairs used: **1**.
