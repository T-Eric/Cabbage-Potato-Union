// Instruction Cache, 2-way set-associative cache
// Connect: mem_io,ins_fetch,pc
// Function: directly give the right instruction according to the cpu_in

module ins_cache (
    input clk,
    input rst,

    // from memory
    input mem_en,
    input [31:0] mem_in,
    output mem_req,
    // to CPU
    input cpu_en,  // cpu requires to read
    input [31:0] cpu_in,  // address
    output reg cpu_ok,  // call cpu to receive the cpu_out
    output reg [31:0] cpu_out,  // inst to cpu
    output hit
);

  // Way 0
  reg [31:0] data0[3:0];  // 4 sets
  reg [27:0] tag0[3:0];
  reg [3:0] valid0;
  reg [3:0] lru0;
  // Way 1
  reg [31:0] data1[3:0];
  reg [27:0] tag1[3:0];
  reg [3:0] valid1;
  reg [3:0] lru1;

  wire [26:0] tag;
  wire [1:0] index;
  wire t0, h0, t1, h1;

  assign tag = cpu_in[31:4];  // 
  assign index = cpu_in[3:2];  // use [3:2] to determine which place

  assign t0 = tag == tag0[index];
  assign t1 = tag == tag1[index];
  assign h0 = valid0[index] && t0;  // 在0
  assign h1 = valid1[index] && t1;  // 在1
  assign hit = h0 | h1;

  always @(posedge clk) begin
    if (rst == 1) begin
      valid0 <= 8'h00;
      valid1 <= 8'h00;
    end

    if (cpu_en) begin
      if (h0) begin
        cpu_out <= data0[index][31:0];
        cpu_ok <= 1'b1;
        lru0[index] <= 1'b0;
        lru1[index] <= 1'b1;
      end else if (h1) begin
        cpu_out <= data1[index][31:0];
        cpu_ok <= 1'b1;
        lru0[index] <= 1'b1;
        lru1[index] <= 1'b0;
      end else begin
        cpu_ok <= 1'b0;  // no hit, not ready for reading
      end
    end

    if (mem_en) begin
      if (!valid0[index]) begin
        // direct insert to 0
        data0[index][31:0] <= mem_in;
        cpu_ok <= 1;
        valid0[index] <= 1'b1;
        tag0[index] <= tag;
        lru0[index] <= 1'b0;
        lru1[index] <= 1'b1;
      end else if (!valid1[index]) begin
        data1[index][31:0] <= mem_in;
        cpu_ok <= 1;
        valid1[index] <= 1'b1;
        tag1[index] <= tag;
        lru1[index] <= 1'b0;
        lru0[index] <= 1'b1;
      end else if (lru0[index]) begin
        // overwrite 0
        data0[index][31:0] <= mem_in;
        cpu_ok <= 1;
        valid0[index] <= 1'b1;
        tag0[index] <= tag;
        lru0[index] <= 1'b0;
        lru1[index] <= 1'b1;
      end else if (lru1[index]) begin
        //overwrite 1
        data0[index][31:0] <= mem_in;
        cpu_ok <= 1;
        valid0[index] <= 1'b1;
        tag0[index] <= tag;
        lru0[index] <= 1'b0;
        lru1[index] <= 1'b1;
      end
      cpu_ok <= repeat (1) @(negedge clk) 0;
      // return to 0, maybe we can do this in 
    end
    
  end
endmodule
