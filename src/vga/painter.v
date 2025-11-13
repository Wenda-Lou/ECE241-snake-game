// ===========================================================
// Module: painter
// Description:
//   初始化背景（黑色+白色边框）+ 绘制红色水果 + 绘制绿色蛇头。
//   水果中心由顶层传入（像素坐标），半径固定为 6（常量平方，避免额外乘法器）。
// ===========================================================
module painter(
    input  wire        clk,
    input  wire        resetn,
    // 蛇头像素范围
    input  wire [9:0]  x_min_px,
    input  wire [9:0]  x_max_px,
    input  wire [9:0]  y_min_px,
    input  wire [9:0]  y_max_px,
    // 新增：水果像素中心
    input  wire [9:0]  fruit_cx,
    input  wire [9:0]  fruit_cy,

    // 输出到 VGA adapter
    output reg  [9:0]  x,
    output reg  [9:0]  y,
    output reg  [2:0]  colour,
    output reg         plot,
    output reg         busy
);

    // 基本参数
    localparam H_RES = 640;
    localparam V_RES = 480;
    localparam BORDER_THICK = 4;

    // 颜色
    localparam [2:0] COL_BLACK = 3'b000;
    localparam [2:0] COL_GREEN = 3'b010;
    localparam [2:0] COL_WHITE = 3'b111;
    localparam [2:0] COL_RED   = 3'b100;

    // 水果半径（常量平方）
    localparam [3:0] FRUIT_RADIUS    = 4'd6;
    localparam [7:0] FRUIT_RADIUS_SQ = FRUIT_RADIUS * FRUIT_RADIUS;

    // FSM
    localparam S_INIT_BG = 3'd0; // 画背景+边框
    localparam S_FRUIT   = 3'd1; // 画水果
    localparam S_DRAW    = 3'd2; // 画蛇头
    localparam S_IDLE    = 3'd3; // 静止

    reg [2:0] state;
    reg [9:0] xi, yi;

    // 水果绘制窗口（进入 S_FRUIT 前准备好）
    reg [9:0] fx_min, fx_max, fy_min, fy_max;

    // 距离计算（注意位宽：减法用 11-bit 有符号）
    wire signed [10:0] sxi = {1'b0, xi};
    wire signed [10:0] syi = {1'b0, yi};
    wire signed [10:0] fcx = {1'b0, fruit_cx};
    wire signed [10:0] fcy = {1'b0, fruit_cy};
    wire signed [10:0] dx  = sxi - fcx;
    wire signed [10:0] dy  = syi - fcy;   // ✅ 修正为 [10:0]
    wire        [21:0] dist_sq = dx*dx + dy*dy; // 11x11 → 22-bit

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state  <= S_INIT_BG;
            xi     <= 10'd0;
            yi     <= 10'd0;
            x      <= 10'd0;
            y      <= 10'd0;
            colour <= COL_BLACK;
            plot   <= 1'b0;
            busy   <= 1'b1;
            fx_min <= 10'd0; fx_max <= 10'd0;
            fy_min <= 10'd0; fy_max <= 10'd0;
        end else begin
            plot <= 1'b0; // 默认不写
            case (state)
                // -------------------------------------------------
                // 初始化背景：黑色 + 白色边框
                // -------------------------------------------------
                S_INIT_BG: begin
                    if (xi < BORDER_THICK || xi >= H_RES - BORDER_THICK ||
                        yi < BORDER_THICK || yi >= V_RES - BORDER_THICK)
                        colour <= COL_WHITE;
                    else
                        colour <= COL_BLACK;

                    x    <= xi;
                    y    <= yi;
                    plot <= 1'b1;

                    if (xi == H_RES - 1) begin
                        xi <= 0;
                        if (yi == V_RES - 1) begin
                            // 准备水果窗口（防越界）
                            fx_min <= (fruit_cx > FRUIT_RADIUS) ? (fruit_cx - FRUIT_RADIUS) : 10'd0;
                            fy_min <= (fruit_cy > FRUIT_RADIUS) ? (fruit_cy - FRUIT_RADIUS) : 10'd0;
                            fx_max <= (fruit_cx + FRUIT_RADIUS <= H_RES-1) ? (fruit_cx + FRUIT_RADIUS) : (H_RES-1);
                            fy_max <= (fruit_cy + FRUIT_RADIUS <= V_RES-1) ? (fruit_cy + FRUIT_RADIUS) : (V_RES-1);
                            xi     <= (fruit_cx > FRUIT_RADIUS) ? (fruit_cx - FRUIT_RADIUS) : 10'd0;
                            yi     <= (fruit_cy > FRUIT_RADIUS) ? (fruit_cy - FRUIT_RADIUS) : 10'd0;
                            state  <= S_FRUIT;
                        end else
                            yi <= yi + 1'b1;
                    end else
                        xi <= xi + 1'b1;
                end

                // -------------------------------------------------
                // 绘制红色水果（近似圆，仅在圆内 plot=1）
                // -------------------------------------------------
                S_FRUIT: begin
                    if (dist_sq <= FRUIT_RADIUS_SQ) begin
                        colour <= COL_RED;
                        x      <= xi;
                        y      <= yi;
                        plot   <= 1'b1;
                    end
                    // 扫描水果窗口
                    if (xi == fx_max) begin
                        xi <= fx_min;
                        if (yi == fy_max) begin
                            yi    <= y_min_px;
                            xi    <= x_min_px;
                            state <= S_DRAW;
                        end else
                            yi <= yi + 1'b1;
                    end else
                        xi <= xi + 1'b1;
                end

                // -------------------------------------------------
                // 绘制蛇头：绿色方块
                // -------------------------------------------------
                S_DRAW: begin
                    colour <= COL_GREEN;
                    x      <= xi;
                    y      <= yi;
                    plot   <= 1'b1;

                    if (xi == x_max_px) begin
                        xi <= x_min_px;
                        if (yi == y_max_px) begin
                            state <= S_IDLE;
                            busy  <= 1'b0;
                        end else
                            yi <= yi + 1'b1;
                    end else
                        xi <= xi + 1'b1;
                end

                // -------------------------------------------------
                // 静止显示
                // -------------------------------------------------
                S_IDLE: begin
                    busy <= 1'b0;
                end
            endcase
        end
    end
endmodule