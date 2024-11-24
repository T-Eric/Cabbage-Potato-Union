// load-store buffer
// Function: FIFO sender, react with dc to store and load
`include "utils/head.v"

module load_store_buffer (
    input clk,
    input rst,
    input en,

    // from ROB: TODO: 先传入一切必要的信息
    input rob_en_i,
    input [`OP_W - 1:0] rob_op_i,
    input [`DAT_W - 1:0] rob_imm_i,
    input [`ROB_BIT - 1:0] rob_qj_i,
    input [`ROB_BIT - 1:0] rob_qk_i,
    input [`DAT_W - 1:0] rob_vj_i,
    input [`DAT_W - 1:0] rob_vk_i,
    input [`ROB_BIT - 1:0] rob_qd_i,

    // Visit Memory
    output reg                     dc_en_o,
    output reg                    dc_rwen_o,   // 0:R, 1:W
    output reg  [             2:0] dc_len_o,  // 1:B; 2:H; 4:W
    output reg  [`RAM_ADR_W - 1:0] dc_adr_o,
    output reg  [`DAT_W - 1:0] dc_dat_o,
    input                     dc_en_i,
    input  [`DAT_W - 1:0] dc_dat_i,

    // Output LOAD Result，可能与CDB冲突，先考虑不放在一起
    // 如果没有进一步操作，q和v不用reg
    output reg rs_en_o,
    output reg[`ROB_BIT - 1:0] rs_q_o,
    output reg[`DAT_W - 1:0] rs_v_o,

    output reg rob_en_o,
    output reg[`ROB_BIT - 1:0] rob_q_o,
    output reg[`DAT_W - 1:0] rob_v_o,

    // from CDB: Update Calculation Result Directly
    input cdb_en_i,
    input [`ROB_BIT - 1:0] cdb_q_i,
    input [`DAT_W - 1:0] cdb_v_i,

    // Commit STORE
    input rob_cmt_s_i,

    // ! Misprediction
    input rob_br_flag

    // TODO stall when full
);

endmodule
