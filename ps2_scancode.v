module ps2_scancode(
    input  wire clk,
    input  wire rst_n,
    input  wire data_ready,
    input  wire [7:0] data_in,
    output reg  up_make,
    output reg  down_make,
    output reg  left_make,
    output reg  right_make,
	 output reg  enter_make);

	// takes in the raw data bytes from the ps2_rx 
	// convert these data to key scanned sequences into 1 clk pulses for key pressing detections
	
	// Arrow codes (Set-2) with E0 prefix
   localparam [7:0] SC_UP    = 8'h75;
   localparam [7:0] SC_DOWN  = 8'h72;
   localparam [7:0] SC_LEFT  = 8'h6B;
   localparam [7:0] SC_RIGHT = 8'h74;
	localparam [7:0] SC_ENTER = 8'h5A;
	
	reg e0_seen, f0_seen;   // e0 for pressing, f0 for releasing
	
	always @(posedge clk) begin
        
		  //Clean things up after reset
		  if (!rst_n) begin
            e0_seen <= 0; f0_seen <= 0;
            up_make <= 0; down_make <= 0; left_make <= 0; right_make <= 0; enter_make <= 0;
        end else begin
            // default: clear pulses
            up_make <= 0; down_make <= 0; left_make <= 0; right_make <= 0; enter_make <= 0;

            if (data_ready) begin
                case (data_in)
                    8'hE0: begin
                        e0_seen <= 1'b1;
                        f0_seen <= 1'b0;
                    end
                    8'hF0: begin
                        // break prefix (must come after E0 for arrows)
                        if (e0_seen) f0_seen <= 1'b1;
                    end
                    default: begin
								
								// Key deteection when we are in the e0 mode
								if (e0_seen && !f0_seen) begin
                            // MAKE event for extended key
                            if (data_in == SC_UP)    up_make    <= 1'b1;
                            if (data_in == SC_DOWN)  down_make  <= 1'b1;
                            if (data_in == SC_LEFT)  left_make  <= 1'b1;
                            if (data_in == SC_RIGHT) right_make <= 1'b1;
                        end
								
								
								// ENTER MAKE (non-extended, simple case)
                        // We only care about the MAKE (key press),
                        // so any SC_ENTER byte is treated as a press.
								if (!e0_seen && !f0_seen && data_in == SC_ENTER)
                            enter_make <= 1'b1;
									 
                        // clear prefix state after any final byte
                        if (e0_seen && f0_seen) begin
                            // this was a BREAK final byte 
                            e0_seen <= 1'b0; f0_seen <= 1'b0;
                        end else if (e0_seen && !f0_seen) begin
                            // consumed a MAKE code; clear E0
                            e0_seen <= 1'b0;
                        end else begin
                            // regular non-extended keys: ignore
                            e0_seen <= 1'b0; f0_seen <= 1'b0;
                        end
                    end
                endcase
            end
        end
    end
endmodule