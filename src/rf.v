// Register File, 32 registers

// 还没有对同步读写做适配
// 还没有与ROB联动

`include "utils/head.v"

module register_file#(
  parameter REG_CARD_WIDTH=5,
  parameter DATA_WIDTH=32
) (
    input clk,
    input rst,

    input en,  // full control
    input read_en,
    input write_en,

    input [REG_CARD_WIDTH-1:0] rd,
    input [REG_CARD_WIDTH-1:0] rs1,
    input [REG_CARD_WIDTH-1:0] rs2,

    input [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out1,
    output reg [DATA_WIDTH-1:0] data_out2
);
  //该寄存器的值会被前面的指令更新，用该寄存器作为源操作数的需要等待CDB将更新后的值传输过来。
  reg [`ROB_S_BIT-1:0] reorder[REG_CARD_WIDTH-1:0];
  reg [`ROB_S_BIT-1:0] busy[REG_CARD_WIDTH-1:0];
  reg [DATA_WIDTH-1:0] regs[REG_CARD_WIDTH-1:0];
  integer i;

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      for (i = 0; i < 32; i = i + 1) regs[i] <= 0;

    end else if (en) begin
      if (read_en) begin
        regs[rd] <= data_in;
      end
      if (write_en) begin
        data_out1 <= regs[rs1];
        data_out2 <= regs[rs2];
      end
    end
  end

  always @(posedge clk or negedge rst) begin
    if(en)begin
      regs[0]<=0;// always keep it zero
    end
  end
endmodule
