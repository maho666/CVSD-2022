module alu #(
    parameter INT_W  = 3,
    parameter FRAC_W = 5,
    parameter INST_W = 3,
    parameter DATA_W = INT_W + FRAC_W
)(
    input                     i_clk,
    input                     i_rst_n,
    input                     i_valid,
    input signed [DATA_W-1:0] i_data_a,
    input signed [DATA_W-1:0] i_data_b,
    input        [INST_W-1:0] i_inst,
    output                    o_valid,
    output       [DATA_W-1:0] o_data
);

parameter ADD = 3'd0;
parameter SUB = 3'd1;
parameter MUL = 3'd2;
parameter NAND = 3'd3;
parameter XNOR = 3'd4;
parameter SIG = 3'd5;
parameter SHIFT = 3'd6;
parameter MIN = 3'd7;
// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------
reg  [DATA_W:0] o_data_w, o_data_r;
reg             o_valid_w, o_valid_r;

// ---- Add your own wires and registers here if needed ---- //
reg  [2:0] stt_c,stt_n;
reg overflow_add,overflow_sub,overflow_mul;
reg signed [DATA_W-1:0] i_data_b_n;
reg [15:0]o_mul;
reg [DATA_W-1:0] shift_b,shift_a;
reg [7:0]o_sig;
//reg  [7:0] o_get;
// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
assign o_valid = o_valid_r;
assign o_data = o_data_r;
// ---- Add your own wire data assignments here if needed ---- //


// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
// ---- Write your combinational block design here ---- //
always@(*) begin
    //o_data_w = o_get;
	case(i_inst)
		3'd0 : 
		begin
			o_data_w = i_data_a + i_data_b;
			if( (!i_data_a[7] && !i_data_b[7] && o_data_w[7]) || (i_data_a[7] && i_data_b[7] && !o_data_w[7]))
				overflow_add = 1;
			else
				overflow_add = 0;
		end
		3'd1 : 
		begin
			i_data_b_n = (~i_data_b + 1);
			o_data_w = i_data_a + i_data_b_n;
			if( (!i_data_a[7] && !i_data_b_n[7] && o_data_w[7]) || (i_data_a[7] && i_data_b_n[7] && !o_data_w[7]))
				overflow_sub = 1;
			else
				overflow_sub = 0;
		end
		3'd2 : 
		begin
			//o_data_w = i_data_a * i_data_b;
			o_mul = i_data_a * i_data_b;
			if(o_mul[4] == 1)
				o_data_w = o_mul[12:5] + 1;
			else
				o_data_w = o_mul[12:5] + 0;
			if(((|o_mul[15:13]) && ((i_data_a[7] && i_data_b[7]) || (!i_data_a[7] && !i_data_b[7]))) || (~(&o_mul[15:13]) && ((i_data_a[7] && !i_data_b[7]) || (!i_data_a[7] && i_data_b[7]))))
				overflow_mul = 1;
			else
				overflow_mul = 0;
		end
		3'd3 : 
		begin
			o_data_w = ~(i_data_a & i_data_b);
		end
		3'd4 : 
		begin
			o_data_w = ~(i_data_a ^ i_data_b);
		end
		3'd5 :
		begin
			o_sig = i_data_a;
			if(o_sig[7] && o_sig > 8'b11000000)
				o_data_w = (o_sig >> 2) + 8'b11010000;
			
			else if(!o_sig[7] && o_sig[6])
				o_data_w = 8'b00100000;
			else if(o_sig[7] && o_sig <= 8'b11000000)
				o_data_w = 8'b0;
			/*else if(i_data_a[7] && i_data_a > 8'b11000000)
				o_data_w = 0.25*i_data_a + 8'b00001111;*/
			/*else if(i_data_a[7] && !i_data_a[6])begin
				
				//o_data_w = 0.25*i_data_a + 8'b00010000;
				o_data_w = (i_data_a >> 2) + 8'b00010000;
			end*/
			else begin 
				o_data_w = (o_sig >> 2) + 8'b00010000;
			end
		end
		3'd6 : 
		begin
			shift_a = i_data_a;
			shift_b = i_data_b;
			while(shift_b > 0)begin
				shift_b = shift_b - 1;
				shift_a ={shift_a[0] , shift_a[7:1]}; 
			end

			o_data_w = shift_a;
		end
		3'd7 : 
		begin
			//o_data_r <= (i_data_a == i_data_b)?(i_data_a:((i_data_a < i_data_b)?i_data_a:i_data_b));
			if(i_data_a < i_data_b)
				o_data_w = i_data_a;
			else if(i_data_a > i_data_b)
				o_data_w = i_data_b;
			else
				o_data_w = i_data_a;
		end
	endcase

    o_valid_w = (i_valid)?1:0;
end

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
// ---- Write your sequential block design here ---- //
always@(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
        o_data_r  <= 0;
        o_valid_r <= 0;
    end else begin
		if(overflow_add)begin
			case({i_data_a[7] , i_data_b[7]})
				2'b00: o_data_r <= 8'b01111111;
				2'b11: o_data_r <= 8'b10000000;
			default: o_data_r <= 8'b11111111;
			endcase
		end
        	/*else begin
			o_data_r  <= o_data_w;	
		end*/
		else if(overflow_sub)begin
			case({i_data_a[7] , i_data_b_n[7]})
				2'b00: o_data_r <= 8'b01111111;
				2'b11: o_data_r <= 8'b10000000;
			default: o_data_r <= 8'b11111111;
			endcase
		end
		else if(overflow_mul)begin
			case({i_data_a[7] , i_data_b[7]})
				2'b00 , 2'b11: o_data_r <= 8'b01111111;
				2'b01 , 2'b10: o_data_r <= 8'b10000000;
			default: o_data_r <= 8'b11111111;
			endcase
		end
        	else begin
			o_data_r  <= o_data_w;	
		end

        o_valid_r <= o_valid_w;
    end
end


// ---------------------------------------------------------------------------
// FSM
// ---------------------------------------------------------------------------
always@(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n)begin
		stt_c <= 3'b0;
	end
	else begin
		stt_c <= stt_n;
	end
end

always@(*)begin
	case(i_inst)
		3'd0 : stt_n = ADD;
		3'd1 : stt_n = SUB;
		3'd2 : stt_n = MUL;
		3'd3 : stt_n = NAND;
		3'd4 : stt_n = XNOR;
		3'd5 : stt_n = SIG;
		3'd6 : stt_n = SHIFT;
		3'd7 : stt_n = MIN;
	default : stt_n = ADD;
	endcase
end
endmodule
