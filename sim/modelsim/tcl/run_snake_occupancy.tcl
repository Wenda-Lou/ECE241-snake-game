# 例如:
# vsim -do tcl/run_snake_occupancy.tcl

# 切到当前脚本所在目录（防止从别处调用路径错乱）
cd [file dirname [info script]]

# 建立/清空 work 库
if { [file exists ../work] } {
    vdel -lib ../work -all
}
vlib ../work
vmap work ../work

# 编译 DUT & testbench
vlog ../../../src/game/snake_occupancy.v
vlog ../tb/tb_snake_occupancy.v

# 运行仿真
vsim -t 1ns work.tb_snake_occupancy

# 可选：把所有信号丢进波形窗口
add wave *

# 跑到结束（$finish）
run -all
