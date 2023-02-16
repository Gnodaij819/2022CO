`timescale 1ns / 1ps

`include "constants.v"

//////////////////////////////////////////////////////////////////////////////////////////
module mips(
    input clk,
    input reset,
    input [31:0] i_inst_rdata,
    input [31:0] m_data_rdata,
    
    output [31:0] i_inst_addr,
    output [31:0] m_data_addr,
    output [31:0] m_data_wdata,
    output [3 :0] m_data_byteen,
    output [31:0] m_inst_addr,
    output w_grf_we,
    output [4:0] w_grf_addr,
    output [31:0] w_grf_wdata,
    output [31:0] w_inst_addr
);

///////////////////////////// PC /////////////////////////////////////
    reg [31:0] PC;

    initial begin
        PC = 32'h00003000;
    end

    always @(posedge clk) begin
        if (reset) begin
            PC <= 32'h00003000;
        end
        else begin
            PC <= NPC_NPC;
        end
    end

    wire [31:0] PC_D;
    wire [31:0] PC_E;
    wire [31:0] PC_M;
    wire [31:0] PC_W;
///////////////////////////// IM /////////////////////////////////////
    wire [31:0] instr_F;
    assign instr_F = i_inst_rdata;
///////////////////////////// NPC ////////////////////////////////////
    wire [31:0] NPC_NPC;
    wire flush;
///////////////////////////// D_REG //////////////////////////////////
    wire [31:0] instr_D;
///////////////////////////// CTRL ///////////////////////////////////
    wire [5:0] op_D;
    wire [4:0] rs;
    wire [4:0] rt;
    wire [4:0] rd;
    wire [4:0] shamt_D;
    wire [5:0] funct_D;
    wire [15:0] imm16;
    wire [25:0] imm26;

    assign op_D = instr_D[31:26];
    assign rs = instr_D[25:21];
    assign rt = instr_D[20:16];
    assign rd = instr_D[15:11];
    assign shamt_D = instr_D[10:6];
    assign funct_D = instr_D[5:0];
    assign imm16 = instr_D[15:0];
    assign imm26 = instr_D[25:0];

// D_ctrl
    wire [1:0] RegDst_D;
    wire [1:0] ExtOP_D;
    wire ALUSrc_D;
    wire [3:0] ALUOP_D;
    wire isHILO;
    wire [3:0] HILOtype_D;
    wire RegWrite_D;
    wire [1:0] MemtoReg_D;
    wire [1:0] storeOP_D;
    wire [2:0] DextOP_D;
    wire [2:0] nPC_sel;
    wire [1:0] T_use_rs;
    wire [1:0] T_use_rt;

// E_ctrl
    //wire [1:0] RegDst_E;
    //wire [1:0] ExtOP_E;
    wire ALUSrc_E;
    wire [3:0] ALUOP_E;
    wire [3:0] HILOtype_E;
    wire RegWrite_E;
    wire [1:0] MemtoReg_E;
    wire [1:0] storeOP_E;
    wire [2:0] DextOP_E;
    //wire [2:0] nPC_sel_E;

// M_ctrl
    //wire [1:0] RegDst_M;
    //wire [1:0] ExtOP_M;
    //wire ALUSrc_M;
    //wire [3:0] ALUOP_M;
    wire RegWrite_M;
    wire [1:0] MemtoReg_M;
    wire [1:0] storeOP_M;
    wire [2:0] DextOP_M;
    //wire [2:0] nPC_sel_M;

// W_ctrl
    //wire [1:0] RegDst_W;
    //wire [1:0] ExtOP_W;
    //wire ALUSrc_W;
    //wire [3:0] ALUOP_W;
    wire RegWrite_W;
    wire [1:0] MemtoReg_W;
    wire [1:0] storeOP_W;
    //wire [2:0] DextOP_W;
    //wire [2:0] nPC_sel_W;

///////////////////////////// Stall //////////////////////////////////
    wire Stall_RS;
    wire Stall_RT;
    wire Stall;
///////////////////////////// MUX ////////////////////////////////////
    wire [4:0] MUX_A3_out;
    wire [31:0] MUX_ALUB_out;
    wire [31:0] MUX_GRF_WD_out;
///////////////////////////// GRF ////////////////////////////////////
    wire [31:0] GRF_RD1;
    wire [31:0] GRF_RD2;

    wire [1:0] FW_RD1_sel;
    wire [1:0] FW_RD2_sel;
    wire [31:0] FW_RD1_out;
    wire [31:0] FW_RD2_out;

    assign FW_RD1_sel = (rs == A3_E && rs != 5'd0 && T_new_E == 2'b0 && RegWrite_E == 1'b1) ? 2'd1 :
                        (rs == A3_M && rs != 5'd0 && T_new_M == 2'b0 && RegWrite_M == 1'b1) ? 2'd2 :
                        (rs == A3_W && rs != 5'd0 && T_new_W == 2'b0 && RegWrite_W == 1'b1) ? 2'd3 :
                        2'd0;

    assign FW_RD2_sel = (rt == A3_E && rt != 5'd0 && T_new_E == 2'b0 && RegWrite_E == 1'b1) ? 2'd1 :
                        (rt == A3_M && rt != 5'd0 && T_new_M == 2'b0 && RegWrite_M == 1'b1) ? 2'd2 :
                        (rt == A3_W && rt != 5'd0 && T_new_W == 2'b0 && RegWrite_W == 1'b1) ? 2'd3 :
                        2'd0;

    assign FW_RD1_out = (FW_RD1_sel == 2'd1) ? FW_E :
                        (FW_RD1_sel == 2'd2) ? FW_M :
                        (FW_RD1_sel == 2'd3) ? FW_W :
                        GRF_RD1;

    assign FW_RD2_out = (FW_RD2_sel == 2'd1) ? FW_E :
                        (FW_RD2_sel == 2'd2) ? FW_M :
                        (FW_RD2_sel == 2'd3) ? FW_W :
                        GRF_RD2;
///////////////////////////// CMP ////////////////////////////////////
    wire isSame;
///////////////////////////// EXT ////////////////////////////////////
    wire [31:0] EXT_Result_D;
///////////////////////////// E_REG //////////////////////////////////
    wire [4:0] shamt_E;
    wire [4:0] A1_E;
    wire [4:0] A2_E;
    wire [31:0] GRF_RD1_E;
    wire [31:0] GRF_RD2_E;
    wire [4:0] A3_E;
    wire [31:0] EXT_Result_E;

    wire [1:0] T_new_E;

    wire [1:0] FW_ALUA_sel;
    wire [1:0] FW_ALUB_sel;
    wire [31:0] FW_ALUA_out;
    wire [31:0] FW_ALUB_out;

    assign FW_ALUA_sel =    (A1_E == A3_M && A1_E != 5'd0 && T_new_M == 2'b0 && RegWrite_M == 1'b1) ? 2'd1 :
                            (A1_E == A3_W && A1_E != 5'd0 && T_new_W == 2'b0 && RegWrite_W == 1'b1) ? 2'd2 :
                            2'd0;

    assign FW_ALUB_sel =    (A2_E == A3_M && A2_E != 5'd0 && T_new_M == 2'b0 && RegWrite_M == 1'b1) ? 2'd1 :
                            (A2_E == A3_W && A2_E != 5'd0 && T_new_W == 2'b0 && RegWrite_W == 1'b1) ? 2'd2 :
                            2'd0;

    assign FW_ALUA_out =    (FW_ALUA_sel == 2'd1) ? FW_M :
                            (FW_ALUA_sel == 2'd2) ? FW_W :
                            GRF_RD1_E;

    assign FW_ALUB_out =    (FW_ALUB_sel == 2'd1) ? FW_M :
                            (FW_ALUB_sel == 2'd2) ? FW_W :
                            GRF_RD2_E;

    wire [31:0] FW_E;

    assign FW_E = (MemtoReg_E == `MemtoReg_PC) ? PC_E + 32'h8 : EXT_Result_E;
///////////////////////////// ALU ////////////////////////////////////
    wire [31:0] ALU_C_E;
///////////////////////////// MD /////////////////////////////////////
    wire [31:0] HILO_E;
    wire HILO_BUSY;
///////////////////////////// M_REG //////////////////////////////////
    wire [4:0] A2_M;
    wire [4:0] A3_M;
    wire [31:0] ALU_C_M;
    wire [31:0] HILO_M;
    wire [31:0] GRF_RD2_M;

    wire [1:0] T_new_M;

    wire FW_DM_WD_sel;
    wire [31:0] FW_DM_WD_out;

    assign FW_DM_WD_sel =   (A2_M == A3_W && A2_M != 5'd0 && T_new_W == 2'b0 && RegWrite_W == 1'b1) ? 1'b1 :
                            1'b0;

    assign FW_DM_WD_out =   (FW_DM_WD_sel == 1'b1) ? FW_W :
                            GRF_RD2_M;

    wire [31:0] FW_M;

    assign FW_M =   (MemtoReg_M == `MemtoReg_PC) ? PC_M + 32'h8 :
                    (MemtoReg_M == `MemtoReg_HILO) ? HILO_M :
                    ALU_C_M;
///////////////////////////// DM /////////////////////////////////////
    wire [31:0] DM_Rdata;
///////////////////////////// DEXT ///////////////////////////////////
    wire [31:0] DM_RD;
///////////////////////////// W_REG //////////////////////////////////
    wire [4:0] A3_W;
    wire [31:0] ALU_C_W;
    wire [31:0] HILO_W;
    wire [31:0] DM_RD_W;

    wire [1:0] T_new_W;

    wire [31:0] FW_W;

    assign FW_W =   (MemtoReg_W == `MemtoReg_DM) ? DM_RD_W :
                    (MemtoReg_W == `MemtoReg_PC) ? PC_W + 32'h8 :
                    (MemtoReg_W == `MemtoReg_HILO) ? HILO_W :
                    ALU_C_W;
//////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////// Fetch //////////////////////////////
    assign i_inst_addr = PC;

    npc NPC(
        .Stall(Stall),
        .HILO_BUSY(HILO_BUSY),
        .isHILO(isHILO),

        .PC(PC),
        .imm26(imm26),
        .EXT(EXT_Result_D),
        .RD1(FW_RD1_out),
        .nPC_sel(nPC_sel),
        .isSame(isSame),
        
        .NPC(NPC_NPC),
        .flush(flush)
    );

    d_reg D_REG(
        .clk(clk),
        .reset(reset),
        .Stall(Stall),
        .HILO_BUSY(HILO_BUSY),
        .isHILO(isHILO),
        .flush(flush),

        .instr_in(instr_F),
        .PC_in(PC),
        
        .instr_out(instr_D),
        .PC_out(PC_D)
    );
///////////////////////////// Decord //////////////////////////////
    ctrl CTRL(
        .op(op_D),
        .funct(funct_D),

        .RegDst(RegDst_D),
        .ExtOP(ExtOP_D),
        .ALUSrc(ALUSrc_D),
        .ALUOP(ALUOP_D),
        .isHILO(isHILO),
        .HILOtype(HILOtype_D),
        .RegWrite(RegWrite_D),
        .MemtoReg(MemtoReg_D),
        .storeOP(storeOP_D),
        .DextOP(DextOP_D),
        .nPC_sel(nPC_sel),
        .T_use_rs(T_use_rs),
        .T_use_rt(T_use_rt)
    );

    assign Stall_RS = (((T_use_rs < T_new_E) & (rs == A3_E) & RegWrite_E) | ((T_use_rs < T_new_M) & (rs == A3_M) & RegWrite_M)) & (rs != 5'd0);
    assign Stall_RT = (((T_use_rt < T_new_E) & (rt == A3_E) & RegWrite_E) | ((T_use_rt < T_new_M) & (rt == A3_M) & RegWrite_M)) & (rt != 5'd0);
    assign Stall = Stall_RS | Stall_RT;

    assign MUX_A3_out = (RegDst_D == `RegDst_rt) ?  rt :
                        (RegDst_D == `RegDst_rd) ?  rd :
                                                    5'd31;

    grf GRF(
        .clk(clk),
        .reset(reset),
        .RegWrite(RegWrite_W),
        .PC(PC_W),
        .A1(rs),
        .A2(rt),
        .A3(A3_W),
        .WD(MUX_GRF_WD_out),

        .RD1(GRF_RD1),
        .RD2(GRF_RD2)
    );

    cmp CMP(
        .GRF_RD1(FW_RD1_out),
        .GRF_RD2(FW_RD2_out),
        .nPC_sel(nPC_sel),

        .isSame(isSame)
    );

    ext EXT(
        .imm16(imm16),
        .ExtOP(ExtOP_D),

        .EXT_Result(EXT_Result_D)
    );

    e_reg E_REG(
        .clk(clk),
        .reset(reset),
        .Stall(Stall),
        .HILO_BUSY(HILO_BUSY),
        .isHILO(isHILO),

        .PC_in(PC_D),
        .op(op_D),
        .funct(funct_D),
        .shamt_in(shamt_D),

        .ALUSrc_in(ALUSrc_D),
        .ALUOP_in(ALUOP_D),
        .HILOtype_in(HILOtype_D),
        .RegWrite_in(RegWrite_D),
        .MemtoReg_in(MemtoReg_D),
        .storeOP_in(storeOP_D),
        .DextOP_in(DextOP_D),

        .A1_in(rs),
        .A2_in(rt),
        .GRF_RD1_in(FW_RD1_out),
        .GRF_RD2_in(FW_RD2_out),
        .A3_in(MUX_A3_out),
        .EXT_Result_in(EXT_Result_D),

        .PC_out(PC_E),
        .shamt_out(shamt_E),
        .T_new(T_new_E),

        .ALUSrc_out(ALUSrc_E),
        .ALUOP_out(ALUOP_E),
        .HILOtype_out(HILOtype_E),
        .RegWrite_out(RegWrite_E),
        .MemtoReg_out(MemtoReg_E),
        .storeOP_out(storeOP_E),
        .DextOP_out(DextOP_E),

        .A1_out(A1_E),
        .A2_out(A2_E),
        .GRF_RD1_out(GRF_RD1_E),
        .GRF_RD2_out(GRF_RD2_E),
        .A3_out(A3_E),
        .EXT_Result_out(EXT_Result_E)
    );
///////////////////////////// Execute //////////////////////////////
    assign MUX_ALUB_out = (ALUSrc_E == 1'b0) ? FW_ALUB_out : EXT_Result_E;

    alu ALU(
        .A(FW_ALUA_out),
        .B(MUX_ALUB_out),
        .shamt(shamt_E),
        .ALUOP(ALUOP_E),

        .C(ALU_C_E)
    );

    md MD(
        .clk(clk),
        .reset(reset),
        .HILOtype(HILOtype_E),
        .A(FW_ALUA_out),
        .B(FW_ALUB_out),

        .HILO_BUSY(HILO_BUSY),
        .HILO(HILO_E)
    );

    m_reg M_REG(
        .clk(clk),
        .reset(reset),

        .PC_in(PC_E),
        .T_new_in(T_new_E),

        .RegWrite_in(RegWrite_E),
        .MemtoReg_in(MemtoReg_E),
        .storeOP_in(storeOP_E),
        .DextOP_in(DextOP_E),

        .A2_in(A2_E),
        .A3_in(A3_E),
        .ALU_C_in(ALU_C_E),
        .HILO_in(HILO_E),
        .GRF_RD2_in(FW_ALUB_out),

        .PC_out(PC_M),
        .T_new_out(T_new_M),

        .RegWrite_out(RegWrite_M),
        .MemtoReg_out(MemtoReg_M),
        .storeOP_out(storeOP_M),
        .DextOP_out(DextOP_M),

        .A2_out(A2_M),
        .A3_out(A3_M),
        .ALU_C_out(ALU_C_M),
        .HILO_out(HILO_M),
        .GRF_RD2_out(GRF_RD2_M)
    );
///////////////////////////// Memory //////////////////////////////
    assign DM_Rdata = m_data_rdata;

    assign m_data_addr = ALU_C_M;

    assign m_data_wdata =   (storeOP_M == `store_sh) ? {2{FW_DM_WD_out[15:0]}} :
                            (storeOP_M == `store_sb) ? {4{FW_DM_WD_out[7:0]}} :
                            FW_DM_WD_out;

    assign m_data_byteen =  (storeOP_M == `store_sw) ? 4'b1111 :
                            (storeOP_M == `store_sh && ALU_C_M[1] == 1'b0) ? 4'b0011 : 
                            (storeOP_M == `store_sh && ALU_C_M[1] == 1'b1) ? 4'b1100 :
                            (storeOP_M == `store_sb && ALU_C_M[1:0] == 2'b00) ? 4'b0001 :
                            (storeOP_M == `store_sb && ALU_C_M[1:0] == 2'b01) ? 4'b0010 :
                            (storeOP_M == `store_sb && ALU_C_M[1:0] == 2'b10) ? 4'b0100 :
                            (storeOP_M == `store_sb && ALU_C_M[1:0] == 2'b11) ? 4'b1000 :
                            4'b0000;

    assign m_inst_addr = PC_M;

    dext DEXT(
        .A(ALU_C_M[1:0]),
        .D_in(DM_Rdata),
        .dextOP(DextOP_M),

        .D_out(DM_RD)
    );

    w_reg W_REG(
        .clk(clk),
        .reset(reset),

        .PC_in(PC_M),
        .T_new_in(T_new_M),

        .RegWrite_in(RegWrite_M),
        .MemtoReg_in(MemtoReg_M),

        .A3_in(A3_M),
        .ALU_C_in(ALU_C_M),
        .HILO_in(HILO_M),
        .DM_RD_in(DM_RD),

        .PC_out(PC_W),
        .T_new_out(T_new_W),

        .RegWrite_out(RegWrite_W),
        .MemtoReg_out(MemtoReg_W),

        .A3_out(A3_W),
        .ALU_C_out(ALU_C_W),
        .HILO_out(HILO_W),
        .DM_RD_out(DM_RD_W)
    );
///////////////////////////// Writeback //////////////////////////////
    assign w_grf_we = RegWrite_W;
    assign w_grf_addr = A3_W;
    assign w_grf_wdata = MUX_GRF_WD_out;
    assign w_inst_addr = PC_W;

    assign MUX_GRF_WD_out = (MemtoReg_W == `MemtoReg_ALU) ?  ALU_C_W :
                            (MemtoReg_W == `MemtoReg_DM) ?  DM_RD_W :
                            (MemtoReg_W == `MemtoReg_PC) ?  PC_W + 32'h8 :
                                                            HILO_W;
    

endmodule
