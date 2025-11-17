module frame_tick #(
    parameter INPUT_CLK_FREQ = 50_000_000,
    parameter FRAME_RATE     = 30
)(
    input  wire clk,
    input  wire resetn,
    output reg tick
);

    localparam integer PERIOD = INPUT_CLK_FREQ / FRAME_RATE;

    reg [$clog2(PERIOD)-1:0] counter;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            counter <= 0;
            tick <= 0;
        end else begin
            tick <= 0;
            if (counter == PERIOD - 1) begin
                counter <= 0;
                tick <= 1;
            end else begin
                counter <= counter + 1;
            end
        end
    end
endmodule