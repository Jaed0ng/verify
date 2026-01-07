interface xs_top_if;
  // 时钟与复位
  logic io_clock;
  logic io_reset;
  logic io_rtc_clock;

  // NMI中断
  logic nmi_0_0;
  logic nmi_0_1;

  // DMA AXI4接口（主设备）
  // AW通道
  logic        dma_awready;
  logic        dma_awvalid;
  logic [13:0] dma_awid;
  logic [47:0] dma_awaddr;
  logic [7:0]  dma_awlen;
  logic [2:0]  dma_awsize;
  logic [1:0]  dma_awburst;
  logic        dma_awlock;
  logic [3:0]  dma_awcache;
  logic [2:0]  dma_awprot;
  logic [3:0]  dma_awqos;
  // W通道
  logic        dma_wready;
  logic        dma_wvalid;
  logic [255:0]dma_wdata;
  logic [31:0] dma_wstrb;
  logic        dma_wlast;
  // B通道
  logic        dma_bready;
  logic        dma_bvalid;
  logic [13:0] dma_bid;
  logic [1:0]  dma_bresp;
  // AR通道
  logic        dma_arready;
  logic        dma_arvalid;
  logic [13:0] dma_arid;
  logic [47:0] dma_araddr;
  logic [7:0]  dma_arlen;
  logic [2:0]  dma_arsize;
  logic [1:0]  dma_arburst;
  logic        dma_arlock;
  logic [3:0]  dma_arcache;
  logic [2:0]  dma_arprot;
  logic [3:0]  dma_arqos;
  // R通道
  logic        dma_rready;
  logic        dma_rvalid;
  logic [13:0] dma_rid;
  logic [255:0]dma_rdata;
  logic [1:0]  dma_rresp;
  logic        dma_rlast;

  // 外设AXI4接口（从设备）
  logic        peripheral_awready;
  logic        peripheral_awvalid;
  logic [1:0]  peripheral_awid;
  logic [30:0] peripheral_awaddr;
  logic [7:0]  peripheral_awlen;
  logic [2:0]  peripheral_awsize;
  logic [1:0]  peripheral_awburst;
  logic        peripheral_awlock;
  logic [3:0]  peripheral_awcache;
  logic [2:0]  peripheral_awprot;
  logic [3:0]  peripheral_awqos;
  logic        peripheral_wready;
  logic        peripheral_wvalid;
  logic [63:0] peripheral_wdata;
  logic [7:0]  peripheral_wstrb;
  logic        peripheral_wlast;
  logic        peripheral_bready;
  logic        peripheral_bvalid;
  logic [1:0]  peripheral_bid;
  logic [1:0]  peripheral_bresp;
  logic        peripheral_arready;
  logic        peripheral_arvalid;
  logic [1:0]  peripheral_arid;
  logic [30:0] peripheral_araddr;
  logic [7:0]  peripheral_arlen;
  logic [2:0]  peripheral_arsize;
  logic [1:0]  peripheral_arburst;
  logic        peripheral_arlock;
  logic [3:0]  peripheral_arcache;
  logic [2:0]  peripheral_arprot;
  logic [3:0]  peripheral_arqos;
  logic        peripheral_rready;
  logic        peripheral_rvalid;
  logic [1:0]  peripheral_rid;
  logic [63:0] peripheral_rdata;
  logic [1:0]  peripheral_rresp;
  logic        peripheral_rlast;

  // 内存AXI4接口（从设备）
  logic        memory_awready;
  logic        memory_awvalid;
  logic [13:0] memory_awid;
  logic [47:0] memory_awaddr;
  logic [7:0]  memory_awlen;
  logic [2:0]  memory_awsize;
  logic [1:0]  memory_awburst;
  logic        memory_awlock;
  logic [3:0]  memory_awcache;
  logic [2:0]  memory_awprot;
  logic [3:0]  memory_awqos;
  logic        memory_wready;
  logic        memory_wvalid;
  logic [255:0]memory_wdata;
  logic [31:0] memory_wstrb;
  logic        memory_wlast;
  logic        memory_bready;
  logic        memory_bvalid;
  logic [13:0] memory_bid;
  logic [1:0]  memory_bresp;
  logic        memory_arready;
  logic        memory_arvalid;
  logic [13:0] memory_arid;
  logic [47:0] memory_araddr;
  logic [7:0]  memory_arlen;
  logic [2:0]  memory_arsize;
  logic [1:0]  memory_arburst;
  logic        memory_arlock;
  logic [3:0]  memory_arcache;
  logic [2:0]  memory_arprot;
  logic [3:0]  memory_arqos;
  logic        memory_rready;
  logic        memory_rvalid;
  logic [13:0] memory_rid;
  logic [255:0]memory_rdata;
  logic [1:0]  memory_rresp;
  logic        memory_rlast;

  // 其他关键信号
  logic [15:0] io_sram_config;
  logic [63:0] io_extIntrs;
  logic        io_pll0_lock;
  logic [31:0] io_pll0_ctrl_0;
  logic [31:0] io_pll0_ctrl_1;
  logic [31:0] io_pll0_ctrl_2;
  logic [31:0] io_pll0_ctrl_3;
  logic [31:0] io_pll0_ctrl_4;
  logic [31:0] io_pll0_ctrl_5;
  logic        io_systemjtag_jtag_TCK;
  logic        io_systemjtag_jtag_TMS;
  logic        io_systemjtag_jtag_TDI;
  logic        io_systemjtag_jtag_TDO_data;
  logic        io_systemjtag_jtag_TDO_driven;
  logic        io_systemjtag_reset;
  logic [10:0] io_systemjtag_mfr_id;
  logic [15:0] io_systemjtag_part_number;
  logic [3:0]  io_systemjtag_version;
  logic        io_debug_reset;
  logic [47:0] io_riscv_rst_vec_0;
  logic        io_riscv_halt_0;
  logic        io_riscv_critical_error_0;

  // 时钟生成
  initial begin
    io_clock = 1'b0;
    forever #10 io_clock = ~io_clock; // 50MHz时钟
  end

  initial begin
    io_rtc_clock = 1'b0;
    forever #100 io_rtc_clock = ~io_rtc_clock; // 5MHz RTC时钟
  end

  // 复位序列
  task reset();
    io_reset = 1'b1;
    repeat(10) @(posedge io_clock);
    io_reset = 1'b0;
    $display("Reset released at time %0t", $time);
  endtask
endinterface

