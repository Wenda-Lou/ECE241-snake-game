module top_snake_input(
    input  wire clk,        // e.g., 50 MHz
    input  wire rst_n,
    input  wire ps2_clk,
    input  wire ps2_dat,
    output wire [1:0] dir   // feed to snake engine
);
    wire byte_rdy;
    wire [7:0] byte_data;
    wire up_mk, dn_mk, lt_mk, rt_mk;

    ps2_rx #(.CLK_HZ(50_000_000)) u_rx (
        .clk(clk), .rst_n(rst_n),
        .ps2_clk(ps2_clk), .ps2_dat(ps2_dat),
        .data_ready(byte_rdy),
        .data_out(byte_data),
        .frame_err() // optional: monitor/debug
    );

    ps2_scancode u_dec (
        .clk(clk), .rst_n(rst_n),
        .data_ready(byte_rdy), .data_in(byte_data),
        .up_make(up_mk), .down_make(dn_mk),
        .left_make(lt_mk), .right_make(rt_mk)
    );

    snake_dir u_dir (
        .clk(clk), .rst_n(rst_n),
        .up_pulse(up_mk), .down_pulse(dn_mk),
        .left_pulse(lt_mk), .right_pulse(rt_mk),
        .dir(dir)
    );
endmodule