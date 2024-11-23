// Immediate Generation
// Function: combination logic, turn one insuction directly then put to ALU

module imm_gen #(
    parameter DATA_WIDTH = 32
) (
    input [DATA_WIDTH-1:0] ins,
    output reg [DATA_WIDTH-1:0] imm
);

  assign opcode = ins[6:0];

  always @(*) begin
    case (opcode)
      // LUI (U-type, 20-bit immediate)
      7'b0110111: imm = {ins[31:12], 12'b0};  // imm = {upper 20 bits, 12 zeros}
      // AUIPC (U-type, 20-bit immediate)
      7'b0010111: imm = {ins[31:12], 12'b0};
      // JAL (J-type, 20-bit immediate)
      7'b1101111:
      imm = {
        ins[31], ins[19:12], ins[20], ins[30:21], 1'b0
      };  // imm[20], imm[10:1], imm[11], imm[19:12]
      // JALR (I-type, 12-bit immediate)
      7'b1100111: imm = {20'b0, ins[31:20]};  // imm[11:0]
      // Branch insuctions (BEQ, BNE, BLT, BGE, BLTU, BGEU) (B-type, 12-bit immediate)
      7'b1100011:
      imm = {
        ins[31], ins[7], ins[30:25], ins[11:8], 1'b0
      };  // imm[12], imm[10:5], imm[4:1], imm[11]
      // Load insuctions (LB, LH, LW, LBU, LHU) (I-type, 12-bit immediate)
      7'b0000011: imm = {20'b0, ins[31:20]};  // imm[11:0]
      // Store insuctions (SB, SH, SW) (S-type, 12-bit immediate)
      7'b0100011: imm = {ins[31:25], ins[11:7]};  // imm[11:5], imm[4:0]
      // ADDI, SLLI, SLTI, SLTIU, XORI, SRLI, SRAI, ORI, ANDI (I-type, 12-bit immediate)
      7'b0010011: imm = {20'b0, ins[31:20]};  // imm[11:0]
      // Default case: no immediate (or zero)
      default: imm = 32'b0;
    endcase
  end

endmodule
