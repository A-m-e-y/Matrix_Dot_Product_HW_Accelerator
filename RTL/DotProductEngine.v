module DotProductEngine #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [ADDR_WIDTH-1:0] vec_length,
    input wire [DATA_WIDTH-1:0] patch_data,
    input wire [DATA_WIDTH-1:0] filter_data,
    output reg done,
    output reg [DATA_WIDTH-1:0] result,
    output reg [ADDR_WIDTH-1:0] patch_addr,
    output reg [ADDR_WIDTH-1:0] filter_addr
);

    // FSM states
    reg [1:0] state, next_state;
    parameter IDLE = 2'b00;
    parameter RUN  = 2'b01;
    parameter WAIT_RESULT = 2'b10;
    parameter DONE = 2'b11;

    reg [ADDR_WIDTH-1:0] counter;
    reg [DATA_WIDTH-1:0] acc;

    wire [DATA_WIDTH-1:0] mac_result;

    // Instantiate MAC unit
    MAC32_top u_mac (
        .clk(clk),
        .rst_n(rst_n),
        .A_i(acc),
        .B_i(patch_data),
        .C_i(filter_data),
        .Result(mac_result)
    );

    // State transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE: next_state = (start) ? RUN : IDLE;
            // RUN: next_state = (counter == vec_length) ? WAIT_RESULT : RUN;
            RUN: next_state = WAIT_RESULT;
            WAIT_RESULT: next_state = (counter == vec_length) ? DONE : RUN;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Counter, Accumulator, Address Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            acc <= 0;
            patch_addr <= 0;
            filter_addr <= 0;
            done <= 0;
            result <= 0;
        end else begin
            case (state)
                IDLE: begin
                    counter <= 0;
                    acc <= 32'b0;
                    patch_addr <= 0;
                    filter_addr <= 0;
                    done <= 0;
                end
                RUN: begin
                    // acc <= mac_result;  // latch output
                    patch_addr <= patch_addr + 1;
                    filter_addr <= filter_addr + 1;
                    counter <= counter + 1;
                end
                WAIT_RESULT: begin
                    acc <= mac_result;  // capture final MAC output
                end
                DONE: begin
                    result <= acc;
                    done <= 1;
                end
            endcase
        end
    end

endmodule
