
module EACAdder #(
    parameter PARM_MANT = 23
) (
    input [2*PARM_MANT + 1 : 0] CSA_sum_i,
    input [2*PARM_MANT + 1 : 0] CSA_carry_i,
    input Carry_postcor_i,
    input Sub_Sign_i,
    input A_Zero_i,    

    output [2*PARM_MANT + 1 : 0] low_sum_o,
    output low_carry_o,
    output [2*PARM_MANT + 1 : 0] low_sum_inv_o,
    output low_carry_inv_o);

    wire end_round_carry = Sub_Sign_i & (~A_Zero_i);
    assign {low_carry_o, low_sum_o} =  CSA_sum_i + {Carry_postcor_i, CSA_carry_i[2*PARM_MANT : 0], end_round_carry};
    assign {low_carry_inv_o, low_sum_inv_o} = 2'b10 + {1'b1, ~CSA_sum_i} + {~Carry_postcor_i, ~CSA_carry_i[2*PARM_MANT : 0], ~end_round_carry};

endmodule
