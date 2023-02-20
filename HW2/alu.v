//op
`include "define.v" 
module alu#(                             //Don't modify interface
	parameter ADDR_W = 32,
	parameter INST_W = 32,
	parameter DATA_W = 32
)(
    input       [2:0]  i_stt,
    input       [5:0]  i_alu_op,
    input       [31:0] i_data_1,
    input       [31:0] i_data_2,
    input       [31:0] i_im,
    //input [ DATA_W-1 : 0 ] i_alu_reg,
    //input [ DATA_W-1 : 0 ] i_alu_reg_n,
    output reg         o_alu_ovflw,
    output reg  [31:0] o_alu_result

);

wire [31:0]sum,sub;
//wire [31:0]sum_s,sub_s;

wire signed [31:0]i_data_1_s,i_data_2_s;

//assign sum_s = i_data_1_s + i_data_2_s;
//assign sub_s = i_data_1_s - i_data_2_s;

assign sum = i_data_1 + i_data_2;
assign sub = i_data_1 - i_data_2;

//assign sum_u = i_alu_reg[i_data_1] + i_alu_reg[i_data_2];
//assign sub_u = i_alu_reg[i_data_1] - i_alu_reg[i_data_2];
always@(*)begin
    //if(i_stt == `ALU_COM)begin
        o_alu_ovflw = 0;
        //o_alu_bran = 0;
        case(i_alu_op)
        //still not have add sub addi
            `OP_ADD:begin //1
                o_alu_result = sum;
                if((!i_data_1[31] && !i_data_2[31] && sum[31]) || (i_data_1[31] && i_data_2[31] && !sum[31]))
                    o_alu_ovflw = 1; //when positive???
                else
                    o_alu_ovflw = 0;
            end
            `OP_SUB:begin //2
                o_alu_result = sub;
                if((!i_data_1[31] && i_data_2[31] && sub[31]) || (i_data_1[31] && !i_data_2[31] && !sum[31]))
                    o_alu_ovflw = 1; //when positive???
                else
                    o_alu_ovflw = 0;
            end
            `OP_ADDU:begin //3
                o_alu_result = sum;
                if(sum < i_data_1 || sum < i_data_2)
                    o_alu_ovflw = 1;
                else
                    o_alu_ovflw = 0;
            end
            `OP_SUBU:begin //4
                o_alu_result = sub;
                if(sub > i_data_1)
                    o_alu_ovflw = 1;
                else
                    o_alu_ovflw = 0; //must be 1 not sum[31]
            end
            `OP_ADDI:begin //5
                o_alu_result = i_data_1+i_im;//$signed(i_data_1) + $signed(i_im);
                //o_alu_ovflw = sum[31];
                o_alu_ovflw = 0;
            end
            `OP_AND: begin//8
                o_alu_result = i_data_1 & i_data_2;
                o_alu_ovflw = 0;
            end
            `OP_OR: begin//9
                o_alu_result = i_data_1 | i_data_2;
                o_alu_ovflw = 0;
            end
            `OP_NOR: begin//10
                o_alu_result = ~(i_data_1 | i_data_2);
                o_alu_ovflw = 0;
            end
/*            `OP_BEQ: begin//11
                o_alu_bran = (i_data_1 == i_data_2)?1:0;
                o_alu_ovflw = 0;
            end
            `OP_BNE: begin//12
                o_alu_bran = (i_data_1 != i_data_2)?1:0;
                o_alu_ovflw = 0;
            end*/
            `OP_SLT: begin//13
                o_alu_result = ($signed(i_data_1) < $signed(i_data_2))?1:0;
                o_alu_ovflw = 0;
            end
        endcase
        //i_alu_en = 0;
    //end
end


endmodule