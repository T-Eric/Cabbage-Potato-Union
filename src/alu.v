// Arithmetic, maybe many(as Execution Unit)
`include "src/head.v"
`ifndef ALU_V
`define ALU_V

module arith_logic_unit (
    input clk,
    input rst,
    input en,

    // from rs: calc
    input rs_en_i,
    input [`OP_W-1:0] rs_op_i,
    input rs_ic_i,
    input [`ROB_BIT-1:0] rs_qd_i,
    input [`DAT_W-1:0] rs_vs_i,
    input [`DAT_W-1:0] rs_vt_i,
    input [`DAT_W-1:0] rs_imm_i,
    input [`RAM_ADR_W-1:0] rs_pc_i,

    // to cdb: the result and the q
    output reg cdb_en_o,
    output [`ROB_BIT-1:0] cdb_q_o,
    output [`DAT_W-1:0] cdb_v_o,
    output cdb_cbr_o,  // calculated branch or not
    output [`RAM_ADR_W-1:0] cdb_cbt_o  // calced branch-to
);
  // cdb outputs 
  reg [`ROB_BIT-1:0] q;
  reg [`DAT_W-1:0] v;
  reg cbr;
  reg [`DAT_W-1:0] cbt;
  assign cdb_q_o   = q;
  assign cdb_v_o   = v;
  assign cdb_cbr_o = cbr;
  assign cdb_cbt_o = cbt[`RAM_ADR_W-1:0];

  wire [`DAT_W-1:0] pc, vs, vt, imm;
  wire [`OP_W-1:0] op;
  wire ic;
  assign pc  = {15'b0, rs_pc_i};  //32-17
  assign vs  = rs_vs_i;
  assign vt  = rs_vt_i;
  assign imm = rs_imm_i;
  assign op  = rs_op_i;
  assign ic  = rs_ic_i;

  always @(posedge clk) begin
    if (rst) begin
      cdb_en_o <= 0;
      q <= 0;
      v <= 0;
      cbr <= 0;
      cbt <= 0;
    end else if (en) begin
      cdb_en_o <= 0;
      q <= 0;
      v <= 0;
      cbr <= 0;
      cbt <= 0;

      if (rs_en_i) begin
        cdb_en_o <= 1;
        q <= rs_qd_i;
        cbr <= 0;

        // calculation
        case (op)
          `LUI:    v <= imm;
          `AUIPC:  v <= pc + imm;
          `JAL:    v <= ic ? pc + 2 : pc + 4;  // 存进寄存器的
          `JALR: begin
            v   <= ic ? pc + 2 : pc + 4;
            cbr <= 1;
            cbt <= (vs + imm) & (~1);
          end
          `BEQ: begin
            cbr <= vs == vt;
            cbt <= vs == vt ? pc + imm : ic ? pc + 2 : pc + 4;
          end
          `BNE: begin
            cbr <= vs != vt;
            cbt <= vs != vt ? pc + imm : ic ? pc + 2 : pc + 4;
          end
          `BLT: begin
            cbr <= $signed(vs) < $signed(vt);
            cbt <= $signed(vs) < $signed(vt) ? pc + imm : ic ? pc + 2 : pc + 4;
          end
          `BGE: begin
            cbr <= $signed(vs) >= $signed(vt);
            cbt <= $signed(vs) >= $signed(vt) ? pc + imm : ic ? pc + 2 : pc + 4;
          end
          `BLTU: begin
            cbr <= vs < vt;
            cbt <= vs < vt ? pc + imm : ic ? pc + 2 : pc + 4;
          end
          `BGEU: begin
            cbr <= vs >= vt;
            cbt <= vs >= vt ? pc + imm : ic ? pc + 2 : pc + 4;
          end
          `ADDI:   v <= vs + imm;
          `SLLI:   v <= vs << imm;
          `SLTI:   v <= ($signed(vs) < $signed(imm)) ? 1 : 0;
          `SLTIU:  v <= vs < imm ? 1 : 0;
          `XORI:   v <= vs ^ imm;
          `SRLI:   v <= vs >> imm[5:0];
          `SRAI:   v <= vs >>> imm[5:0];  // signed rightmove
          `ORI:    v <= vs | imm;
          `ANDI:   v <= vs & imm;
          `ADD:    v <= vs + vt;
          `SUB:    v <= vs - vt;
          `SLL:    v <= vs << vt[5:0];
          `SLT:    v <= $signed(vs) < $signed(vt) ? 1 : 0;
          `SLTU:   v <= vs < vt ? 1 : 0;
          `XOR:    v <= vs ^ vt;
          `SRL:    v <= vs >> vt;
          `SRA:    v <= vs >>> vt;  // signed right move
          `OR:     v <= vs | vt;
          `AND:    v <= vs & vt;
          default: ;
        endcase
      end
    end
  end

endmodule

`endif
