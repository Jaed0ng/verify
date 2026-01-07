class xs_env_transaction extends uvm_sequence_item;
    `uvm_object_utils(xs_env_transaction)

    trans_kind_e kind;
    bit [63:0] addr;   // 寄存器号或内存地址
    bit [63:0] data;   // 数据
    int size;          // 内存操作大小（1/2/4/8）
    int count;         // 步骤数量（用于STEP类型）
    bit [63:0] pc;     // 程序计数器（输出）

    // WB 核心字段
    bit                wb_valid;       // 写回有效
    bit [7:0]         pdest;          // 目标寄存器（整数/浮点/向量）
    bit [127:0]       wb_data;        // 写回数据（兼容向量127位、整数64位）
    bit [23:0]        exception_vec;   // 异常标记
    bit                is_int;         // 整数写回标记
    bit                is_fp;          // 浮点写回标记
    bit                is_vec;         // 向量写回标记
    bit                vecWen;         // 向量寄存器写使能
    bit                vlWen;          // 向量长度寄存器写使能
    bit [5:0]         rob_idx;        // ROB 索引（关联事务）
    function new(string name = "xs_env_transaction");
        super.new(name);
    endfunction

    virtual function string convert2string();
        string s;
        case (kind)
            REG_READ:  s = $sformatf("REG_READ: reg=%0d", addr);
            REG_WRITE: s = $sformatf("REG_WRITE: reg=%0d, data=0x%0h", addr, data);
            MEM_READ:  s = $sformatf("MEM_READ: addr=0x%0h, size=%0d", addr, size);
            MEM_WRITE: s = $sformatf("MEM_WRITE: addr=0x%0h, size=%0d, data=0x%0h", addr, size, data);
            STEP:      s = $sformatf("STEP: count=%0d, pc=0x%0h", count, pc);
        endcase
        return s;
    endfunction
endclass
