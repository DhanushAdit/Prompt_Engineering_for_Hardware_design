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

logic [31:0] rd1;
logic [31:0] rd2;
logic [31:0] ImmExtD;

logic [31:0] ALUA;
logic [31:0] ALUB;
logic [31:0] ALUResult;
logic [31:0] Sum;

logic        BranchCond;
logic        PCSrc;
logic [31:0] PCPlus4;
logic [31:0] PCTarget;

logic [31:0] IEUResult;
logic [31:0] LoadData;
logic [31:0] WritebackData;

controller controller_inst (
    .InstrD(Instr),
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

regfile regfile_inst (
    .clk(clk),
    .a1(Instr[19:15]),
    .a2(Instr[24:20]),
    .a3(Instr[11:7]),
    .wd3(WritebackData),
    .we3(RegWriteD),
    .rd1(rd1),
    .rd2(rd2)
);

extend extend_inst (
    .InstrD(Instr[31:7]),
    .ImmSrcD(ImmSrcD),
    .ImmExtD(ImmExtD)
);

assign ALUA = ALUSrcAD ? PC : rd1;
assign ALUB = ALUSrcBD ? ImmExtD : rd2;

alu alu_inst (
    .A(ALUA),
    .B(ALUB),
    .ALUSelect(ALUSelectD),
    .SubArith(SubArithD),
    .ALUResult(ALUResult),
    .Sum(Sum)
);

branch_unit branch_unit_inst (
    .A(rd1),
    .B(rd2),
    .Funct3(Instr[14:12]),
    .Branch(BranchD),
    .Jump(JumpD),
    .BranchCond(BranchCond),
    .PCSrc(PCSrc)
);

assign PCTarget = (JumpD && (Instr[6:0] == 7'b1100111)) ? {Sum[31:1], 1'b0} : Sum;

pc_unit pc_unit_inst (
    .clk(clk),
    .reset(reset),
    .PCSrc(PCSrc),
    .PCTarget(PCTarget),
    .PC(PC),
    .PCPlus4(PCPlus4)
);

assign IEUResult = ALUResultSrcD ? (JumpD ? PCPlus4 : ImmExtD) : ALUResult;
assign DataAdr = Sum;

memory_access memory_access_inst (
    .MemRW(MemRWD),
    .Funct3(Instr[14:12]),
    .AddrLSB(Sum[1:0]),
    .StoreData(rd2),
    .ReadData(ReadData),
    .WriteData(WriteData),
    .ByteEnable(ByteEnable),
    .LoadData(LoadData)
);

assign MemRead = (MemRWD == 2'b10);
assign MemWrite = (MemRWD == 2'b01);
assign WritebackData = (ResultSrcD == 3'b001) ? LoadData : IEUResult;
assign IllegalInstr = IllegalInstrD;

endmodule