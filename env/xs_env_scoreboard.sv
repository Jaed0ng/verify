// 计分板：基础功能检查
class xs_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(xs_scoreboard)
  uvm_analysis_imp#(uvm_sequence_item, xs_top_scoreboard) item_collected_export;

  function new(string name = "xs_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    item_collected_export = new("item_collected_export", this);
  endfunction

  virtual function void write(uvm_sequence_item t);
    // 可扩展：对比DUT输出与参考模型结果
    // 此处先实现基础断言检查
    if (vif.io_riscv_critical_error_0) begin
      `uvm_error("SCOREBOARD", "Core critical error detected!")
    end
  endfunction
endclass


