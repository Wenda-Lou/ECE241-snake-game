// Module: snake_occupancy
// Description:
//   Maintains a bitmap of which grid cells are occupied by the snake.
//   - grid[y * H_CELLS + x] = 1 means snake occupies cell (x, y)
//   - Updated incrementally using new head and old tail information.
//   - On reset, initializes to the same 3-segment snake as snake_engine.

module snake_occupancy #(
    parameter integer H_CELLS = 40,
    parameter integer V_CELLS = 30
)(
    input  wire                   clk,
    input  wire                   resetn,

    // New head position after a move (valid for both normal and growth moves)
    input  wire [5:0]             new_head_x_cell,
    input  wire [5:0]             new_head_y_cell,
    input  wire                   new_head_valid,

    // Old tail position before a normal (non-growth) move
    input  wire [5:0]             old_tail_x_cell,
    input  wire [5:0]             old_tail_y_cell,
    input  wire                   old_tail_valid,

    // Occupancy bitmap: 1 = occupied, 0 = empty
    output reg  [H_CELLS*V_CELLS-1:0] grid
);
    // Initial 3-segment snake, consistent with snake_engine reset:
    // head at (H_CELLS/2, V_CELLS/2), then two segments to the left.
    localparam integer INIT_HEAD_X = H_CELLS/2;
    localparam integer INIT_HEAD_Y = V_CELLS/2;
    localparam integer INIT_MID_X  = H_CELLS/2 - 1;
    localparam integer INIT_MID_Y  = V_CELLS/2;
    localparam integer INIT_TAIL_X = H_CELLS/2 - 2;
    localparam integer INIT_TAIL_Y = V_CELLS/2;

    localparam integer INIT_HEAD_IDX = INIT_HEAD_Y * H_CELLS + INIT_HEAD_X;
    localparam integer INIT_MID_IDX  = INIT_MID_Y  * H_CELLS + INIT_MID_X;
    localparam integer INIT_TAIL_IDX = INIT_TAIL_Y * H_CELLS + INIT_TAIL_X;

    wire [10:0] tail_index = old_tail_y_cell * H_CELLS + old_tail_x_cell;
    wire [10:0] head_index = new_head_y_cell * H_CELLS + new_head_x_cell;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            // Clear all cells
            grid <= {H_CELLS*V_CELLS{1'b0}};

            // Mark initial 3 segments as occupied
            grid[INIT_HEAD_IDX] <= 1'b1;
            grid[INIT_MID_IDX]  <= 1'b1;
            grid[INIT_TAIL_IDX] <= 1'b1;
        end else begin
            // Clear old tail cell on a normal move (no growth)
            if (old_tail_valid) begin
                grid[tail_index] <= 1'b0;
            end

            // Set new head cell on every move (normal or growth)
            if (new_head_valid) begin
                grid[head_index] <= 1'b1;
            end
        end
    end

endmodule
