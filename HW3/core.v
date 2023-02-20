`include "define.v"
module core (                       //Don't modify interface
	input         i_clk,
	input         i_rst_n,
	input         i_op_valid,
	input  [ 3:0] i_op_mode,
    output        o_op_ready,
	input         i_in_valid,
	input  [ 7:0] i_in_data,
	output        o_in_ready,
	output        o_out_valid,
	output [12:0] o_out_data
);

// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------
// ---- Add your own wires and registers here if needed ---- //
//parameter IDLE = 			2'd0;
//parameter OP_SAVE_MOVE = 	2'd1;
//parameter DISPLAY = 		2'd2;
//parameter FIN = 			2'd3;
reg  	[2:0]  stt_c, stt_n;
//reg		start_w,start_r;
reg            op_ready_r, op_ready_w, in_ready_r, in_ready_w, out_valid_r, out_valid_w;
reg  	[12:0] out_data_r, out_data_w;
//wire 	[7:0] sram_in[0:3];
//wire	[7:0]sram_Q[0:3];

reg  	[10:0] load_counter, load_counter_n;
reg  	[1:0]  conv_counter_r, conv_counter_w;

reg  	[5:0]  data_idx_0_c, data_idx_0_n;
reg  	[1:0]  depth_c, depth_n; //0~3


reg  	[12:0] sum_edge, sum_map_idx;
reg  	[16:0] conv_result_r, conv_result_w;

//--------------------------sram-----------------------------//
wire 	[11:0] sram_addr;
reg  	[11:0] sram_addr_w, sram_addr_r;
wire           sram_cen,sram_wen;
reg            sram_cen_w, sram_cen_r, sram_wen_w, sram_wen_r;
wire 	[7:0]  sram_in, sram_Q;
reg  	[7:0]  sram_in_w, sram_in_r;
// wire 	[7:0] sram_in[0:3];
// wire	[7:0]sram_Q[0:3];
// reg 	sram_cen_w[0:3] , sram_cen_r[0:3];
// reg 	sram_wen_r[0:3], sram_wen_w[0:3];
// wire 	sram_cen[0:3];
// wire 	sram_wen[0:3];


reg  	[5:0]  map_idx, square_edge;

wire 	[11:0] accum_r;
reg		[11:0] accum_w;

reg  	[10:0] accumulation_8_w[0:63],accumulation_8_r[0:63];
reg  	[10:0] accumulation_16_w[0:63],accumulation_16_r[0:63];
reg  	[11:0] accumulation_32_w[0:63],accumulation_32_r[0:63];

// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
// ---- Add your own wire data assignments here if needed ---- //
assign o_in_ready = in_ready_r;
assign o_op_ready = op_ready_r;

assign o_out_valid = out_valid_r;
assign o_out_data = out_data_r;

assign sram_addr = sram_addr_r;
assign sram_cen = sram_cen_r;
assign sram_wen = sram_wen_r;
assign sram_in = sram_in_r;

// assign sram_cen[0] = sram_cen_r[0];
// assign sram_cen[1] = sram_cen_r[1];
// assign sram_cen[2] = sram_cen_r[2];
// assign sram_cen[3] = sram_cen_r[3];

// assign sram_wen[0] = sram_wen_r[0];
// assign sram_wen[1] = sram_wen_r[1];
// assign sram_wen[2] = sram_wen_r[2];
// assign sram_wen[3] = sram_wen_r[3];


// assign sram_addr[0] = sram_addr_r[0];
// assign sram_addr[1] = sram_addr_r[1];
// assign sram_addr[2] = sram_addr_r[2];
// assign sram_addr[3] = sram_addr_r[3];

// assign sram_in[0]  = sram_in_r[0];
// assign sram_in[1]  = sram_in_r[1];
// assign sram_in[2]  = sram_in_r[2];
// assign sram_in[3]  = sram_in_r[3];

assign accum_r =  i_in_data + accum_w ;

sram_4096x8 s0_sram(
	.Q( sram_Q ), 
	.CLK( i_clk ), 
	.CEN( sram_cen ), 
	.WEN( sram_wen ), 
	.A( sram_addr ), 
	.D( sram_in )
);

// sram_512x8 s0_sram(
//     .Q   ( sram_Q[0] ),
//     .CLK ( i_clk      ),
//     .CEN ( sram_cen[0] ),
//     .WEN ( sram_wen[0] ),
//     .A   ( sram_addr[0]  ),
//     .D   ( sram_in[0]  )
// );
// sram_512x8 s1_sram(
//     .Q   ( sram_Q[1] ),
//     .CLK ( i_clk      ),
//     .CEN ( sram_cen[1] ),
//     .WEN ( sram_wen[1] ),
//     .A   ( sram_addr[1]  ),
//     .D   ( sram_in[1]  )
// );
// sram_512x8 s2_sram(
//     .Q   ( sram_Q[2]),
//     .CLK ( i_clk      ),
//     .CEN ( sram_cen[2] ),
//     .WEN ( sram_wen[2] ),
//     .A   ( sram_addr[2]  ),
//     .D   ( sram_in[2]  )
// );
// sram_512x8 s3_sram(
//     .Q   ( sram_Q[3] ),
//     .CLK ( i_clk      ),
//     .CEN ( sram_cen[3] ),
//     .WEN ( sram_wen[3] ),
//     .A   ( sram_addr[3]  ),
//     .D   ( sram_in[3]  )
// );
integer i;
// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
// ---- Write your conbinational block design here ---- //

always@ (*)begin
	//out_valid_r = 0;
	//out_data_r = 13'd0;
	
	//sram_addr = 9'd0;
	//sram_out_s0_r = sram_out_s0;
	//sram_out_s1_r = sram_out_s1;
	//sram_out_s2_r = sram_out_s2;
	//sram_out_s3_r = sram_out_s3;
	/*sram_cen[0] = 1; //sram standby
	sram_cen[1] = 1;
	sram_cen[2] = 1;
	sram_cen[3] = 1;
	sram_wen[0] = 0;
	sram_wen[1] = 0;
	sram_wen[2] = 0;
	sram_wen[3] = 0;*/
	case(stt_c)
		`IDLE:begin
			
			// if(i_op_valid == 1)
			// 		//if(load_counter < 2048)
			// 	stt_n = `LOADING;
			// else
			// 	stt_n = `IDLE;
			load_counter_n = load_counter;
			conv_counter_w = 0;
			//conv_counter_r = 0;
			data_idx_0_n = data_idx_0_c;
			depth_n = depth_c;
			
			sram_addr_w = sram_addr_r;
			sram_cen_w = sram_cen_r;
			sram_wen_w = sram_wen_r;
			sram_in_w = sram_in_r;

			conv_result_w = conv_result_r;

			for(i = 0 ;  i < 64 ;  i = i + 1)begin

				accumulation_8_w[i] = accumulation_8_r[i];

				accumulation_16_w[i] = accumulation_16_r[i];

				accumulation_32_w[i] = accumulation_32_r[i];
				
			end
			out_valid_w = 0;
			out_data_w = 0;
			op_ready_w = 1;

			stt_n = `START;
		end
		`START:begin
			op_ready_w = 0;
			depth_n = depth_c;
			data_idx_0_n = data_idx_0_c;

			load_counter_n = load_counter;
			conv_counter_w = 0;		

			sram_addr_w = sram_addr_r;
			sram_cen_w = sram_cen_r;
			sram_wen_w = sram_wen_r;
			sram_in_w = sram_in_r;

			conv_result_w = conv_result_r;

			for(i = 0 ;  i < 64 ;  i = i + 1)begin

				accumulation_8_w[i] = accumulation_8_r[i];

				accumulation_16_w[i] = accumulation_16_r[i];

				accumulation_32_w[i] = accumulation_32_r[i];
				
			end
			out_valid_w = 0;
			out_data_w = 0;

			stt_n = `OP;
		end
		`OP:begin
            
			op_ready_w = 0;
			out_valid_w = 0;
			out_data_w = 0;
			load_counter_n = load_counter;
			conv_counter_w = 0;
			case(i_op_mode)
				`OP_LOAD:begin

					depth_n = depth_c;
					sram_cen_w = sram_cen_r;
					sram_wen_w = sram_wen_r;
					sram_in_w = sram_in_r;				
					data_idx_0_n = data_idx_0_c;
					
					sram_addr_w = sram_addr_r;

					stt_n = `LOADING;
				end
				`OP_UP:begin
					
					//$display("up ^^^^^^^^^");
					
					depth_n = depth_c;
					sram_cen_w = sram_cen_r;
					sram_wen_w = sram_wen_r;
					sram_in_w = sram_in_r;
					sram_addr_w = sram_addr_r;
					if(data_idx_0_c[5:3] != 0) begin
						data_idx_0_n = data_idx_0_c - 8;
					end
					else begin
						data_idx_0_n = data_idx_0_c;
					end

					stt_n = `IDLE;
				end
				`OP_DOWN :begin
					
					//$display("down vvvvvvvvvvvv");
					depth_n = depth_c;
					sram_addr_w = sram_addr_r; 
					sram_cen_w = sram_cen_r;
					sram_wen_w = sram_wen_r;
					sram_in_w = sram_in_r;
					if(data_idx_0_c[5:3] != 6) begin
						data_idx_0_n = data_idx_0_c + 8;
					end
					else begin
						data_idx_0_n = data_idx_0_c ;
					end
					

					stt_n = `IDLE;
				end
				`OP_RIGHT:begin 
					
					//$display("right >>>>>>");
					depth_n = depth_c;
					sram_cen_w = sram_cen_r;
					sram_wen_w = sram_wen_r;
					sram_in_w = sram_in_r;
					sram_addr_w = sram_addr_r;
					if(data_idx_0_c[2:0] != 6) begin//if touch right margin
						data_idx_0_n = data_idx_0_c + 1;
					end
					else begin
						data_idx_0_n = data_idx_0_c;
					end

					stt_n = `IDLE;
				end
				`OP_LEFT : begin
					//$display("left <<<<<<<<<<");
					depth_n = depth_c;
					sram_cen_w = sram_cen_r;
					sram_wen_w = sram_wen_r;
					sram_in_w = sram_in_r;
					sram_addr_w = sram_addr_r;
					if(data_idx_0_c[2:0] > 0) begin
						data_idx_0_n = data_idx_0_c - 1;
					end
					else begin
						data_idx_0_n = data_idx_0_c;
					end
					

					stt_n = `IDLE;
				end
				
				`OP_CONV :begin 
					
					
					data_idx_0_n = data_idx_0_c;
					depth_n = depth_c;
					
					sram_in_w = sram_in_r;
					sram_cen_w = sram_cen_r;
					sram_wen_w = sram_wen_r;
					
					// sram_addr_w[0] = sram_addr_r[0];
					// sram_addr_w[1] = sram_addr_r[1];
					// sram_addr_w[2] = sram_addr_r[2];
					// sram_addr_w[3] = sram_addr_r[3];
					sram_addr_w = sram_addr_r; 

					stt_n = `CONV;
				end
				`OP_RE_CHANNEL:begin
					//$display("Reduce channel------------");
					sram_addr_w = sram_addr_r;
					sram_cen_w = sram_cen_r;
					sram_wen_w = sram_wen_r;
					sram_in_w = sram_in_r;
					data_idx_0_n = data_idx_0_c;
					if(depth_c == 0) begin  //0->>8
						depth_n = depth_c;
					end
					else begin
						depth_n = depth_c - 1;
					end
					

					stt_n = `IDLE;
				end
				`OP_IN_CHANNEL:begin 
					//$display("Increase channel+++++++++++");
					
					data_idx_0_n = data_idx_0_c;
					sram_addr_w = sram_addr_r; 
					sram_cen_w = sram_cen_r;
					sram_wen_w = sram_wen_r;
					sram_in_w = sram_in_r;
					if(depth_c == 2) begin //2 -->32
						depth_n = depth_c;
					end
					else begin
						depth_n = depth_c + 1;
					end
					

					stt_n = `IDLE;
				end
				
				default:begin 
					
					
					data_idx_0_n = data_idx_0_c;
					depth_n = depth_c;

					sram_addr_w = data_idx_0_c;
					sram_cen_w = 0;
					sram_wen_w = 1;
					// sram_cen_w[0] = 0;
					// sram_wen_w[0] = 1;
					// sram_cen_w[1] = 0;
					// sram_wen_w[1] = 1;
					// sram_cen_w[2] = 0;
					// sram_wen_w[2] = 1;
					// sram_cen_w[3] = 0;
					// sram_wen_w[3] = 1;
					sram_in_w = sram_in_r;

					stt_n = `WAITING ;
				end
			endcase

			conv_result_w = conv_result_r;

			for(i = 0 ;  i < 64 ;  i = i + 1)begin

				accumulation_8_w[i] = accumulation_8_r[i];

				accumulation_16_w[i] = accumulation_16_r[i];

				accumulation_32_w[i] = accumulation_32_r[i];
				
			end
		end
		`LOADING:begin
			if(i_in_valid)begin
				op_ready_w = 0;
				

				sram_cen_w = 0;
				for(i = 0 ;  i < 64 ;  i = i + 1)begin
					if(i == load_counter[5:0])begin
						//$display(i);
						if(load_counter[10:9] == 0)begin //0 ~ 255
							accum_w = accumulation_8_r[i];

							accumulation_16_w[i] = accumulation_16_r[i];
							accumulation_32_w[i] = accumulation_32_r[i];
							accumulation_8_w[i] = accum_r;
						end
						else if(load_counter[10:9] == 1)begin //255 ~ 511
							accumulation_8_w[i] = accumulation_8_r[i];
							accumulation_16_w[i] = accum_r;
							accumulation_32_w[i] = accumulation_32_r[i];
							accum_w = accumulation_16_r[i];
						end
						else begin //511~2048
							accumulation_8_w[i] = accumulation_8_r[i];
							accumulation_16_w[i] = accumulation_16_r[i];
							accumulation_32_w[i] = accum_r;
							accum_w = accumulation_32_r[i];
						end
					end
					else begin
							//accum_w = 0;
							accumulation_8_w[i] = accumulation_8_r[i];
							accumulation_16_w[i] = accumulation_16_r[i];
							accumulation_32_w[i] = accumulation_32_r[i];
					end
				end
				load_counter_n = load_counter + 1;
				stt_n = `LOADING;

			end
			else begin
				//accum_w = 0;
				op_ready_w = 0;
				load_counter_n = 0;
				
				sram_cen_w = 1;
				for(i = 0 ;  i < 64 ;  i = i + 1)begin
					accumulation_8_w[i] = accumulation_8_r[i];
					accumulation_16_w[i] = accumulation_16_r[i];
					accumulation_32_w[i] = accumulation_32_r[i];
				end
				stt_n = `IDLE;
			end
			//accum_w = 0;
			
			conv_counter_w = 0;
			out_valid_w = 0;
			out_data_w = 0;
			
			data_idx_0_n = data_idx_0_c;
			depth_n = depth_c;

			sram_addr_w = load_counter;
			sram_wen_w = 0;
			sram_in_w = i_in_data;

			conv_result_w = conv_result_r;
		end
		`CONV:begin//
			op_ready_w = 0;
			out_valid_w = 0;
			out_data_w = 0;


			load_counter_n = load_counter + 1;
			conv_counter_w = conv_counter_r;
			data_idx_0_n = data_idx_0_c;
			depth_n = depth_c;

			sram_addr_w = data_idx_0_c;
			sram_cen_w = 1;
		    sram_wen_w = 0;
			sram_in_w = sram_in_r;
			//
			map_idx = data_idx_0_c + conv_counter_r[0] + {conv_counter_r[1], 3'b000};

			
			/*
			if(load_counter[2:0] == 0)begin
				square_edge = map_idx - 6'd9;
			end
			else if(load_counter[2:0] == 1)begin
				square_edge = map_idx - 6'd8;
			end
			else if(load_counter[2:0] == 2)begin
				square_edge = map_idx - 6'd7;
			end
			else if(load_counter[2:0] == 3)begin
				square_edge = map_idx - 6'd1;
			end
			else if(load_counter[2:0] == 4)begin
				square_edge = map_idx + 6'd1;
			end
			else if(load_counter[2:0] == 5)begin
				square_edge = map_idx + 6'd7;
			end
			else if(load_counter[2:0] == 6)begin
				square_edge = map_idx + 6'd8;
			end
			else if(load_counter[2:0] == 7)begin
				square_edge = map_idx + 6'd9;
			end
			else begin
				square_edge = 0;
			end
			*/
			case( load_counter[2:0] )
			 	0: square_edge = map_idx - 6'd9;
			 	1: square_edge = map_idx - 6'd8;
			 	2: square_edge = map_idx - 6'd7;
			 	3: square_edge = map_idx - 6'd1;
			 	4: square_edge = map_idx + 6'd1;
			 	5: square_edge = map_idx + 6'd7;
			 	6: square_edge = map_idx + 6'd8;
			 	7: square_edge = map_idx + 6'd9;
			endcase
		/*if(dis_idx_r == 0)begin
			out_valid_w = 1;
			//0
			conv_result = ((data_idx_0_c[2:0] == 0 || data_idx_0_c[5:3] == 0)? 0 : accumulation_sel[data_idx_0_c - 9])+
			//1
			({((data_idx_0_c[5:3] == 0)? 0 : accumulation_sel[data_idx_0_c - 8]), 1'b0})+
			//2
			((data_idx_0_c[5:3] == 0)? 0 : accumulation_sel[data_idx_0_c - 7]) +
			
			//----------------------------------------------------------------------------------//
			//3
			({((data_idx_0_c[2:0] == 0)? 0 : accumulation_sel[data_idx_0_c - 1]), 1'b0}) +
			//4
			({(accumulation_sel[data_idx_0_c]), 2'b0}) +
			//5
			({(accumulation_sel[data_idx_0_c + 1]), 1'b0}) +
			//---------------------------------------------------------------------------------//
			//6
			((data_idx_0_c[2:0] == 0)? 0 : accumulation_sel[data_idx_0_c + 7]) +
			//7
			({(accumulation_sel[data_idx_0_c + 8]), 1'b0}) +
			//8
			(accumulation_sel[data_idx_0_c + 9]) ;

			out_data_w = conv_result[18:4] + conv_result[3];
		end
		else if(dis_idx_r == 1)begin
			out_valid_w = 1;
			//0
			conv_result = ((data_idx_0_c[5:3] == 0)? 0 : accumulation_sel[data_idx_0_c - 8])+
			//1
			({((data_idx_0_c[5:3] == 0)? 0 : accumulation_sel[data_idx_0_c - 7]),1'b0})+
			//2
			((data_idx_0_c[2:0] == 6 || data_idx_0_c[5:3] == 0)? 0 : accumulation_sel[data_idx_0_c - 6]) +
		
			//----------------------------------------------------------------------------------//
			//3
			({(accumulation_sel[data_idx_0_c]),1'b0}) +
			//4
			({(accumulation_sel[data_idx_0_c + 1]),2'b0}) +
			//5
			({((data_idx_0_c[2:0] == 6 )? 0 : accumulation_sel[data_idx_0_c + 2]),1'b0}) +
			//---------------------------------------------------------------------------------//
			//6
			(accumulation_sel[data_idx_0_c + 8]) +
			//7
			({(accumulation_sel[data_idx_0_c + 9]),1'b0}) +
			//8
			((data_idx_0_c[2:0] == 6 )? 0 : accumulation_sel[data_idx_0_c + 10]) ;

			out_data_w = conv_result[18:4] + conv_result[3];
		end
		else if(dis_idx_r == 2)begin
			out_valid_w = 1;
			//0
			conv_result = (( data_idx_0_c[2:0] == 0 )? 0 : accumulation_sel[data_idx_0_c - 1])+
			//1
			({(accumulation_sel[data_idx_0_c]),1'b0})+
			//2
			(accumulation_sel[data_idx_0_c + 1]) +
		
			//----------------------------------------------------------------------------------//
			//3
			({((data_idx_0_c[2:0] == 0)? 0 : accumulation_sel[data_idx_0_c + 7]),1'b0}) +
			//4
			({(accumulation_sel[data_idx_0_c + 8]),2'b0}) +
			//5
			({(accumulation_sel[data_idx_0_c + 9]),1'b0}) +
			//---------------------------------------------------------------------------------//
			//6
			((data_idx_0_c[2:0] == 0 || data_idx_0_c[5:3] == 6)? 0 : accumulation_sel[data_idx_0_c + 15]) +
			//7
			({((data_idx_0_c[5:3] == 6)? 0 : accumulation_sel[data_idx_0_c + 16]),1'b0}) +
			//8
			((data_idx_0_c[5:3] == 6)? 0 : accumulation_sel[data_idx_0_c + 17]) ;

			out_data_w = conv_result[18:4] + conv_result[3];
		end
		else if(dis_idx_r == 3)begin
			out_valid_w = 1;
			//0
			conv_result = (accumulation_sel[data_idx_0_c])+
			//1
			({(accumulation_sel[data_idx_0_c + 1]),1'b0})+
			//2
			((data_idx_0_c[2:0] == 6)? 0 : accumulation_sel[data_idx_0_c + 2]) +
		
			//----------------------------------------------------------------------------------//
			//3
			({(accumulation_sel[data_idx_0_c + 8]),1'b0}) +
			//4
			({(accumulation_sel[data_idx_0_c + 9]),2'b0}) +
			//5
			({((data_idx_0_c[2:0] == 6)? 0 : accumulation_sel[data_idx_0_c + 10]),1'b0}) +
			//---------------------------------------------------------------------------------//
			//6
			((data_idx_0_c[5:3] == 6)? 0 : accumulation_sel[data_idx_0_c + 16]) +
			//7
			({((data_idx_0_c[5:3] == 6)? 0 : accumulation_sel[data_idx_0_c + 17]),1'b0}) +
			//8
			((data_idx_0_c[5:3] == 6 || data_idx_0_c[2:0] == 6)? 0 : accumulation_sel[data_idx_0_c + 18]) ;

			out_data_w = conv_result[18:4] + conv_result[3];
		end*/
		//------------------------------------sum of each channel----------------------------------------//
			if(depth_c == 0)begin
				sum_map_idx = accumulation_8_r[map_idx];
				sum_edge = accumulation_8_r[square_edge];
				
			end
			else if(depth_c == 1)begin
				
				sum_map_idx = accumulation_8_r[map_idx] + accumulation_16_r[map_idx];
				sum_edge = accumulation_8_r[square_edge] + accumulation_16_r[square_edge];
			end
			else if(depth_c == 2)begin
				
				sum_map_idx = accumulation_8_r[map_idx] + accumulation_16_r[map_idx] + accumulation_32_r[map_idx];
				sum_edge = accumulation_8_r[square_edge] + accumulation_16_r[square_edge] + accumulation_32_r[square_edge];
			end
			else begin
				sum_map_idx = 0;
				//out_data_w = 0;
				sum_edge = 0;
				
			end
		//------------------------------------sum of pixel ----------------------------------------//
			case( load_counter[2:0] ) //0 ~ 7
				0:begin // /8 %8==0 vertical
					

					conv_result_w = ( (map_idx[2:0] == 0) || (map_idx[5:3] == 0))?({sum_map_idx, 2'b0}):
									sum_edge + ({sum_map_idx, 2'b0});
					stt_n = `CONV;
				end
				1:begin // /8
					
					conv_result_w = (map_idx[5:3] == 0)? conv_result_r:
									conv_result_r + ({sum_edge, 1'b0});
					stt_n = `CONV;
				end
				2:begin// /8 %8 == 7 vertical
					

					conv_result_w = ((map_idx[5:3] == 0) || (map_idx[2:0] == 7) )? conv_result_r:
									conv_result_r + sum_edge;

					stt_n = `CONV;
				end
				3:begin
					
					conv_result_w = (map_idx[2:0] == 0)? conv_result_r:
									conv_result_r + ({sum_edge, 1'b0}); //*2
					stt_n = `CONV;
				end
				4:begin
					
					conv_result_w = (map_idx[2:0] == 7)? conv_result_r:
									conv_result_r + ({sum_edge, 1'b0});//*2
					stt_n = `CONV;
				end
				5:begin
					

					conv_result_w = ( (map_idx[5:3] == 7) || (map_idx[2:0] == 0) )? conv_result_r:
									 conv_result_r + sum_edge;
					stt_n = `CONV;
				end
				6:begin
					
					conv_result_w = ( map_idx[5:3] == 7 )? conv_result_r:
									 conv_result_r + ({sum_edge, 1'b0});//*2
					stt_n = `CONV;
				end
				7:begin
					
					conv_result_w = ( (map_idx[2:0] == 7) || (map_idx[5:3] == 7))? conv_result_r:
									conv_result_r + sum_edge;
					stt_n = `CONV_DIS;
				end
				default: begin
					conv_result_w = conv_result_r;
					stt_n = `IDLE;
				end
			endcase
			for(i = 0 ;  i < 64 ;  i = i + 1)begin

				accumulation_8_w[i] = accumulation_8_r[i];

				accumulation_16_w[i] = accumulation_16_r[i];

				accumulation_32_w[i] = accumulation_32_r[i];
				
			end
		end
		`CONV_DIS:begin
			sram_cen_w = 1;
		    sram_wen_w = 0;
			out_valid_w = 1;
			//rounded +[3]
			out_data_w = conv_result_r[16 : 4] + conv_result_r[3]; 

			
			load_counter_n = 0;
			data_idx_0_n = data_idx_0_c;
			depth_n = depth_c;

			sram_addr_w = data_idx_0_c;
			
			sram_in_w = sram_in_r;

			conv_result_w = 0;

			op_ready_w = 0;
			
			if(conv_counter_r >= 3) begin
				conv_counter_w = 0;
				stt_n = `IDLE;
			end
			else begin
				conv_counter_w = conv_counter_r + 1;
				stt_n = `CONV;
			end

			for(i = 0 ;  i < 64 ;  i = i + 1)begin

				accumulation_8_w[i] = accumulation_8_r[i];

				accumulation_16_w[i] = accumulation_16_r[i];

				accumulation_32_w[i] = accumulation_32_r[i];
				
			end
		end
		`WAITING :begin
			//waiting for the sum of convolution
			conv_counter_w = 0;
			load_counter_n = load_counter + 1;
			// if      (dis_q_r < 32)   
			// 	out_data_w = sram_Q[0]; 
			// else if (dis_q_r < 64)   
			// 	out_data_w = sram_Q[1];
			// else if (dis_q_r < 96)   
			// 	out_data_w = sram_Q[2]; 
			// else begin                 
			// 	out_data_w = sram_Q[3];
			// end
			
			data_idx_0_n = data_idx_0_c;
			depth_n = depth_c;
			sram_addr_w = data_idx_0_c + 1;
			sram_cen_w = 0;
		    sram_wen_w = 1;
			sram_in_w = sram_in_r;

			conv_result_w = conv_result_r;
			op_ready_w = 0;
			out_valid_w = 0;
			out_data_w = 0;
			for(i = 0 ;  i < 64 ;  i = i + 1)begin

				accumulation_8_w[i] = accumulation_8_r[i];

				accumulation_16_w[i] = accumulation_16_r[i];

				accumulation_32_w[i] = accumulation_32_r[i];
				
			end
			stt_n = `DISPLAY;
		end
		`DISPLAY:begin	
			/*
			if(load_counter[1:0] == 0) begin
				sram_addr_w = sram_addr_r + 1;
			end
			else if(load_counter[1:0] == 1) begin
				sram_addr_w = sram_addr_r + 7;
			end
			else if(load_counter[1:0] == 2) begin
				sram_addr_w = sram_addr_r + 1;
			end
			else if(load_counter[1:0] == 3)begin
				sram_addr_w = sram_addr_r + 55;
			end
			else begin
				sram_addr_w = sram_addr_r;
			end
			*/
			case(load_counter[1:0])
				0,2:sram_addr_w = sram_addr_r + 1;
				1:sram_addr_w = sram_addr_r + 7;
				//2:sram_addr_w = sram_addr_r + 1;
				3:sram_addr_w = sram_addr_r + 55;
			endcase

			conv_counter_w = 0;
			data_idx_0_n = data_idx_0_c;
			depth_n = depth_c;

			out_valid_w = 1;
			out_data_w = sram_Q;
			
			sram_in_w = sram_in_r;

			if(depth_c == 0) begin
				/*if(loader_counter == 8)begin
					sram_cen_w[0] = 1;
					sram_wen_w[0] = 0;
					op_ready_w[0] = 0;
					load_counter_n = 0;

					stt_n = `IDLE;
				end
				else if(loader_counter == 16)begin
					sram_cen_w[1] = 1;
					sram_wen_w[1] = 0;
					op_ready_w[1] = 0;
					load_counter_n = 0;

					stt_n = `IDLE;
				end
				else if(loader_counter == 24)begin
					sram_cen_w[2] = 1;
					sram_wen_w[2] = 0;
					op_ready_w[2] = 0;
					load_counter_n = 0;

					stt_n = `IDLE;
				end
				else if(loader_counter == 32)begin
					sram_cen_w[3] = 1;
					sram_wen_w[3] = 0;
					op_ready_w[3] = 0;
					load_counter_n = 0;

					stt_n = `IDLE;
				end*/

				if(load_counter == 32) begin

					load_counter_n = 0;
					sram_cen_w = 1;
					//sram_cen_w[0] = 1;
					//sram_wen_w[0] = 0;
					//sram_cen_w[1] = 1;
					//sram_wen_w[1] = 0;
					//sram_cen_w[2] = 1;
					//sram_wen_w[2] = 0;
					//sram_cen_w[3] = 1;
					//sram_wen_w[3] = 0;
					sram_wen_w = 0;
					op_ready_w = 0;
					
					stt_n = `IDLE;
				end
				else begin
					load_counter_n = load_counter + 1;
					op_ready_w = 0;
					
					sram_cen_w = 0;
					//sram_cen_w[0] = 0;
					//sram_wen_w[0] = 1;
					//sram_cen_w[1] = 0;
					//sram_wen_w[1] = 1;
					//sram_cen_w[2] = 0;
					//sram_wen_w[2] = 1;
					//sram_cen_w[3] = 0;
					//sram_wen_w[3] = 1;
					sram_wen_w = 1;
					stt_n = `DISPLAY;
				end
			end
			else if(depth_c == 1)begin
				if(load_counter == 64) begin
					
					load_counter_n = 0;
					sram_cen_w = 1;
					//sram_cen_w[0] = 1;
					//sram_wen_w[0] = 0;
					//sram_cen_w[1] = 1;
					//sram_wen_w[1] = 0;
					//sram_cen_w[2] = 1;
					//sram_wen_w[2] = 0;
					//sram_cen_w[3] = 1;
					//sram_wen_w[3] = 0;
					sram_wen_w = 0;
					op_ready_w = 0;
					
					stt_n = `IDLE;
				end
				else begin
					load_counter_n = load_counter + 1;
					op_ready_w = 0;
					//sram_cen_w[0] = 0;
					//sram_wen_w[0] = 1;
					//sram_cen_w[1] = 0;
					//sram_wen_w[1] = 1;
					//sram_cen_w[2] = 0;
					//sram_wen_w[2] = 1;
					//sram_cen_w[3] = 0;
					//sram_wen_w[3] = 1;
					sram_cen_w = 0;
					sram_wen_w = 1;
					stt_n = `DISPLAY;
				end
			end
			else begin
				if(load_counter == 128) begin
					
					load_counter_n = 0;
					sram_cen_w = 1;
					//sram_cen_w[0] = 1;
					//sram_wen_w[0] = 0;
					//sram_cen_w[1] = 1;
					//sram_wen_w[1] = 0;
					//sram_cen_w[2] = 1;
					//sram_wen_w[2] = 0;
					//sram_cen_w[3] = 1;
					//sram_wen_w[3] = 0;
					sram_wen_w = 0;
					op_ready_w = 0;
					
					stt_n = `IDLE;
				end
				else begin
					load_counter_n = load_counter + 1;
					op_ready_w = 0;
					
					sram_cen_w = 0;
					//sram_cen_w[0] = 0;
					//sram_wen_w[0] = 1;
					//sram_cen_w[1] = 0;
					//sram_wen_w[1] = 1;
					//sram_cen_w[2] = 0;
					//sram_wen_w[2] = 1;
					//sram_cen_w[3] = 0;
					//sram_wen_w[3] = 1;
					sram_wen_w = 1;
					stt_n = `DISPLAY;
				end
			end
			conv_result_w = conv_result_r;

			for(i = 0 ;  i < 64 ;  i = i + 1)begin

				accumulation_8_w[i] = accumulation_8_r[i];

				accumulation_16_w[i] = accumulation_16_r[i];

				accumulation_32_w[i] = accumulation_32_r[i];
				
			end
 		end
	endcase

end
/*always@(*)begin
	if(stt_n == `SHIFT)begin
		case(i_op_mode)
				`OP_RIGHT:begin
					//$display("right >>>>>>");
					if(data_idx_0_c [2:0] != 6) //if touch right margin
						data_idx_0_n = data_idx_0_c + 1;
					else
						data_idx_0_n = data_idx_0_c;
				end
				`OP_LEFT:begin
					//$display("left <<<<<<<<<<");
					if(data_idx_0_c[2:0] > 0)
						data_idx_0_n = data_idx_0_c - 1;
					else
						data_idx_0_n = data_idx_0_c;
				end
				`OP_UP:begin
					//$display("up ^^^^^^^^^");
					if(data_idx_0_c > 7 )
						data_idx_0_n = data_idx_0_c - 8;
					else
						data_idx_0_n = data_idx_0_c;
				end
				`OP_DOWN:begin
					//$display("down vvvvvvvvvvvv");
					if(data_idx_0_c < 56)
						data_idx_0_n = data_idx_0_c + 8;
					else
						data_idx_0_n = data_idx_0_c;
				end
				default:
					data_idx_0_n = data_idx_0_c;
		endcase
	end
	else begin
		//$display("no      shfit");
		data_idx_0_n = data_idx_0_c;
	end
end*/
// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
// ---- Write your sequential block design here ---- //

always@ (posedge i_clk or negedge i_rst_n)begin
	if(!i_rst_n) begin
		stt_c <= `IDLE;
		op_ready_r <= 0;
		out_valid_r <= 0;
		out_data_r <= 0;		
		load_counter <= 0;
		conv_counter_r <= 0;
		data_idx_0_c <= 0;
		depth_c <= 2;
		conv_result_r <= 0;
		// sram_cen_r[0] <= 0;
		// sram_wen_r[0] <= 0;
		// sram_cen_r[1] <= 0 ;
		// sram_wen_r[1] <= 0 ;
		// sram_cen_r[2] <= 0 ;
		// sram_wen_r[2] <= 0 ;
		// sram_cen_r[3] <=0 ;
		// sram_wen_r[3] <= 0 ;

		// sram_in_r[0] <= 0;
		// sram_in_r[1] <= 0;
		// sram_in_r[2] <= 0;
		// sram_in_r[3] <= 0;

		// sram_addr_r[0] <= 0;
		// sram_addr_r[1] <= 0;
		// sram_addr_r[2] <= 0;
		// sram_addr_r[3] <= 0;

		for(i = 0 ;  i < 64 ;  i = i + 1)begin
			accumulation_8_r[i] <= 0;
			accumulation_16_r[i] <= 0;
			accumulation_32_r[i] <= 0;
		end
		in_ready_r <= 1;
		sram_in_r <= 0;
		sram_addr_r <= 0; //sram sram_addr
		sram_cen_r <= 1;
		sram_wen_r <= 0;
		
	end 
	else begin
		op_ready_r <= op_ready_w;
		in_ready_r <= 1;
		out_valid_r <= out_valid_w;
		out_data_r <= out_data_w;

		stt_c <= stt_n;
		load_counter <= load_counter_n;
		//out_valid_r <= out_valid_r_w;
		conv_counter_r <= conv_counter_w;
		data_idx_0_c <= data_idx_0_n;
		depth_c <= depth_n;
		//center <= next_center;
		//pixel <= next_pixel;
		//display_counter <= next_display_counter;
		//flag <= next_flag;

		// sram_cen_r[0] <= sram_cen_w[0] ;
		// sram_wen_r[0] <= sram_wen_w[0] ;
		// sram_cen_r[1] <= sram_cen_w[1] ;
		// sram_wen_r[1] <= sram_wen_w[1] ;
		// sram_cen_r[2] <= sram_cen_w[2] ;
		// sram_wen_r[2] <= sram_wen_w[2] ;
		// sram_cen_r[3] <= sram_cen_w[3] ;
		// sram_wen_r[3] <= sram_wen_w[3] ;

		// sram_in_r[0] <= sram_in_w[0];
		// sram_in_r[1] <= sram_in_w[1];
		// sram_in_r[2] <= sram_in_w[2];
		// sram_in_r[3] <= sram_in_w[3];

		// sram_addr_r[0] <= sram_addr_w[0];
		// sram_addr_r[1] <= sram_addr_w[1];
		// sram_addr_r[2] <= sram_addr_w[2];
		// sram_addr_r[3] <= sram_addr_w[3];

		conv_result_r <= conv_result_w;

		for(i = 0 ;  i < 64 ;  i = i + 1)begin
			accumulation_8_r[i] <= accumulation_8_w[i];
			//$display("%d",accumulation_32_r[i]);
			accumulation_16_r[i] <= accumulation_16_w[i];
			accumulation_32_r[i] <= accumulation_32_w[i];
		end

		sram_addr_r <= sram_addr_w;
		sram_cen_r <= sram_cen_w;
		sram_wen_r <= sram_wen_w;
		sram_in_r <= sram_in_w;

  	end
end



endmodule
