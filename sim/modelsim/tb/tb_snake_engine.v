`timescale 1ns/1ps

// -----------------------------------------------------------
// Testbench for snake_engine
// -----------------------------------------------------------
module tb_snake_engine;

    // 50 MHz clock
    reg clk   = 1'b0;
    // active-low reset
    reg rst_n = 1'b0;
    // move tick (1-cycle pulse)
    reg step  = 1'b0;
    // direction: 01=left, 00=right, 10=up, 11=down
    reg [1:0] dir;

    // fruit position in cell coordinates
    reg [5:0] fruit_x_cell;
    reg [5:0] fruit_y_cell;

    // DUT outputs
    wire [5:0] snake_head_x_cell;
    wire [5:0] snake_head_y_cell;
    wire       game_over;
    wire       ate_fruit;
    wire [7:0] snake_len;

    // -------------------------------------------------------
    // Clock generation: 50 MHz -> 20 ns period
    // -------------------------------------------------------
    always #10 clk = ~clk;

    // -------------------------------------------------------
    // DUT instantiation (use defaults: 40x30, MAX_LEN=64)
    // -------------------------------------------------------
    snake_engine #(
        .H_CELLS(40),
        .V_CELLS(30),
        .MAX_LEN(64)
    ) dut (
        .clk               (clk),
        .rst_n             (rst_n),
        .step              (step),
        .dir               (dir),
        .fruit_x_cell      (fruit_x_cell),
        .fruit_y_cell      (fruit_y_cell),
        .snake_head_x_cell (snake_head_x_cell),
        .snake_head_y_cell (snake_head_y_cell),
        .game_over         (game_over),
        .ate_fruit         (ate_fruit),
        .snake_len         (snake_len)
    );

    // -------------------------------------------------------
    // Helper task: generate a single move-tick pulse
    // -------------------------------------------------------
    task do_step;
    begin
        step = 1'b1;
        @(posedge clk);   // one clock with step=1
        step = 1'b0;
        @(posedge clk);   // one clock with step=0 (settle)
    end
    endtask

    // -------------------------------------------------------
    // Test sequence
    // -------------------------------------------------------
    initial begin
        // initial values
        dir          = 2'b00;   // start moving RIGHT
        fruit_x_cell = 6'd21;   // just to the right of default head (20,15)
        fruit_y_cell = 6'd15;

        // hold reset low for a few cycles
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;

        $display("time   x_head  y_head  len  ate  game_over");
        $monitor("%0t   %0d      %0d      %0d   %b    %b",
                 $time, snake_head_x_cell, snake_head_y_cell,
                 snake_len, ate_fruit, game_over);

        // ---------------------------------------------------
        // 1) Move right, eat the fruit on the first step
        // ---------------------------------------------------
        repeat (1) do_step;   // step #1: should land on fruit_x_cell,fruit_y_cell -> growth
        repeat (4) do_step;   // a few more right moves

        // ---------------------------------------------------
        // 2) Turn down
        // ---------------------------------------------------
        dir = 2'b11;          // down
        repeat (4) do_step;

        // ---------------------------------------------------
        // 3) Turn left
        // ---------------------------------------------------
        dir = 2'b01;          // left
        repeat (4) do_step;

        // ---------------------------------------------------
        // 4) Turn up (might self-collide, depending on path)
        // ---------------------------------------------------
        dir = 2'b10;          // up
        repeat (6) do_step;

        // let it run a bit then finish
        #1000;
        $finish;
    end

endmodule
