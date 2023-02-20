`include "define.v"
module polar_decoder (
    clk,
    rst_n,
    module_en,
    proc_done,
    raddr,
    rdata,
    waddr,
    wdata
);
// IO description
    input  wire         clk;
    input  wire         rst_n;
    input  wire         module_en;
    input  wire [191:0] rdata;
    output wire [ 10:0] raddr;
    output wire [  5:0] waddr;
    output wire [139:0] wdata;
    output wire         proc_done;

//read_data declaration
    reg     [2:0]       stt_c;
    reg     [2:0]       stt_n;
    reg     [10:0]      addr_r ; 
    reg                 end_p;
    reg     [6:0]       packet;
    reg     [6:0]       num_p;
    reg     [9:0]       N;
    reg     [7:0]       K;
    reg     [191:0]     LLR_A [0:15];
    reg     [191:0]     LLR_B [0:15];
    reg                 dec_begin;
    reg                 addr_ctr;
    reg     [4:0]       dec_ctr;
    reg                 reg_ctr;
    reg                 read_end;

//intermediate registers
//abs
    reg     [11:0]      out_s0 [0:15][0:15];
    reg     [12:0]      out_s1 [0:7][0:15];
    reg     [13:0]      out_s2 [0:3][0:15];
    reg     [14:0]      out_s3 [0:1][0:15];
    reg     [15:0]      out_s4 [0:15];
    reg     [16:0]      out_s5 [0:7];
    reg     [17:0]      out_s6 [0:3];
    reg     [18:0]      out_s7 [0:1]; 
    //sign
    reg                 sign_s0 [0:15][0:15];
    reg                 sign_s1 [0:7][0:15];
    reg                 sign_s2 [0:3][0:15];
    reg                 sign_s3 [0:1][0:15];
    reg                 sign_s4 [0:15];
    reg                 sign_s5 [0:7];
    reg                 sign_s6 [0:3];
    reg                 sign_s7 [0:1];


    reg [4:0] stage, total_stage;
    reg       next_stage; //0-down 1-up
    reg       skip, skip_next;
    // reg       stage_n;
    reg       stage0;
    reg [1:0] stage1;
    reg [2:0] stage2;
    reg [3:0] stage3;
    reg [4:0] stage4;
    reg [5:0] stage5;
    reg [6:0] stage6;
    reg [7:0] stage7;
    reg [8:0] stage8;

    reg     u0 ;
    reg     u1 [0:1];
    reg     u2 [0:3];
    reg     u3 [0:7];
    reg     u4 [0:15];
    reg     u5 [0:31];
    reg     u6 [0:63];
    reg     u7 [0:127];
    reg     u8 [0:255];
    
    integer i,j;

    reg  [4:0] addr_end;
    reg  [139:0] u;
    reg          sel;
    reg          proc_done_r;
    reg [7:0] u_ctr;//max count to 140

    reg [1:0] ctr;
    reg get_frozen, get_frozen_next;
    //reg [4:0] addr_ctr;


    assign waddr = num_p;
    assign wdata = u;
    // always@(*)begin
    //     if (end_p) 
    // end

    assign raddr = addr_r;
    assign proc_done = proc_done_r;

    reg         frozen_ready;
    reg  [511:0]  reliability;
    wire [511:0]  reliability_w;
    wire        endlist;
    reg [1:0] N_type;
    reg stage_n;
    wire [18:0] output_mag [0:15];
    reg [18:0] abs_a [0:15]; 
    reg [18:0] abs_b [0:15];
    wire output_sign [0:15];
    reg sign_a [0:15], sign_b [0:15];
    reg input_u [0:15];
    reg [3:0] stage_c; //LLR_A[0]~LLR_A[15], LLR_B[0]~LLR_B[15]
    
    reg [10:0] LLR_A_abs [0:15];
    reg [10:0] LLR_B_abs [0:15];
        


//------------------------- reliability  --------------------------------
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        frozen_ready <= 0;
    else begin
        if (endlist)
            frozen_ready <= 0;
        else if ( stt_c == `DATA_FRO|| (stt_c == `INFO && ctr == 3))
            frozen_ready <= 1;
        else
            frozen_ready <= 0;  
    end
end

always @(*) begin
    case(N)
    128:N_type = 0;
    256:N_type = 1;
    512:N_type = 2;
    default:N_type = 3;
    endcase
end

reliability_list R1 (.N(N_type),
                    .K(K),
                    .clk(clk),
                    .state(frozen_ready),
                    .rst_n(rst_n),
                    .endlist(endlist),
                    .reliability(reliability_w));

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        reliability <= 0;
    else begin
        if (endlist)
            reliability <= reliability_w;
        else 
            reliability <= reliability;  
    end
end

//-----------------------state machine------------------------------
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        stt_c <= `IDLE;
    else
        stt_c <= stt_n;
end

always@(*)begin //check
    case(stt_c)
        `IDLE: begin
            stt_n = (module_en || !proc_done) ? `INFO : `IDLE;
        end
        `INFO:begin
            stt_n = ( ctr == 3) ? `DATA_FRO : `INFO;
        end
        `DATA_FRO: begin
            stt_n = (endlist) ? `DATA_DEC : `DATA_FRO; 
        end
        `DATA_DEC: begin
            stt_n = ((u_ctr == K) && (num_p == (packet - 1))) ? `DONE : ((end_p) ? `INFO : `DATA_DEC);
        end
        `DONE:begin
            stt_n = `IDLE;
        end
        default: stt_n = stt_c; 
    endcase
end



always@(posedge clk or negedge rst_n)begin  //// ctr
    if(!rst_n )begin
        ctr <= 0;
    end
    else begin
        if(stt_c == `INFO)begin
            ctr <= ctr + 1;
        end
        else if(stt_c == `INFO && !dec_begin)begin
            ctr <= 3;
        end
        else if(stt_c == `DATA_DEC && end_p)begin
            ctr <= 1;
        end
        else begin
            ctr <= ctr;
        end
    end
end

//-----------------------------stage_n----------------------------
     always@(*) begin
        if (stt_c==`DATA_DEC && read_end==1)
            if (!next_stage)
                stage_n = ((stage_c == addr_end) || skip);
            else 
                stage_n = 1;
        else
            stage_n = 0;
    end
//skip

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        stage <= 0;
    else begin
        if (stt_c==`DATA_DEC && read_end==1)begin
            if (stage_n && next_stage) begin
                stage <= stage - 1;
            end
            else if (stage_n && ((stage == total_stage) || skip)) begin
                stage <= stage;
            end
            else if (stage_n) begin
                stage <= stage + 1;
            end
            else begin 
                stage <= stage;
            end
            end
            else begin
                stage <= 0;
            end
    end
end

//----------------------K N-------------------
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n) begin
        N <= 0;
        K <= 0;
    end
    else if(stt_c==`INFO && ctr == 3)begin
        N <= rdata[9:0];
        K <= rdata[17:10];
    end
    else begin
        N <= N;
        K <= K;
    end
end

//--------------------------------read address-----------------------
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        addr_r <= 0;
    else begin
        if (stt_c == `IDLE)
            addr_r <= 0;
        else if(stt_c==`INFO && ctr == 1)begin
            addr_r <= ((num_p<<5) + num_p+'d1);
        end
        else if (stt_c==`INFO && ctr == 2)
            addr_r <= ((num_p<<5) + num_p+'d1);
        else if (stt_c==`INFO && ctr == 3)
            addr_r <= addr_r+'d1;
        else if(stt_c==`DATA_DEC && (dec_ctr <(N>>5)-1))begin
            case({N_type, addr_ctr})
            3'b000:
                addr_r <= addr_r +'d4;
            3'b001:
                addr_r <= addr_r -'d3;
            3'b010:
                addr_r <= addr_r +'d8;
            3'b011:
                addr_r <= addr_r -'d7;
            3'b100:
                addr_r <= addr_r +'d16;
            3'b101:
                addr_r <= addr_r -'d15;
            3'b110:
                addr_r <= 0;
            3'b111:
                addr_r <= 0;
            default:
                addr_r <= 0;
            endcase
        end
        else if(stt_c == `DONE)begin
                addr_r <= 0;
        end
        else begin
            addr_r <= addr_r;
        end
    end
end
//--------------------address ctr------------------------
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        addr_ctr <= 0;
    else begin
        if (stt_c == `INFO && &ctr == 1)
            addr_ctr <= 0;
        else if(stt_c==`DATA_DEC)
            addr_ctr <= addr_ctr+1;
        else
            addr_ctr <= addr_ctr;
    end
end

// always @(*) begin
//     skip = !get_frozen;
// end
//------------------------decoder---------------------------------
always@(*) begin
        if (stt_c==`DATA_DEC && read_end)
            case(N)
             128: begin
                if (stage == 0) begin
                    get_frozen = (| reliability[(stage0 *64) +: 64]);
                    get_frozen_next = 1;
                end
                else if (stage == 1) begin
                    get_frozen = (| reliability[(stage1 *32) +: 32]);
                    get_frozen_next = (| reliability[(stage1 *32) +: 32]);
                end
                else if (stage == 2) begin
                    get_frozen = (| reliability[(stage2 *16) +: 16]);
                    get_frozen_next = (| reliability[(stage1 *32) +: 32]);
                end
                else if (stage == 3) begin
                    get_frozen = (| reliability[(stage3 *8) +: 8]);
                    get_frozen_next = (| reliability[(stage2 *16) +: 16]);
                end
                else if (stage == 4) begin
                    get_frozen = (| reliability[(stage4 *4) +: 4]);
                    get_frozen_next = (| reliability[(stage3 *8) +: 8]);
                end
                else if (stage == 5) begin
                    get_frozen = (| reliability[(stage5 *2) +: 2]);
                     get_frozen_next = (| reliability[(stage4 *4) +: 4]);
                end
                else if (stage == 6) begin
                    get_frozen = (| reliability[stage6]);
                    get_frozen_next = (| reliability[(stage5 *2) +: 2]);
                end
                else begin
                    get_frozen = 1;
                    get_frozen_next = 1;
                end
            end
            256: begin
                if (stage == 0) begin
                    get_frozen = (| reliability[(stage0 *128) +: 128]);
                    get_frozen_next = 0;
                end
                else if (stage == 1) begin
                    get_frozen = (| reliability[(stage1 *64) +: 64]);
                    get_frozen_next = (| reliability[(stage0 *128) +: 128]);
                end
                else if (stage == 2) begin
                    get_frozen = (| reliability[(stage2 *32) +: 32]);
                    get_frozen_next = (| reliability[(stage1 *64) +: 64]);
                end
                else if (stage == 3) begin
                    get_frozen = (| reliability[(stage3 *16) +: 16]);
                    get_frozen_next = (| reliability[(stage2 *32) +: 32]);
                end
                else if (stage == 4) begin
                    get_frozen = (| reliability[(stage4 *8) +: 8]);
                    get_frozen_next = (| reliability[(stage3 *16) +: 16]);
                end
                else if (stage == 5) begin
                    get_frozen = (| reliability[(stage5 *4) +: 4]);
                    get_frozen_next = (| reliability[(stage4 *8) +: 8]);
                end
                else if (stage == 6) begin
                    get_frozen = (| reliability[(stage6 *2) +: 2]);
                    get_frozen_next = (| reliability[(stage5 *4) +: 4]);
                end
                else if (stage == 7) begin
                    get_frozen = (| reliability[(stage7) +: 1]);
                    get_frozen_next = (| reliability[(stage6 *2) +: 2]);
                end
                else begin
                    get_frozen = 0;
                    get_frozen_next = 0;
                end
            end
            512: begin
                if (stage == 0) begin
                    get_frozen = (| reliability[(stage0 *256) +: 256]);
                    get_frozen_next = 0;
                end
                else if (stage == 1) begin
                    get_frozen = (| reliability[(stage1 *128) +: 128]);
                    get_frozen_next = (| reliability[(stage0 *256) +: 256]);
                end
                else if (stage == 2) begin
                    get_frozen = (| reliability[(stage2 *64) +: 64]);
                    get_frozen_next = (| reliability[(stage1 *128) +: 128]);
                end
                else if (stage == 3) begin
                    get_frozen = (| reliability[(stage3 *32) +: 32]);
                    get_frozen_next = (| reliability[(stage2 *64) +: 64]);
                end
                else if (stage == 4) begin
                    get_frozen = (| reliability[(stage4 *16) +: 16]);
                    get_frozen_next = (| reliability[(stage3 *32) +: 32]);
                end
                else if (stage == 5) begin
                    get_frozen = (| reliability[(stage5 *8) +: 8]);
                    get_frozen_next = (| reliability[(stage4 *16) +: 16]);
                end
                else if (stage == 6) begin
                    get_frozen = (| reliability[(stage6 *4) +: 4]);
                    get_frozen_next = (| reliability[(stage5 *8) +: 8]);
                end
                else if (stage == 7) begin
                    get_frozen = (| reliability[(stage7 *2) +: 2]);
                    get_frozen_next = (| reliability[(stage6 *4) +: 4]);
                end
                else if (stage == 8) begin
                    get_frozen = (| reliability[(stage8) +: 1]);
                    get_frozen_next = (| reliability[(stage7 *2) +: 2]);
                end
                else begin
                    get_frozen = 0;
                    get_frozen_next = 0;
                end
            end
            default: 
            begin
                get_frozen = 0;
                get_frozen_next = 0;
            end
            endcase    
        else begin
            get_frozen = 0;
            get_frozen_next = 0;
        end
        skip = !get_frozen;
        skip_next = !get_frozen_next;
    end
  
//stage

//total_stage
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            total_stage <= 0;
        end
        else begin
            case(N)
            128:
                total_stage <= 6;
            256:
                total_stage <= 7;
            512:
                total_stage <= 8;
            default:
                total_stage <= 0;
            endcase
        end
    end
//next_stage
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n)
            next_stage <= 0;
        else begin
            if (stt_c == `DATA_DEC && read_end)
            case (stage)
                0: begin 
                    next_stage <= (!next_stage)? (skip && stage0):0;
                end
                1: begin 
                    next_stage <= (!next_stage)? (skip && stage1[0]):0;
                end
                2: begin 
                    next_stage <= (!next_stage)? (skip && stage2[0]):((!skip_next) && (stage1[0]))? 0 : 1;
                end
                3: begin 
                    next_stage <= (!next_stage)? (skip && stage3[0]):((!skip_next) && (stage2[0]))? 0 : 1;
                end
                4: begin 
                    next_stage <= (!next_stage)? (skip && stage4[0]):((!skip_next) && (stage3[0]))? 0 : 1;
                end
                5: begin 
                    next_stage <= (!next_stage)? (skip && stage5[0]):((!skip_next) && (stage4[0]))? 0 : 1;
                end
                6: begin 
                    if (N == 128) begin
                        next_stage <= (!next_stage)? (!stage6[0]):((!skip_next) && (stage5[0]))? 0 : 1;
                    end 
                    else begin
                        next_stage <= (!next_stage)? (skip && stage6[0]):((!skip_next) && (stage5[0]))? 0 : 1;
                    end
                end
                7: begin 
                    if (N == 256) 
                        next_stage <= (!next_stage)? (!stage7[0]):((!skip_next) && (stage6[0]))? 0 : 1;
                    else
                        next_stage <= (!next_stage)? (skip && stage7[0]):((!skip_next) && (stage6[0]))? 0 : 1;
                end
                8: begin 
                    next_stage <= (!next_stage)? (!stage8[0]):((!skip_next) && (stage7[0]))? 0 : 1;
                end
                default: next_stage <= 0;
            endcase
            else begin
                next_stage <= 0;
            end
        end
    end
always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            stage0 <= 0;
            stage1 <= 0; 
            stage2 <= 0;
            stage3 <= 0;
            stage4 <= 0;
            stage5 <= 0;
            stage6 <= 0;
            stage7 <= 0;
            stage8 <= 0;
        end else if (stt_c==`DATA_DEC && read_end)
            case (stage)
                0: begin
                    if (next_stage) begin
                        stage0 <= (stage0) ? stage0 + 1 : stage0;
                    end
                    else  begin
                        stage0 <=  ((stage_c == addr_end) || skip) ? stage0 + 1 : stage0;
                    end
                    if (skip) begin
                        if(next_stage && !stage0)begin
                            stage1 <= stage1 ;
                            stage2 <= stage2 ;
                            stage3 <= stage3 ;
                            stage4 <= stage4 ;
                            stage5 <= stage5 ;
                            stage6 <= stage6 ;
                            stage7 <= stage7 ;
                            stage8 <= stage8 ;
                        end
                        else begin
                            stage1 <= stage1 + 2;
                            stage2 <= stage2 + 4;
                            stage3 <= stage3 + 8;
                            stage4 <= stage4 + 16;
                            stage5 <= stage5 + 32;
                            stage6 <= stage6 + 64;
                            stage7 <= stage7 + 128;
                            stage8 <= stage8 + 256;
                        end
                    end
                    else begin
                        stage1 <= stage1;
                        stage2 <= stage2;
                        stage3 <= stage3;
                        stage4 <= stage4;
                        stage5 <= stage5;
                        stage6 <= stage6;
                        stage7 <= stage7;
                        stage8 <= stage8;
                    end
                end
                1: begin
                    if (next_stage) begin
                        stage1 <= (stage1[0]) ? stage1 + 1 : stage1;
                    end
                    else begin 
                        stage1 <=  ((stage_c == addr_end) || skip) ? stage1 + 1 : stage1; 
                    end
                    if (skip) begin
                        stage2 <= (next_stage && !stage1[0]) ? stage2 : stage2 + 2;
                        stage3 <= (next_stage && !stage1[0]) ? stage3 : stage3 + 4;
                        stage4 <= (next_stage && !stage1[0]) ? stage4 : stage4 + 8;
                        stage5 <= (next_stage && !stage1[0]) ? stage5 : stage5 + 16;
                        stage6 <= (next_stage && !stage1[0]) ? stage6 : stage6 + 32;
                        stage7 <= (next_stage && !stage1[0]) ? stage7 : stage7 + 64;
                        stage8 <= (next_stage && !stage1[0]) ? stage8 : stage8 + 128;
                    end 
                    else begin
                        stage2 <= stage2;
                        stage3 <= stage3;
                        stage4 <= stage4;
                        stage5 <= stage5;
                        stage6 <= stage6;
                        stage7 <= stage7;
                        stage8 <= stage8;
                    end
                end
                2: begin 
                    if (next_stage) stage2 <= (stage2[0]) ? stage2 + 1 : stage2;
                    else  stage2 <=  ((stage_c == addr_end) || skip) ? stage2 + 1 : stage2;
                    if (skip) begin
                        stage3 <= (next_stage && !stage2[0]) ? stage3 : stage3 + 2;
                        stage4 <= (next_stage && !stage2[0]) ? stage4 : stage4 + 4;
                        stage5 <= (next_stage && !stage2[0]) ? stage5 : stage5 + 8;
                        stage6 <= (next_stage && !stage2[0]) ? stage6 : stage6 + 16;
                        stage7 <= (next_stage && !stage2[0]) ? stage7 : stage7 + 32;
                        stage8 <= (next_stage && !stage2[0]) ? stage8 : stage8 + 64;
                    end else begin
                        stage3 <= stage3;
                        stage4 <= stage4;
                        stage5 <= stage5;
                        stage6 <= stage6;
                        stage7 <= stage7;
                        stage8 <= stage8;
                    end
                end
                3: begin
                    if (next_stage) stage3 <= (stage3[0]) ? stage3 + 1 : stage3;
                    else  stage3 <=  ((stage_c == addr_end) || skip) ? stage3 + 1 : stage3;
                    if (skip) begin
                        stage4 <= (next_stage && !stage3[0]) ? stage4 : stage4 + 2;
                        stage5 <= (next_stage && !stage3[0]) ? stage5 : stage5 + 4;
                        stage6 <= (next_stage && !stage3[0]) ? stage6 : stage6 + 8;
                        stage7 <= (next_stage && !stage3[0]) ? stage7 : stage7 + 16;
                        stage8 <= (next_stage && !stage3[0]) ? stage8 : stage8 + 32;
                    end else begin
                        stage4 <= stage4;
                        stage5 <= stage5;
                        stage6 <= stage6;
                        stage7 <= stage7;
                        stage8 <= stage8;
                    end
                end
                4: begin
                    if (next_stage) stage4 <= (stage4[0]) ? stage4 + 1 : stage4;
                    else  stage4 <=  ((stage_c == addr_end) || skip) ? stage4 + 1 : stage4;
                    if (skip) begin
                        stage5 <= (next_stage && !stage4[0]) ? stage5 : stage5 + 2;
                        stage6 <= (next_stage && !stage4[0]) ? stage6 : stage6 + 4;
                        stage7 <= (next_stage && !stage4[0]) ? stage7 : stage7 + 8;
                        stage8 <= (next_stage && !stage4[0]) ? stage8 : stage8 + 16;
                    end else begin
                        stage5 <= stage5;
                        stage6 <= stage6;
                        stage7 <= stage7;
                        stage8 <= stage8;
                    end
                end
                5: begin
                    if (next_stage) stage5 <= (stage5[0]) ? stage5 + 1 : stage5;
                    else  stage5 <=  ((stage_c == addr_end) || skip) ? stage5 + 1 : stage5;
                    if (skip) begin
                        stage6 <= (next_stage && !stage5[0]) ? stage6 : stage6 + 2;
                        stage7 <= (next_stage && !stage5[0]) ? stage7 : stage7 + 4;
                        stage8 <= (next_stage && !stage5[0]) ? stage8 : stage8 + 8;
                    end else begin
                        stage6 <= stage6;
                        stage7 <= stage7;
                        stage8 <= stage8;
                    end
                end
                6: begin
                    if (next_stage) stage6 <= (stage6[0]) ? stage6 + 1 : stage6;
                    else  stage6 <=  ((stage_c == addr_end) || skip) ? stage6 + 1 : stage6;
                    if (skip) begin
                        stage7 <= (next_stage && !stage6[0]) ? stage7 : stage7 + 2;
                        stage8 <= (next_stage && !stage6[0]) ? stage8 : stage8 + 4;
                    end else begin
                        stage7 <= stage7;
                        stage8 <= stage8;
                    end
                end
                7: begin
                    if (next_stage) stage7 <= (stage7[0]) ? stage7 + 1 : stage7;
                    else  stage7 <=  ((stage_c == addr_end) || skip) ? stage7 + 1 : stage7;
                    if (skip) begin
                        stage8 <= (next_stage && !stage7[0]) ? stage8 : stage8 + 2;
                    end else begin
                        stage8 <= stage8;
                    end
                end
                8: begin
                    stage8 <= (next_stage & !stage8[0]) ? stage8 : (stage8 + 1);
                end
                default: begin
                    stage0 <= 0;
                    stage1 <= 0; 
                    stage2 <= 0;
                    stage3 <= 0;
                    stage4 <= 0;
                    stage5 <= 0;
                    stage6 <= 0;
                    stage7 <= 0;
                    stage8 <= 0;
                end
            endcase
        else begin
            stage0 <= 0;
            stage1 <= 0; 
            stage2 <= 0;
            stage3 <= 0;
            stage4 <= 0;
            stage5 <= 0;
            stage6 <= 0;
            stage7 <= 0;
            stage8 <= 0;
        end
    end

always@(posedge clk or negedge rst_n)begin
        if(!rst_n) begin
            u0 <= 0;
            u1[0] <= 0;
            u1[1] <= 0;
            for (i=0;i<4;i=i+1)begin
                u2[i] <= 0;
            end
            for (i=0;i<8;i=i+1)begin
                 u3[i] <= 0;
            end
            for (i=0;i<16;i=i+1)begin
                 u4[i] <= 0;
            end
            for (i=0;i<32;i=i+1)begin
                 u5[i] <= 0;
            end
            for (i=0;i<64;i=i+1)begin
                 u6[i] <= 0;
            end
            for (i=0;i<128;i=i+1)begin
                 u7[i] <= 0;
            end
            for (i=0;i<256;i=i+1)begin
                 u8[i] <= 0;
            end
        end 
        else if (stt_c == `DATA_DEC && read_end) begin
            if ((stage == total_stage)) begin
                case(stage)
                    6: begin
                        if (!skip) begin
                            u0 <= (!stage6[0]) ? (output_sign[0]) : u0;
                            u1[0] <= (!stage6[0]) ? (output_sign[0]) : (u1[0] ^ output_sign[0]);
                            u1[1] <= (stage6[0]) ? (output_sign[0]) : u1[1];
                        end 
                        else begin
                            u0 <= 0;
                            u1[0] <= (!stage6[0]) ? 0 : (u1[0] ^ 0);
                            u1[1] <= (stage6[0]) ? 0 : u1[1]; 
                        end
                    end
                    7: begin
                        if (!skip) begin
                            u0 <= !(stage7[0]) ? (output_sign[0]) : u0;
                            u1[0] <= !(stage7[0]) ? (output_sign[0]) : (u1[0] ^ output_sign[0]);
                            u1[1] <= (stage7[0]) ? (output_sign[0]) : u1[1];
                        end else begin
                            u0 <= 0;
                            u1[0] <= (!stage7[0]) ? 0 : (u1[0] ^ 0);
                            u1[1] <= (stage7[0]) ? 0 : u1[1]; 
                        end
                    end
                    8: begin
                        if (!skip) begin
                            u0 <= (!stage8[0]) ? (output_sign[0]) : u0;
                            u1[0] <= (!stage8[0]) ? (output_sign[0]) : (u1[0] ^ output_sign[0]);
                            u1[1] <= (stage8[0]) ? (output_sign[0]) : u1[1];
                        end else begin
                            u0 <= 0;
                            u1[0] <= (!stage8[0]) ? 0 : (u1[0] ^ 0);
                            u1[1] <= (stage8[0]) ? 0 : u1[1]; 
                        end
                    end
                    default: begin
                        u0 <= 0;
                        u1[0] <= u1[0];
                        u1[1] <= u1[1];
                    end
                endcase
            end 
            else if (N==128) begin
                case(stage)
                    0: begin
                        u0 <= 0;
                        u1[0] <= 0;
                        u1[1] <= 0;
                        for (i=0;i<4;i=i+1)begin
                            u2[i] <= 0;
                        end
                        for (i=0;i<8;i=i+1)begin
                            u3[i] <= 0;
                        end
                        for (i=0;i<16;i=i+1)begin
                            u4[i] <= 0;
                        end
                        for (i=0;i<32;i=i+1)begin
                            u5[i] <= 0;
                        end
                        for (i=0;i<64;i=i+1)begin
                            u6[i] <= u6[i];
                        end
                        for (i=0;i<128;i=i+1)begin
                            u7[i] <= 0;
                        end
                        for (i=0;i<256;i=i+1)begin
                            u8[i] <= 0;
                        end      
                    end
                    1: begin
                        if (!next_stage)begin
                            for (i=0;i<32;i=i+1) begin
                                u5[i] <= (skip && (!stage1[0])) ? 0 : u5[i];
                                u6[i] <= (stage1[0]) ? u5[i] : u6[i];
                            end    
                        end
                        else if (stage1[0])begin 
                            for (i=0;i<32;i=i+1) begin
                                u6[i] <= 0 ^ u5[i];
                                u6[i+32] <= 0;
                            end
                        end
                        else begin
                            for (i=0;i<32;i=i+1) begin
                                u6[i] <= u5[i] ^ u6[i];
                                u6[i+32] <= u5[i];
                            end   
                        end         
                    end
                    2: begin
                        if (!next_stage)begin
                            for (i=0;i<16;i=i+1) begin
                                u4[i] <= (skip && (!stage2[0])) ? 0 : u4[i];
                                u5[i] <= (stage2[0]) ? u4[i] : u5[i];
                            end 
                        end
                        else if (stage2[0]) begin
                            for (i=0;i<16;i=i+1) begin
                                u5[i] <= 0 ^ u4[i] ;
                                u5[i+16] <= 0;
                            end
                        end
                        else begin
                            for (i=0;i<16;i=i+1) begin
                                u5[i] <= u4[i] ^ u5[i];
                                u5[i+16] <= u4[i];
                            end 
                        end 
                    end
                    3: begin
                        if (!next_stage)begin
                            for (i=0;i<8;i=i+1) begin
                                u3[i] <= (skip && (!stage3[0])) ? 0 : u3[i];
                                u4[i] <= (stage3[0]) ? u3[i] : u4[i];
                            end 
                        end
                        else if (stage3[0]) begin
                            for (i=0;i<8;i=i+1) begin
                                u4[i] <= 0 ^ u3[i];
                                u4[i+8] <= 0;
                            end
                        end
                        else begin
                            for (i=0;i<8;i=i+1) begin
                                u4[i] <= u3[i] ^ u4[i];
                                u4[i+8] <= u3[i];
                            end  
                        end
                    end
                    4: begin
                        if (!next_stage)begin
                            for (i=0;i<4;i=i+1) begin
                                u2[i] <= (skip && (!stage4[0])) ? 0 : u2[i];
                                u3[i] <= (stage4[0]) ? u2[i] : u3[i];
                            end 
                        end
                        else if (stage4[0]) begin
                            for (i=0;i<4;i=i+1) begin
                                u3[i] <= 0 ^ u2[i];
                                u3[i+4] <= 0;
                            end
                        end
                        else begin
                            for (i=0;i<4;i=i+1) begin
                                u3[i] <= u2[i] ^ u3[i];
                                u3[i+4] <= u2[i];
                            end 
                        end  
                    end
                    5: begin
                        if (!next_stage)begin
                            for (i=0;i<2;i=i+1) begin
                                u1[i] <= (skip && (!stage5[0])) ? 0 : u1[i];
                                u2[i] <= (stage5[0]) ? u1[i] : u2[i];
                            end 
                        end
                        else if (stage5[0]) begin
                            for (i=0;i<2;i=i+1) begin
                                u2[i] <= 0 ^ u1[i];
                                u2[i+2] <= 0;
                            end
                        end
                        else begin
                            for (i=0;i<2;i=i+1) begin
                                u2[i] <= u1[i] ^ u2[i];
                                u2[i+2] <= u1[i];
                            end 
                        end      
                    end
                    default: begin
                        u0 <= 0;
                        u1[0] <= 0;
                        u1[1] <= 0;
                        for (i=0;i<4;i=i+1) begin
                            u2[i] <= 0;
                        end
                        for (i=0;i<8;i=i+1) begin
                            u3[i] <= 0;
                        end
                        for (i=0;i<16;i=i+1)begin 
                            u4[i] <= 0;
                        end
                        for (i=0;i<32;i=i+1)begin 
                            u5[i] <= 0;
                        end
                        for (i=0;i<64;i=i+1) begin
                            u6[i] <= 0;
                        end
                        for (i=0;i<128;i=i+1) begin
                            u7[i] <= 0;
                        end
                        for (i=0;i<256;i=i+1) begin
                            u8[i] <= 0;
                        end 
                    end
                endcase
            end 
            else if (N == 256) begin
                case(stage)
                    0: begin
                        u0 <= 0;
                        u1[0] <= 0;
                        u1[1] <= 0;
                        for (i=0;i<4;i=i+1) begin
                            u2[i] <= 0;
                        end
                        for (i=0;i<8;i=i+1) begin
                            u3[i] <= 0;
                        end
                        for (i=0;i<16;i=i+1)begin 
                            u4[i] <= 0;
                        end
                        for (i=0;i<32;i=i+1)begin 
                            u5[i] <= 0;
                        end
                        for (i=0;i<64;i=i+1) begin
                            u6[i] <= 0;
                        end
                        for (i=0;i<128;i=i+1) begin
                            u7[i] <= u7[i];
                        end
                        for (i=0;i<256;i=i+1) begin
                            u8[i] <= 0;
                        end        
                        end
                    1:begin
                        if (!next_stage)begin
                            for (i=0;i<64;i=i+1) begin
                                u6[i] <= (skip && (!stage1[0])) ? 0 : u6[i];
                                u7[i] <= (stage1[0]) ? u6[i] : u7[i];
                            end 
                        end   
                        else if (stage1[0]) begin
                            for (i=0;i<64;i=i+1) begin
                                u7[i] <= u6[i] ^ 0;
                                u7[i+64] <= 0;
                            end
                        end
                        else begin
                            for (i=0;i<64;i=i+1) begin
                                u7[i] <= u7[i] ^ u6[i];
                                u7[i+64] <= u6[i];
                            end 
                        end  
                    end
                    2:begin
                        if (!next_stage)begin
                            for (i=0;i<32;i=i+1) begin
                                u5[i] <= (skip && (!stage2[0])) ? 0 : u5[i];
                                u6[i] <= (stage2[0]) ? u5[i] : u6[i];
                            end    
                        end
                        else if (stage2[0]) begin
                            for (i=0;i<32;i=i+1) begin
                                u6[i] <= u5[i] ^ 0;
                                u6[i+32] <= 0;
                            end
                        end
                        else begin
                            for (i=0;i<32;i=i+1) begin
                                u6[i] <= u6[i] ^ u5[i];
                                u6[i+32] <= u5[i];
                            end
                        end   
                    end
                    3:begin
                        if (!next_stage)begin
                            for (i=0;i<16;i=i+1) begin
                                u4[i] <= (skip && (!stage3[0])) ? 0 : u4[i];
                                u5[i] <= (stage3[0]) ? u4[i] : u5[i];
                            end 
                        end
                        else if (stage3[0]) begin
                            for (i=0;i<16;i=i+1) begin
                                u5[i] <= u4[i] ^ 0;
                                u5[i+16] <= 0;
                            end
                        end
                        else begin
                            for (i=0;i<16;i=i+1) begin
                                u5[i] <= u5[i] ^ u4[i];
                                u5[i+16] <= u4[i];
                            end 
                        end
                    end
                    4:begin
                        if (!next_stage)begin
                            for (i=0;i<8;i=i+1) begin
                                u3[i] <= (skip && (!stage4[0])) ? 0 : u3[i];
                                u4[i] <= (stage4[0]) ? u3[i] : u4[i];
                            end 
                        end 
                        else if (stage4[0]) begin
                            for (i=0;i<8;i=i+1) begin
                                u4[i] <= u3[i] ^ 0;
                                u4[i+8] <= 0;
                            end
                        end 
                        else begin
                            for (i=0;i<8;i=i+1) begin
                                u4[i] <= u4[i] ^ u3[i];
                                u4[i+8] <= u3[i];
                            end  
                        end 
                    end
                    5:begin
                        if (!next_stage)begin
                            for (i=0;i<4;i=i+1) begin
                                u2[i] <= (skip && (!stage5[0])) ? 0 : u2[i];
                                u3[i] <= (stage5[0]) ? u2[i] : u3[i];
                            end 
                        end
                        else if (stage5[0]) begin
                            for (i=0;i<4;i=i+1) begin
                                u3[i] <= u2[i] ^ 0;
                                u3[i+4] <= 0;
                            end
                        end
                        else begin
                            for (i=0;i<4;i=i+1) begin
                                u3[i] <= u3[i] ^ u2[i];
                                u3[i+4] <= u2[i];
                            end  
                        end 
                    end
                    6:begin
                       if (!next_stage)begin
                            for (i=0;i<2;i=i+1) begin
                                u1[i] <= (skip && (!stage6[0])) ? 0 : u1[i];
                                u2[i] <= (stage6[0]) ? u1[i] : u2[i];
                            end 
                        end
                        else if (stage6[0]) begin
                            for (i=0;i<2;i=i+1) begin
                                u2[i] <= u1[i] ^ 0;
                                u2[i+2] <= 0;
                            end
                        end
                        else begin
                            for (i=0;i<2;i=i+1) begin
                                u2[i] <= u2[i] ^ u1[i];
                                u2[i+2] <= u1[i];
                            end 
                        end  
                    end
                    default: begin
                        u0 <= 0;
                        u1[0] <= 0;
                        u1[1] <= 0;
                        for (i=0;i<4;i=i+1) begin
                            u2[i] <= 0;
                        end
                        for (i=0;i<8;i=i+1) begin
                            u3[i] <= 0;
                        end
                        for (i=0;i<16;i=i+1)begin 
                            u4[i] <= 0;
                        end
                        for (i=0;i<32;i=i+1)begin 
                            u5[i] <= 0;
                        end
                        for (i=0;i<64;i=i+1) begin
                            u6[i] <= 0;
                        end
                        for (i=0;i<128;i=i+1) begin
                            u7[i] <= 0;
                        end
                        for (i=0;i<256;i=i+1) begin
                            u8[i] <= 0;
                        end 
                    end
                endcase
            end 
            else begin
                case(stage)
                    0: begin
                           
                        u0 <= 0;
                        u1[0] <= 0;
                        u1[1] <= 0;
                        for (i=0;i<4;i=i+1) begin
                            u2[i] <= 0;
                        end
                        for (i=0;i<8;i=i+1) begin
                            u3[i] <= 0;
                        end
                        for (i=0;i<16;i=i+1)begin 
                            u4[i] <= 0;
                        end
                        for (i=0;i<32;i=i+1)begin 
                            u5[i] <= 0;
                        end
                        for (i=0;i<64;i=i+1) begin
                            u6[i] <= 0;
                        end
                        for (i=0;i<128;i=i+1) begin
                            u7[i] <= 0;
                        end
                        for (i=0;i<256;i=i+1) begin
                            u8[i] <= u8[i];
                        end  
                    end
                    1:begin
                        if (!next_stage)begin
                            for (i=0;i<128;i=i+1) begin
                                u7[i] <= (skip && (!stage1[0])) ? 0 : u7[i];
                                u8[i] <= (stage1[0]) ? u7[i] : u8[i];
                            end    
                        end
                        else if (stage1[0]) begin
                            for (i=0;i<128;i=i+1) begin
                                u8[i] <= u7[i] ^ 0;
                                u8[i+128] <= 0;
                            end
                        end
                        else begin
                            for (i=0;i<128;i=i+1) begin
                                u8[i] <= u8[i] ^ u7[i];
                                u8[i+128] <= u7[i];
                            end   
                        end
                    end
                    2:begin
                        if (!next_stage)begin
                            for (i=0;i<64;i=i+1) begin
                                u6[i] <= (skip && (!stage2[0])) ? 0 : u6[i];
                                u7[i] <= (stage2[0]) ? u6[i] : u7[i];
                            end    
                        end
                        else if (stage2[0]) begin
                            for (i=0;i<64;i=i+1) begin
                                u7[i] <= u6[i] ^ 0;
                                u7[i+64] <= 0;
                            end
                        end
                        else begin
                            for (i=0;i<64;i=i+1) begin
                                u7[i] <= u7[i] ^ u6[i];
                                u7[i+64] <= u6[i];
                            end 
                        end  
                    end
                    3:begin
                        if (!next_stage)begin
                            for (i=0;i<32;i=i+1) begin
                                u5[i] <= (skip && (!stage3[0])) ? 0 : u5[i];
                                u6[i] <= (stage3[0]) ? u5[i] : u6[i];
                            end    
                        end
                        else if (stage3[0]) begin
                            for (i=0;i<32;i=i+1) begin
                                u6[i] <= u5[i] ^ 0;
                                u6[i+32] <= 0;
                            end
                        end
                        else begin
                            for (i=0;i<32;i=i+1) begin
                                u6[i] <= u6[i] ^ u5[i];
                                u6[i+32] <= u5[i];
                            end  
                        end 
                    end
                    4:begin
                        if (!next_stage)begin
                            for (i=0;i<16;i=i+1) begin
                                u4[i] <= (skip && (!stage4[0])) ? 0 : u4[i];
                                u5[i] <= (stage4[0]) ? u4[i] : u5[i];
                            end 
                        end
                        else if (stage4[0]) begin
                            for (i=0;i<16;i=i+1) begin
                                u5[i] <= u4[i] ^ 0;
                                u5[i+16] <= 0;
                            end
                        end
                        else begin
                            for (i=0;i<16;i=i+1) begin
                                u5[i] <= u5[i] ^ u4[i];
                                u5[i+16] <= u4[i];
                            end 
                        end
                    end
                    5:begin
                        if (!next_stage)begin
                            for (i=0;i<8;i=i+1) begin
                                u3[i] <= (skip && (!stage5[0])) ? 0 : u3[i];
                                u4[i] <= (stage5[0]) ? u3[i] : u4[i];
                            end 
                        end
                        else if (stage5[0])begin 
                            for (i=0;i<8;i=i+1) begin
                                u4[i] <= u3[i] ^ 0;
                                u4[i+8] <= 0;
                            
                            end
                        end
                        else begin
                            for (i=0;i<8;i=i+1) begin
                                u4[i] <= u4[i] ^ u3[i];
                                u4[i+8] <= u3[i];
                            end  
                        end
                    end
                    6:begin
                        if (!next_stage)begin
                            for (i=0;i<4;i=i+1) begin
                                u2[i] <= (skip && (!stage6[0])) ? 0 : u2[i];
                                u3[i] <= (stage6[0]) ? u2[i] : u3[i];
                            end 
                        end
                        else if (stage6[0]) begin
                            for (i=0;i<4;i=i+1) begin
                                u3[i] <= u2[i] ^ 0;
                                u3[i+4] <= 0;
                            end
                        end
                        else begin
                            for (i=0;i<4;i=i+1) begin
                                u3[i] <= u3[i] ^ u2[i];
                                u3[i+4] <= u2[i];
                            end  
                        end
                    end
                    7:begin
                        if (!next_stage)begin
                            for (i=0;i<2;i=i+1) begin
                                u1[i] <= (skip && (!stage7[0])) ? 0 : u1[i];
                                u2[i] <= (stage7[0]) ? u1[i] : u2[i];
                            end 
                            end
                        else if (stage7[0]) begin
                            for (i=0;i<2;i=i+1) begin
                                u2[i] <= u1[i] ^ 0;
                                u2[i+2] <= 0;
                            end
                            end
                        else begin
                            for (i=0;i<2;i=i+1) begin
                                u2[i] <= u2[i] ^ u1[i];
                                u2[i+2] <= u1[i];
                            end   
                            end
                    end
                    default: begin
                        u0 <= 0;
                        u1[0] <= 0;
                        u1[1] <= 0;
                        for (i=0;i<4;i=i+1) begin
                            u2[i] <= 0;
                        end
                        for (i=0;i<8;i=i+1) begin
                            u3[i] <= 0;
                        end
                        for (i=0;i<16;i=i+1)begin 
                            u4[i] <= 0;
                        end
                        for (i=0;i<32;i=i+1)begin 
                            u5[i] <= 0;
                        end
                        for (i=0;i<64;i=i+1) begin
                            u6[i] <= 0;
                        end
                        for (i=0;i<128;i=i+1) begin
                            u7[i] <= 0;
                        end
                        for (i=0;i<256;i=i+1) begin
                            u8[i] <= 0;
                        end
                    end
            endcase
            end
        end else begin
            u0 <= 0;
            u1[0] <= 0;
            u1[1] <= 0;
            for (i=0;i<4;i=i+1) begin
                u2[i] <= 0;
            end
            for (i=0;i<8;i=i+1) begin
                u3[i] <= 0;
            end
            for (i=0;i<16;i=i+1)begin 
                u4[i] <= 0;
            end
            for (i=0;i<32;i=i+1)begin 
                u5[i] <= 0;
            end
            for (i=0;i<64;i=i+1) begin
                u6[i] <= 0;
            end
            for (i=0;i<128;i=i+1) begin
                u7[i] <= 0;
            end
            for (i=0;i<256;i=i+1) begin
                u8[i] <= 0;
            end
        end
    end
///////////////////////////////////////////here 2/////////////////////////////////////////////////////////////////////////
    

//-----------------------------------generate----------------------------------
    
    //input_u
        always@(*) begin
            if ((stt_c==`DATA_DEC) && (read_end==1) && (N == 128))
                case(stage)
                    0: begin
                        if (!stage0)
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = u6[(stage_c *16) + i];
                            end
                    end
                    1: begin
                        if (!stage1[0])
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = u5[(stage_c *16) + i];
                            end
                    end
                    2: begin
                        if (!stage2[0])
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = u4[i];
                            end
                    end
                    3: begin
                        if (!stage3[0])
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else begin
                            for (i=0;i<8;i=i+1) begin
                                input_u[i] = u3[i];
                            end
                            for (i=8;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        end
                    end
                    4: begin
                        if (!stage4[0])
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else begin
                            for (i=0;i<4;i=i+1) begin
                                input_u[i] = u2[i];
                            end
                            for (i=4;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        end
                    end
                    5: begin
                        if (!stage5[0])
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else begin
                            for (i=0;i<2;i=i+1) begin
                                input_u[i] = u1[i];
                            end
                            for (i=2;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        end
                    end
                    6: begin
                        if (!stage6[0])
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = u0;
                            end
                    end
                    default: begin
                        for (i=0;i<16;i=i+1) begin
                            input_u[i] = 0;
                        end
                    end
                endcase
            else if ((stt_c==`DATA_DEC) && (read_end==1) && (N == 256))
                case(stage)
                    0: begin
                        if (!stage0)
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = u7[(stage_c *16) + i];
                            end
                    end
                    1: begin
                        if (!stage1[0])
                            for (i=0;i<16;i=i+1) begin
                            input_u[i] = 0;
                            end
                        else
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = u6[(stage_c *16) + i];
                            end
                    end
                    2: begin
                        if (!stage2[0])
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = u5[(stage_c *16) + i];
                            end
                    end
                    3: begin
                        if (!stage3[0])
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = u4[i];
                            end
                    end
                    4: begin
                        if (!stage4[0])
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else begin
                            for (i=0;i<8;i=i+1) begin
                                input_u[i] = u3[i];
                            end
                            for (i=8;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        end
                    end
                    5: begin
                        if (!stage5[0])
                            for (i=0;i<16;i=i+1) begin
                            input_u[i] = 0;
                            end
                        else begin
                            for (i=0;i<4;i=i+1) begin
                                input_u[i] = u2[i];
                            end
                            for (i=4;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        end
                    end
                    6: begin
                        if (!stage6[0])
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else begin
                            for (i=0;i<2;i=i+1) begin
                                input_u[i] = u1[i];
                            end
                            for (i=2;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        end
                    end
                    7: begin
                        if (!stage7[0])
                            for (i=0;i<16;i=i+1) begin
                            input_u[i] = 0;
                            end
                        else
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = u0;
                            end
                    end
                    default: begin
                        for (i=0;i<16;i=i+1) begin
                            input_u[i] = 0;
                        end
                    end
                endcase
            else if ((stt_c==`DATA_DEC) && (read_end==1) && (N == 512))
                case(stage)
                    0: begin
                        if (!stage0)
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = u8[(stage_c *16) + i];
                            end
                    end
                    1: begin
                        if (!stage1[0])
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = u7[(stage_c *16) + i];
                            end
                    end
                    2: begin
                        if (!stage2[0])
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = u6[(stage_c *16) + i];
                            end
                    end
                    3: begin
                        if (!stage3[0])
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = u5[(stage_c *16) + i];
                            end
                    end
                    4: begin
                        if (!stage4[0])
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = u4[i];
                            end
                    end
                    5: begin
                        if (!stage5[0])
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else begin
                            for (i=0;i<8;i=i+1) begin
                                input_u[i] = u3[i];
                            end
                            for (i=8;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        end
                    end
                    6: begin
                        if (!stage6[0])
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else begin
                            for (i=0;i<4;i=i+1) begin
                                input_u[i] = u2[i];
                            end
                            for (i=4;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        end
                    end
                    7: begin
                        if (!stage7[0])
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else begin
                            for (i=0;i<2;i=i+1) begin
                                input_u[i] = u1[i];
                            end
                            for (i=2;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        end
                    end
                    8: begin
                        if (!stage8[0])
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = 0;
                            end
                        else
                            for (i=0;i<16;i=i+1) begin
                                input_u[i] = u0;
                            end
                    end
                    default: begin
                        for (i=0;i<16;i=i+1) begin
                            input_u[i] = 0;
                        end
                    end
                endcase
            else
                for (i=0;i<16;i=i+1) begin
                    input_u[i] = 0;
                end
        end



    //sel
        always@(*) begin
            if (stt_c==`DATA_DEC && read_end==1)
                case(stage)
                    0: sel = stage0;
                    1: sel = stage1[0];
                    2: sel = stage2[0];
                    3: sel = stage3[0];
                    4: sel = stage4[0];
                    5: sel = stage5[0];
                    6: sel = stage6[0];
                    7: sel = stage7[0];
                    8: sel = stage8[0];
                    default: sel = 0;
                endcase
            else
                sel = 0;
        end




//-------------------h_out--------------------

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        u_ctr <= 0;
    end
    else begin
        if ((stt_c==`DATA_DEC) && read_end)begin
            if (stage == total_stage) u_ctr <= (skip) ? u_ctr : u_ctr + 1;
            else u_ctr <= u_ctr;
        end
        else begin
            u_ctr <= 0;
        end
    end
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        u <= 0;
    end
    else begin
        if((stt_c==`DATA_DEC) && read_end)begin
            if (stage == total_stage) begin
                u[u_ctr] <= (!skip) ? (output_sign[0]) : u[u_ctr];
            end else begin
                u<=u;
            end
        end
        else u <= 0;
    end
end

//PE input output //Take the magnitude from LLR_A,LLR_B or out_s0~out_s7, sign_s0~sign_s7
// generate input_mag & sign & PE
    always@(*)begin 
        case(stage)
            0:begin
                for (i=0;i<16;i=i+1) begin
                    LLR_A_abs[i] =  (LLR_A[stage_c][((i<<2)+(i<<3))+11]) ? ((~LLR_A[stage_c][((i<<2)+(i<<3))+:11]) + 1) : LLR_A[stage_c][((i<<2)+(i<<3))+:11];
                    LLR_B_abs[i] = (LLR_B[stage_c][((i<<2)+(i<<3))+11]) ? ((~LLR_B[stage_c][((i<<2)+(i<<3))+:11]) + 1) : LLR_B[stage_c][((i<<2)+(i<<3))+:11];
                end
                for (i=0;i<16;i=i+1) begin
                    sign_a[i] = LLR_A[stage_c][((i<<2)+(i<<3))+11];
                    sign_b[i] = LLR_B[stage_c][((i<<2)+(i<<3))+11];
                end
                for (i=0;i<16;i=i+1) begin
                    abs_a[i] = {8'b0, LLR_A_abs[i]};
                    abs_b[i] = {8'b0, LLR_B_abs[i]};
                end
                
            end
            1:begin
                
                for (i=0;i<16;i=i+1) begin                                
                     abs_a[i] = out_s0[stage_c][i];       
                     abs_b[i] = out_s0[stage_c+(N>>6)][i];
                     sign_a[i] = sign_s0[stage_c][i];
                     sign_b[i] = sign_s0[stage_c+(N>>6)][i];
                end
                
            end
            2:begin
                
                for (i=0;i<16;i=i+1) begin                                  
                     abs_a[i] = out_s1[stage_c][i];
                     abs_b[i] = out_s1[stage_c+(N>>7)][i];  
                     sign_a[i] = sign_s1[stage_c][i];
                     sign_b[i] = sign_s1[stage_c+(N>>7)][i];
                end
                
            end
            3:begin
                if (N=='d128)begin
                    
                    for (i=0;i<8;i=i+1) begin
                         abs_a[i] = out_s2[0][i];
                         abs_b[i] = out_s2[0][i+8];
                         sign_a[i] = sign_s2[0][i];
                         sign_b[i] = sign_s2[0][i+8];
                    end
                    
                    //8 PE unknown? (delete?)
                    for (i=8;i<16;i=i+1) begin
                         abs_a[i] = 0;
                         abs_b[i] = 0;
                         sign_a[i] = 0;
                         sign_b[i] = 0;
                    end
                end
                else begin //N = 256, 512
                    
                    for (i=0;i<16;i=i+1) begin
                         abs_a[i] = out_s2[stage_c][i];
                         abs_b[i] = out_s2[stage_c+(N>>8)][i];
                         sign_a[i] = sign_s2[stage_c][i];
                         sign_b[i] = sign_s2[stage_c+(N>>8)][i];
                    end
                    
                end
            end
            4:begin
                if(N==512)begin
                    for (i=0;i<16;i=i+1) begin
                         abs_a[i] = out_s3[stage_c][i];
                         abs_b[i] = out_s3[stage_c+1][i];
                         sign_a[i] = sign_s3[stage_c][i];
                         sign_b[i] = sign_s3[stage_c+1][i];
                    end
                    
                end
                else begin
                    if(N==256)begin
                        for (i=0;i<8;i=i+1) begin
                            abs_a[i] = out_s3[0][i];
                            abs_b[i] = out_s3[0][i+(N>>5)];
                            sign_a[i] = sign_s3[0][i];
                            sign_b[i] = sign_s3[0][i+(N>>5)];
                        end
                        for (i=8;i<16;i=i+1) begin
                            abs_a[i] = 0;
                            abs_b[i] = 0;
                            sign_a[i] = 0;
                            sign_b[i] = 0;
                        end
                    end
                    else begin//128
                        for (i=0;i<4;i=i+1) begin
                            sign_a[i] = sign_s3[0][i];
                            sign_b[i] = sign_s3[0][i+(N>>5)];
                        end
                        for (i=0;i<4;i=i+1) begin
                            abs_a[i] = out_s3[0][i];
                            abs_b[i] = out_s3[0][i+(N>>5)];
                        end
                        for (i=4;i<16;i=i+1) begin
                            abs_a[i] = 0;
                            abs_b[i] = 0;
                        end
                        for (i=4;i<16;i=i+1) begin
                            sign_a[i] = 0;
                            sign_b[i] = 0;
                        end
                    end
                end
                
            end
            5:begin
                if(N==512)begin
                    for (i=0;i<8;i=i+1) begin
                            abs_a[i] = out_s4[i];
                            abs_b[i] = out_s4[i+(N>>6)];
                            sign_a[i] = sign_s4[i];
                            sign_b[i] = sign_s4[i+(N>>6)];
                        end
                    for (i=8;i<16;i=i+1) begin
                            abs_a[i] = 0;
                            abs_b[i] = 0;
                            sign_a[i] = 0;
                            sign_b[i] = 0;
                        end
                end
                else begin
                    if(N==256)begin
                        for (i=0;i<4;i=i+1) begin
                            abs_a[i] = out_s4[i];
                            abs_b[i] = out_s4[i+(N>>6)];
                            sign_a[i] = sign_s4[i];
                            sign_b[i] = sign_s4[i+(N>>6)];
                        end
                        for (i=4;i<16;i=i+1) begin
                            abs_a[i] = 0;
                            abs_b[i] = 0;
                            sign_a[i] = 0;
                            sign_b[i] = 0;
                        end    
                    end
                    else begin//N=128
                        for (i=0;i<2;i=i+1) begin
                            abs_a[i] = out_s4[i];
                            abs_b[i] = out_s4[i+(N>>6)];
                            sign_a[i] = sign_s4[i];
                            sign_b[i] = sign_s4[i+(N>>6)];
                        end
                        for (i=2;i<16;i=i+1) begin
                            abs_a[i] = 0;
                            abs_b[i] = 0;
                            sign_a[i] = 0;
                            sign_b[i] = 0;
                        end    
                    end

                end
                
            end
            6:begin
                if(N==128)begin
                    for (i=0;i<1;i=i+1) begin
                        abs_a[i] = out_s5[i];
                        abs_b[i] = out_s5[i+(N>>7)];
                        sign_a[i] = sign_s5[i];
                        sign_b[i] = sign_s5[i+(N>>7)];
                    end
                    for (i=1;i<16;i=i+1) begin
                        abs_a[i] = 0;
                        abs_b[i] = 0;
                        sign_a[i] = 0;
                        sign_b[i] = 0;
                        end   
                end
                else if (N==256)begin
                    for (i=0;i<2;i=i+1) begin
                        abs_a[i] = out_s5[i];
                        abs_b[i] = out_s5[i+(N>>7)];
                        sign_a[i] = sign_s5[i];
                        sign_b[i] = sign_s5[i+(N>>7)];
                    end
                    for (i=2;i<16;i=i+1) begin
                        abs_a[i] = 0;
                        abs_b[i] = 0;
                        sign_a[i] = 0;
                        sign_b[i] = 0;
                        end   
                end
                else begin//512
                    for (i=0;i<4;i=i+1) begin
                        abs_a[i] = out_s5[i];
                        abs_b[i] = out_s5[i+(N>>7)];
                        sign_a[i] = sign_s5[i];
                        sign_b[i] = sign_s5[i+(N>>7)];
                    end
                    for (i=4;i<16;i=i+1) begin
                        abs_a[i] = 0;
                        abs_b[i] = 0;
                        sign_a[i] = 0;
                        sign_b[i] = 0;
                        end   
                end
                
            end
            7:begin //N=256, N=512
                //128 bits X
                if (N==256)begin
                    for (i=0;i<1;i=i+1) begin
                        abs_a[i] = out_s6[i];
                        abs_b[i] = out_s6[i+(N>>8)];
                        sign_a[i] = sign_s6[i];
                        sign_b[i] = sign_s6[i+(N>>8)];
                    end
                    for (i=1;i<16;i=i+1) begin
                        abs_a[i] = 0;
                        abs_b[i] = 0;
                        sign_a[i] = 0;
                        sign_b[i] = 0;
                        end   
                end
                else  begin//512
                    for (i=0;i<2;i=i+1) begin
                        abs_a[i] = out_s6[i];
                        abs_b[i] = out_s6[i+(N>>8)];
                        sign_a[i] = sign_s6[i];
                        sign_b[i] = sign_s6[i+(N>>8)];
                    end
                    for (i=2;i<16;i=i+1) begin
                        abs_a[i] = 0;
                        abs_b[i] = 0;
                        sign_a[i] = 0;
                        sign_b[i] = 0;
                        end   
                end
    
            end
            8:begin 
                    abs_a[0] = out_s7[0];
                    abs_b[0] = out_s7[1];
                    sign_a[0] = sign_s7[0];
                    sign_b[0] = sign_s7[1];
                    for (i=1;i<16;i=i+1) begin
                        abs_a[i] =  0;
                        abs_b[i] =  0;
                        sign_a[i] = 0;
                        sign_b[i] = 0;
                    end
            end
            default:begin
                for (i=0;i<16;i=i+1) begin
                    abs_a[i] = 0;
                    abs_b[i] = 0;
                    sign_a[i] = 0;
                    sign_b[i] = 0;
                end
                
            end
        endcase
    end
    // endgenerate
    genvar gen_i;
    generate 
        for (gen_i=0;gen_i<16;gen_i=gen_i+1) begin
            PE u_PE(.mag_a(abs_a[gen_i]),
                    .sign_a(sign_a[gen_i]),
                    .mag_b(abs_b[gen_i]),
                    .sign_b(sign_b[gen_i]),
                    .sign_out(output_sign[gen_i]),
                    .mag_out(output_mag[gen_i]),
                    .u(input_u[gen_i]),
                    .sel(sel));
        end 
    endgenerate

//--------------------------------------stage_c-------------------------------------
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        stage_c <= 0;
    else begin
        if (stage_c == addr_end)
            stage_c <= 0;
        else if (stt_c==`DATA_DEC && read_end==1)
            stage_c <= (skip || next_stage) ? 0: stage_c+1;
        else
            stage_c <= 0;
    end
end
//--------------------------------------addr_end ----------------------------------
always@(*) begin
    if (stt_c==`DATA_DEC && read_end==1)begin
        case(stage)
            0: addr_end = (N == 512) ? 15 : ((N == 256) ?  7 : ((N == 128) ? 3 : 0));
            1: addr_end = (N == 512) ? 7 :  ((N == 256) ?  3 : ((N == 128) ? 1 : 0));
            2: addr_end = (N == 512) ? 3 :  ((N == 256) ?  1 : 0);
            3: addr_end = (N == 512) ? 1 :  0;
            default: addr_end = 0;
        endcase
    end
    else begin
        addr_end = 0;
    end
end

always@(posedge clk or negedge rst_n)begin//s0
    if(!rst_n) begin
        for (i=0;i<16;i=i+1) begin
            for (j=0;j<16;j=j+1)begin
                out_s0[i][j] <= 0;
                sign_s0[i][j] <= 0;
            end
        end
    end 
    else begin
        if(stage==0 && !skip && read_end && (!next_stage))begin
            for (i=0;i<16;i=i+1) begin
                out_s0[stage_c][i] <= output_mag[i];
                sign_s0[stage_c][i] <= output_sign[i];
            end
        end
        else
            for (i=0;i<16;i=i+1) begin
                for (j=0;j<16;j=j+1)begin
                    out_s0[i][j] <= out_s0[i][j];
                    sign_s0[i][j] <= sign_s0[i][j];
                end
            end
    end
end 
always@(posedge clk or negedge rst_n)begin//s1
    if(!rst_n) begin
        for (i=0;i<16;i=i+1) begin
            for (j=0;j<16;j=j+1)begin
                out_s1[i][j] <= 0;
                sign_s1[i][j] <= 0;
            end
        end
    end 
    else begin
        if(stage==1 && !skip && read_end && (!next_stage))begin
            for (i=0;i<16;i=i+1) begin 
                out_s1[stage_c][i] <= output_mag[i];
                sign_s1[stage_c][i] <= output_sign[i];
            end
        end
        else
            for (i=0;i<16;i=i+1) begin
                for (j=0;j<16;j=j+1)begin
                    out_s1[i][j] <= out_s1[i][j];
                    sign_s1[i][j] <= sign_s1[i][j];
                end
            end
    end
end 
always@(posedge clk or negedge rst_n)begin
    if(!rst_n) begin
        for (i=0;i<16;i=i+1) begin
            for (j=0;j<16;j=j+1)begin
                out_s2[i][j] <= 0;
                sign_s2[i][j] <= 0;
            end
        end
    end 
    else begin
        if(stage==2 && !skip && read_end && (!next_stage))begin
            for (i=0;i<16;i=i+1) begin 
                out_s2[stage_c][i] <= output_mag[i];
                sign_s2[stage_c][i] <= output_sign[i];
            end
        end
        else begin
            for (i=0;i<16;i=i+1) begin
                for (j=0;j<16;j=j+1)begin
                    out_s2[i][j] <= out_s2[i][j];
                    sign_s2[i][j] <= sign_s2[i][j];
                end
            end
        end
    end
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n) begin
        for (i=0;i<16;i=i+1) begin
            for (j=0;j<16;j=j+1)begin
                out_s3[i][j] <= 0;
                sign_s3[i][j] <= 0;
            end
        end
    end 
    else begin
        if(stage==3 && !skip && read_end && (!next_stage))
            if(N==512)begin
                for (i=0;i<16;i=i+1) begin
                    out_s3[stage_c][i] <= output_mag[i];
                    sign_s3[stage_c][i] <= output_sign[i];
                end
            end
            else begin
                if(N==256)
                    for (i=0;i<16;i=i+1) begin 
                        out_s3[0][i] <= output_mag[i]; 
                        sign_s3[0][i] <= output_sign[i];
                    end
                else //128
                    for (i=0;i<8;i=i+1) begin 
                        out_s3[0][i] <= output_mag[i]; 
                        sign_s3[0][i] <= output_sign[i]; 
                    end
            end
        else begin
            for (i=0;i<16;i=i+1) begin
                for (j=0;j<16;j=j+1)begin
                    out_s3[i][j] <= out_s3[i][j];
                    sign_s3[i][j] <= sign_s3[i][j];
                end
            end
        end
        
    end
end 
always@(posedge clk or negedge rst_n)begin//s4
    if(!rst_n) begin
        for (i=0;i<16;i=i+1) begin
            out_s4[i] <= 0;
            sign_s4[i] <= 0;
        end
    end 
    else begin
        if(stage==4 && !skip && read_end && (!next_stage))
            for (i=0;i<(N>>5);i=i+1) begin 
                out_s4[i] <= output_mag[i]; 
                sign_s4[i] <= output_sign[i]; 
            end
        else
            for (i=0;i<16;i=i+1) begin
            out_s4[i] <= out_s4[i];
            sign_s4[i] <= sign_s4[i];
        end
    end
end 
always@(posedge clk or negedge rst_n)begin//s5
    if(!rst_n) begin
        for (i=0;i<8;i=i+1) begin
            out_s5[i] <= 0;
            sign_s5[i] <= 0;
        end
    end 
    else begin
        if(stage==5 && !skip && read_end && (!next_stage))
            for (i=0;i<(N>>6);i=i+1) begin 
                out_s5[i] <= output_mag[i]; 
                sign_s5[i] <= output_sign[i]; 
            end
        else
            for (i=0;i<8;i=i+1) begin
            out_s5[i] <= out_s5[i];
            sign_s5[i] <= sign_s5[i];
        end
    end
end 
//----------------------------stage 6 ----------------------------
always@(posedge clk or negedge rst_n)begin//s6
    if(!rst_n) begin
        for (i=0;i<4;i=i+1) begin
            out_s6[i] <= 0;
            sign_s6[i] <= 0;
        end
    end 
    else begin
        if(N==256 || N==512)begin
            if(stage==6 && !skip && read_end && (!next_stage))
                for (i=0;i<(N>>7);i=i+1) begin 
                    out_s6[i] <= output_mag[i]; 
                    sign_s6[i] <= output_sign[i]; 
                end
            else
                for (i=0;i<4;i=i+1) begin 
                    out_s6[i] <= out_s6[i]; 
                    sign_s6[i] <= sign_s6[i]; 
            end
        end
        else
            for (i=0;i<4;i=i+1) begin 
                out_s6[i] <= 0; 
                sign_s6[i] <= 0; 
            end
    
    end
end 
//----------------------------stage 7------------------------------
always@(posedge clk or negedge rst_n)begin//s6
    if(!rst_n) begin
        for (i=0;i<2;i=i+1) begin
            out_s7[i] <= 0;
            sign_s7[i] <= 0;
        end
    end else begin
        if(N==512)begin
            if(stage==7 && !skip && read_end && (!next_stage))
                for (i=0;i<(N>>8);i=i+1) begin 
                    out_s7[i] <= output_mag[i]; 
                    sign_s7[i] <= output_sign[i]; 
                end
            else
                for (i=0;i<16;i=i+1) begin 
                    out_s7[i] <= out_s7[i]; 
                    sign_s7[i] <= sign_s7[i];
            end
        end
        else begin//N=512
            for (i=0;i<2;i=i+1) begin
                out_s7[i] <= 0;
                sign_s7[i] <= 0;
            end
        end 
    end
end 



// -------------------------------read_end----------------------------
always@(posedge clk or negedge rst_n)begin
    if(!rst_n) begin
        read_end <= 0;
        dec_begin <= 0;
    end
    else begin
        if(stt_c==`DATA_DEC && reg_ctr==0 && dec_begin==1) begin
            read_end <= 1;
            dec_begin <= dec_begin;
        end
        else if(stt_c==`DATA_DEC) begin
            read_end <= 0;
            dec_begin <= 1;
        end
        else begin
            read_end <= 0;
            dec_begin <= 0;
        end
    end
end


//------------------------packet--------------------------
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        packet <= 0;
    else begin
        if(stt_c==`INFO && ctr == 1 && addr_r == 0)
            packet <= rdata;
        else
            packet <= packet;
    end
end

//--------------------------------num_p--------------------------
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        num_p <=0;
    else begin
        if (stt_c == `IDLE)
            num_p <= 0;
        else if (end_p)
            num_p <= num_p+1;
        else
            num_p <= num_p;
    end
end






//---------------------------dec_----------------------------------
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dec_ctr <= 0;
    else begin
        if (stt_c==`INFO && ctr == 2)
            dec_ctr <=0;
        else if(stt_c==`DATA_DEC && dec_ctr=='d31)begin
            dec_ctr <= dec_ctr;
        end
        else if(stt_c==`DATA_DEC && dec_begin==1 && addr_ctr==0)begin
            dec_ctr <= dec_ctr+1;
        end
        else begin
            dec_ctr <= dec_ctr;
        end
    end
end

//--------------------------LLR-----------------------------------
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)begin
        for(i=0;i<'d16;i=i+1)begin
            LLR_A[i]<=0;
            LLR_B[i] <= 0;
        end
    end 
    else begin
        if(stt_c==`DATA_DEC && addr_ctr==1 && reg_ctr==1)begin
            LLR_A[dec_ctr] <= rdata;
        end
        else if(stt_c==`DATA_DEC && addr_ctr==0 && reg_ctr==1)begin
            LLR_B[dec_ctr] <= rdata;
        end
        else begin
            for(i=0;i<'d16;i=i+1)begin
                LLR_A[i]<=LLR_A[i];
                LLR_B[i-1] <= LLR_B[i-1];
            end
        end
    end
end


    //reg_ctr
    always@(posedge clk or negedge rst_n)
    begin
        if(!rst_n)begin
            reg_ctr <=0;
        end
        else begin
            if(stt_c==`DATA_DEC && (dec_ctr==((N>>5)-1)) && addr_ctr==0)begin
                reg_ctr <=0;
            end
            else if(stt_c==`DATA_DEC && (dec_ctr<((N>>5))))begin
                reg_ctr <=1;
            end
            else
                reg_ctr <=0;
        end
    end

//----------------------end_p--------------------------
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        end_p <= 0;
    else begin
        if ((stt_c == `DATA_DEC) && (stage == total_stage))
            case(stage)
                6: end_p <= (stage6 == 127);
                7: end_p <= (stage7 == 255);
                8: end_p <= (stage8 == 511);
                default: end_p <= 0;
            endcase
        else
            end_p <= 0;
    end
end

    
//---------------------proc_done--------------------------
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        proc_done_r <= 0;
    else begin
        if (stt_c == `DATA_DEC)
            proc_done_r <= ((u_ctr == K) && (num_p == (packet - 1)));
        else
            proc_done_r <= 0;
    end
end


    
endmodule