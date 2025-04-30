
module ZeroDetector_Base #(
    parameter XLEN = 8
) (
    input [XLEN - 1: 0] base_data_i,
    output zero_o );

    assign zero_o = (base_data_i == 0);
    
endmodule
