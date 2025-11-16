# ======================== run_keyboard_input.tcl ========================
# 用途：编译和仿真完整的键盘输入处理链路
transcript on
onerror {resume}

# --- 参数 ---
set TB_DIR ../tb
set SRC_DIR_INPUT ../../../src/input
set TOP_TB tb_keyboard_input
set LIB_NAME work

# --- 编译 ---
vlib $LIB_NAME
vmap $LIB_NAME $LIB_NAME

vlog +acc "$SRC_DIR_INPUT/ps2_rx.v"
vlog +acc "$SRC_DIR_INPUT/ps2_scancode.v"
vlog +acc "$SRC_DIR_INPUT/snake_dir.v"
vlog +acc "$TB_DIR/tb_keyboard_input.v"

# --- 仿真 ---
vsim -voptargs="+acc" $LIB_NAME.$TOP_TB

# --- 波形 ---
add wave -noupdate -divider "TOP"
add wave -noupdate -r sim:/$TOP_TB/*
add wave -noupdate -divider "PS2 RX"
add wave -noupdate -r sim:/$TOP_TB/u_rx/*
add wave -noupdate -divider "Scan Code"
add wave -noupdate -r sim:/$TOP_TB/u_sc/*
add wave -noupdate -divider "Direction"
add wave -noupdate -r sim:/$TOP_TB/u_dir/*

# --- 运行 ---
run -all
