// Register File, 32 registers

`include "src/head.v"
`ifndef RF_V
`define RF_V

module register_file (
    input clk,
    input rst,

    input en,  // full control

    // from decoder, come for values and qs
    input is_en_i,
    input is_ic_i,
    input [1:0] is_tp_i,
    input [`REG_BIT-1:0] is_rd_i,
    input [`REG_BIT-1:0] is_rs1_i,
    input [`REG_BIT-1:0] is_rs2_i,
    input [`OP_W-1:0] is_op_i,
    input [`DAT_W-1:0] is_imm_i,
    input [`RAM_ADR_W-1:0] is_pc_i,

    // from ROB, to revise
    input rob_en_i,
    input [`REG_BIT-1:0] rob_rd_i,
    input [`ROB_BIT-1:0] rob_q_i,
    input [`DAT_W-1:0] rob_v_i,
    input [`ROB_BIT-1:0] rob_qd_i,

    // to ROB
    output reg rob_en_o,
    output reg rob_ic_o,
    output reg rob_ls_o,  // 0 L 1 S 
    output reg [`ROB_BIT-1:0] rob_qj_o,
    output reg [`ROB_BIT-1:0] rob_qk_o,
    output reg [`DAT_W-1:0] rob_vj_o,
    output reg [`DAT_W-1:0] rob_vk_o,
    output reg [`ROB_BIT-1:0] rob_qd_o,
    output reg [`RAM_ADR_W-1:0] rob_pc_o,

    //RS 相关数据走个过场交给ROB，由ROB交给RS
    output reg [ `OP_W-1:0] rob_op_o,
    output reg [`DAT_W-1:0] rob_imm_o

    // 不需要接触CDB，因为只有ROB commit后才修改值
    // ALU依赖RS而不依赖RF，RS也不需要RF而只需要总线
);
  //该寄存器的值会被前面的指令更新，用该寄存器作为源操作数的需要等待CDB将更新后的值传输过来。
  reg [`ROB_BIT-1:0] q[`REG_S-1:0];
  reg [`ROB_BIT-1:0] busy[`REG_S-1:0];
  reg [`DAT_W-1:0] regs[`REG_S-1:0];
  integer i;

  always @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < 32; i = i + 1) begin
        regs[i] <= 0;
        q[i] <= 0;
        busy[i] <= 0;
      end
    end else if (en) begin
      // TODO 考虑ROB是否能此时顺利接受
      rob_en_o <= 0;

      if (rob_en_i) begin
        regs[rob_rd_i] <= rob_v_i;
        if (q[rob_rd_i] == rob_q_i) q[rob_rd_i] <= 0;
      end

      if (is_en_i) begin
        // passer-by
        rob_en_o   <= 1;
        rob_ic_o   <= is_ic_i;
        rob_ls_o   <= is_tp_i == 2'b10 || is_tp_i == 2'b01;
        rob_op_o   <= is_op_i;
        rob_imm_o  <= is_imm_i;
        rob_vj_o   <= regs[is_rs1_i];
        rob_vk_o   <= regs[is_rs2_i];
        rob_qj_o   <= q[is_rs1_i];
        rob_qk_o   <= q[is_rs2_i];
        rob_pc_o   <= is_pc_i;

        // rob_qd_i=rob's ctail
        rob_qj_o   <= q[is_rs1_i];
        rob_qk_o   <= q[is_rs2_i];
        q[is_rd_i] <= rob_qd_i;
        rob_qd_o   <= rob_qd_i;
      end
    end
  end

  always @(posedge clk) begin
    if (en) begin
      regs[0] <= 0;
      q[0] <= 0;
    end
  end
endmodule

`endif