
module Rounder #(
    parameter PARM_EXP              = 8,
    parameter PARM_MANT             = 23
) (

    input [PARM_EXP + 1 : 0]Exp_i,
    input Sign_i,

    input Allzero_i,
    input Exp_mv_sign_i,

    input Sub_Sign_i,
    input [PARM_EXP - 1 : 0] A_Exp_raw_i,
    input [PARM_MANT : 0] A_Mant_i,
    input A_Sign_i,
    input B_Sign_i,
    input C_Sign_i,

    input A_DeN_i,
    input A_Inf_i,
    input B_Inf_i,
    input C_Inf_i,
    input A_Zero_i,
    input B_Zero_i,
    input C_Zero_i,
    input A_NaN_i,
    input B_NaN_i,
    input C_NaN_i,

    input Mant_sticky_sht_out_i,
    input Minus_sticky_bit_i,

    input [3*PARM_MANT + 4 : 0] Mant_norm_i,
    input [PARM_EXP + 1 : 0] Exp_norm_i,
    input [PARM_EXP + 1 : 0] Exp_norm_mone_i,
    input [PARM_EXP + 1 : 0] Exp_max_rs_i,
    input [3*PARM_MANT + 6 : 0] Rs_Mant_i,

    output reg Sign_result_o,
    output reg [PARM_EXP - 1 : 0] Exp_result_o,
    output reg [PARM_MANT - 1 : 0] Mant_result_o);

    //Sticky bit
    reg [2*PARM_MANT + 1 : 0] Mant_sticky_changed;
    always @(*) begin
        if(Exp_norm_i[PARM_EXP + 1]) 
            Mant_sticky_changed = Rs_Mant_i [2*PARM_MANT + 3 : 2];
        else if(Exp_norm_i == 0) 
            Mant_sticky_changed = Mant_norm_i[2*PARM_MANT + 2 : 1];
        else if(Mant_norm_i[3*PARM_MANT + 4]) 
            Mant_sticky_changed = Mant_norm_i[2*PARM_MANT + 1 : 0];
        else 
            Mant_sticky_changed = {Mant_norm_i[2*PARM_MANT : 0], 1'b0};
    end

    wire Sticky_one = (|Mant_sticky_changed) || Mant_sticky_sht_out_i || Minus_sticky_bit_i;

    reg Mant_sticky;
    reg [PARM_MANT : 0] Mant_result_norm; // 24 bit
    reg [PARM_EXP - 1 : 0] Exp_result_norm; // 8 bit
    reg [1 : 0] Mant_lower;

    always @(*) begin
        //assign value to avoid latches
        Mant_result_norm = 0;
        Exp_result_norm = 0;
        Mant_lower = 2'b00;
        Sign_result_o = 1'b0;
        Mant_sticky = 1'b0;

        if(A_Inf_i | B_Inf_i | C_Inf_i)begin
            // The result is Infinity     
            Exp_result_norm = 8'b1111_1111;
            if(A_Inf_i) Sign_result_o = A_Sign_i;
            else Sign_result_o = B_Sign_i ^ C_Sign_i; 

        end
        else if(B_Zero_i | C_Zero_i)begin 
            Mant_result_norm = A_Mant_i;
            Exp_result_norm = A_Exp_raw_i;
            Sign_result_o = A_Sign_i;

        end
        else if(Exp_mv_sign_i)begin
            Mant_result_norm = A_Mant_i;
            Exp_result_norm = A_Exp_raw_i;
            Sign_result_o = A_Sign_i;
            Mant_sticky = Sticky_one;
            
        end
        else if(Allzero_i)begin
            Sign_result_o = Sign_i;

        end
        else if(Exp_i[PARM_EXP + 1])begin 
            if(~Exp_max_rs_i[PARM_EXP + 1])begin
                Sign_result_o = Sign_i;
            end
            else begin 
                Mant_result_norm = {1'b0, Rs_Mant_i[3*PARM_MANT + 6 : 2*PARM_MANT + 6]};
                Mant_lower = Rs_Mant_i[2*PARM_MANT + 5 : 2*PARM_MANT + 4];
                Sign_result_o = Sign_i;
                Mant_sticky = Sticky_one;
            end

        end
        else if(Exp_norm_i[PARM_EXP - 1 : 0] == 8'b1111_1111)begin
            if(Mant_norm_i[3*PARM_MANT + 4] || (Mant_norm_i[3*PARM_MANT + 4 : 2*PARM_MANT + 4] == 0))begin 
                Sign_result_o = Sign_i;
            end
            else begin 
                Exp_result_norm = 8'b1111_1110; //254
                Sign_result_o = Sign_i;

                Mant_result_norm  = Mant_norm_i [3*PARM_MANT + 2 : 2*PARM_MANT + 3];
                Mant_lower = Mant_norm_i[2*PARM_MANT + 2 : 2*PARM_MANT + 1];
                Mant_sticky = Sticky_one;
            end

        end
        else if(Exp_norm_i[PARM_EXP])begin 
            Sign_result_o = Sign_i;
        end
        else if(Exp_norm_i == 10'd0)begin 
            Mant_result_norm = {1'b0, Mant_norm_i[3*PARM_MANT + 4 : 2*PARM_MANT + 5]};
            Mant_lower = Mant_norm_i[2*PARM_MANT + 4 : 2*PARM_MANT + 3];
            Sign_result_o = Sign_i;
            Mant_sticky = Sticky_one;
        end
        else if(Exp_norm_i == 10'd1)begin
            if(Mant_norm_i[3*PARM_MANT + 4])begin 
                Mant_result_norm = Mant_norm_i[3*PARM_MANT + 4 : 2*PARM_MANT + 4];
                Exp_result_norm = 1;
                Mant_lower = Mant_norm_i[2*PARM_MANT + 3 : 2*PARM_MANT + 2];
                Sign_result_o = Sign_i;
                Mant_sticky = Sticky_one;

            end
            else begin 
                Mant_result_norm = Mant_norm_i[3*PARM_MANT + 4: 2*PARM_MANT + 4];
                Mant_lower = Mant_norm_i[2*PARM_MANT + 3 : 2*PARM_MANT + 2];
                Sign_result_o = Sign_i;
                Mant_sticky = Sticky_one;

            end

        end
        else if(~Mant_norm_i[3*PARM_MANT + 4])begin 
            Mant_result_norm = Mant_norm_i[3*PARM_MANT + 3 : 2*PARM_MANT + 3];
            Exp_result_norm = Exp_norm_mone_i[PARM_EXP - 1 : 0];
            Mant_lower = Mant_norm_i[2*PARM_MANT + 2 : 2*PARM_MANT + 1];
            Sign_result_o = Sign_i;
            Mant_sticky = Sticky_one;
        end
        else begin 
            Mant_result_norm = Mant_norm_i[3*PARM_MANT + 4 : 2*PARM_MANT + 4];
            Exp_result_norm = Exp_norm_i[PARM_EXP - 1 : 0];
            Mant_lower = Mant_norm_i[2*PARM_MANT + 3 : 2*PARM_MANT + 2];
            Sign_result_o = Sign_i;
            Mant_sticky = Sticky_one;
        end
    end

    //Represents Guard, Round and Sticky bit
    wire GRSbits = (|Mant_lower) || Mant_sticky; 
    
    //Rounding logic for RUP mode only
    reg Mant_roundup;

    always @(*) begin
        Mant_roundup = GRSbits & (~Sign_i); // RUP logic
    end

    wire [PARM_MANT + 1 : 0] Mant_upper_rounded = Mant_result_norm + Mant_roundup;
    wire Mant_renormalize = Mant_upper_rounded[PARM_MANT + 1];

    //output logic

    always @(*) begin
        if(Mant_renormalize)
            Mant_result_o = Mant_upper_rounded[PARM_MANT : 1];
        else 
            Mant_result_o = Mant_upper_rounded[PARM_MANT - 1 : 0];
    end

    always@(*)begin
        Exp_result_o = Exp_result_norm + Mant_renormalize;
    end

endmodule
