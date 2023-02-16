`timescale 1ns / 1ps

`include "constants.v"
//////////////////////////////////////////////////////////////////////////////////
`define IM      SR[15:10]       // ��Ӧ6���ⲿ�ж��Ƿ������ж�
`define EXL     SR[1]           // �κ��쳣����ʱ��λ
`define IE      SR[0]           // ȫ���ж�ʹ��
`define BD      Cause[31]       // ��1ʱEPC��ǰһ��ָ����ת
`define IP      Cause[15:10]    // ��Ӧ6���ⲿ�ж��Ƿ���
`define ExcCode Cause[6:2]      // �쳣����
//////////////////////////////////////////////////////////////////////////////////
module CP0(
    input clk,              // ʱ���ź�
    input reset,            // ͬ����λ�ź�
    input CP0_WE,           // дʹ���ź�
    input [4:0] CP0_addr,   // �Ĵ�����ַ
    input [31:0] CP0_in,    // CP0 д������
    output [31:0] CP0_out,  // CP0 ��������
    input [31:0] VPC,       // �ܺ�PC
    input isBD,             // �Ƿ�Ϊ�ӳٲ�ָ��
    input [4:0] ExcCode_in, // ��¼�쳣����
    input [5:0] HWInt,      // �����ж��ź�
    input EXLClr,           // ������λEXL
    output [31:0] EPC_out,  // EPC��ֵ
    output [31:0] SR_out,
    output Req              // ���봦���������
    );

    reg [31:0] SR;
    reg [31:0] Cause;
    reg [31:0] EPC;

    assign SR_out = SR;

    // assign CP0_out =    (CP0_addr == 12) ? {{16{1'b0}}, `IM, {8{1'b0}}, `EXL, `IE} :
    //                     (CP0_addr == 13) ? {`BD, {15{1'b0}}, `IP, {3{1'b0}}, `ExcCode, {2{1'b0}}} :
    //                     (CP0_addr == 14) ? EPC :
    //                     32'b0;

    assign CP0_out =    (CP0_addr == 12) ? SR :
                        (CP0_addr == 13) ? Cause :
                        (CP0_addr == 14) ? EPC :
                        32'b0;

    wire Req_Int = (|(`IM & HWInt)) & `IE;
    wire Req_Exc = (ExcCode_in != `Exc_None);
    assign Req = (Req_Int | Req_Exc) & !`EXL;

    initial begin
        SR <= 32'b0;
        Cause <= 32'b0;
        EPC <= 32'b0;
    end

    assign EPC_out = (Req) ? (isBD ? VPC - 32'd4 : VPC) :
                     EPC;

    always @(posedge clk) begin
        if (reset) begin
            SR <= 32'b0;
            Cause <= 32'b0;
            EPC <= 32'b0;
        end
        else begin
            if (EXLClr) begin
                `EXL <= 1'b0;
            end
            if (Req) begin
                `EXL <= 1'b1;
                `ExcCode <= (Req_Int == 1'b1) ? `Exc_Int : ExcCode_in;
                `BD = isBD;
                EPC <= EPC_out;
            end else if (CP0_WE) begin
                //$display("!%h: $%d <= %h", VPC, CP0_addr, CP0_in);
                if (CP0_addr == 12) begin
                    SR <= CP0_in;
                end
                else if (CP0_addr == 13) begin
                    Cause <= CP0_in;
                end
                else if (CP0_addr == 14) begin
                    EPC <= CP0_in;
                end
            end
            `IP <= HWInt;
        end
    end


endmodule
