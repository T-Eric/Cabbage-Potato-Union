// Reorder Buffer
// Connect: CDB, LSB(io), 
// Function: FIFO queue, get and commit ins in order
// if need branching, raise flag_br, send to lsb, fet and rs
// call them stop and digest! then tell pc to jump
`include "src/head.v"
`ifndef ROB_V
`define ROB_V

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
    input [`DAT_W-1:0] is_pc_i,
    input is_pbr_i,  // predicted jump-to 

    // from/to LSB: commit and update
    output reg                  lsb_cmt_o,       // tell LSB to store now
    input                       lsb_cmt_full_i,
    input                       lsb_en_i,
    input      [`ROB_BIT - 1:0] lsb_q_i,
    input      [  `DAT_W - 1:0] lsb_v_i,

    // from CDB
    input cdb_en_i,
    input [`ROB_BIT - 1:0] cdb_q_i,
    input [`DAT_W - 1:0] cdb_v_i,
    input cdb_cbr_i,
    input [`DAT_W - 1:0] cdb_cbt_i,  // 算出来的指令跳转地址

    // Commit to update RF
    output reg rf_en_o,
    output reg [`REG_BIT - 1:0] rf_rd_o,
    output reg [`ROB_BIT - 1:0] rf_q_o,
    output reg [`DAT_W - 1:0] rf_v_o,
    output [`ROB_BIT-1:0] rf_qd_o,

    // 用于在ready时直接供给数据
    input [`ROB_BIT - 1:0] rf_reqqj_i,
    input [`ROB_BIT - 1:0] rf_reqqk_i,
    output rf_rdyj_o,
    output rf_rdyk_o,
    output [`DAT_W - 1:0] rf_rdyvj_o,
    output [`DAT_W - 1:0] rf_rdyvk_o,

    // Branch / JUMP
    output reg                br_flag,  // if mispredict
    output reg                br_abr,   // actually branched or not  
    output reg [  `DAT_W-1:0] br_tpc,   // pc then 
    output reg [`DAT_W - 1:0] br_cbt,   // branched to where

    // Full
    output full
);
  integer i;

  // sheet
  reg [`OP_W-1:0] op[`ROB_S-1:0];
  reg ic[`ROB_S-1:0];
  reg [1:0] tp[`ROB_S-1:0];  // 00:branch, 01:store, 10:load, 11: alu operation
  reg [`REG_BIT-1:0] rd[`ROB_S-1:0];  // if alu op, reg dest
  reg [`DAT_W-1:0] v[`ROB_S-1:0];  // the value
  reg [`DAT_W-1:0] pc[`ROB_S-1:0];
  reg pbr[`ROB_S-1:0];  // predicted branch or not
  reg cbr[`ROB_S-1:0];  // calculated branch or not
  reg [`DAT_W-1:0] cbt[`ROB_S-1:0];  // calced branch-to
  reg ready[`ROB_S-1:0];  //whether finished

  // queue
  reg [`ROB_BIT-1:0] chead, ctail;  // [) pointer
  wire [`ROB_BIT-1:0] thead, ttail, tttail, ttttail;
  wire empty;

  assign thead = (chead + 5'b1 == 5'b0) ? 5'b1 : (chead + 5'b1);
  assign ttail = (ctail + 5'b1 == 5'b0) ? 5'b1 : (ctail + 5'b1);
  assign tttail = (ctail + 2 == 5'b0) ? 5'b1 : (ctail + 2);
  assign ttttail = (ctail + 3 == 5'b0) ? 5'b1 : (ctail + 3);
  assign full = (ttail == chead) || (tttail == chead) || (ttttail == chead);
  assign empty = chead == ctail;
  assign rf_qd_o = ctail;

  // ready supply
  assign rf_rdyj_o = ready[rf_reqqj_i];
  assign rf_rdyk_o = ready[rf_reqqk_i];
  assign rf_rdyvj_o = v[rf_reqqj_i];
  assign rf_rdyvk_o = v[rf_reqqk_i];

  // branching
  reg br;  // 1 means missed prediction and jump

  // ---debug---
  wire [`OP_W-1:0] DHop;
  wire DHic;
  wire [1:0] DHtp;
  wire [`REG_BIT-1:0] DHrd;
  wire [`DAT_W-1:0] DHv;
  wire [`DAT_W-1:0] DHpc;
  wire DHpbr;
  wire DHcbr;
  wire [`DAT_W-1:0] DHcbt;
  wire DHready;

  assign DHop = op[chead];
  assign DHic = ic[chead];
  assign DHtp = tp[chead];
  assign DHrd = rd[chead];
  assign DHv = v[chead];
  assign DHpc = pc[chead];
  assign DHpbr = pbr[chead];
  assign DHcbr = cbr[chead];
  assign DHcbt = cbt[chead];
  assign DHready = ready[chead];
  // ---debug---

  always @(posedge clk) begin
    if (rst || br_flag) begin
      for (i = 0; i < `ROB_S; i = i + 1) begin
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
      chead   <= 1;
      ctail   <= 1;

      br_flag <= 0;
      br_abr  <= 0;
      br_tpc  <= 0;
      br_cbt  <= 0;

      rf_en_o <= 0;
      rf_rd_o <= 0;
      rf_q_o  <= 0;
      rf_v_o  <= 0;
    end else if (en) begin
      // reset enables
      ready[0]  <= 0;
      rf_en_o   <= 0;
      lsb_cmt_o <= 0;
      br_flag   <= 0;

      // new instruction fifo input: from IS
      if (is_en_i) begin
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
      end

      // update some results: from LSB and CDB
      // 对于新加入的大概也可以一并处理了
      if (lsb_en_i) begin
        ready[lsb_q_i] <= 1'b1;
        v[lsb_q_i] <= lsb_v_i;
      end
      if (cdb_en_i) begin
        ready[cdb_q_i] <= 1'b1;
        v[cdb_q_i] <= cdb_v_i;
        cbr[cdb_q_i] <= cdb_cbr_i;
        cbt[cdb_q_i] <= cdb_cbt_i;
      end

      // Try commit head: from myself's !empty
      // 00:branch, 01:store, 10:load, 11: alu operation
      if (!empty) begin
        if (ready[chead] || (!lsb_cmt_full_i && tp[chead] == 2'b01)) begin
          // $display("ROB Commit,pc:%h, q:%d, tp:%b, op:%d, rd:%d, val:%h\n", pc[chead], chead,
          //          tp[chead], op[chead], rd[chead], v[chead]);
          case (tp[chead])
            2'b00: begin
              if (pbr[chead] != cbr[chead]) begin
                // $display("Misprediction! From %h, To %h", pc[chead], cbt[chead]);
                br_flag <= 1;
                br_tpc  <= pc[chead];
                br_abr  <= cbr[chead];
                br_cbt  <= cbt[chead];
              end else begin
                // $display("Jump From %h, To %h", pc[chead], cbt[chead]);
              end
              if (op[chead] == `JALR) begin
                rf_en_o <= 1;
                rf_rd_o <= rd[chead];
                rf_q_o  <= chead;
                rf_v_o  <= v[chead];
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
        end
      end
    end
  end

endmodule

`endif
