// ===========================================================
// Module: snake_head
// Description:
//   控制蛇头位置（以网格坐标表示）。
//   当前版本：蛇头固定在 (5,5)，后续可扩展为移动逻辑。
// ===========================================================

module snake_head (
    input  wire        clk,       // 系统时钟 (CLOCK_50)
    input  wire        resetn,    // 低电平复位
    output reg  [9:0]  x_cell,    // 当前蛇头X坐标 (cell)
    output reg  [9:0]  y_cell     // 当前蛇头Y坐标 (cell)
);

    // =======================================================
    // 局部参数定义（仅供未来逻辑扩展使用）
    // =======================================================
    localparam H_RES     = 640;   // 水平分辨率
    localparam V_RES     = 480;   // 垂直分辨率
    localparam CELL_PX   = 16;    // 每个 cell 16x16 像素
    localparam GRID_W    = H_RES / CELL_PX;  // 40
    localparam GRID_H    = V_RES / CELL_PX;  // 30
    localparam X0_OFFSET = 0;
    localparam Y0_OFFSET = 0;

    // =======================================================
    // 蛇头位置寄存器逻辑
    // =======================================================
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            x_cell <= 10'd5;  // 第6列
            y_cell <= 10'd5;  // 第6行
        end else begin
            // 暂时固定位置（后续可扩展移动逻辑）
            x_cell <= 10'd5;
            y_cell <= 10'd5;
        end
    end

endmodule
