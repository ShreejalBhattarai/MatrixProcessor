module Execution (
    input  logic         Clk,
    inout  logic [255:0] DataBus,    // shared bus (tri-state)
    output logic [15:0]  address,    // [15:12] = module id, [11:0] = slot/offset
    output logic         nRead,      // active-low read
    output logic         nWrite,     // active-low write
    input  logic         nReset
);
    `include "params.vh"

    // -----------------------------
    // Internal state / registers
    // -----------------------------
    logic [255:0] InternalReg[0:3];   // small internal register file (4 entries) 
    logic [255:0] resReg;             // result captured from ALU
    logic [255:0] source1;            // operand 1 (registered)
    logic [255:0] source2;            // operand 2 (registered)
    logic [255:0] next_source1, next_source2; // combinational-next values

    // Instruction (registered) and decoded fields
    logic [31:0] instruction;
    logic [7:0]  op_code;
    logic [7:0]  destRegByte;
    logic [3:0]  dest_index;
    logic [7:0]  src1RegByte;
    logic [3:0]  src1_index;
    logic [7:0]  src2RegByte;
    logic [3:0]  src2_index;

    // ExeDataOut: value Execution drives onto DataBus when performing a write
    logic [255:0] ExeDataOut_reg, next_ExeDataOut;

    // Program counter / instruction counter (registered)
    logic [15:0] instr_count;

    // FSM states
    typedef enum logic [3:0] {
        IF1, IF2, DEC, LD1, GETREG1, LD2, GETREG2,
        SEND_SRC1, SRC1_RCV, SEND_SRC2, SRC2_RCV,
        SEND_OP, EXE1, EXE2, WB1, WB2
    } state_t;

    state_t current_state, next_state;

    // Registered outputs (single driver) and next-state outputs
    logic [15:0] address_reg, next_address;
    logic         nRead_reg, next_nRead;
    logic         nWrite_reg, next_nWrite;

    // Tri-state driving done by comparing nWrite_reg (drive only when nWrite_reg == 0)
    wire drive_bus = (nWrite_reg == 1'b0);
    assign DataBus = drive_bus ? ExeDataOut_reg : 'hz;

    // Map registered outputs to module outputs (these are single-source)
    assign address = address_reg;
    assign nRead   = nRead_reg;
    assign nWrite  = nWrite_reg;

    // Combinational decode of the registered instruction
    always_comb begin
        op_code      = instruction[31:24];
        destRegByte  = instruction[23:16];
        dest_index   = destRegByte[3:0];
        src1RegByte  = instruction[15:8];
        src1_index   = src1RegByte[3:0];
        src2RegByte  = instruction[7:0];
        src2_index   = src2RegByte[3:0];
    end

    // -----------------------------
    // Sequential block: update state, register outputs, sample bus data
    // Single place updating address_reg, nRead_reg, nWrite_reg, ExeDataOut_reg
    // -----------------------------
    always_ff @(posedge Clk or negedge nReset) begin
        if (!nReset) begin
            // asynchronous reset values for registered outputs & internal storage
            instr_count     <= 16'h0;
            instruction     <= 32'h0;
            resReg          <= 256'h0;
            source1         <= 256'h0;
            source2         <= 256'h0;
            ExeDataOut_reg  <= 256'h0;
            address_reg     <= (ExecuteEn << 12);
            nRead_reg       <= 1'b1;
            nWrite_reg      <= 1'b1;
            current_state   <= IF1;
            next_state      <= IF1;
            for (int i = 0; i < 4; i = i + 1) InternalReg[i] <= 256'h0;
        end
        else begin
            // advance FSM state & commit outputs
            current_state <= next_state;
            address_reg    <= next_address;
            nRead_reg      <= next_nRead;
            nWrite_reg     <= next_nWrite;
            ExeDataOut_reg <= next_ExeDataOut;

            // default commit of next_source -> source (combinationally chosen earlier)
            source1 <= next_source1;
            source2 <= next_source2;

            // synchronous sampling of DataBus at states where data is valid on the bus
            case (current_state)
                IF2: begin
                    // instruction memory placed data on DataBus, sample low 32 bits
                    instruction <= DataBus[31:0];
                end

                GETREG1: begin
                    if (src1RegByte[7:4] == MainMemEn) begin
                        // only memory operands sample DataBus
                        source1 <= DataBus;
                    end
                end

                GETREG2: begin
                    if (src2RegByte[7:4] == MainMemEn) begin
                        source2 <= DataBus;
                    end
                end

                EXE2: begin
                    // sample ALU result placed on DataBus
                    resReg <= DataBus;
                end

                WB2: begin
                    // if destination is internal register file, commit value (we wrote it to the bus earlier)
                    if (destRegByte[7:4] == RegisterEn) begin
                        // dest_index should be valid [0..3] now that InternalReg is 4 entries
                        InternalReg[dest_index] <= ExeDataOut_reg;
                    end
                    // advance PC
                    instr_count <= instr_count + 1'b1;
                end

                default: begin
                    // nothing else to sample
                end
            endcase
        end
    end

    // -----------------------------
    // Combinational FSM + next-* outputs
    // Compute next_state and next_* values. Only this combinational block writes next_* signals.
    // -----------------------------
    always_comb begin
        // defaults (safe)
        next_state = current_state;
        next_nRead  = 1'b1;
        next_nWrite = 1'b1;
        next_address = (ExecuteEn << 12);
        next_ExeDataOut = 256'h0;

        // default next_source is to hold current registered source value
        next_source1 = source1;
        next_source2 = source2;

        // Normal operation only when not in reset
        if (nReset) begin
            case (current_state)
                // IF1: request instruction fetch
                IF1: begin
                    next_address = (InstrMemEn << 12) | (instr_count & 16'h0FFF);
                    next_nRead = 1'b0;   // assert read
                    next_nWrite = 1'b1;
                    next_state = IF2;
                end

                // IF2: return address to execute slot
                IF2: begin
                    next_address = (ExecuteEn << 12);
                    next_nRead = 1'b1;
                    next_nWrite = 1'b1;
                    next_state = DEC;
                end

                DEC: begin
                    if (op_code == Instruct13) begin
                        // Stop instruction - remain in DEC (or halt) for now
                        next_state = DEC;   
                    end else begin
                        // Otherwise continue normal flow
                        next_state = LD1;
                    end
                end 

                // LD1: decide source1 location
                LD1: begin
                    if (src1RegByte[7:4] == MainMemEn) begin
                        // read from main memory: place full 8-bit byte into the 12-bit offset
                        next_address = (MainMemEn << 12) | {4'h0, src1RegByte};
                        next_nRead = 1'b0;
                        next_nWrite = 1'b1;
                        next_state = GETREG1;
                    end
                    else if (src1RegByte[7:4] == RegisterEn) begin
                        // read from internal register file combinationally
                        next_source1 = InternalReg[src1_index];
                        next_nRead = 1'b1;
                        next_nWrite = 1'b1;
                        next_state = LD2;
                    end
                    else begin
                        // default treat as memory
                        next_address = (MainMemEn << 12) | {4'h0, src1RegByte};
                        next_nRead = 1'b0;
                        next_nWrite = 1'b1;
                        next_state = GETREG1;
                    end
                end

                // GETREG1: return to execute slot; source1 will be sampled on next clock (sequentially)
                GETREG1: begin
                    next_address = (ExecuteEn << 12);
                    next_nRead = 1'b1;
                    next_nWrite = 1'b1;
                    next_state = LD2;
                end

                // LD2: decide source2 location
                LD2: begin
                    if (src2RegByte[7:4] == MainMemEn) begin
                        next_address = (MainMemEn << 12) | {4'h0, src2RegByte};
                        next_nRead = 1'b0;
                        next_nWrite = 1'b1;
                        next_state = GETREG2;
                    end
                    else if (src2RegByte[7:4] == RegisterEn) begin
                        next_source2 = InternalReg[src2_index];
                        next_nRead = 1'b1;
                        next_nWrite = 1'b1;
                        next_state = SEND_SRC1;
                    end
                    else begin
                        next_address = (MainMemEn << 12) | {4'h0, src2RegByte};
                        next_nRead = 1'b0;
                        next_nWrite = 1'b1;
                        next_state = GETREG2;
                    end
                end

                // GETREG2: return to execute slot; source2 sampled on next clock
                GETREG2: begin
                    next_address = (ExecuteEn << 12);
                    next_nRead = 1'b1;
                    next_nWrite = 1'b1;
                    next_state = SEND_SRC1;
                end

                // SEND_SRC1: send source1 to selected ALU
                SEND_SRC1: begin
                    logic [3:0] alu_sel;
                    alu_sel = (op_code[7:4] == 4'h0) ? AluEn : IntAlu;
                    next_address = (alu_sel << 12) | ALU_Source1;

                    if (alu_sel == AluEn) next_ExeDataOut = source1;
                    else                  next_ExeDataOut = {240'h0, source1[15:0]};

                    next_nWrite = 1'b0;
                    next_nRead  = 1'b1;
                    next_state = SRC1_RCV;
                end

                // SRC1_RCV: release bus
                SRC1_RCV: begin
                    next_address = (ExecuteEn << 12);
                    next_nWrite = 1'b1;
                    next_nRead  = 1'b1;
                    next_state = SEND_SRC2;
                end

                // SEND_SRC2: send source2 to ALU
                SEND_SRC2: begin
                    logic [3:0] alu_sel2;
                    alu_sel2 = (op_code[7:4] == 4'h0) ? AluEn : IntAlu;
                    next_address = (alu_sel2 << 12) | ALU_Source2;

                    if (alu_sel2 == AluEn) next_ExeDataOut = source2;
                    else                    next_ExeDataOut = {240'h0, source2[15:0]};

                    next_nWrite = 1'b0;
                    next_nRead  = 1'b1;
                    next_state = SRC2_RCV;
                end

                // SRC2_RCV: release bus
                SRC2_RCV: begin
                    next_address = (ExecuteEn << 12);
                    next_nWrite = 1'b1;
                    next_nRead  = 1'b1;
                    next_state = SEND_OP;
                end

                // SEND_OP: write opcode to ALU control slot
                SEND_OP: begin
                    logic [3:0] alu_sel3;
                    alu_sel3 = (op_code[7:4] == 4'h0) ? AluEn : IntAlu;
                    next_address = (alu_sel3 << 12) | ALU_Result;
                    next_ExeDataOut = {248'h0, op_code};
                    next_nWrite = 1'b0;
                    next_nRead  = 1'b1;
                    next_state = EXE1;
                end

                // EXE1: prepare to read result
                EXE1: begin
                    logic [3:0] alu_sel4;
                    alu_sel4 = (op_code[7:4] == 4'h0) ? AluEn : IntAlu;
                    next_address = (alu_sel4 << 12) | ALU_Result;
                    next_nRead = 1'b0;
                    next_nWrite = 1'b1;
                    next_state = EXE2;
                end

                // EXE2: result will be sampled on next clock
                EXE2: begin
                    next_nRead = 1'b1;
                    next_nWrite = 1'b1;
                    next_state = WB1;
                end

                // WB1: writeback result to destination
                WB1: begin
                    if (destRegByte[7:4] == MainMemEn) begin
                        next_address = (MainMemEn << 12) | {4'h0, destRegByte};
                        next_ExeDataOut = resReg;
                        next_nWrite = 1'b0;
                        next_nRead  = 1'b1;
                        next_state = WB2;
                    end
                    else if (destRegByte[7:4] == RegisterEn) begin
                        // write to register file slot (low 4 bits are the index) - extend to 12 bits
                        next_address = (RegisterEn << 12) | {8'h0, dest_index};
                        next_ExeDataOut = resReg;
                        next_nWrite = 1'b0;
                        next_nRead  = 1'b1;
                        next_state = WB2;
                    end
                    else begin
                        next_address = (MainMemEn << 12) | {4'h0, destRegByte};
                        next_ExeDataOut = resReg;
                        next_nWrite = 1'b0;
                        next_nRead  = 1'b1;
                        next_state = WB2;
                    end
                end

                // WB2: finalize writeback
                WB2: begin
                    next_nWrite = 1'b1;
                    next_nRead  = 1'b1;
                    next_address = (ExecuteEn << 12);
                    next_state = IF1;
                end

                default: begin
                    next_state = IF1;
                    next_nRead = 1'b1;
                    next_nWrite = 1'b1;
                    next_address = (ExecuteEn << 12);
                end
            endcase
        end
        else begin
            // if reset low: safe defaults (this 'else' is the reset==0 path)
            next_state = IF1;
            next_nRead = 1'b1;
            next_nWrite = 1'b1;
            next_address = (ExecuteEn << 12);
            next_ExeDataOut = 256'h0;
            // keep next_source as zeros on reset
            next_source1 = 256'h0;
            next_source2 = 256'h0;
        end
    end

endmodule
