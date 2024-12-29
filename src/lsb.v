// load-store buffer
// Function: FIFO sender, react with dc to store and load
`include "head.v"
`ifndef LSB_V
`define LSB_V

// bug(): rob commit过后就不管了，此时store很可能没完成
// solution: commit让cmt_cnt(to be stored)+1,只要其不为0且head ready就store
// bug(): sw sw sw br，此时队列中还有sw，怎么办？
// solution: 不粗暴清空，此时只有sw，将tail设为head+cmt_cnt

// 接受所有的load和store指令（一定会stall）
module load_store_buffer (
    input clk,
    input rst,
    input en,

    // from RF
    input rf_en_i,
    input [`OP_W - 1:0] rf_op_i,
    input [`ROB_BIT - 1:0] rf_qj_i,
    input [`ROB_BIT - 1:0] rf_qk_i,
    input [`DAT_W - 1:0] rf_vj_i,
    input [`DAT_W - 1:0] rf_vk_i,
    input [`ROB_BIT - 1:0] rf_qd_i,
    input [`DAT_W - 1:0] rf_imm_i,
    // input [`DAT_W-1:0] rf_pc_i,  // 仅供调试 

    // Visit Memory
    output reg                dc_en_o,
    output                    dc_rwen_o,  // 0:R, 1:W
    output reg [ `OP_W - 1:0] dc_op_o,
    output reg [         2:0] dc_len_o,   // 1:B; 2:H; 4:W
    output reg [`DAT_W - 1:0] dc_adr_o,
    output reg [`DAT_W - 1:0] dc_dat_o,
    // output reg [  `DAT_W-1:0] dc_pc_o,    // 仅供调试
    input                     dc_en_i,
    input      [`DAT_W - 1:0] dc_dat_i,

    // Output LOAD Result，可能与CDB冲突，考虑不放在一起
    // 如果没有进一步操作，q和v不用reg
    output reg ldb_en_o,
    output reg [`ROB_BIT - 1:0] ldb_q_o,
    output reg [`DAT_W - 1:0] ldb_v_o,

    // from CDB: Update Calculation Result
    input cdb_en_i,
    input [`ROB_BIT - 1:0] cdb_q_i,
    input [`DAT_W - 1:0] cdb_v_i,

    // Commit STORE
    input  rob_cmt_i,
    output rob_cmt_full,

    // ! Misprediction
    input br_flag,

    // stall when full
    output full,

    // whole io buffer, if 0 should not Load/Store
    input iob_full_i
);
  reg [`OP_W-1:0] op[`LSB_S-1:0];
  reg [`DAT_W-1:0] vj[`LSB_S-1:0];
  reg [`DAT_W-1:0] vk[`LSB_S-1:0];
  reg [`DAT_W-1:0] imm[`LSB_S-1:0];
  reg [`ROB_BIT-1:0] qj[`LSB_S-1:0];
  reg [`ROB_BIT-1:0] qk[`LSB_S-1:0];
  reg [`ROB_BIT-1:0] qd[`LSB_S-1:0];
  // reg [`DAT_W-1:0] pc[`LSB_S-1:0];  //仅供调试

  wire ls[`LSB_S-1:0];  // Load 1 or Store 0
  wire ready[`LSB_S-1:0];

  genvar j;
  generate
    for (j = 0; j < `LSB_S; j = j + 1) begin
      assign ls[j] = op[j][4] == 0;  // TODO 从原来的直接比等逻辑变为直接取位逻辑
      assign ready[j] = (qj[j] == 0) && (qk[j] == 0);  // TODO 暂时把op!=0判断去除了
    end
  endgenerate

  // FIFO Load-Store
  reg [`ROB_BIT-1:0] chead, ctail;  // [) pointer
  wire [`ROB_BIT-1:0] thead, ttail, tttail, ttttail;
  wire empty;

  assign thead = chead + 4'b0001;
  assign ttail = ctail + 4'b0001;
  assign tttail = ctail + 4'b0010;
  assign ttttail = ctail + 4'b0011;
  assign full = (ttail == chead || tttail == chead || ttttail == chead);
  assign empty = !full && chead == ctail;  // 去掉了op的判定，毕竟只要empty就不会有提交

  // connect DC
  reg dc_wait;  // 1 means pending for DC
  assign dc_rwen_o = ~ls[chead];  // TMD之前的是错的！RAM写是1！

  // commit counter
  reg [`LSB_BIT-1:0] cmt_cnt;
  assign rob_cmt_full = cmt_cnt >= (`LSB_S - 3);

  // temporary remember
  // reg [`ROB_BIT-1:0] last_q;
  // reg [`DAT_W-1:0] last_v;

  // ---debug---
  // wire [`OP_W-1:0] DHop;
  // wire [`DAT_W-1:0] DHvj;
  // wire [`DAT_W-1:0] DHvk;
  // wire [`DAT_W-1:0] DHimm;
  // wire [`ROB_BIT-1:0] DHqj;
  // wire [`ROB_BIT-1:0] DHqk;
  // wire [`ROB_BIT-1:0] DHqd;
  // wire [`DAT_W-1:0] DHpc;
  // wire DHls;
  // wire DHready;

  // assign DHop = op[chead];
  // assign DHvj = vj[chead];
  // assign DHvk = vk[chead];
  // assign DHqj = qj[chead];
  // assign DHqk = qk[chead];
  // assign DHqd = qd[chead];
  // assign DHimm = imm[chead];
  // assign DHls = ls[chead];
  // // assign DHpc = pc[chead];
  // assign DHready = ready[chead];

  // wire [`DAT_W-1:0] vj_watch, vk_watch;
  // wire [`ROB_BIT-1:0] qj_watch, qk_watch;
  // assign qj_watch = qj[0];
  // assign qk_watch = qk[0];
  // assign vj_watch = vj[0];
  // assign vk_watch = vk[0];
  // ---debug---

  // 队列塞满容易寄，故保证每次空个两格
  integer i;
  always @(posedge clk) begin
    if (rst) begin
      chead   <= 0;
      ctail   <= 0;
      // full <= 0;
      cmt_cnt <= 0;
      for (i = 0; i < `LSB_S; i = i + 1) begin
        op[i]  <= 0;
        vj[i]  <= 0;
        vk[i]  <= 0;
        imm[i] <= 0;
        qj[i]  <= 0;
        qk[i]  <= 0;
        qd[i]  <= 0;
        // pc[i]  <= 0;
      end
      ldb_en_o <= 0;
      ldb_q_o  <= 0;
      ldb_v_o  <= 0;
      dc_wait  <= 0;
    end else if (en && br_flag) begin
      ldb_q_o  <= 0;
      ldb_v_o  <= 0;
      ldb_en_o <= 0;
      dc_en_o  <= 0;
      if (!ls[chead] || empty) begin
        // 如果是写，后面不可能有读，让这次翻篇即可
        // dc_wait <= 0;
        if (dc_wait) begin
          ctail <= thead + cmt_cnt;
          if (dc_en_i) begin
            chead   <= thead;
            dc_wait <= 0;
            // op[chead] <= 0;
          end
        end else ctail <= chead + cmt_cnt;
      end else begin
        // $display("LSB wants to handle flag when head is read at %h!", pc[chead]);
        // 如果是读，这个读是错的，立即停止这个读并且翻篇
        ctail <= thead + cmt_cnt;
        chead <= thead;
        if (dc_wait) dc_wait <= 0;
        // op[chead] <= 0;  // 这个不能忘记！否则可能导致错误的ready！
      end
    end else if (en) begin
      // reset
      dc_en_o  <= 0;
      dc_len_o <= 0;
      dc_adr_o <= 0;
      dc_dat_o <= 0;
      ldb_en_o <= 0;
      // q_o <= 0;
      // v_o <= 0;
      // last_q   <= 0;
      // last_v   <= 0;

      // cmt_cnt  <= rob_cmt_i ? cmt_cnt + 1 : cmt_cnt;
      if (rob_cmt_i) cmt_cnt <= cmt_cnt + 1;

      // new LS instruction
      if (rf_en_i) begin
        op[ctail]  <= rf_op_i;
        imm[ctail] <= rf_imm_i;
        qd[ctail]  <= rf_qd_i;
        qj[ctail]  <= rf_qj_i;
        qk[ctail]  <= rf_qk_i;
        vj[ctail]  <= rf_vj_i;
        vk[ctail]  <= rf_vk_i;
        // pc[ctail]  <= rf_pc_i;

        if (ldb_en_o) begin
          if (rf_qj_i == ldb_q_o) begin
            qj[ctail] <= 0;
            vj[ctail] <= ldb_v_o;
          end
          if (rf_qk_i == ldb_q_o) begin
            qk[ctail] <= 0;
            vk[ctail] <= ldb_v_o;
          end
        end

        // if (last_q != 0) begin
        //   if (rf_qj_i == last_q) begin
        //     qj[ctail] <= 0;
        //     vj[ctail] <= last_v;
        //   end
        //   if (rf_qk_i == last_q) begin
        //     qk[ctail] <= 0;
        //     vk[ctail] <= last_v;
        //   end
        // end

        // bugfix: 此时传入的也可以直接给
        // bugfix: 但是如果是写（!ls），那就算了（这么简单的事都想不到吗。。。你之前是怎么过的）
        if (dc_en_i && ls[chead]) begin
          if (rf_qj_i == qd[chead]) begin
            qj[ctail] <= 0;
            vj[ctail] <= dc_dat_i;
          end
          if (rf_qk_i == qd[chead]) begin
            qk[ctail] <= 0;
            vk[ctail] <= dc_dat_i;
          end
        end

        if (cdb_en_i) begin
          if (rf_qj_i == cdb_q_i) begin
            qj[ctail] <= 0;
            vj[ctail] <= cdb_v_i;
          end
          if (rf_qk_i == cdb_q_i) begin
            qk[ctail] <= 0;
            vk[ctail] <= cdb_v_i;
          end
        end

        ctail <= ttail;
        // full  <= ttail == chead || ttail + 1 == chead;
      end

      // update
      if (cdb_en_i) begin
        for (i = 0; i < `LSB_S; i = i + 1) begin
          if (qj[i] == cdb_q_i) begin
            vj[i] <= cdb_v_i;
            qj[i] <= 0;
          end
          if (qk[i] == cdb_q_i) begin
            vk[i] <= cdb_v_i;
            qk[i] <= 0;
          end
        end
      end

      // if head ready, give it to DC
      if (ready[chead] && !empty && !dc_wait && !iob_full_i) begin
        dc_adr_o <= vj[chead] + imm[chead];
        dc_dat_o <= vk[chead];
        dc_op_o  <= op[chead];
        // dc_pc_o  <= pc[chead];
        if (ls[chead]) begin
          dc_wait <= 1;
          dc_en_o <= 1;
          case (op[chead])
            `LB, `LBU: dc_len_o <= 1;  // LB, LBU
            `LH, `LHU: dc_len_o <= 2;  // LH, LHU
            `LW: dc_len_o <= 4;  // LW
            default: ;
          endcase
        end else if (cmt_cnt != 0) begin
          // commit store
          cmt_cnt <= rob_cmt_i ? cmt_cnt : cmt_cnt - 1;
          dc_wait <= 1;
          dc_en_o <= 1;
          case (op[chead])
            `SB: dc_len_o <= 1;  // SB
            `SH: dc_len_o <= 2;  // SH
            `SW: dc_len_o <= 4;  // SW
            default: ;
          endcase
        end
      end

      // if DC finished, submit and pop
      // TODO 是否要在此时继续送出ready？-
      if (dc_en_i && dc_wait) begin
        dc_wait <= 0;
        if (ls[chead]) begin
          // $display("Load value %h", dc_dat_i);
          // reply data
          for (i = 0; i < `LSB_S; i = i + 1) begin
            if (qd[chead] == qj[i]) begin
              vj[i] <= dc_dat_i;
              qj[i] <= 0;
            end
            if (qd[chead] == qk[i]) begin
              vk[i] <= dc_dat_i;
              qk[i] <= 0;
            end
          end
          ldb_q_o  <= qd[chead];
          ldb_v_o  <= dc_dat_i;
          ldb_en_o <= 1;
          // last_q   <= qd[chead];
          // last_v   <= dc_dat_i;
        end
        chead <= thead;
        // op[chead] <= 0;// TODO 到时考虑下要不要加回来
        // if (!rf_en_i && !(ttail == chead || ttail + 1 == chead)) full <= 0;
      end

      // lsb只能更新自己现在有的数据，rob只能在lsb数据来到后更新。
      // 如果rob_en_i和rob_en_o同时出现，双方数据都未到，则这个被传输的q不能被更新。
      // 解决法：不麻烦每次commit搞一下更新了，如果某个时刻两个都是亮的，就
      // 判断上次en_o输出的值能否更新这个。
    end
  end
endmodule

`endif
