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

  function automatic [31:0] exp_sum_fn(
    input [31:0] a,
    input [31:0] b,
    input        sub
  );
    begin
      exp_sum_fn = sub ? (a - b) : (a + b);
    end
  endfunction

  function automatic [31:0] exp_res_fn(
    input [31:0] a,
    input [31:0] b,
    input [2:0]  sel,
    input        sub
  );
    reg signed [31:0] sa;
    reg signed [31:0] sb;
    reg [4:0] shamt;
    begin
      sa = a;
      sb = b;
      shamt = b[4:0];
      case ({sel,sub})
        4'b0000: exp_res_fn = a + b;
        4'b0001: exp_res_fn = a - b;
        4'b0010: exp_res_fn = a << shamt;
        4'b0101: exp_res_fn = (sa < sb) ? 32'h00000001 : 32'h00000000;
        4'b0111: exp_res_fn = (a < b)  ? 32'h00000001 : 32'h00000000;
        4'b1000: exp_res_fn = a ^ b;
        4'b1010: exp_res_fn = a >> shamt;
        4'b1011: exp_res_fn = $unsigned(sa >>> shamt);
        4'b1100: exp_res_fn = a | b;
        4'b1110: exp_res_fn = a & b;
        default: exp_res_fn = 32'h00000000;
      endcase
    end
  endfunction

  task automatic run_case(
    input [31:0] inA,
    input [31:0] inB,
    input [2:0]  inSel,
    input        inSub,
    input        res_specified
  );
    reg [31:0] exp_sum;
    reg [31:0] exp_res;
    begin
      exp_sum = exp_sum_fn(inA, inB, inSub);
      exp_res = exp_res_fn(inA, inB, inSel, inSub);

      A = inA;
      B = inB;
      ALUSelect = inSel;
      SubArith = inSub;
      #1;

      checks = checks + 1;
      if (Sum !== exp_sum) begin
        failures = failures + 1;
        $display("Mismatch Sum A=%h B=%h ALUSelect=%03b SubArith=%b actual=%h expected=%h",
                 A, B, ALUSelect, SubArith, Sum, exp_sum);
      end

      if (res_specified) begin
        checks = checks + 1;
        if (ALUResult !== exp_res) begin
          failures = failures + 1;
          $display("Mismatch ALUResult A=%h B=%h ALUSelect=%03b SubArith=%b actual=%h expected=%h",
                   A, B, ALUSelect, SubArith, ALUResult, exp_res);
        end
      end
    end
  endtask

  task automatic do_tests;
    reg [31:0] vals [0:9];
    reg [31:0] shv  [0:7];
    integer i;
    integer j;
    integer s;
    integer sub;
    begin
      // Boundary/example values
      vals[0] = 32'h00000000;
      vals[1] = 32'h00000001;
      vals[2] = 32'hFFFFFFFF;
      vals[3] = 32'h7FFFFFFF;
      vals[4] = 32'h80000000;
      vals[5] = 32'h0000000A;
      vals[6] = 32'h00000003;
      vals[7] = 32'h55555555;
      vals[8] = 32'hAAAAAAAA;
      vals[9] = 32'h12345678;

      shv[0] = 32'h00000000;
      shv[1] = 32'h00000001;
      shv[2] = 32'h0000001F;
      shv[3] = 32'h00000020;
      shv[4] = 32'h0000003F;
      shv[5] = 32'h12345660;
      shv[6] = 32'h12345661;
      shv[7] = 32'h1234567F;

      // Sample usage
      run_case(32'h0000000A, 32'h00000003, 3'b000, 1'b0, 1'b1);
      run_case(32'h0000000A, 32'h00000003, 3'b000, 1'b1, 1'b1);
      run_case(32'hFFFFFFFF, 32'h00000001, 3'b010, 1'b1, 1'b1);
      run_case(32'hFFFFFFFF, 32'h00000001, 3'b011, 1'b1, 1'b1);
      run_case(32'h80000000, 32'h00000001, 3'b101, 1'b1, 1'b1);
      run_case(32'h0000000F, 32'h0000001F, 3'b001, 1'b0, 1'b1);

      // Arithmetic/logical/compare operations and Sum independence
      for (i = 0; i < 10; i = i + 1) begin
        for (j = 0; j < 10; j = j + 1) begin
          run_case(vals[i], vals[j], 3'b000, 1'b0, 1'b1);
          run_case(vals[i], vals[j], 3'b000, 1'b1, 1'b1);
          run_case(vals[i], vals[j], 3'b100, 1'b0, 1'b1);
          run_case(vals[i], vals[j], 3'b100, 1'b1, 1'b0);
          run_case(vals[i], vals[j], 3'b110, 1'b0, 1'b1);
          run_case(vals[i], vals[j], 3'b110, 1'b1, 1'b0);
          run_case(vals[i], vals[j], 3'b111, 1'b0, 1'b1);
          run_case(vals[i], vals[j], 3'b111, 1'b1, 1'b0);
          run_case(vals[i], vals[j], 3'b010, 1'b1, 1'b1);
          run_case(vals[i], vals[j], 3'b010, 1'b0, 1'b0);
          run_case(vals[i], vals[j], 3'b011, 1'b1, 1'b1);
          run_case(vals[i], vals[j], 3'b011, 1'b0, 1'b0);
        end
      end

      // Shift operations and B[4:0] masking
      for (i = 0; i < 10; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
          run_case(vals[i], shv[j], 3'b001, 1'b0, 1'b1);
          run_case(vals[i], shv[j], 3'b001, 1'b1, 1'b0);
          run_case(vals[i], shv[j], 3'b101, 1'b0, 1'b1);
          run_case(vals[i], shv[j], 3'b101, 1'b1, 1'b1);
        end
      end

      // Unspecified ALUResult combinations: only Sum is checked
      for (s = 1; s <= 7; s = s + 1) begin
        run_case(32'h89ABCDEF, 32'h10203040, s[2:0], 1'b1, (s == 3'b101));
      end
      run_case(32'h89ABCDEF, 32'h10203040, 3'b001, 1'b1, 1'b0);
      run_case(32'h89ABCDEF, 32'h10203040, 3'b010, 1'b0, 1'b0);
      run_case(32'h89ABCDEF, 32'h10203040, 3'b011, 1'b0, 1'b0);
      run_case(32'h89ABCDEF, 32'h10203040, 3'b100, 1'b1, 1'b0);
      run_case(32'h89ABCDEF, 32'h10203040, 3'b110, 1'b1, 1'b0);
      run_case(32'h89ABCDEF, 32'h10203040, 3'b111, 1'b1, 1'b0);

      // Interacting control sweep on one operand pair
      for (sub = 0; sub < 2; sub = sub + 1) begin
        for (s = 0; s < 8; s = s + 1) begin
          case ({s[2:0],sub[0]})
            4'b0000,4'b0001,4'b0010,4'b0101,4'b0111,4'b1000,4'b1010,4'b1011,4'b1100,4'b1110:
              run_case(32'h80000001, 32'h7FFFFFFF, s[2:0], sub[0], 1'b1);
            default:
              run_case(32'h80000001, 32'h7FFFFFFF, s[2:0], sub[0], 1'b0);
          endcase
        end
      end
    end
  endtask

  initial begin
    checks = 0;
    failures = 0;
    done = 0;
    A = 32'h0;
    B = 32'h0;
    ALUSelect = 3'b000;
    SubArith = 1'b0;

    do_tests();

    done = 1;
    $display("SUMMARY checks=%0d failures=%0d", checks, failures);
    if (checks > 0 && failures == 0) begin
      $display("PASS");
      $finish;
    end else begin
      $display("FAIL");
      $fatal(1, "verification failed");
    end
  end

  initial begin
    #5000;
    if (!done) begin
      $display("FAIL");
      $fatal(1, "timeout");
    end
  end

endmodule
