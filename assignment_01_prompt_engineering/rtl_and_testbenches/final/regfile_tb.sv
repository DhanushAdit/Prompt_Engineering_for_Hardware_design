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

  logic [31:0] exp_regs [0:31];

  integer checks;
  integer failures;
  integer done_flag;

  regfile dut (
    .clk(clk),
    .reset(reset),
    .we3(we3),
    .a1(a1),
    .a2(a2),
    .a3(a3),
    .wd3(wd3),
    .rd1(rd1),
    .rd2(rd2)
  );

  task automatic check32;
    input [31:0] actual;
    input [31:0] expected;
    input [255:0] tag;
    begin
      checks = checks + 1;
      if (actual !== expected) begin
        failures = failures + 1;
        $display("MISMATCH %0s actual=%08h expected=%08h clk=%0b reset=%0b we3=%0b a1=%0d a2=%0d a3=%0d wd3=%08h rd1=%08h rd2=%08h",
                 tag, actual, expected, clk, reset, we3, a1, a2, a3, wd3, rd1, rd2);
      end
    end
  endtask

  task automatic set_reads;
    input [4:0] ra1;
    input [4:0] ra2;
    begin
      a1 = ra1;
      a2 = ra2;
    end
  endtask

  task automatic check_reads;
    input [255:0] tag;
    input check_rd1_en;
    input [31:0] exp1;
    input check_rd2_en;
    input [31:0] exp2;
    begin
      #1;
      if (check_rd1_en) check32(rd1, exp1, {tag, " rd1"});
      if (check_rd2_en) check32(rd2, exp2, {tag, " rd2"});
    end
  endtask

  task automatic check_reads_from_model;
    input [255:0] tag;
    begin
      check_reads(tag, 1'b1, exp_regs[a1], 1'b1, exp_regs[a2]);
    end
  endtask

  task automatic model_negedge_update;
    integer k;
    begin
      if (reset) begin
        exp_regs[0] = 32'h00000000;
        for (k = 1; k < 32; k = k + 1) exp_regs[k] = 32'h00000000;
      end else begin
        exp_regs[0] = 32'h00000000;
        if (we3 && (a3 != 5'd0)) exp_regs[a3] = wd3;
      end
      exp_regs[0] = 32'h00000000;
    end
  endtask

  task automatic negedge_step;
    begin
      clk = 1'b1;
      #1;
      clk = 1'b0;
      model_negedge_update();
      #1;
    end
  endtask

  initial begin : main
    integer i;
    integer j;
    reg [4:0] idx;
    reg [4:0] idx2;
    reg [31:0] pat;

    checks = 0;
    failures = 0;
    done_flag = 0;

    clk = 1'b1;
    reset = 1'b0;
    we3 = 1'b0;
    a1 = 5'd0;
    a2 = 5'd0;
    a3 = 5'd0;
    wd3 = 32'h00000000;

    for (i = 0; i < 32; i = i + 1) exp_regs[i] = 32'h00000000;

    // Initial edge-based reset; only x0 is specified before first negedge.
    reset = 1'b1;
    we3   = 1'b1;
    a3    = 5'd7;
    wd3   = 32'hA5A5A5A5;
    set_reads(5'd0, 5'd7);
    check_reads("pre-first-reset-edge", 1'b1, 32'h00000000, 1'b0, 32'h00000000);
    negedge_step();
    set_reads(5'd0, 5'd7);
    check_reads_from_model("post-first-reset-edge");

    // No asynchronous reset between falling edges.
    we3 = 1'b1;
    a3  = 5'd9;
    wd3 = 32'h12345678;
    set_reads(5'd9, 5'd7);
    check_reads_from_model("reset-high-no-negedge-yet");
    reset = 1'b0;
    check_reads_from_model("deassert-reset-away-from-edge");

    // x0 hardwired zero; write to x0 ignored.
    we3 = 1'b1;
    a3  = 5'd0;
    wd3 = 32'hFFFFFFFF;
    set_reads(5'd0, 5'd1);
    check_reads_from_model("pre-x0-write");
    negedge_step();
    set_reads(5'd0, 5'd1);
    check_reads_from_model("post-x0-write-ignored");

    // Sample usage write and readback.
    we3 = 1'b1;
    a3  = 5'd5;
    wd3 = 32'hDEADBEEF;
    set_reads(5'd5, 5'd0);
    check_reads_from_model("pre-write-x5");
    negedge_step();
    set_reads(5'd5, 5'd0);
    check_reads_from_model("post-write-x5");

    // we3=0 blocks write.
    we3 = 1'b0;
    a3  = 5'd5;
    wd3 = 32'h0000002A;
    set_reads(5'd5, 5'd5);
    check_reads_from_model("pre-disabled-write");
    negedge_step();
    set_reads(5'd5, 5'd5);
    check_reads_from_model("post-disabled-write");

    // Overwrite and visibility after negedge.
    we3 = 1'b1;
    a3  = 5'd5;
    wd3 = 32'h0000002A;
    set_reads(5'd5, 5'd3);
    check_reads_from_model("pre-overwrite-x5");
    negedge_step();
    set_reads(5'd5, 5'd3);
    check_reads_from_model("post-overwrite-x5");

    // Independent combinational read ports.
    we3 = 1'b1;
    a3  = 5'd3;
    wd3 = 32'h80000000;
    negedge_step();
    set_reads(5'd5, 5'd3);
    check_reads_from_model("read-different");
    set_reads(5'd3, 5'd3);
    check_reads_from_model("read-same-both");
    set_reads(5'd0, 5'd0);
    check_reads_from_model("read-x0-both");

    // Boundary data and index values.
    we3 = 1'b1; a3 = 5'd1;  wd3 = 32'h00000000; negedge_step();
    we3 = 1'b1; a3 = 5'd2;  wd3 = 32'hFFFFFFFF; negedge_step();
    we3 = 1'b1; a3 = 5'd30; wd3 = 32'h7FFFFFFF; negedge_step();
    we3 = 1'b1; a3 = 5'd31; wd3 = 32'h80000000; negedge_step();
    set_reads(5'd1, 5'd2);   check_reads_from_model("boundary-zero-ones");
    set_reads(5'd30, 5'd31); check_reads_from_model("boundary-sign");
    set_reads(5'd31, 5'd0);  check_reads_from_model("boundary-maxidx-x0");

    // Reset priority over write on negedge.
    reset = 1'b1;
    we3   = 1'b1;
    a3    = 5'd31;
    wd3   = 32'h13579BDF;
    set_reads(5'd31, 5'd5);
    negedge_step();
    set_reads(5'd31, 5'd5);
    check_reads_from_model("reset-priority");
    reset = 1'b0;
    we3   = 1'b0;

    // Deterministic sweep of writes to all writable regs.
    for (i = 1; i < 32; i = i + 1) begin
      idx = i[4:0];
      pat = (32'h01010101 * i) ^ {27'h0, idx};
      a3  = idx;
      wd3 = pat;
      we3 = 1'b1;
      set_reads(idx, 5'd0);
      check_reads_from_model("sweep-pre");
      negedge_step();
      set_reads(idx, idx);
      check_reads_from_model("sweep-post");
    end

    // Address sweep across both read ports.
    we3 = 1'b0;
    for (i = 0; i < 32; i = i + 1) begin
      for (j = 0; j < 32; j = j + 9) begin
        idx  = i[4:0];
        idx2 = j[4:0];
        set_reads(idx, idx2);
        check_reads_from_model("read-sweep");
      end
    end

    // Inputs may change away from edges; only final pre-edge values sampled.
    we3 = 1'b1;
    a3  = 5'd10;
    wd3 = 32'hCAFEBABE;
    set_reads(5'd10, 5'd11);
    check_reads_from_model("pending-write-state-unchanged");
    a3  = 5'd11;
    wd3 = 32'h0BADF00D;
    set_reads(5'd10, 5'd11);
    check_reads_from_model("changed-write-inputs-before-edge");
    negedge_step();
    set_reads(5'd10, 5'd11);
    check_reads_from_model("final-preedge-write-sampled");

    // Same-cycle read addresses matching destination before and after edge.
    we3 = 1'b1;
    a3  = 5'd12;
    wd3 = 32'h11223344;
    set_reads(5'd12, 5'd12);
    check_reads_from_model("same-dst-read-before-edge");
    negedge_step();
    set_reads(5'd12, 5'd12);
    check_reads_from_model("same-dst-read-after-edge");

    // Final reset then verify all defined state is cleared.
    reset = 1'b1;
    we3   = 1'b1;
    a3    = 5'd13;
    wd3   = 32'h55667788;
    negedge_step();
    reset = 1'b0;
    we3   = 1'b0;
    for (i = 0; i < 32; i = i + 1) begin
      idx = i[4:0];
      set_reads(idx, 5'd0);
      check_reads_from_model("final-clear-sweep");
    end

    done_flag = 1;
    $display("SUMMARY checks=%0d failures=%0d", checks, failures);
    if ((checks > 0) && (failures == 0)) begin
      $display("PASS");
      $finish;
    end else begin
      $display("FAIL");
      $fatal(1, "verification failed");
    end
  end

  initial begin : watchdog
    #1000;
    if (!done_flag) begin
      $display("FAIL");
      $fatal(1, "timeout");
    end
  end

endmodule
