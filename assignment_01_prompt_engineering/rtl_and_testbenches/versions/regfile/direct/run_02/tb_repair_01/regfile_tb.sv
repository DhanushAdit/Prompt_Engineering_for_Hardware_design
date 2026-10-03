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
  integer finished;
  integer i;
  integer j;

  logic [4:0] tmp5_a;
  logic [4:0] tmp5_b;
  logic [31:0] tmp32;

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
    reg [31:0] exp1;
    reg [31:0] exp2;
    begin
      #1;
      exp1 = (a1 == 5'd0) ? 32'h00000000 : exp_regs[a1];
      exp2 = (a2 == 5'd0) ? 32'h00000000 : exp_regs[a2];
      check32({tag, " rd1"}, rd1, exp1);
      check32({tag, " rd2"}, rd2, exp2);
    end
  endtask

  task automatic set_reads_and_check;
    input [4:0] ra1;
    input [4:0] ra2;
    input [255:0] tag;
    begin
      a1 = ra1;
      a2 = ra2;
      check_reads(tag);
    end
  endtask

  task automatic negedge_step;
    input        n_reset;
    input        n_we3;
    input [4:0]  n_a3;
    input [31:0] n_wd3;
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
        exp_regs[0] = 32'h00000000;
        for (j = 1; j < 32; j = j + 1) begin
          exp_regs[j] = 32'h00000000;
        end
      end else begin
        exp_regs[0] = 32'h00000000;
        if (n_we3 && (n_a3 != 5'd0)) begin
          exp_regs[n_a3] = n_wd3;
        end
      end
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

    for (i = 0; i < 32; i = i + 1) begin
      exp_regs[i] = 32'h00000000;
    end

    // Initialize through specified interface before checking state
    negedge_step(1'b1, 1'b0, 5'd0, 32'h00000000);

    // Reset behavior and combinational reads
    set_reads_and_check(5'd0, 5'd0,  "after init reset both zero");
    set_reads_and_check(5'd0, 5'd31, "after init reset x0 x31");
    set_reads_and_check(5'd1, 5'd2,  "after init reset x1 x2");
    set_reads_and_check(5'd31, 5'd0, "after init reset x31 x0");

    // No asynchronous reset between edges
    reset = 1'b1;
    we3   = 1'b0;
    a3    = 5'd0;
    wd3   = 32'h89ABCDEF;
    set_reads_and_check(5'd1, 5'd31, "reset high between edges no async clear");
    reset = 1'b0;

    // Directed writes and x0 hardwire behavior
    negedge_step(1'b0, 1'b1, 5'd5, 32'hDEADBEEF);
    set_reads_and_check(5'd5, 5'd0, "write x5 then read x5 x0");
    set_reads_and_check(5'd5, 5'd5, "same register both ports");
    negedge_step(1'b0, 1'b1, 5'd0, 32'hFFFFFFFF);
    set_reads_and_check(5'd0, 5'd5, "write x0 ignored");
    negedge_step(1'b0, 1'b0, 5'd5, 32'h0000002A);
    set_reads_and_check(5'd5, 5'd0, "we3 low no change");

    // Boundary data values and addresses
    negedge_step(1'b0, 1'b1, 5'd1,  32'h00000000);
    negedge_step(1'b0, 1'b1, 5'd2,  32'hFFFFFFFF);
    negedge_step(1'b0, 1'b1, 5'd3,  32'h80000000);
    negedge_step(1'b0, 1'b1, 5'd4,  32'h7FFFFFFF);
    negedge_step(1'b0, 1'b1, 5'd31, 32'hA5A5A5A5);
    set_reads_and_check(5'd1, 5'd2,  "read x1 x2");
    set_reads_and_check(5'd3, 5'd4,  "read x3 x4");
    set_reads_and_check(5'd31, 5'd5, "read x31 x5");

    // Read-before-negedge old value; after negedge new value
    a1 = 5'd6;
    a2 = 5'd5;
    reset = 1'b0;
    we3 = 1'b1;
    a3 = 5'd6;
    wd3 = 32'hCAFEBABE;
    check_reads("before negedge no bypass old x6");
    #2;
    clk = 1'b1;
    #2;
    clk = 1'b0;
    #1;
    exp_regs[0] = 32'h00000000;
    exp_regs[6] = 32'hCAFEBABE;
    check_reads("after negedge new x6 visible");

    // Reset priority over write
    negedge_step(1'b1, 1'b1, 5'd7, 32'h11111111);
    set_reads_and_check(5'd5, 5'd6,  "reset priority clears x5 x6");
    set_reads_and_check(5'd7, 5'd31, "reset priority clears x7 x31");
    set_reads_and_check(5'd0, 5'd1,  "reset keeps x0 zero and clears x1");

    // Reset sampled only on negedge; deassert before edge prevents clear
    negedge_step(1'b0, 1'b1, 5'd8, 32'h13579BDF);
    reset = 1'b1;
    we3   = 1'b0;
    set_reads_and_check(5'd8, 5'd0, "reset asserted between edges old state retained");
    reset = 1'b0;
    negedge_step(1'b0, 1'b0, 5'd0, 32'h00000000);
    set_reads_and_check(5'd8, 5'd0, "reset low at negedge no clear");

    // Selected combinational address sweep
    for (i = 0; i < 8; i = i + 1) begin
      tmp5_a = i[4:0];
      tmp5_b = (5'd31 - i[4:0]);
      a1 = tmp5_a;
      a2 = tmp5_b;
      check_reads("selected address sweep");
    end

    // Systematic writes to all nonzero registers
    for (i = 1; i < 32; i = i + 1) begin
      tmp5_a = i[4:0];
      tmp32 = 32'h01010101 * i;
      negedge_step(1'b0, 1'b1, tmp5_a, tmp32);
    end

    // Systematic readback all addresses and paired ports
    for (i = 0; i < 32; i = i + 1) begin
      tmp5_a = i[4:0];
      tmp5_b = (5'd31 - i[4:0]);
      a1 = tmp5_a;
      a2 = tmp5_b;
      check_reads("systematic readback");
    end

    // x0 robustness amidst surrounding writes
    negedge_step(1'b0, 1'b1, 5'd0, 32'hAAAAAAAA);
    set_reads_and_check(5'd0, 5'd1, "x0 still zero after ignored write");
    negedge_step(1'b0, 1'b1, 5'd1, 32'h55555555);
    set_reads_and_check(5'd1, 5'd0, "rewrite x1 and x0 zero");

    // Read all registers against model after final state
    for (i = 0; i < 32; i = i + 1) begin
      for (j = 0; j < 32; j = j + 7) begin
        tmp5_a = i[4:0];
        tmp5_b = j[4:0];
        a1 = tmp5_a;
        a2 = tmp5_b;
        check_reads("final cross-read subset");
      end
    end

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
