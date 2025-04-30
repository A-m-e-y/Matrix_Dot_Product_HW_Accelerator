
module ZeroDetector_Group #(
    parameter XLEN = 2
) (
    input [XLEN - 1 : 0] group_data_i,
    output group_zero_o );

    assign group_zero_o = &group_data_i;
    
endmodule