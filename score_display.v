// 7-segment HEX decoder for digits 0–9 (active-HIGH segments)
// seg = {g,f,e,d,c,b,a}
module hex7
(
    input  wire [3:0] digit,
    output reg  [6:0] seg
);
    always @* begin
        case (digit)
            4'd0: seg = 7'b0000001; // 0
            4'd1: seg = 7'b1001111; // 1
            4'd2: seg = 7'b0010010; // 2
            4'd3: seg = 7'b0000110; // 3
            4'd4: seg = 7'b1001100; // 4
            4'd5: seg = 7'b0100100; // 5
            4'd6: seg = 7'b0100000; // 6
            4'd7: seg = 7'b0001111; // 7
            4'd8: seg = 7'b0000000; // 8
            4'd9: seg = 7'b0000100; // 9
            default: seg = 7'b1111111; // blank
        endcase
    end
endmodule



module score_display
(
    input  wire       clk,
    input  wire       resetn,     // active-LOW
    input  wire       score_inc,  // 1-cycle pulse
    output wire [6:0] HEX_TENS,
    output wire [6:0] HEX_ONES
);

    reg [3:0] ones;
    reg [3:0] tens;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            ones <= 4'd0;
            tens <= 4'd0;
        end else if (score_inc) begin
            if (!(tens == 4'd9 && ones == 4'd9)) begin
                if (ones == 4'd9) begin
                    ones <= 4'd0;
                    tens <= tens + 4'd1;
                end else begin
                    ones <= ones + 4'd1;
                end
            end
        end
    end

    hex7 u_hex_tens (.digit(tens), .seg(HEX_TENS));
    hex7 u_hex_ones (.digit(ones), .seg(HEX_ONES));

endmodule

