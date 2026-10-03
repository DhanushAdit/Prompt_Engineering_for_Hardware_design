module datapath (
    input  logic        clk,
    input  logic        reset,
    input  logic [31:0] Instr,
    input  logic [31:0] ReadData,
    output logic [31:0] PC,
    output logic [31:0] DataAdr,
    output logic [31:0] WriteData,
    output logic [3:0]  ByteEnable,
    output logic        MemRead,
    output logic        MemWrite,
    output logic        IllegalInstr
);

logic [31:0] rd1, rd2;
logic [31:0] ImmExtD;
logic [31:0] SrcA, SrcB;
logic [31:0] ALUResult, Sum;
logic [31:0] PCTarget;
logic [31:0] PCPlus4;
logic [31:0] IEUResult;
logic [31:0] LoadData;
logic [31:0] WritebackData;

logic        RegWriteD;
logic [2:0]  ImmSrcD;
logic        ALUSrcAD;
logic        ALUSrcBD;
logic [3:0]  ALUSelectD;
logic        SubArithD;
logic        BranchD;
logic        JumpD;
logic [1:0]  MemRWD;
logic [2:0]  ResultSrcD;
logic        ALUResultSrcD;
logic        IllegalInstrD;
logic        PCSrc;

assign PCPlus4 = PC + 32'd4;

controller u_controller (
    .op(Instr[6:0]),
    .funct3(Instr[14:12]),
    .funct7b5(Instr[30]),
    .zero(ALUResult == 32'b0),
    .RegWriteD(RegWriteD),
    .ImmSrcD(ImmSrcD),
    .ALUSrcAD(ALUSrcAD),
    .ALUSrcBD(ALUSrcBD),
    .ALUSelectD(ALUSelectD),
    .SubArithD(SubArithD),
    .BranchD(BranchD),
    .JumpD(JumpD),
    .MemRWD(MemRWD),
    .ResultSrcD(ResultSrcD),
    .ALUResultSrcD(ALUResultSrcD),
    .IllegalInstrD(IllegalInstrD)
);

regfile u_regfile (
    .clk(clk),
    .we3(RegWriteD),
    .a1(Instr[19:15]),
    .a2(Instr[24:20]),
    .a3(Instr[11:7]),
    .wd3(WritebackData),
    .rd1(rd1),
    .rd2(rd2)
);

extend u_extend (
    .instr(Instr[31:7]),
    .immsrc(ImmSrcD),
    .immext(ImmExtD)
);

assign SrcA = ALUSrcAD ? PC : rd1;
assign SrcB = ALUSrcBD ? ImmExtD : rd2;

alu u_alu (
    .a(SrcA),
    .b(SrcB),
    .alucontrol(ALUSelectD),
    .sub(SubArithD),
    .result(ALUResult),
    .sum(Sum)
);

branch_unit u_branch_unit (
    .rs1(rd1),
    .rs2(rd2),
    .funct3(Instr[14:12]),
    .BranchD(BranchD),
    .JumpD(JumpD),
    .PCSrc(PCSrc)
);

assign PCTarget = ((Instr[6:0] == 7'b1100111) && JumpD) ? {Sum[31:1], 1'b0} : Sum;

pc_unit u_pc_unit (
    .clk(clk),
    .reset(reset),
    .PCSrc(PCSrc),
    .PCTarget(PCTarget),
    .PC(PC)
);

assign DataAdr = Sum;

memory_access u_memory_access (
    .MemRWD(MemRWD),
    .funct3(Instr[14:12]),
    .addr_low(DataAdr[1:0]),
    .store_data_in(rd2),
    .read_data_in(ReadData),
    .write_data_out(WriteData),
    .byte_enable(ByteEnable),
    .load_data_out(LoadData)
);

assign MemRead  = (MemRWD == 2'b10);
assign MemWrite = (MemRWD == 2'b01);

assign IEUResult = ALUResultSrcD ? (JumpD ? PCPlus4 : ImmExtD) : ALUResult;
assign WritebackData = (ResultSrcD == 3'b001) ? LoadData : IEUResult;

assign IllegalInstr = IllegalInstrD;

endmodule