`timescale 1ns/1ps
// Drives ps2_scancode directly with bytes (E0 75, E0 74, E0 6B, E0 72)
module tb;

  // 50 MHz
  reg clk = 1'b0;  always #10 clk = ~clk;
  reg rst_n = 1'b0;
  initial begin
    repeat (10) @(posedge clk);
    rst_n = 1'b1;
  end

  // byte interface into scancode
  reg        byte_rdy = 1'b0;
  reg [7:0]  byte_data = 8'h00;

  wire up_mk, dn_mk, lt_mk, rt_mk;
  wire [1:0] dir;

  // DUTs (no ps2_rx here)
  ps2_scancode u_sc (
    .clk(clk), .rst_n(rst_n),
    .data_ready(byte_rdy), .data_in(byte_data),
    .up_make(up_mk), .down_make(dn_mk),
    .left_make(lt_mk), .right_make(rt_mk)
  );

  snake_dir u_dir (
    .clk(clk), .rst_n(rst_n),
    .up_pulse(up_mk), .down_pulse(dn_mk),
    .left_pulse(lt_mk), .right_pulse(rt_mk),
    .dir(dir)
  );

  // push one byte into scancode (1-cycle ready pulse)
  task automatic drive_byte(input [7:0] b);
  begin
    @(posedge clk);
    byte_data <= b;
    byte_rdy  <= 1'b1;
    @(posedge clk);
    byte_rdy  <= 1'b0;
  end
  endtask

  // Set-2 extended scan codes (arrows)
  localparam [7:0] SC_UP=8'h75, SC_RIGHT=8'h74, SC_DOWN=8'h72, SC_LEFT=8'h6B;

  // log the bytes we inject (sanity)
  always @(posedge clk) if (byte_rdy)
    $display("[%0t] INJECT BYTE = 0x%02h", $time, byte_data);

  initial begin
    @(posedge rst_n);
    repeat (5) @(posedge clk);
    $display("[%0t] dir=%b (expect 01=RIGHT)", $time, dir);

    // E0 75  -> UP = 00
    drive_byte(8'hE0); drive_byte(SC_UP);    repeat (4) @(posedge clk);
    $display("[%0t] After UP: dir=%b (expect 00)", $time, dir);

    // E0 74  -> RIGHT = 01
    drive_byte(8'hE0); drive_byte(SC_RIGHT); repeat (4) @(posedge clk);
    $display("[%0t] After RIGHT: dir=%b (expect 01)", $time, dir);

    // E0 6B  -> LEFT (opposite) blocked → still 01
    drive_byte(8'hE0); drive_byte(SC_LEFT);  repeat (4) @(posedge clk);
    $display("[%0t] After LEFT(blocked): dir=%b (expect 01)", $time, dir);

    // E0 72  -> DOWN = 10
    drive_byte(8'hE0); drive_byte(SC_DOWN);  repeat (4) @(posedge clk);
    $display("[%0t] After DOWN: dir=%b (expect 10)", $time, dir);

    $stop;
  end
endmodule
