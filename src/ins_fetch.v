// Instruction Fetcher
// Connect: ins_cache,decoder
// Function: fetch, judge rv32i or c, then issue to rf and rob
`include "src/head.v"
`ifndef IF_V
`define IF_V

module ins_fetch (
    input clk,
    input rst,
    input en,

    // from/to IC: get and receive
    input ic_en_i,
    input [`DAT_W-1:0] ic_ins_i,
    output reg ic_en_o,
    output [`DAT_W-1:0] ic_pc_o,

    // from ROB: branching
    input br_flag_i,
    input br_abr_i,  // actually branched or not  
    input [`DAT_W-1:0] br_tpc_i,  // pc where branch happened
    input [`DAT_W-1:0] br_cbt_i,  // calced branch to

    // from/to Prd: predict branch. This is conbinational
    output [`DAT_W-1:0] bp_pc_o,
    input bp_br_i,  // predicted branch or not,
    // from/to Prd: feedback. This is synchronous because we won't read that fast
    output bp_en_o,
    output bp_abr_o,  // actually jumped or not
    output [`DAT_W-1:0] bp_tpc_o,  // then pc

    // to Dec: give the instruction
    output reg is_en_o,
    output reg is_ic_o,  // 0 I 1 C
    output reg [`DAT_W-1:0] is_ins_o,
    output reg [`DAT_W-1:0] is_pc_o,
    output reg is_pbr_o,

    // from ROB/RS/LSB: if FULL stop fetching
    input full_i
);
  // 1. PC没必要单独一个元件，应当直接装进IF中
  // 2. JAL虽然跳转，但是可以直接跳，没必要拉到后面去，等效赋值语句；JALR虽然无条件，但是必须要算，则归为Branch指令
  reg [`DAT_W-1:0] pc;
  // reg ic_wait;  // waiting for ic's ins

  wire ins_ic;  // i 0 c 1, depend on ic_ins_i[1:0]
  wire [`DAT_W-1:0] ijal_dst, cjal_dst, ibr_dst, cbr_dst;  // direct calculation
  wire [6:0] iopcode;
  wire [4:0] copcode;

  // 这个dst对j和jal都有用
  assign ins_ic = ic_ins_i[1:0] != 2'b11;  // 这样就可以了
  assign ijal_dst = pc + {{12{ic_ins_i[31]}}, ic_ins_i[19:12], ic_ins_i[20], ic_ins_i[30:21], 1'b0};
  assign cjal_dst = pc + {{21{ic_ins_i[12]}},ic_ins_i[8],ic_ins_i[10:9],ic_ins_i[6],ic_ins_i[7],ic_ins_i[2],ic_ins_i[11],ic_ins_i[5:3],1'b0};
  assign ibr_dst = pc + {{21{ic_ins_i[31]}}, ic_ins_i[7], ic_ins_i[30:25], ic_ins_i[11:8], 1'b0};
  assign cbr_dst = pc + {{24{ic_ins_i[12]}}, ic_ins_i[6:5], ic_ins_i[2], ic_ins_i[11:10], ic_ins_i[4:3], 1'b0};
  assign iopcode = ic_ins_i[6:0];
  assign copcode = {ic_ins_i[15:13], ic_ins_i[1:0]};

  assign ic_pc_o = pc;
  assign bp_pc_o = pc;
  assign bp_en_o = br_flag_i;
  assign bp_abr_o = br_abr_i;
  assign bp_tpc_o = br_tpc_i;  // 反馈给BP

  // jalr, c.jr, c.jalr，不预测，不跳转，也就是必定mispredict
  // 所以要特地判断出来
  // 是不是在decoder中已经做了？
  wire ins_jalr;
  assign ins_jalr = (!ins_ic && (ic_ins_i[6:0] == 7'b1101111) && (ic_ins_i[14:12] == 3'b000))||(ins_ic&&((ic_ins_i[15:12]==4'b1000||ic_ins_i[15:12]==4'b1001)&&ic_ins_i[6:0]==7'b0000010));

  always @(posedge clk) begin
    if (rst) begin
      pc <= 0;
      // ic_wait <= 0;
      ic_en_o <= 0;
      is_en_o <= 0;
    end else if (en && br_flag_i) begin
      // branch: 修改预测结果，执行跳转
      pc <= br_cbt_i;
      // ic_wait <= 0;
      ic_en_o <= 0;
      is_en_o <= 0;
    end else if (en) begin
      // 喊出，并等待
      ic_en_o <= 0;
      is_en_o <= 0;

      // 适配组合逻辑icache做出的修改：ic_wait好像没用
      // 如果当前pc无法对应hit，即ic_en_i=0，则进入等待
      // 否则该pc可以直接送出
      if (!full_i && !ic_en_i) ic_en_o <= 1;

      if (!full_i && ic_en_i) begin
        is_en_o  <= 1;
        is_pc_o  <= pc;
        is_ins_o <= ic_ins_i;
        is_ic_o  <= ins_ic;
        is_pbr_o <= bp_br_i;

        if (ins_ic) begin
          // RV23C
          case (copcode)
            5'b10101, 5'b00101: begin  // c.jal & c.j, 
              pc <= cjal_dst;
            end
            5'b11001, 5'b11101: begin  // branches, c.beqz&c.bnez
              // 从bp那里预测要不要跳，如果不要就pc+2，否则转到br直接算出来的位置
              if (bp_br_i) begin
                pc <= cbr_dst;
              end else begin
                pc <= pc + 2;
              end
            end
            default: begin
              pc <= pc + 2;
            end
          endcase
        end else begin
          // RV32I
          case (iopcode)
            7'b1101111: begin  // jal
              pc <= ijal_dst;
            end
            7'b1100011: begin  // branches
              if (bp_br_i) begin
                pc <= ibr_dst;
              end else begin
                pc <= pc + 4;
              end
            end
            default: begin
              pc <= pc + 4;  // jalr直接认为是跳转
            end
          endcase
        end
      end
    end
  end

endmodule

`endif
