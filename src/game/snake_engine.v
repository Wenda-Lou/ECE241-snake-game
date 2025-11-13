// ===========================================================
// Module: snake_engine
// Description:
//   Snake game core in CELL coordinates (not pixels).
//   - Moves 1 cell whenever `step` pulses
//   - Grows when head reaches fruit cell
//   - Detects wall + self collision
//   - Freezes when game_over = 1
// ===========================================================
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

    // Snake head position in cell coordinates
    output reg  [5:0] snake_head_x_cell,
    output reg  [5:0] snake_head_y_cell,
    output reg        game_over,

    output reg        ate_fruit,      // pulse when fruit eaten
    output reg  [7:0] snake_len       // current length (segments)
);

    // Grid boundaries (for H_CELLS=40, V_CELLS=30)
    localparam [5:0] MIN_X = 6'd0;
    localparam [5:0] MAX_X = 6'd39;
    localparam [5:0] MIN_Y = 6'd0;
    localparam [5:0] MAX_Y = 6'd29;

    // Snake body storage: [0] = head, [snake_len-1] = tail
    reg [5:0] snake_x [0:MAX_LEN-1];
    reg [5:0] snake_y [0:MAX_LEN-1];

    integer i;

    // Next head position (combinational)
    reg [5:0] next_head_x;
    reg [5:0] next_head_y;
    reg       will_hit_wall;

    // ----------------------------------------------------------------
    // Direction → next head position + wall check
    // ----------------------------------------------------------------
    always @* begin
        next_head_x  = snake_head_x_cell;
        next_head_y  = snake_head_y_cell;
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

    // Fruit hit on next move?
    wire hit_fruit_next =
        (next_head_x == fruit_x_cell) &&
        (next_head_y == fruit_y_cell);

    // ----------------------------------------------------------------
    // Self-collision check (combinational)
    // Tail exception: if we're NOT growing this move, head is allowed
    // to move into the current tail position (it will move away).
    // ----------------------------------------------------------------
    reg self_hit;

    always @* begin
        self_hit = 1'b0;
        for (i = 0; i < MAX_LEN; i = i + 1) begin
            if (i < snake_len) begin
                // ignore tail when not growing
                if (!hit_fruit_next && (i == snake_len-1)) begin
                    // skip tail, it will vacate
                end else if ((next_head_x == snake_x[i]) &&
                             (next_head_y == snake_y[i])) begin
                    self_hit = 1'b1;
                end
            end
        end
    end

    // ----------------------------------------------------------------
    // Sequential logic: movement, growth, game_over
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset snake: center, length 3, horizontal to the left
            snake_head_x_cell <= H_CELLS/2;
            snake_head_y_cell <= V_CELLS/2;
            game_over         <= 1'b0;

            snake_len         <= 8'd3;
            snake_x[0]        <= H_CELLS/2;       // head
            snake_y[0]        <= V_CELLS/2;
            snake_x[1]        <= H_CELLS/2 - 1;
            snake_y[1]        <= V_CELLS/2;
            snake_x[2]        <= H_CELLS/2 - 2;
            snake_y[2]        <= V_CELLS/2;

            for (i = 3; i < MAX_LEN; i = i + 1) begin
                snake_x[i] <= 6'd0;
                snake_y[i] <= 6'd0;
            end

            ate_fruit <= 1'b0;

        end else begin
            ate_fruit <= 1'b0;  // default each cycle

            if (game_over) begin
                // freeze: do nothing
            end else if (step) begin
                // only update on step pulse

                // Collision with wall or self?
                if (will_hit_wall || self_hit) begin
                    game_over <= 1'b1;

                end else begin
                    // ------------------------------------------------
                    // GROWTH MOVE (eat fruit)
                    // ------------------------------------------------
                    if (hit_fruit_next && (snake_len < MAX_LEN)) begin
                        // Shift body:
                        // old [0] -> [1], ..., old [snake_len-1] -> [snake_len]
                        for (i = MAX_LEN-1; i > 0; i = i - 1) begin
                            if (i <= snake_len) begin
                                snake_x[i] <= snake_x[i-1];
                                snake_y[i] <= snake_y[i-1];
                            end
                        end

                        snake_x[0]        <= next_head_x;
                        snake_y[0]        <= next_head_y;
                        snake_head_x_cell <= next_head_x;
                        snake_head_y_cell <= next_head_y;

                        snake_len <= snake_len + 8'd1;
                        ate_fruit <= 1'b1;

                    end else begin
                        // ------------------------------------------------
                        // NORMAL MOVE (no growth)
                        // ------------------------------------------------
                        // Shift body:
                        // old [0] -> [1], ..., old [snake_len-2] -> [snake_len-1]
                        for (i = MAX_LEN-1; i > 0; i = i - 1) begin
                            if (i < snake_len) begin
                                snake_x[i] <= snake_x[i-1];
                                snake_y[i] <= snake_y[i-1];
                            end
                        end

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
