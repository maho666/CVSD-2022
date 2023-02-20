`include "define.v"
`timescale 1ns/10ps
module IOTDF( clk, rst, in_en, iot_in, fn_sel, busy, valid, iot_out);
input          clk;
input          rst;
input          in_en;
input  [7:0]   iot_in;
input  [2:0]   fn_sel;
output         busy;
output         valid;
output [127:0] iot_out;


reg     [6:0]   counter_128;
reg     [1:0]   stt_c,stt_n;
reg     [7:0]   iot_data_1[0:15],iot_data_2[0:15];
reg             bigger_r , bigger_w;
reg             busy_r , busy_w;
reg             valid_w,valid_r;
reg     [2:0]   peak_value;

wire            bigger;
wire    [7:0]   sum_8b;
wire            carry_1b;

parameter EXTRACT_LOW = 128'h6FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
parameter EXTRACT_HIGH = 128'hAFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
parameter EXCLUDE_LOW = 128'h7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
parameter EXCLUDE_HIGH = 128'hBFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;

assign iot_out = valid? fn_sel == `FN_AVG?
                {peak_value,iot_data_1[15],iot_data_1[14],iot_data_1[13],iot_data_1[12],iot_data_1[11],iot_data_1[10],
                iot_data_1[9],iot_data_1[8],iot_data_1[7],iot_data_1[6],iot_data_1[5],
                iot_data_1[4],iot_data_1[3],iot_data_1[2],iot_data_1[1],iot_data_1[0][7:3]}  
                :
                ((fn_sel == `FN_EXC || fn_sel == `FN_EXT)||((fn_sel == `FN_PMAX || fn_sel == `FN_PMIN || fn_sel == `FN_MAX || fn_sel == `FN_MIN) && bigger)) ?
                
                            
                //:              
                //:
                 ({iot_data_1[15],iot_data_1[14],iot_data_1[13],iot_data_1[12],iot_data_1[11],iot_data_1[10],
                 iot_data_1[9],iot_data_1[8],iot_data_1[7],iot_data_1[6],iot_data_1[5],
                 iot_data_1[4],iot_data_1[3],iot_data_1[2],iot_data_1[1],iot_data_1[0]})

                 :
                 {iot_data_2[15],iot_data_2[14],iot_data_2[13],iot_data_2[12],iot_data_2[11],iot_data_2[10],
                 iot_data_2[9],iot_data_2[8],iot_data_2[7],iot_data_2[6],iot_data_2[5],
                 iot_data_2[4],iot_data_2[3],iot_data_2[2],iot_data_2[1],iot_data_2[0]}
                //:
                
                
                
                :0
                ; //

assign bigger = bigger_r;
assign busy = busy_r;
assign valid = valid_r;
assign {carry_1b , sum_8b} = (|counter_128[3:0] == 0) ? iot_data_1[15] + iot_data_2[15] + bigger
                            :iot_data_1[counter_128[3:0]-1] + iot_data_2[counter_128[3:0]-1] + bigger;
integer i;

//-------FSM--------//
always@(*)begin
    case(stt_c)
        `IDLE: begin //if MAX MIN output initialize
            if(rst)
                stt_n = `IDLE;
            else
                stt_n = `LOAD;
        end
        `LOAD:begin
            if( /*counter_128[3:0] == 4'b1110 ||*/ &counter_128[3:0] == 1 )
                stt_n = `PROCESS;
            else
                stt_n = `LOAD;
        end
        `PROCESS:begin
            // if(((fn_sel == `FN_MAX || fn_sel == `FN_MIN) && |counter_128 == 1)||
            //     (fn_sel == `FN_PMAX || fn_sel == `FN_PMIN) && peak_value == 
            // )
            if(|counter_128 == 0 && ((fn_sel == `FN_AVG ||fn_sel == `FN_MAX || fn_sel == `FN_MIN)  ||
            ((fn_sel == `FN_PMAX || fn_sel == `FN_PMIN) && peak_value > 0 )
            )
                
            )
                stt_n = `OUT; 
            else if(fn_sel == `FN_AVG)
                stt_n = `IDLE;
            else
                stt_n = `LOAD;
        end
        `OUT:begin
            if(fn_sel == `FN_MAX || fn_sel == `FN_MIN)
                stt_n = `IDLE;
            else
                stt_n = `LOAD;
        end
        default: 
            stt_n = `IDLE;
    endcase

end

always@(posedge clk or posedge rst)begin // got the input
    if(rst)begin
        for(i=0 ; i < 16 ; i = i + 1)begin
            iot_data_2[i] <= 0;
        end
        for(i=0 ; i < 16 ; i = i + 1)begin
            iot_data_1[i] <= 0;
        end
    end
    else begin 
        if(stt_c == `IDLE)begin      
        case(fn_sel)
            `FN_MAX , `FN_PMAX ,`FN_EXT , `FN_EXC :begin
                for(i=0 ; i < 16 ; i = i + 1)begin
                    iot_data_2[i] <= 0;
                end
                for(i=0 ; i < 16 ; i = i + 1)begin
                    iot_data_1[i] <= 0;
                end
            end
             `FN_MIN , `FN_PMIN:begin
                for(i=0 ; i < 16 ; i = i + 1)begin
                    iot_data_2[i] <= EXTRACT_LOW;
                end
                for(i=0 ; i < 16 ; i = i + 1)begin
                    iot_data_1[i] <= EXTRACT_LOW;
                end
            end
            default:begin
                for(i=0 ; i < 16 ; i = i + 1)begin
                    iot_data_2[i] <= iot_data_2[i];
                end
                for(i=0 ; i < 16 ; i = i + 1)begin
                    iot_data_1[i] <= iot_data_1[i];
                end
            end
        endcase
    end
    else if(stt_c == `LOAD && in_en)begin
        case(fn_sel)
            `FN_MAX , `FN_MIN,`FN_PMAX , `FN_PMIN:begin
                if(!bigger)begin
                    iot_data_1[counter_128[3:0]] <= iot_in;
                    iot_data_2[counter_128] <= iot_data_2[counter_128];
                end
                else begin
                    iot_data_2[counter_128[3:0]] <= iot_in;
                    iot_data_1[counter_128] <= iot_data_1[counter_128];
                end
            end
            `FN_EXT , `FN_EXC:begin
                    iot_data_1[counter_128[3:0]] <= iot_in;
                    iot_data_2[counter_128[3:0]] <= 0;
            end
            `FN_AVG:begin
                if(|counter_128[6:4] == 0)begin
                    iot_data_1[counter_128[3:0]] <= iot_in;
                    iot_data_2[counter_128[3:0]] <= 0;
                end
                else begin
                    iot_data_1[counter_128[3:0]-1] <= sum_8b;
                    iot_data_2[counter_128[3:0]] <= iot_in;

                end
            end

            default:begin
                for(i=0 ; i < 16 ; i = i + 1)begin
                    iot_data_2[i] <= iot_data_2[i];
                end
                for(i=0 ; i < 16 ; i = i + 1)begin
                    iot_data_1[i] <= iot_data_1[i];
                end
            end
        endcase
    end
    else if (stt_c == `PROCESS)begin
        case(fn_sel)
            `FN_AVG:begin

                    iot_data_1[15] <= sum_8b;
                    iot_data_2[15] <= iot_in;

            end
            default:begin
                for(i=0 ; i < 16 ; i = i + 1)begin
                    iot_data_2[i] <= iot_data_2[i];
                end
                for(i=0 ; i < 16 ; i = i + 1)begin
                    iot_data_1[i] <= iot_data_1[i];
                end
            end
        endcase
    end
    else begin
         for(i=0 ; i < 16 ; i = i + 1)begin
             iot_data_2[i] <= iot_data_2[i];
         end
         for(i=0 ; i < 16 ; i = i + 1)begin
             iot_data_1[i] <= iot_data_1[i];
         end
    end
    end
    // else begin
    //     for(i=0 ; i < 16 ; i = i + 1)begin
    //         iot_data_2[i] <= iot_data_2[i];
    //     end
    //     for(i=0 ; i < 16 ; i = i + 1)begin
    //         iot_data_1[i] <= iot_data_1[i];
    //     end
    // end

end



always@(*)begin
    // if(stt_n == `LOAD )
    //     busy_w = 0;
    if(counter_128[3:0] == 4'b1110 || stt_n == `IDLE || stt_n == `PROCESS || stt_n == `OUT)
        busy_w = 1;
    else
        busy_w = 0;
end

always@(posedge clk or posedge rst)begin
    if(rst)
        counter_128 <= 0;
    else if(stt_c == `LOAD && in_en)
        counter_128 <= counter_128 + 1;
    else
        counter_128 <= counter_128;
end

always@(*)begin //bigger_w
    if(stt_n != `IDLE)begin
    case(fn_sel)
        `FN_MAX ,`FN_PMAX:begin
            if({iot_data_1[15] , iot_data_1[14]} > {iot_data_2[15] , iot_data_2[14]})            
                bigger_w = 1;
            else
                bigger_w = 0;
        end
        `FN_MIN , `FN_PMIN:begin
            if({iot_data_1[15] , iot_data_1[14]} < {iot_data_2[15] , iot_data_2[14]})            
                bigger_w = 1;
            else
                bigger_w = 0;
        end
        `FN_AVG:begin
            if((stt_c == `LOAD || stt_c == `PROCESS) && carry_1b)            
                bigger_w = 1;
            // else if((stt_n == `OUT || stt_c == `PROCESS) && iot_data_1[15] < iot_data_2[15])            
            //     bigger_w = 1;
            
            else
                bigger_w = 0;
        end
        default:
            bigger_w = 0;
    endcase
     end
     else begin
         bigger_w = 0;
     end

end

always@(*)begin
    if(stt_n == `OUT || 
    (stt_c == `PROCESS && 
    ((fn_sel == `FN_EXC && ({iot_data_1[15],iot_data_1[14]} < EXCLUDE_LOW[127:112] || {iot_data_1[15],iot_data_1[14]} > EXCLUDE_HIGH[127:112]))||
    (fn_sel == `FN_EXT && ({iot_data_1[15],iot_data_1[14]} > EXTRACT_LOW[127:112] && {iot_data_1[15],iot_data_1[14]} < EXTRACT_HIGH[127:112]))
    )
    ))    
        valid_w = 1;
    else
        valid_w = 0;
end

always@(posedge clk or posedge rst)begin
    if(rst )
        peak_value <= 0;//|| stt_c == `OUT
    else if(stt_c == `OUT)
        peak_value <= 0;
    else if (fn_sel == `FN_AVG && ((|counter_128[3:0] == 0 ) && carry_1b))
        peak_value <= peak_value + 1;
    else if((fn_sel == `FN_PMAX || fn_sel == `FN_PMIN) && (bigger_w != bigger_r))
        peak_value <= peak_value + 1;
    
    else
        peak_value <= peak_value;
end

always@(posedge clk or posedge rst)begin
    if(rst)begin
        bigger_r <= 0;
        busy_r <= 0;
        valid_r <= 0;
        stt_c <= 0;

    end
    else begin
        bigger_r <= bigger_w;
        busy_r <= busy_w;
        valid_r <= valid_w;
        stt_c <= stt_n;
    end
end





endmodule
