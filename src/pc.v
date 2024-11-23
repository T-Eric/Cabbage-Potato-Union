// Program Counter
`include "utils/head.v"

module program_counter #(
    parameter ADDR_WIDTH = 17
) (
    input clk,
    input rst,

    input en,
    input read_en,
    input revise_en,
    input [ADDR_WIDTH-1:0] revise_in,

    output reg [ADDR_WIDTH-1:0] pc_out
);
// c:cur, t:then

always @(posedge clk or negedge rst) begin
  if(rst)begin
    pc_out <= 0;
  end else if(en) begin
    if(read_en)begin
      //TODO 需要控制在成功read之后再revise，或许read_en就是干这个的
      if(revise_en)pc_out<=revise_in;
      else pc_out<=pc_out+4;
    end
  end
end

endmodule
