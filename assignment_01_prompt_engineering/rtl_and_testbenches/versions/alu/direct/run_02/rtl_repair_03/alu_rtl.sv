module alu (
    input  logic [31:0] A,
    input  logic [31:0] B,
    input  logic [2:0]  ALUSelect,
    input  logic        SubArith,
    output logic [31:0] ALUResult,
    output logic [31:0] Sum
);

    logic [4:0] shamt;
    logic signed [31:0] A_signed;

    assign shamt = B[4:0];
    assign A_signed = A;
    assign Sum = SubArith ? (A - B) : (A + B);

    always_comb begin
        ALUResult = 32'h0000_0000;
        case (ALUSelect)
            3'b000: ALUResult = Sum;
            3'b001: ALUResult = A << shamt;
            3'b010: ALUResult = SubArith ? (($signed(A) < $signed(B)) ? 32'h0000_0001 : 32'h0000_0000) : 32'h0000_0000;
            3'b011: ALUResult = SubArith ? ((A < B) ? 32'h0000_0001 : 32'h0000_0000) : 32'h0000_0000;
            3'b100: ALUResult = A ^ B;
            3'b101: ALUResult = SubArith ? (A_signed >>> shamt) : (A >> shamt);
            3'b110: ALUResult = A | B;
            3'b111: ALUResult = A & B;
            default: ALUResult = 32'h0000_0000;
        endcase
    end

endmodule
