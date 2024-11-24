// Instruction Fetcher
// Connect: RS(io),ins_cache(io),
// Function: get current instruction for cpu, with decoding, into RS
// TODO: FIFO, decoder to control later elements,
`include "utils/head.v"

module ins_fetch (
    input clk,
    input rst,

    // to RS and ROB: decoded numbers
    input en,
    input addr_en,  // whether we need to fetch now
    input [`RAM_ADR_W-1:0] addr_get,  // address to fetch, connect pc
    output reg [`DAT_W:0] ins_out,
    output reg ins_ok,
    output reg busy,

    // from ic: get ins
    output reg ins_call,  // call cache what i need
    output reg [`RAM_ADR_W-1:0] addr_out,
    input cache_en,  // whether ins_cache returned the ins
    input [`DAT_W-1:0] cache_ins_in,  // from ins_cache

    // from/to pc: get or revise pc
    output reg pc_en_o,
    output reg pc_rev_en_o,
    output reg [`RAM_ADR_W-1:0] pc_rev_o,
    input [`RAM_ADR_W-1:0] pc_i
);

  /*
states:
idle--default 
call-- if addr_en when idle, receive addr_get and put to ins_call, wait
reply--if cache_en,put cache_ins_in to 

*/

  reg c_state, t_state;  //00-idle,01:call,10:reply

  always @(posedge clk or negedge rst) begin
    if (rst) begin
      ins_call <= 0;
      addr_out <= 0;
      c_state  <= 0;
      t_state  <= 0;
    end else if (en) begin
      c_state <= t_state;
      case (c_state)
        0: begin  // idle
          ins_ok <= 0;  // 不知道要不要给一点时间延迟
          if (addr_en) begin
            ins_call <= 1;
            addr_out <= addr_get;
            t_state <= 1;
            busy <= 1;
          end
        end
        1: begin  // call
          ins_call <= 0;  // 不到要不要手动关闭请求
          if (cache_en) begin
            ins_call <= 0;
            ins_out <= cache_ins_in;  // 这就是issue了
            ins_ok <= 1;
            t_state <= 0;
            busy <= 0;
          end
        end
        // TODO 状态2或者干脆状态1，可以连接更多事物，实现类似解码的功能
        // 对于不同的指令类型，可能届时添加更多output，直接指挥相关内容
        // 2:decode
        // decode的结果是完整指令、指令大类型、向不同方向传递的合适指令切片
      endcase
    end
  end

endmodule
