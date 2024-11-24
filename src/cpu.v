// RISCV32 CPU top module
// port modification allowed for debugging purposes
`include "alu.v"
`include "data_cache.v"
`include "ins_cache.v"
`include "ins_fetch.v"
`include "lsb.v"
`include "mem_io(hard).v"
`include "pc.v"
`include "ram.v"
`include "rf.v"
`include "rob.v"
`include "rs.v"

module cpu (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input  wire [ 7:0] mem_din,   // data input bus
    output wire [ 7:0] mem_dout,  // data output bus
    output wire [31:0] mem_a,     // address bus (only 17:0 is used)
    output wire        mem_wr,    // write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full

    output wire [31:0] dbgreg_dout  // cpu register output (debugging demo)
);

  // implementation goes here

  // Specifications:
  // - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
  // - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
  // - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
  // - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
  // - 0x30000 read: read a byte from input
  // - 0x30000 write: write a byte to output (write 0x00 is ignored)
  // - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
  // - 0x30004 write: indicates program stop (will output '\0' through uart tx)

  // connect the items

  // TODO 还没有考虑好ins_fetch和issue之间的关系和职能分配
  assign en_in = rdy_in;  // en for all

  wire pc_if_read_en, pc_if_en, pc_if_rev_en;
  wire [`RAM_ADR_W-1:0] pc_if_rev, pc;

  // from ROB: TODO: 先传入一切必要的信息
  wire                    rob_lsb_en;
  wire [     `OP_W - 1:0] rob_lsb_op;
  wire [    `DAT_W - 1:0] rob_lsb_imm;
  wire [  `ROB_BIT - 1:0] rob_lsb_qj;
  wire [  `ROB_BIT - 1:0] rob_lsb_qk;
  wire [    `DAT_W - 1:0] rob_lsb_vj;
  wire [    `DAT_W - 1:0] rob_lsb_vk;
  wire [  `ROB_BIT - 1:0] rob_lsb_qd;

  // Visit Memory
  wire                    lsb_dc_en;
  wire                    lsb_dc_rwen;  // 0:R; 1:W
  wire [             2:0] lsb_dc_len;  // 1:B; 2:H; 4:W
  wire [`RAM_ADR_W - 1:0] lsb_dc_adr;
  wire [    `DAT_W - 1:0] lsb_dc_dat;
  wire                    dc_lsb_en;
  wire [    `DAT_W - 1:0] dc_lsb_dat;

  // Output LOAD Result，可能与CDB冲突，先考虑不放在一起
  // 如果没有进一步操作，q和v不用wire
  wire                    rs_en_o;
  wire [  `ROB_BIT - 1:0] rs_q_o;
  wire [    `DAT_W - 1:0] rs_v_o;

  wire                    rob_en_o;
  wire [  `ROB_BIT - 1:0] rob_q_o;
  wire [    `DAT_W - 1:0] rob_v_o;

  // CDB
  wire                    cdb_en;
  wire [  `ROB_BIT - 1:0] cdb_q;
  wire [    `DAT_W - 1:0] cdb_v;
  wire [`RAM_ADR_W - 1:0] cdb_br_to;
  wire alu_cdb_en, rob_cdb_en;
  assign cdb_en = alu_cdb_en & rob_cdb_en;

  // ROB-RF
  wire rob_rf_en;
  wire [`REG_BIT-1:0] rob_rf_rd;
  wire [`ROB_BIT-1:0] rob_rf_q;
  wire [`DAT_W-1:0] rob_rf_v;

  wire rf_rob_en;
  wire [`ROB_BIT-1:0] rf_rob_qj;
  wire [`ROB_BIT-1:0] rf_rob_qk;
  wire [`DAT_W-1:0] rf_rob_vj;
  wire [`DAT_W-1:0] rf_rob_vk;
  wire [`ROB_BIT-1:0] rf_rob_qd;

  wire [`OP_W-1:0] rf_rob_op;
  wire [`DAT_W-1:0] rf_rob_imm;

  program_counter PC (
      .clk(clk_in),
      .rst(rst_in),
      .en(en_in),
      .read_en_i(pc_if_read_en),
      .rev_en_i(pc_if_rev_en),
      .rev_pc_i(pc_if_rev),
      .pc_o(pc)
  );

  ins_fetch IF (
      .clk(clk_in),
      .rst(rst_in),
      .en (en_in),

      .pc_en_o(pc_if_read_en),
      .pc_rev_en_o(pc_if_rev_en),
      .pc_rev_o(pc_if_rev),
      .pc_i(pc)
  );

  load_store_buffer LSB (
      .clk(clk_in),
      .rst(rst_in),
      .en (en_in),

      .rob_en_i (rob_lsb_en),
      .rob_op_i (rob_lsb_op),
      .rob_imm_i(rob_lsb_imm),
      .rob_qj_i (rob_lsb_qj),
      .rob_qk_i (rob_lsb_qk),
      .rob_vj_i (rob_lsb_vj),
      .rob_vk_i (rob_lsb_vk),
      .rob_qd_i (rob_lsb_qd),

      .dc_en_o  (lsb_dc_en),
      .dc_rwen_o(lsb_dc_rwen),
      .dc_len_o (lsb_dc_len),
      .dc_adr_o (lsb_dc_adr),
      .dc_dat_o (lsb_dc_dat),
      .dc_en_i  (dc_lsb_en),
      .dc_dat_i (dc_lsb_dat)
  );

  reorder_buffer ROB (
      .clk(clk_in),
      .rst(rst_in),
      .en (en_in),

      .rf_en_i(rf_rob_en),
      .rf_qj_i(rf_rob_qj),
      .rf_qk_i(rf_rob_qk),
      .rf_vj_i(rf_rob_vj),
      .rf_vk_i(rf_rob_vk),
      .rf_qd_i(rf_rob_qd),
      .rf_op_i(rf_rob_op),
      .rf_imm_i(rf_rob_imm),

      .rf_en_o(rob_rf_en),
      .rf_rd_o(rob_rf_rd),
      .rf_q_o(rob_rf_q),
      .rf_v_o(rob_rf_v)
  );

  register_file RF (
      .clk(clk_in),
      .rst(rst_in),
      .en (en_in)
  );


  always @(posedge clk_in) begin
    if (rst_in) begin

    end else
    if (!rdy_in) begin

    end else begin

    end
  end

endmodule
