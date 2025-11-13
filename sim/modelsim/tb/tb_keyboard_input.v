`timescale 1ns/1ps
// - Bit-bangs PS/2 with realistic timing
// - Calls arrows, WASD, SPACE, ENTER, RIGHT break
// - Prints every received byte
// - Uses a clock-cycle timeout (relaxed)
module tb;

  // System clock & reset (50 MHz)
  reg clk = 1'b0;  always #10 clk = ~clk;  // 20 ns period
  reg rst_n = 1'b0;
  initial begin
    repeat (10) @(posedge clk);
    rst_n = 1'b1;
  end

  //PS/2 physical lines
  reg ps2_clk = 1'b1;
  reg ps2_dat = 1'b1;

  //Byte interface from receiver
  wire       byte_rdy_w;
  wire [7:0] byte_data_w;

  // DUT chain
  ps2_rx u_rx (
    .clk(clk), .rst_n(rst_n),
    .ps2_clk(ps2_clk), .ps2_dat(ps2_dat),
    .data_ready(byte_rdy_w), .data_out(byte_data_w), .frame_err()
  );

  wire up_mk, dn_mk, lt_mk, rt_mk;
  wire [1:0] dir;

  ps2_scancode u_sc (
    .clk(clk), .rst_n(rst_n),
    .data_ready(byte_rdy_w), .data_in(byte_data_w),
    .up_make(up_mk), .down_make(dn_mk),
    .left_make(lt_mk), .right_make(rt_mk)
  );

  snake_dir u_dir (
    .clk(clk), .rst_n(rst_n),
    .up_pulse(up_mk), .down_pulse(dn_mk),
    .left_pulse(lt_mk), .right_pulse(rt_mk),
    .dir(dir)
  );

  //  PS/2 helpers 
  // Bit timing. Each bit uses 3*TQ in this TB (high → fall → high).
  localparam integer TQ = 20_000;  // 20 us

  // PS/2 bit: idle-high → falling edge (sample) → return high
  task ps2_clock_pulse;
    begin
      ps2_clk = 1'b1; #(TQ);   // idle high
      ps2_clk = 1'b0; #(TQ);   // FALLING edge (sample point)
      ps2_clk = 1'b1; #(TQ);   // back to idle high
    end
  endtask

  function odd_parity; input [7:0] b;
    begin odd_parity = ~(^b); end
  endfunction

  // Send one PS/2 byte: start(0), 8 data LSB-first, parity, stop(1)
  task send_ps2_byte; input [7:0] data;
    integer i; reg p;
    begin
      p = odd_parity(data);

      #(TQ);               // small idle
      ps2_dat = 1'b0;      // START
      ps2_clock_pulse();

      for (i=0;i<8;i=i+1) begin
        ps2_dat = data[i]; // DATA[i] valid BEFORE falling edge
        ps2_clock_pulse();
      end

      ps2_dat = p;         // PARITY (odd)
      ps2_clock_pulse();

      ps2_dat = 1'b1;      // STOP
      ps2_clock_pulse();

      #(TQ);               // inter-byte gap
    end
  endtask

  // Extended make and break helpers
  task make_ext; input [7:0] code; begin
    $display("[%0t] TX: E0 %02h (make)", $time, code);
    send_ps2_byte(8'hE0); send_ps2_byte(code);
  end endtask

  task break_ext; input [7:0] code; begin
    $display("[%0t] TX: E0 F0 %02h (break)", $time, code);
    send_ps2_byte(8'hE0); send_ps2_byte(8'hF0); send_ps2_byte(code);
  end endtask

  // Scancodes (Set-2) 
  // Arrows (extended)
  localparam [7:0] SC_UP    = 8'h75;
  localparam [7:0] SC_RIGHT = 8'h74;
  localparam [7:0] SC_DOWN  = 8'h72;
  localparam [7:0] SC_LEFT  = 8'h6B;

 

  // Debug 
  // Print every received byte
  always @(posedge clk)
    if (byte_rdy_w)
      $display("[%0t] RX BYTE = 0x%02h", $time, byte_data_w);

  // Wait for N bytes, with a clock-cycle timeout.
  // ms_to is wall time; at 50 MHz, there are 50,000 cycles per ms.
  task wait_n_bytes_to; input integer n; input integer ms_to;
    integer got;
    integer cycles_left;  // 50k cycles per ms at 50 MHz
    begin
      got = 0;
      cycles_left = ms_to * 50000;
      while ((got < n) && (cycles_left > 0)) begin
        @(posedge clk);
        if (byte_rdy_w) got = got + 1;
        cycles_left = cycles_left - 1;
      end
      if (got < n)
        $display("[%0t] TIMEOUT waiting bytes: got %0d / %0d", $time, got, n);
      else
        $display("[%0t] Got %0d/%0d bytes", $time, got, n);
      repeat (3) @(posedge clk);
    end
  endtask

  // ---------------- Stimulus (EXPLICIT KEY CALLS) ----------------
  initial begin
    @(posedge rst_n);
    repeat (5) @(posedge clk);
    $display("[%0t] Initial dir=%b (expect 01=RIGHT)", $time, dir);

    // 1) Arrows (extended) — each 2 bytes → use a relaxed 6 ms budget
    make_ext(SC_UP);     wait_n_bytes_to(2, 6);  $display("[%0t] After UP    : dir=%b (expect 00)", $time, dir);
    make_ext(SC_RIGHT);  wait_n_bytes_to(2, 6);  $display("[%0t] After RIGHT : dir=%b (expect 01)", $time, dir);
    make_ext(SC_LEFT);   wait_n_bytes_to(2, 6);  $display("[%0t] After LEFT  : dir=%b (expect 01)  // blocked", $time, dir);
    make_ext(SC_DOWN);   wait_n_bytes_to(2, 6);  $display("[%0t] After DOWN  : dir=%b (expect 10)", $time, dir);

    // 3) Repeat UP twice — 2 bytes each
    make_ext(SC_UP);     wait_n_bytes_to(2, 6);  $display("[%0t] After UP rpt1: dir=%b (expect 00)", $time, dir);
    make_ext(SC_UP);     wait_n_bytes_to(2, 6);  $display("[%0t] After UP rpt2: dir=%b (expect 00)", $time, dir);

    // 4) Break example: RIGHT release — 3 bytes → 8 ms
    break_ext(SC_RIGHT); wait_n_bytes_to(3, 8);  $display("[%0t] RIGHT break sent (no dir change expected)", $time);

    $display("[%0t] *** TEST COMPLETE ***", $time);
    $stop;
  end

endmodule
