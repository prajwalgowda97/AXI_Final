/*class axi_boundary_cross_test extends axi_base_test;
  // Factory registration
  `uvm_component_utils(axi_boundary_cross_test)
  
  // Create instance of the boundary crossing sequence
  axi_boundary_cross_seq boundary_cross_seq_inst;
  
  // Constructor
  function new(string name = "axi_boundary_cross_test", uvm_component parent);
    super.new(name, parent);
  endfunction
 
  // Build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    boundary_cross_seq_inst = axi_boundary_cross_seq::type_id::create("boundary_cross_seq_inst");
  endfunction
  
  // Run phase
  virtual task run_phase(uvm_phase phase);
    `uvm_info(get_full_name(), "AXI4 4KB Boundary Crossing Test Started", UVM_LOW)
    phase.raise_objection(this);
    
    // Reset DUT
    boundary_cross_seq_inst.scenario = 1;
    boundary_cross_seq_inst.start(env_inst.agent_inst.seqr_inst);
    #50;
    
    // Run WRAP burst test with boundary crossing - 10 tests with 10 transfers each
    boundary_cross_seq_inst.scenario = 2;
    boundary_cross_seq_inst.start(env_inst.agent_inst.seqr_inst);
    #50;
    
    // Verify with read - all 10 tests
    boundary_cross_seq_inst.scenario = 3;
    boundary_cross_seq_inst.start(env_inst.agent_inst.seqr_inst);
    #50;
    
    phase.drop_objection(this);
    
    // Print out summary of test results
    for (int i = 0; i < boundary_cross_seq_inst.num_tests; i++) begin
      bit crosses = boundary_cross_seq_inst.will_cross_4k_boundary(
                      boundary_cross_seq_inst.test_addresses[i], 
                      boundary_cross_seq_inst.wr_len, 
                      boundary_cross_seq_inst.wr_size);
      `uvm_info(get_full_name(), $sformatf("Test %0d: Address 0x%0h %s 4K boundary", 
                        i, boundary_cross_seq_inst.test_addresses[i], 
                        crosses ? "CROSSES" : "does NOT cross"), UVM_LOW)
    end
    
    `uvm_info(get_full_name(), "AXI4 4KB Boundary Crossing Test Completed", UVM_LOW)
  endtask
endclass */


class axi_boundary_cross_test extends axi_base_test;

  //factory registration
  `uvm_component_utils(axi_boundary_cross_test)
   axi_boundary_cross_seq boundary_cross_inst;

  //constructor
  function new(string name = "axi_boundary_cross_test",uvm_component parent);
    super.new(name,parent);
    boundary_cross_inst = axi_boundary_cross_seq::type_id::create("boundary_cross_inst");
  endfunction
 
  //build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  //run phase
   virtual task run_phase(uvm_phase phase);
    `uvm_info(get_full_name(),$sformatf("it test boundary_cross first line"),UVM_MEDIUM)
    phase.raise_objection(this);

    `uvm_info(get_type_name(),$sformatf("inside the boundary_cross test"),UVM_MEDIUM)

    begin
    boundary_cross_inst.scenario = 26;
    boundary_cross_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("boundary_cross scenario 26 is competed"),UVM_MEDIUM)
 
    begin
    boundary_cross_inst.scenario = 27;
    boundary_cross_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("boundary_cross scenario 27 is competed"),UVM_MEDIUM)
        
    phase.phase_done.set_drain_time(this,1000);

    begin
    boundary_cross_inst.scenario = 28;
    boundary_cross_inst.start(env_inst.agent_inst.seqr_inst);
    end  
    `uvm_info(get_type_name(),$sformatf("boundary_cross scenario 28 is competed"),UVM_MEDIUM)
        
    phase.phase_done.set_drain_time(this,1000);

    phase.drop_objection(this);
   endtask
  endclass

