//  OPCODE and parameter definitions

`define OPCODE      6:0
`define FUNC3       14:12
`define FUNC5       31:27
`define SUBTYPE     30
`define RD          11:7
`define RS1         19:15
`define RS2         24:20


localparam  [31: 0] NOP        = 32'h0000_0013;     // addi x0, x0, 0

// OPCODE, INST[6:0]
localparam  [ 6: 0] LUI     = 7'b0110111,        // U-type
                    AUIPC   = 7'b0010111,        // U-type
                    JAL     = 7'b1101111,        // J-type
                    JALR    = 7'b1100111,        // I-type
                    BRANCH  = 7'b1100011,        // B-type
                    LOAD    = 7'b0000011,        // I-type
                    STORE   = 7'b0100011,        // S-type
                    ARITHI  = 7'b0010011,        // I-type
                    ARITHR  = 7'b0110011,        // R-type
                    LOAD_FP = 7'b0000111,        // I-type (FP Load)
                    STORE_FP= 7'b0100111,        // S-type (FP Store)
                    OP_FP   = 7'b1010011;        // R-type (FP ALU)



// FUNC3, INST[14:12], INST[6:0] = 7'b1100011
localparam  [ 2: 0] BEQ     = 3'b000,
                    BNE     = 3'b001,
                    BLT     = 3'b100,
                    BGE     = 3'b101,
                    BLTU    = 3'b110,
                    BGEU    = 3'b111;

// FUNC3, INST[14:12], INST[6:0] = 7'b0000011
localparam  [ 2: 0] LB      = 3'b000,
                    LH      = 3'b001,
                    LW      = 3'b010,
                    LBU     = 3'b100,
                    LHU     = 3'b101;

// FUNC3, INST[14:12], INST[6:0] = 7'b0100011
localparam  [ 2: 0] SB      = 3'b000,
                    SH      = 3'b001,
                    SW      = 3'b010;
                    
// FUNC3, INST[14:12], INST[6:0] = 7'b0110011, 7'b0010011
localparam  [ 2: 0] ADD     = 3'b000,    // inst[30] == 0: ADD, inst[31] == 1: SUB
                    SLL     = 3'b001,
                    SLT     = 3'b010,
                    SLTU    = 3'b011,
                    XOR     = 3'b100,
                    SR      = 3'b101,    // inst[30] == 0: SRL, inst[31] == 1: SRA
                    OR      = 3'b110,
                    AND     = 3'b111;

// FUNC3 for RV32M (M-Extension)
localparam  [ 2: 0] MUL     = 3'b000,
                    MULH    = 3'b001,
                    MULHSU  = 3'b010,
                    MULHU   = 3'b011,
                    DIV     = 3'b100,
                    DIVU    = 3'b101,
                    REM     = 3'b110,
                    REMU    = 3'b111;

// SYSTEM Opcodes length
localparam  [ 6: 0] SYSTEM  = 7'b1110011;
localparam  [ 2: 0] PRIV    = 3'b000,
                    CSRRW   = 3'b001,
                    CSRRS   = 3'b010,
                    CSRRC   = 3'b011,
                    CSRRWI  = 3'b101,
                    CSRRSI  = 3'b110,
                    CSRRCI  = 3'b111;

// FUNC5 for RV32F (F-Extension) - INST[31:27]
localparam  [ 4: 0] FADD_S   = 5'b00000,
                    FSUB_S   = 5'b00001,
                    FMUL_S   = 5'b00010,
                    FDIV_S   = 5'b00011,
                    FSQRT_S  = 5'b01011,
                    FCVT_W_S = 5'b11000,
                    FCVT_S_W = 5'b11010,
                    FMV_X_W  = 5'b11100,
                    FMV_W_X  = 5'b11110,
                    FCMP_S   = 5'b10100;

// FUNC3 for RV32F (Loads/Stores) - INST[14:12]
localparam  [ 2: 0] FLW_FSW  = 3'b010;

