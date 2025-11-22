// ===========================================================
// Module: fruit_placer
// Description:
//   Generate fruit board coordinates (cell_x, cell_y) using the random stream
//   with constraints: stay at least MARGIN_CELLS away from the border, avoid the snake head,
//   maintain a Manhattan distance >= MIN_DIST from the head,
//   choose the candidate farthest from the head among TRIES attempts,
//   and fall back to the farthest corner if no candidate passes.
//   Uses only addition/subtraction/compare (no multipliers); fully Verilog-2001 compatible.
// ===========================================================
module fruit_placer #(
    parameter integer CELL_PX      = 16,   // Pixel size per cell (interface alignment, unused internally)
    parameter integer H_CELLS      = 40,   // 640 / 16
    parameter integer V_CELLS      = 30,   // 480 / 16
    parameter integer MARGIN_CELLS = 1,    // Minimum number of cells away from the border
    parameter integer TRIES        = 16,   // Number of candidate attempts (more tries => farther placement)
    parameter integer MIN_DIST     = 3     // Minimum safe Manhattan distance (cells)
)(
    input  wire       clk,
    input  wire       resetn,

    // Trigger: when request=1 (typically for 1 cycle), start generating a new fruit
    input  wire       request,

    // Current snake-head cell coordinates (could be extended to pass the body bitmap)
    input  wire [5:0] snake_x_cell,   // 0..63 (effectively <= H_CELLS-1)
    input  wire [5:0] snake_y_cell,   // 0..63 (effectively <= V_CELLS-1)

    // Output result: fruit cell coordinate
    output reg  [5:0] fruit_x_cell,
    output reg  [5:0] fruit_y_cell,

    // Handshake/status
    output reg        done,    // Result-ready pulse (1 cycle)
    output reg        busy     // Generation in-progress flag
);

    // ---------------------------
    // Valid board range (inclusive) with explicit bit widths (Verilog-2001 friendly)
    // ---------------------------
    localparam [5:0] X_MIN  = MARGIN_CELLS;
    localparam [5:0] X_MAX  = H_CELLS - 1 - MARGIN_CELLS;
    localparam [5:0] Y_MIN  = MARGIN_CELLS;
    localparam [5:0] Y_MAX  = V_CELLS - 1 - MARGIN_CELLS;

    localparam [5:0] X_SPAN = X_MAX - X_MIN + 6'd1;   // 40 - 2*margin
    localparam [5:0] Y_SPAN = Y_MAX - Y_MIN + 6'd1;   // 30 - 2*margin

    // 8-bit local copies to avoid width/sign issues when comparing/counting
    localparam [7:0] TRIES8    = TRIES;
    localparam [7:0] MIN_DIST8 = MIN_DIST;

    // ---------------------------
    // PRNG
    // ---------------------------
    wire [15:0] rnd;
    lfsr16 u_lfsr(.clk(clk), .resetn(resetn), .rnd(rnd));

    // Candidate extraction (rejection sampling: accept only when rx<X_SPAN and ry<Y_SPAN)
    wire [5:0] rx = rnd[5:0];      // 0..63
    wire [5:0] ry = rnd[11:6];     // 0..63

    wire       valid_x = (rx < X_SPAN);
    wire       valid_y = (ry < Y_SPAN);

    wire [5:0] cand_x  = X_MIN + rx;   // Map into valid region
    wire [5:0] cand_y  = Y_MIN + ry;

    // Manhattan distance relative to the snake head (pure add/sub operations)
    wire [5:0] dx = (cand_x > snake_x_cell) ? (cand_x - snake_x_cell)
                                            : (snake_x_cell - cand_x);
    wire [5:0] dy = (cand_y > snake_y_cell) ? (cand_y - snake_y_cell)
                                            : (snake_y_cell - cand_y);
    wire [7:0] manhattan = dx + dy;     // Max is about 69, so 8 bits are enough

    // Filter conditions
    wire overlap_head = (cand_x == snake_x_cell) && (cand_y == snake_y_cell);
    wire far_enough   = (manhattan >= MIN_DIST8);

    // ---------------------------
    // Corner fallback (all corners lie within the valid range)
    // ---------------------------
    wire [5:0] c0x = X_MIN, c0y = Y_MIN;
    wire [5:0] c1x = X_MAX, c1y = Y_MIN;
    wire [5:0] c2x = X_MIN, c2y = Y_MAX;
    wire [5:0] c3x = X_MAX, c3y = Y_MAX;

    // Manhattan distance from each corner to the snake head
    wire [7:0] d0 = ((c0x>snake_x_cell)?(c0x-snake_x_cell):(snake_x_cell-c0x))
                  + ((c0y>snake_y_cell)?(c0y-snake_y_cell):(snake_y_cell-c0y));
    wire [7:0] d1 = ((c1x>snake_x_cell)?(c1x-snake_x_cell):(snake_x_cell-c1x))
                  + ((c1y>snake_y_cell)?(c1y-snake_y_cell):(snake_y_cell-c1y));
    wire [7:0] d2 = ((c2x>snake_x_cell)?(c2x-snake_x_cell):(snake_x_cell-c2x))
                  + ((c2y>snake_y_cell)?(c2y-snake_y_cell):(snake_y_cell-c2y));
    wire [7:0] d3 = ((c3x>snake_x_cell)?(c3x-snake_x_cell):(snake_x_cell-c3x))
                  + ((c3y>snake_y_cell)?(c3y-snake_y_cell):(snake_y_cell-c3y));

    // Combinational logic to pick the farthest corner
    reg [5:0] fb_x, fb_y; reg [7:0] fb_d;
    always @* begin
        fb_x = c0x; fb_y = c0y; fb_d = d0;
        if (d1 > fb_d) begin fb_x = c1x; fb_y = c1y; fb_d = d1; end
        if (d2 > fb_d) begin fb_x = c2x; fb_y = c2y; fb_d = d2; end
        if (d3 > fb_d) begin fb_x = c3x; fb_y = c3y; fb_d = d3; end
    end

    // ---------------------------
    // FSM
    // ---------------------------
    localparam S_IDLE = 2'd0, S_GEN = 2'd1, S_DONE = 2'd2;
    reg [1:0] state;

    reg        found_any;             // Whether at least one valid candidate was found this round
    reg [7:0]  best_dist;             // Current best distance
    reg [5:0]  best_x, best_y;        // Current best coordinates
    reg [7:0]  tries_left;            // Remaining attempts (decremented every cycle)

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state         <= S_IDLE;
            done          <= 1'b0;
            busy          <= 1'b0;

            fruit_x_cell  <= X_MIN;
            fruit_y_cell  <= Y_MIN;

            found_any     <= 1'b0;
            best_dist     <= 8'd0;
            best_x        <= X_MIN;
            best_y        <= Y_MIN;
            tries_left    <= 8'd0;
        end else begin
            case (state)
                // --------------------------
                // Idle: wait for a trigger
                // --------------------------
                S_IDLE: begin
                    done <= 1'b0;
                    if (request) begin
                        busy       <= 1'b1;
                        found_any  <= 1'b0;
                        best_dist  <= 8'd0;
                        best_x     <= X_MIN;
                        best_y     <= Y_MIN;
                        tries_left <= TRIES8;   // e.g., 16 attempts
                        state      <= S_GEN;
                    end
                end

                // --------------------------
                // Generation: try one candidate per cycle (counter always decrements)
                // --------------------------
                S_GEN: begin
                    // 1) Early exit when the counter hits zero to maintain exact attempt count
                    if (tries_left == 0) begin
                        // Fall back to the farthest corner if no valid candidate was found
                        fruit_x_cell <= found_any ? best_x : fb_x;
                        fruit_y_cell <= found_any ? best_y : fb_y;
                        busy         <= 1'b0;
                        state        <= S_DONE;
                    end else begin
                        // 2) Consume one attempt
                        tries_left <= tries_left - 8'd1;

                        // 3) Apply filters and update the best candidate
                        if (valid_x && valid_y && !overlap_head && far_enough) begin
                            if (manhattan >= best_dist) begin
                                best_dist <= manhattan;
                                best_x    <= cand_x;
                                best_y    <= cand_y;
                            end
                            found_any <= 1'b1;
                        end
                        // The LFSR supplies a new random number on the next clock
                    end
                end

                // --------------------------
                // Done: emit one-cycle done pulse
                // --------------------------
                S_DONE: begin
                    done  <= 1'b1;    // One-cycle pulse
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule
