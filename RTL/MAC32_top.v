module MAC32_top #(
    parameter PARM_XLEN     = 32,
    parameter PARM_EXP      = 8,
    parameter PARM_MANT     = 23,
    parameter PARM_BIAS     = 127
) (
    input clk,
    input rst_n,
    input [PARM_XLEN - 1 : 0] A_i,
    input [PARM_XLEN - 1 : 0] B_i,
    input [PARM_XLEN - 1 : 0] C_i,
    
    output reg [PARM_XLEN - 1 : 0] Result // result = A + (B * C)
    );

    parameter PARM_LEADONE_WIDTH = 7;
    parameter PARM_EXP_ONE      = 8'h01; 

    // Detect leading bits for special case handling
    wire A_Leadingbit = | A_i[PARM_XLEN - 2 : PARM_MANT]; 
    wire B_Leadingbit = | B_i[PARM_XLEN - 2 : PARM_MANT];
    wire C_Leadingbit = | C_i[PARM_XLEN - 2 : PARM_MANT];

    // Outputs of the SpecialCaseDetector module
    wire A_Inf, B_Inf, C_Inf;
    wire A_Zero, B_Zero, C_Zero;
    wire A_NaN, B_NaN, C_NaN;
    wire A_DeN, B_DeN, C_DeN;

    wire [PARM_XLEN - 1 : 0] Result_o;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            Result <= 0;
        end else begin
            Result <= Result_o;
        end
    end
    // assign Result = Result_o;

    SpecialCaseDetector #(
        .PARM_XLEN(PARM_XLEN),
        .PARM_EXP(PARM_EXP),
        .PARM_MANT(PARM_MANT)
    ) SpecialCaseDetector (
        .A_i(A_i),
        .B_i(B_i),
        .C_i(C_i),
        .A_Leadingbit_i(A_Leadingbit),
        .B_Leadingbit_i(B_Leadingbit),
        .C_Leadingbit_i(C_Leadingbit),
        
        .A_Inf_o(A_Inf),
        .B_Inf_o(B_Inf),
        .C_Inf_o(C_Inf),
        .A_Zero_o(A_Zero),
        .B_Zero_o(B_Zero),
        .C_Zero_o(C_Zero),
        .A_NaN_o(A_NaN),
        .B_NaN_o(B_NaN),
        .C_NaN_o(C_NaN),
        .A_DeN_o(A_DeN),
        .B_DeN_o(B_DeN),
        .C_DeN_o(C_DeN)
    );

    // Extract sign bits
    wire A_Sign = A_i[PARM_XLEN - 1];
    wire B_Sign = B_i[PARM_XLEN - 1];
    wire C_Sign = C_i[PARM_XLEN - 1];
    wire Sub_Sign = A_Sign ^ B_Sign ^ C_Sign; // Compute the sign of the result

    // Handle denormalized numbers for exponent extraction
    wire [PARM_EXP - 1: 0] A_Exp = A_DeN ? PARM_EXP_ONE : A_i[PARM_XLEN - 2 : PARM_MANT];
    wire [PARM_EXP - 1: 0] B_Exp = B_DeN ? PARM_EXP_ONE : B_i[PARM_XLEN - 2 : PARM_MANT];
    wire [PARM_EXP - 1: 0] C_Exp = C_DeN ? PARM_EXP_ONE : C_i[PARM_XLEN - 2 : PARM_MANT];

    // Add leading bit for mantissa
    wire [PARM_MANT : 0] A_Mant = {A_Leadingbit, A_i[PARM_MANT - 1 : 0]};
    wire [PARM_MANT : 0] B_Mant = {B_Leadingbit, B_i[PARM_MANT - 1 : 0]};
    wire [PARM_MANT : 0] C_Mant = {C_Leadingbit, C_i[PARM_MANT - 1 : 0]};

    wire [2*PARM_MANT + 2 : 0] booth_PP [12 - 1: 0];
    wire [2*PARM_MANT + 1 : 0] booth_PP_13;

    R4Booth #(
        .PARM_MANT(PARM_MANT)
    ) R4Booth (
        .MantA_i(B_Mant),
        .MantB_i(C_Mant),
        
        .pp_00_o(booth_PP[ 0]),
        .pp_01_o(booth_PP[ 1]),
        .pp_02_o(booth_PP[ 2]),
        .pp_03_o(booth_PP[ 3]),
        .pp_04_o(booth_PP[ 4]),
        .pp_05_o(booth_PP[ 5]),
        .pp_06_o(booth_PP[ 6]),
        .pp_07_o(booth_PP[ 7]),
        .pp_08_o(booth_PP[ 8]),
        .pp_09_o(booth_PP[ 9]),
        .pp_10_o(booth_PP[10]),
        .pp_11_o(booth_PP[11]),
        .pp_12_o(booth_PP_13)
    );

    wire [2*PARM_MANT + 2 : 0] Wallace_sum;
    wire [2*PARM_MANT + 2 : 0] Wallace_carry;
    wire Wallace_suppression_sign_extension;

    WallaceTree #(
        .PARM_MANT(PARM_MANT)
    ) WallaceTree (
        .pp_00_i(booth_PP[ 0]),
        .pp_01_i(booth_PP[ 1]),
        .pp_02_i(booth_PP[ 2]),
        .pp_03_i(booth_PP[ 3]),
        .pp_04_i(booth_PP[ 4]),
        .pp_05_i(booth_PP[ 5]),
        .pp_06_i(booth_PP[ 6]),
        .pp_07_i(booth_PP[ 7]),
        .pp_08_i(booth_PP[ 8]),
        .pp_09_i(booth_PP[ 9]),
        .pp_10_i(booth_PP[10]),
        .pp_11_i(booth_PP[11]),
        .pp_12_i(booth_PP_13),
        
        .wallace_sum_o(Wallace_sum),
        .wallace_carry_o(Wallace_carry),
        .suppression_sign_extension_o(Wallace_suppression_sign_extension)
    );

    wire Sign_aligned;
    wire Exp_mv_sign;
    wire Mv_halt;

    // Compute exponent movement
    wire [PARM_EXP + 1 : 0] Exp_mv = 27 - A_Exp + B_Exp + C_Exp - PARM_BIAS; 
    wire [PARM_EXP + 1 : 0] Exp_mv_neg = -27 + A_Exp - B_Exp - C_Exp + PARM_BIAS;

    // Determine if exponent movement is negative
    assign Exp_mv_sign = Exp_mv[PARM_EXP + 1];

    // Halt movement if exponent is too large or A is zero
    assign Mv_halt = ((~Exp_mv_sign) & (Exp_mv[PARM_EXP : 0] > 73)) || A_Zero; 

    wire SignFlip_ADD_PRN;

    wire [3*PARM_MANT + 5 : 0] A_Mant_aligned;
    wire [PARM_MANT + 3 : 0] A_Mant_aligned_high = A_Mant_aligned[3*PARM_MANT + 5 : 2*PARM_MANT + 2];
    wire [2*PARM_MANT + 1 : 0] A_Mant_aligned_low = A_Mant_aligned[2*PARM_MANT + 1 : 0];

    wire signed [PARM_EXP + 1 : 0] Exp_aligned;
    wire Mant_sticky_sht_out;

    PreNormalizer #(
        .PARM_EXP(PARM_EXP),
        .PARM_MANT(PARM_MANT),
        .PARM_BIAS(PARM_BIAS)
    ) PreNormalizer (
        .A_sign_i(A_Sign),
        .B_sign_i(B_Sign),
        .C_sign_i(C_Sign),
        .Sub_Sign_i(Sub_Sign),
        .A_Exp_i(A_Exp),
        .B_Exp_i(B_Exp),
        .C_Exp_i(C_Exp),
        .A_Mant_i(A_Mant),
        .Sign_flip_i(SignFlip_ADD_PRN), 
        .Mv_halt_i(Mv_halt),
        .Exp_mv_i(Exp_mv),
        .Exp_mv_sign_i(Exp_mv_sign),

        .A_Mant_aligned_o(A_Mant_aligned),
        .Exp_aligned_o(Exp_aligned),
        .Sign_aligned_o(Sign_aligned),
        .Mant_sticky_sht_out_o(Mant_sticky_sht_out)
    );

    wire [2*PARM_MANT + 2 : 0] Wallace_sum_adjusted;
    wire [2*PARM_MANT + 2 : 0] Wallace_carry_adjusted;

    // Adjust Wallace tree outputs based on exponent movement
    assign Wallace_sum_adjusted = (Exp_mv_sign) ? 0 : Wallace_sum;
    assign Wallace_carry_adjusted = (Exp_mv_sign) ? 0 : Wallace_carry;

    wire [2*PARM_MANT + 1 : 0] CSA_sum;
    wire [2*PARM_MANT + 1 : 0] CSA_carry;

    Compressor32 #(
        .XLEN(2*PARM_MANT + 2)
    ) CarrySaveAdder (
        .A_i(A_Mant_aligned_low),
        .B_i(Wallace_sum_adjusted[2*PARM_MANT + 1 : 0]),
        .C_i({Wallace_carry_adjusted[2*PARM_MANT : 0], 1'b0}),

        .Sum_o(CSA_sum),
        .Carry_o(CSA_carry)
    );

    reg [73 : 0] PosSum;
    wire Minus_sticky_bit;

    wire Adder_sign;

    // Compute post-correction carry
    wire wallace_msb_G = Wallace_sum_adjusted[2*PARM_MANT + 2] & Wallace_carry_adjusted[2*PARM_MANT + 1];
    wire adder_Correlated_sign = Wallace_suppression_sign_extension | Wallace_carry_adjusted[2*PARM_MANT + 2] | wallace_msb_G;
    wire Carry_postcor = (~Exp_mv_sign) & ((~adder_Correlated_sign) ^ CSA_carry[2*PARM_MANT + 1]);

    wire [2*PARM_MANT + 1 : 0] low_sum;
    wire low_carry;
    wire [2*PARM_MANT + 1 : 0] low_sum_inv;
    wire low_carry_inv;

    EACAdder #(
        .PARM_MANT(PARM_MANT)
    ) EACAdder (
        .CSA_sum_i(CSA_sum),
        .CSA_carry_i(CSA_carry),
        .Carry_postcor_i(Carry_postcor),
        .Sub_Sign_i(Sub_Sign),
        .A_Zero_i(A_Zero),

        .low_sum_o(low_sum),
        .low_carry_o(low_carry),
        .low_sum_inv_o(low_sum_inv),
        .low_carry_inv_o(low_carry_inv)
    );

    wire [PARM_MANT + 3 : 0] high_sum;
    wire [PARM_MANT + 3 : 0] high_sum_inv;

    MSBIncrementer #(
        .PARM_MANT(PARM_MANT)
    ) MSBIncrementer (
        .low_carry_i(low_carry),
        .low_carry_inv_i(low_carry_inv),
        .A_Mant_aligned_high_i(A_Mant_aligned_high), 

        .high_sum_o(high_sum),
        .high_sum_inv_o(high_sum_inv)
    );

    wire bc_not_strange = ~(B_Inf | C_Inf | B_Zero | C_Zero | B_NaN | C_NaN);
    wire [3*PARM_MANT + 4 : 0] sub_minus = {{A_Mant_aligned_high[PARM_MANT+2 : 0], 1'b0} - bc_not_strange, 47'd0};

    assign SignFlip_ADD_PRN = high_sum[PARM_MANT + 3];
    assign Adder_sign = Exp_mv_sign ? Sign_aligned : (SignFlip_ADD_PRN ^ Sign_aligned);

    // Compute the final sum based on conditions
    always @(*) begin
        if (Mv_halt)
            PosSum = {{26'd0}, low_sum}; // Halt movement, use low sum
        else if (Exp_mv_sign)
            PosSum = Sub_Sign ? sub_minus : {A_Mant_aligned_high[PARM_MANT+2 : 0], 48'd0}; // Negative movement
        else if (SignFlip_ADD_PRN)
            PosSum = {high_sum_inv[PARM_MANT + 2 : 0], low_sum_inv}; // Sign flip
        else
            PosSum = {high_sum[PARM_MANT + 2 : 0], low_sum}; // Normal case
    end

    // Compute sticky bit for negative movement
    assign Minus_sticky_bit = Exp_mv_sign && (bc_not_strange);

    wire [PARM_LEADONE_WIDTH - 1 : 0] shift_num;
    wire allzero;

    LeadingOneDetector_Top #(
        .X_LEN(74)
    ) LeadingOneDetector (
        .data_i(PosSum),

        .shift_num_o(shift_num),
        .allzero_o(allzero)
    );

    wire [3*PARM_MANT + 4 : 0] Mant_norm;
    wire [PARM_EXP + 1 : 0] Exp_norm;
    wire [PARM_EXP + 1 : 0] Exp_norm_mone;
    wire [PARM_EXP + 1 : 0] Exp_max_rs;
    wire [3*PARM_MANT + 6 : 0] Rs_Mant;

    Normalizer #(
        .PARM_EXP(PARM_EXP),
        .PARM_MANT(PARM_MANT),
        .PARM_LEADONE_WIDTH(PARM_LEADONE_WIDTH)
    ) Normalizer (
        .Mant_i(PosSum),
        .Exp_i(Exp_aligned),
        .Shift_num_i(shift_num),
        .Exp_mv_sign_i(Exp_mv_sign),

        .Mant_norm_o(Mant_norm),
        .Exp_norm_o(Exp_norm),
        .Exp_norm_mone_o(Exp_norm_mone),
        .Exp_max_rs_o(Exp_max_rs),
        .Rs_Mant_o(Rs_Mant)
    );

    wire Sign_result;
    wire [PARM_EXP - 1 : 0] Exp_result;
    wire [PARM_MANT - 1 : 0] Mant_result;

    // Combine final result
    assign Result_o = {Sign_result, Exp_result, Mant_result};

    Rounder #(
        .PARM_EXP(PARM_EXP),          
        .PARM_MANT(PARM_MANT)
    ) Rounder (
        .Exp_i(Exp_aligned),
        .Sign_i(Adder_sign),
        .Allzero_i(allzero),
        .Exp_mv_sign_i(Exp_mv_sign),
        .Sub_Sign_i(Sub_Sign),
        .A_Exp_raw_i(A_i[PARM_XLEN - 2 : PARM_MANT]),
        .A_Mant_i(A_Mant),
        .A_Sign_i(A_Sign),
        .B_Sign_i(B_Sign),
        .C_Sign_i(C_Sign),
        .A_DeN_i(A_DeN),
        .A_Inf_i(A_Inf),
        .B_Inf_i(B_Inf),
        .C_Inf_i(C_Inf),
        .A_Zero_i(A_Zero),
        .B_Zero_i(B_Zero),
        .C_Zero_i(C_Zero),
        .A_NaN_i(A_NaN),
        .B_NaN_i(B_NaN),
        .C_NaN_i(C_NaN),
        .Mant_sticky_sht_out_i(Mant_sticky_sht_out),
        .Minus_sticky_bit_i(Minus_sticky_bit),
        .Mant_norm_i(Mant_norm),
        .Exp_norm_i(Exp_norm),
        .Exp_norm_mone_i(Exp_norm_mone),
        .Exp_max_rs_i(Exp_max_rs),
        .Rs_Mant_i(Rs_Mant),

        .Sign_result_o(Sign_result),
        .Exp_result_o(Exp_result),
        .Mant_result_o(Mant_result)
    );

endmodule

