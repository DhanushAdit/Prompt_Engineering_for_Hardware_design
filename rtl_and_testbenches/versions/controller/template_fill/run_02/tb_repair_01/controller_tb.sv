`timescale 1ns/1ps
module controller_tb;
  logic [31:0] InstrD;
  logic RegWriteD;
  logic [2:0] ImmSrcD;
  logic ALUSrcAD, ALUSrcBD;
  logic [1:0] MemRWD;
  logic [2:0] ResultSrcD;
  logic BranchD, JumpD, ALUResultSrcD;
  logic [2:0] ALUSelectD;
  logic SubArithD, IllegalInstrD;
  integer checks, failures;
  logic done;

  controller dut(
    .InstrD(InstrD), .RegWriteD(RegWriteD), .ImmSrcD(ImmSrcD), .ALUSrcAD(ALUSrcAD),
    .ALUSrcBD(ALUSrcBD), .MemRWD(MemRWD), .ResultSrcD(ResultSrcD), .BranchD(BranchD),
    .JumpD(JumpD), .ALUResultSrcD(ALUResultSrcD), .ALUSelectD(ALUSelectD),
    .SubArithD(SubArithD), .IllegalInstrD(IllegalInstrD)
  );

  typedef struct packed {
    logic RegWriteD,v_RegWriteD;
    logic [2:0] ImmSrcD; logic v_ImmSrcD;
    logic ALUSrcAD,v_ALUSrcAD;
    logic ALUSrcBD,v_ALUSrcBD;
    logic [1:0] MemRWD; logic v_MemRWD;
    logic [2:0] ResultSrcD; logic v_ResultSrcD;
    logic BranchD,v_BranchD;
    logic JumpD,v_JumpD;
    logic ALUResultSrcD,v_ALUResultSrcD;
    logic [2:0] ALUSelectD; logic v_ALUSelectD;
    logic SubArithD,v_SubArithD;
    logic IllegalInstrD,v_IllegalInstrD;
  } exp_t;

  function automatic [31:0] mk_r(input [6:0] f7,input [4:0] rs2,input [4:0] rs1,input [2:0] f3,input [4:0] rd,input [6:0] opc);
    mk_r={f7,rs2,rs1,f3,rd,opc};
  endfunction
  function automatic [31:0] mk_i(input [11:0] imm,input [4:0] rs1,input [2:0] f3,input [4:0] rd,input [6:0] opc);
    mk_i={imm,rs1,f3,rd,opc};
  endfunction
  function automatic [31:0] mk_s(input [11:0] imm,input [4:0] rs2,input [4:0] rs1,input [2:0] f3,input [6:0] opc);
    mk_s={imm[11:5],rs2,rs1,f3,imm[4:0],opc};
  endfunction
  function automatic [31:0] mk_b(input [12:0] imm,input [4:0] rs2,input [4:0] rs1,input [2:0] f3,input [6:0] opc);
    mk_b={imm[12],imm[10:5],rs2,rs1,f3,imm[4:1],imm[11],opc};
  endfunction
  function automatic [31:0] mk_u(input [19:0] imm,input [4:0] rd,input [6:0] opc);
    mk_u={imm,rd,opc};
  endfunction
  function automatic [31:0] mk_j(input [20:0] imm,input [4:0] rd,input [6:0] opc);
    mk_j={imm[20],imm[10:1],imm[11],imm[19:12],rd,opc};
  endfunction

  function automatic exp_t ref_decode(input logic [31:0] instr);
    exp_t e; logic [6:0] opc,f7; logic [2:0] f3;
    begin
      e='0; opc=instr[6:0]; f3=instr[14:12]; f7=instr[31:25];
      case(opc)
        7'b0000011: begin
          if(f3==3'b000||f3==3'b001||f3==3'b010||f3==3'b100||f3==3'b101) begin
            e.RegWriteD=1; e.v_RegWriteD=1; e.ImmSrcD=3'b000; e.v_ImmSrcD=1;
            e.ALUSrcAD=0; e.v_ALUSrcAD=1; e.ALUSrcBD=1; e.v_ALUSrcBD=1;
            e.MemRWD=2'b10; e.v_MemRWD=1; e.ResultSrcD=3'b001; e.v_ResultSrcD=1;
            e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
            e.ALUResultSrcD=0; e.v_ALUResultSrcD=1; e.ALUSelectD=3'b000; e.v_ALUSelectD=1;
            e.SubArithD=0; e.v_SubArithD=1; e.IllegalInstrD=0; e.v_IllegalInstrD=1;
          end else begin
            e.IllegalInstrD=1; e.v_IllegalInstrD=1; e.RegWriteD=0; e.v_RegWriteD=1;
            e.MemRWD=2'b00; e.v_MemRWD=1; e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
          end
        end
        7'b0010011: begin
          if((f3==3'b001 && f7!=7'b0000000) || (f3==3'b101 && !(f7==7'b0000000||f7==7'b0100000))) begin
            e.IllegalInstrD=1; e.v_IllegalInstrD=1; e.RegWriteD=0; e.v_RegWriteD=1;
            e.MemRWD=2'b00; e.v_MemRWD=1; e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
          end else begin
            e.RegWriteD=1; e.v_RegWriteD=1; e.ImmSrcD=3'b000; e.v_ImmSrcD=1;
            e.ALUSrcAD=0; e.v_ALUSrcAD=1; e.ALUSrcBD=1; e.v_ALUSrcBD=1;
            e.MemRWD=2'b00; e.v_MemRWD=1; e.ResultSrcD=3'b000; e.v_ResultSrcD=1;
            e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
            e.ALUResultSrcD=0; e.v_ALUResultSrcD=1; e.ALUSelectD=f3; e.v_ALUSelectD=1;
            e.SubArithD=(f3==3'b010)||(f3==3'b011)||((f3==3'b101)&&(f7==7'b0100000)); e.v_SubArithD=1;
            e.IllegalInstrD=0; e.v_IllegalInstrD=1;
          end
        end
        7'b0010111: begin
          e.RegWriteD=1; e.v_RegWriteD=1; e.ImmSrcD=3'b100; e.v_ImmSrcD=1;
          e.ALUSrcAD=1; e.v_ALUSrcAD=1; e.ALUSrcBD=1; e.v_ALUSrcBD=1; e.MemRWD=2'b00; e.v_MemRWD=1;
          e.ResultSrcD=3'b000; e.v_ResultSrcD=1; e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
          e.ALUResultSrcD=0; e.v_ALUResultSrcD=1; e.ALUSelectD=3'b000; e.v_ALUSelectD=1;
          e.SubArithD=0; e.v_SubArithD=1; e.IllegalInstrD=0; e.v_IllegalInstrD=1;
        end
        7'b0100011: begin
          if(f3==3'b000||f3==3'b001||f3==3'b010) begin
            e.RegWriteD=0; e.v_RegWriteD=1; e.ImmSrcD=3'b001; e.v_ImmSrcD=1;
            e.ALUSrcAD=0; e.v_ALUSrcAD=1; e.ALUSrcBD=1; e.v_ALUSrcBD=1; e.MemRWD=2'b01; e.v_MemRWD=1;
            e.ResultSrcD=3'b000; e.v_ResultSrcD=1; e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
            e.ALUResultSrcD=0; e.v_ALUResultSrcD=1; e.ALUSelectD=3'b000; e.v_ALUSelectD=1;
            e.SubArithD=0; e.v_SubArithD=1; e.IllegalInstrD=0; e.v_IllegalInstrD=1;
          end else begin
            e.IllegalInstrD=1; e.v_IllegalInstrD=1; e.RegWriteD=0; e.v_RegWriteD=1;
            e.MemRWD=2'b00; e.v_MemRWD=1; e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
          end
        end
        7'b0110011: begin
          if(f7==7'b0000000) begin
            e.RegWriteD=1; e.v_RegWriteD=1; e.ImmSrcD=3'b000; e.v_ImmSrcD=1;
            e.ALUSrcAD=0; e.v_ALUSrcAD=1; e.ALUSrcBD=0; e.v_ALUSrcBD=1; e.MemRWD=2'b00; e.v_MemRWD=1;
            e.ResultSrcD=3'b000; e.v_ResultSrcD=1; e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
            e.ALUResultSrcD=0; e.v_ALUResultSrcD=1; e.ALUSelectD=f3; e.v_ALUSelectD=1;
            e.SubArithD=(f3==3'b010)||(f3==3'b011); e.v_SubArithD=1; e.IllegalInstrD=0; e.v_IllegalInstrD=1;
          end else if(f7==7'b0100000 && (f3==3'b000||f3==3'b101)) begin
            e.RegWriteD=1; e.v_RegWriteD=1; e.ImmSrcD=3'b000; e.v_ImmSrcD=1;
            e.ALUSrcAD=0; e.v_ALUSrcAD=1; e.ALUSrcBD=0; e.v_ALUSrcBD=1; e.MemRWD=2'b00; e.v_MemRWD=1;
            e.ResultSrcD=3'b000; e.v_ResultSrcD=1; e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
            e.ALUResultSrcD=0; e.v_ALUResultSrcD=1; e.ALUSelectD=f3; e.v_ALUSelectD=1;
            e.SubArithD=1; e.v_SubArithD=1; e.IllegalInstrD=0; e.v_IllegalInstrD=1;
          end else begin
            e.IllegalInstrD=1; e.v_IllegalInstrD=1; e.RegWriteD=0; e.v_RegWriteD=1;
            e.MemRWD=2'b00; e.v_MemRWD=1; e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
          end
        end
        7'b0110111: begin
          e.RegWriteD=1; e.v_RegWriteD=1; e.ImmSrcD=3'b100; e.v_ImmSrcD=1;
          e.ALUSrcAD=0; e.v_ALUSrcAD=1; e.ALUSrcBD=1; e.v_ALUSrcBD=1; e.MemRWD=2'b00; e.v_MemRWD=1;
          e.ResultSrcD=3'b000; e.v_ResultSrcD=1; e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
          e.ALUResultSrcD=1; e.v_ALUResultSrcD=1; e.ALUSelectD=3'b000; e.v_ALUSelectD=1;
          e.SubArithD=0; e.v_SubArithD=1; e.IllegalInstrD=0; e.v_IllegalInstrD=1;
        end
        7'b1100011: begin
          if(f3==3'b000||f3==3'b001||f3==3'b100||f3==3'b101||f3==3'b110||f3==3'b111) begin
            e.RegWriteD=0; e.v_RegWriteD=1; e.ImmSrcD=3'b010; e.v_ImmSrcD=1;
            e.ALUSrcAD=1; e.v_ALUSrcAD=1; e.ALUSrcBD=1; e.v_ALUSrcBD=1; e.MemRWD=2'b00; e.v_MemRWD=1;
            e.ResultSrcD=3'b000; e.v_ResultSrcD=1; e.BranchD=1; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
            e.ALUResultSrcD=0; e.v_ALUResultSrcD=1; e.ALUSelectD=3'b000; e.v_ALUSelectD=1;
            e.SubArithD=0; e.v_SubArithD=1; e.IllegalInstrD=0; e.v_IllegalInstrD=1;
          end else begin
            e.IllegalInstrD=1; e.v_IllegalInstrD=1; e.RegWriteD=0; e.v_RegWriteD=1;
            e.MemRWD=2'b00; e.v_MemRWD=1; e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
          end
        end
        7'b1100111: begin
          if(f3==3'b000) begin
            e.RegWriteD=1; e.v_RegWriteD=1; e.ImmSrcD=3'b000; e.v_ImmSrcD=1;
            e.ALUSrcAD=0; e.v_ALUSrcAD=1; e.ALUSrcBD=1; e.v_ALUSrcBD=1; e.MemRWD=2'b00; e.v_MemRWD=1;
            e.ResultSrcD=3'b000; e.v_ResultSrcD=1; e.BranchD=0; e.v_BranchD=1; e.JumpD=1; e.v_JumpD=1;
            e.ALUResultSrcD=1; e.v_ALUResultSrcD=1; e.ALUSelectD=3'b000; e.v_ALUSelectD=1;
            e.SubArithD=0; e.v_SubArithD=1; e.IllegalInstrD=0; e.v_IllegalInstrD=1;
          end else begin
            e.IllegalInstrD=1; e.v_IllegalInstrD=1; e.RegWriteD=0; e.v_RegWriteD=1;
            e.MemRWD=2'b00; e.v_MemRWD=1; e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
          end
        end
        7'b1101111: begin
          e.RegWriteD=1; e.v_RegWriteD=1; e.ImmSrcD=3'b011; e.v_ImmSrcD=1;
          e.ALUSrcAD=1; e.v_ALUSrcAD=1; e.ALUSrcBD=1; e.v_ALUSrcBD=1; e.MemRWD=2'b00; e.v_MemRWD=1;
          e.ResultSrcD=3'b000; e.v_ResultSrcD=1; e.BranchD=0; e.v_BranchD=1; e.JumpD=1; e.v_JumpD=1;
          e.ALUResultSrcD=1; e.v_ALUResultSrcD=1; e.ALUSelectD=3'b000; e.v_ALUSelectD=1;
          e.SubArithD=0; e.v_SubArithD=1; e.IllegalInstrD=0; e.v_IllegalInstrD=1;
        end
        default: begin
          e.IllegalInstrD=1; e.v_IllegalInstrD=1; e.RegWriteD=0; e.v_RegWriteD=1;
          e.MemRWD=2'b00; e.v_MemRWD=1; e.BranchD=0; e.v_BranchD=1; e.JumpD=0; e.v_JumpD=1;
        end
      endcase
      ref_decode=e;
    end
  endfunction

  task automatic c1(input [127:0] n,input logic a,e,v,input [31:0] instr); begin if(v) begin checks=checks+1; if(a!==e) begin failures=failures+1; $display("MISMATCH %0s instr=%h actual=%b expected=%b",n,instr,a,e); end end end endtask
  task automatic c2(input [127:0] n,input logic [1:0] a,e,input logic v,input [31:0] instr); begin if(v) begin checks=checks+1; if(a!==e) begin failures=failures+1; $display("MISMATCH %0s instr=%h actual=%b expected=%b",n,instr,a,e); end end end endtask
  task automatic c3(input [127:0] n,input logic [2:0] a,e,input logic v,input [31:0] instr); begin if(v) begin checks=checks+1; if(a!==e) begin failures=failures+1; $display("MISMATCH %0s instr=%h actual=%b expected=%b",n,instr,a,e); end end end endtask

  task automatic apply(input [31:0] instr,input [127:0] tag);
    exp_t e;
    begin
      e=ref_decode(instr); InstrD=instr; #1;
      c1({tag," RW"},RegWriteD,e.RegWriteD,e.v_RegWriteD,instr);
      c3({tag," IM"},ImmSrcD,e.ImmSrcD,e.v_ImmSrcD,instr);
      c1({tag," SA"},ALUSrcAD,e.ALUSrcAD,e.v_ALUSrcAD,instr);
      c1({tag," SB"},ALUSrcBD,e.ALUSrcBD,e.v_ALUSrcBD,instr);
      c2({tag," MR"},MemRWD,e.MemRWD,e.v_MemRWD,instr);
      c3({tag," RS"},ResultSrcD,e.ResultSrcD,e.v_ResultSrcD,instr);
      c1({tag," BR"},BranchD,e.BranchD,e.v_BranchD,instr);
      c1({tag," JP"},JumpD,e.JumpD,e.v_JumpD,instr);
      c1({tag," AR"},ALUResultSrcD,e.ALUResultSrcD,e.v_ALUResultSrcD,instr);
      c3({tag," AS"},ALUSelectD,e.ALUSelectD,e.v_ALUSelectD,instr);
      c1({tag," SU"},SubArithD,e.SubArithD,e.v_SubArithD,instr);
      c1({tag," IL"},IllegalInstrD,e.IllegalInstrD,e.v_IllegalInstrD,instr);
    end
  endtask

  initial begin
    checks=0; failures=0; done=0; InstrD=32'h0;

    // Representative and boundary coverage
    apply(mk_r(7'b0000000,5'd3,5'd2,3'b000,5'd1,7'b0110011),"add");
    apply(mk_r(7'b0100000,5'd3,5'd2,3'b000,5'd1,7'b0110011),"sub");
    apply(mk_r(7'b0000000,5'd3,5'd2,3'b001,5'd1,7'b0110011),"sll");
    apply(mk_r(7'b0000000,5'd3,5'd2,3'b010,5'd1,7'b0110011),"slt");
    apply(mk_r(7'b0000000,5'd3,5'd2,3'b011,5'd1,7'b0110011),"sltu");
    apply(mk_r(7'b0000000,5'd3,5'd2,3'b100,5'd1,7'b0110011),"xor");
    apply(mk_r(7'b0000000,5'd3,5'd2,3'b101,5'd1,7'b0110011),"srl");
    apply(mk_r(7'b0100000,5'd3,5'd2,3'b101,5'd1,7'b0110011),"sra");
    apply(mk_r(7'b0000000,5'd3,5'd2,3'b110,5'd1,7'b0110011),"or");
    apply(mk_r(7'b0000000,5'd3,5'd2,3'b111,5'd1,7'b0110011),"and");
    apply(mk_r(7'b0100000,5'd3,5'd2,3'b010,5'd1,7'b0110011),"r_il_slt");
    apply(mk_r(7'b0000001,5'd3,5'd2,3'b000,5'd1,7'b0110011),"r_il_ext");

    apply(mk_i(12'h000,5'd2,3'b000,5'd1,7'b0010011),"addi0");
    apply(mk_i(12'h800,5'd0,3'b010,5'd31,7'b0010011),"slti_min");
    apply(mk_i(12'h7ff,5'd31,3'b011,5'd0,7'b0010011),"sltiu_max");
    apply(mk_i(12'h055,5'd2,3'b100,5'd1,7'b0010011),"xori");
    apply(mk_i({7'b0000000,5'd0},5'd2,3'b001,5'd1,7'b0010011),"slli0");
    apply(mk_i({7'b0000000,5'd31},5'd2,3'b001,5'd1,7'b0010011),"slli31");
    apply(mk_i({7'b0000000,5'd7},5'd2,3'b101,5'd1,7'b0010011),"srli");
    apply(mk_i({7'b0100000,5'd7},5'd2,3'b101,5'd1,7'b0010011),"srai");
    apply(mk_i(12'h0f0,5'd2,3'b110,5'd1,7'b0010011),"ori");
    apply(mk_i(12'hf0f,5'd2,3'b111,5'd1,7'b0010011),"andi");
    apply(mk_i({7'b0100000,5'd1},5'd2,3'b001,5'd1,7'b0010011),"i_il_slli");
    apply(mk_i({7'b0010000,5'd1},5'd2,3'b101,5'd1,7'b0010011),"i_il_shift");

    apply(mk_i(12'h000,5'd2,3'b000,5'd1,7'b0000011),"lb");
    apply(mk_i(12'h001,5'd2,3'b001,5'd1,7'b0000011),"lh");
    apply(mk_i(12'h7ff,5'd2,3'b010,5'd1,7'b0000011),"lw");
    apply(mk_i(12'h800,5'd2,3'b100,5'd1,7'b0000011),"lbu");
    apply(mk_i(12'h123,5'd2,3'b101,5'd1,7'b0000011),"lhu");
    apply(mk_i(12'h123,5'd2,3'b011,5'd1,7'b0000011),"load_il");

    apply(mk_s(12'h000,5'd1,5'd2,3'b000,7'b0100011),"sb");
    apply(mk_s(12'h7ff,5'd1,5'd2,3'b001,7'b0100011),"sh");
    apply(mk_s(12'h800,5'd1,5'd2,3'b010,7'b0100011),"sw");
    apply(mk_s(12'h001,5'd1,5'd2,3'b011,7'b0100011),"store_il");

    apply(mk_b(13'h0000,5'd2,5'd1,3'b000,7'b1100011),"beq");
    apply(mk_b(13'h0002,5'd2,5'd1,3'b001,7'b1100011),"bne");
    apply(mk_b(13'h1ffe,5'd2,5'd1,3'b100,7'b1100011),"blt");
    apply(mk_b(13'h1000,5'd2,5'd1,3'b101,7'b1100011),"bge");
    apply(mk_b(13'h0004,5'd2,5'd1,3'b110,7'b1100011),"bltu");
    apply(mk_b(13'h0006,5'd2,5'd1,3'b111,7'b1100011),"bgeu");
    apply(mk_b(13'h0000,5'd2,5'd1,3'b010,7'b1100011),"br_il2");
    apply(mk_b(13'h0000,5'd2,5'd1,3'b011,7'b1100011),"br_il3");

    apply(mk_u(20'h00000,5'd1,7'b0010111),"auipc0");
    apply(mk_u(20'hfffff,5'd31,7'b0010111),"auipcmax");
    apply(mk_u(20'h00000,5'd1,7'b0110111),"lui0");
    apply(mk_u(20'h80000,5'd31,7'b0110111),"luisign");
    apply(mk_i(12'h000,5'd2,3'b000,5'd1,7'b1100111),"jalr");
    apply(mk_i(12'h123,5'd2,3'b001,5'd1,7'b1100111),"jalr_il");
    apply(mk_j(21'h00000,5'd1,7'b1101111),"jal0");
    apply(mk_j(21'h100000,5'd0,7'b1101111),"jalmin");
    apply(mk_j(21'h0ffffe,5'd31,7'b1101111),"jalmax");

    // Unsupported/system/extension opcodes
    apply(32'h0000000f,"fence");
    apply(32'h0000100f,"fencei");
    apply(32'h00000073,"ecall");
    apply(32'h00100073,"ebreak");
    apply(32'h001110f3,"csr");
    apply(32'h0000007f,"badopc");

    done=1;
    $display("SUMMARY checks=%0d failures=%0d",checks,failures);
    if(checks>0 && failures==0) begin $display("PASS"); $finish; end
    else begin $display("FAIL"); $fatal(1,"verification failed"); end
  end

  initial begin
    #1000;
    if(!done) begin
      $display("FAIL");
      $fatal(1,"timeout");
    end
  end
endmodule
