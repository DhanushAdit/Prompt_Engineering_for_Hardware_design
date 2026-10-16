module student_assertions(
    input logic        clk,
    input logic        reset,
    // Decode-stage register read: source addresses and the values actually read from the register file.
    input logic [4:0]  Rs1D,
    input logic [4:0]  Rs2D,
    input logic [31:0] rd1D,
    input logic [31:0] rd2D,
    // Execute-stage forwarding selects + their source-register ids.
    input logic [1:0]  ForwardAE,   // 00 none / 10 from Memory stage / 01 from Writeback stage
    input logic [1:0]  ForwardBE,
    input logic [4:0]  Rs1E,
    input logic [4:0]  Rs2E,
    // In-flight producers that forwarding may source from (Memory and Writeback stages).
    input logic        RegWriteM,
    input logic [4:0]  RdM,
    input logic        RegWriteW,
    input logic [4:0]  RdW
);

    // ------------------------------------------------------------------
    // 1. x0 always reads as zero (both read ports, checked separately)
    // ------------------------------------------------------------------
    always @(posedge clk) if (!reset)
        assert (!(Rs1D == 5'd0) || (rd1D == 32'd0))
        else $display("ASSERT_FAIL x0_read_rs1_zero Rs1D=%0d rd1D=%h", Rs1D, rd1D);

    always @(posedge clk) if (!reset)
        assert (!(Rs2D == 5'd0) || (rd2D == 32'd0))
        else $display("ASSERT_FAIL x0_read_rs2_zero Rs2D=%0d rd2D=%h", Rs2D, rd2D);

    // ------------------------------------------------------------------
    // 2. Never forward into an x0 source operand
    // ------------------------------------------------------------------
    always @(posedge clk) if (!reset)
        assert (!(Rs1E == 5'd0) || (ForwardAE == 2'b00))
        else $display("ASSERT_FAIL no_forward_x0_rs1 Rs1E=%0d ForwardAE=%b", Rs1E, ForwardAE);

    always @(posedge clk) if (!reset)
        assert (!(Rs2E == 5'd0) || (ForwardBE == 2'b00))
        else $display("ASSERT_FAIL no_forward_x0_rs2 Rs2E=%0d ForwardBE=%b", Rs2E, ForwardBE);

    // ------------------------------------------------------------------
    // 3. No spurious forwarding: an active select implies a real producer
    // ------------------------------------------------------------------
    always @(posedge clk) if (!reset)
        assert (!(ForwardAE == 2'b10) ||
                (RegWriteM && (RdM == Rs1E) && (RdM != 5'd0)))
        else $display("ASSERT_FAIL forward_a_mem_has_producer Rs1E=%0d RdM=%0d RegWriteM=%b",
                      Rs1E, RdM, RegWriteM);

    always @(posedge clk) if (!reset)
        assert (!(ForwardAE == 2'b01) ||
                (RegWriteW && (RdW == Rs1E) && (RdW != 5'd0)))
        else $display("ASSERT_FAIL forward_a_wb_has_producer Rs1E=%0d RdW=%0d RegWriteW=%b",
                      Rs1E, RdW, RegWriteW);

    always @(posedge clk) if (!reset)
        assert (!(ForwardBE == 2'b10) ||
                (RegWriteM && (RdM == Rs2E) && (RdM != 5'd0)))
        else $display("ASSERT_FAIL forward_b_mem_has_producer Rs2E=%0d RdM=%0d RegWriteM=%b",
                      Rs2E, RdM, RegWriteM);

    always @(posedge clk) if (!reset)
        assert (!(ForwardBE == 2'b01) ||
                (RegWriteW && (RdW == Rs2E) && (RdW != 5'd0)))
        else $display("ASSERT_FAIL forward_b_wb_has_producer Rs2E=%0d RdW=%0d RegWriteW=%b",
                      Rs2E, RdW, RegWriteW);

endmodule
