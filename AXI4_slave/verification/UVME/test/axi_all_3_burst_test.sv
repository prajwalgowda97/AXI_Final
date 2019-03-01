class axi_all_3_burst_test extends axi_base_test;

  //factory registration
  `uvm_component_utils(axi_all_3_burst_test)
   axi_all_3_burst_seq all_3_burst_inst;

  //constructor
  function new(string name = "axi_all_3_burst_test",uvm_component parent);
    super.new(name,parent);
    all_3_burst_inst = axi_all_3_burst_seq::type_id::create("all_3_burst_inst");
  endfunction
 
  //build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  //run phase
   virtual task run_phase(uvm_phase phase);
    `uvm_info(get_full_name(),$sformatf("it test all_3_burst first line"),UVM_MEDIUM)
    phase.raise_objection(this);

    `uvm_info(get_type_name(),$sformatf("inside the all_3_burst test"),UVM_MEDIUM)

    begin
    all_3_burst_inst.scenario = 26;
    all_3_burst_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("all_3_burst scenario 26 is competed"),UVM_MEDIUM)
 
    begin
    all_3_burst_inst.scenario = 27;
    all_3_burst_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("all_3_burst scenario 27 is competed"),UVM_MEDIUM)
        
    phase.phase_done.set_drain_time(this,1000);

    begin
    all_3_burst_inst.scenario = 28;
    all_3_burst_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("all_3_burst scenario 28 is competed"),UVM_MEDIUM)
        
    phase.phase_done.set_drain_time(this,1000);

    begin
    all_3_burst_inst.scenario = 29;
    all_3_burst_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("all_3_burst scenario 29 is competed"),UVM_MEDIUM)
        
    phase.phase_done.set_drain_time(this,1000);

    begin
    all_3_burst_inst.scenario = 30;
    all_3_burst_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("all_3_burst scenario 30 is competed"),UVM_MEDIUM)
        
    phase.phase_done.set_drain_time(this,1000);

    begin
    all_3_burst_inst.scenario = 31;
    all_3_burst_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("all_3_burst scenario 31 is competed"),UVM_MEDIUM)
        
    phase.phase_done.set_drain_time(this,1000);

    begin
    all_3_burst_inst.scenario = 32;
    all_3_burst_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("all_3_burst scenario 32 is competed"),UVM_MEDIUM)
        
    phase.phase_done.set_drain_time(this,1000);

    begin
    all_3_burst_inst.scenario = 33;
    all_3_burst_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("all_3_burst scenario 33 is competed"),UVM_MEDIUM)
        
    phase.phase_done.set_drain_time(this,1000);

    begin
    all_3_burst_inst.scenario = 34;
    all_3_burst_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("all_3_burst scenario 34 is competed"),UVM_MEDIUM)
        
    phase.phase_done.set_drain_time(this,1000);

    phase.drop_objection(this);
   endtask
  endclass


