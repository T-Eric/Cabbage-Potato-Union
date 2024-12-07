// Reorder Buffer
// Connect: CDB, LSB(io), 
// Function: FIFO queue, get and commit ins in order
// if need branching, raise flag_br, send to lsb, fet and rs
// call them stop and digest! then tell pc to jump
`include "utils/head.v"
// TODO branch相关，cdb相关，需要更新一些逻辑

module reorder_buffer (
    input clk,
    input rst,
    input en,

    // from/to decoder: new ins' info
    input is_en_i,
    input is_ic_i,
    input [1:0] is_tp_i,  // branch, store, load, normal  
    input [`OP_W-1:0] is_op_i,
    input [`REG_BIT - 1:0] is_rd_i,
    input [`RAM_ADR_W-1:0] is_pc_i,
    input is_pbr_i,  // predicted jump-to 

    // from RF: data from register file, then will forward
    // to rs and lsb
    input rf_en_i,
    input rf_ls_i,
    input [`ROB_BIT - 1:0] rf_qj_i,
    input [`ROB_BIT - 1:0] rf_qk_i,
    input [`DAT_W - 1:0] rf_vj_i,
    input [`DAT_W - 1:0] rf_vk_i,
    input [`ROB_BIT - 1:0] rf_qd_i,
    input [`OP_W - 1:0] rf_op_i,
    input [`DAT_W - 1:0] rf_imm_i,
    input [`RAM_ADR_W-1:0] rf_pc_i,
    output [`ROB_BIT-1:0] rf_qd_o,

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
    output [`RAM_ADR_W-1:0] rs_pc_o,

    // to LSB: tell him to load/store
    output reg lsb_en_o,
    output [`OP_W - 1:0] lsb_op_o,
    output [`DAT_W - 1:0] lsb_imm_o,
    output [`ROB_BIT - 1:0] lsb_qj_o,
    output [`ROB_BIT - 1:0] lsb_qk_o,
    output [`DAT_W - 1:0] lsb_vj_o,
    output [`DAT_W - 1:0] lsb_vk_o,
    output [`ROB_BIT - 1:0] lsb_qd_o,

    // from/to LSB: commit and update
    output reg                  lsb_cmt_o,  // tell LSB to store now
    input                       lsb_en_i,
    input      [`ROB_BIT - 1:0] lsb_q_i,
    input      [  `DAT_W - 1:0] lsb_v_i,

    // from CDB
    input cdb_en_i,
    input [`ROB_BIT - 1:0] cdb_q_i,
    input [`DAT_W - 1:0] cdb_v_i,
    input cdb_cbr_i,
    input [`RAM_ADR_W - 1:0] cdb_cbt_i,  // 算出来的指令跳转地址

    // Commit to update RF
    output reg rf_en_o,
    output reg [`REG_BIT - 1:0] rf_rd_o,
    output reg [`ROB_BIT - 1:0] rf_q_o,
    output reg [`DAT_W - 1:0] rf_v_o,

    // Branch / JUMP
    output reg                    br_flag,  // if mispredict
    output reg                    br_abr,   // actually branched or not  
    output reg [  `RAM_ADR_W-1:0] br_tpc,   // pc then 
    output reg [`RAM_ADR_W - 1:0] br_bt,    // branched to where

    // Full
    output reg full
);
  integer i;

  // sheet
  reg [`OP_W-1:0] op[`ROB_S-1:0];
  reg ic[`ROB_S-1:0];
  reg [1:0] tp[`ROB_S-1:0];  // 00:branch, 01:store, 10:load, 11: alu operation
  reg [`REG_BIT-1:0] rd[`ROB_S-1:0];  // if alu op, reg dest
  reg [`DAT_W-1:0] v[`ROB_S-1:0];  // the value
  reg [`RAM_ADR_W-1:0] pc;
  reg pbr[`ROB_S-1:0];  // predicted branch or not
  reg cbr[`ROB_S-1:0];  // calculated branch or not
  reg [`RAM_ADR_W-1:0] cbt[`ROB_S-1:0];  // calced branch-to
  reg ready[`ROB_S-1:0];  //whether finished


  // queue
  reg [`ROB_BIT-1:0] chead, ctail;  // [) pointer
  wire [`ROB_BIT-1:0] thead, ttail;
  wire empty;

  assign thead   = (chead + 5'b1 == 5'b0) ? 5'b1 : (chead + 5'b1);
  assign ttail   = (ctail + 5'b1 == 5'b0) ? 5'b1 : (ctail + 5'b1);
  assign empty   = !full && chead == ctail;
  assign rf_qd_o = ctail;

  // branching
  reg br;  // 1 means missed prediction and jump

  // output
  reg ic_o;
  reg [`OP_W - 1:0] op_o;
  reg [`DAT_W - 1:0] imm_o;
  reg [`ROB_BIT - 1:0] qj_o;
  reg [`ROB_BIT - 1:0] qk_o;
  reg [`DAT_W - 1:0] vj_o;
  reg [`DAT_W - 1:0] vk_o;
  reg [`ROB_BIT - 1:0] qd_o;
  reg [`RAM_ADR_W-1:0] pc_o;

  assign rs_ic_o   = ic_o;
  assign rs_op_o   = op_o;
  assign rs_imm_o  = imm_o;
  assign rs_qj_o   = qj_o;
  assign rs_qk_o   = qk_o;
  assign rs_vj_o   = vj_o;
  assign rs_vk_o   = vk_o;
  assign rs_qd_o   = qd_o;
  assign rs_pc_o   = pc_o;

  assign lsb_op_o  = op_o;
  assign lsb_imm_o = imm_o;
  assign lsb_qj_o  = qj_o;
  assign lsb_qk_o  = qk_o;
  assign lsb_vj_o  = vj_o;
  assign lsb_vk_o  = vk_o;
  assign lsb_qd_o  = qd_o;

  always @(posedge clk) begin
    if (rst || br_flag) begin
      for (i = 1; i <= `ROB_S; i = i + 1) begin
        op[i] <= 0;
        ic[i] <= 0;
        tp[i] <= 0;
        rd[i] <= 0;
        v[i] <= 0;
        pc[i] <= 0;
        pbr[i] <= 0;
        cbr[i] <= 0;
        cbt[i] <= 0;
        ready[i] <= 0;
      end
      full  <= 0;
      chead <= 1;
      ctail <= 1;

      ic_o  <= 0;
      op_o  <= 0;
      imm_o <= 0;
      qj_o  <= 0;
      qk_o  <= 0;
      vj_o  <= 0;
      vk_o  <= 0;
      qd_o  <= 0;
      pc_o  <= 0;
    end else if (en) begin
      // reset enables
      rf_en_o   <= 0;
      rs_en_o   <= 0;
      lsb_en_o  <= 0;
      lsb_cmt_o <= 0;

      // new instruction fifo input: from IS
      if (is_en_i && !full) begin
        ready[ctail] <= 0;
        v[ctail] <= 0;
        ic[ctail] <= is_ic_i;
        tp[ctail] <= is_tp_i;
        pbr[ctail] <= is_pbr_i;  // predicted
        pc[ctail] <= is_pc_i;
        cbt[ctail] <= 0;
        op[ctail] <= is_op_i;
        rd[ctail] <= is_rd_i;

        ctail <= ttail;
        full <= ttail == chead;
      end

      // update some results: from LSB and CDB
      if (lsb_en_i) begin
        ready[cdb_q_i] <= 1'b1;
        v[cdb_q_i] <= lsb_v_i;
      end
      if (cdb_en_i) begin
        ready[cdb_q_i] <= 1'b1;
        v[cdb_q_i] <= cdb_v_i;
        cbr[cdb_q_i] <= cdb_cbr_i;
        cbt[cdb_q_i] <= cdb_cbt_i;
      end

      // 从rf中得到qv数据后，分发给rs和lsb
      if (rf_en_i) begin
        // 为了同步时序，从rf中接受是load/store与否的信号\
                lsb_en_o <= rf_ls_i;
        rs_en_o <= !rf_ls_i;  // load 和 store 一定会stall，交给lsb去解决

        op_o <= rf_op_i;
        imm_o <= rf_imm_i;
        pc_o <= rf_pc_i;

        // rf传来的值,记入
        qj_o <= rf_qj_i;
        qk_o <= rf_qk_i;
        vj_o <= rf_vj_i;
        vk_o <= rf_vk_i;
        qd_o <= rf_qd_i;

        if (rf_qj_i != 0) begin
          if (cdb_en_i && cdb_q_i == rf_qj_i) begin
            qj_o <= 0;
            vj_o <= cdb_v_i;
          end else if (lsb_en_i && lsb_q_i == rf_qj_i) begin
            qj_o <= 0;
            vj_o <= lsb_v_i;
          end else if (ready[rf_qj_i]) begin
            qj_o <= 0;
            vj_o <= v[rf_qj_i];
          end
        end

        if (rf_qk_i != 0) begin
          if (cdb_en_i && cdb_q_i == rf_qk_i) begin
            qk_o <= 0;
            vk_o <= cdb_v_i;
          end else if (lsb_en_i && lsb_q_i == rf_qk_i) begin
            qk_o <= 0;
            vk_o <= lsb_v_i;
          end else if (ready[rf_qk_i]) begin
            qk_o <= 0;
            vk_o <= v[rf_qk_i];
          end
        end
      end

      // Try commit head: from myself's !empty
      // TODO: predicter 整合，联动 pc
      // 00:branch, 01:store, 10:load, 11: alu operation
      if (!empty) begin
        if (ready[chead] || tp[chead] == 2'b01) begin
          case (tp[chead])
            2'b00: begin
              if (pbr[chead] != cbr[chead]) begin
                br_flag <= 1;
                br_tpc  <= pc[chead];
                br_abr  <= cbr[chead];
                br_bt   <= cbt[chead];
              end else begin
                rf_en_o <= 1;
                rf_rd_o <= rd[chead];
                rf_q_o  <= chead;
                rf_v_o  <= v[chead];
                // TODO 不跳转要提交吗？其实应该不用吧？好吧其实也是要的
                // 但是除了JALR之外不会有什么影响就是了
              end
            end
            2'b01: begin
              // store交给LSB去Commit
              lsb_cmt_o <= 1;
            end
            default: begin
              rf_en_o <= 1;
              rf_rd_o <= rd[chead];
              rf_q_o  <= chead;
              rf_v_o  <= v[chead];
            end
          endcase
          chead <= thead;
          if (full) full <= 0;
        end
      end
    end else begin
      for (i = 1; i <= `ROB_S; i = i + 1) begin
        tp[i] <= 0;
        rd[i] <= 0;
        v[i] <= 0;
        ready[i] <= 0;
      end
      full  <= 0;
      chead <= 1;
      ctail <= 1;
    end
  end

endmodule
