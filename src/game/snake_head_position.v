// ===========================================================
// Module: snake_head_position
// Description:
//   控制蛇头位置（以网格坐标表示）。
//   根据外部的方向(dir)和移动节拍(move_tick)来更新坐标。
// ===========================================================

module snake_head_position (
    input  wire        clk,       // 系统时钟 (CLOCK_50)
    input  wire        resetn,    // 低电平复位
    input  wire [1:0]  dir,       // 移动方向 (00=上, 01=下, 10=左, 11=右)
    input  wire        move_tick, // 移动节拍脉冲
    output reg  [9:0]  x_cell,    // 当前蛇头X坐标 (cell)
    output reg  [9:0]  y_cell     // 当前蛇头Y坐标 (cell)
);

    // =======================================================
    // 局部参数定义
    // =======================================================
    localparam H_RES     = 640;   // 水平分辨率
    localparam V_RES     = 480;   // 垂直分辨率
    localparam CELL_PX   = 16;    // 每个 cell 16x16 像素
    localparam GRID_W    = H_RES / CELL_PX;  // 40
    localparam GRID_H    = V_RES / CELL_PX;  // 30

    localparam DIR_UP    = 2'b00;
    localparam DIR_DOWN  = 2'b01;
    localparam DIR_LEFT  = 2'b10;
    localparam DIR_RIGHT = 2'b11;

    reg [1:0] last_dir; // 存储上一次的有效移动方向

    // =======================================================
    // 蛇头位置寄存器逻辑
    // =======================================================
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            x_cell   <= 10'd10; // 初始位置 X=10
            y_cell   <= 10'd10; // 初始位置 Y=10
            last_dir <= DIR_RIGHT; // 初始方向向右
        end else begin
            // 每当接收到移动节拍脉冲时，更新一次位置
            if (move_tick) begin
                // 避免180度掉头: 如果新方向不是当前方向的反方向，则更新 last_dir
                // (dir[0] != last_dir[0]) 检查是否在不同轴上 (上下 vs 左右)
                // (dir == last_dir) 检查是否是相同方向
                if ((dir[1] != last_dir[1]) || (dir == last_dir)) begin
                    last_dir <= dir;
                end

                // 根据（可能已更新的）last_dir 来计算下一个位置
                case (last_dir)
                    DIR_UP:    if (y_cell > 0)            y_cell <= y_cell - 1;
                    DIR_DOWN:  if (y_cell < GRID_H - 1)   y_cell <= y_cell + 1;
                    DIR_LEFT:  if (x_cell > 0)            x_cell <= x_cell - 1;
                    DIR_RIGHT: if (x_cell < GRID_W - 1)   x_cell <= x_cell + 1;
                    default:   /* do nothing */ ;
                endcase
            end
        end
    end

endmodule
