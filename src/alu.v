// Arithmetic, maybe many(as Execution Unit)


module alu #(
    parameter REG_BIT = 5,
    parameter DATA_WIDTH = 32
) (
    input clk,
    input rst,

    input en,

    // from Reservation Station
    input [2:0] ins_type,  // or[31:0] ins, decode here?
    input [DATA_WIDTH-1:0] lhs,  //rs1
    input [DATA_WIDTH-1:0] rhs,  //rs2/imm 

    // to cdb
    // cdb_rob_id
    output reg cdb_alu_en,// one activate en from alu 
    output reg [REG_BIT-1:0] cdb_rd_out,
    output reg [DATA_WIDTH-1:0] cdb_data_out
);



endmodule
