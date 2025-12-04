module MatrixAlu (
    input  logic         Clk,
    inout  logic [255:0] DataBus,
    input  logic [15:0]  address,
    input  logic         nRead,
    input  logic         nWrite,
    input  logic         nReset
);
    `include "params.vh"

    // Internal 4x4 matrices (16-bit entries)
    logic [15:0] matrix_src1[3:0][3:0];
    logic [15:0] matrix_src2[3:0][3:0];
    logic [15:0] matrix_result[3:0][3:0];
    logic [15:0] immediate_val;

    // Packed view of the last computed result for driving the bus
    logic [255:0] packed_result;

    // Drive DataBus only when this module is selected and READ is requested
    wire drive_bus = (address[15:12] == AluEn) && (!nRead);
    assign DataBus = drive_bus ? packed_result : 'hz;

    // reset and functional behavior on negedge (match original style)
    always_ff @(negedge Clk or negedge nReset) begin
        if (!nReset) begin
            immediate_val <= 16'h0;
            packed_result <= 256'h0;
            for (int i=0; i<4; i=i+1)
                for (int j=0; j<4; j=j+1) begin
                    matrix_src1[i][j]  <= 16'h0;
                    matrix_src2[i][j]  <= 16'h0;
                    matrix_result[i][j] <= 16'h0;
                end
        end
        else begin
            // WRITE path: when CPU/Execution writes to this module
            if ((address[15:12] == AluEn) && (!nWrite)) begin
                case (address[11:0])
                    ALU_Source1: begin
                        // unpack 16-bit words from DataBus into src1 matrix
                        for (int i=0; i<4; i=i+1)
                            for (int j=0; j<4; j=j+1) begin
                                int bit_start = (i*4 + j) * 16;
                                matrix_src1[i][j] <= DataBus[bit_start +: 16];
                            end
                    end
                    ALU_Source2: begin
                        immediate_val <= DataBus[15:0];
                        for (int i=0; i<4; i=i+1)
                            for (int j=0; j<4; j=j+1) begin
                                int bit_start = (i*4 + j) * 16;
                                matrix_src2[i][j] <= DataBus[bit_start +: 16];
                            end
                    end
                    ALU_Result: begin
                        // opcode is in low 8 bits of DataBus
                        logic [7:0] op = DataBus[7:0];

                        // compute matrix_result according to opcode
                        unique case (op)
                            MMult1: begin
                                for (int i=0; i<4; i=i+1) begin
                                    for (int j=0; j<4; j=j+1) begin
                                        logic [31:0] acc = 32'h0;
                                        for (int k=0; k<4; k=k+1)
                                            acc += (matrix_src1[i][k] * matrix_src2[k][j]);
                                        matrix_result[i][j] <= acc[15:0];
                                    end
                                end
                            end
                            MMult2: begin // same as MMult2a in your mapping

                                for (int i=0; i<4; i=i+1) begin
                                    for (int j=0; j<4; j=j+1) begin
                                        logic [31:0] acc = 32'h0;
                                        for (int k=0; k<2; k=k+1)
                                            acc += (matrix_src1[i][k] * matrix_src2[k][j]);
                                        matrix_result[i][j] <= acc[15:0];
                                    end
                                end
                            end
                            MMult3: begin // your small mode variant
                                // compute only 2x2 useful region
                                for (int i=0; i<2; i=i+1) begin
                                    for (int j=0; j<2; j=j+1) begin
                                        logic [31:0] acc = 32'h0;
                                        for (int k=0; k<4; k=k+1)
                                            acc += (matrix_src1[i][k] * matrix_src2[k][j]);
                                        matrix_result[i][j] <= acc[15:0];
                                    end
                                end
                            end
                            MAdd: begin
                                for (int i=0; i<4; i=i+1)
                                    for (int j=0; j<4; j=j+1)
                                        matrix_result[i][j] <= matrix_src1[i][j] + matrix_src2[i][j];
                            end
                            MSub: begin
                                for (int i=0; i<4; i=i+1)
                                    for (int j=0; j<4; j=j+1)
                                        matrix_result[i][j] <= matrix_src1[i][j] - matrix_src2[i][j];
                            end
                            MTranspose: begin
                                for (int i=0; i<4; i=i+1)
                                    for (int j=0; j<4; j=j+1)
                                        matrix_result[i][j] <= matrix_src1[j][i];
                            end
                            MScaleImm: begin
                                for (int i=0; i<4; i=i+1)
                                    for (int j=0; j<4; j=j+1)
                                        matrix_result[i][j] <= matrix_src1[i][j] * immediate_val;
                            end
                            default: begin
                                // unknown op: no change
                            end
                        endcase
                    end
                    default: ; // ignore other writes
                endcase
            end

            // READ path: when the module is read, build the packed_result (done each cycle)
            // build packed_result from matrix_result and small_result_mode
            packed_result <= 256'h0;
        end
    end
endmodule
