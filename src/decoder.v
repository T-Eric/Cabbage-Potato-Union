// Decoder
// Connect: Ins-Fetch, 
// Function: Decode the ins from IC, then Issue. Careless about branching.
`include "head.v"
`ifndef DEC_V
`define DEC_V

module decoder (
    input clk,
    input rst,
    input en,

    // from ins_fetch: original instruction
    input if_en_i,
    input if_ic_i,  // 0 I 1 C
    input [`DAT_W-1:0] if_ins_i,
    input [`DAT_W-1:0] if_pc_i,
    input if_pbr_i,  // predicted branch or not

    // to RF, go fetch data for rob
    output rf_en_o,
    output rf_ic_o,
    output [1:0] rf_tp_o,
    output [`OP_W-1:0] rf_op_o,
    output [`REG_BIT-1:0] rf_rd_o,
    output [`REG_BIT-1:0] rf_rs1_o,
    output [`REG_BIT-1:0] rf_rs2_o,
    output [`DAT_W-1:0] rf_imm_o,
    output [`DAT_W-1:0] rf_pc_o,

    // to ROB, launch new item
    output rob_en_o,
    output rob_ic_o,
    output [`OP_W-1:0] rob_op_o,
    output [1:0] rob_tp_o,
    output [`REG_BIT-1:0] rob_rd_o,
    output [`DAT_W-1:0] rob_pc_o,
    output rob_pbr_o  // predicted branch or not
);

  reg [`DAT_W-1:0] ins;
  reg [`OP_W-1:0] op;  // 都按仓库排列顺序确定
  reg [1:0] tp;  // 0 branch 1 store 2 load 3 alu-operations
  reg [`DAT_W-1:0] imm;
  reg [`REG_BIT-1:0] rd, rs1, rs2;
  reg pbr;  // 由于jalr这种煞笔存在，需要特别安排

  assign rf_op_o   = op;
  assign rf_ic_o   = if_ic_i;
  assign rf_tp_o   = tp;
  assign rf_rd_o   = rd;
  assign rf_rs1_o  = rs1;
  assign rf_rs2_o  = rs2;
  assign rf_imm_o  = imm;
  assign rf_pc_o   = if_pc_i;

  assign rob_ic_o  = if_ic_i;
  assign rob_op_o  = op;
  assign rob_tp_o  = tp;
  assign rob_rd_o  = rd;
  assign rob_pc_o  = if_pc_i;
  assign rob_pbr_o = pbr;

  assign rf_en_o   = if_en_i;
  assign rob_en_o  = if_en_i;

  // RV32I assets
  wire [6:0] iopcode;
  wire [2:0] ifunct3;
  wire [6:0] ifunct7;

  assign iopcode = ins[6:0];
  assign ifunct3 = ins[14:12];
  assign ifunct7 = ins[31:25];

  // RV32C assets
  wire [1:0] copcode;
  wire [2:0] cfunct3;
  wire [`REG_BIT-1:0] crd, crs1, crs2;
  wire [`REG_BIT-1:0] crda, crs1a, crs2a;
  wire [1:0] c01oph, c01opl;

  assign copcode = ins[1:0];
  assign cfunct3 = ins[15:13];
  assign crd = ins[11:7];
  assign crs1 = ins[11:7];
  assign crs2 = ins[6:2];
  assign crda = {2'b00, ins[9:7]} + 8;
  assign crs1a = {2'b00, ins[9:7]} + 8;
  assign crs2a = {2'b00, ins[4:2]} + 8;
  assign c01oph = ins[11:10];
  assign c01opl = ins[6:5];

  // TODO 先写成组合逻辑试一试，改起来不费力
  always @(*) begin
    if (clk || rst || en) begin
    end

    ins = if_ins_i;
    op  = 0;
    tp  = 0;
    imm = 0;
    rd  = 0;
    rs1 = 0;
    rs2 = 0;
    pbr = if_pbr_i;

    if (if_ic_i) begin
      // RV32C instructions
      // 为每一条的rd,rs1,rs2,imm,op赋值，否则可能出问题
      tp = 2'b11;
      case (copcode)
        2'b01: begin
          case (cfunct3)
            3'b000: begin  // c.addi
              rd  = crd;
              rs1 = crs1;
              rs2 = 0;
              imm = {{27{ins[12]}}, ins[6:2]};
              op  = `ADDI;
            end
            3'b001: begin  // c.jal
              rd  = 1;
              rs1 = 0;
              rs2 = 0;
              imm = 0;  // need pc
              op  = `JAL;
            end
            3'b010: begin  // c.li
              rd  = crd;
              rs1 = 0;
              rs2 = 0;
              imm = {{27{ins[12]}}, ins[6:2]};
              op  = `ADDI;
            end
            3'b011: begin
              if (crd == 2) begin  // c.addi16sp
                rd  = crd;
                rs1 = crs1;
                rs2 = 0;
                imm = {{23{ins[12]}}, ins[4:3], ins[5], ins[2], ins[6], 4'b0};
                op  = `ADDI;
              end else begin  // c.lui
                rd  = crd;
                rs1 = 0;
                rs2 = 0;
                imm = {{15{ins[12]}}, ins[6:2], 12'b0};
                op  = `LUI;
              end
            end
            3'b100: begin
              case (c01oph)
                2'b00, 2'b01: begin  // c.srli, c,srai, no sext
                  rd  = crda;
                  rs1 = crs1a;
                  rs2 = 0;
                  imm = {26'b0, ins[12], ins[6:2]};
                  op  = c01oph ? `SRAI : `SRLI;
                end
                2'b10: begin  // c.andi
                  rd  = crda;
                  rs1 = crs1a;
                  rs2 = 0;
                  imm = {{27{ins[12]}}, ins[6:2]};
                  op  = `ANDI;
                end
                2'b11: begin
                  rd  = crda;
                  rs1 = crs1a;
                  rs2 = crs2a;
                  imm = 0;
                  case (c01opl)
                    2'b00: op = `SUB;  // c.sub
                    2'b01: op = `XOR;  // c.xor 
                    2'b10: op = `OR;  //  c.or
                    2'b11: op = `AND;  // c.and
                  endcase
                end
              endcase
            end
            3'b101: begin  // c.j
              rd  = 0;
              rs1 = 0;
              rs2 = 0;
              imm = 0;  // pc has been revised
              op  = `JAL;
            end
            3'b110, 3'b111: begin  // c.beqz, c.bnez
              tp  = 2'b00;
              rd  = 0;
              rs1 = crs1a;
              rs2 = 0;
              imm = {{24{ins[12]}}, ins[6:5], ins[2], ins[11:10], ins[4:3], 1'b0};
              op  = (cfunct3 == 3'b110) ? `BEQ : `BNE;
            end
            default: ;
          endcase
        end
        2'b00: begin
          case (cfunct3)
            3'b000: begin  // c.addi4spn
              rd  = crs2a;
              rs1 = 2;
              rs2 = 0;
              imm = {22'b0, ins[10:7], ins[12:11], ins[5], ins[6], 2'b0};
              op  = `ADDI;
            end
            3'b010: begin  // c.lw
              tp  = 2'b10;
              rd  = crs2a;
              rs1 = crs1a;
              rs2 = 0;
              imm = {25'b0, ins[5], ins[12:10], ins[6], 2'b0};
              op  = `LW;
            end
            3'b110: begin  // c.sw
              tp  = 2'b01;
              rd  = 0;
              rs1 = crs1a;
              rs2 = crs2a;
              imm = {25'b0, ins[5], ins[12:10], ins[6], 2'b0};
              op  = `SW;
            end
            default: ;
          endcase
        end
        2'b10: begin
          case (cfunct3)
            3'b000: begin  // c.slli
              rd  = crd;
              rs1 = crs1;
              rs2 = 0;
              imm = {26'b0, ins[12], ins[6:2]};
              op  = `SLLI;
            end
            3'b100: begin
              if (!ins[12]) begin
                if (crs2 == 0) begin  // c.jr
                  tp  = 2'b00;
                  rd  = 0;
                  rs1 = crs1;
                  rs2 = 0;
                  imm = 0;
                  op  = `JALR;
                  pbr = 0;
                end else begin  // c.mv
                  rd  = crd;
                  rs1 = 0;
                  rs2 = crs2;
                  imm = 0;
                  op  = `ADD;
                end
              end else begin
                if (crs2 == 0) begin  // c.jalr
                  tp  = 2'b00;
                  rd  = 1;
                  rs1 = crs1;
                  rs2 = 0;
                  imm = 0;
                  op  = `JALR;
                  pbr = 0;
                end else begin  // c.add
                  rd  = crd;
                  rs1 = crs1;
                  rs2 = crs2;
                  imm = 0;
                  op  = `ADD;
                end
              end
            end
            3'b010: begin  // c.lwsp
              tp  = 2'b10;
              rd  = crd;
              rs1 = 2;
              rs2 = 0;
              imm = {24'b0, ins[3:2], ins[12], ins[6:4], 2'b0};
              op  = `LW;
            end
            3'b110: begin  // c.swsp
              tp  = 2'b01;
              rd  = 0;
              rs1 = 2;
              rs2 = crs2;
              imm = {24'b0, ins[8:7], ins[12:9], 2'b0};
              op  = `SW;
            end
          endcase
        end
      endcase

    end else begin
      // RV32I instructions
      rd  = ins[11:7];
      rs1 = ins[19:15];
      rs2 = ins[24:20];

      case (iopcode)
        7'b1100111, 7'b0000011, 7'b0010011: begin  // I
          imm = {{20{ins[31]}}, ins[31:20]};
          rs2 = 0;
        end
        7'b0100011: begin  // S
          imm = {{20{ins[31]}}, ins[31:25], ins[11:7]};
          rd  = 0;
        end
        7'b1100011: begin  // B
          imm = {{19{ins[31]}}, ins[31], ins[7], ins[30:25], ins[11:8], 1'b0};
          rd  = 0;
        end
        7'b0110111, 7'b0010111: begin  // U:LUI,AUIPC
          imm = {ins[31:12], 12'b0};
          rs1 = 0;
          rs2 = 0;
        end
        7'b1101111: begin  // J:JAL
          imm = {{12{ins[31]}}, ins[19:12], ins[20], ins[30:21], 1'b0};
          rs1 = 0;
          rs2 = 0;
        end
        default: ;  // R
      endcase

      tp = 2'b11;
      case (iopcode)
        7'b0110111: op = `LUI;  // LUI
        7'b0010111: op = `AUIPC;  // AUIPC
        7'b1101111: op = `JAL;  // JAL, not branch
        7'b1100111: begin  // JALR, branch
          tp  = 0;
          op  = `JALR;
          pbr = 0;
        end
        7'b1100011: begin
          tp = 0;
          case (ifunct3)
            3'b000:  op = `BEQ;  // BEQ
            3'b001:  op = `BNE;  // BNE
            3'b100:  op = `BLT;  // BLT
            3'b101:  op = `BGE;  // BGE
            3'b110:  op = `BLTU;  // BLTU
            3'b111:  op = `BGEU;  // BGEU
            default: op = 6'b000000;
          endcase
        end
        7'b0000011: begin
          tp = 2'b10;
          case (ifunct3)
            3'b000:  op = `LB;  // LB
            3'b001:  op = `LH;  // LH
            3'b010:  op = `LW;  // LW
            3'b100:  op = `LBU;  // LBU
            3'b101:  op = `LHU;  // LHU
            default: op = 6'b000000;
          endcase
        end
        7'b0100011: begin
          tp = 2'b01;
          case (ifunct3)
            3'b000:  op = `SB;  // SB
            3'b001:  op = `SH;  // SH
            3'b010:  op = `SW;  // SW
            default: op = 6'b000000;
          endcase
        end
        7'b0010011: begin
          case (ifunct3)
            3'b000: op = `ADDI;  // ADDI
            3'b001: op = `SLLI;  // SLLI
            3'b010: op = `SLTI;  // SLTI
            3'b011: op = `SLTIU;  // SLTIU
            3'b100: op = `XORI;  // XORI
            3'b101: op = ifunct7 ? `SRAI : `SRLI;  // SRAI or SRLI
            3'b110: op = `ORI;  // ORI
            3'b111: op = `ANDI;  // ANDI
          endcase
        end
        7'b0110011: begin
          case (ifunct3)
            3'b000: op = ifunct7 ? `SUB : `ADD;  // ADD or SUB
            3'b001: op = `SLL;  // SLL
            3'b010: op = `SLT;  // SLT
            3'b011: op = `SLTU;  // SLTU
            3'b100: op = `XOR;  // XOR
            3'b101: op = ifunct7 ? `SRA : `SRL;  // SRA or SRL
            3'b110: op = `OR;  // OR
            3'b111: op = `AND;  // AND
          endcase
        end
        default: op = 6'b000000;
      endcase
    end
  end


endmodule

`endif
