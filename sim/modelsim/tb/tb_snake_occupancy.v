`timescale 1ns/1ps

module tb_snake_occupancy;

    // ------------------------------------------------------------
    // Parameters matching DUT
    // ------------------------------------------------------------
    localparam integer H_CELLS   = 40;
    localparam integer V_CELLS   = 30;
    localparam integer GRID_BITS = H_CELLS * V_CELLS;

    // Clock & reset
    reg clk;
    reg resetn;

    // DUT inputs
    reg  [5:0] new_head_x_cell;
    reg  [5:0] new_head_y_cell;
    reg        new_head_valid;

    reg  [5:0] old_tail_x_cell;
    reg  [5:0] old_tail_y_cell;
    reg        old_tail_valid;

    // DUT output
    wire [GRID_BITS-1:0] grid;

    // ============================================================
    // DUT instance
    // ============================================================
    snake_occupancy #(
        .H_CELLS(H_CELLS),
        .V_CELLS(V_CELLS)
    ) dut (
        .clk             (clk),
        .resetn          (resetn),
        .new_head_x_cell (new_head_x_cell),
        .new_head_y_cell (new_head_y_cell),
        .new_head_valid  (new_head_valid),
        .old_tail_x_cell (old_tail_x_cell),
        .old_tail_y_cell (old_tail_y_cell),
        .old_tail_valid  (old_tail_valid),
        .grid            (grid)
    );

    // Clock generator
    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    // ------------------------------------------------------------
    // Helper: convert (x,y) → bit index
    // ------------------------------------------------------------
    function integer idx;
        input [5:0] x;
        input [5:0] y;
        begin
            idx = y * H_CELLS + x;
        end
    endfunction

    // ------------------------------------------------------------
    // Initial snake segments (must match DUT)
    // ------------------------------------------------------------
    localparam integer INIT_HEAD_X = H_CELLS/2;      // 20
    localparam integer INIT_HEAD_Y = V_CELLS/2;      // 15
    localparam integer INIT_MID_X  = H_CELLS/2 - 1;  // 19
    localparam integer INIT_MID_Y  = V_CELLS/2;      // 15
    localparam integer INIT_TAIL_X = H_CELLS/2 - 2;  // 18
    localparam integer INIT_TAIL_Y = V_CELLS/2;      // 15

    // ------------------------------------------------------------
    // ASSERT: check reset state (three-segment snake)
    // ------------------------------------------------------------
    task assert_init_snake;
        input [8*80-1:0] msg;
        integer k;
        integer head_i, mid_i, tail_i;
    begin
        $display("%s : checking initial 3-segment snake state...", msg);
        head_i = idx(INIT_HEAD_X, INIT_HEAD_Y);
        mid_i  = idx(INIT_MID_X , INIT_MID_Y );
        tail_i = idx(INIT_TAIL_X, INIT_TAIL_Y);

        for (k = 0; k < GRID_BITS; k = k + 1) begin
            if (k == head_i || k == mid_i || k == tail_i) begin
                if (grid[k] !== 1'b1) begin
                    $display("ASSERTION FAILED: %s (init segment bit %0d must be 1, got %b) @ time %0t",
                             msg, k, grid[k], $time);
                    $stop;
                end
            end else begin
                if (grid[k] !== 1'b0) begin
                    $display("ASSERTION FAILED: %s (grid[%0d] must be 0, got %b) @ time %0t",
                             msg, k, grid[k], $time);
                    $stop;
                end
            end
        end

        $display("Initial snake OK.");
    end
    endtask

    // 简单 PASS 打印
    task pass;
        input [8*80-1:0] msg;
    begin
        $display(">>> PASS: %s", msg);
    end
    endtask

    // ------------------------------------------------------------
    // MAIN TESTBENCH
    // ------------------------------------------------------------
    initial begin
        $display("==== tb_snake_occupancy START ====");

        // 初始化输入
        new_head_x_cell = 0;
        new_head_y_cell = 0;
        new_head_valid  = 0;

        old_tail_x_cell = 0;
        old_tail_y_cell = 0;
        old_tail_valid  = 0;

        // 复位
        resetn = 0;
        repeat (3) @(posedge clk);
        resetn = 1;
        repeat (2) @(posedge clk);

        // --------------------------------------------------------
        // Test 0: reset 后应该是一条 3 段蛇
        // --------------------------------------------------------
        assert_init_snake("After reset");

        // --------------------------------------------------------
        // Case 1: 普通移动（清旧尾，设新头）
        // 原始：tail=(18,15), mid=(19,15), head=(20,15)
        // 模拟向右走：new head=(21,15)，旧尾=(18,15)
        // --------------------------------------------------------
        old_tail_x_cell = 18;
        old_tail_y_cell = 15;
        old_tail_valid  = 1;

        new_head_x_cell = 21;
        new_head_y_cell = 15;
        new_head_valid  = 1;

        @(posedge clk);
        #1;

        // 检查旧尾被清
        if (grid[idx(18,15)] !== 1'b0) begin
            $display("FAIL: Case1 tail (18,15) not cleared");
            $stop;
        end
        // 检查新头被置位
        if (grid[idx(21,15)] !== 1'b1) begin
            $display("FAIL: Case1 new head (21,15) not set");
            $stop;
        end

        pass("Case1 normal move");

        // 拉低脉冲
        old_tail_valid  = 0;
        new_head_valid  = 0;
        @(posedge clk);

        // --------------------------------------------------------
        // Case 2: 增长移动（不清尾巴，只加新头）
        // new head = (22,15)，old_tail_valid=0
        // 期望：之前那个 mid 位置 (19,15) 仍然为 1，新头 (22,15)=1
        // --------------------------------------------------------
        old_tail_valid  = 0;
        old_tail_x_cell = 0;
        old_tail_y_cell = 0;

        new_head_x_cell = 22;
        new_head_y_cell = 15;
        new_head_valid  = 1;

        @(posedge clk);
        #1;

        if (grid[idx(19,15)] !== 1'b1) begin
            $display("FAIL: Case2 middle segment (19,15) incorrectly cleared during growth");
            $stop;
        end
        if (grid[idx(22,15)] !== 1'b1) begin
            $display("FAIL: Case2 new head (22,15) not set");
            $stop;
        end

        pass("Case2 growth move");

        new_head_valid = 0;
        @(posedge clk);

        // --------------------------------------------------------
        // Case 3: 再构造一条小蛇，测试 head+tail 同时更新的时序
        // step1: 只加 (5,5)
        // step2: 加 (6,5) 同时清 (4,5)
        // --------------------------------------------------------
        // step1: growth-like
        new_head_x_cell = 5;
        new_head_y_cell = 5;
        new_head_valid  = 1;
        old_tail_valid  = 0;
        @(posedge clk);

        // step2: normal move
        new_head_x_cell = 6;
        new_head_y_cell = 5;
        new_head_valid  = 1;
        old_tail_x_cell = 4;
        old_tail_y_cell = 5;
        old_tail_valid  = 1;
        @(posedge clk);
        #1;

        if (grid[idx(6,5)] !== 1'b1) begin
            $display("FAIL: Case3 new head (6,5) not set");
            $stop;
        end
        if (grid[idx(4,5)] !== 1'b0) begin
            $display("FAIL: Case3 old tail (4,5) not cleared");
            $stop;
        end

        pass("Case3 two-step move");

        $display("==== tb_snake_occupancy ALL TESTS PASSED ====");
        $finish;
    end

endmodule
