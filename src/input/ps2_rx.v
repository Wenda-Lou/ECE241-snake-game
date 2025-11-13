module ps2_rx
#(parameter CLK_HZ = 50_000_000)
(
  input  wire clk,
  input  wire rst_n,
  input  wire ps2_clk,
  input  wire ps2_dat,
  output reg  data_ready,
  output reg  [7:0] data_out,
  output reg  frame_err
);

  // --- 2-FF sync ---
  reg [2:0] c_sync, d_sync;
  always @(posedge clk) begin
    c_sync <= {c_sync[1:0], ps2_clk};
    d_sync <= {d_sync[1:0], ps2_dat};
  end
  wire c = c_sync[2];
  wire d = d_sync[2];

  // --- falling edge detect ---
  reg c_d1;
  always @(posedge clk) c_d1 <= c;
  wire fall = (c_d1 == 1'b1) && (c == 1'b0);

  // --- state ---
  reg       busy;
  reg [3:0] idx;         // 0..10
  reg [10:0] bits;       // [0]=start, [1..8]=data LSB..MSB, [9]=parity, [10]=stop
  reg [10:0] bits_next;  // shadow (declared at module scope)
  reg [3:0]  idx_next;   // shadow index

  always @(posedge clk) begin
    data_ready <= 1'b0;
    frame_err  <= 1'b0;

    if (!rst_n) begin
      busy      <= 1'b0;
      idx       <= 4'd0;
      bits      <= 11'd0;
      bits_next <= 11'd0;
      idx_next  <= 4'd0;
      data_out  <= 8'h00;

    end else if (fall) begin
      // decide the index we are writing THIS edge
      if (!busy) begin
        busy     <= 1'b1;
        idx_next = 4'd0;     // first captured bit is start at index 0
      end else begin
        idx_next = idx + 4'd1;
      end

      // include THIS edge's sampled bit before validating
      bits_next       = bits;
      bits_next[idx_next] = d;

      // last bit? (stop at index 10)
      if (idx_next == 4'd10) begin
        // done collecting 11 bits
        busy <= 1'b0;

        // framing checks
        if (bits_next[0] != 1'b0 || bits_next[10] != 1'b1) begin
          frame_err <= 1'b1;
        end else if (~^( {bits_next[9], bits_next[8:1]} )) begin
          // odd parity over parity+data must be 1
          frame_err <= 1'b1;
        end else begin
          data_out   <= bits_next[8:1];
          data_ready <= 1'b1;
        end
      end else begin
        // still collecting
        busy <= 1'b1;
      end

      // commit state for next edge
      idx  <= idx_next;
      bits <= bits_next;
    end
  end
endmodule
