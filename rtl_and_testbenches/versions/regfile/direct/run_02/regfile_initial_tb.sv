`timescale 1ns/1ps

module regfile_tb;

  logic        clk;
  logic        reset;
  logic        we3;
  logic [4:0]  a1;
  logic [4:0]  a2;
  logic [4:0]  a3;
  logic [31:0] wd3;
  logic [31:0] rd1;
  logic [31:0] rd2;

  integer checks;
  integer failures;
  integer finished;

  logic [31:0] exp_regs [0:31];
  integer i;

  regfile dut (
    .clk  (clk),
    .reset(reset),
    .we3  (we3),
    .a1   (a1),
    .a2   (a2),
    .a3   (a3),
    .wd3  (wd3),
    .rd1  (rd1),
    .rd2  (rd2)
  );

  task automatic check_val32;
    input [255:0] tag;
    input [31:0] actual;
    input [31:0] expected;
    begin
      checks = checks + 1;
      if (actual !== expected) begin
        failures = failures + 1;
        $display("MISMATCH %0s actual=%h expected=%h time=%0t a1=%0d a2=%0d a3=%0d we3=%b reset=%b wd3=%h",
                 tag, actual, expected, $time, a1, a2, a3, we3, reset, wd3);
      end
    end
  endtask

  task automatic check_reads;
    input [255:0] tag;
    logic [31:0] exp1;
    logic [31:0] exp2;
    begin
      #1;
      exp1 = (a1 == 5'd0) ? 32'h00000000 : exp_regs[a1];
      exp2 = (a2 == 5'd0) ? 32'h00000000 : exp_regs[a2];
      check_val32({tag, " rd1"}, rd1, exp1);
      check_val32({tag, " rd2"}, rd2, exp2);
    end
  endtask

  task automatic drive_reads_and_check;
    input [4:0] ra1;
    input [4:0] ra2;
    input [255:0] tag;
    begin
      a1 = ra1;
      a2 = ra2;
      check_reads(tag);
    end
  endtask

  task automatic apply_negedge_and_update;
    input        n_reset;
    input        n_we3;
    input [4:0]  n_a3;
    input [31:0] n_wd3;
    input [255:0] tag;
    integer k;
    begin
      reset = n_reset;
      we3   = n_we3;
      a3    = n_a3;
      wd3   = n_wd3;

      #2;
      clk = 1'b1;
      #2;
      clk = 1'b0;
      #1;

      if (n_reset) begin
        for (k = 1; k < 32; k = k + 1)
          exp_regs[k] = 32'h00000000;
        exp_regs[0] = 32'h00000000;
      end else if (n_we3 && (n_a3 != 5'd0)) begin
        exp_regs[n_a3] = n_wd3;
        exp_regs[0] = 32'h00000000;
      end else begin
        exp_regs[0] = 32'h00000000;
      end

      check_reads(tag);
    end
  endtask

  initial begin
    checks = 0;
    failures = 0;
    finished = 0;

    clk = 1'b0;
    reset = 1'b0;
    we3 = 1'b0;
    a1 = 5'd0;
    a2 = 5'd0;
    a3 = 5'd0;
    wd3 = 32'h00000000;

    for (i = 0; i < 32; i = i + 1)
      exp_regs[i] = 32'h00000000;

    #1;

    // x0 combinational behavior and dual-read basics
    drive_reads_and_check(5'd0, 5'd0, "init both x0");
    drive_reads_and_check(5'd0, 5'd31, "init x0 and x31");
    drive_reads_and_check(5'd31, 5'd0, "init x31 and x0");

    // No asynchronous reset: assert reset away from edge, state must not change yet
    reset = 1'b1;
    we3   = 1'b0;
    a3    = 5'd0;
    wd3   = 32'h12345678;
    drive_reads_and_check(5'd0, 5'd1, "reset asserted between edges no async effect");
    reset = 1'b0;

    // Write sample cases and boundaries
    apply_negedge_and_update(1'b0, 1'b1, 5'd5,  32'hDEADBEEF, "write x5 deadbeef");
    drive_reads_and_check(5'd5, 5'd0, "read x5 and x0 after write");
    drive_reads_and_check(5'd5, 5'd5, "same register on both ports");
    apply_negedge_and_update(1'b0, 1'b1, 5'd0,  32'hFFFFFFFF, "attempt write x0 ignored");
    drive_reads_and_check(5'd0, 5'd5, "x0 stays zero after write attempt");
    apply_negedge_and_update(1'b0, 1'b0, 5'd5,  32'h0000002A, "we3 low no change");
    drive_reads_and_check(5'd5, 5'd0, "x5 unchanged when we3 low");

    // More directed writes: zero/extrema/sign boundaries/address boundaries
    apply_negedge_and_update(1'b0, 1'b1, 5'd1,  32'h00000000, "write x1 zero");
    apply_negedge_and_update(1'b0, 1'b1, 5'd2,  32'hFFFFFFFF, "write x2 all ones");
    apply_negedge_and_update(1'b0, 1'b1, 5'd3,  32'h80000000, "write x3 sign bit set");
    apply_negedge_and_update(1'b0, 1'b1, 5'd4,  32'h7FFFFFFF, "write x4 max positive");
    apply_negedge_and_update(1'b0, 1'b1, 5'd31, 32'hA5A5A5A5, "write x31 high addr");
    drive_reads_and_check(5'd1, 5'd2, "read x1 x2");
    drive_reads_and_check(5'd3, 5'd4, "read x3 x4");
    drive_reads_and_check(5'd31, 5'd5, "read x31 x5");

    // Combinational addressing over selected register pairs
    for (i = 0; i < 8; i = i + 1) begin
      logic [4:0] t1;
      logic [4:0] t2;
      t1 = i[4:0];
      t2 = (31 - i)[4:0];
      a1 = t1;
      a2 = t2;
      check_reads("selected address sweep");
    end

    // Overwrite same register, reads update after negedge
    apply_negedge_and_update(1'b0, 1'b1, 5'd5, 32'h12345678, "overwrite x5");
    drive_reads_and_check(5'd5, 5'd31, "read overwritten x5");

    // Read-before-edge should still show old state; no bypass/internal forwarding
    a1 = 5'd6;
    a2 = 5'd5;
    reset = 1'b0;
    we3 = 1'b1;
    a3 = 5'd6;
    wd3 = 32'hCAFEBABE;
    check_reads("before negedge old x6 visible");
    #2;
    clk = 1'b1;
    #2;
    clk = 1'b0;
    #1;
    exp_regs[6] = 32'hCAFEBABE;
    exp_regs[0] = 32'h00000000;
    check_reads("after negedge new x6 visible");

    // Reset priority over write
    apply_negedge_and_update(1'b1, 1'b1, 5'd7, 32'h11111111, "reset priority over write");
    drive_reads_and_check(5'd5, 5'd6, "post-reset x5 x6 cleared");
    drive_reads_and_check(5'd7, 5'd31, "post-reset x7 x31 cleared");
    drive_reads_and_check(5'd0, 5'd1, "post-reset x0 and x1");

    // Reset sampled only on negedge: deassert before edge prevents reset
    apply_negedge_and_update(1'b0, 1'b1, 5'd8, 32'h13579BDF, "write x8 after reset");
    reset = 1'b1;
    drive_reads_and_check(5'd8, 5'd0, "reset asserted between edges still old state");
    reset = 1'b0;
    apply_negedge_and_update(1'b0, 1'b0, 5'd0, 32'h00000000, "deassert reset before edge no clear");
    drive_reads_and_check(5'd8, 5'd0, "x8 preserved when reset low at negedge");

    // Systematic writes to all nonzero addresses
    for (i = 1; i < 32; i = i + 1) begin
      logic [31:0] pat;
      logic [4:0] ai;
      ai = i[4:0];
      pat = 32'h01010101 * i;
      apply_negedge_and_update(1'b0, 1'b1, ai, pat, "systematic full write");
    end

    // Systematic readback all addresses with paired ports
    for (i = 0; i < 32; i = i + 1) begin
      logic [4:0] ai;
      logic [4:0] bi;
      ai = i[4:0];
      bi = (31 - i)[4:0];
      a1 = ai;
      a2 = bi;
      check_reads("systematic readback");
    end

    // x0 robustness amidst surrounding writes
    apply_negedge_and_update(1'b0, 1'b1, 5'd0, 32'hAAAAAAAA, "x0 ignore after full write");
    drive_reads_and_check(5'd0, 5'd1, "x0 still zero after ignore");
    apply_negedge_and_update(1'b0, 1'b1, 5'd1, 32'h55555555, "rewrite x1");
    drive_reads_and_check(5'd1, 5'd0, "x1 rewritten x0 zero");

    finished = 1;

    $display("SUMMARY checks=%0d failures=%0d", checks, failures);
    if ((checks > 0) && (failures == 0)) begin
      $display("PASS");
      $finish;
    end else begin
      $display("FAIL");
      $fatal(1, "verification failed");
    end
  end

  initial begin
    #1000;
    if (!finished) begin
      $display("FAIL");
      $fatal(1, "timeout");
    end
  end

endmodule
