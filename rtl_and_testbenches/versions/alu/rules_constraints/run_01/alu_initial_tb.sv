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

  task automatic check_case(
    input [31:0] inA,
    input [31:0] inB,
    input [2:0]  inSel,
    input        inSub,
    input        check_result,
    input [31:0] exp_result,
    input [31:0] exp_sum
  );
    reg signed [31:0] sA;
    reg signed [31:0] sB;
    reg [4:0] shamt;
    begin
      A = inA;
      B = inB;
      ALUSelect = inSel;
      SubArith = inSub;
      #1;

      checks = checks + 1;
      if (Sum !== exp_sum) begin
        failures = failures + 1;
        $display("Mismatch Sum A=%h B=%h ALUSelect=%03b SubArith=%b actual=%h expected=%h", A, B, ALUSelect, SubArith, Sum, exp_sum);
      end

      if (check_result) begin
        checks = checks + 1;
        if (ALUResult !== exp_result) begin
          failures = failures + 1;
          $display("Mismatch ALUResult A=%h B=%h ALUSelect=%03b SubArith=%b actual=%h expected=%h", A, B, ALUSelect, SubArith, ALUResult, exp_result);
        end
      end

      sA = inA;
      sB = inB;
      shamt = inB[4:0];
      if (check_result) begin
        case ({inSel,inSub})
          4'b0000: if (exp_result !== (inA + inB)) begin failures = failures + 1; $display("TB internal expectation error ADD"); end
          4'b0001: if (exp_result !== (inA - inB)) begin failures = failures + 1; $display("TB internal expectation error SUB"); end
          4'b0010: if (exp_result !== (inA << shamt)) begin failures = failures + 1; $display("TB internal expectation error SLL"); end
          4'b0101: if (exp_result !== ((sA < sB) ? 32'h00000001 : 32'h00000000)) begin failures = failures + 1; $display("TB internal expectation error SLT"); end
          4'b0111: if (exp_result !== ((inA < inB) ? 32'h00000001 : 32'h00000000)) begin failures = failures + 1; $display("TB internal expectation error SLTU"); end
          4'b1000: if (exp_result !== (inA ^ inB)) begin failures = failures + 1; $display("TB internal expectation error XOR"); end
          4'b1010: if (exp_result !== (inA >> shamt)) begin failures = failures + 1; $display("TB internal expectation error SRL"); end
          4'b1011: if (exp_result !== (sA >>> shamt)) begin failures = failures + 1; $display("TB internal expectation error SRA"); end
          4'b1100: if (exp_result !== (inA | inB)) begin failures = failures + 1; $display("TB internal expectation error OR"); end
          4'b1110: if (exp_result !== (inA & inB)) begin failures = failures + 1; $display("TB internal expectation error AND"); end
          default: begin end
        endcase
      end
      if (exp_sum !== (inSub ? (inA - inB) : (inA + inB))) begin
        failures = failures + 1;
        $display("TB internal expectation error Sum");
      end
    end
  endtask

  task automatic do_directed;
    reg signed [31:0] sA;
    reg signed [31:0] sB;
    reg [31:0] exp_r;
    reg [31:0] exp_s;
    reg [31:0] vals [0:7];
    reg [31:0] shifts [0:7];
    integer i;
    integer j;
    begin
      vals[0] = 32'h00000000;
      vals[1] = 32'h00000001;
      vals[2] = 32'hFFFFFFFF;
      vals[3] = 32'h7FFFFFFF;
      vals[4] = 32'h80000000;
      vals[5] = 32'h0000000A;
      vals[6] = 32'h00000003;
      vals[7] = 32'h55555555;

      shifts[0] = 32'h00000000;
      shifts[1] = 32'h00000001;
      shifts[2] = 32'h0000001F;
      shifts[3] = 32'h00000020;
      shifts[4] = 32'h0000003F;
      shifts[5] = 32'h12345660;
      shifts[6] = 32'h12345661;
      shifts[7] = 32'h1234567F;

      check_case(32'h0000000A, 32'h00000003, 3'b000, 1'b0, 1'b1, 32'h0000000D, 32'h0000000D);
      check_case(32'h0000000A, 32'h00000003, 3'b000, 1'b1, 1'b1, 32'h00000007, 32'h00000007);
      check_case(32'hFFFFFFFF, 32'h00000001, 3'b010, 1'b1, 1'b1, 32'h00000001, 32'hFFFFFFFE);
      check_case(32'hFFFFFFFF, 32'h00000001, 3'b011, 1'b1, 1'b1, 32'h00000000, 32'hFFFFFFFE);
      check_case(32'h80000000, 32'h00000001, 3'b101, 1'b1, 1'b1, 32'hC0000000, 32'h7FFFFFFF);
      check_case(32'h0000000F, 32'h0000001F, 3'b001, 1'b0, 1'b1, 32'h80000000, 32'h0000002E);

      for (i = 0; i < 8; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
          exp_s = vals[i] + vals[j];
          exp_r = vals[i] + vals[j];
          check_case(vals[i], vals[j], 3'b000, 1'b0, 1'b1, exp_r, exp_s);

          exp_s = vals[i] - vals[j];
          exp_r = vals[i] - vals[j];
          check_case(vals[i], vals[j], 3'b000, 1'b1, 1'b1, exp_r, exp_s);

          exp_s = vals[i] + vals[j];
          exp_r = vals[i] ^ vals[j];
          check_case(vals[i], vals[j], 3'b100, 1'b0, 1'b1, exp_r, exp_s);

          exp_s = vals[i] + vals[j];
          exp_r = vals[i] | vals[j];
          check_case(vals[i], vals[j], 3'b110, 1'b0, 1'b1, exp_r, exp_s);

          exp_s = vals[i] + vals[j];
          exp_r = vals[i] & vals[j];
          check_case(vals[i], vals[j], 3'b111, 1'b0, 1'b1, exp_r, exp_s);

          sA = vals[i];
          sB = vals[j];
          exp_s = vals[i] - vals[j];
          exp_r = (sA < sB) ? 32'h1 : 32'h0;
          check_case(vals[i], vals[j], 3'b010, 1'b1, 1'b1, exp_r, exp_s);

          exp_s = vals[i] - vals[j];
          exp_r = (vals[i] < vals[j]) ? 32'h1 : 32'h0;
          check_case(vals[i], vals[j], 3'b011, 1'b1, 1'b1, exp_r, exp_s);
        end
      end

      for (i = 0; i < 8; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
          exp_s = vals[i] + shifts[j];
          exp_r = vals[i] << shifts[j][4:0];
          check_case(vals[i], shifts[j], 3'b001, 1'b0, 1'b1, exp_r, exp_s);

          exp_s = vals[i] + shifts[j];
          exp_r = vals[i] >> shifts[j][4:0];
          check_case(vals[i], shifts[j], 3'b101, 1'b0, 1'b1, exp_r, exp_s);

          sA = vals[i];
          exp_s = vals[i] - shifts[j];
          exp_r = sA >>> shifts[j][4:0];
          check_case(vals[i], shifts[j], 3'b101, 1'b1, 1'b1, exp_r, exp_s);
        end
      end

      exp_s = 32'hFFFFFFFF + 32'h00000001;
      check_case(32'hFFFFFFFF, 32'h00000001, 3'b110, 1'b0, 1'b1, 32'hFFFFFFFF, exp_s);

      exp_s = 32'h80000000 - 32'h00000001;
      check_case(32'h80000000, 32'h00000001, 3'b111, 1'b1, 1'b0, 32'h00000000, exp_s);

      exp_s = 32'h12345678 + 32'h9ABCDEF0;
      check_case(32'h12345678, 32'h9ABCDEF0, 3'b010, 1'b0, 1'b0, 32'h00000000, exp_s);

      exp_s = 32'h12345678 - 32'h9ABCDEF0;
      check_case(32'h12345678, 32'h9ABCDEF0, 3'b001, 1'b1, 1'b0, 32'h00000000, exp_s);

      exp_s = 32'hAAAAAAAA + 32'h55555555;
      check_case(32'hAAAAAAAA, 32'h55555555, 3'b011, 1'b0, 1'b0, 32'h00000000, exp_s);

      exp_s = 32'hAAAAAAAA - 32'h55555555;
      check_case(32'hAAAAAAAA, 32'h55555555, 3'b100, 1'b1, 1'b0, 32'h00000000, exp_s);
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

    // Directed operation, boundary, shift amount, and independent Sum tests
    do_directed();

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

  initial begin
    #5000;
    if (!done) begin
      $display("FAIL");
      $fatal(1, "timeout");
    end
  end

endmodule
