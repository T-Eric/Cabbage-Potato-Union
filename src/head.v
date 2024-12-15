  // constants definitions
`ifndef HEAD_H
`define HEAD_H
`define DAT_W 32

// Register
`define REG_DAT_W 32 // reg's storing data's width
`define REG_BIT 5
`define REG_S 32
// Instruction Cache
`define IC_S 64 // max cache item size
// Memory
`define RAM_ADR_W 17
// Reordered Buffer
`define ROB_S 32// 1-based
`define ROB_BIT 5
// Reservation Station
`define RS_S 32
`define RS_BIT 5
// Load-Store Buffer
`define LSB_S 32
`define LSB_BIT 5
// Instructions
`define OP_W 6
`define LUI 6'b000001
`define AUIPC 6'b000010
`define JAL 6'b000011
`define JALR 6'b000100
`define BEQ 6'b000101
`define BNE 6'b000110
`define BLT 6'b000111
`define BGE 6'b001000
`define BLTU 6'b001001
`define BGEU 6'b001010
`define LB 6'b001011// B
`define LH 6'b001100// C
`define LW 6'b001101// D
`define LBU 6'b001110// E
`define LHU 6'b001111// F
`define SB 6'b010000// 10
`define SH 6'b010001// 11
`define SW 6'b010010// 12
`define ADDI 6'b010011//13
`define SLLI 6'b010100
`define SLTI 6'b010101
`define SLTIU 6'b010110
`define XORI 6'b010111
`define SRLI 6'b011000
`define SRAI 6'b011001
`define ORI 6'b011010
`define ANDI 6'b011011
`define ADD 6'b011100
`define SUB 6'b011101
`define SLL 6'b011110
`define SLT 6'b011111
`define SLTU 6'b100000
`define XOR 6'b100001
`define SRL 6'b100010
`define SRA 6'b100011
`define OR 6'b100100
`define AND 6'b100101
`endif
