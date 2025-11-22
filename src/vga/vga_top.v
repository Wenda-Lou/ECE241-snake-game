// Module: vga_top
// Description: Snake engine + fruit + painter + VGA adapter
module vga_top(
    input  wire CLOCK_50,
    input  wire [1:0] KEY,  // KEY[0] = resetn
    input  wire [1:0] dir,
	 input  wire game_started,
	 output wire score_inc,
    output wire [7:0] VGA_R,
    output wire [7:0] VGA_G,
    output wire [7:0] VGA_B,
    output wire       VGA_HS,
    output wire       VGA_VS,
    output wire       VGA_BLANK_N,
    output wire       VGA_SYNC_N,
    output wire       VGA_CLK
);

    wire resetn = KEY[0];

    // Grid dimensions (cells)
    localparam integer H_CELLS = 40;
    localparam integer V_CELLS = 30;

    // Fruit position in cells (shared between snake_engine and fruit_placer)
    wire [5:0] fruit_x_cell, fruit_y_cell;

    // 1 Hz movement tick
    wire base_tick;
	wire snake_step;

    game_tick #(
        .INPUT_CLK_FREQ(50_000_000),
        .TICK_FREQ     (8)
    ) u_move_tick (
        .clk    (CLOCK_50),
        .resetn (resetn),
        .tick   (base_tick)
    );


    // 30 FPS frame tick
    wire frame_tick;
    frame_tick #(
        .INPUT_CLK_FREQ(50_000_000),
        .FRAME_RATE(30)       // 30 FPS
    ) u_frame_tick (
        .clk(CLOCK_50),
        .resetn(resetn),
        .tick(frame_tick)
    );


    // Snake Engine
    wire [5:0] snake_x_cell6, snake_y_cell6;
    wire [7:0] snake_len;
    wire       ate_fruit;
    wire       game_over;

    // Helper signals for occupancy (new head / old tail)
    wire [5:0] new_head_x_cell, new_head_y_cell;
    wire       new_head_valid;
    wire [5:0] old_tail_x_cell, old_tail_y_cell;
    wire       old_tail_valid;

    snake_engine #(
        .H_CELLS(H_CELLS),
        .V_CELLS(V_CELLS),
        .MAX_LEN(64)
    ) u_snake (
        .clk                (CLOCK_50),
        .rst_n              (resetn),
        .step               (game_started ? snake_step : 1'b0),
        .dir                (dir),
        .fruit_x_cell       (fruit_x_cell),
        .fruit_y_cell       (fruit_y_cell),
        .snake_head_x_cell  (snake_x_cell6),
        .snake_head_y_cell  (snake_y_cell6),
        .game_over          (game_over),
        .ate_fruit          (ate_fruit),
        .snake_len          (snake_len),
        .new_head_x_cell    (new_head_x_cell),
        .new_head_y_cell    (new_head_y_cell),
        .new_head_valid     (new_head_valid),
        .old_tail_x_cell    (old_tail_x_cell),
        .old_tail_y_cell    (old_tail_y_cell),
        .old_tail_valid     (old_tail_valid)
    );
	 
	 assign score_inc = ate_fruit;
	 
	 

	 // Fruit counter for speed upgrades
	 reg [7:0] fruit_count;
	 reg [1:0] speed_level;
		
	 always @(posedge CLOCK_50 or negedge resetn) begin
			 if (!resetn)
				  fruit_count <= 8'd0;
			 else if (ate_fruit && fruit_count != 8'hFF)
				  fruit_count <= fruit_count + 8'd1;
	 end
		
	// Speed level from fruit_count
	//   L0: 0.5 s   (8 Hz / 4)
	//   L1: 0.25 s  (8 Hz / 2)
	//   L2+: 0.125 s (8 Hz / 1)
	
	always @* begin
		 if      (fruit_count < 8'd5)   speed_level = 2'd0; // 0..4 fruits
		 else if (fruit_count < 8'd10)  speed_level = 2'd1; // 5..9
		 else                            speed_level = 2'd2; // 10+ (fastest)
	end
	
	// Map level -> divide-by-N of 8 Hz base tick
	reg [2:0] every_n;  // valid values: 4,2,1
	always @* begin
		 case (speed_level)
			  2'd0: every_n = 3'd4; // 0.5 s
			  2'd1: every_n = 3'd2; // 0.25 s
			  default: every_n = 3'd1; // 0.125 s
		 endcase
	end
	
	// ONE clean 1-clk snake_step pulse every 'every_n' base ticks
	reg [2:0] tick_ctr;
	reg       snake_step_reg;
	
	assign snake_step = snake_step_reg;
	
	always @(posedge CLOCK_50 or negedge resetn) begin
		 if (!resetn) begin
			  tick_ctr       <= 3'd0;
			  snake_step_reg <= 1'b0;
		 end else begin
			  snake_step_reg <= 1'b0;  // default low (one-clock pulse)
			  if (base_tick) begin     // base_tick = 8 Hz (0.125 s)
					if (tick_ctr == every_n - 1) begin
						 tick_ctr       <= 3'd0;
						 snake_step_reg <= 1'b1;   // emit exactly one pulse
					end else begin
						 tick_ctr <= tick_ctr + 3'd1;
					end
			  end
		 end
	end



    // Fruit placer
    wire       fruit_done, fruit_busy;

    reg fruit_req;
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn)
            fruit_req <= 1'b1;
        else if (fruit_done)
            fruit_req <= 1'b0;
    end

    fruit_placer #(
        .CELL_PX      (16),
        .H_CELLS      (H_CELLS),
        .V_CELLS      (V_CELLS),
        .MARGIN_CELLS (1),
        .TRIES        (16),
        .MIN_DIST     (3)
    ) u_fruit (
        .clk          (CLOCK_50),
        .resetn       (resetn),
        .request      (ate_fruit || fruit_req),
        .snake_x_cell (snake_x_cell6),
        .snake_y_cell (snake_y_cell6),
        .fruit_x_cell (fruit_x_cell),
        .fruit_y_cell (fruit_y_cell),
        .done         (fruit_done),
        .busy         (fruit_busy)
    );

    // cell -> pixel (fruit center)
    wire [9:0] fruit_cx = {fruit_x_cell, 4'b0000} + 10'd8;
    wire [9:0] fruit_cy = {fruit_y_cell, 4'b0000} + 10'd8;

    // Snake occupancy bitmap (for full body draw)
    wire [H_CELLS*V_CELLS-1:0] snake_grid;

    snake_occupancy #(
        .H_CELLS(H_CELLS),
        .V_CELLS(V_CELLS)
    ) u_occ (
        .clk              (CLOCK_50),
        .resetn           (resetn),
        .new_head_x_cell  (new_head_x_cell),
        .new_head_y_cell  (new_head_y_cell),
        .new_head_valid   (new_head_valid),
        .old_tail_x_cell  (old_tail_x_cell),
        .old_tail_y_cell  (old_tail_y_cell),
        .old_tail_valid   (old_tail_valid),
        .grid             (snake_grid)
    );

    // Grid map for snake head (still available if needed)
    wire [9:0] x_min_px, x_max_px;
    wire [9:0] y_min_px, y_max_px;

    grid_mapper u_mapper (
        .x_cell   (snake_x_cell6),
        .y_cell   (snake_y_cell6),
        .x_min_px (x_min_px),
        .x_max_px (x_max_px),
        .y_min_px (y_min_px),
        .y_max_px (y_max_px)
    );


    // Painter refresh controller
    wire painter_busy;
    reg  start_frame;

    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn)
            start_frame <= 1'b1;                 // Draw the very first frame right after power-up
        else if (!painter_busy && frame_tick)    // Assert only when the painter is idle and the frame tick arrives
            start_frame <= 1'b1;
        else
            start_frame <= 1'b0;
    end

    // Painter
    wire [9:0] x;
    wire [9:0] y;
    wire [2:0] color_3b;
    wire       write_stb;

    painter u_painter (
        .clk                (CLOCK_50),
        .resetn             (resetn),

        .x_min_px           (x_min_px),
        .x_max_px           (x_max_px),
        .y_min_px           (y_min_px),
        .y_max_px           (y_max_px),

        .fruit_cx           (fruit_cx),
        .fruit_cy           (fruit_cy),

        .start              (start_frame),
        .game_over          (game_over),
		  .game_started         (game_started),
        .snake_dir          (dir),

        .snake_occ          (snake_grid),
        .snake_head_x_cell  (snake_x_cell6),
        .snake_head_y_cell  (snake_y_cell6),

        .x                  (x),
        .y                  (y),
        .colour             (color_3b),
        .plot               (write_stb),
        .busy               (painter_busy)
    );

    // 3-bit to 9-bit colour
    wire [8:0] color_9b = { {3{color_3b[2]}}, {3{color_3b[1]}}, {3{color_3b[0]}} };

    // VGA adapter
    vga_adapter VGA (
        .resetn      (resetn),
        .clock       (CLOCK_50),
        .color       (color_9b),
        .x           (x),
        .y           (y),
        .write       (write_stb),
        .VGA_R       (VGA_R),
        .VGA_G       (VGA_G),
        .VGA_B       (VGA_B),
        .VGA_HS      (VGA_HS),
        .VGA_VS      (VGA_VS),
        .VGA_BLANK_N (VGA_BLANK_N),
        .VGA_SYNC_N  (VGA_SYNC_N),
        .VGA_CLK     (VGA_CLK)
    );

    defparam VGA.RESOLUTION        = "640x480";
    defparam VGA.COLOR_DEPTH       = 9;
    defparam VGA.BACKGROUND_IMAGE  = "";

endmodule

