// Branch Predictor
// Connect: Ins-Fetch
// Function: take [7:2] of pc to predict branch or not.
`include "utils/head.v"
module branch_predictor (
    input clk,
    input rst,
    input en,

    // from IF: input pc
    input [`RAM_ADR_W-1:0] if_pc_i,
    output if_br_o,

    // from IF: feedback
    input if_en_i,
    input if_abr_i,  // actually branched or not
    input [`RAM_ADR_W-1:0] if_tpc_i  // then_pc, pc at that time
);

  reg  [1:0] counter[31:0];  // 10,11 -> jump


  // conbinational predict
  wire [5:0] hash;
  assign hash = if_pc_i[7:2];
  assign thash = if_tpc_i[7:2];
  assign if_br_o = counter[hash][1];

  // systematic revise
  integer i;
  always @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < 32; ++i) begin
        counter[i] <= 2'b10;  // weakly branch
      end
    end else if (en) begin
      if (if_en_i) begin
        if (if_abr_i && counter[thash] < 2'b11) counter[thash] <= counter[thash] + 1;
        else if (!if_abr_i && counter[thash] > 2'b00) counter[thash] <= counter[thash] - 1;
      end
    end
  end

endmodule
