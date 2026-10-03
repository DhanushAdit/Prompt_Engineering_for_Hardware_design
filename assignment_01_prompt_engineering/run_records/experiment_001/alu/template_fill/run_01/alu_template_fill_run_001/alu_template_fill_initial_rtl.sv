module alu (
    input  logic [31:0] A,
    input  logic [31:0] B,
    input  logic [2:0]  ALUSelect,
    input  logic        SubArith,
    output logic [31:0] ALUResult,
    output logic [31:0] Sum
);
    logic signed [31:0] A_signed;
    logic signed [31:0] B_signed;

    assign A_signed = A;
    assign B_signed = B;

    always_comb begin
        Sum = SubArith ? (A - B) : (A + B);

        unique case (ALUSelect)
            3'b000: ALUResult = Sum;
            3'b001: ALUResult = A << B[4:0];
            3'b010: ALUResult = (A_signed < B_signed) ? 32'h00000001 : 32'h00000000;
            3'b011: ALUResult = (A < B) ? 32'h00000001 : 32'h00000000;
            3'b100: ALUResult = A ^ B;
            3'b101: ALUResult = SubArith ? (A_signed >>> B[4:0]) : (A >> B[4:0]);
            3'b110: ALUResult = A | B;
            3'b111: ALUResult = A & B;
            default: ALUResult = 32'h00000000;
        endcase
    end
endmodule
