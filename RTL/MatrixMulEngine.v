`timescale 1ns/1ps

module MatrixMulEngine #(
    parameter M = 2,   // Rows of A
    parameter K = 2,   // Cols of A / Rows of B
    parameter N = 2    // Cols of B
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg done,

    input  wire [31:0] matrix_A [0:M*K-1],
    input  wire [31:0] matrix_B [0:K*N-1],
    output reg  [31:0] matrix_C [0:M*N-1]
);

    // FSM states
    reg [1:0] state;
    localparam IDLE  = 2'b00,
               LOAD  = 2'b01,
               WAIT  = 2'b10,
               STORE = 2'b11;

    // Counters
    integer i, j;
    reg [7:0] row_idx, col_idx;

    // Buffers for dot product inputs
    reg [31:0] patch_buffer [0:K-1];   // A row
    reg [31:0] filter_buffer [0:K-1];  // B column

    // Dot Product Engine signals
    reg  dpe_start;
    wire dpe_done;
    wire [31:0] dpe_result;
    wire [9:0] dpe_patch_addr, dpe_filter_addr;
    reg  [31:0] dpe_patch_data, dpe_filter_data;

    // Instance of dot product engine
    DotProductEngine dpe_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(dpe_start),
        .vec_length(K[9:0]),
        .patch_data(dpe_patch_data),
        .filter_data(dpe_filter_data),
        .done(dpe_done),
        .result(dpe_result),
        .patch_addr(dpe_patch_addr),
        .filter_addr(dpe_filter_addr)
    );

    // FSM Logic
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
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    for (i = 0; i < K; i = i + 1) begin
                        patch_buffer[i] <= matrix_A[row_idx * K + i];
                    end
                    for (j = 0; j < K; j = j + 1) begin
                        filter_buffer[j] <= matrix_B[j * N + col_idx];
                    end
                    dpe_start <= 1;
                    state <= WAIT;
                end

                WAIT: begin
                    dpe_start <= 0;
                    if (dpe_done) begin
                        state <= STORE;
                    end
                end

                STORE: begin
                    matrix_C[row_idx * N + col_idx] <= dpe_result;
                    if (col_idx < N - 1) begin
                        col_idx <= col_idx + 1;
                        state <= LOAD;
                    end else if (row_idx < M - 1) begin
                        row_idx <= row_idx + 1;
                        col_idx <= 0;
                        state <= LOAD;
                    end else begin
                        done <= 1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

    // Provide current address data to DotProductEngine
    always @(posedge clk) begin
        dpe_patch_data  <= patch_buffer[dpe_patch_addr];
        dpe_filter_data <= filter_buffer[dpe_filter_addr];
    end

endmodule
