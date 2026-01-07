class xs_env_cfg extends uvm_object;
    string isa = "RV64IMAFDC";  // 默认ISA配置
    string bootargs = "";       // 启动参数
    string elf_path;            // ELF文件路径

    `uvm_object_utils(xs_env_cfg)

    function new(string name = "riscv_refm_config");
        super.new(name);
    endfunction
endclass

