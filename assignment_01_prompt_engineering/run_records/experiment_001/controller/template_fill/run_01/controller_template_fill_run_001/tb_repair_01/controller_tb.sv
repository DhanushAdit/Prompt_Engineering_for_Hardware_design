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

  integer checks, failures;
  logic done;

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

  typedef struct packed {
    logic        RegWriteD;     logic v_RegWriteD;
    logic [2:0]  ImmSrcD;       logic v_ImmSrcD;
    logic        ALUSrcAD;      logic v_ALUSrcAD;
    logic        ALUSrcBD;      logic v_ALUSrcBD;
    logic [1:0]  MemRWD;        logic v_MemRWD;
    logic [2:0]  ResultSrcD;    logic v_ResultSrcD;
    logic        BranchD;       logic v_BranchD;
    logic        JumpD;         logic v_JumpD;
    logic        ALUResultSrcD; logic v_ALUResultSrcD;
    logic [2:0]  ALUSelectD;    logic v_ALUSelectD;
    logic        SubArithD;     logic v_SubArithD;
    logic        IllegalInstrD; logic v_IllegalInstrD;
  } exp_t;

  function automatic [31:0] mk_r(input [6:0] funct7, input [4:0] rs2, input [4:0] rs1, input [2:0] funct3, input [4:0] rd, input [6:0] opcode);
    mk_r = {funct7, rs2, rs1, funct3, rd, opcode};
  endfunction
  function automatic [31:0] mk_i(input [11:0] imm12, input [4:0] rs1, input [2:0] funct3, input [4:0] rd, input [6:0] opcode);
    mk_i = {imm12, rs1, funct3, rd, opcode};
  endfunction
  function automatic [31:0] mk_s(input [11:0] imm12, input [4:0] rs2, input [4:0] rs1, input [2:0] funct3, input [6:0] opcode);
    mk_s = {imm12[11:5], rs2, rs1, funct3, imm12[4:0], opcode};
  endfunction
  function automatic [31:0] mk_b(input [12:0] imm13, input [4:0] rs2, input [4:0] rs1, input [2:0] funct3, input [6:0] opcode);
    mk_b = {imm13[12], imm13[10:5], rs2, rs1, funct3, imm13[4:1], imm13[11], opcode};
  endfunction
  function automatic [31:0] mk_u(input [19:0] imm20, input [4:0] rd, input [6:0] opcode);
    mk_u = {imm20, rd, opcode};
  endfunction
  function automatic [31:0] mk_j(input [20:0] imm21, input [4:0] rd, input [6:0] opcode);
    mk_j = {imm21[20], imm21[10:1], imm21[11], imm21[19:12], rd, opcode};
  endfunction

  function automatic exp_t decode_ref(input logic [31:0] instr);
    exp_t e;
    logic [6:0] opcode, funct7;
    logic [2:0] funct3;
    begin
      e = '0;
      opcode = instr[6:0];
      funct3 = instr[14:12];
      funct7 = instr[31:25];
      case (opcode)
        7'b0000011: begin
          if (funct3==3'b000 || funct3==3'b001 || funct3==3'b010 || funct3==3'b100 || funct3==3'b101) begin
            e.RegWriteD=1; e.v_RegWriteD=1; e.ImmSrcD=3'b000; e.v_ImmSrcD=1; e.ALUSrcAD=0; e.v_ALUSrcAD=1;
            e.ALUSrcBD=1; e.v_ALUSrcBD=1; e.MemRWD=2'b10; e.v_MemRWD=1; e.ResultSrcD=3'b001; e.v_ResultSrcD=1;
            e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1; e.ALUResultSrcD=0; e.v_ALUResultSrcD=1;
            e.ALUSelectD=3'b000; e.v_ALUSelectD=1; e.SubArithD=0; e.v_SubArithD=1; e.IllegalInstrD=0; e.v_IllegalInstrD=1;
          end else begin
            e.IllegalInstrD=1; e.v_IllegalInstrD=1; e.RegWriteD=0; e.v_RegWriteD=1; e.MemRWD=2'b00; e.v_MemRWD=1;
            e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
          end
        end
        7'b0010011: begin
          if ((funct3==3'b001 && funct7!=7'b0000000) || (funct3==3'b101 && !(funct7==7'b0000000 || funct7==7'b0100000))) begin
            e.IllegalInstrD=1; e.v_IllegalInstrD=1; e.RegWriteD=0; e.v_RegWriteD=1; e.MemRWD=2'b00; e.v_MemRWD=1;
            e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
          end else begin
            e.RegWriteD=1; e.v_RegWriteD=1; e.ImmSrcD=3'b000; e.v_ImmSrcD=1; e.ALUSrcAD=0; e.v_ALUSrcAD=1;
            e.ALUSrcBD=1; e.v_ALUSrcBD=1; e.MemRWD=2'b00; e.v_MemRWD=1; e.ResultSrcD=3'b000; e.v_ResultSrcD=1;
            e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1; e.ALUResultSrcD=0; e.v_ALUResultSrcD=1;
            e.ALUSelectD=funct3; e.v_ALUSelectD=1;
            e.SubArithD=(funct3==3'b010 || funct3==3'b011 || (funct3==3'b101 && funct7==7'b0100000)); e.v_SubArithD=1;
            e.IllegalInstrD=0; e.v_IllegalInstrD=1;
          end
        end
        7'b0010111: begin
          e.RegWriteD=1; e.v_RegWriteD=1; e.ImmSrcD=3'b100; e.v_ImmSrcD=1; e.ALUSrcAD=1; e.v_ALUSrcAD=1;
          e.ALUSrcBD=1; e.v_ALUSrcBD=1; e.MemRWD=2'b00; e.v_MemRWD=1; e.ResultSrcD=3'b000; e.v_ResultSrcD=1;
          e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1; e.ALUResultSrcD=0; e.v_ALUResultSrcD=1;
          e.ALUSelectD=3'b000; e.v_ALUSelectD=1; e.SubArithD=0; e.v_SubArithD=1; e.IllegalInstrD=0; e.v_IllegalInstrD=1;
        end
        7'b0100011: begin
          if (funct3==3'b000 || funct3==3'b001 || funct3==3'b010) begin
            e.RegWriteD=0; e.v_RegWriteD=1; e.ImmSrcD=3'b001; e.v_ImmSrcD=1; e.ALUSrcAD=0; e.v_ALUSrcAD=1;
            e.ALUSrcBD=1; e.v_ALUSrcBD=1; e.MemRWD=2'b01; e.v_MemRWD=1; e.ResultSrcD=3'b000; e.v_ResultSrcD=1;
            e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1; e.ALUResultSrcD=0; e.v_ALUResultSrcD=1;
            e.ALUSelectD=3'b000; e.v_ALUSelectD=1; e.SubArithD=0; e.v_SubArithD=1; e.IllegalInstrD=0; e.v_IllegalInstrD=1;
          end else begin
            e.IllegalInstrD=1; e.v_IllegalInstrD=1; e.RegWriteD=0; e.v_RegWriteD=1; e.MemRWD=2'b00; e.v_MemRWD=1;
            e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
          end
        end
        7'b0110011: begin
          if (funct7==7'b0000000 || ((funct3==3'b000 || funct3==3'b101) && funct7==7'b0100000)) begin
            e.RegWriteD=1; e.v_RegWriteD=1; e.ImmSrcD=3'b000; e.v_ImmSrcD=1; e.ALUSrcAD=0; e.v_ALUSrcAD=1;
            e.ALUSrcBD=0; e.v_ALUSrcBD=1; e.MemRWD=2'b00; e.v_MemRWD=1; e.ResultSrcD=3'b000; e.v_ResultSrcD=1;
            e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1; e.ALUResultSrcD=0; e.v_ALUResultSrcD=1;
            e.ALUSelectD=funct3; e.v_ALUSelectD=1;
            e.SubArithD=(funct3==3'b010 || funct3==3'b011 || ((funct3==3'b000 || funct3==3'b101) && funct7==7'b0100000)); e.v_SubArithD=1;
            e.IllegalInstrD=0; e.v_IllegalInstrD=1;
          end else begin
            e.IllegalInstrD=1; e.v_IllegalInstrD=1; e.RegWriteD=0; e.v_RegWriteD=1; e.MemRWD=2'b00; e.v_MemRWD=1;
            e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
          end
        end
        7'b0110111: begin
          e.RegWriteD=1; e.v_RegWriteD=1; e.ImmSrcD=3'b100; e.v_ImmSrcD=1; e.ALUSrcAD=0; e.v_ALUSrcAD=1;
          e.ALUSrcBD=1; e.v_ALUSrcBD=1; e.MemRWD=2'b00; e.v_MemRWD=1; e.ResultSrcD=3'b000; e.v_ResultSrcD=1;
          e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1; e.ALUResultSrcD=1; e.v_ALUResultSrcD=1;
          e.ALUSelectD=3'b000; e.v_ALUSelectD=1; e.SubArithD=0; e.v_SubArithD=1; e.IllegalInstrD=0; e.v_IllegalInstrD=1;
        end
        7'b1100011: begin
          if (funct3==3'b000 || funct3==3'b001 || funct3==3'b100 || funct3==3'b101 || funct3==3'b110 || funct3==3'b111) begin
            e.RegWriteD=0; e.v_RegWriteD=1; e.ImmSrcD=3'b010; e.v_ImmSrcD=1; e.ALUSrcAD=1; e.v_ALUSrcAD=1;
            e.ALUSrcBD=1; e.v_ALUSrcBD=1; e.MemRWD=2'b00; e.v_MemRWD=1; e.ResultSrcD=3'b000; e.v_ResultSrcD=1;
            e.BranchD=1; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1; e.ALUResultSrcD=0; e.v_ALUResultSrcD=1;
            e.ALUSelectD=3'b000; e.v_ALUSelectD=1; e.SubArithD=0; e.v_SubArithD=1; e.IllegalInstrD=0; e.v_IllegalInstrD=1;
          end else begin
            e.IllegalInstrD=1; e.v_IllegalInstrD=1; e.RegWriteD=0; e.v_RegWriteD=1; e.MemRWD=2'b00; e.v_MemRWD=1;
            e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
          end
        end
        7'b1100111: begin
          if (funct3==3'b000) begin
            e.RegWriteD=1; e.v_RegWriteD=1; e.ImmSrcD=3'b000; e.v_ImmSrcD=1; e.ALUSrcAD=0; e.v_ALUSrcAD=1;
            e.ALUSrcBD=1; e.v_ALUSrcBD=1; e.MemRWD=2'b00; e.v_MemRWD=1; e.ResultSrcD=3'b000; e.v_ResultSrcD=1;
            e.BranchD=0; e.v_BranchD=1; e.JumpD=1; e.v_JumpD=1; e.ALUResultSrcD=1; e.v_ALUResultSrcD=1;
            e.ALUSelectD=3'b000; e.v_ALUSelectD=1; e.SubArithD=0; e.v_SubArithD=1; e.IllegalInstrD=0; e.v_IllegalInstrD=1;
          end else begin
            e.IllegalInstrD=1; e.v_IllegalInstrD=1; e.RegWriteD=0; e.v_RegWriteD=1; e.MemRWD=2'b00; e.v_MemRWD=1;
            e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
          end
        end
        7'b1101111: begin
          e.RegWriteD=1; e.v_RegWriteD=1; e.ImmSrcD=3'b011; e.v_ImmSrcD=1; e.ALUSrcAD=1; e.v_ALUSrcAD=1;
          e.ALUSrcBD=1; e.v_ALUSrcBD=1; e.MemRWD=2'b00; e.v_MemRWD=1; e.ResultSrcD=3'b000; e.v_ResultSrcD=1;
          e.BranchD=0; e.v_BranchD=1; e.JumpD=1; e.v_JumpD=1; e.ALUResultSrcD=1; e.v_ALUResultSrcD=1;
          e.ALUSelectD=3'b000; e.v_ALUSelectD=1; e.SubArithD=0; e.v_SubArithD=1; e.IllegalInstrD=0; e.v_IllegalInstrD=1;
        end
        default: begin
          e.IllegalInstrD=1; e.v_IllegalInstrD=1; e.RegWriteD=0; e.v_RegWriteD=1; e.MemRWD=2'b00; e.v_MemRWD=1;
          e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
        end
      endcase
      decode_ref = e;
    end
  endfunction

  task automatic cmp1(input [255:0] n, input logic a, input logic e, input logic v, input [31:0] instr);
    begin if (v) begin checks=checks+1; if (a !== e) begin failures=failures+1; $display("MISMATCH %0s instr=%h actual=%b expected=%b", n, instr, a, e); end end end
  endtask
  task automatic cmp2(input [255:0] n, input logic [1:0] a, input logic [1:0] e, input logic v, input [31:0] instr);
    begin if (v) begin checks=checks+1; if (a !== e) begin failures=failures+1; $display("MISMATCH %0s instr=%h actual=%b expected=%b", n, instr, a, e); end end end
  endtask
  task automatic cmp3(input [255:0] n, input logic [2:0] a, input logic [2:0] e, input logic v, input [31:0] instr);
    begin if (v) begin checks=checks+1; if (a !== e) begin failures=failures+1; $display("MISMATCH %0s instr=%h actual=%b expected=%b", n, instr, a, e); end end end
  endtask

  task automatic apply_and_check(input [31:0] instr, input [255:0] label);
    exp_t e;
    begin
      e = decode_ref(instr);
      InstrD = instr;
      #1;
      cmp1({label," RegWriteD"},RegWriteD,e.RegWriteD,e.v_RegWriteD,instr);
      cmp3({label," ImmSrcD"},ImmSrcD,e.ImmSrcD,e.v_ImmSrcD,instr);
      cmp1({label," ALUSrcAD"},ALUSrcAD,e.ALUSrcAD,e.v_ALUSrcAD,instr);
      cmp1({label," ALUSrcBD"},ALUSrcBD,e.ALUSrcBD,e.v_ALUSrcBD,instr);
      cmp2({label," MemRWD"},MemRWD,e.MemRWD,e.v_MemRWD,instr);
      cmp3({label," ResultSrcD"},ResultSrcD,e.ResultSrcD,e.v_ResultSrcD,instr);
      cmp1({label," BranchD"},BranchD,e.BranchD,e.v_BranchD,instr);
      cmp1({label," JumpD"},JumpD,e.JumpD,e.v_JumpD,instr);
      cmp1({label," ALUResultSrcD"},ALUResultSrcD,e.ALUResultSrcD,e.v_ALUResultSrcD,instr);
      cmp3({label," ALUSelectD"},ALUSelectD,e.ALUSelectD,e.v_ALUSelectD,instr);
      cmp1({label," SubArithD"},SubArithD,e.SubArithD,e.v_SubArithD,instr);
      cmp1({label," IllegalInstrD"},IllegalInstrD,e.IllegalInstrD,e.v_IllegalInstrD,instr);
    end
  endtask

  initial begin
    checks=0; failures=0; done=0; InstrD=32'h0;

    // Representative legal cases
    apply_and_check(mk_r(7'b0000000,5'd3,5'd2,3'b000,5'd1,7'b0110011),"add");
    apply_and_check(mk_r(7'b0100000,5'd3,5'd2,3'b000,5'd1,7'b0110011),"sub");
    apply_and_check(mk_i(12'h000,5'd2,3'b010,5'd1,7'b0000011),"lw");
    apply_and_check(mk_s(12'h000,5'd1,5'd2,3'b010,7'b0100011),"sw");
    apply_and_check(mk_b(13'h0000,5'd2,5'd1,3'b000,7'b1100011),"beq");
    apply_and_check(mk_i(12'h000,5'd2,3'b000,5'd1,7'b1100111),"jalr");
    apply_and_check(mk_j(21'h00000,5'd1,7'b1101111),"jal");
    apply_and_check(mk_u(20'h00000,5'd1,7'b0110111),"lui");
    apply_and_check(mk_u(20'hfffff,5'd1,7'b0010111),"auipc");
    apply_and_check(32'h0000007f,"illegal_opcode");

    // Load/store legality and boundaries
    apply_and_check(mk_i(12'h800,5'd0,3'b000,5'd31,7'b0000011),"lb_neg");
    apply_and_check(mk_i(12'h7ff,5'd31,3'b001,5'd0,7'b0000011),"lh_pos");
    apply_and_check(mk_i(12'h001,5'd1,3'b100,5'd2,7'b0000011),"lbu");
    apply_and_check(mk_i(12'hffe,5'd2,3'b101,5'd3,7'b0000011),"lhu");
    apply_and_check(mk_i(12'h123,5'd4,3'b011,5'd5,7'b0000011),"load_bad3");
    apply_and_check(mk_s(12'h800,5'd31,5'd0,3'b000,7'b0100011),"sb_neg");
    apply_and_check(mk_s(12'h7ff,5'd0,5'd31,3'b001,7'b0100011),"sh_pos");
    apply_and_check(mk_s(12'h001,5'd2,5'd1,3'b010,7'b0100011),"sw_small");
    apply_and_check(mk_s(12'h001,5'd2,5'd1,3'b011,7'b0100011),"store_bad3");

    // Branch legality and boundaries
    apply_and_check(mk_b(13'h0000,5'd0,5'd0,3'b001,7'b1100011),"bne");
    apply_and_check(mk_b(13'h1ffe,5'd1,5'd2,3'b100,7'b1100011),"blt_max");
    apply_and_check(mk_b(13'h1000,5'd2,5'd1,3'b101,7'b1100011),"bge_min");
    apply_and_check(mk_b(13'h0002,5'd3,5'd4,3'b110,7'b1100011),"bltu");
    apply_and_check(mk_b(13'h0004,5'd4,5'd3,3'b111,7'b1100011),"bgeu");
    apply_and_check(mk_b(13'h0000,5'd1,5'd2,3'b010,7'b1100011),"branch_bad010");
    apply_and_check(mk_b(13'h0000,5'd1,5'd2,3'b011,7'b1100011),"branch_bad011");

    // I-type ALU coverage
    apply_and_check(mk_i(12'h001,5'd2,3'b000,5'd1,7'b0010011),"addi");
    apply_and_check(mk_i(12'h001,5'd2,3'b010,5'd1,7'b0010011),"slti");
    apply_and_check(mk_i(12'hfff,5'd2,3'b011,5'd1,7'b0010011),"sltiu");
    apply_and_check(mk_i(12'h055,5'd2,3'b100,5'd1,7'b0010011),"xori");
    apply_and_check(mk_i({7'b0000000,5'd0},5'd2,3'b001,5'd1,7'b0010011),"slli0");
    apply_and_check(mk_i({7'b0000000,5'd31},5'd2,3'b001,5'd1,7'b0010011),"slli31");
    apply_and_check(mk_i({7'b0000000,5'd7},5'd2,3'b101,5'd1,7'b0010011),"srli");
    apply_and_check(mk_i({7'b0100000,5'd7},5'd2,3'b101,5'd1,7'b0010011),"srai");
    apply_and_check(mk_i(12'h0f0,5'd2,3'b110,5'd1,7'b0010011),"ori");
    apply_and_check(mk_i(12'h0f0,5'd2,3'b111,5'd1,7'b0010011),"andi");
    apply_and_check(mk_i({7'b0100000,5'd1},5'd2,3'b001,5'd1,7'b0010011),"slli_badf7");
    apply_and_check(mk_i({7'b0010000,5'd1},5'd2,3'b101,5'd1,7'b0010011),"shifti_badf7");

    // R-type full coverage
    apply_and_check(mk_r(7'b0000000,5'd3,5'd2,3'b001,5'd1,7'b0110011),"sll");
    apply_and_check(mk_r(7'b0000000,5'd3,5'd2,3'b010,5'd1,7'b0110011),"slt");
    apply_and_check(mk_r(7'b0000000,5'd3,5'd2,3'b011,5'd1,7'b0110011),"sltu");
    apply_and_check(mk_r(7'b0000000,5'd3,5'd2,3'b100,5'd1,7'b0110011),"xor");
    apply_and_check(mk_r(7'b0000000,5'd3,5'd2,3'b101,5'd1,7'b0110011),"srl");
    apply_and_check(mk_r(7'b0100000,5'd3,5'd2,3'b101,5'd1,7'b0110011),"sra");
    apply_and_check(mk_r(7'b0000000,5'd3,5'd2,3'b110,5'd1,7'b0110011),"or");
    apply_and_check(mk_r(7'b0000000,5'd3,5'd2,3'b111,5'd1,7'b0110011),"and");
    apply_and_check(mk_r(7'b0100000,5'd3,5'd2,3'b010,5'd1,7'b0110011),"rtype_bad_slt");
    apply_and_check(mk_r(7'b0000001,5'd3,5'd2,3'b000,5'd1,7'b0110011),"rtype_mul_ext");

    // Upper/jump boundaries and illegal system/fence
    apply_and_check(mk_j(21'h100000,5'd0,7'b1101111),"jal_min");
    apply_and_check(mk_j(21'h0ffffe,5'd31,7'b1101111),"jal_max");
    apply_and_check(mk_u(20'h80000,5'd31,7'b0110111),"lui_sign");
    apply_and_check(mk_u(20'h00001,5'd0,7'b0010111),"auipc_small");
    apply_and_check(mk_i(12'h123,5'd2,3'b001,5'd1,7'b1100111),"jalr_bad3");
    apply_and_check(32'h0000000f,"fence");
    apply_and_check(32'h0000100f,"fencei");
    apply_and_check(32'h00000073,"ecall");
    apply_and_check(32'h00100073,"ebreak");
    apply_and_check(32'h001110f3,"csr");

    // Compact deterministic sweep across main classes and funct3/funct7 interactions
    begin
      integer oi, f3i, f7i;
      reg [6:0] opclist [0:8];
      logic [6:0] opc, f7;
      logic [2:0] f3;
      logic [31:0] instr;
      opclist[0]=7'b0000011; opclist[1]=7'b0010011; opclist[2]=7'b0010111;
      opclist[3]=7'b0100011; opclist[4]=7'b0110011; opclist[5]=7'b0110111;
      opclist[6]=7'b1100011; opclist[7]=7'b1100111; opclist[8]=7'b1101111;
      for (oi=0; oi<9; oi=oi+1) begin
        opc = opclist[oi];
        for (f3i=0; f3i<8; f3i=f3i+1) begin
          f3 = f3i[2:0];
          for (f7i=0; f7i<3; f7i=f7i+1) begin
            case (f7i)
              0: f7=7'b0000000;
              1: f7=7'b0100000;
              default: f7=7'b0000001;
            endcase
            case (opc)
              7'b0000011,7'b0010011,7'b1100111: instr = mk_i({f7,5'd3},5'd2,f3,5'd1,opc);
              7'b0100011: instr = mk_s(12'h155,5'd3,5'd2,f3,opc);
              7'b0110011: instr = mk_r(f7,5'd3,5'd2,f3,5'd1,opc);
              7'b1100011: instr = mk_b(13'h0554,5'd3,5'd2,f3,opc);
              7'b0010111,7'b0110111: instr = mk_u(20'h54321,5'd1,opc);
              default: instr = mk_j(21'h15555,5'd1,opc);
            endcase
            apply_and_check(instr,"sweep");
          end
        end
      end
    end

    done=1;
    $display("SUMMARY checks=%0d failures=%0d", checks, failures);
    if (checks>0 && failures==0) begin
      $display("PASS");
      $finish;
    end else begin
      $display("FAIL");
      $fatal(1,"verification failed");
    end
  end

  initial begin
    #5000;
    if (!done) begin
      $display("FAIL");
      $fatal(1,"timeout");
    end
  end

endmodule
