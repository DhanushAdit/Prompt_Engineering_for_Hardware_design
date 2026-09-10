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
  logic        init_known [0:31];

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
    input [191:0] msg;
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

  task automatic check_reads;
    input [191:0] msg;
    input logic check_rd1;
    input logic check_rd2;
    logic [31:0] exp1;
    logic [31:0] exp2;
    begin
      #0.1;
      exp1 = exp_regs[a1];
      exp2 = exp_regs[a2];
      if (check_rd1) check32(rd1, exp1, {msg, " rd1"});
      if (check_rd2) check32(rd2, exp2, {msg, " rd2"});
    end
  endtask

  task automatic sample_negedge;
    integer k;
    begin
      if (reset) begin
        exp_regs[0] = 32'h00000000; init_known[0] = 1'b1;
        for (k = 1; k < 32; k = k + 1) begin
          exp_regs[k] = 32'h00000000;
          init_known[k] = 1'b1;
        end
      end else begin
        exp_regs[0] = 32'h00000000; init_known[0] = 1'b1;
        if (we3 && (a3 != 5'd0)) begin
          exp_regs[a3] = wd3;
          init_known[a3] = 1'b1;
        end
      end
      exp_regs[0] = 32'h00000000;
      init_known[0] = 1'b1;
    end
  endtask

  task automatic negedge_step;
    begin
      clk = 1'b1;
      #0.4;
      clk = 1'b0;
      sample_negedge();
      #0.2;
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
      init_known[i] = 1'b0;
    end
    exp_regs[0] = 32'h00000000;
    init_known[0] = 1'b1;

    // Initial combinational read: only x0 is specified before any reset/write.
    set_reads(5'd0, 5'd0);
    check_reads("initial x0 reads", 1'b1, 1'b1);
    set_reads(5'd0, 5'd7);
    check_reads("initial only x0 specified", 1'b1, 1'b0);

    // Reset sampled on negedge; no async reset between edges.
    reset = 1'b1;
    we3 = 1'b1;
    a3 = 5'd7;
    wd3 = 32'hA5A5A5A5;
    set_reads(5'd0, 5'd0);
    check_reads("reset high before edge no async effect on x0", 1'b1, 1'b1);
    negedge_step();
    set_reads(5'd0, 5'd7);
    check_reads("after first reset edge clears x7 and x0", 1'b1, 1'b1);

    // Deassert reset away from edge.
    a3 = 5'd9;
    wd3 = 32'h12345678;
    we3 = 1'b1;
    set_reads(5'd9, 5'd7);
    check_reads("state stable after reset edge", 1'b1, 1'b1);
    reset = 1'b0;
    #0.1;
    check_reads("deassert reset away from edge", 1'b1, 1'b1);

    // x0 hardwired zero and write to x0 ignored.
    we3 = 1'b1;
    a3 = 5'd0;
    wd3 = 32'hFFFFFFFF;
    set_reads(5'd0, 5'd1);
    check_reads("before x0 write attempt", 1'b1, 1'b1);
    negedge_step();
    set_reads(5'd0, 5'd1);
    check_reads("after x0 write attempt ignored", 1'b1, 1'b1);

    // Basic sample write/read and disabled write.
    we3 = 1'b1;
    a3 = 5'd5;
    wd3 = 32'hDEADBEEF;
    set_reads(5'd5, 5'd0);
    check_reads("before write x5", 1'b1, 1'b1);
    negedge_step();
    set_reads(5'd5, 5'd0);
    check_reads("after write x5", 1'b1, 1'b1);

    we3 = 1'b0;
    a3 = 5'd5;
    wd3 = 32'h0000002A;
    set_reads(5'd5, 5'd5);
    check_reads("before disabled write", 1'b1, 1'b1);
    negedge_step();
    set_reads(5'd5, 5'd5);
    check_reads("after disabled write unchanged", 1'b1, 1'b1);

    // Overwrite and immediate visibility after negedge.
    we3 = 1'b1;
    a3 = 5'd5;
    wd3 = 32'h0000002A;
    set_reads(5'd5, 5'd3);
    check_reads("overwrite pending no early change", 1'b1, 1'b0);
    negedge_step();
    set_reads(5'd5, 5'd3);
    check_reads("overwrite visible after negedge", 1'b1, 1'b0);

    // Independent combinational read ports.
    we3 = 1'b1;
    a3 = 5'd3;
    wd3 = 32'h80000000;
    negedge_step();
    set_reads(5'd5, 5'd3);
    check_reads("different registers", 1'b1, 1'b1);
    set_reads(5'd3, 5'd3);
    check_reads("same register both ports", 1'b1, 1'b1);
    set_reads(5'd0, 5'd0);
    check_reads("x0 both ports", 1'b1, 1'b1);

    // Boundary values and register index extrema.
    we3 = 1'b1; a3 = 5'd1;  wd3 = 32'h00000000; negedge_step();
    we3 = 1'b1; a3 = 5'd2;  wd3 = 32'hFFFFFFFF; negedge_step();
    we3 = 1'b1; a3 = 5'd30; wd3 = 32'h7FFFFFFF; negedge_step();
    we3 = 1'b1; a3 = 5'd31; wd3 = 32'h80000000; negedge_step();
    set_reads(5'd1, 5'd2);   check_reads("zero and all ones", 1'b1, 1'b1);
    set_reads(5'd30, 5'd31); check_reads("sign boundaries", 1'b1, 1'b1);
    set_reads(5'd31, 5'd0);  check_reads("highest index and x0", 1'b1, 1'b1);

    // Reset priority over write.
    reset = 1'b1;
    we3 = 1'b1;
    a3 = 5'd31;
    wd3 = 32'h13579BDF;
    set_reads(5'd31, 5'd5);
    check_reads("before priority edge", 1'b1, 1'b1);
    negedge_step();
    set_reads(5'd31, 5'd5);
    check_reads("reset priority over write", 1'b1, 1'b1);
    reset = 1'b0;
    we3 = 1'b0;

    // Deterministic write sweep all writable registers.
    for (i = 1; i < 32; i = i + 1) begin
      idx = i[4:0];
      pat = (32'h01010101 * i) ^ {27'h0, idx};
      a3 = idx;
      we3 = 1'b1;
      wd3 = pat;
      set_reads(idx, 5'd0);
      check_reads("pre-write sweep", 1'b1, 1'b1);
      negedge_step();
      set_reads(idx, idx);
      check_reads("post-write sweep", 1'b1, 1'b1);
    end

    // Read sweep over both ports.
    for (i = 0; i < 32; i = i + 1) begin
      for (j = 0; j < 32; j = j + 9) begin
        idx = i[4:0];
        idx2 = j[4:0];
        set_reads(idx, idx2);
        check_reads("read sweep", 1'b1, 1'b1);
      end
    end

    // Inputs may change away from edge; only final pre-edge values sampled.
    we3 = 1'b1;
    a3 = 5'd10;
    wd3 = 32'hCAFEBABE;
    set_reads(5'd10, 5'd11);
    check_reads("pending write no early state change", 1'b1, 1'b1);
    a3 = 5'd11;
    wd3 = 32'h0BADF00D;
    #0.1;
    set_reads(5'd10, 5'd11);
    check_reads("changed write inputs before edge", 1'b1, 1'b1);
    negedge_step();
    set_reads(5'd10, 5'd11);
    check_reads("only final pre-edge write sampled", 1'b1, 1'b1);

    // No write when we3=0.
    we3 = 1'b0;
    a3 = 5'd12;
    wd3 = 32'hAAAAAAAA;
    set_reads(5'd12, 5'd11);
    check_reads("disabled write pending", 1'b1, 1'b1);
    negedge_step();
    set_reads(5'd12, 5'd11);
    check_reads("disabled write ignored", 1'b1, 1'b1);

    // Final reset and cleared-state sweep.
    reset = 1'b1;
    we3 = 1'b0;
    a3 = 5'd0;
    wd3 = 32'h00000000;
    negedge_step();
    reset = 1'b0;
    for (i = 0; i < 32; i = i + 1) begin
      idx = i[4:0];
      set_reads(idx, 5'd0);
      check_reads("final clear sweep", 1'b1, 1'b1);
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
