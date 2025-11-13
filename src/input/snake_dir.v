module snake_dir (clk, rst_n, up_pulse, down_pulse, left_pulse, right_pulse, dir);
    input clk;
    input rst_n;
    input up_pulse;
    input down_pulse;
    input left_pulse;
    input right_pulse;
    output [1:0] dir;
    
	 
	 reg    [1:0] dir;

	// Set the initial condition to the right (Increase X = 2'b01)
	
	always @ (posedge clk) begin
		if (!rst_n) begin
			dir <= 2'b00;
		end else begin 
		
			// Only one should be asserted per key event; if multiple priority shown
			
            // 1. UP key -> Decrease Y (2'b11). Cannot be opposite of Increase Y (2'b10).
			if (up_pulse && dir != 2'b11) dir <= 2'b10; 
            
            // 2. LEFT key -> Decrease X (2'b01). Cannot be opposite of Increase X (2'b00).
			else if (left_pulse && dir != 2'b00) dir <= 2'b01;
            
            // 3. DOWN key (Opposite of UP) -> Increase Y (2'b10). Cannot be opposite of Decrease Y (2'b11).
			else if (down_pulse && dir != 2'b10) dir <= 2'b11;
            
            // 4. RIGHT key (Opposite of LEFT) -> Increase X (2'b00). Cannot be opposite of Decrease X (2'b01).
			else if (right_pulse && dir != 2'b01) dir <= 2'b00;
		end 
	end 
endmodule
	