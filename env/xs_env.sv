class xs_env extends uvm_env;
  `uvm_component_utils(xs_env)

  // 接口句柄
  virtual xs_top_if vif;


  // 监测器与计分板
  xs_monitor monitor;
  xs_scoreboard sb;

  function new(string name = "xs_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // 获取虚拟接口
    if (!uvm_config_db#(virtual xs_top_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF", "Failed to get virtual interface")
    end
    // 实例化组件
    monitor = xs_top_monitor::type_id::create("monitor", this);
    sb = xs_top_scoreboard::type_id::create("sb", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // 连接监测器到计分板
    monitor.item_collected_port.connect(sb.item_collected_export);
    // 绑定接口到代理
    memory_axi_agent.vif = vif;
    peripheral_axi_agent.vif = vif;
    dma_axi_agent.vif = vif;
  endfunction
endclass



