`timescale 1ns/1ps

module tb_MatrixMulEngine;
    parameter MAX_M = 100;
    parameter MAX_K = 100;
    parameter MAX_N = 100;

    reg clk;
    reg rst_n;
    reg start;
    wire done;

    reg [7:0] M, K, N;

    reg  [31:0] matrix_A [0:MAX_M*MAX_K-1];
    reg  [31:0] matrix_B [0:MAX_K*MAX_N-1];
    wire [31:0] matrix_C [0:MAX_M*MAX_N-1];

    integer i;
    integer outfile;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Instantiate DUT with static max sizes; only use M, K, N values dynamically
    MatrixMulEngine #(.MAX_M(MAX_M), .MAX_K(MAX_K), .MAX_N(MAX_N)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .M_val(M),
        .K_val(K),
        .N_val(N),
        .start(start),
        .done(done),
        .matrix_A(matrix_A),
        .matrix_B(matrix_B),
        .matrix_C(matrix_C)
    );

    // Random float generator function
    function [31:0] random_float32;
        input dummy;
        reg [7:0] exponent;
        reg [22:0] mantissa;
        reg sign;
        begin
            exponent = $urandom_range(120, 130);         // Between ~1.0 and 1000.0
            mantissa = $urandom_range(0, (1<<16)-1);     // 16 bits random mantissa
            sign = $urandom_range(0,1);                  // Random sign
            random_float32 = {sign, exponent, mantissa};
        end
    endfunction

    // Test logic
    initial begin
        $display("[TB] Starting MatrixMulEngine test...");
        $dumpfile("tb_MatrixMulEngine.vcd");
        $dumpvars(0, tb_MatrixMulEngine);

        outfile = $fopen("matrix_result_dump.txt", "w");

        rst_n = 0;
        start = 0;
        #20;

        rst_n = 1;
        #10;

        // Randomize M, K, N between 2 and 10
        M = $urandom_range(10, MAX_M);
        K = $urandom_range(10, MAX_K);
        N = $urandom_range(10, MAX_N);
        // M = 50;
        // K = 50;
        // N = 50;

        // Zero out full matrices first
        for (i = 0; i < MAX_M*MAX_K; i = i + 1) matrix_A[i] = 32'h00000000;
        for (i = 0; i < MAX_K*MAX_N; i = i + 1) matrix_B[i] = 32'h00000000;

        // Fill active regions with random floats
        // matrix_A[0] = 32'h3f800000; // 1.0
        // matrix_A[1] = 32'h40000000; // 2.0
        // matrix_A[2] = 32'h40400000; // 3.0
        // matrix_A[3] = 32'h40800000; // 4.0
        // matrix_B[0] = 32'h3f800000; // 1.0
        // matrix_B[1] = 32'h40000000; // 2.0
        // matrix_B[2] = 32'h40400000; // 3.0
        // matrix_B[3] = 32'h40800000; // 4.0
        for (i = 0; i < M*K; i = i + 1) matrix_A[i] = random_float32(0);
        for (i = 0; i < K*N; i = i + 1) matrix_B[i] = random_float32(0);


        $display("Matrix A:");
        for (i = 0; i < M*K; i = i + 1) $display("%08h", matrix_A[i]);
        
        $display("Matrix B:");
        for (i = 0; i < K*N; i = i + 1) $display("%08h", matrix_B[i]);


        #10;
        start = 1;
        #10;
        start = 0;

        wait (done);
        #20;

        $display("Matrix C:");
        for (i = 0; i < M*N; i = i + 1) $display("%08h", matrix_C[i]);

        // Dump to file
        $fdisplay(outfile, "M: %0d, K: %0d", M, K);
        for (i = 0; i < M*K; i = i + 1)
            $fdisplay(outfile, "%08h", matrix_A[i]);

        $fdisplay(outfile, "K: %0d, N: %0d", K, N);
        for (i = 0; i < K*N; i = i + 1)
            $fdisplay(outfile, "%08h", matrix_B[i]);

        $fdisplay(outfile, "M: %0d, N: %0d", M, N);
        for (i = 0; i < M*N; i = i + 1)
            $fdisplay(outfile, "%08h", matrix_C[i]);

        $fclose(outfile);

        $display("\n[TB] Dumped matrix data to matrix_result_dump.txt");
        $display("[TB] Test complete!");
        $finish;
    end
endmodule
