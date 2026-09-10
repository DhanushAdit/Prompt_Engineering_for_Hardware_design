module alu (
    input  logic [31:0] A,
    input  logic [31:0] B,
    input  logic [2:0]  ALUSelect,
    input  logic        SubArith,
    output logic [31:0] ALUResult,
    output logic [31:0] Sum
);

    always_comb begin
        if (SubArith) begin
            Sum = A - B;
        end else begin
            Sum = A + B;
        end

        unique case (ALUSelect)
            3'b000: ALUResult = Sum;
            3'b001: ALUResult = A << B[4:0];
            3'b010: ALUResult = ($signed(A) < $signed(B)) ? 32'h00000001 : 32'h00000000;
            3'b011: ALUResult = (A < B) ? 32'h00000001 : 32'h00000000;
            3'b100: ALUResult = A ^ B;
            3'b101: ALUResult = SubArith ? ($signed(A) >>> B[4:0]) : (A >> B[4:0]);
            3'b110: ALUResult = A | B;
            3'b111: ALUResult = A & B;
            default: ALUResult = 32'h00000000;
        endcase
    end

endmodule
