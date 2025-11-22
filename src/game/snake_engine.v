// Module: snake_engine
// Description:
//   Snake game core in CELL coordinates (not pixels).
//   - Grows when head reaches fruit cell
//   - Detects wall + self collision
//   - Freezes when game_over = 1

module snake_engine #(
    parameter integer H_CELLS = 40,   // grid width  (cells)
    parameter integer V_CELLS = 30,   // grid height (cells)
    parameter integer MAX_LEN = 64    // max snake segments
)(
    input  wire       clk,
    input  wire       rst_n,          // active-low reset
    input  wire       step,           // 1-cycle move tick (e.g. 1 Hz)
    input  wire [1:0] dir,            // 01=left, 00=right, 10=up, 11=down

    // Fruit position in cell coordinates
    input  wire [5:0] fruit_x_cell,
    input  wire [5:0] fruit_y_cell,

    // Snake head position in cell coordinates (for VGA, etc.)
    output reg  [5:0] snake_head_x_cell,
    output reg  [5:0] snake_head_y_cell,

    // Game state
    output reg        game_over,
    output reg        ate_fruit,      // 1-cycle pulse when fruit eaten
    output reg  [7:0] snake_len,      // current length (segments)

    // helper outputs for rendering / occupancy map.
    output reg  [5:0] new_head_x_cell,  // head position AFTER this move
    output reg  [5:0] new_head_y_cell,
    output reg        new_head_valid,   // 1-cycle pulse when a move occurs

    output reg  [5:0] old_tail_x_cell,  // tail position BEFORE this move
    output reg  [5:0] old_tail_y_cell,
    output reg        old_tail_valid    // 1-cycle pulse when tail cell is freed
);

    // Grid boundaries (for H_CELLS=40, V_CELLS=30)
    localparam [5:0] MIN_X = 6'd0;
    localparam [5:0] MAX_X = H_CELLS - 1;
    localparam [5:0] MIN_Y = 6'd0;
    localparam [5:0] MAX_Y = V_CELLS - 1;

    // Snake body storage: [0] = head, [snake_len-1] = tail
    reg [5:0] snake_x [0:MAX_LEN-1];
    reg [5:0] snake_y [0:MAX_LEN-1];

    integer i;

    // Next head position (combinational)
    reg [5:0] next_head_x;
    reg [5:0] next_head_y;
    reg       will_hit_wall;

    // Direction → next head position + wall check
    always @* begin
        next_head_x   = snake_head_x_cell;
        next_head_y   = snake_head_y_cell;
        will_hit_wall = 1'b0;

        case (dir)
            2'b01: begin // left: X--
                if (snake_head_x_cell == MIN_X)
                    will_hit_wall = 1'b1;
                else
                    next_head_x = snake_head_x_cell - 6'd1;
            end

            2'b00: begin // right: X++
                if (snake_head_x_cell == MAX_X)
                    will_hit_wall = 1'b1;
                else
                    next_head_x = snake_head_x_cell + 6'd1;
            end

            2'b10: begin // up: Y--
                if (snake_head_y_cell == MIN_Y)
                    will_hit_wall = 1'b1;
                else
                    next_head_y = snake_head_y_cell - 6'd1;
            end

            2'b11: begin // down: Y++
                if (snake_head_y_cell == MAX_Y)
                    will_hit_wall = 1'b1;
                else
                    next_head_y = snake_head_y_cell + 6'd1;
            end

            default: begin
                // hold direction if invalid
            end
        endcase
    end

    // Will we land on the fruit after the next move?
    wire hit_fruit_next =
        (next_head_x == fruit_x_cell) &&
        (next_head_y == fruit_y_cell);

    // Self-collision check
    // Tail exception:
    reg self_hit;

    always @* begin
        self_hit = 1'b0;
        for (i = 0; i < MAX_LEN; i = i + 1) begin
            if (i < snake_len) begin
                // Ignore tail when not growing
                if (!hit_fruit_next && (i == snake_len-1)) begin
                    // skip tail, it will move away
                end else if ((next_head_x == snake_x[i]) &&
                             (next_head_y == snake_y[i])) begin
                    self_hit = 1'b1;
                end
            end
        end
    end

    // Sequential logic: movement, growth, game_over
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset snake: centered, length 3, horizontal to left
            snake_head_x_cell <= H_CELLS/2;
            snake_head_y_cell <= V_CELLS/2;
            game_over         <= 1'b0;

            snake_len         <= 8'd3;

            // Head segment
            snake_x[0]        <= H_CELLS/2;
            snake_y[0]        <= V_CELLS/2;
            // Body segments
            snake_x[1]        <= H_CELLS/2 - 1;
            snake_y[1]        <= V_CELLS/2;
            snake_x[2]        <= H_CELLS/2 - 2;
            snake_y[2]        <= V_CELLS/2;

            // Clear unused segments
            for (i = 3; i < MAX_LEN; i = i + 1) begin
                snake_x[i] <= 6'd0;
                snake_y[i] <= 6'd0;
            end

            ate_fruit        <= 1'b0;

            // Helper outputs for occupancy / rendering
            new_head_x_cell  <= 6'd0;
            new_head_y_cell  <= 6'd0;
            old_tail_x_cell  <= 6'd0;
            old_tail_y_cell  <= 6'd0;
            new_head_valid   <= 1'b0;
            old_tail_valid   <= 1'b0;

        end else begin
            // Default: clear 1-cycle pulses
            ate_fruit      <= 1'b0;
            new_head_valid <= 1'b0;
            old_tail_valid <= 1'b0;

            if (game_over) begin
                // Freeze snake when game_over is asserted
                // No movement, no length change
            end else if (step) begin
                // Only update on step pulse

                // Check collisions first
                if (will_hit_wall || self_hit) begin
                    game_over <= 1'b1;
                end else begin
                    // No collision: perform the move

                    // Inform helpers what the new head cell will be
                    new_head_x_cell <= next_head_x;
                    new_head_y_cell <= next_head_y;
                    new_head_valid  <= 1'b1;

                    if (hit_fruit_next && (snake_len < MAX_LEN)) begin
                        // GROWTH MOVE (fruit eaten)
                        // Shift body:
                        // old [0] -> [1], ..., old [snake_len-1] -> [snake_len]
                        for (i = MAX_LEN-1; i > 0; i = i - 1) begin
                            if (i <= snake_len) begin
                                snake_x[i] <= snake_x[i-1];
                                snake_y[i] <= snake_y[i-1];
                            end
                        end

                        // New head position
                        snake_x[0]        <= next_head_x;
                        snake_y[0]        <= next_head_y;
                        snake_head_x_cell <= next_head_x;
                        snake_head_y_cell <= next_head_y;

                        // Increase length
                        snake_len <= snake_len + 8'd1;
                        ate_fruit <= 1'b1;

                        // For a growth move, the tail cell is NOT freed,
                        // so old_tail_valid stays 0 in this branch.

                    end else begin
                        // NORMAL MOVE
                        // Capture old tail position BEFORE it is overwritten.
                        old_tail_x_cell <= snake_x[snake_len-1];
                        old_tail_y_cell <= snake_y[snake_len-1];
                        old_tail_valid  <= 1'b1;

                        // Shift body:
                        // old [0] -> [1], ..., old [snake_len-2] -> [snake_len-1]
                        for (i = MAX_LEN-1; i > 0; i = i - 1) begin
                            if (i < snake_len) begin
                                snake_x[i] <= snake_x[i-1];
                                snake_y[i] <= snake_y[i-1];
                            end
                        end

                        // New head position
                        snake_x[0]        <= next_head_x;
                        snake_y[0]        <= next_head_y;
                        snake_head_x_cell <= next_head_x;
                        snake_head_y_cell <= next_head_y;
                    end
                end
            end
        end
    end

endmodule
