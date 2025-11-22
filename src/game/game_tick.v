module game_tick #(
    parameter INPUT_CLK_FREQ = 50_000_000,  // Input clock frequency (Hz)
    parameter TICK_FREQ      = 2            // Output tick frequency (Hz)
)(
    input  wire clk,        // System clock (CLOCK_50)
    input  wire resetn,     // Active-low reset
    output reg  tick        // Each pulse stays high for one clk cycle
);

    // Number of clock cycles per tick period
    localparam integer PERIOD_COUNT = INPUT_CLK_FREQ / TICK_FREQ;

    // Counter width = ceil(log2(PERIOD_COUNT))
    reg [$clog2(PERIOD_COUNT)-1:0] counter;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            counter <= 0;
            tick    <= 1'b0;
        end else begin
            // Default state keeps tick low
            tick <= 1'b0;

            if (counter == PERIOD_COUNT - 1) begin
                counter <= 0;
                tick    <= 1'b1; // Generate a one-clock pulse
            end else begin
                counter <= counter + 1;
            end
        end
    end

endmodule
