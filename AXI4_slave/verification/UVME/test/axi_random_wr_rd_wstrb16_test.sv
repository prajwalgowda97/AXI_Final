class axi_random_wr_rd_wstrb16_test extends axi_base_test;

  //factory registration
  `uvm_component_utils(axi_random_wr_rd_wstrb16_test)
  axi_random_wr_rd_wstrb16_seq random_wr_rd_wstrb16_seq_inst;

  //constructor
  function new(string name = "axi_random_wr_rd_wstrb16_test",uvm_component parent);
    super.new(name,parent);
    random_wr_rd_wstrb16_seq_inst = axi_random_wr_rd_wstrb16_seq::type_id::create("random_wr_rd_wstrb16_seq_inst");
  endfunction
 
  //build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  //run phase
   virtual task run_phase(uvm_phase phase);
    `uvm_info(get_full_name(),$sformatf("it test random_wr_rd_wstrb16 first line"),UVM_MEDIUM)
    phase.raise_objection(this);

    `uvm_info(get_type_name(),$sformatf("inside the random_wr_rd_wstrb16 test"),UVM_MEDIUM)
   
   begin
    random_wr_rd_wstrb16_seq_inst.scenario = 1;
    random_wr_rd_wstrb16_seq_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("random_wr_rd_wstrb16 scenario 1 is competed"),UVM_MEDIUM)
 
    begin
    random_wr_rd_wstrb16_seq_inst.scenario = 2;
    random_wr_rd_wstrb16_seq_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("random_wr_rd_wstrb16 scenario 2 is competed"),UVM_MEDIUM)
        
    phase.phase_done.set_drain_time(this,1000);

    begin
    random_wr_rd_wstrb16_seq_inst.scenario = 3;
    random_wr_rd_wstrb16_seq_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("random_wr_rd_wstrb16 scenario 3 is competed"),UVM_MEDIUM)
        
    phase.phase_done.set_drain_time(this,1000);

    phase.drop_objection(this);
   endtask
  endclass
