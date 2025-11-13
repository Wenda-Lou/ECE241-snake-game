// ===========================================================
// Module: vga_top
// Description:
//   顶层：蛇头、网格映射、随机水果、绘制、VGA 适配器（同一 50MHz 时钟域）。
// ===========================================================
module vga_top(
    input  wire CLOCK_50,
    input  wire [1:0] KEY,  // KEY[0] = resetn
    output wire [7:0] VGA_R,
    output wire [7:0] VGA_G,
    output wire [7:0] VGA_B,
    output wire       VGA_HS,
    output wire       VGA_VS,
    output wire       VGA_BLANK_N,
    output wire       VGA_SYNC_N,
    output wire       VGA_CLK
);
    // 基本参数
    localparam H_RES     = 640;
    localparam V_RES     = 480;
    localparam CELL_PX   = 16;
    localparam GRID_W    = H_RES / CELL_PX;  // 40
    localparam GRID_H    = V_RES / CELL_PX;  // 30
    localparam X0_OFFSET = 0;
    localparam Y0_OFFSET = 0;

    wire resetn = KEY[0];

    // （仿真/检查用）当未来把网格放大到 >=64 时，请同时扩展 fruit_placer 端口位宽
    // initial begin
    //   if (GRID_W > 64 || GRID_H > 64) $error("Grid exceeds 6-bit range; widen fruit_placer ports.");
    // end

    // 蛇头 cell 坐标（snake_head 如为 [9:0] 输出，这里安全截断到 [5:0]。
    // 说明：当前 GRID_W=40, GRID_H=30，数值范围均 < 64，截断不会丢失有效位。）
    wire [9:0] x_cell, y_cell;
    snake_head u_snake_head (
        .clk    (CLOCK_50),
        .resetn (resetn),
        .x_cell (x_cell),
        .y_cell (y_cell)
    );
    wire [5:0] snake_x_cell6 = x_cell[5:0]; // ✅ 在 40x30 网格下安全
    wire [5:0] snake_y_cell6 = y_cell[5:0];

    // 随机水果（cell 坐标）
    wire [5:0] fruit_x_cell, fruit_y_cell;
    wire       fruit_done, fruit_busy;

    // 复位后请求一次生成（保持 1 直到 done）
    reg fruit_req;
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn)      fruit_req <= 1'b1;
        else if (fruit_done) fruit_req <= 1'b0;
    end

    fruit_placer #(
        .CELL_PX(16), .H_CELLS(40), .V_CELLS(30),
        .MARGIN_CELLS(1), .TRIES(16), .MIN_DIST(3)
    ) u_fruit (
        .clk          (CLOCK_50),
        .resetn       (resetn),
        .request      (fruit_req),
        .snake_x_cell (snake_x_cell6),
        .snake_y_cell (snake_y_cell6),
        .fruit_x_cell (fruit_x_cell),
        .fruit_y_cell (fruit_y_cell),
        .done         (fruit_done),
        .busy         (fruit_busy)
    );

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

    // VGA 适配器（如你的 IP 端口名为 .colour/.plot，请相应改回）
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