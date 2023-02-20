`ifndef DEFINE_V
`define DEFINE_V
    // opcode definition
    `define OP_LOAD             0
    `define OP_RIGHT            1
    `define OP_LEFT             2
    `define OP_UP               3
    `define OP_DOWN             4
    `define OP_RE_CHANNEL       5
    `define OP_IN_CHANNEL       6
    `define OP_CONV             7
    `define OP_PIXEL_DISPLAY    8
    //FSM
    `define IDLE                0
    `define START               1
    `define OP                  2
    `define LOADING             3
    `define CONV                4  
    `define CONV_DIS            5 
    `define WAITING             6
    `define DISPLAY             7
`endif

