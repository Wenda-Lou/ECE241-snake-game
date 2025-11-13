`timescale 1ns/1ps
module tb;

  reg clk = 1'b0;  always #10 clk = ~clk;  // 50 MHz
  reg rst_n = 1'b0;
  initial begin repeat (10) @(posedge clk); rst_n = 1'b1; end

  // PS/2 lines
  reg ps2_clk = 1'b1;
  reg ps2_dat = 1'b1;

  // byte iface
  wire       byte_rdy_w;
  wire [7:0] byte_data_w;

  // DUTs
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

  // -------- PS/2 helpers (fast enough for sim) --------
  integer TQ = 10_000; // 10 us half, ~220 us/byte

  task ps2_fall; begin
    #(TQ); ps2_clk = 1'b0;
    #(TQ); ps2_clk = 1'b1;
  end endtask

  function odd_parity(input [7:0] b);
    odd_parity = ~(^b);
  endfunction

  task send_ps2_byte(input [7:0] data);
    integer i; reg p;
  begin
    p = odd_parity(data);
    #(TQ);
    ps2_dat = 1'b0; ps2_fall();                    // start
    for (i=0;i<8;i=i+1) begin ps2_dat = data[i]; ps2_fall(); end
    ps2_dat = p;   ps2_fall();                      // parity
    ps2_dat = 1'b1; ps2_fall();                     // stop
    #(TQ);
  end endtask

  task make_ext(input [7:0] code);
  begin send_ps2_byte(8'hE0); send_ps2_byte(code); end
  endtask

  localparam [7:0] SC_UP=8'h75, SC_RIGHT=8'h74, SC_DOWN=8'h72, SC_LEFT=8'h6B;

  // show received bytes
  always @(posedge clk) if (byte_rdy_w)
    $display("[%0t] BYTE = 0x%02h", $time, byte_data_w);

  // wait for N received bytes
  task wait_n_bytes(input integer n);
    integer k;
  begin
    for (k=0;k<n;k=k+1) @(posedge byte_rdy_w);
    repeat (4) @(posedge clk);
  end endtask

  initial begin
    @(posedge rst_n); repeat (5) @(posedge clk);
    $display("[%0t] dir=%b (expect 01=RIGHT)", $time, dir);

    make_ext(SC_UP);    wait_n_bytes(2); $display("[%0t] After UP: dir=%b (expect 00)", $time, dir);
    make_ext(SC_RIGHT); wait_n_bytes(2); $display("[%0t] After RIGHT: dir=%b (expect 01)", $time, dir);
    make_ext(SC_LEFT);  wait_n_bytes(2); $display("[%0t] After LEFT(blocked): dir=%b (expect 01)", $time, dir);
    make_ext(SC_DOWN);  wait_n_bytes(2); $display("[%0t] After DOWN: dir=%b (expect 10)", $time, dir);

    $stop;
  end
endmodule
