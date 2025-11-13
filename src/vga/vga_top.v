// ===========================================================
// Module: vga_top
// Description:
//   顶层：蛇头、网格映射、随机水果、绘制、VGA 适配器。
//   接收外部的方向和移动节拍来控制蛇头。
// ===========================================================
module vga_top(
    input  wire        CLOCK_50,
    input  wire [1:0]  KEY,        // KEY[0] = resetn
    input  wire [1:0]  dir,        // 新增：键盘方向
    input  wire        move_tick,  // 新增：移动脉冲
    output wire [7:0]  VGA_R,
    output wire [7:0]  VGA_G,
    output wire [7:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire        VGA_BLANK_N,
    output wire        VGA_SYNC_N,
    output wire        VGA_CLK
);
    // 基本参数
    localparam H_RES     = 640;
    localparam V_RES     = 480;
    localparam CELL_PX   = 16;
    localparam GRID_W    = H_RES / CELL_PX;  // 40
    localparam GRID_H    = V_RES / CELL_PX;  // 30

    wire resetn = KEY[0];

    // 蛇头 cell 坐标
    wire [9:0] x_cell, y_cell;
    snake_head_position u_snake_head (
        .clk       (CLOCK_50),
        .resetn    (resetn),
        .dir       (dir),        // 传递方向
        .move_tick (move_tick),  // 传递移动节拍
        .x_cell    (x_cell),
        .y_cell    (y_cell)
    );

    // 随机水果（cell 坐标）
    // 为了简化当前目标，暂时禁用随机水果逻辑
    wire [5:0] fruit_x_cell = 6'd20; // 固定水果位置
    wire [5:0] fruit_y_cell = 6'd15;

    // cell → 像素中心（*16 + 8）
    wire [9:0] fruit_cx = {fruit_x_cell, 4'b0000} + 10'd8;
    wire [9:0] fruit_cy = {fruit_y_cell, 4'b0000} + 10'd8;

    // 网格映射：蛇头 cell → 像素区间
    wire [9:0] x_min_px, x_max_px;
    wire [9:0] y_min_px, y_max_px;
    grid_mapper u_mapper (
        .x_cell   (x_cell),
        .y_cell   (y_cell),
        .x_min_px (x_min_px),
        .x_max_px (x_max_px),
        .y_min_px (y_min_px),
        .y_max_px (y_max_px)
    );

    // 绘制模块
    wire [9:0] x;
    wire [9:0] y;
    wire [2:0] color_3b;
    wire       write_stb;
    wire       busy;

    // 3-bit → 9-bit (RRR GGG BBB)
    wire [8:0] color_9b = { {3{color_3b[2]}}, {3{color_3b[1]}}, {3{color_3b[0]}} };

    painter u_painter (
        .clk       (CLOCK_50),
        .resetn    (resetn),
        .x_min_px  (x_min_px),
        .x_max_px  (x_max_px),
        .y_min_px  (y_min_px),
        .y_max_px  (y_max_px),
        .fruit_cx  (fruit_cx),
        .fruit_cy  (fruit_cy),
        .x         (x),
        .y         (y),
        .colour    (color_3b),
        .plot      (write_stb),
        .busy      (busy)
    );

    // VGA 适配器
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
