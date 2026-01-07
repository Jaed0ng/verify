// 监测器：采集DUT关键信号
class xs_monitor extends uvm_monitor;
  `uvm_component_utils(xs_top_monitor)
  uvm_analysis_port#(uvm_sequence_item) item_collected_port;
  virtual xs_top_if vif;

  function new(string name = "xs_top_monitor", uvm_component parent = null);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever @(posedge vif.io_clock) begin
      if (!vif.io_reset) begin
        // 采集内存AXI4接口事务
        if (vif.memory_arvalid && vif.memory_arready) begin
          `uvm_info("MONITOR", $sformatf("Memory AR transaction: addr=0x%h, id=%h",
            vif.memory_araddr, vif.memory_arid), UVM_MEDIUM)
        end
        // 采集外设AXI4接口事务
        if (vif.peripheral_wvalid && vif.peripheral_wready) begin
          `uvm_info("MONITOR", $sformatf("Peripheral W transaction: data=0x%h, strb=0x%h",
            vif.peripheral_wdata, vif.peripheral_wstrb), UVM_MEDIUM)
        end
        // 采集核心状态信号
        if (vif.io_riscv_halt_0) begin
          `uvm_info("MONITOR", "Core halted", UVM_LOW)
        end
      end
    end
  endtask
endclass

