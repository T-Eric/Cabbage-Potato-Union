// Reservation Station
// Connect: ROB(in), LSB(in), ALU(io)
// Function: temp save stall instructions, wait for data to send to ALU

// 
`include "utils/head.v"
`include "common/fifo/fifo.v"

module reser_station (
    input clk,
    input rst,
    input en,

    // basic info, from/to ins_fetch, RF, ROB
    input ins_info_en,  // call me save stalled ins from ins_fetch
    input rob_index_en,  // call me save the index from ROB
    input [2:0] tp_in,
    input [`INSSET_BIT-1:0] op_in,
    input [`ROB_BIT-1:0] qj_in,  // former ins' ROB entry tag, 0 means no
    input [`ROB_BIT-1:0] qk_in,
    input [`DAT_W-1:0] vj_in,  // real data to be used, rs1
    input [`DAT_W-1:0] vk_in,  // rs2, load/store src reg
    input [`DAT_W-1:0] imm_i,
    input [`ROB_BIT-1:0] dest_in,  // index of ins in ROB, from ROB
    output reg full,  //tell them whether full, both then insert 
    output reg insert_ok,  // tell them whether ok

    // from/to ALU: if one instruction is ready()
    input alu_ready,  // alu tell me it's ready?
    output alu_en_out,
    output [`DAT_W-1:0] alu_lhs_out,
    output [`DAT_W-1:0] alu_rhs_out,
    output [`INSSET_BIT-1:0] alu_op_out,
    output [2:0] alu_tp_out,


    // from/to CDB: ALU->ROB->RS/RF
    input cdb_rs_en,  // one signal from rob and alu 
    input [`ROB_BIT-1:0] cdb_rob_id_in,
    input [`REG_BIT-1:0] cdb_rd_in,
    input [`DAT_W-1:0] cdb_data_in
);

  reg [`RS_S-1:0] busy;
  reg [`RS_S-1:0] send;  // must busy, this ins has sent to calc
  reg [`INSSET_BIT-1:0] op[`RS_S-1:0];
  reg [2:0] tp[`RS_S-1:0];
  reg [`DAT_W-1:0] vj[`RS_S-1:0];
  reg [`DAT_W-1:0] vk[`RS_S-1:0];
  reg [`DAT_W-1:0] ad[`RS_S-1:0];
  reg [`ROB_BIT-1:0] qj[`RS_S-1:0];
  reg [`ROB_BIT-1:0] qk[`RS_S-1:0];
  reg [`ROB_BIT-1:0] dest[`RS_S-1:0];

  reg [1:0] c_state, t_state;
  integer i;

  // pre-find one empty place
  reg [`RS_BIT-1:0] pre_empty_id;
  reg found_id;
  always @(posedge clk or negedge rst) begin
    if (rst) begin
      pre_empty_id <= 0;
      busy <= 0;
    end else if (en && !full) begin
      full = &busy;
      for (i = pre_empty_id; i < `RS_S; i = i + 1) begin
        if (!busy[i] && !found_id) begin
          pre_empty_id = i;
          found_id = 1;
        end
      end
      if (!found_id) begin
        for (i = 0; i <= pre_empty_id; i = i + 1) begin
          if (!busy[i] && !found_id) begin
            pre_empty_id = i;
            found_id = 1;
          end
        end
      end
    end
  end

  // write_in
  always @(posedge clk or negedge rst) begin
    if (rst) begin
      busy <= 0;
      for (i = 0; i < `RS_S; i = i + 1) begin
        op[i]   <= 0;
        tp[i]   <= 0;
        vj[i]   <= 0;
        vk[i]   <= 0;
        ad[i]   <= 0;
        qj[i]   <= 0;
        qk[i]   <= 0;
        dest[i] <= 0;
      end
    end else if (en) begin
      // TODO 将新的指令放入空槽
      // TODO 根据指令类型放东西，对于32(R2)的偏移类，直接组合逻辑计算后丢进
      // vk 或 A。之后编写时若立刻算出就不用A了，否则要用A。
      //----------
      // watch cdb and update qvjk
      if (cdb_rs_en) begin
        for (i = 0; i < `RS_S; i = i + 1) begin
          if (busy[i] && qj[i] == cdb_rob_id_in) begin
            vj[i] <= cdb_data_in;
            qj[i] <= 0;
          end
          if (busy[i] && qk[i] == cdb_rob_id_in) begin
            vk[i] <= cdb_data_in;
            qk[i] <= 0;
            // TODO load和store的更新逻辑
          end
        end
      end
    end
  end

  // send to ALU
  always @(posedge clk or negedge rst) begin
    if (rst) begin
      send <= 0;
    end else if (en) begin
      for (i = 0; i < `RS_S; i = i + 1) begin
        if (qj[i] == 0 && qk[i] == 0 && !send[i] && alu_ready) begin
          // TODO：根据不同指令类型，取数送到ALU
          send[i] <= 1;
        end
      end
    end
  end

  // watch CDB, ready to reset busy and send
  // TODO：我们暂且认为CDB提供的rob_id唯一指代RS中的一个entry
  always @(posedge clk or negedge rst) begin
    if (rst) begin
      //
    end else if (en && cdb_rs_en) begin
      // TODO 这个过程可能更复杂，不知道要不要CDB全程记录RS中的id
      // TODO 现在认为是，cdb_rs_en由ALU和ROB共同控制，所以dest[i]准确
      for (i = 0; i < `RS_S; i = i + 1) begin
        if (cdb_rob_id_in == dest[i] && send[i]) begin
          send[i] <= 0;
          busy[i] <= 0;
          dest[i] <= 0;
        end
      end
    end
  end

endmodule
