
// ===========================================================
// Module: top_snake_fpga
// Description:
//   最终的顶层模块，整合了 PS/2 键盘输入、游戏逻辑和 VGA 显示。
// ===========================================================
module top_snake_fpga (
    // 全局接口
    input  wire        CLOCK_50,     // 50 MHz board clock
    input  wire [3:0]  KEY,          // KEY[0] = active-LOW reset button
    
    // PS/2 接口
    inout  wire        PS2_CLK,      // PS/2 Clock
    inout  wire        PS2_DAT,      // PS/2 Data
    
    // VGA 接口
    output wire [7:0]  VGA_R,
    output wire [7:0]  VGA_G,
    output wire [7:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire        VGA_BLANK_N,
    output wire        VGA_SYNC_N,
    output wire        VGA_CLK,

    // 调试用 LED
    output wire [9:0]  LEDR
);

    // -------------------------------------------------------
    // 信号定义
    // -------------------------------------------------------
    
    // 复位信号 (同步处理，低电平有效)
    reg [1:0] rst_sync;
    always @(posedge CLOCK_50) rst_sync <= {rst_sync[0], KEY[0]};
    wire resetn = rst_sync[1];

    // PS/2 模块信号
    wire [7:0] scancode;
    wire       scancode_ready;
    
    // 方向译码器信号
    wire [1:0] dir;
    
    // 游戏节拍信号
    wire move_tick;

    // -------------------------------------------------------
    // 1. PS/2 键盘输入 -> 方向信号 (dir)
    // -------------------------------------------------------

    // PS/2 接收器
    ps2_rx u_ps2_rx (
        .clk      (CLOCK_50),
        .rst_n    (resetn),
        .ps2_clk  (PS2_CLK),
        .ps2_dat  (PS2_DAT),
        .data_ready(scancode_ready),
        .data_out (scancode),
        .frame_err()
    );

    // 方向译码器
    direction_decoder u_dir_decoder (
        .clk            (CLOCK_50),
        .resetn         (resetn),
        .scancode       (scancode),
        .scancode_ready (scancode_ready),
        .dir            (dir)
    );

    // -------------------------------------------------------
    // 2. 游戏节拍生成
    // -------------------------------------------------------
    game_tick #(
        .INPUT_CLK_FREQ(50_000_000),
        .TICK_FREQ     (4)          // 蛇每秒移动 4 格
    ) u_game_tick (
        .clk    (CLOCK_50),
        .resetn (resetn),
        .tick   (move_tick)
    );

    // -------------------------------------------------------
    // 3. VGA 显示核心
    // -------------------------------------------------------
    vga_top u_vga_top (
        .CLOCK_50    (CLOCK_50),
        .KEY         ({1'b1, resetn}), // vga_top 只用到了 KEY[0] 作为 resetn
        .dir         (dir),
        .move_tick   (move_tick),
        .VGA_R       (VGA_R),
        .VGA_G       (VGA_G),
        .VGA_B       (VGA_B),
        .VGA_HS      (VGA_HS),
        .VGA_VS      (VGA_VS),
        .VGA_BLANK_N (VGA_BLANK_N),
        .VGA_SYNC_N  (VGA_SYNC_N),
        .VGA_CLK     (VGA_CLK)
    );

    // -------------------------------------------------------
    // 4. 调试用 LED
    // -------------------------------------------------------
    assign LEDR[1:0] = dir;       // 显示当前方向
    assign LEDR[2]   = move_tick; // 移动时闪烁
    assign LEDR[9:3] = 7'b0;      // 未使用

endmodule
