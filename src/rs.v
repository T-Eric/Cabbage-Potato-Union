// Reservation Station
// Connect: ROB(in), LSB(in), ALU(io)
// Function: temp save stall instructions, wait for data to send to ALU

// 
`include "utils/head.v"
`include "common/fifo/fifo.v"

module moduleName #(
    parameter ADDR_WIDTH = 17,
    parameter DATA_WIDTH = 32,
    parameter REG_BIT = 5,
    parameter OP_WIDTH = 5
) (
    input clk,
    input rst,
    input en,

    // basic info, from/to ins_fetch, RF, ROB
    input ins_info_en,  // call me save stalled ins from ins_fetch
    input rob_index_en,  // call me save the index from ROB
    input [DATA_WIDTH-1:0] ins_full_in,  // MAYBE NO USE
    input [OP_WIDTH-1:0] op_in,
    input [`ROB_S_BIT-1:0] qj_in,  // former ins' ROB entry tag, 0 means no
    input [`ROB_S_BIT-1:0] qk_in,
    input [DATA_WIDTH-1:0] vj_in,  // real data to be used, rs1
    input [DATA_WIDTH-1:0] vk_in,  // rs2, load/store src reg
    input [DATA_WIDTH-1:0] ad_in,  // A, load/store offset, 
    input [`ROB_S_BIT-1:0] dest_in,  // index of entry in ROB, from ROB
    output reg insert_ready,  // tell them whether ready
    output reg full,  //tell them whether full, both then insert 
    output reg insert_ok,  // tell them whether ok

    // from/to ALU: if one instruction is ready()
    input alu_ready,  // alu tell me it's ready?
    input alu_ok,  // alu finished?
    output [DATA_WIDTH-1:0] lhs_alu,
    output [DATA_WIDTH-1:0] rhs_alu,
    output [DATA_WIDTH-1:0] op_alu,

    // from/to CDB: ALU->ROB->RS/RF
    input cdb_rs_en,  // one signal from rob and alu 
    input[`ROB_S_BIT-1:0] cdb_rob_id_in,
    input[REG_BIT-1:0] cdb_rd_in,
    input[DATA_WIDTH-1:0] cdb_data_in,
    output reg cdb_rs_ok  // whether it finnished reading the data
);

  reg [`RS_S-1:0] busy;
  reg [`INSSET_S_BIT-1:0] op[`RS_S-1:0];
  reg [DATA_WIDTH-1:0] vj[`RS_S-1:0];
  reg [DATA_WIDTH-1:0] vk[`RS_S-1:0];
  reg [DATA_WIDTH-1:0] ad[`RS_S-1:0];
  reg [`ROB_S_BIT-1:0] qj[`RS_S-1:0];
  reg [`ROB_S_BIT-1:0] qk[`RS_S-1:0];
  reg [`ROB_S_BIT-1:0] dest[`RS_S-1:0];

  reg [1:0] c_state, t_state;
  integer i;

  // pre-find one empty place
  reg [`RS_S_BIT-1:0] pre_empty_id;
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

  always @(posedge clk or negedge rst) begin
    if(rst)begin
      busy<=0;
      for(i=0;i<`RS_S;i=i+1)begin
        op[i]<=0;
        vj[i]<=0;
        vk[i]<=0;
        ad[i]<=0;
        qj[i]<=0;
        qk[i]<=0;
        dest[i]<=0;
      end
    end else if(en) begin
      // TODO 将新的指令放入空槽
      // 取出东西需要考虑指令类型
      //----------
      // 监控CDB，更新vj和qj
      if(cdb_rs_en)begin
        for(i=0;i<`RS_S;i=i+1)begin
          // TODO i的更新逻辑
          if(busy[i]&&qj[i]==cdb_rob_id_in)begin
            vj[i]<=cdb_data_in;
            qj[i]<=0;
          end
          if(busy[i]&&qk[i]==cdb_rob_id_in)begin
            vk[i]<=cdb_data_in;
            qk[i]<=0;
          end
        end
      end
    end
  end

endmodule
