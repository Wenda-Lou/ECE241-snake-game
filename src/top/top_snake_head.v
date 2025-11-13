module top_snake_test (
    // Clock and Reset (Verilog-2001 style port declaration)
    input  wire CLOCK_50,    // 50 MHz input clock (User specified: CLOCK_50)
    input  wire [3:0]KEY,        // Active-Low Reset (User specified: KEY[0])

    // PS/2 Keyboard Input
    input  wire PS2_CLK,     // PS/2 Clock pin
    inout  wire PS2_DAT,     // PS/2 Data pin

    // 7-Segment Display Outputs (Active-Low)
    output wire [6:0] HEX0,  // Display 0 (LSD of Y)
    output wire [6:0] HEX1,  // Display 1
    output wire [6:0] HEX2,  // Display 2 (LSD of X)
    output wire [6:0] HEX3   // Display 3
);

    wire system_clk = CLOCK_50;
    // Active-Low reset: 0 = Reset, 1 = Run
    wire system_rst_n = KEY[0];

    // Clock Enable for 1 Hz Movement
    // 50MHz / 2 = 25,000,000 cycles for 0.5s.
    localparam CLK_MAX = 25_000_000 - 1; 
    reg [24:0] clk_counter;
    reg move_en;
    always @(posedge system_clk or negedge system_rst_n) begin
        if (!system_rst_n) begin
            clk_counter <= 25'd0;
            move_en     <= 1'b0;
        end else begin
            if (clk_counter == CLK_MAX) begin
                clk_counter <= 25'd0;
                move_en     <= 1'b1; // Pulse high for one cycle
            end else begin
                clk_counter <= clk_counter + 25'b1;
                move_en     <= 1'b0;
            end
        end
    end

    // PS/2 Keyboard Input Wires
    wire [7:0] ps2_data_in;
    wire ps2_data_ready;
    wire ps2_frame_err;

    wire up_make, down_make, left_make, right_make; // Key press pulses
    wire [1:0] dir; // Snake direction output

    // Instantiate PS2 Receiver Module
    ps2_rx #(.CLK_HZ(50_000_000)) ps2_rx_inst (
        .clk(system_clk),
        .rst_n(system_rst_n),
        .ps2_clk(PS2_CLK),
        .ps2_dat(PS2_DAT),
        .data_ready(ps2_data_ready),
        .data_out(ps2_data_in),
        .frame_err(ps2_frame_err)
    );

    // Instantiate PS2 Scancode Decoder Module
    ps2_scancode ps2_scancode_inst (
        .clk(system_clk),
        .rst_n(system_rst_n),
        .data_ready(ps2_data_ready),
        .data_in(ps2_data_in),
        .up_make(up_make),
        .down_make(down_make),
        .left_make(left_make),
        .right_make(right_make)
    );

    // Instantiate Snake Direction Logic Module
    snake_dir snake_dir_inst (
        .clk(system_clk),
        .rst_n(system_rst_n),
        .up_pulse(up_make),
        .down_pulse(down_make),
        .left_pulse(left_make),
        .right_pulse(right_make),
        .dir(dir)
    );

    // Snake Movement Engine
    wire movement_clk;
    assign movement_clk = move_en ? system_clk : 1'b0;  // = system_clk if move_en true, otherwise 0

    wire [7:0] snake_head_x_reg;
    wire [7:0] snake_head_y_reg;
    wire game_over;

    // Instantiate Snake Engine Module (from snake_head.v)
    snake_engine snake_engine_inst (
        .clk(movement_clk), // 1Hz movement clock
        .rst_n(system_rst_n),
        .dir(dir),
        .snake_head_x(snake_head_x_reg),
        .snake_head_y(snake_head_y_reg),
        .game_over(game_over)
    );

    // Seven-Segment Display (SSD) Logic
    // HEX3 HEX2 (X) . HEX1 HEX0 (Y)

    // BCD conversion for X (0-39)
    wire [3:0] x_tens, x_ones;
    assign x_tens = snake_head_x_reg / 8'd10;
    assign x_ones = snake_head_x_reg % 8'd10;

    // BCD conversion for Y (0-29)
    wire [3:0] y_tens, y_ones;
    assign y_tens = snake_head_y_reg / 8'd10;
    assign y_ones = snake_head_y_reg % 8'd10;

    // Digit Assignments
    wire [3:0] hex_digit_3 = x_tens; // X Ten's Place
    wire [3:0] hex_digit_2 = x_ones; // X One's Place
    wire [3:0] hex_digit_1 = y_tens; // Y Ten's Place
    wire [3:0] hex_digit_0 = y_ones; // Y One's Place

    // 7-Segment Decoder Module Outputs
    wire [6:0] hex_out_3, hex_out_2, hex_out_1, hex_out_0;

    // Instance the decoder (defined below)
    seven_seg_decoder decoder_3 (.bcd(hex_digit_3), .segments(hex_out_3));
    seven_seg_decoder decoder_2 (.bcd(hex_digit_2), .segments(hex_out_2));
    seven_seg_decoder decoder_1 (.bcd(hex_digit_1), .segments(hex_out_1));
    seven_seg_decoder decoder_0 (.bcd(hex_digit_0), .segments(hex_out_0));

    // Final output connections
    assign HEX3 = hex_out_3;
    assign HEX2 = hex_out_2;
    assign HEX1 = hex_out_1;
    assign HEX0 = hex_out_0;

endmodule

// 5. Seven-Segment Decoder Definition 

module seven_seg_decoder (
    input  wire [3:0] bcd,
    output wire [6:0] segments 
);

    // Active-Low patterns 
    reg [6:0] seg_val;

    always @(*) begin
        case (bcd)
            4'd0: seg_val = 7'b1000000; // 0
            4'd1: seg_val = 7'b1111001; // 1
            4'd2: seg_val = 7'b0100100; // 2
            4'd3: seg_val = 7'b0110000; // 3
            4'd4: seg_val = 7'b0011001; // 4
            4'd5: seg_val = 7'b0010010; // 5
            4'd6: seg_val = 7'b0000010; // 6
            4'd7: seg_val = 7'b1111000; // 7
            4'd8: seg_val = 7'b0000000; // 8
            4'd9: seg_val = 7'b0010000; // 9
            default: seg_val = 7'b1111111; // Blank
        endcase
    end

    assign segments = seg_val;

endmodule