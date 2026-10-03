module memory_access (
    input  logic [1:0]  MemRW,
    input  logic [2:0]  Funct3,
    input  logic [1:0]  AddrLSB,
    input  logic [31:0] StoreData,
    input  logic [31:0] ReadData,
    output logic [31:0] WriteData,
    output logic [3:0]  ByteEnable,
    output logic [31:0] LoadData
);

always @* begin
    WriteData  = 32'b0;
    ByteEnable = 4'b0000;
    LoadData   = 32'b0;

    case (MemRW)
        2'b01: begin
            case (Funct3)
                3'b000: begin
                    case (AddrLSB)
                        2'b00: begin
                            ByteEnable = 4'b0001;
                            WriteData  = {24'b0, StoreData[7:0]};
                        end
                        2'b01: begin
                            ByteEnable = 4'b0010;
                            WriteData  = {16'b0, StoreData[7:0], 8'b0};
                        end
                        2'b10: begin
                            ByteEnable = 4'b0100;
                            WriteData  = {8'b0, StoreData[7:0], 16'b0};
                        end
                        default: begin
                            ByteEnable = 4'b1000;
                            WriteData  = {StoreData[7:0], 24'b0};
                        end
                    endcase
                end
                3'b001: begin
                    case (AddrLSB[1])
                        1'b0: begin
                            ByteEnable = 4'b0011;
                            WriteData  = {16'b0, StoreData[15:0]};
                        end
                        default: begin
                            ByteEnable = 4'b1100;
                            WriteData  = {StoreData[15:0], 16'b0};
                        end
                    endcase
                end
                3'b010: begin
                    ByteEnable = 4'b1111;
                    WriteData  = StoreData;
                end
                default: begin
                    WriteData  = 32'b0;
                    ByteEnable = 4'b0000;
                end
            endcase
        end

        2'b10: begin
            case (Funct3)
                3'b000: begin
                    case (AddrLSB)
                        2'b00: LoadData = {{24{ReadData[7]}},   ReadData[7:0]};
                        2'b01: LoadData = {{24{ReadData[15]}},  ReadData[15:8]};
                        2'b10: LoadData = {{24{ReadData[23]}},  ReadData[23:16]};
                        default: LoadData = {{24{ReadData[31]}}, ReadData[31:24]};
                    endcase
                end
                3'b001: begin
                    case (AddrLSB[1])
                        1'b0: LoadData = {{16{ReadData[15]}}, ReadData[15:0]};
                        default: LoadData = {{16{ReadData[31]}}, ReadData[31:16]};
                    endcase
                end
                3'b010: begin
                    LoadData = ReadData;
                end
                3'b100: begin
                    case (AddrLSB)
                        2'b00: LoadData = {24'b0, ReadData[7:0]};
                        2'b01: LoadData = {24'b0, ReadData[15:8]};
                        2'b10: LoadData = {24'b0, ReadData[23:16]};
                        default: LoadData = {24'b0, ReadData[31:24]};
                    endcase
                end
                3'b101: begin
                    case (AddrLSB[1])
                        1'b0: LoadData = {16'b0, ReadData[15:0]};
                        default: LoadData = {16'b0, ReadData[31:16]};
                    endcase
                end
                default: begin
                    LoadData = 32'b0;
                end
            endcase
        end

        default: begin
            WriteData  = 32'b0;
            ByteEnable = 4'b0000;
            LoadData   = 32'b0;
        end
    endcase
end

endmodule