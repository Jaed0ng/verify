virtual class xs_base_test extends uvm_test;

  xs_env env;
  xs_env_config cfg;
  
  virtual chip_env_if test_vif;                           
  int ddr_en = 1;

  function new(string name, uvm_component parent=null);
    super.new(name, parent);
  endfunction: new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

     if (!uvm_config_db#(virtual chip_env_if)::get(this, "", "test_vif", test_vif)) begin
      `uvm_fatal("GETCFG", "NO top virtual chip_env_if is top down set, vif is null")
    end
    // top level config object creation

    do_config();

    // config top down set
    uvm_config_db#(chip_env_config)::set(this, "env", "cfg", cfg);

    // top level environment creation
    env = chip_env_env::type_id::create("env", this);

   endfunction: build_phase

  function void connect_phase(uvm_phase phase);
  endfunction: connect_phase

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_root uvm_top;
    super.end_of_elaboration_phase(phase);
  endfunction

  virtual task reset_phase(uvm_phase phase);
    super.reset_phase(phase);
    phase.raise_objection(this);
    phase.drop_objection(this);
  endtask

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    env.vif.clk_enable(1);
    //decode the CPU boot mode as the simulation command line(BOOT_MODE)
    this.get_boot_mode();
    //do DUT PAD initial
    this.do_init_pads();
    //Cfg the pll's reference clk and traget work freq(800M/1066Mhz)
    this.do_init_pll();
    //Add ddr traning paramater cfg for ddr boot mode(Add by GaoTianYi)
    end
    //load program into flash/sram or ddr in custom boot
    this.load_program();
    if(dbg_cfg.custom_boot_mode==0) begin
        this.custom_boot();
    end
    phase.drop_objection(this);
  endtask: run_phase

  /**
   * Calculate the pass or fail status for the test in the final phase method of the
   * test. If a UVM_FATAL, UVM_ERROR, or a UVM_WARNING message has been generated the
   * test will fail.
   */
  function void final_phase(uvm_phase phase);
    uvm_report_server svr;
    `uvm_info("final_phase", "Entered ...",UVM_LOW)
    super.final_phase(phase);
    svr = uvm_report_server::get_server();
    if ((svr.get_severity_count(UVM_FATAL) + 
      svr.get_severity_count(UVM_ERROR)) > 0)
      `uvm_error("final_phase", "\nSvtTestEpilog: Failed\n")
    else
      `uvm_info("final_phase", "\nSvtTestEpilog: Passed\n", UVM_NONE)
    `uvm_info("final_phase", "Exited ...",UVM_LOW)
  endfunction


  task do_init_pads();
    //do PAD initial during DUT Powerdown
    env.vif.pad_custom_boot = 1'b0;
    //env.vif.pad_gpio = 8'd0;
    env.vif.pad_ext_interrupts = 1'b0;
    env.vif.pad_nmi_fire = 1'b0;
    //for pll
    env.vif.pad_pll_reset = 1;
    env.vif.pad_pll_bypass = 0;
    env.vif.pad_pll_pd = 1;
    env.vif.pad_pll_delaysel = 5'd0;
    `ifdef GATE_SIM
         //do gls initial during DUT Powerdown for x state
         force `DUT.iocell_reset.PAD = 1'b1;
         force `DUT.facriALLSyncPLL.xd_pll.clko0 = 1'b0;
         force `DUT.iocell_ddr_jtag_trst_n.PAD = 1'b0;
         force `DUT.system.qspiClockDomainWrapper.qspi_0.mac.cs_dflt_0_reg.QN = 1'b1;
         force `DUT.pad_qspi0_cs = 1'b1;
         force `DUT.pad_jtag_tck = 1'b0;
         //ddr power init
         #10ns;
         release `DUT.facriALLSyncPLL.xd_pll.clko0;
         release `DUT.iocell_reset.PAD;
         release `DUT.system.qspiClockDomainWrapper.qspi_0.mac.cs_dflt_0_reg.QN;
         release `DUT.pad_qspi0_cs;
         release `DUT.pad_jtag_tck;
    `endif
     //disable DFT mode
     env.vif.pad_dft_mode = 1'b0;
     env.vif.pad_dft_select = 1'b0;
  endtask

  task do_init_pll();

    #($urandom_range(0,'d10));
    if(cfg.boot_mode == "ddr")//cfg for input clk jitter
        env.vif.jt_enable(0);
    else begin
      if(ddr_en == 0)
        env.vif.jt_enable(1);
      else
        env.vif.jt_enable(0);
    end

    `ifdef GATE_SIM //netlist test clk only 1066
        assert(cfg.pll_cfg.randomize with {
            freq_out_int == 1066;});
    `else
        `ifdef UART_ENV//zhangning add
            assert(cfg.pll_cfg.randomize with {
                freq_out_int == 1066;});
        `else
            `ifdef CLK1066
                assert(cfg.pll_cfg.randomize with {
                    if(cfg.boot_mode == "ddr") {
                        freq_out_int == 1066;//ddr cfg
                    } else {
                        if(ddr_en == 0)
                            freq_out_int inside {800,933,1066};//clk output freq 
                        else
                            freq_out_int == 1066;
                    }
                });
            `elsif CLK933
                assert(cfg.pll_cfg.randomize with {
                    if(cfg.boot_mode == "ddr") {
                        freq_out_int == 933;//ddr cfg
                    } else {
                        if(ddr_en == 0)
                            freq_out_int inside {800,933,1066};//clk output freq 
                        else
                            freq_out_int == 933;
                    }
                });
            `else
                assert(cfg.pll_cfg.randomize with {
                    if(cfg.boot_mode == "ddr") {
                        freq_out_int == 800;
                    } else {
                        if(ddr_en == 0)
                            freq_out_int inside {800,933,1066};
                        else
                            freq_out_int == 800;
                    }
                });
            `endif
        `endif
    `endif

    $display("cfg.pll_cfg.freq_in is %0d",cfg.pll_cfg.freq_in_int);
    $display("cfg.pll_cfg.freq_out is %0d",cfg.pll_cfg.freq_out_int);
    $display("cfg.pll_cfg.cpp_bias is %0d",cfg.pll_cfg.cpp_bias);    
    $display("cfg.pll_cfg.postdiv0 is %0d",cfg.pll_cfg.postdiv0);
    $display("cfg.pll_cfg.fbclk_delaysel is %0d",cfg.pll_cfg.fbclk_delaysel);     
    $display("cfg.pll_cfg.fbdiv is %0d",cfg.pll_cfg.fbdiv);
    $display("cfg.pll_cfg.prediv is %0d",cfg.pll_cfg.prediv);

    //connect cfg to interface
    env.vif.pad_pll_cpp_bias=cfg.pll_cfg.cpp_bias;
    env.vif.pad_pll_postdiv0_0=cfg.pll_cfg.postdiv0;    
    env.vif.pad_pll_delaysel=cfg.pll_cfg.fbclk_delaysel;//input
    env.vif.pad_pll_fbdiv=cfg.pll_cfg.fbdiv;
    env.vif.pad_pll_prediv=cfg.pll_cfg.prediv;
    env.vif.set_freq(cfg.pll_cfg.freq_in_int*0.999);
    power_on();
  endtask

  /*
   *Task power_on:
   * Poweron sequence:
   * 1.set pll's pd to 1'b1.
   * 2.Random delay and power on PLL.
   * 3.Random cfg pll_bypass_en before Pll lock(just for pll code coverage)
   * 4.Wait for PLL locked.
   * 5.Set release core reset after random delay.
   * 6.Check the 100M/400M/800M reset after core reset release.
  */
  task power_on();
    real clk_in_start;
    real clk_in_end;
    real clk_in_time;
    int is_bypass_en;
    is_bypass_en  = $urandom_range('d0,'d100);
    
    repeat ($urandom_range('d1,'d5)) @(posedge env.vif.pad_pll_clock);
    env.vif.pad_pll_pd = 1;
    #($urandom_range('d1000,'d2000));
    env.vif.pad_pll_pd = 0;
    //for cov bypass pad toggle-----
    if(is_bypass_en=='d50)begin
        repeat ($urandom_range('d1,'d5)) @(posedge env.vif.pad_pll_clock);
        #($urandom_range('d0,'d11));
        env.vif.pad_pll_bypass =1;
        repeat ($urandom_range('d1,'d5)) @(posedge env.vif.pad_pll_clock);
        clk_in_start=$realtime;
        @(posedge env.vif.pad_pll_clock);
        clk_in_end=$realtime;
        clk_in_time = clk_in_end - clk_in_start;

        if((10**6/(cfg.pll_cfg.freq_in_int*0.999)>clk_in_time-2)&&(10**6/(cfg.pll_cfg.freq_in_int*0.999)<clk_in_time+2))begin
            `uvm_info("power_on",$sformatf("bypass pad clk in : %0t ,act clk in %0t ",clk_in_time,10**6/(cfg.pll_cfg.freq_in_int*0.999)),UVM_LOW);
        end 
        else begin
            `uvm_error("power_on", "bypass pad fail");
            `uvm_info("power_on",$sformatf("bypass pad clk in : %0t ,act clk in %0t ",clk_in_time,10**6/(cfg.pll_cfg.freq_in_int*0.999)),UVM_LOW);       
        end

        repeat (1) @(posedge env.vif.pad_pll_clock);
        env.vif.pad_pll_bypass =0;
    end
    wait(env.vif.pad_pll_lock===1);

    repeat ($urandom_range('d1,'d5)) @(posedge env.vif.pad_pll_clock);
    #($urandom_range('d0,'d100));
    env.vif.pad_pll_reset = 1;           
    #($urandom_range('d0,'d200)); 
    env.vif.pad_pll_reset = 0;
    //reset pad check------------
    `ifndef GATE_SIM
        repeat (2) @(posedge `CLK_100M);
        if((`RST_100M!=1)&&(`RST_400M!=1)&&(`RST_800M!=1))
            `uvm_error("power_on", "reset 1 value fail");
        repeat (3) @(posedge `CLK_100M);
        if((`RST_100M!=0)||(`RST_400M!=0)||(`RST_800M!=0))
            `uvm_error("power_on", "reset 0 value fail"); 
    `else
        repeat (2) @(posedge `CLK_100M);
        if((`RST_100M!=0)&&(`RST_400M!=0)&&(`RST_800M!=0))
            `uvm_error("power_on", "reset 1 value fail");
        repeat (3) @(posedge `CLK_100M);
        if((`RST_100M!=1)||(`RST_400M!=1)||(`RST_800M!=1))
            `uvm_error("power_on", "reset 0 value fail");         
    `endif
 
  endtask

  // Backdoor-load the asm test binary file into the flash memory model
  task load_binary_to_flash();
     string      flash_bin;
      `uvm_info(get_full_name(), $sformatf("Flash bin file init load..."),UVM_LOW);
     if(!$value$plusargs("flash_bin=%s", flash_bin)) begin
        `uvm_fatal(get_full_name(), $sformatf("Cannot open file flash_bin"));
     end
     else begin
       $readmemh(flash_bin,`TOP_TB.flash_model_inst.memory);
       `uvm_info(get_full_name(), $sformatf("Flash bin file %0s init done",flash_bin),UVM_LOW);
     end

  endtask

  // Backdoor-load the test binary file into the sram memory model
  task load_binary_to_sram();
     string     firmware_bin;
     bit[63:0]  data_array[0:(8192*16-1)];
     bit[72-1:0]  sram_bank0[0:(8192-1)];
     bit[72-1:0]  sram_bank1[0:(8192-1)];
     bit[72-1:0]  sram_bank2[0:(8192-1)];
     bit[72-1:0]  sram_bank3[0:(8192-1)];
     bit[72-1:0]  sram_bank4[0:(8192-1)];
     bit[72-1:0]  sram_bank5[0:(8192-1)];
     bit[72-1:0]  sram_bank6[0:(8192-1)];
     bit[72-1:0]  sram_bank7[0:(8192-1)];
     bit[72-1:0]  sram_bank8[0:(8192-1)];
     bit[72-1:0]  sram_bank9[0:(8192-1)];
     bit[72-1:0]  sram_bank10[0:(8192-1)];
     bit[72-1:0]  sram_bank11[0:(8192-1)];
     bit[72-1:0]  sram_bank12[0:(8192-1)];
     bit[72-1:0]  sram_bank13[0:(8192-1)];
     bit[72-1:0]  sram_bank14[0:(8192-1)];
     bit[72-1:0]  sram_bank15[0:(8192-1)];

     integer    fo_handle;
     string     fo_path;
     bit [ 7:0] ecc[16];
     bit [63:0] sram_data[16];

      `uvm_info(get_full_name(), $sformatf("Firmware bin file init load..."),UVM_LOW);
     if(!$value$plusargs("flash_bin=%s", firmware_bin)) begin
        `uvm_fatal(get_full_name(), $sformatf("Cannot open file Firmware_bin"));
     end
     else begin
       $readmemh(firmware_bin,data_array);
     end
     //Read the firmware hex and add ecc to sram content
     for(int i=0; i<2; i++) begin
       for(int j=0; j<8192*1; j=j+1) begin
            for(int z=0; z<1; z++) begin
                sram_data[z] = data_array[i*8192+j+z];
                ecc[z] = get_data_ecc_encoder(sram_data[z]);
            end
            //low_ecc = get_data_ecc_encoder(sram_data[31:0]);
            case(i)
               0: begin sram_bank0[j]  = {ecc[0], sram_data[0]}; end
               1: begin sram_bank1[j]  = {ecc[0], sram_data[0]}; end
               2: begin sram_bank2[j]  = {ecc[0], sram_data[0]}; end
               3: begin sram_bank3[j]  = {ecc[0], sram_data[0]}; end
               4: begin sram_bank4[j]  = {ecc[0], sram_data[0]}; end
               5: begin sram_bank5[j]  = {ecc[0], sram_data[0]}; end
               6: begin sram_bank6[j]  = {ecc[0], sram_data[0]}; end
               7: begin sram_bank7[j]  = {ecc[0], sram_data[0]}; end
               8: begin sram_bank8[j]  = {ecc[0], sram_data[0]}; end
               9: begin sram_bank9[j]  = {ecc[0], sram_data[0]}; end
              10: begin sram_bank10[j] = {ecc[0], sram_data[0]}; end
              11: begin sram_bank11[j] = {ecc[0], sram_data[0]}; end
              12: begin sram_bank12[j] = {ecc[0], sram_data[0]}; end
              13: begin sram_bank13[j] = {ecc[0], sram_data[0]}; end
              14: begin sram_bank14[j] = {ecc[0], sram_data[0]}; end
              15: begin sram_bank15[j] = {ecc[0], sram_data[0]}; end
            endcase
       end
     end

     //Generat the new firmware hex file which are added ecc code
     for(int i=0; i<2; i++) begin
        fo_path = $sformatf("%0s.%0d",firmware_bin, i);
        case(i)
            0: begin $writememb(fo_path, sram_bank0); end
            1: begin $writememb(fo_path, sram_bank1); end
            2: begin $writememb(fo_path, sram_bank2); end
            3: begin $writememb(fo_path, sram_bank3); end
            4: begin $writememb(fo_path, sram_bank4); end
            5: begin $writememb(fo_path, sram_bank5); end
            6: begin $writememb(fo_path, sram_bank6); end
            7: begin $writememb(fo_path, sram_bank7); end
            8: begin $writememb(fo_path, sram_bank8); end
            9: begin $writememb(fo_path, sram_bank9); end
           10: begin $writememb(fo_path,sram_bank10); end
           11: begin $writememb(fo_path,sram_bank11); end
           12: begin $writememb(fo_path,sram_bank12); end
           13: begin $writememb(fo_path,sram_bank13); end
           14: begin $writememb(fo_path,sram_bank14); end
           15: begin $writememb(fo_path,sram_bank15); end
         endcase
     end

     //Preload the generate bin file(with ecc) into the sram memory model
     for(int i=0; i<2; i++) begin
        fo_path = $sformatf("%0s.%0d",firmware_bin, i);
        case(i)
            0: begin `FACRISRAM.facrisram_mem0.loadmem(fo_path); end
            1: begin `FACRISRAM.facrisram_mem1.loadmem(fo_path); end
      //      2: begin `FACRISRAM.facrisram_mem2.loadmem(fo_path); end
      //      3: begin `FACRISRAM.facrisram_mem3.loadmem(fo_path); end
      //      4: begin `FACRISRAM.facrisram_mem4.loadmem(fo_path); end
      //      5: begin `FACRISRAM.facrisram_mem5.loadmem(fo_path); end
      //      6: begin `FACRISRAM.facrisram_mem6.loadmem(fo_path); end
      //      7: begin `FACRISRAM.facrisram_mem7.loadmem(fo_path); end
      //      8: begin `FACRISRAM.facrisram_mem8.loadmem(fo_path); end
      //      9: begin `FACRISRAM.facrisram_mem9.loadmem(fo_path); end
      //     10: begin `FACRISRAM.facrisram_mem10.loadmem(fo_path); end
      //     11: begin `FACRISRAM.facrisram_mem11.loadmem(fo_path); end
      //     12: begin `FACRISRAM.facrisram_mem12.loadmem(fo_path); end
      //     13: begin `FACRISRAM.facrisram_mem13.loadmem(fo_path); end
      //     14: begin `FACRISRAM.facrisram_mem14.loadmem(fo_path); end
      //     15: begin `FACRISRAM.facrisram_mem15.loadmem(fo_path); end
         endcase
     end
  endtask


`ifdef DUMMY_DDR
//inital mmu_ddrmc.
  // Backdoor-load the test binary file into the DDR model when env define DUMMY_DDR
  task load_binary_to_ddr();
	  string firmware_bin, ddr_bin_path, ddr_bin;
    integer  file_handle;

	  if(!$value$plusargs("flash_bin=%s", firmware_bin)) begin
        `uvm_fatal(get_full_name(), $sformatf("Cannot open file Firmware_bin"));
    end
    else begin
      ddr_bin_path=firmware_bin.substr(0,(firmware_bin.len() - 19));
      for(int j=0; j<8; j++) begin
        ddr_bin = $sformatf("%sfirmware_part%0d.hex",ddr_bin_path,j);
        file_handle = $fopen(ddr_bin, "r");
        if(file_handle) begin
          $fclose(file_handle);
          case(j)
    `ifndef GATE_SIM
            0: begin $readmemh(ddr_bin,`TOP_TB.mmu_ddrmc.MEM_BANK[0].bank); end
            1: begin $readmemh(ddr_bin,`TOP_TB.mmu_ddrmc.MEM_BANK[1].bank); end
            2: begin $readmemh(ddr_bin,`TOP_TB.mmu_ddrmc.MEM_BANK[2].bank); end
            3: begin $readmemh(ddr_bin,`TOP_TB.mmu_ddrmc.MEM_BANK[3].bank); end
			4: begin $readmemh(ddr_bin,`TOP_TB.mmu_ddrmc.MEM_BANK[4].bank); end
            5: begin $readmemh(ddr_bin,`TOP_TB.mmu_ddrmc.MEM_BANK[5].bank); end
            6: begin $readmemh(ddr_bin,`TOP_TB.mmu_ddrmc.MEM_BANK[6].bank); end
            7: begin $readmemh(ddr_bin,`TOP_TB.mmu_ddrmc.MEM_BANK[7].bank); end
    `endif
          endcase
        end
      end
      `uvm_info(get_full_name(), $sformatf("Flash bin file %0s init done",firmware_bin),UVM_LOW);
    end
  endtask
`endif

  //Decode the boot_mode and set boot address for spike 
  task get_boot_mode();
     if(!$value$plusargs("boot_mode=%s", cfg.boot_mode)) begin
        `uvm_fatal(get_full_name(), $sformatf("Cannot get boot_mode from env!"));
     end
     else begin
       if(cfg.boot_mode=="sram") begin
       `ifndef GATE_SIM
         //force the counter to speedup simulation and avoid the mem bank init of design
         //force `DUT.system.subsystem_l2_wrapper.tl_ram.scrapingCount = 'h3FFFF;
       `else
         //force the counter to speedup simulation and avoid the mem bank init of design
         force `DUT.system.subsystem_l2_wrapper.tl_ram.scrapingCount_reg_14_.Q = 1'b1;
       `endif
         //update the boot address and mtvec address
         env.core_env.cfg.boot_addr = 64'h1010_0000;
         env.core_env.cfg.start_mtvec = 64'h1010_0000 | 64'h1000;
       end
       else if(cfg.boot_mode=="ddr") begin
         //update the boot address and mtvec address
         env.core_env.cfg.boot_addr = 64'h8000_0000;
         env.core_env.cfg.start_mtvec = 64'h8000_0000 | 64'h1000;
         //Backdoor to force the DDR APB bus during DUMMY_DDR(with boot_mode=ddr)
         `ifndef DUMMY_DDR
            force `DUT.ddrmc.i_psel    = `TOP_TB.top_if.psel     ;
            force `DUT.ddrmc.i_pwrite  = `TOP_TB.top_if.pwrite   ;
            force `DUT.ddrmc.i_penable = `TOP_TB.top_if.penable  ;
            force `DUT.ddrmc.i_paddr   = `TOP_TB.top_if.paddr    ; 
            force `DUT.ddrmc.i_pwdata  = `TOP_TB.top_if.pwdata   ;
         `endif
       end
       else if(cfg.boot_mode=="flash") begin
         //update the boot address and mtvec address during flash bbot mode
         env.core_env.cfg.boot_addr = 64'h2000_0000;
         env.core_env.cfg.start_mtvec = 64'h2000_0000 | 64'h1000;
       end
     end
  endtask
  //load program into flash/sram or ddr in custom boot
  task load_program();
     `uvm_info(get_full_name(), $sformatf("User Program init loading..."),UVM_LOW);
     if(cfg.boot_mode=="flash") begin
       load_binary_to_flash();
     end
     else if(cfg.boot_mode=="sram") begin
       `ifndef GATE_SIM
            wait(`DUT.system.subsystem_l2_wrapper.tl_ram.scrapingDone === 1);
            #10ns;
       `endif
       load_binary_to_sram();
     end
`ifdef DUMMY_DDR
	 else if(cfg.boot_mode=="ddr") begin
       load_binary_to_ddr();
     end
`endif
     `uvm_info(get_full_name(), $sformatf("User Program init loading done"),UVM_LOW);
  endtask

  //wait for rom bootloade done and force the boot address and enter sram/ddr address
  task custom_boot();
    bit[63:0] boot_add_reg;
    `ifndef GATE_SIM
    //wait for rom bootloader done
        wait(`DUT.system.tile_prci_domain.tile_reset_domain.facri_tile.core.io_wfi === 1);
    `else
        wait(`DUT.system.tile_prci_domain.tile_reset_domain.facri_tile.core.csr.reg_wfi_reg.Q === 1);
    `endif
    repeat($urandom_range(10,30)) #1us;
    `uvm_info(get_full_name(), $sformatf("Rom bootloader done"),UVM_LOW);
    env.vif.pad_custom_boot = 1'b1;
    `ifndef GATE_SIM
    wait(`DUT.system.subsystem_cbus.state === 3'd1);
    if(cfg.boot_mode=="sram") begin
      force `DUT.system.subsystem_cbus.coupler_from_port_named_custom_boot_pin_auto_tl_in_a_bits_data = 64'h10100000;
      repeat(2) @(posedge `DUT.system.subsystem_cbus.auto_subsystem_cbus_clock_groups_in_member_subsystem_cbus_0_clock);
      release `DUT.system.subsystem_cbus.coupler_from_port_named_custom_boot_pin_auto_tl_in_a_bits_data;
	  end
    else if(cfg.boot_mode=="ddr") begin
      force `DUT.system.subsystem_cbus.coupler_from_port_named_custom_boot_pin_auto_tl_in_a_bits_data = 64'h80000000;
      repeat(2) @(posedge `DUT.system.subsystem_cbus.auto_subsystem_cbus_clock_groups_in_member_subsystem_cbus_0_clock);
      release `DUT.system.subsystem_cbus.coupler_from_port_named_custom_boot_pin_auto_tl_in_a_bits_data;
    end
    `else
    if(cfg.boot_mode=="sram") begin
      //force `DUT.system.subsystem_cbus.in_xbar.auto_out_a_bits_data = 64'h10100000;
      //repeat(2) @(posedge `DUT.pad_clock);
      //release `DUT.system.subsystem_cbus.in_xbar.auto_out_a_bits_data;
      boot_add_reg = 64'h10100000;
	  end
    else if(cfg.boot_mode=="ddr") begin
      boot_add_reg = 64'h80000000;
      //force `DUT.system.subsystem_cbus.in_xbar.auto_out_a_bits_data = 64'h80000000;
      ////repeat(2) @(posedge `DUT.system.subsystem_cbus.auto_subsystem_cbus_clock_groups_in_member_subsystem_cbus_0_clock);
      //repeat(2) @(posedge `DUT.pad_clock);
      //release `DUT.system.subsystem_cbus.in_xbar.auto_out_a_bits_data;
    end
    if((cfg.boot_mode == "sram") || (cfg.boot_mode == "ddr")) begin
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_63_.Q", boot_add_reg[63]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_62_.Q", boot_add_reg[62]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_61_.Q", boot_add_reg[61]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_60_.Q", boot_add_reg[60]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_59_.Q", boot_add_reg[59]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_58_.Q", boot_add_reg[58]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_57_.Q", boot_add_reg[57]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_56_.Q", boot_add_reg[56]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_55_.Q", boot_add_reg[55]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_54_.Q", boot_add_reg[54]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_53_.Q", boot_add_reg[53]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_52_.Q", boot_add_reg[52]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_51_.Q", boot_add_reg[51]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_50_.Q", boot_add_reg[50]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_49_.Q", boot_add_reg[49]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_48_.Q", boot_add_reg[48]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_47_.Q", boot_add_reg[47]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_46_.Q", boot_add_reg[46]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_45_.Q", boot_add_reg[45]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_44_.Q", boot_add_reg[44]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_43_.Q", boot_add_reg[43]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_42_.Q", boot_add_reg[42]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_41_.Q", boot_add_reg[41]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_40_.Q", boot_add_reg[40]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_39_.Q", boot_add_reg[39]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_38_.Q", boot_add_reg[38]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_37_.Q", boot_add_reg[37]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_36_.Q", boot_add_reg[36]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_35_.Q", boot_add_reg[35]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_34_.Q", boot_add_reg[34]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_33_.Q", boot_add_reg[33]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_32_.Q", boot_add_reg[32]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_31_.QN", boot_add_reg[31]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_30_.Q", boot_add_reg[30]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_29_.Q", boot_add_reg[29]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_28_.Q", boot_add_reg[28]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_27_.Q", boot_add_reg[27]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_26_.Q", boot_add_reg[26]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_25_.Q", boot_add_reg[25]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_24_.Q", boot_add_reg[24]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_23_.Q", boot_add_reg[23]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_22_.Q", boot_add_reg[22]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_21_.Q", boot_add_reg[21]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_20_.Q", boot_add_reg[20]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_19_.Q", boot_add_reg[19]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_18_.Q", boot_add_reg[18]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_17_.Q", boot_add_reg[17]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_16_.Q", boot_add_reg[16]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_15_.Q", boot_add_reg[15]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_14_.Q", boot_add_reg[14]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_13_.Q", boot_add_reg[13]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_12_.Q", boot_add_reg[12]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_11_.Q", boot_add_reg[11]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_10_.Q", boot_add_reg[10]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_9_.Q", boot_add_reg[9]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_8_.Q", boot_add_reg[8]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_7_.Q", boot_add_reg[7]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_6_.Q", boot_add_reg[6]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_5_.Q", boot_add_reg[5]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_4_.Q", boot_add_reg[4]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_3_.Q", boot_add_reg[3]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_2_.Q", boot_add_reg[2]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_1_.Q", boot_add_reg[1]);
      uvm_hdl_force("chip_env_tb.dut.system.subsystem_cbus.bootAddrReg_reg_0_.Q", boot_add_reg[0]);
    end
    `endif
  endtask

  /*
   * Task wait_test_done:
   * 1.Wait asm test done
   * 1.1 wait for asm or c test send "pass\n" or "fail\n" by gpio during test end
   * 1.2 wait for riscv-dv test enter write_host.
  */
  task wait_test_done();
	string smile, sad;
	smile= {"   -----    \n" ,
		    " /       \\ \n" , 
		    "|   ^ ^   | \n" , 
		    " \\   _   / \n" , 
			"   -----    \n"};
	sad	=  {"   -----    \n" , 
			" /       \\ \n" , 
			"|   x x   | \n" , 
			" \\   ~   / \n" , 
			"   -----    \n"};
	fork
		begin //wait c test pass
			/*wait(`TOP_TB.pad_gpio == 8'h50); //"P" : 80(0x50).
			wait(`TOP_TB.pad_gpio == 8'h41); //"A" : 65(0x41).
			wait(`TOP_TB.pad_gpio == 8'h53); //"S" : 83(0x53).
			wait(`TOP_TB.pad_gpio == 8'h53); //"S" : 83(0x53).*/
			wait(`TOP_TB.tbe_core_print.pass == 1);
			#200ns;
			`uvm_info(get_full_name(), $sformatf("USER PROGRAM TEST PASS. \n%s", smile), UVM_LOW); 
		end
		begin //wait c test fail
			/*wait(`TOP_TB.pad_gpio == 8'h46); //"F" : 70(0x46).
			wait(`TOP_TB.pad_gpio == 8'h41); //"A" : 65(0x41).
			wait(`TOP_TB.pad_gpio == 8'h49); //"I" : 73(0x49).
			wait(`TOP_TB.pad_gpio == 8'h4C); //"L" : 76(0x4C).)*/
			wait(`TOP_TB.tbe_core_print.fail == 1);
			#200ns;
			`uvm_error(get_full_name(), $sformatf("USER PROGRAM TEST FAIL !!! \n%s", sad)); 
		end
    begin
      wait_write_tohost_done();
    end
	join_any
    //disable the inst trace log in sim end
    env.core_env.rvfi_agent.cfg.enable_logger = 0;
    #1us;
  endtask
	
  task check_fail();
    string sad;
	sad	=  {"   -----    \n" , 
			" /       \\ \n" , 
			"|   x x   | \n" , 
			" \\   ~   / \n" , 
			"   -----    \n"};
	fork
		begin //wait c test fail
			wait(`TOP_TB.pad_gpio == 8'h46); //"F" : 70(0x46).
			wait(`TOP_TB.pad_gpio == 8'h41); //"A" : 65(0x41).
			wait(`TOP_TB.pad_gpio == 8'h49); //"I" : 73(0x49).
			wait(`TOP_TB.pad_gpio == 8'h4C); //"L" : 76(0x4C).
			#200ns;
			`uvm_error(get_full_name(), $sformatf("USER PROGRAM TEST FAIL !!! \n%s", sad)); 
		end
	join_none
  endtask


  task wait_hart_halted();
    int unsigned rdata;
    int cnt=0;
    jtag_csr_read(`dmstatus,rdata);
    while((rdata[9:8]!=2'b11)) begin //check allhalted and anyhalted
        jtag_csr_read(`dmstatus,rdata);
        cnt++;
        if(cnt > 30) break;
    end
    if(cnt > 30) `uvm_error(get_full_name(), $sformatf("set hart halted timeout, cnt = %d", cnt));
    if(rdata[19:10] != 10'b0011000000) `uvm_error(get_full_name(), $sformatf("check halted other state bit error, data = %10b", rdata[19:10])); //check resume reset unavailble nonexistent state bit 
    jtag_csr_read(`halt_summary0,rdata);
    if(rdata != 1) `uvm_error(get_full_name(), $sformatf("hart halted halt_summary0 check error, data = %h", rdata));
    jtag_csr_read(`halt_summary1,rdata);
    if(rdata != 1) `uvm_error(get_full_name(), $sformatf("hart halted halt_summary1 check error, data = %h", rdata));
  endtask

  task debug_progbuf_read_csr(bit [11:0] addr,output bit [31:0] data); //read hart csr regs throungh programbuffer
    int unsigned rdata,wdata;
    int cnt=0;
    wdata={addr,20'h020f3};
    jtag_csr_write(`progbuf0,wdata); // csrr rs1 csr
    debug_progbuf_ebreak_mode(`progbuf1); //end with ebreak

    jtag_csr_write(`abstract_cmd,32'h00240000); //aarsize=2 postexec=1 
    jtag_csr_read(`abstractcs,rdata);
    while((rdata[12]==1'b1)) begin //check busy
        jtag_csr_read(`abstractcs,rdata);
        cnt++;
        if(cnt > 50) break;
    end
    if(cnt > 30) `uvm_error(get_full_name(), $sformatf("progbuf read csr timeout, cnt = %d", cnt));
    if(rdata[10:8] !=0)  `uvm_error(get_full_name(), $sformatf("abcmd cmderr check error, data = %4h", rdata)); //check cmderr=0
    jtag_csr_write(`abstractcs,32'hf00);
    cnt =0;
    jtag_csr_write(`abstract_cmd,32'h00221001); //aarsize=2 postexec=0 transfer=1 regno=0x1001
    jtag_csr_read(`abstractcs,rdata);
    while((rdata[12]==1'b1)) begin //check busy
        jtag_csr_read(`abstractcs,rdata);
        cnt++;
        if(cnt > 50) break;
    end
    if(cnt > 30) `uvm_error(get_full_name(), $sformatf("progbuf read csr timeout, cnt = %d", cnt));
    if(rdata[10:8] !=0)  `uvm_error(get_full_name(), $sformatf("abcmd cmderr check error, data = %4h", rdata));//check cmderr=0
    jtag_csr_read(`abstract_data0,rdata);
    data = rdata;
    `uvm_info(get_full_name(), $sformatf("progbuf read data = %8h, addr =%3h", rdata,addr), UVM_LOW)
  endtask

 
  //wait for asm write_tohost finshed 3rd times
  task wait_write_tohost_done();
      //check test done of asm
      wait(env.core_env.sb.write_tohost_cnt >= 3);
			`uvm_info(get_full_name(), $sformatf("USER PROGRAM TEST DONE !!!"),UVM_NONE); 
  endtask


  
//gen atomic exp data;
task gen_atomic_exp_data(input [2:0] cl_opcode,input [2:0] cl_param,input [31:0] dut_data[2],input  [31:0] ato_data[2],output [31:0] ato_data_new[2]);
   if(cl_opcode == 'h2)begin
    if(cl_param == 0 )begin//MIN
      foreach(dut_data[i])begin
        if(dut_data[i][31]==0 && ato_data[i][31]==0)begin 
          if(dut_data[i] > ato_data[i])
            ato_data_new[i] = ato_data[i];
          else 
            ato_data_new[i] = dut_data[i];
        end
        else if(dut_data[i][31]==0 && ato_data[i][31]==1)begin 
            ato_data_new[i] = ato_data[i];
        end
        else if(dut_data[i][31]==1 && ato_data[i][31]==0)begin 
            ato_data_new[i] = dut_data[i];
        end
        else if(dut_data[i][31]==1 && ato_data[i][31]==1)begin 
          if(dut_data[i] > ato_data[i])
            ato_data_new[i] = dut_data[i];
          else 
            ato_data_new[i] = ato_data[i];
        end
      end
    end 
    else if(cl_param ==2)begin//MIN
      foreach(dut_data[i])begin 
       if(dut_data[i] > ato_data[i])
        ato_data_new[i] = ato_data[i];
       else 
        ato_data_new[i] = dut_data[i];
      end
    end 
    else if(cl_param == 3)begin//MAX 
      foreach(dut_data[i])begin 
       if(dut_data[i] < ato_data[i])
        ato_data_new[i] = ato_data[i];
       else 
        ato_data_new[i] = dut_data[i];
      end
    end 
    else if(cl_param == 1)begin//MAX 
      foreach(dut_data[i])begin
        if(dut_data[i][31]==0 && ato_data[i][31]==0)begin 
          if(dut_data[i] > ato_data[i])
            ato_data_new[i] = dut_data[i];
          else 
            ato_data_new[i] = ato_data[i];
        end
        else if(dut_data[i][31]==0 && ato_data[i][31]==1)begin 
            ato_data_new[i] = dut_data[i];
        end
        else if(dut_data[i][31]==1 && ato_data[i][31]==0)begin 
            ato_data_new[i] = ato_data[i];
        end
        else if(dut_data[i][31]==1 && ato_data[i][31]==1)begin 
          if(dut_data[i] > ato_data[i])
            ato_data_new[i] = ato_data[i];
          else 
            ato_data_new[i] = dut_data[i];
        end
      end
    end 
    else if(cl_param == 4)begin//ADD
       foreach(dut_data[i])begin
        ato_data_new[i] = ato_data[i] + dut_data[i];
       end
    end 
  end 
  else if(cl_opcode == 'h3)begin 
    if(cl_param == 0)begin
      foreach(dut_data[i])
       ato_data_new[i] = ato_data[i] ^ dut_data[i];
    end 
    else if(cl_param == 1)begin 
      foreach(dut_data[i])
       ato_data_new[i] = ato_data[i] | dut_data[i];
    end 
    else if(cl_param == 2)begin 
      foreach(dut_data[i])
       ato_data_new[i] = ato_data[i] & dut_data[i];
    end 
    else if(cl_param == 3)begin 
      foreach(dut_data[i])begin 
       ato_data_new[i] = ato_data[i];
      end 
    end 
  end  
endtask
//for check two data 
task check_data(bit [31:0] exp_data,bit [31:0] src_data);
   if(exp_data == src_data)begin 
     `uvm_info(get_full_name(),$sformatf("data check is right!"),UVM_NONE)
   end
   else begin 
     `uvm_error(get_full_name(),$sformatf("data check  Error!"))
     `uvm_info("check data",$sformatf("exp_data = %0h ;src_data = %0h;",exp_data,src_data),UVM_LOW);
   end
endtask 
endclass: chip_env_base_test


