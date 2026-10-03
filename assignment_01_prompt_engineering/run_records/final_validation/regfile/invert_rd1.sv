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
logic [31:0] observed_rd1;
logic [31:0] observed_rd2;
mutation_core core(.clk(clk), .reset(reset), .we3(we3), .a1(a1), .a2(a2), .a3(a3), .wd3(wd3), .rd1(observed_rd1), .rd2(observed_rd2));
assign rd1 = observed_rd1 ^ 1;
assign rd2 = observed_rd2;
endmodule
module mutation_core (
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
    integer i;

    always_ff @(negedge clk) begin
        if (reset) begin
            for (i = 1; i < 32; i = i + 1)
                rf[i] <= 32'h00000000;
            rf[0] <= 32'h00000000;
        end else begin
            rf[0] <= 32'h00000000;
            if (we3 && (a3 != 5'd0))
                rf[a3] <= wd3;
        end
    end

    always_comb begin
        if (a1 == 5'd0)
            rd1 = 32'h00000000;
        else
            rd1 = rf[a1];

        if (a2 == 5'd0)
            rd2 = 32'h00000000;
        else
            rd2 = rf[a2];
    end
endmodule
