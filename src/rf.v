// Register File, 32 registers

// 还没有对同步读写做适配
// 还没有与ROB联动

`include "utils/head.v"

module register_file (
    input clk,
    input rst,

    input en,  // full control

    // from ins_fetch issue, come for values and qs
    input is_en_i,
    input [`REG_BIT-1:0] is_rd_i,
    input [`REG_BIT-1:0] is_rs1_i,
    input [`REG_BIT-1:0] is_rs2_i,
    input [`OP_W-1:0] is_op_i,
    input [`DAT_W-1:0] is_imm_i,
    input [`ROB_BIT-1:0] is_rob_qd_i,

    // from ROB, to revise
    input rob_en_i,
    input [`REG_BIT-1:0] rob_rd_i,
    input [`ROB_BIT-1:0] rob_q_i,
    input [`DAT_W-1:0] rob_v_i,

    // to ROB
    output reg rob_en_o,
    output reg [`ROB_BIT-1:0] rob_qj_o,
    output reg [`ROB_BIT-1:0] rob_qk_o,
    output reg [`DAT_W-1:0] rob_vj_o,
    output reg [`DAT_W-1:0] rob_vk_o,
    output reg [`ROB_BIT-1:0] rob_qd_o,

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

  always @(posedge clk or negedge rst) begin
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
        rob_op_o   <= is_op_i;
        rob_imm_o  <= is_imm_i;
        rob_vj_o   <= regs[is_rs1_i];
        rob_vk_o   <= regs[is_rs2_i];

        rob_en_o   <= 1;

        rob_qj_o   <= q[is_rs1_i];
        rob_qk_o   <= q[is_rs2_i];

        // TODO 考虑rs=rd时的ROB id
        // issue先问rob要一个空位，为rd给一个新的rob id
        // 相当于rename
        rob_qj_o   <= q[is_rs1_i];
        rob_qk_o   <= q[is_rs2_i];
        q[is_rd_i] <= is_rob_qd_i;
        rob_qd_o   <= is_rob_qd_i;
      end
    end
  end

  always @(posedge clk or negedge rst) begin
    if (en) begin
      regs[0] <= 0;
      q[0] <= 0;
    end
  end
endmodule
