// ===========================================================
// Module: direction_decoder
// Description:
//   将 PS/2 键盘的扫描码 (scancode) 解码为方向信号 (dir)。
//   只处理 W, A, S, D 和方向键的 make code。
// ===========================================================

module direction_decoder (
    input  wire       clk,
    input  wire       resetn,
    input  wire [7:0] scancode,       // 扫描码
    input  wire       scancode_ready, // 扫描码有效脉冲
    output reg  [1:0] dir             // 方向: 00=上, 01=下, 10=左, 11=右
);

    // PS/2 Make Codes for arrow keys and WASD
    localparam KEY_UP_ARROW = 8'h75;
    localparam KEY_W        = 8'h1D;
    localparam KEY_DOWN_ARROW = 8'h72;
    localparam KEY_S        = 8'h1B;
    localparam KEY_LEFT_ARROW = 8'h6B;
    localparam KEY_A        = 8'h1C;
    localparam KEY_RIGHT_ARROW = 8'h74;
    localparam KEY_D        = 8'h23;

    // Direction encodings
    localparam DIR_UP    = 2'b00;
    localparam DIR_DOWN  = 2'b01;
    localparam DIR_LEFT  = 2'b10;
    localparam DIR_RIGHT = 2'b11;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            dir <= DIR_RIGHT; // 默认初始方向向右
        end else begin
            // 当有新的扫描码准备好时，进行解码
            if (scancode_ready) begin
                case (scancode)
                    KEY_UP_ARROW, KEY_W:
                        dir <= DIR_UP;
                    KEY_DOWN_ARROW, KEY_S:
                        dir <= DIR_DOWN;
                    KEY_LEFT_ARROW, KEY_A:
                        dir <= DIR_LEFT;
                    KEY_RIGHT_ARROW, KEY_D:
                        dir <= DIR_RIGHT;
                    default:
                        // 忽略其他按键
                        ;
                endcase
            end
        end
    end

endmodule
