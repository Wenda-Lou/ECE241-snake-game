// src/random/lfsr16.v
module lfsr16(
    input  wire       clk,
    input  wire       resetn,
    output reg [15:0] rnd
);
    // Polynomial x^16 + x^14 + x^13 + x^11
    wire feedback = rnd[15] ^ rnd[13] ^ rnd[12] ^ rnd[10];
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            rnd <= 16'hACE1;           // Any non-zero seed
        else
            rnd <= {rnd[14:0], feedback};
    end
endmodule