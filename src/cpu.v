// RISCV32 CPU top module
// port modification allowed for debugging purposes
// `include "src/head.v"
`include "src/alu.v"
`include "src/bp.v"
`include "src/data_cache.v"
`include "src/decoder.v"
`include "src/ins_cache.v"
`include "src/ins_fetch.v"
`include "src/lsb.v"
`include "src/mem_io.v"
`include "src/ram.v"
`include "src/rf.v"
`include "src/rob.v"
`include "src/rs.v"

`ifndef CPU_V
`define CPU_V

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

  // wires, from_to_which

  wire                  cdb_en;
  wire [  `ROB_BIT-1:0] cdb_q;
  wire [    `DAT_W-1:0] cdb_v;
  wire                  cdb_cbr;
  wire [    `DAT_W-1:0] cdb_cbt;

  wire                  bp_if_br;

  wire                  is_rf_en;
  wire                  is_rf_ic;
  wire [           1:0] is_rf_tp;
  wire [     `OP_W-1:0] is_rf_op;
  wire [  `REG_BIT-1:0] is_rf_rd;
  wire [  `REG_BIT-1:0] is_rf_rs1;
  wire [  `REG_BIT-1:0] is_rf_rs2;
  wire [    `DAT_W-1:0] is_rf_imm;
  wire [    `DAT_W-1:0] is_rf_pc;
  wire                  is_rob_en;
  wire                  is_rob_ic;
  wire [     `OP_W-1:0] is_rob_op;
  wire [           1:0] is_rob_tp;
  wire [  `REG_BIT-1:0] is_rob_rd;
  wire [    `DAT_W-1:0] is_rob_pc;
  wire                  is_rob_pbr;

  wire                  ic_if_en;
  wire [    `DAT_W-1:0] ic_if_ins;
  wire                  ic_mc_en;
  wire [    `DAT_W-1:0] ic_mc_pc;

  wire                  if_ic_en;
  wire [    `DAT_W-1:0] if_ic_pc;
  wire [    `DAT_W-1:0] if_bp_pc;
  wire                  if_bp_en;
  wire                  if_bp_abr;
  wire [    `DAT_W-1:0] if_bp_tpc;
  wire                  if_is_en;
  wire                  if_is_ic;
  wire [    `DAT_W-1:0] if_is_ins;
  wire [    `DAT_W-1:0] if_is_pc;
  wire                  if_is_pbr;

  wire                  lsb_mc_en;
  wire                  lsb_mc_rwen;
  wire [     `OP_W-1:0] lsb_mc_op;
  wire [           2:0] lsb_mc_len;
  wire [  `DAT_W - 1:0] lsb_mc_adr;
  wire [  `DAT_W - 1:0] lsb_mc_dat;
  wire [    `DAT_W-1:0] lsb_mc_pc;
  wire                  ldb_en;
  wire [`ROB_BIT - 1:0] ldb_q;
  wire [  `DAT_W - 1:0] ldb_v;
  wire                  lsb_full;
  wire                  lsb_cmt_full;

  wire                  mc_ic_en;
  wire [    `DAT_W-1:0] mc_ic_ins;
  wire                  mc_lsb_en;
  wire [    `DAT_W-1:0] mc_lsb_dat;
  wire [           7:0] mc_ram_dat;
  wire [    `DAT_W-1:0] mc_ram_adr;
  wire                  mc_ram_rwen;

  wire [           7:0] ram_d;

  wire                  rf_rs_en;
  wire                  rf_rs_ic;
  wire [  `ROB_BIT-1:0] rf_rs_qj;
  wire [  `ROB_BIT-1:0] rf_rs_qk;
  wire [    `DAT_W-1:0] rf_rs_vj;
  wire [    `DAT_W-1:0] rf_rs_vk;
  wire [  `ROB_BIT-1:0] rf_rs_qd;
  wire [    `DAT_W-1:0] rf_rs_pc;
  wire [     `OP_W-1:0] rf_rs_op;
  wire [    `DAT_W-1:0] rf_rs_imm;

  wire                  rf_lsb_en;
  wire [  `ROB_BIT-1:0] rf_lsb_qj;
  wire [  `ROB_BIT-1:0] rf_lsb_qk;
  wire [    `DAT_W-1:0] rf_lsb_vj;
  wire [    `DAT_W-1:0] rf_lsb_vk;
  wire [  `ROB_BIT-1:0] rf_lsb_qd;
  wire [     `OP_W-1:0] rf_lsb_op;
  wire [    `DAT_W-1:0] rf_lsb_imm;
  wire [    `DAT_W-1:0] rf_lsb_pc;

  wire [  `ROB_BIT-1:0] rf_rob_reqqj;
  wire [  `ROB_BIT-1:0] rf_rob_reqqk;
  wire                  rob_rf_rdyj;
  wire                  rob_rf_rdyk;
  wire [  `DAT_W - 1:0] rob_rf_rdyvj;
  wire [  `DAT_W - 1:0] rob_rf_rdyvk;

  wire [  `ROB_BIT-1:0] rob_rf_qd;
  wire                  rob_rs_en;
  wire                  rob_rs_ic;
  wire                  rob_lsb_cmt;
  wire                  rob_rf_en;
  wire [`REG_BIT - 1:0] rob_rf_rd;
  wire [`ROB_BIT - 1:0] rob_rf_q;
  wire [  `DAT_W - 1:0] rob_rf_v;
  wire                  rob_full;

  wire                  br_flag;
  wire                  br_abr;
  wire [    `DAT_W-1:0] br_tpc;
  wire [  `DAT_W - 1:0] br_cbt;

  wire                  rs_alu_en;
  wire [     `OP_W-1:0] rs_alu_op;
  wire                  rs_alu_ic;
  wire [  `ROB_BIT-1:0] rs_alu_qd;
  wire [    `DAT_W-1:0] rs_alu_vs;
  wire [    `DAT_W-1:0] rs_alu_vt;
  wire [    `DAT_W-1:0] rs_alu_imm;
  wire [    `DAT_W-1:0] rs_alu_pc;


  // units

  arith_logic_unit ALU (
      .clk(clk_in),
      .rst(rst_in),
      .en (rdy_in),

      .rs_en_i (rs_alu_en),
      .rs_op_i (rs_alu_op),
      .rs_ic_i (rs_alu_ic),
      .rs_qd_i (rs_alu_qd),
      .rs_vs_i (rs_alu_vs),
      .rs_vt_i (rs_alu_vt),
      .rs_imm_i(rs_alu_imm),
      .rs_pc_i (rs_alu_pc),

      .cdb_en_o (cdb_en),
      .cdb_q_o  (cdb_q),
      .cdb_v_o  (cdb_v),
      .cdb_cbr_o(cdb_cbr),
      .cdb_cbt_o(cdb_cbt)
  );

  branch_predictor BP (
      .clk(clk_in),
      .rst(rst_in),
      .en (rdy_in),

      // from IF: input pc
      .if_pc_i(if_bp_pc),
      .if_br_o(bp_if_br),

      // from IF: feedback
      .if_en_i (if_bp_en),
      .if_abr_i(if_bp_abr),
      .if_tpc_i(if_bp_tpc)

  );

  decoder DEC (
      .clk(clk_in),
      .rst(rst_in),
      .en (rdy_in),

      .if_en_i (if_is_en),
      .if_ic_i (if_is_ic),
      .if_ins_i(if_is_ins),
      .if_pc_i (if_is_pc),
      .if_pbr_i(if_is_pbr),

      .rf_en_o (is_rf_en),
      .rf_ic_o (is_rf_ic),
      .rf_tp_o (is_rf_tp),
      .rf_op_o (is_rf_op),
      .rf_rd_o (is_rf_rd),
      .rf_rs1_o(is_rf_rs1),
      .rf_rs2_o(is_rf_rs2),
      .rf_imm_o(is_rf_imm),
      .rf_pc_o (is_rf_pc),

      .rob_en_o (is_rob_en),
      .rob_ic_o (is_rob_ic),
      .rob_tp_o (is_rob_tp),
      .rob_rd_o (is_rob_rd),
      .rob_pc_o (is_rob_pc),
      .rob_op_o (is_rob_op),
      .rob_pbr_o(is_rob_pbr)
  );

  ins_cache IC (
      .clk(clk_in),
      .rst(rst_in),
      .en (rdy_in),

      .if_en_i (if_ic_en),
      .if_pc_i (if_ic_pc),
      .if_en_o (ic_if_en),
      .if_ins_o(ic_if_ins),

      // from/to memory 
      .mc_en_i (mc_ic_en),
      .mc_ins_i(mc_ic_ins),
      .mc_en_o (ic_mc_en),
      .mc_pc_o (ic_mc_pc),

      .br_flag(br_flag)
  );

  ins_fetch IF (
      .clk(clk_in),
      .rst(rst_in),
      .en (rdy_in),

      .ic_en_i (ic_if_en),
      .ic_ins_i(ic_if_ins),
      .ic_en_o (if_ic_en),
      .ic_pc_o (if_ic_pc),

      .br_flag_i(br_flag),
      .br_abr_i (br_abr),
      .br_tpc_i (br_tpc),
      .br_cbt_i (br_cbt),

      .bp_pc_o (if_bp_pc),
      .bp_br_i (bp_if_br),
      .bp_en_o (if_bp_en),
      .bp_abr_o(if_bp_abr),
      .bp_tpc_o(if_bp_tpc),

      .is_en_o (if_is_en),
      .is_ic_o (if_is_ic),
      .is_ins_o(if_is_ins),
      .is_pc_o (if_is_pc),
      .is_pbr_o(if_is_pbr),

      .full_i(lsb_full || rob_full || lsb_cmt_full)  // TODO, LSB+RS+ROB
  );

  load_store_buffer LSB (
      .clk(clk_in),
      .rst(rst_in),
      .en (rdy_in),

      .rf_en_i (rf_lsb_en),
      .rf_op_i (rf_lsb_op),
      .rf_qj_i (rf_lsb_qj),
      .rf_qk_i (rf_lsb_qk),
      .rf_vj_i (rf_lsb_vj),
      .rf_vk_i (rf_lsb_vk),
      .rf_qd_i (rf_lsb_qd),
      .rf_imm_i(rf_lsb_imm),
      .rf_pc_i (rf_lsb_pc),

      // Visit Memory
      .dc_en_o  (lsb_mc_en),
      .dc_rwen_o(lsb_mc_rwen),
      .dc_op_o  (lsb_mc_op),
      .dc_len_o (lsb_mc_len),
      .dc_adr_o (lsb_mc_adr),
      .dc_dat_o (lsb_mc_dat),
      .dc_pc_o  (lsb_mc_pc),
      .dc_en_i  (mc_lsb_en),
      .dc_dat_i (mc_lsb_dat),

      // Output LOAD Result
      .ldb_en_o(ldb_en),
      .ldb_q_o (ldb_q),
      .ldb_v_o (ldb_v),

      .cdb_en_i(cdb_en),
      .cdb_q_i (cdb_q),
      .cdb_v_i (cdb_v),

      .rob_cmt_i(rob_lsb_cmt),
      .rob_cmt_full(lsb_cmt_full),

      .br_flag(br_flag),

      .full(lsb_full),

      .iob_full_i(io_buffer_full)
  );

  memory_io_controller MC (
      .clk(clk_in),
      .rst(rst_in),
      .en (rdy_in),

      .ic_en_i (ic_mc_en),
      .ic_pc_i (ic_mc_pc),
      .ic_en_o (mc_ic_en),
      .ic_ins_o(mc_ic_ins),

      .dc_en_i  (lsb_mc_en),
      .dc_rwen_i(lsb_mc_rwen),
      .dc_op_i  (lsb_mc_op),
      .dc_len_i (lsb_mc_len),
      .dc_adr_i (lsb_mc_adr),
      .dc_dat_i (lsb_mc_dat),
      .dc_pc_i  (lsb_mc_pc),
      .dc_en_o  (mc_lsb_en),
      .dc_dat_o (mc_lsb_dat),

      .ram_dat_i (mem_din),
      .ram_dat_o (mem_dout),
      .ram_adr_o (mem_a),
      .ram_rwen_o(mem_wr),

      .br_flag(br_flag)
  );

  register_file RF (
      .clk(clk_in),
      .rst(rst_in),
      .en (rdy_in),

      .is_en_i (is_rf_en),
      .is_ic_i (is_rf_ic),
      .is_tp_i (is_rf_tp),
      .is_rd_i (is_rf_rd),
      .is_rs1_i(is_rf_rs1),
      .is_rs2_i(is_rf_rs2),
      .is_op_i (is_rf_op),
      .is_imm_i(is_rf_imm),
      .is_pc_i (is_rf_pc),

      .rob_en_i(rob_rf_en),
      .rob_rd_i(rob_rf_rd),
      .rob_q_i (rob_rf_q),
      .rob_v_i (rob_rf_v),
      .rob_qd_i(rob_rf_qd),

      .rob_reqqj_o(rf_rob_reqqj),
      .rob_reqqk_o(rf_rob_reqqk),
      .rob_rdyj_i (rob_rf_rdyj),
      .rob_rdyk_i (rob_rf_rdyk),
      .rob_rdyvj_i(rob_rf_rdyvj),
      .rob_rdyvk_i(rob_rf_rdyvk),

      .rs_en_o (rf_rs_en),
      .rs_ic_o (rf_rs_ic),
      .rs_qj_o (rf_rs_qj),
      .rs_qk_o (rf_rs_qk),
      .rs_vj_o (rf_rs_vj),
      .rs_vk_o (rf_rs_vk),
      .rs_qd_o (rf_rs_qd),
      .rs_pc_o (rf_rs_pc),
      .rs_op_o (rf_rs_op),
      .rs_imm_o(rf_rs_imm),

      .lsb_en_o (rf_lsb_en),
      .lsb_qj_o (rf_lsb_qj),
      .lsb_qk_o (rf_lsb_qk),
      .lsb_vj_o (rf_lsb_vj),
      .lsb_vk_o (rf_lsb_vk),
      .lsb_qd_o (rf_lsb_qd),
      .lsb_op_o (rf_lsb_op),
      .lsb_imm_o(rf_lsb_imm),
      .lsb_pc_o (rf_lsb_pc),

      .cdb_en_i(cdb_en),
      .cdb_q_i (cdb_q),
      .cdb_v_i (cdb_v),

      .ldb_en_i(ldb_en),
      .ldb_q_i (ldb_q),
      .ldb_v_i (ldb_v),

      .br_flag(br_flag)
  );

  reorder_buffer ROB (
      .clk(clk_in),
      .rst(rst_in),
      .en (rdy_in),

      .is_en_i (is_rob_en),
      .is_ic_i (is_rob_ic),
      .is_tp_i (is_rob_tp),
      .is_op_i (is_rob_op),
      .is_rd_i (is_rob_rd),
      .is_pc_i (is_rob_pc),
      .is_pbr_i(is_rob_pbr),

      .lsb_cmt_o(rob_lsb_cmt),
      .lsb_cmt_full_i(lsb_cmt_full),
      .lsb_en_i(ldb_en),
      .lsb_q_i(ldb_q),
      .lsb_v_i(ldb_v),

      .cdb_en_i (cdb_en),
      .cdb_q_i  (cdb_q),
      .cdb_v_i  (cdb_v),
      .cdb_cbr_i(cdb_cbr),
      .cdb_cbt_i(cdb_cbt),

      .rf_en_o(rob_rf_en),
      .rf_rd_o(rob_rf_rd),
      .rf_q_o (rob_rf_q),
      .rf_v_o (rob_rf_v),
      .rf_qd_o(rob_rf_qd),

      .rf_reqqj_i(rf_rob_reqqj),
      .rf_reqqk_i(rf_rob_reqqk),
      .rf_rdyj_o (rob_rf_rdyj),
      .rf_rdyk_o (rob_rf_rdyk),
      .rf_rdyvj_o(rob_rf_rdyvj),
      .rf_rdyvk_o(rob_rf_rdyvk),

      .br_flag(br_flag),
      .br_abr (br_abr),
      .br_tpc (br_tpc),
      .br_cbt (br_cbt),

      .full(rob_full)
  );

  reser_station RS (
      .clk(clk_in),
      .rst(rst_in),
      .en (rdy_in),

      .rf_en_i (rf_rs_en),
      .rf_op_i (rf_rs_op),
      .rf_ic_i (rf_rs_ic),
      .rf_qj_i (rf_rs_qj),
      .rf_qk_i (rf_rs_qk),
      .rf_vj_i (rf_rs_vj),
      .rf_vk_i (rf_rs_vk),
      .rf_qd_i (rf_rs_qd),
      .rf_imm_i(rf_rs_imm),
      .rf_pc_i (rf_rs_pc),

      .lsb_en_i(ldb_en),
      .lsb_q_i (ldb_q),
      .lsb_v_i (ldb_v),
      .cdb_en_i(cdb_en),
      .cdb_q_i (cdb_q),
      .cdb_v_i (cdb_v),

      .alu_en_o (rs_alu_en),
      .alu_op_o (rs_alu_op),
      .alu_ic_o (rs_alu_ic),
      .alu_qd_o (rs_alu_qd),
      .alu_vs_o (rs_alu_vs),
      .alu_vt_o (rs_alu_vt),
      .alu_imm_o(rs_alu_imm),
      .alu_pc_o (rs_alu_pc),

      .br_flag(br_flag)
  );

  // indicator

  reg [31:0] counter;

  initial begin
    counter = 0;
  end

  always @(posedge clk_in) begin
    counter <= counter + 1;
    if (counter % 500 == 0) begin
    //   $display("---Time: %dns---", counter * 2);
    end
  end

endmodule

`endif
