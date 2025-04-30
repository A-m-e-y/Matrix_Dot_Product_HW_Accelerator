
module FullAdder(
    input augend_i,
    input addend_i,
    input carry_i,
    output sum_o,
    output carry_o);

    assign sum_o = augend_i ^ addend_i ^ carry_i;
    assign carry_o = (augend_i & addend_i) || (addend_i & carry_i) || (carry_i & augend_i);

endmodule
