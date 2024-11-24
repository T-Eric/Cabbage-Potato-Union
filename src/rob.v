// Reorder Buffer
// Connect: CDB, LSB(io), 
// Function: FIFO queue, get and commit ins in order
// if need branching, raise flag_br, send to lsb, fet and rs
// call them stop and digest! then tell pc to jump
`include "utils/head.v"

module reorder_buffer (
    input clk,
    input rst,
    input en,

    // from/to issue: new ins' info
    // issue同时对被decode的指令做一分类
    input is_en_i,
    input [`REG_BIT - 1:0] is_rd_i,
    input is_bj_i,  // whether jump 

    // from RF: data from register file
    input rf_en_i,
    input [`ROB_BIT - 1:0] rf_qj_i,
    input [`ROB_BIT - 1:0] rf_qk_i,
    input [`REG_DAT_W - 1:0] rf_vj_i,
    input [`REG_DAT_W - 1:0] rf_vk_i,
    input [`ROB_BIT - 1:0] rf_qd_i,  // acturally from issue
    input [`OP_W - 1:0] rf_op_i,
    input [`REG_DAT_W - 1:0] rf_imm_i,

    // to RS
    output reg rs_en_o,
    output [`OP_W - 1:0] rs_op_o,
    output [`REG_DAT_W - 1:0] rs_imm_o,
    output [`ROB_BIT - 1:0] rs_qj_o,
    output [`ROB_BIT - 1:0] rs_qk_o,
    output [`REG_DAT_W - 1:0] rs_vj_o,
    output [`REG_DAT_W - 1:0] rs_vk_o,
    output [`ROB_BIT - 1:0] rs_qd_o,

    // to LSB: tell him to load/store
    output reg lsb_en_o,
    output [`OP_W - 1:0] lsb_op_o,
    output [`REG_DAT_W - 1:0] lsb_imm_o,
    output [`ROB_BIT - 1:0] lsb_qj_o,
    output [`ROB_BIT - 1:0] lsb_qk_o,
    output [`REG_DAT_W - 1:0] lsb_vj_o,
    output [`REG_DAT_W - 1:0] lsb_vk_o,
    output [`ROB_BIT - 1:0] lsb_qd_o,

    // from/to LSB: commit and update
    output reg                    lsb_cmt_s_o,  // tell LSB to store now
    input                         lsb_en_i,
    input      [  `ROB_BIT - 1:0] lsb_qd_i,
    input      [`REG_DAT_W - 1:0] lsb_vd_i,

    // from CDB
    input cdb_en_i,
    input [`ROB_BIT - 1:0] cdb_q_i,
    input [`DAT_W - 1:0] cdb_v_i,
    input [`RAM_ADR_W - 1:0] cdb_br_to_i,  // 算出来的指令跳转地址

    //Commit
    output reg rf_en_o,
    output reg [`REG_BIT - 1:0] rf_rd_o,
    output reg [`ROB_BIT - 1:0] rf_q_o,
    output reg [`REG_DAT_W - 1:0] rf_v_o,

    // Branch / JUMP
    output                    br_flag,  // Misprediction
    output reg [`DAT_W - 1:0] br_to_o,

    // Full
    output full_o
);

  // Main Data
  reg [`REG_DAT_W - 1:0] vd[`ROB_S - 1:0];
  reg is[`ROB_S - 1:0];
  reg bj[`ROB_S - 1:0];
  reg [`REG_DAT_W - 1:0] jt[`ROB_S - 1:0];
  reg [`REG_BIT - 1:0] rd[`ROB_S - 1:0];
  reg [`REG_DAT_W - 1:0] pc[`ROB_S - 1:0];
  reg [`REG_DAT_W - 1:0] pjt[`ROB_S - 1:0];
  reg rdy[`ROB_S - 1:0];

  // Queue
  reg full;
  wire empty;
  reg [`ROB_BIT - 1:0] head, tail;
  wire [`ROB_BIT - 1:0] nxtHead, nxtTail, fullPtr;

  assign empty   = (!full) && (head == tail);
  assign nxtHead = ((head + 5'b1 != 5'b0) ? (head + 5'b1) : 5'b1);
  assign nxtTail = ((tail + 5'b1 != 5'b0) ? (tail + 5'b1) : 5'b1);
  assign fullPtr = ((tail + 5'b100 != 5'b100) ? (tail + 5'b100) : 5'b1);

  // Local Information
  reg mp;  // Misprediction
  wire [`REG_DAT_W - 1:0] headJt;
  assign headJt = jt[head];


  // IO
  // assign rf_q_o = tail;

  reg [`ROB_BIT - 1:0] oQs1, oQs2;
  reg [`REG_DAT_W - 1:0] oVs1, oVs2;
  reg [`ROB_BIT - 1:0] oQd;
  reg [`OP_W - 1:0] oOp;
  reg [`REG_DAT_W - 1:0] oPc;
  reg [`REG_DAT_W - 1:0] oImm;

  assign rs_op_o = oOp;
  assign lsb_op_o = oOp;
  assign oRS_Pc = oPc;
  assign rs_imm_o = oImm;
  assign lsb_imm_o = oImm;
  assign rs_qj_o = oQs1;
  assign lsb_qj_o = oQs1;
  assign rs_qk_o = oQs2;
  assign lsb_qk_o = oQs2;
  assign rs_vj_o = oVs1;
  assign lsb_vj_o = oVs1;
  assign rs_vk_o = oVs2;
  assign lsb_vk_o = oVs2;
  assign rs_qd_o = oQd;
  assign lsb_qd_o = oQd;

  assign br_flag = mp;

  assign full_o = full;

  //===================== ALWAYS =====================

  integer i;
  always @(posedge clk) begin
    if (rst || mp) begin  // ! Clear Self when Misprediction
      for (i = 0; i < `ROB_S; i = i + 1) begin
        vd[i]  <= 0;
        is[i]  <= 0;
        bj[i]  <= 0;
        jt[i]  <= 0;
        rd[i]  <= 0;
        pc[i]  <= 0;
        pjt[i] <= 0;
        rdy[i] <= 0;
      end

      full <= 0;
      head <= 1;
      tail <= 1;

      mp <= 0;

      oQs1 <= 0;
      oQs2 <= 0;
      oVs1 <= 0;
      oVs2 <= 0;
      oQd <= 0;
      oOp <= 0;
      oPc <= 0;
      oImm <= 0;

      rs_en_o <= 0;
      lsb_en_o <= 0;
      lsb_cmt_s_o <= 0;
      rf_en_o <= 0;
      rf_rd_o <= 0;
      rf_q_o <= 0;
      rf_v_o <= 0;

      br_to_o <= 0;
    end else if (en) begin
      mp <= 0;
      rs_en_o <= 0;
      lsb_en_o <= 0;
      lsb_cmt_s_o <= 0;
      rf_en_o <= 0;

      // Update LOAD or Arith Result
      if (lsb_en_i) begin
        rdy[lsb_qd_i] <= 1;
        vd[lsb_qd_i]  <= lsb_vd_i;
      end
      if (cdb_en_i) begin
        rdy[cdb_q_i] <= 1;
        vd[cdb_q_i]  <= cdb_v_i;
        jt[cdb_q_i]  <= cdb_br_to_i;  // 算出来的指令跳转地址
      end

      // New Instruction used current available Q
      if (is_en_i) begin
        vd[tail] <= 0;
        jt[tail] <= 0;
        rdy[tail] <= 0;

        rd[tail] <= is_rd_i;
        bj[tail] <= is_bj_i;  // whether jump

        tail <= nxtTail;  // * Push tail
        full <= (fullPtr == head) ? 1 : 0;
      end

      // Ready to commit first instruction
      if (!empty) begin
        if (is[head]) begin  // Commit STORE
          // $display("%0h", pc[head]);
          // Nothing is needed for STORE to commit, so STORE needn't "rdy" signal
          lsb_cmt_s_o <= 1;
          head <= nxtHead;  // * Pop front
          if (!is_en_i) full <= 0;
        end else if (rdy[head]) begin
          // $display("%0h", pc[head]);
          if (bj[head]) begin  // Commit BRANCH or JUMP
            if (headJt != pjt[head]) begin  // ! Misprediction
              mp <= 1;
              br_to_o <= headJt;
            end
          end else begin  // Commit Arith Instruction
            rf_en_o <= 1;
            rf_rd_o <= rd[head];
            rf_q_o  <= head;
            rf_v_o  <= vd[head];
            // $display("reg[%0h] %0h", rd[head], vd[head]);
          end

          head <= nxtHead;  // * Pop front
          if (!is_en_i) full <= 0;
        end
      end

      // Update instruction information from REG
      if (rf_en_i) begin

        oOp  <= rf_op_i;
        oImm <= rf_imm_i;

        oQs1 <= rf_qj_i;
        oVs1 <= rf_vj_i;
        oQs2 <= rf_qk_i;
        oVs2 <= rf_vk_i;

        if (rf_qj_i != 0) begin
          if (cdb_en_i && cdb_q_i == rf_qj_i) begin
            oQs1 <= 0;
            oVs1 <= cdb_v_i;
          end else if (lsb_en_i && lsb_qd_i == rf_qj_i) begin
            oQs1 <= 0;
            oVs1 <= lsb_vd_i;
          end else if (rdy[rf_qj_i]) begin
            oQs1 <= 0;
            oVs1 <= vd[rf_qj_i];
          end
        end
        if (rf_qk_i != 0) begin
          if (cdb_en_i && cdb_q_i == rf_qk_i) begin
            oQs2 <= 0;
            oVs2 <= cdb_v_i;
          end else if (lsb_en_i && lsb_qd_i == rf_qk_i) begin
            oQs2 <= 0;
            oVs2 <= lsb_vd_i;
          end else if (rdy[rf_qk_i]) begin
            oQs2 <= 0;
            oVs2 <= vd[rf_qk_i];
          end
        end

        oQd <= rf_qd_i;
      end
    end

    vd[0]  <= 0;
    bj[0]  <= 0;
    jt[0]  <= 0;
    rd[0]  <= 0;
    pc[0]  <= 0;
    pjt[0] <= 0;
    rdy[0] <= 0;
  end

endmodule
