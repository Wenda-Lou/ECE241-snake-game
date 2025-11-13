`timescale 1ns/1ps

module tb_snake_head;
  // DUT 端口
  reg         clk;
  reg         resetn;
  wire [9:0]  x_cell;
  wire [9:0]  y_cell;

  // 实例化被测模块
  snake_head dut (
    .clk    (clk),
    .resetn (resetn),
    .x_cell (x_cell),
    .y_cell (y_cell)
  );

  // 50MHz 只是板上频率，仿真里随便给；这里 100MHz（10ns 周期）
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // 断言/检查任务
  task check_xy(input [9:0] ex, input [9:0] ey, input [255*8:1] tag);
    begin
      if (x_cell !== ex || y_cell !== ey) begin
        $display("[%0t] FAIL(%s): x_cell=%0d y_cell=%0d (expect %0d,%0d)",
                 $time, tag, x_cell, y_cell, ex, ey);
        $fatal; // 终止仿真并标红
      end else begin
        $display("[%0t] PASS(%s): x_cell=%0d y_cell=%0d",
                 $time, tag, x_cell, y_cell);
      end
    end
  endtask

  // 复位 & 用例时序
  initial begin
    // 初始复位
    resetn = 1'b0;
    repeat (2) @(negedge clk);
    resetn = 1'b1;

    // 释放复位后，等待 2 拍让寄存器稳定
    repeat (2) @(posedge clk);
    check_xy(10'd6, 10'd5, "after reset release"); // Change to 5 will continue on simulation

    // 运行一段时间，验证稳定
    repeat (20) @(posedge clk);
    check_xy(10'd5, 10'd5, "steady run");

    // 在时钟间隙拉低复位，测试异步复位
    #3;  // 故意与时钟不同相位
    resetn = 1'b0;
    #7;  // 保持一小段时间
    resetn = 1'b1;

    // 复位后再次检查
    repeat (2) @(posedge clk);
    check_xy(10'd5, 10'd5, "after async reset");

    $display("ALL SNAKE_HEAD TESTS PASSED.");
    $finish;
  end

endmodule