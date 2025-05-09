`timescale 1ns/1ps

module MatrixMulEngine #(
    parameter MAX_M = 100,
    parameter MAX_K = 100,
    parameter MAX_N = 100,
    parameter ADDR_M_BITS = $clog2(MAX_M),
    parameter ADDR_K_BITS = $clog2(MAX_K),
    parameter ADDR_N_BITS = $clog2(MAX_N),
    parameter ADDR_A_BITS = $clog2(MAX_M * MAX_K),
    parameter ADDR_B_BITS = $clog2(MAX_K * MAX_N),
    parameter ADDR_C_BITS = $clog2(MAX_M * MAX_N),
    parameter ADDR_WIDTH = $clog2((MAX_M > MAX_K ? (MAX_M > MAX_N ? MAX_M : MAX_N) : (MAX_K > MAX_N ? MAX_K : MAX_N)))
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg done,

    input [ADDR_M_BITS:0] M_val,
    input [ADDR_K_BITS:0] K_val,
    input [ADDR_N_BITS:0] N_val,

    input  wire [31:0] matrix_A [0:MAX_M*MAX_K-1],
    input  wire [31:0] matrix_B [0:MAX_K*MAX_N-1],
    output reg  [31:0] matrix_C [0:MAX_M*MAX_N-1]
);

    reg [1:0] state;
    localparam IDLE = 2'b00,
               WAIT_DPE = 2'b01,
               STORE = 2'b10;

    integer i;
    reg [ADDR_M_BITS-1:0] row_idx;
    reg [ADDR_N_BITS-1:0] col_idx;

    reg  dpe_start;
    wire dpe_done;
    wire [31:0] dpe_result;
    wire [ADDR_WIDTH-1:0] dpe_patch_addr, dpe_filter_addr;
    wire [31:0] dpe_patch_data, dpe_filter_data;

    wire [ADDR_A_BITS-1:0] a_index = row_idx * K_val + dpe_patch_addr;
    wire [ADDR_B_BITS-1:0] b_index = dpe_filter_addr * N_val + col_idx;
    wire [ADDR_C_BITS-1:0] c_index = row_idx * N_val + col_idx;

    wire [ADDR_WIDTH-1:0] vec_len_ext = K_val;

    DotProductEngine #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dpe_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(dpe_start),
        .vec_length(vec_len_ext),
        .patch_data(dpe_patch_data),
        .filter_data(dpe_filter_data),
        .done(dpe_done),
        .result(dpe_result),
        .patch_addr(dpe_patch_addr),
        .filter_addr(dpe_filter_addr)
    );

    assign dpe_patch_data  = matrix_A[a_index];
    assign dpe_filter_data = matrix_B[b_index];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_idx <= 0;
            col_idx <= 0;
            dpe_start <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        row_idx <= 0;
                        col_idx <= 0;
                        dpe_start <= 1;
                        state <= WAIT_DPE;
                    end
                end

                WAIT_DPE: begin
                    dpe_start <= 0;
                    if (dpe_done) begin
                        state <= STORE;
                    end
                end

                STORE: begin
                    matrix_C[c_index] <= dpe_result;
                    if (col_idx < N_val - 1) begin
                        col_idx <= col_idx + 1;
                        dpe_start <= 1;
                        state <= WAIT_DPE;
                    end else if (row_idx < M_val - 1) begin
                        row_idx <= row_idx + 1;
                        col_idx <= 0;
                        dpe_start <= 1;
                        state <= WAIT_DPE;
                    end else begin
                        done <= 1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
