module game_tick #(
    parameter INPUT_CLK_FREQ = 50_000_000,  // 输入时钟频率 (Hz)
    parameter TICK_FREQ      = 2            // 输出 tick 频率 (Hz)
)(
    input  wire clk,        // 系统时钟 (CLOCK_50)
    input  wire resetn,     // 低电平复位
    output reg  tick        // 每次高电平持续 1 个 clk 周期
);

    // 计算分频系数
    localparam integer DIV_COUNT = INPUT_CLK_FREQ / TICK_FREQ / 2;  
    // /2 是因为 tick 只有 1 个周期高电平，占整个周期一小部分

    reg [31:0] count;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            count <= 0;
            tick  <= 1'b0;
        end else begin
            if (count == DIV_COUNT - 1) begin
                count <= 0;
                tick  <= 1'b1;   // 产生一个单周期脉冲
            end else begin
                count <= count + 1;
                tick  <= 1'b0;
            end
        end
    end

endmodule