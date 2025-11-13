// ===========================================================
// Module: fruit_placer
// Description:
//   依据随机数生成水果的“棋盘坐标”(cell_x, cell_y)
//   约束：离边框保留 MARGIN_CELLS，不与蛇头重合，
//         与蛇头保持 >= MIN_DIST 的曼哈顿距离；
//         在 TRIES 个候选中挑“距离蛇头最远”的，
//         若整轮皆无合法候选，则兜底挑“四角里最远”的。
//   纯加减比较，无乘法；Verilog-2001 兼容写法。
// ===========================================================
module fruit_placer #(
    parameter integer CELL_PX      = 16,   // 每 cell 像素边长（接口对齐用，内部未用）
    parameter integer H_CELLS      = 40,   // 640 / 16
    parameter integer V_CELLS      = 30,   // 480 / 16
    parameter integer MARGIN_CELLS = 1,    // 离边框至少多少格
    parameter integer TRIES        = 16,   // 候选次数（越大越“远”）
    parameter integer MIN_DIST     = 3     // 最小安全距离（格，曼哈顿）
)(
    input  wire       clk,
    input  wire       resetn,

    // 触发：request=1（建议 1 拍），开始生成一次新水果
    input  wire       request,

    // 当前蛇头的 cell 坐标（未来可扩展传蛇身占用位图）
    input  wire [5:0] snake_x_cell,   // 0..63（实际 ≤ H_CELLS-1）
    input  wire [5:0] snake_y_cell,   // 0..63（实际 ≤ V_CELLS-1）

    // 结果输出：水果 cell 坐标
    output reg  [5:0] fruit_x_cell,
    output reg  [5:0] fruit_y_cell,

    // 握手/状态
    output reg        done,    // 结果就绪脉冲（1 拍）
    output reg        busy     // 生成中标志
);

    // ---------------------------
    // 有效棋盘范围（闭区间）
    // 采用显式位宽赋值（Verilog-2001 友好）
    // ---------------------------
    localparam [5:0] X_MIN  = MARGIN_CELLS;
    localparam [5:0] X_MAX  = H_CELLS - 1 - MARGIN_CELLS;
    localparam [5:0] Y_MIN  = MARGIN_CELLS;
    localparam [5:0] Y_MAX  = V_CELLS - 1 - MARGIN_CELLS;

    localparam [5:0] X_SPAN = X_MAX - X_MIN + 6'd1;   // 40 - 2*margin
    localparam [5:0] Y_SPAN = Y_MAX - Y_MIN + 6'd1;   // 30 - 2*margin

    // 8-bit 本地副本（避免比较/计数时的位宽/符号问题）
    localparam [7:0] TRIES8    = TRIES;
    localparam [7:0] MIN_DIST8 = MIN_DIST;

    // ---------------------------
    // PRNG
    // ---------------------------
    wire [15:0] rnd;
    lfsr16 u_lfsr(.clk(clk), .resetn(resetn), .rnd(rnd));

    // 取出候选（拒绝采样：仅当 rx<X_SPAN 且 ry<Y_SPAN 才接受）
    wire [5:0] rx = rnd[5:0];      // 0..63
    wire [5:0] ry = rnd[11:6];     // 0..63

    wire       valid_x = (rx < X_SPAN);
    wire       valid_y = (ry < Y_SPAN);

    wire [5:0] cand_x  = X_MIN + rx;   // 映射到有效区
    wire [5:0] cand_y  = Y_MIN + ry;

    // 与蛇头的曼哈顿距离（全加减）
    wire [5:0] dx = (cand_x > snake_x_cell) ? (cand_x - snake_x_cell)
                                            : (snake_x_cell - cand_x);
    wire [5:0] dy = (cand_y > snake_y_cell) ? (cand_y - snake_y_cell)
                                            : (snake_y_cell - cand_y);
    wire [7:0] manhattan = dx + dy;     // 最大 ~69，8 bit 足够

    // 过滤条件
    wire overlap_head = (cand_x == snake_x_cell) && (cand_y == snake_y_cell);
    wire far_enough   = (manhattan >= MIN_DIST8);

    // ---------------------------
    // 四角兜底（均在有效范围内）
    // ---------------------------
    wire [5:0] c0x = X_MIN, c0y = Y_MIN;
    wire [5:0] c1x = X_MAX, c1y = Y_MIN;
    wire [5:0] c2x = X_MIN, c2y = Y_MAX;
    wire [5:0] c3x = X_MAX, c3y = Y_MAX;

    // 四角到蛇头的曼哈顿距离
    wire [7:0] d0 = ((c0x>snake_x_cell)?(c0x-snake_x_cell):(snake_x_cell-c0x))
                  + ((c0y>snake_y_cell)?(c0y-snake_y_cell):(snake_y_cell-c0y));
    wire [7:0] d1 = ((c1x>snake_x_cell)?(c1x-snake_x_cell):(snake_x_cell-c1x))
                  + ((c1y>snake_y_cell)?(c1y-snake_y_cell):(snake_y_cell-c1y));
    wire [7:0] d2 = ((c2x>snake_x_cell)?(c2x-snake_x_cell):(snake_x_cell-c2x))
                  + ((c2y>snake_y_cell)?(c2y-snake_y_cell):(snake_y_cell-c2y));
    wire [7:0] d3 = ((c3x>snake_x_cell)?(c3x-snake_x_cell):(snake_x_cell-c3x))
                  + ((c3y>snake_y_cell)?(c3y-snake_y_cell):(snake_y_cell-c3y));

    // 组合逻辑挑“最远角落”
    reg [5:0] fb_x, fb_y; reg [7:0] fb_d;
    always @* begin
        fb_x = c0x; fb_y = c0y; fb_d = d0;
        if (d1 > fb_d) begin fb_x = c1x; fb_y = c1y; fb_d = d1; end
        if (d2 > fb_d) begin fb_x = c2x; fb_y = c2y; fb_d = d2; end
        if (d3 > fb_d) begin fb_x = c3x; fb_y = c3y; fb_d = d3; end
    end

    // ---------------------------
    // FSM
    // ---------------------------
    localparam S_IDLE = 2'd0, S_GEN = 2'd1, S_DONE = 2'd2;
    reg [1:0] state;

    reg        found_any;             // 本轮是否命中过至少 1 个合法候选
    reg [7:0]  best_dist;             // 当前最优距离
    reg [5:0]  best_x, best_y;        // 当前最优坐标
    reg [7:0]  tries_left;            // 剩余尝试次数（每拍自减）

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state         <= S_IDLE;
            done          <= 1'b0;
            busy          <= 1'b0;

            fruit_x_cell  <= X_MIN;
            fruit_y_cell  <= Y_MIN;

            found_any     <= 1'b0;
            best_dist     <= 8'd0;
            best_x        <= X_MIN;
            best_y        <= Y_MIN;
            tries_left    <= 8'd0;
        end else begin
            case (state)
                // --------------------------
                // 空闲：等待触发
                // --------------------------
                S_IDLE: begin
                    done <= 1'b0;
                    if (request) begin
                        busy       <= 1'b1;
                        found_any  <= 1'b0;
                        best_dist  <= 8'd0;
                        best_x     <= X_MIN;
                        best_y     <= Y_MIN;
                        tries_left <= TRIES8;   // 例如 16
                        state      <= S_GEN;
                    end
                end

                // --------------------------
                // 生成：每拍尝试 1 个候选（必定自减计数）
                // --------------------------
                S_GEN: begin
                    // 1) 到点收尾（先判断，保证准确尝试次数）
                    if (tries_left == 0) begin
                        // 若本轮没有任何合法候选，兜底为“四角里最远”
                        fruit_x_cell <= found_any ? best_x : fb_x;
                        fruit_y_cell <= found_any ? best_y : fb_y;
                        busy         <= 1'b0;
                        state        <= S_DONE;
                    end else begin
                        // 2) 正常消耗一次尝试机会
                        tries_left <= tries_left - 8'd1;

                        // 3) 候选过滤 + 最优更新
                        if (valid_x && valid_y && !overlap_head && far_enough) begin
                            if (manhattan >= best_dist) begin
                                best_dist <= manhattan;
                                best_x    <= cand_x;
                                best_y    <= cand_y;
                            end
                            found_any <= 1'b1;
                        end
                        // LFSR 在下一个 clk 会提供新随机数
                    end
                end

                // --------------------------
                // 完成：打一拍 done 脉冲
                // --------------------------
                S_DONE: begin
                    done  <= 1'b1;    // 1 拍脉冲
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule
