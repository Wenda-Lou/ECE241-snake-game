// ===========================================================
// Module: painter
// Description:
//   Frame-based painter:
//   - Draws black background + white border
//   - Draws red circular fruit
//   - Draws full snake body from occupancy bitmap
//   - Draws solid red Game Over screen when game_over = 1
// ===========================================================
module painter #(
    parameter integer H_RES    = 640,
    parameter integer V_RES    = 480,
    parameter integer H_CELLS  = 40,
    parameter integer V_CELLS  = 30,
    parameter integer CELL_PX  = 16
)(
    input  wire        clk,
    input  wire        resetn,

    // Unused for now (kept for interface compatibility)
    input  wire [9:0]  x_min_px,
    input  wire [9:0]  x_max_px,
    input  wire [9:0]  y_min_px,
    input  wire [9:0]  y_max_px,

    // Fruit pixel center
    input  wire [9:0]  fruit_cx,
    input  wire [9:0]  fruit_cy,

    // Frame trigger
    input  wire        start,

    // Game over flag
    input  wire        game_over,

    // Snake direction
    input wire [1:0]  snake_dir,

    // Snake occupancy bitmap in cell coordinates
    // bit index = y_cell * H_CELLS + x_cell
    input  wire [H_CELLS*V_CELLS-1:0] snake_occ,

    // Snake head cell (for special coloring)
    input  wire [5:0]  snake_head_x_cell,
    input  wire [5:0]  snake_head_y_cell,

    // Outputs to VGA adapter
    output reg  [9:0]  x,
    output reg  [9:0]  y,
    output reg  [2:0]  colour,
    output reg         plot,
    output reg         busy
);
    // Basic parameters
    localparam integer BORDER_THICK = 4;

    // Colours (3-bit: R,G,B)
    localparam [2:0] COL_BLACK = 3'b000;
    localparam [2:0] COL_GREEN = 3'b010; // head
    localparam [2:0] COL_WHITE = 3'b111;
    localparam [2:0] COL_RED   = 3'b100;
    localparam [2:0] COL_BODY  = 3'b011;  // body segments (slightly different from head)

    // Fruit radius (squared)
    localparam [3:0] FRUIT_RADIUS    = 4'd6;
    localparam [7:0] FRUIT_RADIUS_SQ = FRUIT_RADIUS * FRUIT_RADIUS;

    // FSM states
    localparam [2:0] S_INIT_BG    = 3'd0; // draw background + border
    localparam [2:0] S_FRUIT      = 3'd1; // draw fruit circle
    localparam [2:0] S_BODY_CELL  = 3'd2; // iterate cells
    localparam [2:0] S_BODY_PIX   = 3'd3; // draw one cell's 16x16 block
    localparam [2:0] S_IDLE       = 3'd4; // idle between frames
    localparam [2:0] S_GAME_OVER  = 3'd5; // game over screen

    reg [2:0] state;

    // Pixel scan counters for full-frame operations
    reg [9:0] xi, yi;

    // Fruit drawing window
    reg [9:0] fx_min, fx_max;
    reg [9:0] fy_min, fy_max;

    // Snake body cell scan
    reg [5:0] cell_x, cell_y;   // 0..H_CELLS-1, 0..V_CELLS-1
    reg [3:0] cell_px, cell_py; // 0..15: pixel offset in cell

    reg is_eye_pixel;

    // Fruit distance computation (in pixel space)
    wire signed [10:0] sxi = {1'b0, xi};
    wire signed [10:0] syi = {1'b0, yi};
    wire signed [10:0] fcx = {1'b0, fruit_cx};
    wire signed [10:0] fcy = {1'b0, fruit_cy};
    wire signed [10:0] dx  = sxi - fcx;
    wire signed [10:0] dy  = syi - fcy;
    wire        [21:0] dist_sq = dx*dx + dy*dy;

    // Current cell occupancy lookup
    wire [10:0] body_index    = cell_y * H_CELLS + cell_x;
    wire        cell_occupied = snake_occ[body_index];

    always @* begin
        is_eye_pixel = 1'b0;

        // Only consider head cell
        if (cell_x == snake_head_x_cell && cell_y == snake_head_y_cell) begin
            case (snake_dir)
                2'b00: begin
                    // Facing right: eyes on the right side (two 2x2 squares)
                    if ( (cell_px >= 4'd11 && cell_px < 4'd13) &&
                         ( (cell_py >= 4'd4  && cell_py < 4'd6) ||
                           (cell_py >= 4'd10 && cell_py < 4'd12) ) )
                        is_eye_pixel = 1'b1;
                end
                2'b01: begin
                    // Facing left: eyes on the left side
                    if ( (cell_px >= 4'd3 && cell_px < 4'd5) &&
                         ( (cell_py >= 4'd4  && cell_py < 4'd6) ||
                           (cell_py >= 4'd10 && cell_py < 4'd12) ) )
                        is_eye_pixel = 1'b1;
                end
                2'b10: begin
                    // Facing up: eyes at the top
                    if ( (cell_py >= 4'd3 && cell_py < 4'd5) &&
                         ( (cell_px >= 4'd4  && cell_px < 4'd6) ||
                           (cell_px >= 4'd10 && cell_px < 4'd12) ) )
                        is_eye_pixel = 1'b1;
                end
                2'b11: begin
                    // Facing down: eyes at the bottom
                    if ( (cell_py >= 4'd11 && cell_py < 4'd13) &&
                         ( (cell_px >= 4'd4  && cell_px < 4'd6) ||
                           (cell_px >= 4'd10 && cell_px < 4'd12) ) )
                        is_eye_pixel = 1'b1;
                end
                default: begin
                    is_eye_pixel = 1'b0;
                end
            endcase
        end
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state  <= S_INIT_BG;
            xi     <= 10'd0;
            yi     <= 10'd0;
            x      <= 10'd0;
            y      <= 10'd0;
            colour <= COL_BLACK;
            plot   <= 1'b0;
            busy   <= 1'b1;

            fx_min <= 10'd0; fx_max <= 10'd0;
            fy_min <= 10'd0; fy_max <= 10'd0;

            cell_x  <= 6'd0;
            cell_y  <= 6'd0;
            cell_px <= 4'd0;
            cell_py <= 4'd0;
        end else begin
            // default: do not write unless explicitly set
            plot <= 1'b0;

            case (state)
                // -------------------------------------------------
                // Draw background + border
                // -------------------------------------------------
                S_INIT_BG: begin
                    busy <= 1'b1;

                    // Border = white, inside = black
                    if (xi < BORDER_THICK || xi >= H_RES - BORDER_THICK ||
                        yi < BORDER_THICK || yi >= V_RES - BORDER_THICK)
                        colour <= COL_WHITE;
                    else
                        colour <= COL_BLACK;

                    x    <= xi;
                    y    <= yi;
                    plot <= 1'b1;

                    if (xi == H_RES - 1) begin
                        if (yi == V_RES - 1) begin
                            // Finished full screen background
                            // Prepare fruit window (clamped to screen)
                            fx_min <= (fruit_cx > FRUIT_RADIUS) ? (fruit_cx - FRUIT_RADIUS) : 10'd0;
                            fy_min <= (fruit_cy > FRUIT_RADIUS) ? (fruit_cy - FRUIT_RADIUS) : 10'd0;
                            fx_max <= (fruit_cx + FRUIT_RADIUS <= H_RES-1) ? (fruit_cx + FRUIT_RADIUS) : (H_RES-1);
                            fy_max <= (fruit_cy + FRUIT_RADIUS <= V_RES-1) ? (fruit_cy + FRUIT_RADIUS) : (V_RES-1);

                            xi     <= (fruit_cx > FRUIT_RADIUS) ? (fruit_cx - FRUIT_RADIUS) : 10'd0;
                            yi     <= (fruit_cy > FRUIT_RADIUS) ? (fruit_cy - FRUIT_RADIUS) : 10'd0;
                            state  <= S_FRUIT;
                        end else begin
                            xi <= 10'd0;
                            yi <= yi + 10'd1;
                        end
                    end else begin
                        xi <= xi + 10'd1;
                    end
                end

                // -------------------------------------------------
                // Draw red circular fruit
                // -------------------------------------------------
                S_FRUIT: begin
                    busy <= 1'b1;

                    // Only draw inside the window; outside we leave bg as is
                    if (dist_sq <= FRUIT_RADIUS_SQ) begin
                        colour <= COL_RED;
                        x      <= xi;
                        y      <= yi;
                        plot   <= 1'b1;
                    end

                    // Scan fruit window
                    if (xi == fx_max) begin
                        xi <= fx_min;
                        if (yi == fy_max) begin
                            // Finished fruit; now iterate snake body cells
                            cell_x  <= 6'd0;
                            cell_y  <= 6'd0;
                            cell_px <= 4'd0;
                            cell_py <= 4'd0;
                            state   <= S_BODY_CELL;
                        end else begin
                            yi <= yi + 10'd1;
                        end
                    end else begin
                        xi <= xi + 10'd1;
                    end
                end

                // -------------------------------------------------
                // Iterate all cells; if occupied, go draw its 16x16 block
                // -------------------------------------------------
                S_BODY_CELL: begin
                    busy <= 1'b1;

                    if (cell_y < V_CELLS) begin
                        if (cell_occupied) begin
                            // Start drawing this occupied cell
                            cell_px <= 4'd0;
                            cell_py <= 4'd0;
                            state   <= S_BODY_PIX;
                        end else begin
                            // Move to next cell
                            if (cell_x == H_CELLS - 1) begin
                                cell_x <= 6'd0;
                                if (cell_y == V_CELLS - 1) begin
                                    // Finished last cell
                                    state <= S_IDLE;
                                    busy  <= 1'b0;
                                end else begin
                                    cell_y <= cell_y + 6'd1;
                                end
                            end else begin
                                cell_x <= cell_x + 6'd1;
                            end
                        end
                    end else begin
                        // Safety: out of range, go idle
                        state <= S_IDLE;
                        busy  <= 1'b0;
                    end
                end

                // -------------------------------------------------
                // Draw all pixels of one occupied cell as a solid block
                // -------------------------------------------------
                S_BODY_PIX: begin
                    busy   <= 1'b1;

                    // Head cell vs body cell colour, with eyes
                    if (cell_x == snake_head_x_cell && cell_y == snake_head_y_cell) begin
                        if (is_eye_pixel)
                            colour <= COL_WHITE;  // eyes
                        else
                            colour <= COL_GREEN;  // head base colour
                    end else begin
                        colour <= COL_BODY;       // normal body segments
                    end

                    x      <= {cell_x, 4'b0000} + cell_px; // cell_x * 16 + offset
                    y      <= {cell_y, 4'b0000} + cell_py; // cell_y * 16 + offset
                    plot   <= 1'b1;

                    if (cell_px == CELL_PX - 1) begin
                        cell_px <= 4'd0;
                        if (cell_py == CELL_PX - 1) begin
                            cell_py <= 4'd0;
                            // Finished this cell, move to next cell
                            if (cell_x == H_CELLS - 1) begin
                                cell_x <= 6'd0;
                                if (cell_y == V_CELLS - 1) begin
                                    state <= S_IDLE; // finished all cells
                                    busy  <= 1'b0;
                                end else begin
                                    cell_y <= cell_y + 6'd1;
                                    state  <= S_BODY_CELL;
                                end
                            end else begin
                                cell_x <= cell_x + 6'd1;
                                state  <= S_BODY_CELL;
                            end
                        end else begin
                            cell_py <= cell_py + 4'd1;
                        end
                    end else begin
                        cell_px <= cell_px + 4'd1;
                    end
                end

                // -------------------------------------------------
                // Idle: wait for start or game_over
                // -------------------------------------------------
                S_IDLE: begin
                    busy <= 1'b0;
                    if (game_over) begin
                        // Start drawing game over screen
                        xi    <= 10'd0;
                        yi    <= 10'd0;
                        state <= S_GAME_OVER;
                    end else if (start) begin
                        // Start next normal frame
                        xi    <= 10'd0;
                        yi    <= 10'd0;
                        busy  <= 1'b1;
                        state <= S_INIT_BG;
                    end
                end

                // -------------------------------------------------
                // Game over screen: solid red inside border
                // -------------------------------------------------
                S_GAME_OVER: begin
                    busy <= 1'b1;
                    if (xi < H_RES && yi < V_RES) begin
                        x <= xi;
                        y <= yi;

                        if (xi < BORDER_THICK || xi >= H_RES - BORDER_THICK ||
                            yi < BORDER_THICK || yi >= V_RES - BORDER_THICK)
                            colour <= COL_WHITE;
                        else
                            colour <= COL_RED;

                        plot <= 1'b1;

                        if (xi == H_RES - 1) begin
                            xi <= 10'd0;
                            if (yi == V_RES - 1) begin
                                // Finished game-over frame; remain idle
                                busy  <= 1'b0;
                                state <= S_IDLE;
                            end else begin
                                yi <= yi + 10'd1;
                            end
                        end else begin
                            xi <= xi + 10'd1;
                        end
                    end else begin
                        // Safety
                        busy  <= 1'b0;
                        state <= S_IDLE;
                    end
                end

                default: begin
                    state <= S_IDLE;
                    busy  <= 1'b0;
                end
            endcase
        end
    end

endmodule
