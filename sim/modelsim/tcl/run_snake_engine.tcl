# ======================== run_snake_engine.tcl ========================
# 用途：编译和仿真 snake_engine 核心逻辑
transcript on
onerror {resume}

# --- 参数 ---
set TB_DIR ../tb
set SRC_DIR_GAME ../../../src/game
set TOP_TB tb_snake_engine
set LIB_NAME work

# --- 编译 ---
vlib $LIB_NAME
vmap $LIB_NAME $LIB_NAME

# Compile DUT and TB
vlog snake_engine.v
vlog tb_snake_engine.v

# Elaborate testbench
vsim -t 1ns work.tb_snake_engine

# Load waveform configuration
do wave_snake_engine.do

