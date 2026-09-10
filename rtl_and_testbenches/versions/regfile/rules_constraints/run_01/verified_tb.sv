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
    input [4:0] ra1;
    input [4:0] ra2;
    begin
      a1 = ra1;
      a2 = ra2;
    end
  endtask

  task automatic check_reads;
    input [255:0] msg;
    logic [31:0] exp1;
    logic [31:0] exp2;
    begin
      #1;
      exp1 = (a1 == 5'd0) ? 32'h00000000 : exp_regs[a1];
      exp2 = (a2 == 5'd0) ? 32'h00000000 : exp_regs[a2];
      check32(rd1, exp1, {msg, " rd1"});
      check32(rd2, exp2, {msg, " rd2"});
    end
  endtask

  task automatic check_read1_only;
    input [255:0] msg;
    logic [31:0] exp1;
    begin
      #1;
      exp1 = (a1 == 5'd0) ? 32'h00000000 : exp_regs[a1];
      check32(rd1, exp1, {msg, " rd1"});
    end
  endtask

  task automatic model_negedge;
    integer k;
    begin
      if (reset) begin
        exp_regs[0] = 32'h00000000;
        for (k = 1; k < 32; k = k + 1)
          exp_regs[k] = 32'h00000000;
      end else begin
        exp_regs[0] = 32'h00000000;
        if (we3 && (a3 != 5'd0))
          exp_regs[a3] = wd3;
      end
      exp_regs[0] = 32'h00000000;
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

    for (i = 0; i < 32; i = i + 1)
      exp_regs[i] = 32'h00000000;

    // Reset via specified interface; before first negedge only x0 is specified
    reset = 1'b1;
    we3 = 1'b1;
    a3 = 5'd7;
    wd3 = 32'hA5A5A5A5;
    set_reads(5'd0, 5'd7);
    check_read1_only("pre-reset-edge x0 specified");
    negedge_step();
    set_reads(5'd0, 5'd7);
    check_reads("post-reset clears x1..x31");

    // No asynchronous reset between edges
    a3 = 5'd9;
    wd3 = 32'h12345678;
    we3 = 1'b1;
    set_reads(5'd9, 5'd7);
    check_reads("reset high no async effect before negedge");
    reset = 1'b0;
    check_reads("deassert reset away from edge");

    // x0 hardwired zero; write to x0 ignored
    we3 = 1'b1;
    a3 = 5'd0;
    wd3 = 32'hFFFFFFFF;
    set_reads(5'd0, 5'd1);
    check_reads("before x0 write attempt");
    negedge_step();
    set_reads(5'd0, 5'd1);
    check_reads("after x0 write ignored");

    // Sample write/read usage and combinational visibility after negedge
    we3 = 1'b1;
    a3 = 5'd5;
    wd3 = 32'hDEADBEEF;
    set_reads(5'd5, 5'd0);
    check_reads("before write x5");
    negedge_step();
    set_reads(5'd5, 5'd0);
    check_reads("after write x5");

    // we3=0 no change
    we3 = 1'b0;
    a3 = 5'd5;
    wd3 = 32'h0000002A;
    set_reads(5'd5, 5'd5);
    check_reads("before disabled write");
    negedge_step();
    set_reads(5'd5, 5'd5);
    check_reads("after disabled write no change");

    // Overwrite existing register
    we3 = 1'b1;
    a3 = 5'd5;
    wd3 = 32'h0000002A;
    set_reads(5'd5, 5'd3);
    check_reads("before overwrite x5");
    negedge_step();
    set_reads(5'd5, 5'd3);
    check_reads("after overwrite x5");

    // Independent read ports, same and different addresses
    we3 = 1'b1;
    a3 = 5'd3;
    wd3 = 32'h80000000;
    negedge_step();
    set_reads(5'd5, 5'd3);
    check_reads("read different regs");
    set_reads(5'd3, 5'd3);
    check_reads("read same reg both ports");
    set_reads(5'd0, 5'd0);
    check_reads("read x0 both ports");

    // Boundary register indices and data values
    we3 = 1'b1; a3 = 5'd1;  wd3 = 32'h00000000; negedge_step();
    we3 = 1'b1; a3 = 5'd2;  wd3 = 32'hFFFFFFFF; negedge_step();
    we3 = 1'b1; a3 = 5'd30; wd3 = 32'h7FFFFFFF; negedge_step();
    we3 = 1'b1; a3 = 5'd31; wd3 = 32'h80000000; negedge_step();

    set_reads(5'd1, 5'd2);   check_reads("boundary zero/allones");
    set_reads(5'd30, 5'd31); check_reads("sign boundaries");
    set_reads(5'd31, 5'd0);  check_reads("highest index and x0");

    // Reset priority over write
    reset = 1'b1;
    we3 = 1'b1;
    a3 = 5'd31;
    wd3 = 32'h13579BDF;
    set_reads(5'd31, 5'd5);
    negedge_step();
    set_reads(5'd31, 5'd5);
    check_reads("reset priority over write");
    reset = 1'b0;
    we3 = 1'b0;

    // Deterministic sweep of writes to all writable registers
    for (i = 1; i < 32; i = i + 1) begin
      idx = i[4:0];
      pat = (32'h01010101 * i) ^ {27'h0, idx};
      a3 = idx;
      we3 = 1'b1;
      wd3 = pat;
      set_reads(idx, 5'd0);
      check_reads("pre-write sweep");
      negedge_step();
      set_reads(idx, idx);
      check_reads("post-write sweep");
    end

    // Systematic read-port coverage
    for (i = 0; i < 32; i = i + 1) begin
      idx = i[4:0];
      for (j = 0; j < 32; j = j + 9) begin
        idx2 = j[4:0];
        set_reads(idx, idx2);
        check_reads("read-port sweep");
      end
    end

    // Inputs may change away from edge; only final pre-negedge values sampled
    we3 = 1'b1;
    a3 = 5'd10;
    wd3 = 32'hCAFEBABE;
    set_reads(5'd10, 5'd11);
    check_reads("pending write state unchanged");
    a3 = 5'd11;
    wd3 = 32'h0BADF00D;
    set_reads(5'd10, 5'd11);
    check_reads("changed write inputs before edge");
    negedge_step();
    set_reads(5'd10, 5'd11);
    check_reads("only final pre-edge write sampled");

    // Final reset then verify all registers clear
    reset = 1'b1;
    we3 = 1'b0;
    a3 = 5'd0;
    wd3 = 32'h00000000;
    negedge_step();
    reset = 1'b0;
    for (i = 0; i < 32; i = i + 1) begin
      idx = i[4:0];
      set_reads(idx, 5'd0);
      check_reads("final cleared-state sweep");
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
