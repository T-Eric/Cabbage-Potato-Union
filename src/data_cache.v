// Data Cache
// Almost same as ins_cache
// // Connect: LSB, MioC, ROB(for branching)
// if need branching, force all pending writes
// 实际上没有起到一个cache的作用，只是作为一个中间者传递数据
// 因为同时涉及读写，不能像ins那样直接cache（自己就修改疯了）
`include "utils/head.v"

module data_cache (
    input clk,
    input rst,
    input en,

    // from/to LSB
    input lsb_en_i,  // call me
    input lsb_rwen_i,  // READ 1 WRITE 0
    input [2:0] lsb_len_i,
    input [`RAM_ADR_W-1:0] lsb_adr_i,
    input [`DAT_W-1:0] lsb_dat_i,
    output reg lsb_en_o,  // call lsb
    output reg [`DAT_W-1:0] lsb_dat_o,

    // from/to memory io control
    input mc_en_i,  // mc ready to write
    input mc_dat_i,
    output reg mc_en_o,  // call mc to rw
    output reg mc_rwen_o,  // READ 1 WRITE 0
    output reg [2:0] mc_len_o,
    output reg [`RAM_ADR_W-1:0] mc_adr_o,
    output reg [`DAT_W-1:0] mc_dat_o,

    // from ROB, branching
    input rob_br_flag
);

  always @(posedge clk) begin
    if (rst) begin
      lsb_en_o  <= 0;
      lsb_dat_o <= 0;
      mc_en_o   <= 0;
      mc_rwen_o <= 0;
      mc_adr_o  <= 0;
      mc_len_o  <= 0;
      mc_dat_o  <= 0;
    end else if (en) begin
      // TODO 立刻就归零了，没有等人家！有待商榷
      lsb_en_o <= 0;
      mc_en_o  <= 0;
      if (lsb_en_i) begin
        mc_rwen_o <= lsb_rwen_i;
        mc_len_o  <= lsb_len_i;
        mc_adr_o  <= lsb_adr_i;
        mc_dat_o  <= lsb_dat_i;

        mc_en_o   <= 1;
      end
      if (mc_en_i) begin
        lsb_dat_o <= mc_dat_i;
        lsb_en_o  <= 1;
      end
    end

    // br>en
    if (!rst && rob_br_flag && lsb_en_i && lsb_rwen_i) begin
      // lsb calling to read
      mc_rwen_o <= lsb_rwen_i;
      mc_len_o  <= lsb_len_i;
      mc_adr_o  <= lsb_adr_i;
      mc_dat_o  <= lsb_dat_i;

      mc_en_o   <= 1;
    end
  end

endmodule
