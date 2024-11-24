// constants definitions
`ifndef HEAD_H
`define HEAD_H
`define DAT_W 32
`define OP_W 5
// Register
`define REG_DAT_W 32 // reg's storing data's width
`define REG_OP_W 5 // reg's imm or rs, rd's width
`define REG_BIT 5
`define REG_S 32
// Instruction Cache
`define IC_S 64 // max cache item size
// Memory
`define RAM_ADR_W 17
// Reordered Buffer
`define ROB_S 31// 1-based
`define ROB_BIT 5
// Reservation Station
`define RS_S 32
`define RS_BIT 5
// Instructions
`define INSSET_S 32
`define INSSET_BIT 5
`endif
