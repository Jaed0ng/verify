#---------------------------------------
# 项目基础配置
#---------------------------------------
PRJ_NAME      = xiangshan_uvm
TB_TOP        ?= xs_top          # UVM测试平台顶层
OUT           = out              # 输出目录根路径
SEED          = 1                # 仿真种子
GUI           ?= 0               # 是否启用GUI（0/1）
COV           ?= 0               # 是否收集覆盖率（0/1）
VERBOSITY     = UVM_LOW          # UVM日志级别
TEST          ?= xs_base_test    # 默认测试用例
SIM_DIR       = $(OUT)/sim/$(TEST)_$(SEED)  # 仿真工作目录
MAX_INSTR     ?= 1000000         # 最大指令数限制

#---------------------------------------
# 工具链配置
#---------------------------------------
VCS           ?= vcs
VERDI_HOME    ?= $(shell echo $VERDI_HOME)
SPIKE_HOME    ?= ../spike  # Spike安装路径
RISCV_GCC     ?= riscv64-unknown-elf-gcc # RISC-V编译器
MAKEFLAGS     += -j$(shell nproc)        # 并行编译

#---------------------------------------
# 路径配置（根据实际项目结构调整）
#---------------------------------------
XIANGSHAN_HOME ?= $(shell cd .. && pwd)  # 香山项目根目录
RTL_DIR        = $(XIANGSHAN_HOME)/build/rtl  # 生成的Verilog目录
UVM_ENV_DIR    = ../env              # UVM环境目录（用户自定义）
SPIKE_DPI_DIR  = ../dpi      # Spike DPI接口目录
TEST_PROGS_DIR = $(XIANGSHAN_HOME)/ready-to-run  # 测试程序目录

#---------------------------------------
# 编译选项
#---------------------------------------
# 宏定义：启用Spike对比、香山配置等
DEFINES = +define+SPIKE_DPI \
          +define+UVM_1_2 \
          +define+MAX_INSTR=$(MAX_INSTR) \
          +define+DEBUG=$(GUI)

# VCS编译选项
VCS_COMP_OPTS = -sverilog -full64 -kdb -debug_access+all \
                -ntb_opts uvm-1.2 \
                +incdir+$(UVM_ENV_DIR)/{env,seq,tests,tb} \
                +incdir+$(RTL_DIR) \
                -l $(OUT)/log/compile.log

# VCS链接选项（包含Spike DPI）
VCS_ELAB_OPTS = -full64 -top $(TB_TOP) \
                -o $(OUT)/obj/$(TB_TOP).simv \
                -LDFLAGS "-Wl,--no-as-needed" \
                -debug_access+all \
                -l $(OUT)/log/elab.log \
                $(SPIKE_DPI_LIBS) \
                -P $(VERDI_HOME)/share/PLI/VCS/linux64/novas.tab \
                $(VERDI_HOME)/share/PLI/VCS/linux64/pli.a

# Spike DPI编译配置
SPIKE_DPI_CFLAGS = -I$(SPIKE_HOME)/include \
                   -I$(SPIKE_DPI_DIR) \
                   -fPIC -shared
SPIKE_DPI_LIBS = $(SPIKE_DPI_DIR)/spike_dpi.so \
                 -L$(SPIKE_HOME)/lib -lriscv -lfesvr -lsoftfloat

# 覆盖率选项
ifeq ($(COV),1)
VCS_COMP_OPTS += -cm line+cond+fsm+tgl+branch
VCS_ELAB_OPTS += -cm line+cond+fsm+tgl+branch -cm_dir $(OUT)/cov.vdb
RUN_OPTS      += -cm line+cond+fsm+tgl+branch -cm_dir $(OUT)/cov.vdb
endif

#---------------------------------------
# 文件列表（根据实际项目补充）
#---------------------------------------
# 香山RTL文件（通过生成的filelist获取）
RTL_FILES = $(shell cat $(RTL_DIR)/filelist.f)

# UVM环境文件
UVM_FILES = $(wildcard $(UVM_ENV_DIR)/env/*.sv) \
            $(wildcard $(UVM_ENV_DIR)/seq/*.sv) \
            $(wildcard $(UVM_ENV_DIR)/tests/*.sv) \
			$(UVM_ENV_DIR)/tb/xs_top_if.sv
            $(UVM_ENV_DIR)/tb/$(TB_TOP).sv

#---------------------------------------
# 目标规则
#---------------------------------------
.PHONY: all clean compile elab run run_gui help

# 默认目标：编译+仿真
all: run

# 创建输出目录
$(shell mkdir -p $(OUT)/{log,obj,sim} $(SIM_DIR))

# 编译Spike DPI接口
$(SPIKE_DPI_DIR)/spike_dpi.so: $(SPIKE_DPI_DIR)/spike_dpi.c
	$(CC) $(SPIKE_DPI_CFLAGS) $< -o $@ -L$(SPIKE_HOME)/lib -lriscv -lfesvr

# 编译RTL和UVM环境
compile: $(SPIKE_DPI_DIR)/spike_dpi.so
	$(VCS) $(VCS_COMP_OPTS) $(DEFINES) \
		$(RTL_FILES) $(UVM_FILES)

#  elaboration（生成仿真器）
elab: compile
	$(VCS) $(VCS_ELAB_OPTS)

# 运行仿真
run: elab
	@echo "Running test: $(TEST) with seed: $(SEED)"
	cd $(SIM_DIR) && \
	$(OUT)/obj/$(TB_TOP).simv +UVM_TESTNAME=$(TEST) \
	+UVM_VERBOSITY=$(VERBOSITY) \
	+seed=$(SEED) \
	$(RUN_OPTS) \
	-l $(SIM_DIR)/sim.log

# 带GUI运行（Verdi）
run_gui: elab
	cd $(SIM_DIR) && \
	$(OUT)/obj/$(TB_TOP).simv +UVM_TESTNAME=$(TEST) \
	+UVM_VERBOSITY=$(VERBOSITY) \
	+seed=$(SEED) \
	$(RUN_OPTS) \
	-gui=verdi \
	-l $(SIM_DIR)/sim_gui.log

# 清理
clean:
	rm -rf $(OUT) *.log *.vpd *.fsdb \
		   csrc simv* ucli.key vc_hdrs.h \
		   DVEfiles novas.* urgReport

# 帮助信息
help:
	@echo "XiangShan UVM Verification Makefile"
	@echo "Usage:"
	@echo "  make [TARGET] [OPTIONS]"
	@echo "Targets:"
	@echo "  all       - 完整流程（编译+仿真）"
	@echo "  compile   - 编译RTL和UVM环境"
	@echo "  elab      - 生成仿真器"
	@echo "  run       - 运行仿真"
	@echo "  run_gui   - 带Verdi GUI运行仿真"
	@echo "  clean     - 清理输出文件"
	@echo "Options:"
	@echo "  TEST=xxx      - 指定UVM测试用例（默认: xs_base_test）"
	@echo "  SEED=xxx      - 指定仿真种子（默认: 1）"
	@echo "  GUI=1         - 启用GUI模式（默认: 0）"
	@echo "  COV=1         - 启用覆盖率收集（默认: 0）"
	@echo "  MAX_INSTR=xxx - 最大指令数限制（默认: 1000000）"

