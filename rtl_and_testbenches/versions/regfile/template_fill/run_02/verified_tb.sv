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
  logic        exp_known [0:31];

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
    input logic [31:0] actual;
    input logic [31:0] expected;
    input [255:0] msg;
    begin
      checks = checks + 1;
      if (actual !== expected) begin
        failures = failures + 1;
        $display("MISMATCH %0s actual=%08h expected=%08h clk=%0b reset=%0b we3=%0b a1=%0d a2=%0d a3=%0d wd3=%08h rd1=%08h rd2=%08h",
                 msg, actual, expected, clk, reset, we3, a1, a2, a3, wd3, rd1, rd2);
      end
    end
  endtask

  task automatic set_reads;
    input logic [4:0] ra1;
    input logic [4:0] ra2;
    begin
      a1 = ra1;
      a2 = ra2;
    end
  endtask

  task automatic check_reads_masked;
    input [255:0] msg;
    logic [31:0] exp1;
    logic [31:0] exp2;
    logic k1;
    logic k2;
    begin
      #1;
      exp1 = 32'h00000000;
      exp2 = 32'h00000000;
      k1 = 1'b0;
      k2 = 1'b0;

      if (a1 == 5'd0) begin
        exp1 = 32'h00000000;
        k1 = 1'b1;
      end else if (exp_known[a1]) begin
        exp1 = exp_regs[a1];
        k1 = 1'b1;
      end

      if (a2 == 5'd0) begin
        exp2 = 32'h00000000;
        k2 = 1'b1;
      end else if (exp_known[a2]) begin
        exp2 = exp_regs[a2];
        k2 = 1'b1;
      end

      if (k1) check32(rd1, exp1, {msg, " rd1"});
      if (k2) check32(rd2, exp2, {msg, " rd2"});
    end
  endtask

  task automatic model_negedge;
    integer k;
    begin
      if (reset) begin
        exp_regs[0] = 32'h00000000;
        exp_known[0] = 1'b1;
        for (k = 1; k < 32; k = k + 1) begin
          exp_regs[k] = 32'h00000000;
          exp_known[k] = 1'b1;
        end
      end else begin
        exp_regs[0] = 32'h00000000;
        exp_known[0] = 1'b1;
        if (we3 && (a3 != 5'd0)) begin
          exp_regs[a3] = wd3;
          exp_known[a3] = 1'b1;
        end
      end
      exp_regs[0] = 32'h00000000;
      exp_known[0] = 1'b1;
    end
  endtask

  task automatic negedge_step;
    begin
      clk = 1'b1;
      #1;
      clk = 1'b0;
      model_negedge();
      #1;
    end
  endtask

  initial begin : main
    integer i;
    integer j;
    logic [4:0] idx;
    logic [4:0] idx2;
    logic [31:0] pat;

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

    for (i = 0; i < 32; i = i + 1) begin
      exp_regs[i] = 32'h00000000;
      exp_known[i] = 1'b0;
    end
    exp_regs[0] = 32'h00000000;
    exp_known[0] = 1'b1;

    // Initial checks only where specified before first sampled edge
    set_reads(5'd0, 5'd7);
    check_reads_masked("initial only x0 specified");

    // Reset sampled on negedge; no async reset between edges
    reset = 1'b1;
    we3 = 1'b1;
    a3 = 5'd7;
    wd3 = 32'hA5A5A5A5;
    set_reads(5'd0, 5'd7);
    check_reads_masked("reset high before edge no async effect");
    negedge_step();
    set_reads(5'd0, 5'd7);
    check_reads_masked("after first reset edge clears x1..x31");

    // Deassert reset away from edge, state remains reset until next negedge action
    a3 = 5'd9;
    wd3 = 32'h12345678;
    we3 = 1'b1;
    set_reads(5'd9, 5'd7);
    check_reads_masked("still zero after reset edge");
    reset = 1'b0;
    #1;
    check_reads_masked("deassert reset away from edge");

    // x0 hardwired zero, write to x0 ignored
    we3 = 1'b1;
    a3 = 5'd0;
    wd3 = 32'hFFFFFFFF;
    set_reads(5'd0, 5'd1);
    check_reads_masked("before x0 write attempt");
    negedge_step();
    set_reads(5'd0, 5'd1);
    check_reads_masked("after x0 write attempt ignored");

    // Sample usage: write/read, disabled write
    we3 = 1'b1;
    a3 = 5'd5;
    wd3 = 32'hDEADBEEF;
    set_reads(5'd5, 5'd0);
    check_reads_masked("before write x5");
    negedge_step();
    set_reads(5'd5, 5'd0);
    check_reads_masked("after write x5");

    we3 = 1'b0;
    a3 = 5'd5;
    wd3 = 32'h0000002A;
    set_reads(5'd5, 5'd5);
    check_reads_masked("before disabled write x5");
    negedge_step();
    set_reads(5'd5, 5'd5);
    check_reads_masked("after disabled write x5 unchanged");

    // Overwrite and immediate post-edge visibility
    we3 = 1'b1;
    a3 = 5'd5;
    wd3 = 32'h0000002A;
    set_reads(5'd5, 5'd3);
    check_reads_masked("before overwrite x5");
    negedge_step();
    set_reads(5'd5, 5'd3);
    check_reads_masked("after overwrite x5");

    // Two combinational read ports, same/different addresses
    we3 = 1'b1;
    a3 = 5'd3;
    wd3 = 32'h80000000;
    negedge_step();
    set_reads(5'd5, 5'd3);
    check_reads_masked("read different registers");
    set_reads(5'd3, 5'd3);
    check_reads_masked("read same register both ports");
    set_reads(5'd0, 5'd0);
    check_reads_masked("read x0 both ports");

    // Boundary register indices and data values
    we3 = 1'b1; a3 = 5'd1;  wd3 = 32'h00000000; negedge_step();
    we3 = 1'b1; a3 = 5'd2;  wd3 = 32'hFFFFFFFF; negedge_step();
    we3 = 1'b1; a3 = 5'd30; wd3 = 32'h7FFFFFFF; negedge_step();
    we3 = 1'b1; a3 = 5'd31; wd3 = 32'h80000000; negedge_step();

    set_reads(5'd1, 5'd2);   check_reads_masked("boundary values zero allones");
    set_reads(5'd30, 5'd31); check_reads_masked("sign boundaries");
    set_reads(5'd31, 5'd0);  check_reads_masked("highest index and x0");

    // Reset priority over write
    reset = 1'b1;
    we3 = 1'b1;
    a3 = 5'd31;
    wd3 = 32'h13579BDF;
    set_reads(5'd31, 5'd5);
    check_reads_masked("before reset-priority edge");
    negedge_step();
    set_reads(5'd31, 5'd5);
    check_reads_masked("reset priority over write");
    reset = 1'b0;
    we3 = 1'b0;

    // Deterministic write sweep across all writable registers
    for (i = 1; i < 32; i = i + 1) begin
      idx = i[4:0];
      pat = (32'h01010101 * i) ^ {27'h0, idx};
      a3 = idx;
      we3 = 1'b1;
      wd3 = pat;
      set_reads(idx, 5'd0);
      check_reads_masked("pre-write sweep");
      negedge_step();
      set_reads(idx, idx);
      check_reads_masked("post-write sweep");
    end

    // Full read sweep over representative pairs
    for (i = 0; i < 32; i = i + 1) begin
      idx = i[4:0];
      for (j = 0; j < 32; j = j + 9) begin
        idx2 = j[4:0];
        set_reads(idx, idx2);
        check_reads_masked("read-port sweep");
      end
    end

    // Inputs can change between edges; only final values at negedge matter
    we3 = 1'b1;
    a3 = 5'd10;
    wd3 = 32'hCAFEBABE;
    set_reads(5'd10, 5'd11);
    check_reads_masked("pending write x10 not yet taken");
    a3 = 5'd11;
    wd3 = 32'h0BADF00D;
    set_reads(5'd10, 5'd11);
    check_reads_masked("changed write inputs before edge");
    negedge_step();
    set_reads(5'd10, 5'd11);
    check_reads_masked("only final pre-edge write sampled");

    // Final reset and clear verification
    reset = 1'b1;
    we3 = 1'b0;
    a3 = 5'd0;
    wd3 = 32'h00000000;
    negedge_step();
    reset = 1'b0;
    for (i = 0; i < 32; i = i + 1) begin
      idx = i[4:0];
      set_reads(idx, 5'd0);
      check_reads_masked("final cleared-state sweep");
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
