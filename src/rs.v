// Reservation Station
// Connect: ROB(in), LSB(in), ALU(io)
// Function: temp save stall instructions, wait for data to send to ALU

`include "src/head.v"
`ifndef RS_V
`define RS_V

module reser_station (
    input clk,
    input rst,
    input en,

    // from rob: one item
    input rob_en_i,
    input [`OP_W-1:0] rob_op_i,
    input rob_ic_i,  //0 I 1 C 
    input [`ROB_BIT-1:0] rob_qj_i,
    input [`ROB_BIT-1:0] rob_qk_i,
    input [`DAT_W-1:0] rob_vj_i,
    input [`DAT_W-1:0] rob_vk_i,
    input [`ROB_BIT-1:0] rob_qd_i,
    input [`DAT_W-1:0] rob_imm_i,
    input [`RAM_ADR_W-1:0] rob_pc_i,

    // from lsb/cdb: updator
    input lsb_en_i,
    input [`ROB_BIT-1:0] lsb_q_i,
    input [`DAT_W-1:0] lsb_v_i,
    input cdb_en_i,
    input [`ROB_BIT-1:0] cdb_q_i,
    input [`DAT_W-1:0] cdb_v_i,

    // to alu: calc
    output alu_en_o,
    output [`OP_W-1:0] alu_op_o,
    output alu_ic_o,
    output [`ROB_BIT-1:0] alu_qd_o,
    output [`DAT_W-1:0] alu_vs_o,
    output [`DAT_W-1:0] alu_vt_o,
    output [`DAT_W-1:0] alu_imm_o,
    output [`RAM_ADR_W-1:0] alu_pc_o,

    // branch
    input br_flag
);

  reg busy[`RS_S-1:0];
  wire send[`RS_S-1:0];
  reg [`OP_W-1:0] op[`RS_S-1:0];
  reg ic[`RS_S-1:0];
  reg [`DAT_W-1:0] vj[`RS_S-1:0];
  reg [`DAT_W-1:0] vk[`RS_S-1:0];
  reg [`DAT_W-1:0] imm[`RS_S-1:0];
  reg [`RAM_ADR_W-1:0] pc[`RS_S-1:0];
  reg [`ROB_BIT-1:0] qj[`RS_S-1:0];
  reg [`ROB_BIT-1:0] qk[`RS_S-1:0];
  reg [`ROB_BIT-1:0] qd[`RS_S-1:0];

  // TA启发：组合逻辑找第一个空entry，第一个可送entry
  // 参考https://zhuanlan.zhihu.com/p/647874179
  // 直接把alu_o连接到可送entry条目是可行且很快的
  wire [`RS_BIT-1:0] empty_one, send_one, empty_find[`RS_S:0], send_find[`RS_S:0];
  assign empty_find[0] = 0;
  assign send_find[0] = 0;
  assign empty_one = empty_find[`RS_S];
  assign send_one = send_find[`RS_S];
  assign alu_en_o = send[0] == 1 || send_one != 0;
  assign alu_op_o = op[send_one];
  assign alu_ic_o = ic[send_one];
  assign alu_qd_o = qd[send_one];
  assign alu_vs_o = vj[send_one];
  assign alu_vt_o = vk[send_one];
  assign alu_imm_o = imm[send_one];
  assign alu_pc_o = pc[send_one];

  genvar j;
  generate
    for (j = 0; j < `RS_S; j = j + 1) begin
      assign send[j] = busy[j] && qj[j] == 0 && qk[j] == 0;
      assign send_find[j+1] = send[j] ? j : send_find[j];
      assign empty_find[j+1] = busy[j] ? empty_find[j] : j;
    end
  endgenerate

  integer i;
  always @(posedge clk) begin
    if (rst || br_flag) begin
      for (i = 0; i < `RS_S; i = i + 1) begin
        busy[i] <= 0;
        op[i]   <= 0;
        ic[i]   <= 0;
        vj[i]   <= 0;
        vk[i]   <= 0;
        imm[i]  <= 0;
        qj[i]   <= 0;
        qk[i]   <= 0;
        qd[i]   <= 0;
        pc[i]   <= 0;
      end
    end else if (en) begin
      // non-load-store instruction
      if (rob_en_i) begin
        busy[empty_one] <= 1;
        op[empty_one]   <= rob_op_i;
        ic[empty_one]   <= rob_ic_i;
        vj[empty_one]   <= rob_vj_i;
        vk[empty_one]   <= rob_vk_i;
        imm[empty_one]  <= rob_imm_i;
        qj[empty_one]   <= rob_qj_i;
        qk[empty_one]   <= rob_qk_i;
        qd[empty_one]   <= rob_qd_i;
        pc[empty_one]   <= rob_pc_i;
      end

      // updators
      if (lsb_en_i) begin
        for (i = 0; i < `RS_S; i = i + 1) begin
          if (qj[i] == lsb_q_i) begin
            qj[i] <= 0;
            vj[i] <= lsb_v_i;
          end
          if (qk[i] == lsb_q_i) begin
            qk[i] <= 0;
            vk[i] <= lsb_v_i;
          end
        end
      end
      if (cdb_en_i) begin
        for (i = 0; i < `RS_S; i = i + 1) begin
          if (qj[i] == cdb_q_i) begin
            qj[i] <= 0;
            vj[i] <= cdb_v_i;
          end
          if (qk[i] == cdb_q_i) begin
            qk[i] <= 0;
            vk[i] <= cdb_v_i;
          end
        end
      end

      // given for alu
      if (alu_en_o) busy[send_one] = 0;
    end
  end

endmodule

`endif
