module regfile (
    input  logic        clk,
    input  logic        reset,
    input  logic        we3,
    input  logic [4:0]  a1,
    input  logic [4:0]  a2,
    input  logic [4:0]  a3,
    input  logic [31:0] wd3,
    output logic [31:0] rd1,
    output logic [31:0] rd2
);

logic [31:0] rf [31:0];
int i;

always_ff @(negedge clk) begin
    if (reset) begin
        rf[0] <= 32'h0000_0000;
        for (i = 1; i < 32; i = i + 1) begin
            rf[i] <= 32'h0000_0000;
        end
    end else begin
        rf[0] <= 32'h0000_0000;
        if (we3 && (a3 != 5'd0)) begin
            rf[a3] <= wd3;
        end
    end
end

always_comb begin
    rd1 = 32'h0000_0000;
    rd2 = 32'h0000_0000;

    if (a1 != 5'd0) begin
        rd1 = rf[a1];
    end

    if (a2 != 5'd0) begin
        rd2 = rf[a2];
    end
end

endmodule
