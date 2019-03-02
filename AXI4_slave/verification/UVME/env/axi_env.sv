/*class axi_env extends uvm_env;
  //factory registration
  `uvm_component_utils(axi_env)
  
  //creating component handles
  axi_scoreboard sb;
  axi_agent agent_inst;
  axi_cov_model cov_model;
  
  //constructor
  function new(string name = "axi_env", uvm_component parent);
    super.new(name, parent);
    `uvm_info("ENV_CLASS", "Inside constructor!", UVM_HIGH)
  endfunction
  
  //build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    sb = axi_scoreboard::type_id::create("sb", this);
    agent_inst = axi_agent::type_id::create("agent_inst", this);
    cov_model = axi_cov_model::type_id::create("cov_model", this);
    
    `uvm_info("ENV_CLASS", "Inside Build Phase!", UVM_HIGH)
  endfunction
  
  //connect phase
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    
    // Connect monitor to scoreboard
    agent_inst.mon_inst.wr_analysis_port.connect(sb.wr_export);
    agent_inst.mon_inst.rd_analysis_port.connect(sb.rd_export);
    
    // Connect monitors to coverage model
    // Both read and write transactions will be sent to coverage model
    agent_inst.mon_inst.wr_analysis_port.connect(cov_model.analysis_export);
    agent_inst.mon_inst.rd_analysis_port.connect(cov_model.analysis_export);
    
    `uvm_info("ENV_CLASS", "Inside connect Phase! All connections established", UVM_HIGH)
  endfunction 
endclass*/



class axi_env extends uvm_env;
  //factory registration
  `uvm_component_utils(axi_env)
  
  //creating component handles
  axi_scoreboard sb;
  axi_agent agent_inst;
  axi_cov_model cov_model;
  //axi_driver driver;
  //axi_monitor monitor;
  axi4_protocol_checker protocol_checker;

  
  //constructor
  function new(string name = "axi_env", uvm_component parent);
    super.new(name, parent);
    `uvm_info("ENV_CLASS", "Inside constructor!", UVM_HIGH)
  endfunction
  
  //build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    //driver = axi_driver::type_id::create("driver", this);
    //monitor = axi_monitor::type_id::create("monitor", this);
    sb = axi_scoreboard::type_id::create("sb", this);
    protocol_checker = axi4_protocol_checker::type_id::create("protocol_checker", this);
    agent_inst = axi_agent::type_id::create("agent_inst", this);
    cov_model = axi_cov_model::type_id::create("cov_model", this);
    
    `uvm_info("ENV_CLASS", "Inside Build Phase!", UVM_HIGH)
  endfunction
  
  //connect phase
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    
    // Connect monitor to scoreboard
    agent_inst.mon_inst.wr_analysis_port.connect(sb.wr_fifo.analysis_export);
    agent_inst.mon_inst.rd_analysis_port.connect(sb.rd_fifo.analysis_export);
    agent_inst.mon_inst.handshake_port.connect(sb.handshake_fifo.analysis_export);
    
    // Connect monitor to protocol checker
    agent_inst.mon_inst.wr_analysis_port.connect(protocol_checker.analysis_export);
    agent_inst.mon_inst.rd_analysis_port.connect(protocol_checker.analysis_export);
    agent_inst.mon_inst.handshake_port.connect(protocol_checker.analysis_export); 

    // Connect monitor to scoreboard
    //agent_inst.mon_inst.wr_analysis_port.connect(sb.wr_export);
    //agent_inst.mon_inst.rd_analysis_port.connect(sb.rd_export);
    
    // Connect monitors to coverage model
    // Both read and write transactions will be sent to coverage model
    agent_inst.mon_inst.wr_analysis_port.connect(cov_model.analysis_export);
    agent_inst.mon_inst.rd_analysis_port.connect(cov_model.analysis_export);
    
    `uvm_info("ENV_CLASS", "Inside connect Phase! All connections established", UVM_HIGH)
  endfunction 

    // Report phase - print test results
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    
    // Additional environment-level reporting can be added here
    `uvm_info("AXI_ENV", "End of test report from environment", UVM_LOW)
  endfunction
  
endclass
