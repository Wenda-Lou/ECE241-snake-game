// ===========================================================
// Module: game
// Description:
//   top-level: PS/2 keyboard -> dir, then into vga_top
//   which handles snake_engine + fruit + VGA drawing.
// ===========================================================
module game (
    input  wire        CLOCK_50,   // 50 MHz system clock
    input  wire [3:0]  KEY,        // KEY[0] used as active-low reset

    inout  wire        PS2_CLK,    // PS/2 clock (open-drain on board)
    inout  wire        PS2_DAT,    // PS/2 data  (open-drain on board)
	 
    output wire [6:0]  HEX4,       // ones digit
    output wire [6:0]  HEX5,       // tens digit
	 

    // VGA signals to DE1-SoC connector
    output wire [7:0]  VGA_R,
    output wire [7:0]  VGA_G,
    output wire [7:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire        VGA_BLANK_N,
    output wire        VGA_SYNC_N,
    output wire        VGA_CLK
);

    // Reset
    wire resetn = KEY[0];  // active-low reset from push button

    // PS/2 Keyboard Receive
    // Raw byte stream from keyboard
    wire [7:0] ps2_rx_data;
    wire       ps2_rx_ready;
	 wire frame_err;

    // make sure this matches your ps2_rx.v port list.
    ps2_rx u_ps2_rx (
        .clk      (CLOCK_50),
        .rst_n  (resetn),
        .ps2_clk  (PS2_CLK),
        .ps2_dat (PS2_DAT),
        .data_out  (ps2_rx_data),
        .data_ready (ps2_rx_ready),
		  .frame_err (frame_err)
    );

    // PS/2 Scancode Decoder
    wire up, dn, lt, rt;
	 

    // Again, adapt port names if your ps2_scancode is slightly different.
    ps2_scancode u_ps2_sc (
        .clk      (CLOCK_50),
        .rst_n  (resetn),
        .data_ready (ps2_rx_ready),
        .data_in  (ps2_rx_data),
        .up_make (up),
		  .down_make (dn),
		  .left_make (lt),
		  .right_make (rt)
    );


    // Scancode -> Snake Direction (2 bits)
    // dir encoding (as we’ve been using):
    //   2'b01 : left   (X--)
    //   2'b00 : right  (X++)
    //   2'b10 : up     (Y--)
    //   2'b11 : down   (Y++)
    wire [1:0] dir;

    snake_dir u_snake_dir (
        .clk     (CLOCK_50),
        .rst_n (resetn),
        .up_pulse (up),
		  .down_pulse (dn),
		  .left_pulse (lt),
		  .right_pulse (rt),
        .dir     (dir)
    );
	 

	
	 wire score_inc;
	 
	 
    // VGA + Snake Game Core
    // vga_top does:
    //   - game_tick (1 Hz) inside
    //   - snake_engine (movement, growth, self-collision)
    //   - fruit_placer
    //   - grid_mapper + painter
    //   - vga_adapter
    //
    // feed it CLOCK_50, reset, and dir.
    vga_top u_vga_top (
        .CLOCK_50   (CLOCK_50),
        .KEY        ({1'b0, resetn}),  // KEY[1:0] for vga_top: {unused, resetn}
        .dir        (dir),
		  .score_inc  (score_inc),
        .VGA_R      (VGA_R),
        .VGA_G      (VGA_G),
        .VGA_B      (VGA_B),
        .VGA_HS     (VGA_HS),
        .VGA_VS     (VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N (VGA_SYNC_N),
        .VGA_CLK    (VGA_CLK)
    );
	 
	 score_display u_score_display (
        .clk       (CLOCK_50),
        .resetn    (resetn),
        .score_inc (score_inc),
        .HEX_TENS  (HEX5),  // tens digit
        .HEX_ONES  (HEX4)   // ones digit
    );

endmodule
