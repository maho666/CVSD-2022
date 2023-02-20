`timescale 1ns/100ps
`define CYCLE       10.0
`define HCYCLE      (`CYCLE/2)
`define MAX_CYCLE   120000

`ifdef p0
    `define Inst "../00_TESTBED/PATTERN/p0/inst.dat"
`elsif p1
	`define Inst "../00_TESTBED/PATTERN/p1/inst.dat"
`endif

module testbed;


//========== System Signals ==========//
	reg clk;
	reg rst_n;
	integer cycle_count, i, j;
	integer status_error, data_error;

//========== CPU Signals ==========//
// CPU input
	wire [ 31 : 0 ] imem_inst;
	wire [ 31 : 0 ] dmem_rdata;
// CPU output
	wire [ 31 : 0 ] imem_addr;
	wire            dmem_wen;
	wire [ 31 : 0 ] dmem_addr;
	wire [ 31 : 0 ] dmem_wdata;
	wire [  1 : 0 ] mips_status;
	wire            mips_status_valid;

//========== Module Instantiation ==========//

	initial $readmemb (`Inst, u_inst_mem.mem_r);

	core u_core (
		.i_clk(clk),
		.i_rst_n(rst_n),
		.o_i_addr(imem_addr),
		.i_i_inst(imem_inst),
		.o_d_wen(dmem_wen),
		.o_d_addr(dmem_addr),
		.o_d_wdata(dmem_wdata),
		.i_d_rdata(dmem_rdata),
		.o_status(mips_status),
		.o_status_valid(mips_status_valid)
	);

	inst_mem  u_inst_mem (
		.i_clk(clk),
		.i_rst_n(rst_n),
		.i_addr(imem_addr),
		.o_inst(imem_inst)
	);

	data_mem  u_data_mem (
		.i_clk(clk),
		.i_rst_n(rst_n),
		.i_wen(dmem_wen),
		.i_addr(dmem_addr),
		.i_wdata(dmem_wdata),
		.o_rdata(dmem_rdata)
	);

//========== Load data ==========//
	reg [31:0] golden_data [0:63];
	`ifdef p0
		reg [1:0] golden_status [0:70];
		initial begin
			$readmemb("../00_TESTBED/PATTERN/p0/status.dat",golden_status);
			$readmemb("../00_TESTBED/PATTERN/p0/data.dat",golden_data);
		end
	`elsif p1
		reg [1:0] golden_status [0:10];
		initial begin
		$readmemb("../00_TESTBED/PATTERN/p1/status.dat",golden_status);
		$readmemb("../00_TESTBED/PATTERN/p1/data.dat",golden_data);
		end
	`endif
//========== System Reset ==========//
	reg start;
	initial begin
		rst_n = 1;
		clk = 0;
		start = 0;
		cycle_count = 0;
		i = 0;
		status_error = 0;
		data_error = 0;
	end

//========== clock generation ==========//
	always # (`HCYCLE) clk = ~clk;
	initial begin
		# (`MAX_CYCLE * `CYCLE);
		$display("----------------------------------------------");
		$display("Latency of your design is over 120000 cycles!!");
		$display("----------------------------------------------");
		$finish;
	end

//========== cycle count ==========//
	always@(posedge clk) begin
		if(start)
			cycle_count <= cycle_count + 1;
	end

//========== waveform ==========//
	initial begin
		$fsdbDumpfile("hw2.fsdb");
		$fsdbDumpvars(0, "+mda");
	end

//========== Simulation ==========//
	initial begin
		# (0.25 * `CYCLE);
		$display("Reset System");
		rst_n = 0; 
		# (4 * `CYCLE);
		@(negedge clk);
		rst_n = 1;
		$display("Compute Start");
		start = 1;
	end

	always@(negedge clk) begin
		if(mips_status_valid == 1) begin
			if(mips_status != golden_status[i]) begin
				$display("MIPS Status ERROR!  Status[ %d ]: Golden = %b, Yours = %b", i, golden_status[i], mips_status);
				status_error = status_error + 1;
			end
			// else $display("MIPS Status RIGHT!  Status[ %d ]: Golden = %b, Yours = %b", i, golden_status[i], mips_status);
			i = i + 1;
			if(mips_status == `MIPS_OVERFLOW || mips_status == `MIPS_END) begin
				start = 0;
				$display("Status has   %d   ERRORs.",status_error);
				$display("Start to check the data memory");
				for(j=0; j<64; j=j+1) begin
					if(u_data_mem.mem_r[j] != golden_data[j]) begin
						$display("ERROR! Data[ %d ]: Golden = %b, Yours = %b", j, golden_data[j],  u_data_mem.mem_r[j]);
						data_error = data_error + 1;
					end
					// else $display("RIGHT! Data[ %d ]: Golden = %b, Yours = %b", j, golden_data[j],  u_data_mem.mem_r[j]);
				end
				$display("data has   %d   ERRORs.",data_error);
				if((data_error == 0) && (status_error == 0)) begin
					$display("\n");
          			$display("====================== The test result is ..... PASS ========================");
          			$display("\n");
          			$display("        *************************************************            ");
          			$display("        **                                             **      /|____|\\");
          			$display("        **             Congratulations !!              **    ((Â´-___- `))");
          			$display("        **                                             **   ///        \\\\\\");
          			$display("        **  All data have been generated successfully! **  /||          ||\\");
          			$display("        **                                             **  w|\\ m      m /|w");
          			$display("        *************************************************    \\(o)____(o)/");
          			$display("\n");
          			$display("============================================================================");
				end
				$display("End of Process, total cycle = %d",cycle_count);
				$finish;
			end
		end
	end
endmodule



