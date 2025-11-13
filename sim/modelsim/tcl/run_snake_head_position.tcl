# ======================== run_snake_head.do ========================
# 用途：编译 + 仿真 snake_head 的 testbench，并自动加波形、运行到结束
# 运行方式（任选其一）：
#   1) GUI：  打开 ModelSim，在 Transcript 输入：do run_snake_head.do
#   2) CLI：  vsim -c -do "do run_snake_head.do"   （命令行静默运行）
# ==================================================================

transcript on
onerror {quit -code 1}        ;# 任意出错即退出，CI/自动化更稳

# ---- 可按需修改的参数 ----
set TB_DIR ../tb
set SRC_DIR_GAME ../../src/game
set TOP_TB tb_snake_head
set LIB_NAME work

# ---- 基本检查 ----
if {![file exists "$SRC_DIR_GAME/snake_head_position.v"]} {
    puts "ERROR: 找不到 $SRC_DIR_GAME/snake_head_position.v"
    quit -code 1
}
if {![file exists "$TB_DIR/tb_snake_head.v"]} {
    puts "ERROR: 找不到 $TB_DIR/tb_snake_head.v"
    quit -code 1
}

# ---- 建库映射 ----
catch {vdel -lib $LIB_NAME -all}
vlib $LIB_NAME
vmap $LIB_NAME $LIB_NAME

# ---- 编译（+acc 保留调试信息，便于加波形；可加入 -sv 编译 SV 源）----
vlog +acc "$SRC_DIR_GAME/snake_head_position.v"
vlog +acc "$TB_DIR/tb_snake_head.v"

# ---- 启动仿真（GUI/CLI 都可）----
# 说明：如果你用 CLI: vsim -c -do "do run_snake_head.do" 启动，本行依然有效
vsim -voptargs="+acc" $LIB_NAME.$TOP_TB

# ---- 波形与日志设置 ----
radix -unsigned
log -r /*

# 常用信号：先把 tb 和 dut 的信号都加上
add wave -noupdate -r sim:/$TOP_TB/*
add wave -noupdate -r sim:/$TOP_TB/dut/*

# 也可以只加关键的：clk/resetn/x_cell/y_cell
# add wave -radix unsigned sim:/$TOP_TB/clk
# add wave sim:/$TOP_TB/resetn
# add wave -radix unsigned sim:/$TOP_TB/x_cell
# add wave -radix unsigned sim:/$TOP_TB/y_cell

# ---- 运行到结束（由 $finish 或 $fatal 控制退出）----
run -all

# 若想强制限定最长仿真时间（防死跑），可改为：
run 30 ns
# quit -f
# ==================================================================