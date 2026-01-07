#include "svdpi.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <riscv/sim.h>
#include <riscv/processor.h>

// 全局仿真器实例
static sim_t* spike_sim = nullptr;
static processor_t* spike_core = nullptr;

// 初始化Spike模拟器
extern "C" int spike_init(const char* isa, const char* bootargs) {
    if (spike_sim != nullptr) {
        fprintf(stderr, "Spike already initialized\n");
        return -1;
    }

    try {
        cfg_t cfg;
        cfg.isa = isa;
        cfg.bootargs = bootargs;
        cfg.mem_layout = {mem_cfg_t(0x80000000, 0x10000000)}; // 1GB内存

        std::vector<device_factory_sargs_t> plugin_devices;
        std::vector<std::string> htif_args;
        debug_module_config_t dm_config;

        std::vector<std::pair<reg_t, abstract_mem_t*>> mems;
        for (const auto& cfg : cfg.mem_layout) {
            mems.emplace_back(cfg.get_base(), new mem_t(cfg.get_size()));
        }

        spike_sim = new sim_t(&cfg, false, mems, plugin_devices, htif_args, 
                             dm_config, nullptr, true, nullptr, false, nullptr, std::nullopt);
        spike_core = spike_sim->get_core(0);
        
        return 0;
    } catch (const std::exception& e) {
        fprintf(stderr, "Spike initialization failed: %s\n", e.what());
        return -1;
    }
}

// 加载ELF文件
extern "C" int spike_load_elf(const char* elf_path) {
    if (spike_sim == nullptr) {
        fprintf(stderr, "Spike not initialized\n");
        return -1;
    }

    try {
        spike_sim->load_elf(elf_path);
        return 0;
    } catch (const std::exception& e) {
        fprintf(stderr, "Failed to load ELF: %s\n", e.what());
        return -1;
    }
}

// 执行一条指令
extern "C" int spike_step() {
    if (spike_sim == nullptr || spike_core == nullptr) {
        fprintf(stderr, "Spike not initialized\n");
        return -1;
    }

    try {
        spike_core->step();
        return 0;
    } catch (const std::exception& e) {
        fprintf(stderr, "Step failed: %s\n", e.what());
        return -1;
    }
}

// 获取寄存器值
extern "C" uint64_t spike_get_reg(int reg_num) {
    if (spike_core == nullptr) {
        fprintf(stderr, "Spike not initialized\n");
        return 0;
    }

    if (reg_num < 0 || reg_num >= 32) {
        fprintf(stderr, "Invalid register number\n");
        return 0;
    }

    return spike_core->get_reg(reg_num);
}

// 设置寄存器值
extern "C" void spike_set_reg(int reg_num, uint64_t value) {
    if (spike_core == nullptr) {
        fprintf(stderr, "Spike not initialized\n");
        return;
    }

    if (reg_num < 0 || reg_num >= 32) {
        fprintf(stderr, "Invalid register number\n");
        return;
    }

    spike_core->set_reg(reg_num, value);
}

// 读取内存
extern "C" uint64_t spike_read_mem(uint64_t addr, int size) {
    if (spike_sim == nullptr) {
        fprintf(stderr, "Spike not initialized\n");
        return 0;
    }

    try {
        switch (size) {
            case 1: return spike_sim->debug_read_mem(addr, 1);
            case 2: return spike_sim->debug_read_mem(addr, 2);
            case 4: return spike_sim->debug_read_mem(addr, 4);
            case 8: return spike_sim->debug_read_mem(addr, 8);
            default:
                fprintf(stderr, "Invalid memory access size\n");
                return 0;
        }
    } catch (const std::exception& e) {
        fprintf(stderr, "Memory read failed: %s\n", e.what());
        return 0;
    }
}

// 写入内存
extern "C" void spike_write_mem(uint64_t addr, int size, uint64_t value) {
    if (spike_sim == nullptr) {
        fprintf(stderr, "Spike not initialized\n");
        return;
    }

    try {
        switch (size) {
            case 1: spike_sim->debug_write_mem(addr, 1, value); break;
            case 2: spike_sim->debug_write_mem(addr, 2, value); break;
            case 4: spike_sim->debug_write_mem(addr, 4, value); break;
            case 8: spike_sim->debug_write_mem(addr, 8, value); break;
            default:
                fprintf(stderr, "Invalid memory access size\n");
        }
    } catch (const std::exception& e) {
        fprintf(stderr, "Memory write failed: %s\n", e.what());
    }
}

// 关闭Spike模拟器
extern "C" void spike_close() {
    if (spike_sim != nullptr) {
        delete spike_sim;
        spike_sim = nullptr;
        spike_core = nullptr;
    }
}

// DPI导出声明
extern "C" {
    DPI_FUNCTION void spike_init(const char* isa, const char* bootargs);
    DPI_FUNCTION void spike_load_elf(const char* elf_path);
    DPI_FUNCTION void spike_step();
    DPI_FUNCTION uint64_t spike_get_reg(int reg_num);
    DPI_FUNCTION void spike_set_reg(int reg_num, uint64_t value);
    DPI_FUNCTION uint64_t spike_read_mem(uint64_t addr, int size);
    DPI_FUNCTION void spike_write_mem(uint64_t addr, int size, uint64_t value);
    DPI_FUNCTION void spike_close();
}

