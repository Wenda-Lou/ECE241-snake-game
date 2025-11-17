# wave.do - ModelSim waveform setup for tb_snake_engine

quietly restart

# Add testbench-level signals
add wave -radix binary  sim:/tb_snake_engine/clk
add wave -radix binary  sim:/tb_snake_engine/rst_n
add wave -radix binary  sim:/tb_snake_engine/step
add wave -radix binary  sim:/tb_snake_engine/dir

add wave -radix unsigned sim:/tb_snake_engine/fruit_x_cell
add wave -radix unsigned sim:/tb_snake_engine/fruit_y_cell

# DUT outputs
add wave -radix unsigned sim:/tb_snake_engine/snake_head_x_cell
add wave -radix unsigned sim:/tb_snake_engine/snake_head_y_cell
add wave -radix unsigned sim:/tb_snake_engine/snake_len
add wave -radix binary   sim:/tb_snake_engine/ate_fruit
add wave -radix binary   sim:/tb_snake_engine/game_over

# Some internal arrays from DUT (optional; comment out if names differ)
#add wave -radix unsigned sim:/tb_snake_engine/dut/snake_x*
#add wave -radix unsigned sim:/tb_snake_engine/dut/snake_y*

# Run simulation
run 10 ms
