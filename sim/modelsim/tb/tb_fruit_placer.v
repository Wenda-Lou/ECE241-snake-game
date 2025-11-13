`timescale 1ns/1ps

module tb_fruit_placer;

  // =========================
  // 全局：时钟/复位 & 常量
  // =========================
  localparam integer CLK_NS = 10;   // 100 MHz => 10ns
  reg clk, resetn;
  initial clk = 1'b0;
  always #(CLK_NS/2) clk = ~clk;

  // 固定蛇头坐标（便于复现）
  reg [5:0] snake_x, snake_y;

  // ====== 测试参数（与 DUT 参数保持一致）======
  localparam integer H1=40, V1=30, M1=1, T1=16, D1=3;
  localparam [5:0] XMIN1 = M1;
  localparam [5:0] XMAX1 = H1-1-M1;
  localparam [5:0] YMIN1 = M1;
  localparam [5:0] YMAX1 = V1-1-M1;

  // 角点/循环变量
  reg [5:0] cx [0:3], cy [0:3];
  reg [7:0] cd [0:3];
  integer i, imax;

  // =========================
  // DUT #1：正常参数（最优候选路径）
  // =========================
  reg                 req1;
  wire [5:0]          fx1, fy1;
  wire                done1, busy1;

  fruit_placer #(
    .H_CELLS(H1), .V_CELLS(V1),
    .MARGIN_CELLS(M1), .TRIES(T1), .MIN_DIST(D1)
  ) dut_best (
    .clk(clk), .resetn(resetn),
    .request(req1),
    .snake_x_cell(snake_x), .snake_y_cell(snake_y),
    .fruit_x_cell(fx1), .fruit_y_cell(fy1),
    .done(done1), .busy(busy1)
  );

  // =========================
  // DUT #2：MIN_DIST 极大（兜底四角）
  // =========================
  localparam integer D2 = 100;
  reg                 req2;
  wire [5:0]          fx2, fy2;
  wire                done2, busy2;

  fruit_placer #(
    .H_CELLS(H1), .V_CELLS(V1),
    .MARGIN_CELLS(M1), .TRIES(T1), .MIN_DIST(D2)
  ) dut_fallback (
    .clk(clk), .resetn(resetn),
    .request(req2),
    .snake_x_cell(snake_x), .snake_y_cell(snake_y),
    .fruit_x_cell(fx2), .fruit_y_cell(fy2),
    .done(done2), .busy(busy2)
  );

  // =========================
  // 工具：abs / manhattan
  // =========================
  function [5:0] uabs6(input [5:0] a, input [5:0] b);
    uabs6 = (a>=b) ? (a-b) : (b-a);
  endfunction
  function [7:0] manhattan(input [5:0] x1, input [5:0] y1,
                           input [5:0] x2, input [5:0] y2);
    begin
      manhattan = uabs6(x1,x2) + uabs6(y1,y2);
    end
  endfunction

  // =========================
  // 断言
  // =========================
  task assert_true(input cond, input [255*8:1] tag);
    begin
      if (!cond) begin
        $display("[%0t] FAIL(%s)", $time, tag);
        $fatal;
      end else begin
        $display("[%0t] PASS(%s)", $time, tag);
      end
    end
  endtask

  task check_legal(input [5:0] fx, input [5:0] fy,
                   input [5:0] XMIN, input [5:0] XMAX,
                   input [5:0] YMIN, input [5:0] YMAX,
                   input [5:0] sx,  input [5:0] sy,
                   input [7:0] mindist, input [255*8:1] tag);
    begin
      assert_true(fx!==6'bxxxxxx && fy!==6'bxxxxxx, {"no X/Z ", tag});
      assert_true(fx>=XMIN && fx<=XMAX, {"x in range ", tag});
      assert_true(fy>=YMIN && fy<=YMAX, {"y in range ", tag});
      assert_true(!(fx==sx && fy==sy), {"not overlap head ", tag});
      assert_true(manhattan(fx,fy,sx,sy) >= mindist, {"dist >= MIN_DIST ", tag});
    end
  endtask

  // =========================
  // 更稳的 busy/done 量测（事件时间差，避免 NBA 同拍读取旧值）
  // =========================
  task measure_busy_done_by_time(input integer tries,
                                 input        which); // 0=>实例1, 1=>实例2
    time t_start, t_end, t_rise, t_fall;
    integer busy_cycles;
    begin
      // 1) 量测 busy 宽度（用边沿时间差换算拍数）
      if (!which) @(posedge busy1); else @(posedge busy2);
      t_start = $time;

      if (!which) @(negedge busy1); else @(negedge busy2);
      t_end = $time;

      busy_cycles = (t_end - t_start) / CLK_NS;
      assert_true(busy_cycles == tries + 1,
                  which ? "busy cycles (fb)" : "busy cycles (best)");

      // 2) done 应该在 busy 结束后的“下一拍”拉高
      if (!which) @(posedge done1); else @(posedge done2);
      t_rise = $time;
      assert_true((t_rise - t_end) == CLK_NS,
                  which ? "done after busy +1 (fb)" : "done after busy +1 (best)");

      // 3) done 宽度应该正好 1 拍（再用边沿时间差判断）
      if (!which) @(negedge done1); else @(negedge done2);
      t_fall = $time;
      assert_true((t_fall - t_rise) == CLK_NS,
                  which ? "done is 1-cycle (fb)" : "done is 1-cycle (best)");

      // 4) 额外观察几拍，确保没有二次脉冲
      repeat (3) @(posedge clk);
      if (!which) assert_true(done1==1'b0, "no extra done pulse (best)");
      else        assert_true(done2==1'b0, "no extra done pulse (fb)");
    end
  endtask

  // =========================
  // 触发一次 request（拉高 1 拍）
  // =========================
  task kick(input which);
    begin
      if (!which) begin
        req1 <= 1'b1; @(posedge clk); req1 <= 1'b0;
      end else begin
        req2 <= 1'b1; @(posedge clk); req2 <= 1'b0;
      end
    end
  endtask

  // =========================
  // 主流程
  // =========================
  initial begin
    // 复位
    resetn = 0;
    req1   = 0; req2 = 0;
    snake_x = 6'd10; snake_y = 6'd10;
    repeat (3) @(negedge clk);
    resetn = 1;

    // ---------- 用例 A：正常参数 ----------
    kick(1'b0);
    fork
      begin
        @(posedge busy1);
        req1 <= 1'b1; repeat (3) @(posedge clk); req1 <= 1'b0;
      end
      begin
        measure_busy_done_by_time(T1, 1'b0);
      end
    join
    check_legal(fx1, fy1, XMIN1, XMAX1, YMIN1, YMAX1, snake_x, snake_y, D1, "best-case legal");

    // ---------- 用例 B：兜底四角 ----------
    kick(1'b1);
    measure_busy_done_by_time(T1, 1'b1);

    cx[0]=XMIN1; cy[0]=YMIN1;
    cx[1]=XMAX1; cy[1]=YMIN1;
    cx[2]=XMIN1; cy[2]=YMAX1;
    cx[3]=XMAX1; cy[3]=YMAX1;
    for (i=0;i<4;i=i+1) cd[i] = manhattan(cx[i],cy[i], snake_x, snake_y);
    imax = 0;
    for (i=1;i<4;i=i+1) if (cd[i] > cd[imax]) imax = i;
    assert_true(fx2==cx[imax] && fy2==cy[imax], "fallback to farthest corner");

    $display("ALL FRUIT_PLACER TESTS PASSED.");
    $finish;
  end

endmodule
