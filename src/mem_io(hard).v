// Memory IO Controller
// Connect: ic, dc
// Function: directly connect ram, read according to different modes
// TODO: FIFO


module memory_io #(
    parameter ADDR_WIDTH = 17,
    parameter DATA_WIDTH = 32
) (
    input clk,
    input rst,

    input en,
    input data_en,  // call io to function
    input rw_en,  // read 1 write 0
    input [1:0] mode,  //0:1byte 1:2byte 2:4byte 

    input [31:0] addr_in,
    output reg ready,  // can be used
    output reg read_ok,  // already read, no need for write
    output reg ram_en,
    output reg ram_rw_en,
    output reg [ADDR_WIDTH-1:0] addr_out,

    input  data_in, 
    output reg [31:0] data_out
);

  reg [1:0] c_state, t_state;

  initial begin
    ready <= 1;
    read_ok <= 0;
    data_out <= 0;
    c_state <= 0;
    t_state <= 0;
  end

  always @(posedge clk or negedge rst) begin
    if (rst) begin
      ready <= 1;
      read_ok <= 0;
      data_out <= 0;
      c_state <= 0;
      t_state <= 0;
    end else if (en) begin
      c_state <= t_state;
      if (data_en) begin
        if (rw_en) begin
          // read, 此时应该可以不考虑位数，直接默认高八位？
          case (c_state)
            0: begin  // get and give, maybe fifo!
              t_state <= 1;
              ready <= 0;
              addr_out <= addr_in;
              ram_en <= 1;
              ram_rw_en <= 1;
            end
            1: begin // reply to src
              t_state<=2;// assert data_in has changed
              read_ok<=1;
              
            end
            2: begin
                // return to idle
              t_state <= 0;
              ready <= 1;
              read_ok <= 0;
              
            end
          endcase
        end else begin
          //write

        end
      end
    end
  end

endmodule
