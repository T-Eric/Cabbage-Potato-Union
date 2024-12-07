// load-store buffer
// Function: FIFO sender, react with dc to store and load
`include "src/head.v"
`ifndef LSB_V
`define LSB_V

// 接受所有的load和store指令（一定会stall）
module load_store_buffer (
    input clk,
    input rst,
    input en,

    // from ROB: TODO: 先传入一切必要的信息
    input rob_en_i,
    input [`OP_W - 1:0] rob_op_i,
    input [`ROB_BIT - 1:0] rob_qj_i,
    input [`ROB_BIT - 1:0] rob_qk_i,
    input [`DAT_W - 1:0] rob_vj_i,
    input [`DAT_W - 1:0] rob_vk_i,
    input [`ROB_BIT - 1:0] rob_qd_i,
    input [`DAT_W - 1:0] rob_imm_i,

    // Visit Memory
    output reg                    dc_en_o,
    output                        dc_rwen_o,  // 0:R, 1:W
    output reg [             2:0] dc_len_o,   // 1:B; 2:H; 4:W
    output reg [`RAM_ADR_W - 1:0] dc_adr_o,
    output reg [    `DAT_W - 1:0] dc_dat_o,
    input                         dc_en_i,
    input      [    `DAT_W - 1:0] dc_dat_i,

    // Output LOAD Result，可能与CDB冲突，考虑不放在一起
    // 如果没有进一步操作，q和v不用reg
    output reg rs_en_o,
    output [`ROB_BIT - 1:0] rs_q_o,
    output [`DAT_W - 1:0] rs_v_o,

    output reg rob_en_o,
    output [`ROB_BIT - 1:0] rob_q_o,
    output [`DAT_W - 1:0] rob_v_o,

    // from CDB: Update Calculation Result
    input cdb_en_i,
    input [`ROB_BIT - 1:0] cdb_q_i,
    input [`DAT_W - 1:0] cdb_v_i,

    // Commit STORE
    input rob_cmt_i,

    // ! Misprediction
    input br_flag_i,

    // stall when full
    output reg full,

    // whole io buffer, if 0 should not Load/Store
    input iob_full_i
);
  // 1. 涉及不可逆改变的存取由ROB控制，即只要管顺序执行，不用管跳不跳转
  reg [`OP_W-1:0] op[`LSB_S-1:0];
  reg [`DAT_W-1:0] vj[`LSB_S-1:0];
  reg [`DAT_W-1:0] vk[`LSB_S-1:0];
  reg [`DAT_W-1:0] imm[`LSB_S-1:0];
  reg [`ROB_BIT-1:0] qj[`LSB_S-1:0];
  reg [`ROB_BIT-1:0] qk[`LSB_S-1:0];
  reg [`ROB_BIT-1:0] qd[`LSB_S-1:0];

  wire ls[`LSB_S-1:0];  // Load 1 or Store 0
  wire ready[`LSB_S-1:0];

  genvar j;
  generate
    for (j = 0; j < `LSB_S; j = j + 1) begin
      assign ls[j] = 0;  // TODO 通过机器码判断是否load
      assign ready[j] = (qj[j] == 0) && (qk[j] == 0) && (op[j] != 0);
    end
  endgenerate

  // FIFO Load-Store
  reg [`ROB_BIT-1:0] chead, ctail;  // [) pointer
  wire [`ROB_BIT-1:0] thead, ttail;
  wire empty;

  assign thead = chead + 1;
  assign ttail = ctail + 1;
  assign empty = !full && chead == ctail;

  // outputs
  reg [`ROB_BIT-1:0] q_o;
  reg [  `DAT_W-1:0] v_o;
  assign rs_q_o  = q_o;
  assign rs_v_o  = v_o;
  assign rob_q_o = q_o;
  assign rob_v_o = v_o;

  // connect DC
  reg dc_wait;  // 1 means pending for DC
  assign dc_rwen_o = ls[chead];

  // 队列塞满容易寄，故保证每次空个两格
  integer i;
  always @(posedge clk) begin
    if (rst) begin
      chead <= 0;
      ctail <= 0;
      for (i = 0; i < `LSB_S; i = i + 1) begin
        op[i]  <= 0;
        vj[i]  <= 0;
        vk[i]  <= 0;
        imm[i] <= 0;
        qj[i]  <= 0;
        qk[i]  <= 0;
        qd[i]  <= 0;
      end
      q_o <= 0;
      v_o <= 0;
    end else if (en) begin
      // reset
      dc_en_o <= 0;
      dc_len_o <= 0;
      dc_adr_o <= 0;
      dc_dat_o <= 0;
      rs_en_o <= 0;
      rob_en_o <= 0;
      q_o <= 0;
      v_o <= 0;

      // new LS instruction
      if (rob_en_i) begin
        op[ctail] <= rob_op_i;
        vj[ctail] <= rob_vj_i;
        vk[ctail] <= rob_vk_i;
        imm[ctail] <= rob_imm_i;
        qj[ctail] <= rob_qj_i;
        qk[ctail] <= rob_qk_i;
        qd[ctail] <= rob_qd_i;

        ctail <= ttail;
        full <= ttail == chead || ttail + 1 == chead;
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
      if (ready[chead] && !empty && !dc_wait) begin
        dc_adr_o <= vk[chead] + imm[chead];
        dc_dat_o <= vj[chead];
        if (ls[chead]) begin
          dc_wait <= 1;
          dc_en_o <= 1;
          case (op[chead])
            6'b001011, 6'b001110: dc_len_o <= 1;  // LB, LBU
            6'b001100, 6'b001111: dc_len_o <= 2;  // LH, LHU
            6'b001101: dc_len_o <= 4;  // LW
            default: ;
          endcase
        end else if (!iob_full_i && rob_cmt_i) begin
          // commit store
          dc_wait <= 1;
          dc_en_o <= 1;
          case (op[chead])
            6'b010000: dc_len_o <= 1;  // SB
            6'b010001: dc_len_o <= 2;  // SH
            6'b010010: dc_len_o <= 4;  // SW
            default:   ;
          endcase
        end
      end

      // if DC finished, pop
      if (dc_en_i && dc_wait) begin
        dc_wait <= 0;
        if (ls[chead] <= 0) begin
          // reply the data
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
          q_o <= qd[chead];
          v_o <= dc_dat_i;
          rob_en_o <= 1;
          rs_en_o <= 1;
        end
        chead <= thead;
        if (!rob_en_i && !(ttail == chead || ttail + 1 == chead)) full <= 0;
      end

      // branch: stop every, because all afterward operations are exceeding
      if (br_flag_i) begin
        chead <= 0;
        ctail <= 0;
        for (i = 0; i < `LSB_S; i = i + 1) begin
          op[i]  <= 0;
          vj[i]  <= 0;
          vk[i]  <= 0;
          imm[i] <= 0;
          qj[i]  <= 0;
          qk[i]  <= 0;
          qd[i]  <= 0;
        end
        q_o <= 0;
        v_o <= 0;
      end
    end
  end


endmodule

`endif