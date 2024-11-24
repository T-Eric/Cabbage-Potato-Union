// Arithmetic, maybe many(as Execution Unit)


module alu #(
    parameter REG_BIT = 5,
    parameter DATA_WIDTH = 32
) (
    input clk,
    input rst,

    input en,

    // from Reservation Station
    input  rs_en_i, 
    input [2:0] tp,  // or[31:0] ins, decode here?
    input [5:0] op,
    input [DATA_WIDTH-1:0] lhs,  //rs1
    input [DATA_WIDTH-1:0] rhs,  //rs2/imm

    // to RS
    output reg rs_en_o,

    // to cdb
    // cdb_rob_id
    output reg cdb_alu_en,  // one activate en from alu 
    output reg [REG_BIT-1:0] cdb_rd_o,
    output reg [DATA_WIDTH-1:0] cdb_data_o
);



endmodule
