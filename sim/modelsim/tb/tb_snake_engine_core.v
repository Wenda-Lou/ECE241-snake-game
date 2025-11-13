`timescale 1ns / 1ps

module tb_snake_engine;

    // Declare the signals
    reg clk;
    reg rst_n;
    reg [1:0] dir;           // Direction input (up, down, left, right)
    wire [7:0] snake_head_x; // X position of the snake head (grid-based)
    wire [7:0] snake_head_y; // Y position of the snake head (grid-based)
    wire game_over;          // Game over flag

    // Instantiate the snake engine module
    snake_engine uut (
        .clk(clk),
        .rst_n(rst_n),
        .dir(dir),
        .snake_head_x(snake_head_x),
        .snake_head_y(snake_head_y),
        .game_over(game_over)
    );

    // Clock generation
    always begin
        #5 clk = ~clk;  // 100 MHz clock (adjust as needed)
    end

    // Test stimulus
    initial begin
        // Initialize the signals
        clk = 0;
        rst_n = 0;
        dir = 2'b00;  // Start with moving right

        // Apply reset
        #10 rst_n = 1;

        // Test 1: Move right (2'b01)
        #20 dir = 2'b01;  // Move left
        #100 dir = 2'b00; // Move right

        // Test 2: Move up (2'b10)
        #100 dir = 2'b10;  // Move up
        #100 dir = 2'b00;  // Move right

        // Test 3: Move down (2'b11)
        #100 dir = 2'b11;  // Move down
        #100 dir = 2'b00;  // Move right

        // Test Game Over Condition (Move out of bounds)
        #100 dir = 2'b01;  // Move left
        #400 dir = 2'b10;  // Move up (Out of bounds)

        // End the simulation
        #100 $finish;
    end
endmodule
