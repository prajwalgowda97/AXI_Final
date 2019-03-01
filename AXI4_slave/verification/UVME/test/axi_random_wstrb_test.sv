class axi_random_wstrb_test extends axi_base_test;

  //factory registration
  `uvm_component_utils(axi_random_wstrb_test)
   axi_random_wstrb_seq random_wstrb_inst;

  //constructor
  function new(string name = "axi_random_wstrb_test",uvm_component parent);
    super.new(name,parent);
    random_wstrb_inst = axi_random_wstrb_seq::type_id::create("random_wstrb_inst");
  endfunction
 
  //build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  //run phase
   virtual task run_phase(uvm_phase phase);
    `uvm_info(get_full_name(),$sformatf("it test random_wstrb first line"),UVM_MEDIUM)
    phase.raise_objection(this);

    `uvm_info(get_type_name(),$sformatf("inside the random_wstrb test"),UVM_MEDIUM)

    begin
    random_wstrb_inst.scenario = 26;
    random_wstrb_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("random_wstrb scenario 26 is competed"),UVM_MEDIUM)
 
    begin
    random_wstrb_inst.scenario = 27;
    random_wstrb_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("random_wstrb scenario 27 is competed"),UVM_MEDIUM)
        
    phase.phase_done.set_drain_time(this,1000);

    begin
    random_wstrb_inst.scenario = 28;
    random_wstrb_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("random_wstrb scenario 28 is competed"),UVM_MEDIUM)
        
    phase.phase_done.set_drain_time(this,1000);

    phase.drop_objection(this);
   endtask
  endclass

