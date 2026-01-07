class xs_env_refm extends uvm_component;
    `uvm_component_utils(xs_env_refm)

    // 配置信息
    xs_env_refm_config cfg;

    // DPI-C 函数导入（封装在类内部，外部task无需直接暴露DPI）
    import "DPI-C" function int spike_init(input string isa, input string bootargs);
    import "DPI-C" function int spike_load_elf(input string elf_path);
    import "DPI-C" function int spike_step();
    import "DPI-C" function bit[63:0] spike_get_reg(input int reg_num);
    import "DPI-C" function void spike_set_reg(input int reg_num, input bit[63:0] value);
    import "DPI-C" function bit[63:0] spike_read_mem(input bit[63:0] addr, input int size);
    import "DPI-C" function void spike_write_mem(input bit[63:0] addr, input int size, input bit[63:0] value);
    import "DPI-C" function void spike_close();

    // 分析接口与FIFO（保持不变）
    uvm_analysis_export #(riscv_transaction) refm_export;
    uvm_tlm_analysis_fifo #(riscv_transaction) trans_fifo;

    function new(string name = "xs_env_refm", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // 构建阶段（保持不变：初始化配置、FIFO、Spike）
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // 获取配置
        if (!uvm_config_db#(xs_env_refm_config)::get(this, "", "cfg", cfg)) begin
            `uvm_info(get_full_name(), "Using default configuration", UVM_LOW)
            cfg = xs_env_refm_config::type_id::create("cfg");
        end
        
        // 初始化FIFO和导出
        refm_export = new("refm_export", this);
        trans_fifo = new("trans_fifo", this);
        
        // 初始化Spike
        if (spike_init(cfg.isa, cfg.bootargs) != 0) begin
            `uvm_fatal(get_full_name(), "Failed to initialize Spike simulator")
        end
        
        // 加载ELF文件（如果指定）
        if (cfg.elf_path != "") begin
            if (spike_load_elf(cfg.elf_path) != 0) begin
                `uvm_fatal(get_full_name(), $sformatf("Failed to load ELF file: %s", cfg.elf_path))
            end
        end
    endfunction

    // 运行阶段：仅调用外部task，不内部实现逻辑
    virtual task run_phase(uvm_phase phase);
        xs_env_refm_core_task(cfg, get_full_name(), trans_fifo);
    endtask

    // 连接阶段（保持不变）
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        refm_export.connect(trans_fifo.analysis_export);
    endfunction

    // 结束阶段（保持不变：关闭Spike）
    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        spike_close();
        `uvm_info(get_full_name(), "Spike simulator closed", UVM_LOW)
    endfunction

    extern task xs_env_refm_core_task(xs_env_refm_config cfg, string refm_name, 
                          uvm_tlm_analysis_fifo #(riscv_transaction) trans_fifo);

endclass

// 外部task实现：核心事务处理逻辑（不在refm类内部）
task xs_env_refm_core_task(xs_env_refm_config cfg, string refm_name, 
                          uvm_tlm_analysis_fifo #(riscv_transaction) trans_fifo);
    // 导入DPI函数（外部task需重新导入，或通过类的静态成员访问，此处直接导入更简洁）
    import "DPI-C" function int spike_step();
    import "DPI-C" function bit[63:0] spike_get_reg(input int reg_num);
    import "DPI-C" function void spike_set_reg(input int reg_num, input bit[63:0] value);
    import "DPI-C" function bit[63:0] spike_read_mem(input bit[63:0] addr, input int size);
    import "DPI-C" function void spike_write_mem(input bit[63:0] addr, input int size, input bit[63:0] value);

    xs_env_transaction trans;
    
    forever begin
        // 从FIFO获取事务
        trans_fifo.get(trans);
        
        // 处理事务
        case (trans.kind)
            REG_WRITE: begin
                spike_set_reg(trans.addr, trans.data);
                `uvm_info(refm_name, 
                    $sformatf("Wrote register %0d: 0x%0h", trans.addr, trans.data), UVM_HIGH)
            end
            REG_READ: begin
                trans.data = spike_get_reg(trans.addr);
                `uvm_info(refm_name, 
                    $sformatf("Read register %0d: 0x%0h", trans.addr, trans.data), UVM_HIGH)
            end
            MEM_WRITE: begin
                spike_write_mem(trans.addr, trans.size, trans.data);
                `uvm_info(refm_name, 
                    $sformatf("Wrote memory 0x%0h (size %0d): 0x%0h", 
                    trans.addr, trans.size, trans.data), UVM_HIGH)
            end
            MEM_READ: begin
                trans.data = spike_read_mem(trans.addr, trans.size);
                `uvm_info(refm_name, 
                    $sformatf("Read memory 0x%0h (size %0d): 0x%0h", 
                    trans.addr, trans.size, trans.data), UVM_HIGH)
            end
            STEP: begin
                // 执行指定数量的指令
                for (int i = 0; i < trans.count; i++) begin
                    if (spike_step() != 0) begin
                        `uvm_error(refm_name, $sformatf("Step %0d failed", i))
                    end
                    // 获取当前PC（x0对应PC寄存器，根据Spike定义调整）
                    trans.pc = spike_get_reg(0);
                    `uvm_info(refm_name, 
                        $sformatf("Step %0d, PC: 0x%0h", i, trans.pc), UVM_MEDIUM)
                end
            end
            default: `uvm_warning(refm_name, $sformatf("Unknown transaction type: %0s", trans.kind.name()))
        endcase
        
        // 可在此处将处理后的事务发送到比较器（如需）
        // trans_fifo.write(trans); // 或连接到scoreboard的分析端口
    end
endtask
