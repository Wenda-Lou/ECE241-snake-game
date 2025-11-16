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

vlog +acc "$SRC_DIR_GAME/snake_engine.v"
vlog +acc "$TB_DIR/tb_snake_engine.v"

# --- 仿真 ---
vsim -voptargs="+acc" $LIB_NAME.$TOP_TB

# --- 波形 ---
add wave -noupdate -r sim:/$TOP_TB/*

# --- 运行 ---
run -all
