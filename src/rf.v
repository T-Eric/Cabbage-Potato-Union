// Register File, 32 registers
`include "src/head.v"
`ifndef RF_V
`define RF_V

// bug():太愚蠢了，居然没有设计错误跳转后的行为！
// 错误跳转前可能已经有错误的依赖，这在rob清空后永远得不到实现
// 但是跳转语句前的正确语句一定不会有依赖，跳转不创造依赖
// 这意味着清空依赖即可

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
    input [`DAT_W-1:0] is_pc_i,

    // from ROB, to revise
    input rob_en_i,
    input [`REG_BIT-1:0] rob_rd_i,
    input [`ROB_BIT-1:0] rob_q_i,
    input [`DAT_W-1:0] rob_v_i,
    input [`ROB_BIT-1:0] rob_qd_i,

    // from ROB, ready data pre-supply
    output [`ROB_BIT - 1:0] rob_reqqj_o,
    output [`ROB_BIT - 1:0] rob_reqqk_o,
    input rob_rdyj_i,
    input rob_rdyk_i,
    input [`DAT_W - 1:0] rob_rdyvj_i,
    input [`DAT_W - 1:0] rob_rdyvk_i,

    // to LSB
    output reg lsb_en_o,
    output [`OP_W - 1:0] lsb_op_o,
    output [`DAT_W - 1:0] lsb_imm_o,
    output [`ROB_BIT - 1:0] lsb_qj_o,
    output [`ROB_BIT - 1:0] lsb_qk_o,
    output [`DAT_W - 1:0] lsb_vj_o,
    output [`DAT_W - 1:0] lsb_vk_o,
    output [`ROB_BIT - 1:0] lsb_qd_o,

    // to RS
    output reg rs_en_o,
    output rs_ic_o,
    output [`OP_W - 1:0] rs_op_o,
    output [`DAT_W - 1:0] rs_imm_o,
    output [`ROB_BIT - 1:0] rs_qj_o,
    output [`ROB_BIT - 1:0] rs_qk_o,
    output [`DAT_W - 1:0] rs_vj_o,
    output [`DAT_W - 1:0] rs_vk_o,
    output [`ROB_BIT - 1:0] rs_qd_o,
    output [`DAT_W-1:0] rs_pc_o,

    // 同步更新数据，cdb不能直接修改寄存器值
    input cdb_en_i,
    input [`ROB_BIT - 1:0] cdb_q_i,
    input [`DAT_W - 1:0] cdb_v_i,

    input                  ldb_en_i,
    input [`ROB_BIT - 1:0] ldb_q_i,
    input [  `DAT_W - 1:0] ldb_v_i,

    input br_flag
);
  //该寄存器的值会被前面的指令更新，用该寄存器作为源操作数的需要等待CDB将更新后的值传输过来。
  reg [`ROB_BIT-1:0] q[`REG_S-1:0];
  reg [`DAT_W-1:0] regs[`REG_S-1:0];

  reg ic_o;
  reg [`OP_W - 1:0] op_o;
  reg [`DAT_W - 1:0] imm_o;
  reg [`ROB_BIT - 1:0] qj_o;
  reg [`ROB_BIT - 1:0] qk_o;
  reg [`DAT_W - 1:0] vj_o;
  reg [`DAT_W - 1:0] vk_o;
  reg [`ROB_BIT - 1:0] qd_o;
  reg [`DAT_W-1:0] pc_o;

  assign rs_ic_o = ic_o;
  assign rs_op_o = op_o;
  assign rs_imm_o = imm_o;
  assign rs_qj_o = qj_o;
  assign rs_qk_o = qk_o;
  assign rs_vj_o = vj_o;
  assign rs_vk_o = vk_o;
  assign rs_qd_o = qd_o;
  assign rs_pc_o = pc_o;

  assign lsb_op_o = op_o;
  assign lsb_imm_o = imm_o;
  assign lsb_qj_o = qj_o;
  assign lsb_qk_o = qk_o;
  assign lsb_vj_o = vj_o;
  assign lsb_vk_o = vk_o;
  assign lsb_qd_o = qd_o;

  assign rob_reqqj_o = q[is_rs1_i];
  assign rob_reqqk_o = q[is_rs2_i];

  integer i;
  always @(posedge clk) begin
    if (rst || br_flag) begin
      for (i = 0; i < 32; i = i + 1) begin
        if (rst) regs[i] <= 0;
        q[i] <= 0;
      end
      lsb_en_o <= 0;
      rs_en_o <= 0;
      ic_o <= 0;
      qj_o <= 0;
      qk_o <= 0;
      vj_o <= 0;
      vk_o <= 0;
      qd_o <= 0;
      pc_o <= 0;
      op_o <= 0;
      imm_o <= 0;
    end else if (en) begin
      //---debug---
      if (rob_en_i) begin
        $write("zr:%h\t", regs[0]);
        $write("ra:%h\t", regs[1]);
        $write("sp:%h\t", regs[2]);
        $write("gp:%h\t", regs[3]);
        $write("tp:%h\t", regs[4]);
        $write("t0:%h\t", regs[5]);
        $write("t1:%h\t", regs[6]);
        $write("t2:%h\t", regs[7]);
        $display("");
        $write("s0:%h\t", regs[8]);
        $write("s1:%h\t", regs[9]);
        $write("a0:%h\t", regs[10]);
        $write("a1:%h\t", regs[11]);
        $write("a2:%h\t", regs[12]);
        $write("a3:%h\t", regs[13]);
        $write("a4:%h\t", regs[14]);
        $write("a5:%h\t", regs[15]);
        $display("");
        $write("a6:%h\t", regs[16]);
        $write("a7:%h\t", regs[17]);
        $write("s2:%h\t", regs[18]);
        $write("s3:%h\t", regs[19]);
        $write("s4:%h\t", regs[20]);
        $write("s5:%h\t", regs[21]);
        $write("s6:%h\t", regs[22]);
        $write("s7:%h\t", regs[23]);
        $display("");
        $write("s8:%h\t", regs[24]);
        $write("s9:%h\t", regs[25]);
        $write("10:%h\t", regs[26]);
        $write("11:%h\t", regs[27]);
        $write("t3:%h\t", regs[28]);
        $write("t4:%h\t", regs[29]);
        $write("t5:%h\t", regs[30]);
        $write("t6:%h\t", regs[31]);
        $display("");
      end
      //---debug---
      lsb_en_o <= 0;
      rs_en_o  <= 0;

      if (rob_en_i) begin
        regs[rob_rd_i] <= rob_v_i;
        if (q[rob_rd_i] == rob_q_i) q[rob_rd_i] <= 0;
      end

      // opt：直接传给lsb和rs，何必给rob
      // 只需要在rob_en_i时换值就行了
      if (is_en_i) begin
        if (is_tp_i == 2'b10 || is_tp_i == 2'b01) lsb_en_o <= 1;
        else rs_en_o <= 1;
        ic_o <= is_ic_i;
        op_o <= is_op_i;
        imm_o <= is_imm_i;
        vj_o <= regs[is_rs1_i];
        vk_o <= regs[is_rs2_i];
        qj_o <= q[is_rs1_i];
        qk_o <= q[is_rs2_i];
        pc_o <= is_pc_i;

        q[is_rd_i] <= rob_qd_i;
        qd_o <= rob_qd_i;

        if (q[is_rs1_i] != 0) begin
          if (rob_en_i && rob_q_i == q[is_rs1_i]) begin
            qj_o <= 0;
            vj_o <= rob_v_i;
          end
          if (ldb_en_i && ldb_q_i == q[is_rs1_i]) begin
            qj_o <= 0;
            vj_o <= ldb_v_i;
          end
          if (cdb_en_i && cdb_q_i == q[is_rs1_i]) begin
            qj_o <= 0;
            vj_o <= cdb_v_i;
          end
          if (rob_rdyj_i) begin
            qj_o <= 0;
            vj_o <= rob_rdyvj_i;
          end
        end

        if (q[is_rs2_i] != 0) begin
          if (rob_en_i && rob_q_i == q[is_rs2_i]) begin
            qk_o <= 0;
            vk_o <= rob_v_i;
          end
          if (ldb_en_i && ldb_q_i == q[is_rs2_i]) begin
            qk_o <= 0;
            vk_o <= ldb_v_i;
          end
          if (cdb_en_i && cdb_q_i == q[is_rs2_i]) begin
            qk_o <= 0;
            vk_o <= cdb_v_i;
          end
          if (rob_rdyk_i) begin
            qk_o <= 0;
            vk_o <= rob_rdyvk_i;
          end
        end

      end

      q[0] <= 0;
      regs[0] <= 0;
    end
  end

  // ---debug---
  wire[`DAT_W-1:0]reg_zero, reg_ra, reg_sp, reg_gp, reg_tp, reg_t0, reg_t1, reg_t2, reg_s0, reg_s1, reg_a0, reg_a1, reg_a2, reg_a3, reg_a4, reg_a5, reg_a6, reg_a7, reg_s2, reg_s3, reg_s4, reg_s5, reg_s6, reg_s7, reg_s8, reg_s9, reg_s10, reg_s11, reg_t3, reg_t4, reg_t5, reg_t6;
  wire[`ROB_BIT-1:0]reg_zero_q, reg_ra_q, reg_sp_q, reg_gp_q, reg_tp_q, reg_t0_q, reg_t1_q, reg_t2_q, reg_s0_q, reg_s1_q, reg_a0_q, reg_a1_q, reg_a2_q, reg_a3_q, reg_a4_q, reg_a5_q, reg_a6_q, reg_a7_q, reg_s2_q, reg_s3_q, reg_s4_q, reg_s5_q, reg_s6_q, reg_s7_q, reg_s8_q, reg_s9_q, reg_s10_q, reg_s11_q, reg_t3_q, reg_t4_q, reg_t5_q, reg_t6_q;

  assign reg_zero = regs[0];
  assign reg_ra = regs[1];
  assign reg_sp = regs[2];
  assign reg_gp = regs[3];
  assign reg_tp = regs[4];
  assign reg_t0 = regs[5];
  assign reg_t1 = regs[6];
  assign reg_t2 = regs[7];
  assign reg_s0 = regs[8];
  assign reg_s1 = regs[9];
  assign reg_a0 = regs[10];
  assign reg_a1 = regs[11];
  assign reg_a2 = regs[12];
  assign reg_a3 = regs[13];
  assign reg_a4 = regs[14];
  assign reg_a5 = regs[15];
  assign reg_a6 = regs[16];
  assign reg_a7 = regs[17];
  assign reg_s2 = regs[18];
  assign reg_s3 = regs[19];
  assign reg_s4 = regs[20];
  assign reg_s5 = regs[21];
  assign reg_s6 = regs[22];
  assign reg_s7 = regs[23];
  assign reg_s8 = regs[24];
  assign reg_s9 = regs[25];
  assign reg_s10 = regs[26];
  assign reg_s11 = regs[27];
  assign reg_t3 = regs[28];
  assign reg_t4 = regs[29];
  assign reg_t5 = regs[30];
  assign reg_t6 = regs[31];

  assign reg_zero_q = q[0];
  assign reg_ra_q = q[1];
  assign reg_sp_q = q[2];
  assign reg_gp_q = q[3];
  assign reg_tp_q = q[4];
  assign reg_t0_q = q[5];
  assign reg_t1_q = q[6];
  assign reg_t2_q = q[7];
  assign reg_s0_q = q[8];
  assign reg_s1_q = q[9];
  assign reg_a0_q = q[10];
  assign reg_a1_q = q[11];
  assign reg_a2_q = q[12];
  assign reg_a3_q = q[13];
  assign reg_a4_q = q[14];
  assign reg_a5_q = q[15];
  assign reg_a6_q = q[16];
  assign reg_a7_q = q[17];
  assign reg_s2_q = q[18];
  assign reg_s3_q = q[19];
  assign reg_s4_q = q[20];
  assign reg_s5_q = q[21];
  assign reg_s6_q = q[22];
  assign reg_s7_q = q[23];
  assign reg_s8_q = q[24];
  assign reg_s9_q = q[25];
  assign reg_s10_q = q[26];
  assign reg_s11_q = q[27];
  assign reg_t3_q = q[28];
  assign reg_t4_q = q[29];
  assign reg_t5_q = q[30];
  assign reg_t6_q = q[31];
  // ---debug---
endmodule

`endif
