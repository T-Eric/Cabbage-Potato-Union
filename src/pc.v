// Program Counter
`include "utils/head.v"

module program_counter(
    input clk,
    input rst,

    input en,
    input read_en,
    input revise_en,
    input [`RAM_ADR_W-1:0] rev_pc_i,

    output reg [`RAM_ADR_W-1:0] pc_o
);
// c:cur, t:then

always @(posedge clk or negedge rst) begin
  if(rst)begin
    pc_o <= 0;
  end else if(en) begin
    if(read_en)begin
      //TODO 需要控制在成功read之后再revise，或许read_en就是干这个的
      if(revise_en)pc_o<=rev_pc_i;
      else pc_o<=pc_o+4;
    end
  end
end

endmodule
