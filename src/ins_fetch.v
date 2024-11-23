// Instruction Fetcher
// Connect: RS(io),ins_cache(io),
// Function: get current instruction for cpu, with decoding, into RS
// TODO: FIFO, decoder to control later elements,

module ins_fetch #(
    parameter ADDR_WIDTH = 17,
    parameter INS_WIDTH  = 32
) (
    input clk,
    input rst,

    // connect cpu
    input en,
    input addr_en,  // whether we need to fetch now
    input [ADDR_WIDTH-1:0] addr_get,  // address to fetch, connect pc
    output reg [INS_WIDTH:0] ins_out,
    output reg ins_ok,
    output reg busy,

    // connect ic
    output reg ins_call,  // call cache what i need
    output reg [ADDR_WIDTH-1:0] addr_out,
    input ins_get,  // whether ins_cache returned the ins
    input [INS_WIDTH-1:0] ins_in  // from ins_cache
);

  /*
states:
idle--default 
call-- if addr_en when idle, receive addr_get and put to ins_call, wait
reply--if ins_get,put ins_in to 

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
          if (ins_get) begin
            ins_call <= 0;
            ins_out <= ins_in;// 这就是issue了
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
