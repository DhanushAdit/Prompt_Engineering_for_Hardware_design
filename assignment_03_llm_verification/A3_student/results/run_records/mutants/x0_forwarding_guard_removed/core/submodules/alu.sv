module alu (
    input  logic [31:0] A,
    input  logic [31:0] B,
    input  logic [2:0]  ALUSelect,
    input  logic        SubArith,
    output logic [31:0] ALUResult,
    output logic [31:0] Sum
);

assign Sum = SubArith ? (A - B) : (A + B);

always_comb begin
    ALUResult = 32'h0000_0000;

    unique case (ALUSelect)
        3'b000: begin
            ALUResult = Sum;
        end
        3'b001: begin
            if (SubArith == 1'b0) begin
                ALUResult = A << B[4:0];
            end else begin
                ALUResult = 32'h0000_0000;
            end
        end
        3'b010: begin
            if (SubArith == 1'b1) begin
                ALUResult = ($signed(A) < $signed(B)) ? 32'h0000_0001 : 32'h0000_0000;
            end else begin
                ALUResult = 32'h0000_0000;
            end
        end
        3'b011: begin
            if (SubArith == 1'b1) begin
                ALUResult = (A < B) ? 32'h0000_0001 : 32'h0000_0000;
            end else begin
                ALUResult = 32'h0000_0000;
            end
        end
        3'b100: begin
            if (SubArith == 1'b0) begin
                ALUResult = A ^ B;
            end else begin
                ALUResult = 32'h0000_0000;
            end
        end
        3'b101: begin
            if (SubArith == 1'b0) begin
                ALUResult = A >> B[4:0];
            end else begin
                ALUResult = $signed(A) >>> B[4:0];
            end
        end
        3'b110: begin
            if (SubArith == 1'b0) begin
                ALUResult = A | B;
            end else begin
                ALUResult = 32'h0000_0000;
            end
        end
        3'b111: begin
            if (SubArith == 1'b0) begin
                ALUResult = A & B;
            end else begin
                ALUResult = 32'h0000_0000;
            end
        end
        default: begin
            ALUResult = 32'h0000_0000;
        end
    endcase
end

endmodule
