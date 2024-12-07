// Memory IO Controller
// Connect: ic, dc
// Function: directly connect ram, read according to different modes
`include "utils/head.v"


module memory_io_controller (
    input clk,
    input rst,
    input en,

    // from/to IC
    input ic_en_i,
    input [`RAM_ADR_W-1:0] ic_pc_i,
    output reg ic_en_o,
    output [`DAT_W-1:0] ic_ins_o,

    // from DC: read or write
    input dc_en_i,
    input dc_rwen_i,
    input [2:0] dc_len_i,
    input [`RAM_ADR_W-1:0] dc_adr_i,
    input [`DAT_W-1:0] dc_dat_i,
    output reg dc_en_o,
    output [`DAT_W-1:0] dc_dat_o,

    // connect RAM
    input [7:0] ram_dat_i,
    output reg [7:0] ram_dat_o,
    output [`RAM_ADR_W-1:0] ram_adr_o,
    output ram_rwen_o,

    input br_flag
);

  reg icdc;  // who is in process
  reg rw;  // 0 R 1 W
  reg ic, dc;  // who is waiting
  reg [`RAM_ADR_W-1:0] iadr, dadr;
  reg [`DAT_W-1:0] idat, ddat;
  reg [2:0] iprc, dprc;  // process counter
  reg [2:0] len;

  assign ram_adr_o  = icdc ? dadr : iadr;
  assign ram_rwen_o = icdc ? dc_rwen_i : 0;
  // assign ram_dat_o=;
  assign ic_ins_o   = idat;
  assign dc_dat_o   = ddat;

  // RAM从读入地址到写回数据，有一个时钟周期的延迟
  always @(posedge clk) begin
    if (rst) begin
      icdc <= 0;
      rw   <= 0;
      ic   <= 0;
      dc   <= 0;
      iadr <= 0;
      dadr <= 0;
      idat <= 0;
      ddat <= 0;
      len  <= 0;
    end else if (en) begin
      // reset
      ic_en_o <= 0;
      dc_en_o <= 0;

      // receive request
      // 如果有一方enter process，他就会等待，他的en_i显然不会在结束前亮
      // 也就是，icdc偏向+对应ic=当前process
      if (ic_en_i) begin
        if (!dc) icdc <= 0;
        // if dc is not waiting(aka in process), start ic's process
        ic   <= 1;
        iadr <= ic_pc_i;
        iprc <= 0;

      end
      if (dc_en_i) begin
        if (!ic) icdc <= 1;
        dc <= 1;
        rw <= dc_rwen_i;
        len <= dc_rwen_i ? dc_len_i - 1 : dc_len_i;
        dadr <= dc_adr_i;
        ddat <= dc_dat_i;
        dprc <= 0;

        // 此时已经开始读写了，但是读在下个时期才会到
        // 但是现在必须立刻同步开始写
        ram_dat_o <= dc_dat_i[7:0];
      end

      // process
      if (icdc && dc) begin
        if (rw) begin
          case (dprc)
            0: ram_dat_o <= ddat[15:8];
            1: ram_dat_o <= ddat[23:16];
            2: ram_dat_o <= ddat[31:24];
          endcase
        end else begin
          case (dprc)  // TODO 如果发现要延迟两个周期就改成1234
            0: ddat[7:0] <= ram_dat_i;
            1: ddat[15:8] <= ram_dat_i;
            2: ddat[23:16] <= ram_dat_i;
            3: ddat[31:24] <= ram_dat_i;
          endcase
        end
        dprc <= dprc + 1;
        dadr <= dadr + 1;
      end else if (!icdc && ic) begin
        case (iprc)
          0: idat[7:0] <= ram_dat_i;
          1: idat[15:8] <= ram_dat_i;
          2: idat[23:16] <= ram_dat_i;
          3: idat[31:24] <= ram_dat_i;
        endcase
        iprc <= iprc + 1;
        iadr <= iadr + 1;
      end

      // submit
      if (dc && dprc == len) begin
        dprc <= 0;
        dc <= 0;
        dc_en_o <= 1;
        icdc <= 0;
      end
      if (ic && iprc == 4) begin
        iprc <= 0;
        ic <= 0;
        ic_en_o <= 1;
        if (dc || dc_en_i) icdc <= 1;
      end

      // jump: stop loading, finish current storing
      if (br_flag) begin
        if (ic) ic_en_o <= 0;
        ic   <= 0;
        iprc <= 0;
        if ((dc && rw) || (dc_en_i && dc_rwen_i)) icdc <= 1;
        else begin
          icdc <= 0;
          dc   <= 0;
          dprc <= 0;
        end
      end
    end
  end

endmodule
