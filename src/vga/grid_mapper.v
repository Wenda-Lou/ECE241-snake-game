// ===========================================================
// Module: grid_mapper
// Description:
//   将蛇头的网格坐标 (x_cell, y_cell)
//   映射为 VGA 像素坐标范围 (x_min_px, x_max_px, y_min_px, y_max_px)
//   每个 cell 占据 16×16 个像素。
// ===========================================================

module grid_mapper (
    input  wire [9:0] x_cell,   // 格子坐标 X (0~39)
    input  wire [9:0] y_cell,   // 格子坐标 Y (0~29)
    output wire [9:0] x_min_px, // 对应像素左边界
    output wire [9:0] x_max_px, // 对应像素右边界
    output wire [9:0] y_min_px, // 对应像素上边界
    output wire [9:0] y_max_px  // 对应像素下边界
);

    // =======================================================
    // 局部参数定义（替代 .vh 文件）
    // =======================================================
    localparam CELL_PX   = 16;   // 每个 cell 16×16 像素
    localparam X0_OFFSET = 0;    // 屏幕左侧偏移
    localparam Y0_OFFSET = 0;    // 屏幕上侧偏移

    // =======================================================
    // 坐标映射逻辑
    // =======================================================
    assign x_min_px = X0_OFFSET + x_cell * CELL_PX;
    assign x_max_px = x_min_px + CELL_PX - 1;

    assign y_min_px = Y0_OFFSET + y_cell * CELL_PX;
    assign y_max_px = y_min_px + CELL_PX - 1;

endmodule
