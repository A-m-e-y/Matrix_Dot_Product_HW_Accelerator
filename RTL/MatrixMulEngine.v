`timescale 1ns/1ps

module MatrixMulEngine #(
    parameter MAX_M = 10,
    parameter MAX_K = 10,
    parameter MAX_N = 10
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg done,

    input [7:0] M_val,
    input [7:0] K_val,
    input [7:0] N_val,

    input  wire [31:0] matrix_A [0:MAX_M*MAX_K-1],
    input  wire [31:0] matrix_B [0:MAX_K*MAX_N-1],
    output reg  [31:0] matrix_C [0:MAX_M*MAX_N-1]
);

    reg [1:0] state;
    localparam IDLE = 2'b00,
               LOAD_ROW = 2'b01,
               WAIT_DPE = 2'b10,
               STORE = 2'b11;

    integer i;
    reg [7:0] row_idx, col_idx;
    reg [7:0] load_idx;

    reg [31:0] patch_buffer [0:MAX_K-1];
    reg [31:0] filter_buffer [0:MAX_K-1];

    reg  dpe_start;
    wire dpe_done;
    wire [31:0] dpe_result;
    wire [9:0] dpe_patch_addr, dpe_filter_addr;
    reg  [31:0] dpe_patch_data, dpe_filter_data;

    DotProductEngine dpe_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(dpe_start),
        .vec_length({2'b00, K_val}),
        .patch_data(dpe_patch_data),
        .filter_data(dpe_filter_data),
        .done(dpe_done),
        .result(dpe_result),
        .patch_addr(dpe_patch_addr),
        .filter_addr(dpe_filter_addr)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_idx <= 0;
            col_idx <= 0;
            load_idx <= 0;
            dpe_start <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        row_idx <= 0;
                        col_idx <= 0;
                        load_idx <= 0;
                        state <= LOAD_ROW;
                    end
                end

                LOAD_ROW: begin
                    patch_buffer[load_idx] <= matrix_A[row_idx * K_val + load_idx];
                    filter_buffer[load_idx] <= matrix_B[load_idx * N_val + col_idx];
                    if (load_idx == K_val - 1) begin
                        load_idx <= 0;
                        dpe_start <= 1;
                        state <= WAIT_DPE;
                    end else begin
                        load_idx <= load_idx + 1;
                    end
                end

                WAIT_DPE: begin
                    dpe_start <= 0;
                    if (dpe_done) begin
                        state <= STORE;
                    end
                end

                STORE: begin
                    matrix_C[row_idx * N_val + col_idx] <= dpe_result;
                    if (col_idx < N_val - 1) begin
                        col_idx <= col_idx + 1;
                        state <= LOAD_ROW;
                    end else if (row_idx < M_val - 1) begin
                        row_idx <= row_idx + 1;
                        col_idx <= 0;
                        state <= LOAD_ROW;
                    end else begin
                        done <= 1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

    always @(posedge clk) begin
        dpe_patch_data  <= patch_buffer[dpe_patch_addr];
        dpe_filter_data <= filter_buffer[dpe_filter_addr];
    end

endmodule
