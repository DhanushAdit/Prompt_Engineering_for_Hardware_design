`timescale 1ns/1ps

module alu_tb;

  logic [31:0] A;
  logic [31:0] B;
  logic [2:0]  ALUSelect;
  logic        SubArith;
  logic [31:0] ALUResult;
  logic [31:0] Sum;

  integer checks;
  integer failures;
  integer done;

  alu dut (
    .A(A),
    .B(B),
    .ALUSelect(ALUSelect),
    .SubArith(SubArith),
    .ALUResult(ALUResult),
    .Sum(Sum)
  );

  function automatic [31:0] exp_sum(
    input logic [31:0] a,
    input logic [31:0] b,
    input logic        sub
  );
    begin
      if (sub) exp_sum = a - b;
      else     exp_sum = a + b;
    end
  endfunction

  function automatic logic signed [31:0] to_s32(
    input logic [31:0] x
  );
    begin
      to_s32 = $signed(x);
    end
  endfunction

  task automatic check_case(
    input logic [31:0] a,
    input logic [31:0] b,
    input logic [2:0]  sel,
    input logic        sub,
    input logic        check_res,
    input logic [31:0] exp_res,
    input logic [31:0] exp_sum_v,
    input [255:0]      name
  );
    begin
      A = a;
      B = b;
      ALUSelect = sel;
      SubArith = sub;
      #1;

      checks = checks + 1;
      if (Sum !== exp_sum_v) begin
        failures = failures + 1;
        $display("Mismatch %0s SUM A=%h B=%h ALUSelect=%03b SubArith=%0b actual=%h expected=%h",
                 name, a, b, sel, sub, Sum, exp_sum_v);
      end

      if (check_res) begin
        checks = checks + 1;
        if (ALUResult !== exp_res) begin
          failures = failures + 1;
          $display("Mismatch %0s ALUResult A=%h B=%h ALUSelect=%03b SubArith=%0b actual=%h expected=%h",
                   name, a, b, sel, sub, ALUResult, exp_res);
        end
      end
    end
  endtask

  initial begin : stimulus
    logic [31:0] vals [0:7];
    logic [31:0] shifts [0:7];
    logic [31:0] a_v;
    logic [31:0] b_v;
    logic [31:0] res_v;
    logic [31:0] sum_v;
    logic [4:0]  shamt;
    integer i;
    integer j;
    integer k;
    integer sidx;

    checks = 0;
    failures = 0;
    done = 0;

    A = 32'h00000000;
    B = 32'h00000000;
    ALUSelect = 3'b000;
    SubArith = 1'b0;
    #1;

    vals[0] = 32'h00000000;
    vals[1] = 32'h00000001;
    vals[2] = 32'hFFFFFFFF;
    vals[3] = 32'h7FFFFFFF;
    vals[4] = 32'h80000000;
    vals[5] = 32'h0000000A;
    vals[6] = 32'h00000003;
    vals[7] = 32'h12345678;

    shifts[0] = 32'h00000000;
    shifts[1] = 32'h00000001;
    shifts[2] = 32'h0000001F;
    shifts[3] = 32'h00000020;
    shifts[4] = 32'h0000003F;
    shifts[5] = 32'hFFFFFFE0;
    shifts[6] = 32'h00000005;
    shifts[7] = 32'h1234569F;

    // Sample usage and basic arithmetic/comparison examples
    check_case(32'h0000000A, 32'h00000003, 3'b000, 1'b0, 1'b1, 32'h0000000D, exp_sum(32'h0000000A, 32'h00000003, 1'b0), "sample_add");
    check_case(32'h0000000A, 32'h00000003, 3'b000, 1'b1, 1'b1, 32'h00000007, exp_sum(32'h0000000A, 32'h00000003, 1'b1), "sample_sub");
    check_case(32'hFFFFFFFF, 32'h00000001, 3'b010, 1'b1, 1'b1, 32'h00000001, exp_sum(32'hFFFFFFFF, 32'h00000001, 1'b1), "sample_slt");
    check_case(32'hFFFFFFFF, 32'h00000001, 3'b011, 1'b1, 1'b1, 32'h00000000, exp_sum(32'hFFFFFFFF, 32'h00000001, 1'b1), "sample_sltu");
    check_case(32'h80000000, 32'h00000001, 3'b101, 1'b1, 1'b1, 32'hC0000000, exp_sum(32'h80000000, 32'h00000001, 1'b1), "sample_sra");
    check_case(32'h0000000F, 32'h0000001F, 3'b001, 1'b0, 1'b1, 32'h80000000, exp_sum(32'h0000000F, 32'h0000001F, 1'b0), "sample_sll");

    // ADD/SUB modular wraparound and Sum independence
    for (i = 0; i < 8; i = i + 1) begin
      for (j = 0; j < 8; j = j + 1) begin
        a_v = vals[i];
        b_v = vals[j];

        res_v = a_v + b_v;
        sum_v = exp_sum(a_v, b_v, 1'b0);
        check_case(a_v, b_v, 3'b000, 1'b0, 1'b1, res_v, sum_v, "add");

        res_v = a_v - b_v;
        sum_v = exp_sum(a_v, b_v, 1'b1);
        check_case(a_v, b_v, 3'b000, 1'b1, 1'b1, res_v, sum_v, "sub");

        if (to_s32(a_v) < to_s32(b_v)) res_v = 32'h00000001;
        else                           res_v = 32'h00000000;
        sum_v = exp_sum(a_v, b_v, 1'b1);
        check_case(a_v, b_v, 3'b010, 1'b1, 1'b1, res_v, sum_v, "slt");

        if (a_v < b_v) res_v = 32'h00000001;
        else           res_v = 32'h00000000;
        sum_v = exp_sum(a_v, b_v, 1'b1);
        check_case(a_v, b_v, 3'b011, 1'b1, 1'b1, res_v, sum_v, "sltu");

        res_v = a_v ^ b_v;
        sum_v = exp_sum(a_v, b_v, 1'b0);
        check_case(a_v, b_v, 3'b100, 1'b0, 1'b1, res_v, sum_v, "xor");

        res_v = a_v | b_v;
        sum_v = exp_sum(a_v, b_v, 1'b0);
        check_case(a_v, b_v, 3'b110, 1'b0, 1'b1, res_v, sum_v, "or");

        res_v = a_v & b_v;
        sum_v = exp_sum(a_v, b_v, 1'b0);
        check_case(a_v, b_v, 3'b111, 1'b0, 1'b1, res_v, sum_v, "and");
      end
    end

    // Shift operations: exact use of B[4:0], including >31 values in B
    for (i = 0; i < 8; i = i + 1) begin
      a_v = vals[i];
      for (sidx = 0; sidx < 8; sidx = sidx + 1) begin
        b_v = shifts[sidx];
        shamt = b_v[4:0];

        res_v = a_v << shamt;
        sum_v = exp_sum(a_v, b_v, 1'b0);
        check_case(a_v, b_v, 3'b001, 1'b0, 1'b1, res_v, sum_v, "sll");

        res_v = a_v >> shamt;
        sum_v = exp_sum(a_v, b_v, 1'b0);
        check_case(a_v, b_v, 3'b101, 1'b0, 1'b1, res_v, sum_v, "srl");

        res_v = to_s32(a_v) >>> shamt;
        sum_v = exp_sum(a_v, b_v, 1'b1);
        check_case(a_v, b_v, 3'b101, 1'b1, 1'b1, res_v, sum_v, "sra");
      end
    end

    // Interacting controls: Sum always follows SubArith, ALUResult only when specified
    for (k = 0; k < 8; k = k + 1) begin
      a_v = vals[k];
      b_v = vals[7-k];
      sum_v = exp_sum(a_v, b_v, 1'b1);
      check_case(a_v, b_v, 3'b001, 1'b1, 1'b0, 32'h00000000, sum_v, "unspec_sel001_sub1");
      sum_v = exp_sum(a_v, b_v, 1'b0);
      check_case(a_v, b_v, 3'b010, 1'b0, 1'b0, 32'h00000000, sum_v, "unspec_sel010_sub0");
      sum_v = exp_sum(a_v, b_v, 1'b0);
      check_case(a_v, b_v, 3'b011, 1'b0, 1'b0, 32'h00000000, sum_v, "unspec_sel011_sub0");
      sum_v = exp_sum(a_v, b_v, 1'b1);
      check_case(a_v, b_v, 3'b100, 1'b1, 1'b0, 32'h00000000, sum_v, "unspec_sel100_sub1");
      sum_v = exp_sum(a_v, b_v, 1'b1);
      check_case(a_v, b_v, 3'b110, 1'b1, 1'b0, 32'h00000000, sum_v, "unspec_sel110_sub1");
      sum_v = exp_sum(a_v, b_v, 1'b1);
      check_case(a_v, b_v, 3'b111, 1'b1, 1'b0, 32'h00000000, sum_v, "unspec_sel111_sub1");
    end

    done = 1;
    $display("SUMMARY checks=%0d failures=%0d", checks, failures);
    if (checks > 0 && failures == 0) begin
      $display("PASS");
      $finish;
    end
    else begin
      $display("FAIL");
      $fatal(1, "verification failed");
    end
  end

  initial begin : watchdog
    #5000;
    if (!done) begin
      $display("FAIL");
      $fatal(1, "timeout");
    end
  end

endmodule
