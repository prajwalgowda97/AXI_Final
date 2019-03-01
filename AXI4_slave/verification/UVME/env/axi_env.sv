/*class axi_env extends uvm_env;

  //factory registration
  `uvm_component_utils(axi_env)

  //creating agent handle
  axi_scoreboard sb;
  axi_agent agent_inst;
  axi_cov_model cov_model;

  //constructor
  function new(string name = "axi_env",uvm_component parent);
    super.new(name,parent);
    `uvm_info("env_class", "Inside constructor!", UVM_HIGH)
  endfunction

  //build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    sb = axi_scoreboard::type_id::create("sb",this);
    agent_inst = axi_agent::type_id::create("agent_inst",this);
    
   cov_model = axi_cov_model::type_id::create("cov_model",this);
   `uvm_info("env_class", "Inside Build Phase!", UVM_HIGH)
  endfunction

  //connect phase
  function void connect_phase(uvm_phase phase);
   agent_inst.mon_inst.wr_analysis_port.connect(sb.wr_export);
   agent_inst.mon_inst.rd_analysis_port.connect(sb.rd_export);
   
    agent_inst.mon_inst.wr_analysis_port.connect(cov_model.analysis_export);
    agent_inst.mon_inst.rd_analysis_port.connect(cov_model.analysis_export);
    
   `uvm_info("env_class", "Inside connect Phase!", UVM_HIGH)

  endfunction 
endclass */


class axi_env extends uvm_env;
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
endclass
