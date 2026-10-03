`timescale 1ns/1ps

module controller_tb;

  logic [31:0] InstrD;
  logic        RegWriteD;
  logic [2:0]  ImmSrcD;
  logic        ALUSrcAD;
  logic        ALUSrcBD;
  logic [1:0]  MemRWD;
  logic [2:0]  ResultSrcD;
  logic        BranchD;
  logic        JumpD;
  logic        ALUResultSrcD;
  logic [2:0]  ALUSelectD;
  logic        SubArithD;
  logic        IllegalInstrD;

  controller dut (
    .InstrD(InstrD),
    .RegWriteD(RegWriteD),
    .ImmSrcD(ImmSrcD),
    .ALUSrcAD(ALUSrcAD),
    .ALUSrcBD(ALUSrcBD),
    .MemRWD(MemRWD),
    .ResultSrcD(ResultSrcD),
    .BranchD(BranchD),
    .JumpD(JumpD),
    .ALUResultSrcD(ALUResultSrcD),
    .ALUSelectD(ALUSelectD),
    .SubArithD(SubArithD),
    .IllegalInstrD(IllegalInstrD)
  );

  integer checks;
  integer failures;
  integer done;

  localparam [6:0] OPC_LOAD   = 7'b0000011;
  localparam [6:0] OPC_OPIMM  = 7'b0010011;
  localparam [6:0] OPC_AUIPC  = 7'b0010111;
  localparam [6:0] OPC_STORE  = 7'b0100011;
  localparam [6:0] OPC_OP     = 7'b0110011;
  localparam [6:0] OPC_LUI    = 7'b0110111;
  localparam [6:0] OPC_BRANCH = 7'b1100011;
  localparam [6:0] OPC_JALR   = 7'b1100111;
  localparam [6:0] OPC_JAL    = 7'b1101111;

  task automatic check1;
    input bit do_check;
    input [255:0] name;
    input logic actual;
    input logic expected;
    begin
      if (do_check) begin
        checks = checks + 1;
        if (actual !== expected) begin
          failures = failures + 1;
          $display("Mismatch %0s InstrD=%h actual=%b expected=%b", name, InstrD, actual, expected);
        end
      end
    end
  endtask

  task automatic check2;
    input bit do_check;
    input [255:0] name;
    input logic [1:0] actual;
    input logic [1:0] expected;
    begin
      if (do_check) begin
        checks = checks + 1;
        if (actual !== expected) begin
          failures = failures + 1;
          $display("Mismatch %0s InstrD=%h actual=%b expected=%b", name, InstrD, actual, expected);
        end
      end
    end
  endtask

  task automatic check3;
    input bit do_check;
    input [255:0] name;
    input logic [2:0] actual;
    input logic [2:0] expected;
    begin
      if (do_check) begin
        checks = checks + 1;
        if (actual !== expected) begin
          failures = failures + 1;
          $display("Mismatch %0s InstrD=%h actual=%b expected=%b", name, InstrD, actual, expected);
        end
      end
    end
  endtask

  function automatic [31:0] mk_r;
    input logic [6:0] funct7;
    input logic [4:0] rs2;
    input logic [4:0] rs1;
    input logic [2:0] funct3;
    input logic [4:0] rd;
    input logic [6:0] opcode;
    begin
      mk_r = {funct7, rs2, rs1, funct3, rd, opcode};
    end
  endfunction

  function automatic [31:0] mk_i;
    input logic [11:0] imm12;
    input logic [4:0] rs1;
    input logic [2:0] funct3;
    input logic [4:0] rd;
    input logic [6:0] opcode;
    begin
      mk_i = {imm12, rs1, funct3, rd, opcode};
    end
  endfunction

  function automatic [31:0] mk_s;
    input logic [11:0] imm12;
    input logic [4:0] rs2;
    input logic [4:0] rs1;
    input logic [2:0] funct3;
    input logic [6:0] opcode;
    begin
      mk_s = {imm12[11:5], rs2, rs1, funct3, imm12[4:0], opcode};
    end
  endfunction

  function automatic [31:0] mk_b;
    input logic [12:0] imm13;
    input logic [4:0] rs2;
    input logic [4:0] rs1;
    input logic [2:0] funct3;
    input logic [6:0] opcode;
    begin
      mk_b = {imm13[12], imm13[10:5], rs2, rs1, funct3, imm13[4:1], imm13[11], opcode};
    end
  endfunction

  function automatic [31:0] mk_u;
    input logic [19:0] imm20;
    input logic [4:0] rd;
    input logic [6:0] opcode;
    begin
      mk_u = {imm20, rd, opcode};
    end
  endfunction

  function automatic [31:0] mk_j;
    input logic [20:0] imm21;
    input logic [4:0] rd;
    input logic [6:0] opcode;
    begin
      mk_j = {imm21[20], imm21[10:1], imm21[11], imm21[19:12], rd, opcode};
    end
  endfunction

  task automatic apply_and_check;
    input [31:0] instr;
    input bit cRegWriteD;
    input logic eRegWriteD;
    input bit cImmSrcD;
    input logic [2:0] eImmSrcD;
    input bit cALUSrcAD;
    input logic eALUSrcAD;
    input bit cALUSrcBD;
    input logic eALUSrcBD;
    input bit cMemRWD;
    input logic [1:0] eMemRWD;
    input bit cResultSrcD;
    input logic [2:0] eResultSrcD;
    input bit cBranchD;
    input logic eBranchD;
    input bit cJumpD;
    input logic eJumpD;
    input bit cALUResultSrcD;
    input logic eALUResultSrcD;
    input bit cALUSelectD;
    input logic [2:0] eALUSelectD;
    input bit cSubArithD;
    input logic eSubArithD;
    input bit cIllegalInstrD;
    input logic eIllegalInstrD;
    begin
      InstrD = instr;
      #1;
      check1(cRegWriteD,     "RegWriteD",     RegWriteD,     eRegWriteD);
      check3(cImmSrcD,       "ImmSrcD",       ImmSrcD,       eImmSrcD);
      check1(cALUSrcAD,      "ALUSrcAD",      ALUSrcAD,      eALUSrcAD);
      check1(cALUSrcBD,      "ALUSrcBD",      ALUSrcBD,      eALUSrcBD);
      check2(cMemRWD,        "MemRWD",        MemRWD,        eMemRWD);
      check3(cResultSrcD,    "ResultSrcD",    ResultSrcD,    eResultSrcD);
      check1(cBranchD,       "BranchD",       BranchD,       eBranchD);
      check1(cJumpD,         "JumpD",         JumpD,         eJumpD);
      check1(cALUResultSrcD, "ALUResultSrcD", ALUResultSrcD, eALUResultSrcD);
      check3(cALUSelectD,    "ALUSelectD",    ALUSelectD,    eALUSelectD);
      check1(cSubArithD,     "SubArithD",     SubArithD,     eSubArithD);
      check1(cIllegalInstrD, "IllegalInstrD", IllegalInstrD, eIllegalInstrD);
    end
  endtask

  initial begin : main
    integer f3;
    logic [31:0] instr;
    logic [4:0] shamt5;
    checks = 0;
    failures = 0;
    done = 0;
    InstrD = 32'h00000000;

    // Loads: all legal funct3 and illegal funct3 boundaries
    for (f3 = 0; f3 < 8; f3 = f3 + 1) begin
      instr = mk_i(12'h000, 5'd2, f3[2:0], 5'd1, OPC_LOAD);
      if ((f3 == 0) || (f3 == 1) || (f3 == 2) || (f3 == 4) || (f3 == 5)) begin
        apply_and_check(instr, 1,1, 1,3'b000, 1,0, 1,1, 1,2'b10, 1,3'b001, 1,0, 1,0, 1,0, 1,3'b000, 1,0, 1,0);
      end else begin
        apply_and_check(instr, 1,0, 0,3'b000, 0,0, 0,0, 1,2'b00, 0,3'b000, 1,0, 1,0, 0,0, 0,3'b000, 0,0, 1,1);
      end
    end
    apply_and_check(mk_i(12'hfff, 5'd31, 3'b010, 5'd0, OPC_LOAD), 1,1, 1,3'b000, 1,0, 1,1, 1,2'b10, 1,3'b001, 1,0, 1,0, 1,0, 1,3'b000, 1,0, 1,0);

    // I-type ALU: legal non-shifts
    apply_and_check(mk_i(12'h000, 5'd2, 3'b000, 5'd1, OPC_OPIMM), 1,1, 1,3'b000, 1,0, 1,1, 1,2'b00, 1,3'b000, 1,0, 1,0, 1,0, 1,3'b000, 1,0, 1,0);
    apply_and_check(mk_i(12'h800, 5'd2, 3'b010, 5'd1, OPC_OPIMM), 1,1, 1,3'b000, 1,0, 1,1, 1,2'b00, 1,3'b000, 1,0, 1,0, 1,0, 1,3'b010, 1,1, 1,0);
    apply_and_check(mk_i(12'h7ff, 5'd2, 3'b011, 5'd1, OPC_OPIMM), 1,1, 1,3'b000, 1,0, 1,1, 1,2'b00, 1,3'b000, 1,0, 1,0, 1,0, 1,3'b011, 1,1, 1,0);
    apply_and_check(mk_i(12'h123, 5'd2, 3'b100, 5'd1, OPC_OPIMM), 1,1, 1,3'b000, 1,0, 1,1, 1,2'b00, 1,3'b000, 1,0, 1,0, 1,0, 1,3'b100, 1,0, 1,0);
    apply_and_check(mk_i(12'h456, 5'd2, 3'b110, 5'd1, OPC_OPIMM), 1,1, 1,3'b000, 1,0, 1,1, 1,2'b00, 1,3'b000, 1,0, 1,0, 1,0, 1,3'b110, 1,0, 1,0);
    apply_and_check(mk_i(12'h789, 5'd2, 3'b111, 5'd1, OPC_OPIMM), 1,1, 1,3'b000, 1,0, 1,1, 1,2'b00, 1,3'b000, 1,0, 1,0, 1,0, 1,3'b111, 1,0, 1,0);

    // I-type shifts: legal and illegal encodings
    shamt5 = 5'd0;
    apply_and_check(mk_i({7'b0000000, shamt5}, 5'd2, 3'b001, 5'd1, OPC_OPIMM), 1,1, 1,3'b000, 1,0, 1,1, 1,2'b00, 1,3'b000, 1,0, 1,0, 1,0, 1,3'b001, 1,0, 1,0);
    shamt5 = 5'd31;
    apply_and_check(mk_i({7'b0000000, shamt5}, 5'd2, 3'b001, 5'd1, OPC_OPIMM), 1,1, 1,3'b000, 1,0, 1,1, 1,2'b00, 1,3'b000, 1,0, 1,0, 1,0, 1,3'b001, 1,0, 1,0);
    shamt5 = 5'd1;
    apply_and_check(mk_i({7'b0000000, shamt5}, 5'd2, 3'b101, 5'd1, OPC_OPIMM), 1,1, 1,3'b000, 1,0, 1,1, 1,2'b00, 1,3'b000, 1,0, 1,0, 1,0, 1,3'b101, 1,0, 1,0);
    shamt5 = 5'd31;
    apply_and_check(mk_i({7'b0100000, shamt5}, 5'd2, 3'b101, 5'd1, OPC_OPIMM), 1,1, 1,3'b000, 1,0, 1,1, 1,2'b00, 1,3'b000, 1,0, 1,0, 1,0, 1,3'b101, 1,1, 1,0);
    shamt5 = 5'd3;
    apply_and_check(mk_i({7'b0100000, shamt5}, 5'd2, 3'b001, 5'd1, OPC_OPIMM), 1,0, 0,3'b000, 0,0, 0,0, 1,2'b00, 0,3'b000, 1,0, 1,0, 0,0, 0,3'b000, 0,0, 1,1);
    apply_and_check(mk_i({7'b0010000, shamt5}, 5'd2, 3'b101, 5'd1, OPC_OPIMM), 1,0, 0,3'b000, 0,0, 0,0, 1,2'b00, 0,3'b000, 1,0, 1,0, 0,0, 0,3'b000, 0,0, 1,1);

    // AUIPC and LUI
    apply_and_check(mk_u(20'h00000, 5'd1, OPC_AUIPC), 1,1, 1,3'b100, 1,1, 1,1, 1,2'b00, 1,3'b000, 1,0, 1,0, 1,0, 1,3'b000, 1,0, 1,0);
    apply_and_check(mk_u(20'hfffff, 5'd31, OPC_AUIPC), 1,1, 1,3'b100, 1,1, 1,1, 1,2'b00, 1,3'b000, 1,0, 1,0, 1,0, 1,3'b000, 1,0, 1,0);
    apply_and_check(mk_u(20'h00000, 5'd1, OPC_LUI),   1,1, 1,3'b100, 1,0, 1,1, 1,2'b00, 1,3'b000, 1,0, 1,0, 1,1, 1,3'b000, 0,0, 1,0);
    apply_and_check(mk_u(20'h80000, 5'd31, OPC_LUI),  1,1, 1,3'b100, 1,0, 1,1, 1,2'b00, 1,3'b000, 1,0, 1,0, 1,1, 1,3'b000, 0,0, 1,0);

    // Stores: legal and illegal funct3
    for (f3 = 0; f3 < 8; f3 = f3 + 1) begin
      instr = mk_s(12'h123, 5'd3, 5'd2, f3[2:0], OPC_STORE);
      if ((f3 == 0) || (f3 == 1) || (f3 == 2)) begin
        apply_and_check(instr, 1,0, 1,3'b001, 1,0, 1,1, 1,2'b01, 1,3'b000, 1,0, 1,0, 1,0, 1,3'b000, 1,0, 1,0);
      end else begin
        apply_and_check(instr, 1,0, 0,3'b000, 0,0, 0,0, 1,2'b00, 0,3'b000, 1,0, 1,0, 0,0, 0,3'b000, 0,0, 1,1);
      end
    end

    // R-type ALU: all funct3 with legal funct7s, plus illegal funct7
    for (f3 = 0; f3 < 8; f3 = f3 + 1) begin
      instr = mk_r(7'b0000000, 5'd3, 5'd2, f3[2:0], 5'd1, OPC_OP);
      apply_and_check(instr, 1,1, 1,3'b000, 1,0, 1,0, 1,2'b00, 1,3'b000, 1,0, 1,0, 1,0, 1,f3[2:0], 1,((f3==2)||(f3==3)) ? 1'b1 : 1'b0, 1,0);
    end
    apply_and_check(mk_r(7'b0100000, 5'd3, 5'd2, 3'b000, 5'd1, OPC_OP), 1,1, 1,3'b000, 1,0, 1,0, 1,2'b00, 1,3'b000, 1,0, 1,0, 1,0, 1,3'b000, 1,1, 1,0);
    apply_and_check(mk_r(7'b0100000, 5'd3, 5'd2, 3'b101, 5'd1, OPC_OP), 1,1, 1,3'b000, 1,0, 1,0, 1,2'b00, 1,3'b000, 1,0, 1,0, 1,0, 1,3'b101, 1,1, 1,0);
    apply_and_check(mk_r(7'b0100000, 5'd3, 5'd2, 3'b001, 5'd1, OPC_OP), 1,0, 0,3'b000, 0,0, 0,0, 1,2'b00, 0,3'b000, 1,0, 1,0, 0,0, 0,3'b000, 0,0, 1,1);
    apply_and_check(mk_r(7'b1111111, 5'd3, 5'd2, 3'b111, 5'd1, OPC_OP), 1,0, 0,3'b000, 0,0, 0,0, 1,2'b00, 0,3'b000, 1,0, 1,0, 0,0, 0,3'b000, 0,0, 1,1);

    // Branches: legal and illegal funct3
    for (f3 = 0; f3 < 8; f3 = f3 + 1) begin
      instr = mk_b(13'h0000, 5'd3, 5'd2, f3[2:0], OPC_BRANCH);
      if ((f3 == 0) || (f3 == 1) || (f3 == 4) || (f3 == 5) || (f3 == 6) || (f3 == 7)) begin
        apply_and_check(instr, 1,0, 1,3'b010, 1,1, 1,1, 1,2'b00, 1,3'b000, 1,1, 1,0, 1,0, 1,3'b000, 1,0, 1,0);
      end else begin
        apply_and_check(instr, 1,0, 0,3'b000, 0,0, 0,0, 1,2'b00, 0,3'b000, 1,0, 1,0, 0,0, 0,3'b000, 0,0, 1,1);
      end
    end
    apply_and_check(mk_b(13'h1ffe, 5'd31, 5'd0, 3'b000, OPC_BRANCH), 1,0, 1,3'b010, 1,1, 1,1, 1,2'b00, 1,3'b000, 1,1, 1,0, 1,0, 1,3'b000, 1,0, 1,0);

    // JALR legal and illegal funct3
    apply_and_check(mk_i(12'h000, 5'd2, 3'b000, 5'd1, OPC_JALR), 1,1, 1,3'b000, 1,0, 1,1, 1,2'b00, 1,3'b000, 1,0, 1,1, 1,1, 1,3'b000, 1,0, 1,0);
    apply_and_check(mk_i(12'hfff, 5'd31, 3'b000, 5'd0, OPC_JALR), 1,1, 1,3'b000, 1,0, 1,1, 1,2'b00, 1,3'b000, 1,0, 1,1, 1,1, 1,3'b000, 1,0, 1,0);
    for (f3 = 1; f3 < 8; f3 = f3 + 1) begin
      apply_and_check(mk_i(12'h000, 5'd2, f3[2:0], 5'd1, OPC_JALR), 1,0, 0,3'b000, 0,0, 0,0, 1,2'b00, 0,3'b000, 1,0, 1,0, 0,0, 0,3'b000, 0,0, 1,1);
    end

    // JAL
    apply_and_check(mk_j(21'h00000, 5'd1, OPC_JAL), 1,1, 1,3'b011, 1,1, 1,1, 1,2'b00, 1,3'b000, 1,0, 1,1, 1,1, 1,3'b000, 1,0, 1,0);
    apply_and_check(mk_j(21'h1ffffe, 5'd31, OPC_JAL), 1,1, 1,3'b011, 1,1, 1,1, 1,2'b00, 1,3'b000, 1,0, 1,1, 1,1, 1,3'b000, 1,0, 1,0);

    // Unsupported/extension opcodes and sample illegal opcode
    apply_and_check(32'h0000000f, 1,0, 0,3'b000, 0,0, 0,0, 1,2'b00, 0,3'b000, 1,0, 1,0, 0,0, 0,3'b000, 0,0, 1,1); // FENCE
    apply_and_check(32'h0000100f, 1,0, 0,3'b000, 0,0, 0,0, 1,2'b00, 0,3'b000, 1,0, 1,0, 0,0, 0,3'b000, 0,0, 1,1); // FENCE.I
    apply_and_check(32'h00000073, 1,0, 0,3'b000, 0,0, 0,0, 1,2'b00, 0,3'b000, 1,0, 1,0, 0,0, 0,3'b000, 0,0, 1,1); // ECALL
    apply_and_check(32'h00100073, 1,0, 0,3'b000, 0,0, 0,0, 1,2'b00, 0,3'b000, 1,0, 1,0, 0,0, 0,3'b000, 0,0, 1,1); // EBREAK
    apply_and_check(32'h00002073, 1,0, 0,3'b000, 0,0, 0,0, 1,2'b00, 0,3'b000, 1,0, 1,0, 0,0, 0,3'b000, 0,0, 1,1); // CSR*
    apply_and_check(32'h0000007f, 1,0, 0,3'b000, 0,0, 0,0, 1,2'b00, 0,3'b000, 1,0, 1,0, 0,0, 0,3'b000, 0,0, 1,1); // invalid opcode sample

    done = 1;
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
    if (!done) begin
      $display("FAIL");
      $fatal(1, "timeout");
    end
  end

endmodule
