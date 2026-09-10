`timescale 1ns/1ps

module extend_tb;

  logic [31:7] InstrD;
  logic [2:0]  ImmSrcD;
  logic [31:0] ImmExtD;

  integer checks;
  integer failures;
  integer done;

  extend dut (
    .InstrD(InstrD),
    .ImmSrcD(ImmSrcD),
    .ImmExtD(ImmExtD)
  );

  function automatic [31:0] exp_imm(
    input logic [31:7] instr,
    input logic [2:0]  src
  );
    reg [31:0] r;
    begin
      r = 32'h00000000;
      case (src)
        3'b000: r = {{20{instr[31]}}, instr[31:20]};
        3'b001: r = {{20{instr[31]}}, instr[31:25], instr[11:7]};
        3'b010: r = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
        3'b011: r = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
        3'b100: r = {instr[31:12], 12'b0};
        default: r = 32'hxxxxxxxx;
      endcase
      exp_imm = r;
    end
  endfunction

  task automatic check_case(
    input logic [31:7] instr,
    input logic [2:0]  src,
    input bit          do_check,
    input [255:0]      name
  );
    reg [31:0] expected;
    begin
      InstrD = instr;
      ImmSrcD = src;
      #1;
      if (do_check) begin
        expected = exp_imm(instr, src);
        checks = checks + 1;
        if (ImmExtD !== expected) begin
          failures = failures + 1;
          $display("Mismatch %0s InstrD=%h ImmSrcD=%b actual=%h expected=%h",
                   name, instr, src, ImmExtD, expected);
        end
      end
    end
  endtask

  task automatic test_i_imm(input integer sval);
    reg signed [31:0] tmp;
    reg [11:0] imm12;
    reg [31:7] instr;
    begin
      tmp = sval;
      imm12 = tmp[11:0];
      instr = '0;
      instr[31:20] = imm12;
      check_case(instr, 3'b000, 1'b1, "I");
    end
  endtask

  task automatic test_s_imm(input integer sval);
    reg signed [31:0] tmp;
    reg [11:0] imm12;
    reg [31:7] instr;
    begin
      tmp = sval;
      imm12 = tmp[11:0];
      instr = '0;
      instr[31:25] = imm12[11:5];
      instr[11:7]  = imm12[4:0];
      check_case(instr, 3'b001, 1'b1, "S");
    end
  endtask

  task automatic test_b_imm(input integer sval);
    reg signed [31:0] tmp;
    reg [12:0] imm13;
    reg [31:7] instr;
    begin
      tmp = sval;
      imm13 = tmp[12:0];
      instr = '0;
      instr[31]    = imm13[12];
      instr[7]     = imm13[11];
      instr[30:25] = imm13[10:5];
      instr[11:8]  = imm13[4:1];
      check_case(instr, 3'b010, 1'b1, "B");
    end
  endtask

  task automatic test_j_imm(input integer sval);
    reg signed [31:0] tmp;
    reg [20:0] imm21;
    reg [31:7] instr;
    begin
      tmp = sval;
      imm21 = tmp[20:0];
      instr = '0;
      instr[31]    = imm21[20];
      instr[19:12] = imm21[19:12];
      instr[20]    = imm21[11];
      instr[30:21] = imm21[10:1];
      check_case(instr, 3'b011, 1'b1, "J");
    end
  endtask

  task automatic test_u_imm(input [19:0] upper20);
    reg [31:7] instr;
    begin
      instr = '0;
      instr[31:12] = upper20;
      check_case(instr, 3'b100, 1'b1, "U");
    end
  endtask

  integer i;
  integer val;

  initial begin
    checks = 0;
    failures = 0;
    done = 0;
    InstrD = '0;
    ImmSrcD = 3'b000;

    // I-type: examples, zero, extrema, sign boundaries
    test_i_imm(0);
    test_i_imm(1);
    test_i_imm(-1);
    test_i_imm(2047);
    test_i_imm(-2048);
    test_i_imm(1024);
    test_i_imm(-1024);
    test_i_imm(16);
    test_i_imm(-16);

    // S-type: zero, extrema, sign boundaries
    test_s_imm(0);
    test_s_imm(1);
    test_s_imm(-1);
    test_s_imm(2047);
    test_s_imm(-2048);
    test_s_imm(31);
    test_s_imm(-32);
    test_s_imm(1365);
    test_s_imm(-1365);

    // B-type: sample cases, zero, extrema, alignment/sign boundaries
    test_b_imm(0);
    test_b_imm(8);
    test_b_imm(-4);
    test_b_imm(2);
    test_b_imm(-2);
    test_b_imm(4094);
    test_b_imm(-4096);
    test_b_imm(256);
    test_b_imm(-256);

    // J-type: zero, small, extrema, sign boundaries
    test_j_imm(0);
    test_j_imm(2);
    test_j_imm(-2);
    test_j_imm(2048);
    test_j_imm(-2048);
    test_j_imm(1048574);
    test_j_imm(-1048576);
    test_j_imm(8);
    test_j_imm(-4);

    // U-type: zero and upper-field extrema/patterns
    test_u_imm(20'h00000);
    test_u_imm(20'h00001);
    test_u_imm(20'h7FFFF);
    test_u_imm(20'h80000);
    test_u_imm(20'hFFFFF);
    test_u_imm(20'hABCDE);
    test_u_imm(20'h55555);
    test_u_imm(20'hAAAAA);

    // Systematic fragmented-field coverage for valid modes
    for (i = 0; i < 8; i = i + 1) begin
      val = i * 257 - 1024;
      test_i_imm(val);
      test_s_imm(val);
    end

    for (i = 0; i < 8; i = i + 1) begin
      val = (i * 514) - 2048;
      test_b_imm(val);
    end

    for (i = 0; i < 8; i = i + 1) begin
      val = (i * 131072) - 524288;
      test_j_imm(val);
    end

    for (i = 0; i < 8; i = i + 1) begin
      test_u_imm((20'h13579 * i) ^ 20'hABCDE);
    end

    // Unused ImmSrcD values: drive but do not check unspecified outputs
    check_case(25'h0000000, 3'b101, 1'b0, "UNUSED");
    check_case(25'h1FFFFFF, 3'b110, 1'b0, "UNUSED");
    check_case(25'h1555555, 3'b111, 1'b0, "UNUSED");

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
    #10000;
    if (!done) begin
      $display("FAIL");
      $fatal(1, "timeout");
    end
  end

endmodule
