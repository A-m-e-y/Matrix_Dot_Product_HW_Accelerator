`timescale 1ns/1ps

module tb_DotProductEngine;

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 4;  // 16 elements max for this simple TB

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

    // Instantiate the DotProductEngine
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

    // Memory arrays for patch and filter
    reg [DATA_WIDTH-1:0] patch_mem [0:15];
    reg [DATA_WIDTH-1:0] filter_mem [0:15];

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz clock
    end

    // Test sequence
    initial begin
        $display("Starting Dot Product Engine Testbench...");

        // Enable VCD dumping
        $dumpfile("tb_DotProductEngine.vcd");  // Specify the VCD file name
        $dumpvars(0, tb_DotProductEngine);     // Dump all variables in the module

        rst_n = 0;
        start = 0;
        vec_length = 4;  // Test with 4 elements
        #20;

        rst_n = 1;
        #20;

        // Initialize patch and filter data
        // patch_mem[0] = 32'h00000000; // 0.0
        patch_mem[0] = 32'h3f800000; // 1.0
        patch_mem[1] = 32'h40000000; // 2.0
        patch_mem[2] = 32'h40400000; // 3.0
        patch_mem[3] = 32'h40800000; // 4.0

        // filter_mem[0] = 32'h00000000; // 0.0
        filter_mem[0] = 32'h3f800000; // 1.0
        filter_mem[1] = 32'h40000000; // 2.0
        filter_mem[2] = 32'h40400000; // 3.0
        filter_mem[3] = 32'h40800000; // 4.0

        start = 1;
        #10;
        start = 0;

        wait (done == 1);

        $display("Dot product result: %h", result);

        $finish;
    end

    // Drive patch and filter data based on addresses
    always @(posedge clk) begin
        if (rst_n) begin
            patch_data <= patch_mem[patch_addr];
            filter_data <= filter_mem[filter_addr];
        end
    end

endmodule
