class axi_reserved_burst_test extends axi_base_test;

  //factory registration
  `uvm_component_utils(axi_reserved_burst_test)
   axi_reserved_burst_seq reserved_burst_seq_inst;

  //constructor
  function new(string name = "axi_reserved_burst_test",uvm_component parent);
    super.new(name,parent);
    reserved_burst_seq_inst = axi_reserved_burst_seq::type_id::create("reserved_burst_seq_inst");
  endfunction
 
  //build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  //run phase
   virtual task run_phase(uvm_phase phase);
    `uvm_info(get_full_name(),$sformatf("it test reserved_burst first line"),UVM_MEDIUM)
    phase.raise_objection(this);

    `uvm_info(get_type_name(),$sformatf("inside the reserved_burst test"),UVM_MEDIUM)
   
   begin
    reserved_burst_seq_inst.scenario = 20;
    reserved_burst_seq_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("reserved_burst scenario 20 is competed"),UVM_MEDIUM)
 
    begin
    reserved_burst_seq_inst.scenario = 21;
    reserved_burst_seq_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("reserved_burst scenario 21 is competed"),UVM_MEDIUM)
        
    phase.phase_done.set_drain_time(this,1000);

    begin
    reserved_burst_seq_inst.scenario = 22;
    reserved_burst_seq_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("reserved_burst scenario 22 is competed"),UVM_MEDIUM)
        
    phase.phase_done.set_drain_time(this,1000);

    phase.drop_objection(this);
   endtask
  endclass
