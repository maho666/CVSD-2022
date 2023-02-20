module core #(                             //Don't modify interface
	parameter ADDR_W = 32,
	parameter INST_W = 32,
	parameter DATA_W = 32
)(
	input                   i_clk,
	input                   i_rst_n,
	output [ ADDR_W-1 : 0 ] o_i_addr,
	input  [ INST_W-1 : 0 ] i_i_inst,
	output                  o_d_wen,
	output [ ADDR_W-1 : 0 ] o_d_addr,
	output [ DATA_W-1 : 0 ] o_d_wdata,
	input  [ DATA_W-1 : 0 ] i_d_rdata,
	output [        1 : 0 ] o_status,
	output                  o_status_valid
);

parameter IDLE		 = 3'd0; 
parameter INST_FETCH = 3'd1;
parameter INST_DE 	 = 3'd2;
parameter ALU_COM 	 = 3'd3;
//parameter MEM		 = 3'd4;
parameter DATA_WR 	 = 3'd4;
parameter NEXT_GEN 	 = 3'd5;
parameter FIN 		 = 3'd6;

// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------
// ---- Add your own wires and registers here if needed ---- //
/////////////////
wire [5:0]inst_op;
reg [DATA_W-1 : 0] inst_all;
reg [4:0] data_r_1,data_r_2,data_r_ans;
wire alu_ovflw,alu_bran;
wire [ DATA_W-1 : 0 ] alu_result;

reg [2:0] stt_c,stt_n;
reg	[ ADDR_W-1 : 0 ] o_i_addr_w, o_i_addr_r;
reg					 o_d_wen_w, o_d_wen_r;
reg	[ ADDR_W-1 : 0 ] o_d_addr_w, o_d_addr_r;
reg	[ DATA_W-1 : 0 ] o_d_wdata_w, o_d_wdata_r;
reg	[        1 : 0 ] o_status_w, o_status_r;
reg					 o_status_valid_w, o_status_valid_r;

reg [ ADDR_W-1 : 0 ] pc, pc_n,a1,a2;
reg [1:0]type;
reg [15:0] im;
reg [ DATA_W-1 : 0 ] regist[ ADDR_W-1 : 0 ];
reg [ DATA_W-1 : 0 ] regist_n[ ADDR_W-1 : 0 ];
//reg [ DATA_W-1 : 0 ] alu_data_1,alu_data_2;
reg [ DATA_W-1 : 0 ] ans_n,ans;
integer i;

// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
// ---- Add your own wire data assignments here if needed ---- //
assign o_i_addr = o_i_addr_r;
assign o_d_wen = o_d_wen_r;
assign o_d_addr = o_d_addr_r;
assign o_d_wdata = o_d_wdata_r;
assign o_status = o_status_r;
assign o_status_valid = o_status_valid_r;
assign inst_op = i_i_inst[31:26];
//--------------------------alu----------------------------------------//
alu u_alu(
	.i_stt(stt_n),
	.i_alu_op(i_i_inst[31:26]),
	//.i_alu_reg(regist[ 32 ]),
	//.i_alu_reg_n(regist_n[ 32 ]),
	.i_data_1(regist[i_i_inst[25:21]]),
	.i_data_2(regist[i_i_inst[20:16]]),
    .i_im(regist[i_i_inst[15:0]]),
	.o_alu_ovflw(alu_ovflw),
	.o_alu_result(alu_result)
);
// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
// ---- Write your conbinational block design here ---- //
always@(*) begin
	case(stt_c)
		IDLE: begin //0
			o_i_addr_w = o_i_addr_r;
			o_d_addr_w = 0;
			o_d_wdata_w = 0;
            o_d_wen_w = 0;
			o_status_w = 0;
			o_status_valid_w = 0;
            ans_n = 0;
			for(i=0; i<DATA_W; i=i+1) begin
				regist_n[i] = regist[i];
			end
	
			stt_n = INST_FETCH;
		end
		INST_FETCH: begin //1
			o_i_addr_w = o_i_addr_r;
			o_d_addr_w = 0;
			o_d_wdata_w = 0;
            o_d_wen_w = 0;
			o_status_w = 0;
			o_status_valid_w = 0;
			ans_n = 0;

			stt_n = INST_DE;
		end
		INST_DE: begin //2
			o_i_addr_w = o_i_addr_r;
            o_d_wdata_w = 0;
            o_d_wen_w = 0;
            o_status_w = 0;
            o_status_valid_w = 0;
			if(i_i_inst[31:26] == 6) 
                o_d_addr_w = regist[i_i_inst[25:21]] + i_i_inst[15:0]; //load from data_mem
			else 
                o_d_addr_w = 0;			

			for(i=0; i<DATA_W; i=i+1) begin
				regist_n[i] = regist[i];
			end

			ans_n = 0;

			stt_n = ALU_COM;
		end
		ALU_COM: begin //3

			case(i_i_inst[31:26])
                `OP_ADD,`OP_ADDU,`OP_SUB,`OP_SUBU,
                `OP_AND,`OP_NOR,`OP_OR,`OP_SLT:begin
					type = 0;
					o_i_addr_w = o_i_addr_r;
					o_d_addr_w = 0;
					o_d_wdata_w = 0;
                    o_d_wen_w = 0;
					o_status_w = 0;
					o_status_valid_w = 0;
					ans_n = alu_result; //got the answer from subcircuit
					stt_n = DATA_WR;
				end
				
				`OP_ADDI:begin //5
					o_i_addr_w = o_i_addr_r;
					o_d_addr_w = 0;
					o_d_wdata_w = 0;
                    o_d_wen_w = 0;
					o_status_w = 0;
					o_status_valid_w = 0;
					ans_n = $signed(regist[i_i_inst[25:21]]) + $signed(i_i_inst[15:0]);

					stt_n = DATA_WR;
				end
				`OP_LW:begin //6
					o_i_addr_w = o_i_addr_r;
					o_d_addr_w = 0;
					o_d_wdata_w = 0;
                    o_d_wen_w = 0;
					o_status_w = 0;
					o_status_valid_w = 0;
					ans_n = 0;

					stt_n = DATA_WR;
				end
				`OP_SW:begin //7
					o_i_addr_w = o_i_addr_r;
					o_d_addr_w = regist[i_i_inst[25:21]] + i_i_inst[15:0];
					o_d_wdata_w = regist[i_i_inst[20:16]];
                    o_d_wen_w = 1; //store into memory
					o_status_w = 1;
					o_status_valid_w = 1;
					ans_n = 0;

					stt_n = NEXT_GEN;
				end
				
				`OP_BEQ,`OP_BNE:begin //11 12
					o_i_addr_w = o_i_addr_r;
					o_d_addr_w = 0;
					o_d_wdata_w = 0;
                    o_d_wen_w = 0;
					o_status_w = 1; //-----I_TYPE_SUCCESS
					o_status_valid_w = 1;
					ans_n = 0;

					stt_n = NEXT_GEN;
				end
              
				`OP_EOF:begin //eof
					o_i_addr_w = o_i_addr_r;
					o_d_addr_w = 0;
					o_d_wdata_w = 0;
                    o_d_wen_w = 0;
					o_status_w = 3; //-----MIPS_END
					o_status_valid_w = 1;
					stt_n = FIN;
				end
				default:begin
					o_i_addr_w = o_i_addr_r;
					o_d_addr_w = 0;
					o_d_wdata_w = 0;
                    o_d_wen_w = 0;
					o_status_w = 3; //-------MIPS_END
					o_status_valid_w = 1;

					stt_n = FIN;
				end
			endcase
		end
		DATA_WR: begin //4

			stt_n = NEXT_GEN;

			case(i_i_inst[31:26])
                `OP_ADD,`OP_SUB,`OP_ADDU,`OP_SUBU,
                `OP_AND,`OP_NOR,`OP_OR,`OP_SLT:begin
					o_i_addr_w = o_i_addr_r;
					o_d_addr_w = 0;
                    o_d_wen_w = 0;
					o_d_wdata_w = 0;

                    if(alu_ovflw)begin
					    o_status_w = 2; //-----MIPS_OVERFLOW
					end
					else begin
						o_status_w = 0; //-----R_TYPE_SUCCESS
					end
					o_status_valid_w = 1;

					for(i=0; i<DATA_W; i=i+1) begin
						if(i==(i_i_inst[15:11])) //if it's s1's address
                            regist_n[i] = ans; //put answer into that address
						else 
                            regist_n[i] = regist[i];
					end

					ans_n = ans;
				end
				`OP_ADDI: begin //addi
					o_i_addr_w = o_i_addr_r;
					o_d_addr_w = 0;
                    o_d_wen_w = 0;
					o_d_wdata_w = 0;
					if(((regist[i_i_inst[25:21]][31]==0) && (i_i_inst[15]==0) && (ans[31]==1)) ||
                        ((regist[i_i_inst[25:21]][31]==1) && (i_i_inst[15]==1) && (ans[31]==0)))
						o_status_w = 2; //MIPS_OVERFLOW
					else 
                        o_status_w = 1; //-----I_TYPE_SUCCESS
					o_status_valid_w = 1;

					for(i=0; i<DATA_W; i=i+1) begin
						if(i==(i_i_inst[20:16])) 
                            regist_n[i] = ans;
						else 
                            regist_n[i] = regist[i];
					end

					ans_n = ans;
				end
				`OP_LW: begin //lw
					o_i_addr_w = o_i_addr_r;
					o_d_addr_w = 0;
					o_d_wdata_w = 0;
                    o_d_wen_w = 0;
					o_status_w = 1; //-----I_TYPE_SUCCESS
					o_status_valid_w = 1;

					for(i=0; i<DATA_W; i=i+1) begin
						if(i==(i_i_inst[20:16])) 
                            regist_n[i] = i_d_rdata;
						else 
                            regist_n[i] = regist[i];
					end

					ans_n = ans;
				end                
				default: begin
					o_i_addr_w = o_i_addr_r;
					o_d_addr_w = 0;
					o_d_wdata_w = 0;
                    o_d_wen_w = 0;
					o_status_w = 1; //-----I_TYPE_SUCCESS
					o_status_valid_w = 1;
					ans_n = ans;
				end
			endcase
		end
		NEXT_GEN: begin //5
            case(i_i_inst[31:26])
            `OP_BEQ:begin
                o_i_addr_w = (regist[i_i_inst[25:21]] == regist[i_i_inst[20:16]])? 
                o_i_addr_r + i_i_inst[15:0] + 4 : o_i_addr_r + 4;
            end
            `OP_BNE:begin
                o_i_addr_w = (regist[i_i_inst[25:21]] != regist[i_i_inst[20:16]])? 
                o_i_addr_r + i_i_inst[15:0] + 4 : o_i_addr_r + 4;
            end
            default:
                o_i_addr_w = o_i_addr_r + 4;
            endcase		
			o_d_addr_w = 0;
			o_d_wdata_w = 0;
            o_d_wen_w = 0;
			o_status_w = 0;
			o_status_valid_w = 0;

			ans_n = ans;

			stt_n = INST_FETCH;
		end
		FIN: begin //6
			o_i_addr_w = o_i_addr_r;
			o_d_addr_w = 0;
			o_d_wdata_w = 0;
            o_d_wen_w = 0;
			o_status_w = o_status_r;
			o_status_valid_w = 1;

			ans_n = ans;

			stt_n = IDLE;
		end
		default: begin
			o_i_addr_w = o_i_addr_r;
			o_d_addr_w = 0;
			o_d_wdata_w = 0;
            o_d_wen_w = 0;
			o_status_w = 0;
			o_status_valid_w = 0;
			ans_n = ans;

			stt_n = IDLE;
		end
	endcase
end
// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
// ---- Write your sequential block design here ---- //

always@(posedge i_clk or negedge i_rst_n)begin
	if(!i_rst_n)begin
		stt_c <= 0;
        for(i=0; i<DATA_W; i=i+1) begin
			regist[i]	     <= 0;
        end
    end
	else begin
        for(i=0; i<DATA_W; i=i+1) begin
			regist[i] <= regist_n[i];
		end
		stt_c <= stt_n;
    end
end
always@(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin // set all zero when i_rst_n is low
		//$display("i_rst_n");
		
        o_i_addr_r			 <= 0;
		o_d_wen_r			 <= 0;
		o_d_addr_r			 <= 0;
		o_d_wdata_r			 <= 0;
		o_status_r			 <= 0;
		o_status_valid_r	 <= 0;

		o_i_addr_w			 <= 0;
		o_d_wen_w			 <= 0;
		o_d_addr_w			 <= 0;
		o_d_wdata_w			 <= 0;
		o_status_w			 <= 0;
		o_status_valid_w	 <= 0;
		//inst_op			 <= 0;
		data_r_1			 <= 0;
		data_r_2			 <= 0;
		data_r_ans			 <= 0;
		im					 <= 0;
		stt_c				 <= 0;
		stt_n				 <= 1;

		//pc				 <= 0;
		//pc_n				 <= 0;
		inst_all			 <= 0;
		//type				 <= 0;
		ans					 <= 0;
		//alu_result           <= 0;
	end
	else begin
        o_i_addr_r		 <= o_i_addr_w;
		o_d_wen_r		 <= o_d_wen_w;
		o_d_addr_r		 <= o_d_addr_w;
		o_d_wdata_r		 <= o_d_wdata_w;
		o_status_r		 <= o_status_w;
		o_status_valid_r <= o_status_valid_w;
				
		ans <= ans_n;
	end
end
endmodule