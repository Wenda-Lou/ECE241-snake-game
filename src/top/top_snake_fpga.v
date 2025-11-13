
// top_de1soc_snake.v  
// Shows heartbeat, byte activity, arrow make pulses, and direction.
module top_snake_fpga
#(
    parameter integer CLK_HZ     = 50_000_000,
    parameter integer STRETCH_MS = 100
)
(
    input  wire        CLOCK_50,     // 50 MHz board clock
    input  wire [3:0]  KEY,          // KEY[0] = active-LOW reset button
    inout  wire        PS2_CLK,      // PS/2 mini-DIN (open-drain)
    inout  wire        PS2_DAT,      // PS/2 mini-DIN (open-drain)
    output wire [9:0]  LEDR          // LEDs 
);

    // Reset (sync KEY[0])
    reg [1:0] rst_sync;
    always @(posedge CLOCK_50) rst_sync <= {rst_sync[0], KEY[0]};
    wire rst_n = rst_sync[1];   // active-LOW reset inside design

    // PS/2 
    assign PS2_CLK = 1'bz;
    assign PS2_DAT = 1'bz;
    wire ps2_clk_i = PS2_CLK;
    wire ps2_dat_i = PS2_DAT;

    //Pipeline: RX -> decode -> dir 
    wire        byte_rdy;
    wire [7:0]  byte_data;
    wire        up_mk, dn_mk, lt_mk, rt_mk;
    wire [1:0]  dir;

    ps2_rx #(.CLK_HZ(CLK_HZ)) u_rx (
        .clk(CLOCK_50), .rst_n(rst_n),
        .ps2_clk(ps2_clk_i), .ps2_dat(ps2_dat_i),
        .data_ready(byte_rdy), .data_out(byte_data), .frame_err()
    );

    ps2_scancode u_sc (
        .clk(CLOCK_50), .rst_n(rst_n),
        .data_ready(byte_rdy), .data_in(byte_data),
        .up_make(up_mk), .down_make(dn_mk),
        .left_make(lt_mk), .right_make(rt_mk)
    );

    snake_dir u_dir (
        .clk(CLOCK_50), .rst_n(rst_n),
        .up_pulse(up_mk), .down_pulse(dn_mk),
        .left_pulse(lt_mk), .right_pulse(rt_mk),
        .dir(dir)
    );

    // LED pulse stretchers 
    wire up_led, rt_led, dn_led, lt_led, rdy_led;

    pulse_stretch #(.CLK_HZ(CLK_HZ), .MS(STRETCH_MS)) u_st_up (
        .clk(CLOCK_50), .rst_n(rst_n), .in_pulse(up_mk),   .out_level(up_led)
    );
    pulse_stretch #(.CLK_HZ(CLK_HZ), .MS(STRETCH_MS)) u_st_rt (
        .clk(CLOCK_50), .rst_n(rst_n), .in_pulse(rt_mk),   .out_level(rt_led)
    );
    pulse_stretch #(.CLK_HZ(CLK_HZ), .MS(STRETCH_MS)) u_st_dn (
        .clk(CLOCK_50), .rst_n(rst_n), .in_pulse(dn_mk),   .out_level(dn_led)
    );
    pulse_stretch #(.CLK_HZ(CLK_HZ), .MS(STRETCH_MS)) u_st_lt (
        .clk(CLOCK_50), .rst_n(rst_n), .in_pulse(lt_mk),   .out_level(lt_led)
    );
    pulse_stretch #(.CLK_HZ(CLK_HZ), .MS(40)) u_st_rdy ( // shorter
        .clk(CLOCK_50), .rst_n(rst_n), .in_pulse(byte_rdy), .out_level(rdy_led)
    );

    // Heartbeat (~1 Hz) 
    localparam integer HB_DIV = CLK_HZ/2;
    reg [31:0] hb_cnt; reg hb_bit;
    always @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            hb_cnt <= 32'd0; hb_bit <= 1'b0;
        end else if (hb_cnt == HB_DIV-1) begin
            hb_cnt <= 32'd0; hb_bit <= ~hb_bit;
        end else begin
            hb_cnt <= hb_cnt + 1'b1;
        end
    end

    // LEDs 
    assign LEDR[1:0] = dir;     // 00=UP, 01=RIGHT, 10=DOWN, 11=LEFT
    assign LEDR[2]   = up_led;
    assign LEDR[3]   = rt_led;
    assign LEDR[4]   = dn_led;
    assign LEDR[5]   = lt_led;
    assign LEDR[6]   = rdy_led; // data_ready activity
    assign LEDR[7]   = hb_bit;  // heartbeat
    assign LEDR[9:8] = 2'b00;   // unused

endmodule


// Pulse stretcher: widen a 1-cycle pulse to MS milliseconds
module pulse_stretch
#(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer MS     = 100
)
(
    input  wire clk,
    input  wire rst_n,       // active-LOW
    input  wire in_pulse,    // 1-cycle pulse
    output reg  out_level    // MS-long level
);
    localparam integer TICKS = (CLK_HZ/1000)*MS;

    // clog2 counter
    function integer clog2; input integer v; integer i; begin
        i=0; while ((1<<i) < v) i=i+1; clog2=i;
    end endfunction
    localparam integer W = (TICKS>1) ? clog2(TICKS) : 1;

    reg [W-1:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= {W{1'b0}}; out_level <= 1'b0;
        end else begin
            if (in_pulse) begin
                cnt       <= TICKS[W-1:0];
                out_level <= 1'b1;
            end else if (cnt != {W{1'b0}}) begin
                cnt       <= cnt - 1'b1;
                out_level <= 1'b1;
            end else begin
                out_level <= 1'b0;
            end
        end
    end
endmodule
