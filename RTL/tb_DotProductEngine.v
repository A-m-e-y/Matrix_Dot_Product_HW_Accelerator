`timescale 1ns/1ps

module tb_DotProductEngine;

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 4;
    parameter MAX_LEN = 1 << ADDR_WIDTH;

    reg clk;
    reg rst_n;
    reg start;
    reg [ADDR_WIDTH-1:0] vec_length;
    reg [DATA_WIDTH-1:0] patch_data;
    reg [DATA_WIDTH-1:0] filter_data;
    wire done;
    wire [DATA_WIDTH-1:0] result;
    wire [ADDR_WIDTH-1:0] patch_addr;
    wire [ADDR_WIDTH-1:0] filter_addr;

    // Instantiate DUT
    DotProductEngine #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .vec_length(vec_length),
        .patch_data(patch_data),
        .filter_data(filter_data),
        .done(done),
        .result(result),
        .patch_addr(patch_addr),
        .filter_addr(filter_addr)
    );

    // Memories
    reg [DATA_WIDTH-1:0] patch_mem [0:MAX_LEN-1];
    reg [DATA_WIDTH-1:0] filter_mem [0:MAX_LEN-1];

    // Software dot product
    real patch_f [0:MAX_LEN-1];
    real filter_f [0:MAX_LEN-1];
    real expected_dot;
    integer patch_val, filter_val;

    reg [31:0] float32_vals [0:21];

    initial begin
        float32_vals[ 0] = 32'h00000000;
        float32_vals[ 1] = 32'h80000000;
        float32_vals[ 2] = 32'h3f000000;
        float32_vals[ 3] = 32'hbf000000;
        float32_vals[ 4] = 32'h3f800000;
        float32_vals[ 5] = 32'hbf800000;
        float32_vals[ 6] = 32'h3fa00000;
        float32_vals[ 7] = 32'hbfa00000;
        float32_vals[ 8] = 32'h3fc00000;
        float32_vals[ 9] = 32'hbfc00000;
        float32_vals[10] = 32'h40000000;
        float32_vals[11] = 32'hc0000000;
        float32_vals[12] = 32'h40200000;
        float32_vals[13] = 32'hc0200000;
        float32_vals[14] = 32'h40400000;
        float32_vals[15] = 32'hc0400000;
        float32_vals[16] = 32'h40600000;
        float32_vals[17] = 32'hc0600000;
        float32_vals[18] = 32'h40800000;
        float32_vals[19] = 32'hc0800000;
        float32_vals[20] = 32'h40a00000;
        float32_vals[21] = 32'hc0a00000;
    end


    integer i, test;
    integer num_tests = 5;
    integer fd;

    function [31:0] random_float32;
        input dummy;
        reg [7:0] exponent;
        reg [22:0] mantissa;
        reg sign;
        begin
            // Generate safe random exponent between 120 and 140 (around 1.0 to 1000.0)
            exponent = $urandom_range(120, 130);

            // Generate random mantissa
            mantissa = $urandom_range(0, (1<<16)-1);  // 23 random bits

            // Generate random sign
            sign = $urandom_range(0,1);

            // Assemble float32
            random_float32 = {sign, exponent, mantissa};
        end
    endfunction


    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT driver
    always @(posedge clk) begin
        if (rst_n) begin
            patch_data  <= patch_mem[patch_addr];
            filter_data <= filter_mem[filter_addr];
        end
    end

    // Test sequence
    initial begin
        $dumpfile("tb_DotProductEngine.vcd");
        $dumpvars(0, tb_DotProductEngine);

        fd = $fopen("dot_product_vectors.txt", "w");
        if (fd == 0) begin
            $display("❌ ERROR: Could not open file for writing.");
            $finish;
        end

        $display("Starting Randomized Dot Product Tests...\n");

        rst_n = 0;
        start = 0;
        #20;
        rst_n = 1;

        // Generate random vectors and test
        for (test = 0; test < num_tests; test = test + 1) begin
            vec_length = $urandom_range(1, MAX_LEN - 1);
            $fwrite(fd, "vector_length: %0d\n", vec_length);

            for (i = 0; i < vec_length; i = i + 1) begin
                // patch_val  = $urandom_range(0, 21);
                // filter_val = $urandom_range(0, 21);
                // patch_mem[i]  = float32_vals[patch_val];
                // filter_mem[i] = float32_vals[filter_val];
                patch_mem[i]  = random_float32(0);
                filter_mem[i] = random_float32(0);
                $fwrite(fd, "%08x %08x\n", patch_mem[i], filter_mem[i]);
            end

            // $fwrite(fd, "\n");  // Separate blocks for readability

            start = 1;
            #10;
            start = 0;

            wait (done == 1);
            $fwrite(fd, "DUT: %08x\n\n", result);
            #20;
        end

        $fclose(fd);
        $display("✅ Hex vectors written to dot_product_vectors.txt");
        $finish;
    end


endmodule
