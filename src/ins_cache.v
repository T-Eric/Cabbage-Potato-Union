// Instruction Cache, 2-way set-associative cache
// Connect: mem_io,ins_fetch,pc
// Function: directly give the right instruction according to the cpu_in
`include "src/head.v"
`ifndef IC_V
`define IC_V

module ins_cache (
    input clk,
    input rst,
    input en,

    // from/to IF
    input if_en_i,
    input [`DAT_W-1:0] if_pc_i,
    output reg if_en_o,
    output reg [`DAT_W-1:0] if_ins_o,

    // from/to memory 
    input mc_en_i,
    input [`DAT_W-1:0] mc_ins_i,
    output reg mc_en_o,
    output reg [`DAT_W-1:0] mc_pc_o,

    input br_flag
);
  // Opt 四位缓存还是太抽象了，稍大点循环就撑不住。必须扩大。但是能扩多大？
  // 先尝试最基本的64个，即index=[6:1],tag=[31:3]
  // 后期FPGA如果出问题了就改32个，或调整tag大小

  // Way 0
  reg [`DAT_W-1:0] data0[63:0];  // 4 sets
  reg [`DAT_W-8:0] tag0[63:0];
  reg valid0[63:0];
  reg lru0[63:0];  // least recently used
  // Way 1
  reg [`DAT_W-1:0] data1[63:0];
  reg [`DAT_W-8:0] tag1[63:0];
  reg valid1[63:0];
  reg lru1[63:0];

  wire [`DAT_W-8:0] tag;
  wire [5:0] index;
  wire t0, t1, hit;

  assign tag = if_pc_i[`DAT_W-1:7];
  assign index = if_pc_i[6:1];

  assign t0 = tag == tag0[index];
  assign t1 = tag == tag1[index];
  assign h0 = valid0[index] && t0;  // 在0
  assign h1 = valid1[index] && t1;  // 在1
  assign hit = (valid0[index] && t0) || (valid1[index] && t1);

  reg mc_wait;

  integer i;
  always @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < 64; i = i + 1) begin
        data0[i]  <= 0;
        data1[i]  <= 0;
        tag0[i]   <= 0;
        tag1[i]   <= 0;
        valid0[i] <= 0;
        valid1[i] <= 0;
      end
      mc_wait <= 0;
    end else if (en) begin
      mc_en_o <= 0;
      if_en_o <= 0;

      if (mc_en_i && mc_wait) begin
        mc_wait  <= 0;
        if_en_o  <= 1;
        if_ins_o <= mc_ins_i;
        if (!valid0[index]) begin
          if_en_o <= 1;
          data0[index] <= mc_ins_i;
          valid0[index] <= 1;
          tag0[index] <= tag;
          lru0[index] <= 0;
          lru1[index] <= 1;
        end else if (!valid1[index]) begin
          if_en_o <= 1;
          data1[index] <= mc_ins_i;
          valid1[index] <= 1;
          tag1[index] <= tag;
          lru1[index] <= 0;
          lru0[index] <= 1;
        end else if (lru0[index]) begin
          if_en_o <= 1;
          data0[index] <= mc_ins_i;
          valid0[index] <= 1;
          tag0[index] <= tag;
          lru0[index] <= 0;
          lru1[index] <= 1;
        end else if (lru1[index]) begin
          if_en_o <= 1;
          data1[index] <= mc_ins_i;
          valid1[index] <= 1;
          tag1[index] <= tag;
          lru1[index] <= 0;
          lru0[index] <= 1;
        end
      end

      if (if_en_i) begin
        if (h0) begin
          if_en_o <= 1;
          if_ins_o <= data0[index];
          lru0[index] <= 1'b0;
          lru1[index] <= 1'b1;
        end else if (h1) begin
          if_en_o <= 1;
          if_ins_o <= data1[index];
          lru0[index] <= 1'b1;
          lru1[index] <= 1'b0;
        end else begin
          // go to read
          mc_en_o <= 1;
          mc_pc_o <= if_pc_i;
          mc_wait <= 1;
        end
      end

      // bug: branch居然没有停止本次指令读取？你之前是怎么活下来的？
      // 此时一定是在读一个错误指令，直接掐断就行，mc那边也会掐断的
      if (br_flag) begin
        mc_en_o <= 0;
        if_en_o <= 0;
        mc_wait <= 0;
      end
    end
  end

endmodule

`endif
