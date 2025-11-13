module snake_head_movement(
    input wire clk,
    input wire rst_n,
    input wire [1:0]dir,
    output reg [7:0]snake_head_x,
    output reg [7:0]snake_head_y,
    output reg game_over
);

    // snake movement speed -- 1 per clk cycle
    parameter SPEED = 1;

    // Grid boundaries: X (0 to 39), Y (0 to 29) 16*16 grid
    localparam MIN_X = 8'd0;
    localparam MAX_X = 8'd39; 
    localparam MIN_Y = 8'd0;
    localparam MAX_Y = 8'd29;

    // Movement logic 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Active-low Reset (KEY0): Resets state and position. 
            snake_head_x <= 8'd20; // Initial X
            snake_head_y <= 8'd15; // Initial Y
            game_over    <= 1'b0;
        end else begin 
            
            // --- Movement and Boundary Check Logic ---
            case (dir)
                
                2'b01: begin
                    // Direction: X Increase (Left ARROW logic)
                    if (snake_head_x == MAX_X || snake_head_x == MIN_X) begin
                        game_over <= 1'b1; // Collision detected
                    end else begin
                        snake_head_x <= snake_head_x - SPEED;
                    end
                end
					 2'b00: begin
                    // Direction: X Decrease (Right ARROW logic)
                    if (snake_head_x == MIN_X || snake_head_x == MAX_X) begin
                        game_over <= 1'b1; // Collision detected
                    end else begin
                        snake_head_x <= snake_head_x + SPEED;
                    end
                end
					 
                2'b10: begin
                    // Direction: Y Decrease (UP ARROW logic)
                    if (snake_head_y == MIN_Y || snake_head_y == MAX_Y) begin
                        game_over <= 1'b1; // Collision detected
                    end else begin
                        snake_head_y <= snake_head_y - SPEED;
                    end
                end
                2'b11: begin
                    // Direction: Y Increase (DOWN ARROW logic)
                    if (snake_head_y == MAX_Y || snake_head_y == MIN_Y) begin
                        game_over <= 1'b1; // Collision detected
                    end else begin
                        snake_head_y <= snake_head_y + SPEED;
                    end
                end
            endcase
				if (game_over) begin
					snake_head_x <= 0;
					snake_head_y <= 0;
				end
        end
    end
endmodule