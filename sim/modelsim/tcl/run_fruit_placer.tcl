# ======================== run_fruit_placer.tcl ========================
transcript on
onerror {resume}   ;# 出错不退出，方便看完整错误

# 参数
set TB_DIR ../tb
set SRC_DIR_GAME ../../src/game
set TOP_TB tb_fruit_placer
set LIB_NAME work

# 简单工具：逐文件编译并记录是否失败
set comp_failed 0
proc compile_one {file opts} {
    if {![file exists $file]} {
        puts "ERROR: Missing $file"
        set ::comp_failed 1
        return
    }
    # opts 可能是多参数（例如 "-sv +acc"），用 eval 传递
    if {[catch {eval vlog $opts $file} msg]} {
        puts "==== vlog FAILED for $file ===="
        puts $msg
        set ::comp_failed 1
    }
}

# 重新建库
catch {vdel -lib $LIB_NAME -all}
vlib $LIB_NAME
vmap $LIB_NAME $LIB_NAME

# 编译：源文件用 Verilog，testbench 用 SystemVerilog
compile_one "$SRC_DIR_GAME/lfsr16.v" "+acc"
compile_one "$SRC_DIR_GAME/fruit_placer.v" "+acc"
compile_one "$TB_DIR/tb_fruit_placer.v" "-sv +acc"

# 如果有编译错误，就不要起仿真；留在 Transcript 里看错误
if {$comp_failed} {
    puts ">>> Compilation had errors. Fix them and re-run this script."
    return
}

# 启动仿真
vsim -voptargs="+acc" $LIB_NAME.$TOP_TB

# 波形
radix -unsigned
log -r /*
add wave -noupdate -r sim:/$TOP_TB/*
add wave -noupdate -r sim:/$TOP_TB/dut_best/*
add wave -noupdate -r sim:/$TOP_TB/dut_fallback/*

# 运行到结束（由 $finish/$fatal 控制）；如需固定时长可改 run 10 ms
run -all
# ====================================================================
