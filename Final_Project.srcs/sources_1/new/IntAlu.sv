module IntegerAlu (
    input  logic         Clk,
    inout  logic [255:0] DataBus,
    input  logic [15:0]  address,
    input  logic         nRead,
    input  logic         nWrite,
    input  logic         nReset
);
    `include "params.vh"

    logic [255:0] int_registers[0:5];

    // Drive DataBus only when this module is selected and a READ (!) is requested
    wire drive_bus = (address[15:12] == IntAlu) && (!nRead);

    // When driving, present ALU_Result register on the shared bus
    assign DataBus = drive_bus ? int_registers[ALU_Result] : 'hz;

    always_ff @(negedge Clk or negedge nReset) begin
        if (!nReset) begin
            for (int i = 0; i < 6; i = i + 1) int_registers[i] <= 256'h0;
        end
        else begin
            // Respond only when this module is addressed
            if (address[15:12] == IntAlu) begin
                // WRITE path: host drives DataBus into the ALU internal slots
                if (!nWrite) begin
                    case (address[11:0])
                        ALU_Source1: begin
                            int_registers[ALU_Source1] <= DataBus;
                        end
                        ALU_Source2: begin
                            int_registers[ALU_Source2] <= DataBus;
                        end
                        ALU_Result: begin
                            // DataBus[7:0] holds opcode; operate on the already-stored SRC1/SRC2
                            unique case (DataBus[7:0])
                                Iadd:  int_registers[ALU_Result] <= int_registers[ALU_Source1] + int_registers[ALU_Source2];
                                Isub:  int_registers[ALU_Result] <= int_registers[ALU_Source1] - int_registers[ALU_Source2];
                                Imult: int_registers[ALU_Result] <= int_registers[ALU_Source1] * int_registers[ALU_Source2];
                                Idiv:  int_registers[ALU_Result] <= int_registers[ALU_Source1] / int_registers[ALU_Source2];
                                default: ; // no-op for unknown opcodes
                            endcase
                        end
                        default: ; // ignore other low-addresses
                    endcase
                end
                // READ path is handled by the continuous assign (tri-state) above
            end
        end
    end
endmodule
