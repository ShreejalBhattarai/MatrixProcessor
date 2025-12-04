
// Mark W. Welker
// HDL 4321 Spring 2023
// Matrix addition assignment top module
//
// Main memory MUST be allocated in the mainmemory module as per teh next line.
//  logic [255:0]MainMemory[12]; // this is the physical memory
//



module top ();

wire [255:0] DataBus;
logic nRead,nWrite,nReset,Clk;
logic [15:0] address;

logic Fail;

InstructionMemory  U1(Clk,DataBus, address, nRead,nReset);

MainMemory  U2(Clk,DataBus, address, nRead,nWrite, nReset);

Execution  U3(Clk,DataBus, address, nRead,nWrite, nReset);

MatrixAlu  U4(Clk,DataBus, address, nRead,nWrite, nReset);

IntegerAlu  U5(Clk,DataBus, address, nRead,nWrite, nReset);

TestMatrix  UTest(Clk,nReset);

  initial begin //. setup to allow waveforms for edaplayground
   $dumpfile("dump.vcd");
   $dumpvars(1);
    Fail = 0; // SETUP TO PASS TO START 
 end

always @(DataBus) begin // this block checks to make certain the proper data is in the memory.
		if (DataBus[31:0] == 32'hff000000)
// we are about to execute the stop
begin 
// Print out the entire contents of main memory so I can copy and paste.
			$display ( "memory location 0 = %h", U2.MainMemory[0]);
			$display ( "memory location 1 = %h", U2.MainMemory[1]);
			$display ( "memory location 2 = %h", U2.MainMemory[2]);
			$display ( "memory location 3 = %h", U2.MainMemory[3]);
			$display ( "memory location 4 = %h", U2.MainMemory[4]);
			$display ( "memory location 5 = %h", U2.MainMemory[5]);
			$display ( "memory location 6 = %h", U2.MainMemory[6]);
			$display ( "memory location 7 = %h", U2.MainMemory[7]);
			$display ( "memory location 8 = %h", U2.MainMemory[8]);
			$display ( "memory location 9 = %h", U2.MainMemory[9]);
			$display ( "memory location 10 = %h", U2.MainMemory[10]);
			$display ( "memory location 11 = %h", U2.MainMemory[11]);
			$display ( "memory location 12 = %h", U2.MainMemory[12]);
			$display ( "memory location 13 = %h", U2.MainMemory[13]);

			$display ( "Imternal Reg location 0 = %h", U3.InternalReg[0]);
			$display ( "Internal reg location 1 = %h", U3.InternalReg[1]);
			$display ( "Internal reg location 2 = %h", U3.InternalReg[2]);
			$display ( "Internal reg location 3 = %h", U3.InternalReg[3]);
			
		if (U2.MainMemory[0] == 256'h0009000c0008000d00080003000f0009000b001300100007000c0005000e0006)
			$display ( "memory location 0 is Correct");
		else begin Fail = 1; $display ( "memory location 0 is Wrong"); end
		if (U2.MainMemory[1] == 256'h0007000500070009000c0003000e000200100009000f0008000c000700040006)
			$display ( "memory location 1 is Correct");
		else begin Fail = 1;$display ( "memory location 1 is Wrong"); end
		if (U2.MainMemory[2] == 256'h00100011000f001600140006001d000b001b001c001f000f0018000c0012000c)
			$display ( "memory location 2 is Correct");
		else begin Fail = 1;$display ( "memory location 2 is Wrong"); end
		if (U2.MainMemory[3] == 256'h00240030002000340020000c003c0024002c004c0040001c0030001400380018)
			$display ( "memory location 3 is Correct");
		else begin Fail = 1;$display ( "memory location 3 is Wrong"); end
		if (U2.MainMemory[4] == 256'h001b00240018002700180009002d001b00210039003000150024000f002a0012)
			$display ( "memory location 4 is Correct");
		else begin Fail = 1;$display ( "memory location 4 is Wrong"); end
		if (U2.MainMemory[5] == 256'h00100014001b001800110006001c000c000f001d001f00120016000b000f000c)
			$display ( "memory location 5 is Correct");
		else begin Fail = 1;$display ( "memory location 5 is Wrong"); end
		if (U2.MainMemory[6] == 256'h08d607590bfa07bc070e08580a8c071a0a770a4110c20a20074108b20b9407e0)
			$display ( "memory location 6 is Correct");
		else begin Fail = 1;$display ( "memory location 6 is Wrong"); end
		if (U2.MainMemory[7] == 256'h0000000000000000000000000000000000000000000000000000000000000000)
			$display ( "memory location 7 is Correct");
		else begin Fail = 1;$display ( "memory location 7 is Wrong"); end
		if (U2.MainMemory[8] == 256'h0000000000000000000000000000000000000000000000000000000000000000)
			$display ( "memory location 8 is Correct");
		else begin Fail = 1;$display ( "memory location 8 is Wrong"); end
		if (U2.MainMemory[9] == 256'h0000000000000000000000000000000000000000000000000000000000000000)
			$display ( "memory location 9 is Correct");
		else begin Fail = 1;$display ( "memory location 9 is Wrong"); end
		if (U2.MainMemory[10][15:0] == 16'h0024)
			$display ( "memory location 10 is Correct");
		else begin Fail = 1;$display ( "memory location 10 is Wrong"); end
		if (U2.MainMemory[11][15:0] == 16'h000e)
			$display ( "memory location 11 is Correct");
		else begin Fail = 1;$display ( "memory location 11 is Wrong"); end
		if (U2.MainMemory[12][15:0] == 16'h0000)
			$display ( "memory location 12 is Correct");
		else begin Fail = 1;$display ( "memory location 12 is Wrong"); end


		if (U3.InternalReg[0][15:0] == 16'h0012)
			$display ( "Interal reg location 0 is Correct");
		else begin Fail = 1; $display ( "Internal Register 0 is Wrong"); end
		if (U3.InternalReg[1] == 256'h01200180010001a00100006001e0012001600260020000e0018000a001c000c0)
			$display ( "Internal Reg location 1 is Correct");
		else begin Fail = 1; $display ( "Internal Register 1 is Wrong"); end
		if (U3.InternalReg[2][15:0] == 16'h001e)
			$display ( "Internal Reg location 2 is Correct");
		else begin Fail = 1; $display ( "Internal Register 2 is Wrong"); end

        if (Fail) begin
        $display("********************************************");
        $display(" Project did not return the proper values");
        $display("********************************************");
        end
        else begin
        $display("********************************************");
        $display(" Project PASSED memory check");
        $display("********************************************");
        end
        
        end

end


endmodule


	
	

