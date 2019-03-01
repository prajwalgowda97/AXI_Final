/*class axi_boundary_cross_seq extends uvm_sequence#(axi_seq_item);
  // Factory registration
  `uvm_object_utils(axi_boundary_cross_seq)
  
  // Sequence item handle
  axi_seq_item seq_item_inst;
  int scenario;
  
  // Test parameters
  bit [31:0] test_addresses[10]; // Array of 10 test addresses
  bit [3:0] test_ids[10];        // Array of 10 test IDs
  int num_tests = 10;            // Number of test iterations
  
  // Fixed parameters for 4K boundary crossing test
  bit [2:0] wr_size = 3'b010;  // Fixed size = 4 bytes
  bit [7:0] wr_len = 8'h09;    // Fixed length = 9 (10 transfers)
  bit [1:0] wr_burst = 2'b10;  // WRAP burst
  
  // 4K boundary mask
  bit [31:0] boundary_mask = 32'hFFFFF000;
  
  // Constructor
  function new(string name="axi_boundary_cross_seq");
    super.new(name);
  endfunction
  
  // Build phase
  virtual function void build_phase(uvm_phase phase);
    seq_item_inst = axi_seq_item::type_id::create("seq_item_inst");
    
    // Pre-generate test addresses
    test_addresses[0] = 32'h00000FF0;  // Close to 4K boundary
    test_addresses[1] = 32'h00001FF0;  // Close to 8K boundary
    test_addresses[2] = 32'h00001000 - 8;  // 8 bytes before 4K boundary
    test_addresses[3] = 32'h00002000 - 16; // 16 bytes before 8K boundary
    test_addresses[4] = 32'h00003000 - 24; // 24 bytes before 12K boundary
    test_addresses[5] = 32'h00000F00;  // Further from boundary
    test_addresses[6] = 32'h00001F00;  // Further from boundary
    test_addresses[7] = 32'h00002F00;  // Further from boundary
    test_addresses[8] = 32'h00003FF0;  // Very close to 16K boundary
    test_addresses[9] = 32'h00004FF0;  // Very close to 20K boundary
    
    // Assign different IDs
    for (int i = 0; i < num_tests; i++) begin
      test_ids[i] = i[3:0]; // ID 0-9
    end
  endfunction
  
  // Function to check if a transfer would cross 4KB boundary
  function bit will_cross_4k_boundary(bit [31:0] addr, bit [7:0] len, bit [2:0] size);
    bit [31:0] start_addr = addr;
    bit [31:0] end_addr;
    int bytes_per_transfer = (1 << size);
    int total_bytes = (len + 1) * bytes_per_transfer;
    
    end_addr = start_addr + total_bytes - 1;
    
    return ((start_addr & boundary_mask) != (end_addr & boundary_mask));
  endfunction
  
  // Function to calculate wrap boundary and size
  function void calc_wrap_info(bit [31:0] addr, bit [7:0] len, bit [2:0] size, 
                            output bit [31:0] wrap_boundary, output int wrap_size);
    wrap_size = (len + 1) * (1 << size);
    wrap_boundary = addr & (~(wrap_size - 1));
  endfunction
  
  // Task body
  virtual task body();
    bit crosses;
    bit [31:0] wrap_boundary;
    int wrap_size;
    
    `uvm_info(get_type_name(), "AXI4 Boundary Crossing Test Sequence Started", UVM_LOW)
    
    // Reset sequence
    if (scenario == 1) begin
      `uvm_do_with(seq_item_inst,{
        seq_item_inst.RST       == 1'b0;
        seq_item_inst.AWVALID   == 1'b0;
        seq_item_inst.WVALID    == 1'b0;
        seq_item_inst.BREADY    == 1'b0;
        seq_item_inst.ARVALID   == 1'b0;
        seq_item_inst.RREADY    == 1'b0;
      });
    end
    
    // Write transactions: WRAP burst with 4K boundary crossing
    else if (scenario == 2) begin
      for (int test_idx = 0; test_idx < num_tests; test_idx++) begin
        bit [31:0] current_addr = test_addresses[test_idx];
        bit [3:0] current_id = test_ids[test_idx];
        
        // Send write address
        `uvm_do_with(seq_item_inst,{
          seq_item_inst.RST       == 1'b1;
          seq_item_inst.wr_rd     == 1'b1;
          seq_item_inst.AWVALID   == 1'b1;
          seq_item_inst.WVALID    == 1'b0;
          seq_item_inst.BREADY    == 1'b0;
          seq_item_inst.AWADDR    == current_addr;
          seq_item_inst.AWID      == current_id;
          seq_item_inst.AWLEN     == wr_len;
          seq_item_inst.AWSIZE    == wr_size;
          seq_item_inst.AWBURST   == wr_burst;
          seq_item_inst.ARVALID   == 1'b0;
          seq_item_inst.RREADY    == 1'b0;
        });
        
        // Check if transaction crosses 4K boundary
        crosses = will_cross_4k_boundary(current_addr, wr_len, wr_size);
        calc_wrap_info(current_addr, wr_len, wr_size, wrap_boundary, wrap_size);
        
        // Print clear boundary crossing information
        `uvm_info("BOUNDARY_CHECK", $sformatf("==== TEST %0d of %0d ====", test_idx+1, num_tests), UVM_LOW)
        `uvm_info("BOUNDARY_CHECK", $sformatf("WRAP Burst Boundary Test:"), UVM_LOW)
        `uvm_info("BOUNDARY_CHECK", $sformatf("  Address: 0x%0h", current_addr), UVM_LOW)
        `uvm_info("BOUNDARY_CHECK", $sformatf("  Length: %0d, Size: %0d bytes", wr_len, (1<<wr_size)), UVM_LOW)
        `uvm_info("BOUNDARY_CHECK", $sformatf("  Total transfer size: %0d bytes", (wr_len+1)*(1<<wr_size)), UVM_LOW)
        `uvm_info("BOUNDARY_CHECK", $sformatf("  4K boundary at: 0x%0h", (current_addr & boundary_mask) + 32'h1000), UVM_LOW)
        `uvm_info("BOUNDARY_CHECK", $sformatf("  Wrap boundary at: 0x%0h", wrap_boundary), UVM_LOW)
        `uvm_info("BOUNDARY_CHECK", $sformatf("  Wrap size: %0d bytes", wrap_size), UVM_LOW)
        `uvm_info("BOUNDARY_CHECK", $sformatf("  4K BOUNDARY CROSSING: %s", crosses ? "YES" : "NO"), UVM_LOW)
        
        // Send data beats for the write transaction - exactly 10 transfers
        for (int i = 0; i <= wr_len; i++) begin
          bit is_last = (i == wr_len);
          bit [31:0] expected_addr = wrap_boundary | ((current_addr + (i * (1 << wr_size))) & ~(~(wrap_size - 1)));
          
          `uvm_do_with(seq_item_inst, {
            seq_item_inst.RST       == 1'b1;
            seq_item_inst.wr_rd     == 1'b1;
            seq_item_inst.AWVALID   == 1'b0;
            seq_item_inst.WVALID    == 1'b1;
            seq_item_inst.BREADY    == is_last;
            seq_item_inst.WDATA[0]  == 32'hA5000000 | (test_idx << 16) | i;
            seq_item_inst.WSTRB     == 4'b1111;
            seq_item_inst.WLAST     == is_last;
            seq_item_inst.ARVALID   == 1'b0;
            seq_item_inst.RREADY    == 1'b0;
          });
          
          // Display each transfer with calculated address
          `uvm_info("TRANSFER", $sformatf("  Beat %0d: Data = 0x%0h, Expected Address = 0x%0h", 
                           i, seq_item_inst.WDATA[0], expected_addr), UVM_LOW)
        end
        
        // Brief pause between tests
        #10;
      end
    end
    
    // Read transaction to verify all tests
    else if (scenario == 3) begin
      for (int test_idx = 0; test_idx < num_tests; test_idx++) begin
        bit [31:0] current_addr = test_addresses[test_idx];
        bit [3:0] current_id = test_ids[test_idx];
        
        `uvm_do_with(seq_item_inst, {
          seq_item_inst.RST       == 1'b1;
          seq_item_inst.wr_rd     == 1'b0;
          seq_item_inst.ARVALID   == 1'b1;
          seq_item_inst.RREADY    == 1'b1;
          seq_item_inst.ARID      == current_id;
          seq_item_inst.ARADDR    == current_addr;
          seq_item_inst.ARSIZE    == wr_size;
          seq_item_inst.ARBURST   == wr_burst;
          seq_item_inst.ARLEN     == wr_len;
          seq_item_inst.AWVALID   == 1'b0;
          seq_item_inst.WVALID    == 1'b0;
          seq_item_inst.BREADY    == 1'b0;
        });
        
        // Check if transaction crosses 4K boundary
        crosses = will_cross_4k_boundary(current_addr, wr_len, wr_size);
        
        `uvm_info("VERIFICATION", $sformatf("==== VERIFY TEST %0d of %0d ====", test_idx+1, num_tests), UVM_LOW)
        `uvm_info("VERIFICATION", $sformatf("READ VERIFICATION:"), UVM_LOW)
        `uvm_info("VERIFICATION", $sformatf("  Address: 0x%0h", current_addr), UVM_LOW)
        `uvm_info("VERIFICATION", $sformatf("  ID: %0d", current_id), UVM_LOW)
        `uvm_info("VERIFICATION", $sformatf("  Parameters: Length=%0d, Size=%0d, Burst=%0s", 
                           wr_len, wr_size, wr_burst == 2'b10 ? "WRAP" : "OTHER"), UVM_LOW)
        `uvm_info("VERIFICATION", $sformatf("  4K BOUNDARY CROSSING: %s", crosses ? "YES" : "NO"), UVM_LOW)
        
        // Brief pause between tests
        #10;
      end
    end
  endtask
endclass */



class axi_boundary_cross_seq extends uvm_sequence#(axi_seq_item);

  //factory registration
  `uvm_object_utils(axi_boundary_cross_seq)

    //creating sequence item handle
    axi_seq_item seq_item_inst;
    int scenario;
    int i = 0;

    // Variable to store randomized write address
    bit [31:0] rand_wr_addr[$]; 
    bit [3: 0] rand_wr_id[$];
    bit [2:0] wr_size[$];
    bit [1:0] wr_burst[$];
    bit [7:0] wr_len[$];

  //constructor
  function new(string name="axi_boundary_cross_seq");
   super.new(name);
  endfunction
  
  //Build phase
  function build_phase(uvm_phase phase);
  seq_item_inst = axi_seq_item::type_id::create("seq_item_inst");
  endfunction


  //task body
  task body();

  //reset scenario
        `uvm_info (get_type_name(),"boundary_cross_seq: inside body", UVM_LOW);
      
       if (scenario == 26)
        begin
          `uvm_do_with(seq_item_inst,{
            seq_item_inst.RST       == 1'b0;
            seq_item_inst.AWADDR    == 32'h00000000;
            seq_item_inst.AWVALID   == 1'b0;
            seq_item_inst.WVALID    == 1'b0;
            seq_item_inst.WDATA[0]  == 32'h00000000;
            seq_item_inst.BREADY    == 1'b0;
            seq_item_inst.AWID      == 0;
            seq_item_inst.AWSIZE    == 0;
            seq_item_inst.ARID      == 0;
            seq_item_inst.ARSIZE    == 0;
            seq_item_inst.AWLEN     == 0;
            seq_item_inst.AWBURST   == 0;
            seq_item_inst.WSTRB     == 0;
            seq_item_inst.WLAST     == 0;
            seq_item_inst.ARVALID   == 0;
            seq_item_inst.ARADDR    == 0;
            seq_item_inst.ARLEN     == 0;
            seq_item_inst.ARBURST   == 0;
            seq_item_inst.RREADY    == 0;   });                     
            end

if (scenario == 27) 
        begin
        for (int i = 0; i < 20; i++) 
          begin  
            `uvm_do_with(seq_item_inst,{
            seq_item_inst.RST       == 1'b1;
            seq_item_inst.wr_rd     == 1'b1;
            seq_item_inst.AWVALID   == 1'b0;
            seq_item_inst.WVALID    == 1'b0;
            seq_item_inst.BREADY    == 1'b0;
            seq_item_inst.AWADDR inside {[32'hFFFF_FF00 : 32'hFFFF_FFFF]}; 
            seq_item_inst.WDATA[0]  inside {[32'h0000_0000 : 32'hFFFF_FFFF]};
            seq_item_inst.AWID   inside {[4'h0 : 4'hF]};
            seq_item_inst.AWLEN     == 8'hFF;
            seq_item_inst.AWSIZE    == 3'b010;
            seq_item_inst.AWBURST   == 2'b10;
            seq_item_inst.WSTRB     == 4'b1111;
            seq_item_inst.WLAST     == 1'b0; 
            
            seq_item_inst.ARVALID   == 0;
            seq_item_inst.RREADY    == 0;
            seq_item_inst.ARID      == 0;
            seq_item_inst.ARADDR    == 0;
            seq_item_inst.ARSIZE    == 0;
            seq_item_inst.ARBURST   == 0;
            seq_item_inst.ARLEN     == 0; });
            
            `uvm_info("SEQ", $sformatf("Running scenario = %0d", scenario), UVM_MEDIUM)    
            
            // Store the randomized AWADDR value into the class variable
            rand_wr_addr[i] = seq_item_inst.AWADDR;
            rand_wr_id[i]   = seq_item_inst.AWID;
            wr_size[i]      = seq_item_inst.AWSIZE;
            wr_burst [i]    = seq_item_inst.AWBURST;
            wr_len [i]      = seq_item_inst.AWLEN;

            `uvm_info("SEQ", $sformatf("Randomized AWADDR = 0x%0p", rand_wr_addr), UVM_MEDIUM)
             `uvm_info("i", $sformatf("i value = %0d", i), UVM_MEDIUM) 

            for (int j = 0; j < i; j++) begin
            `uvm_info("SEQ", $sformatf("rand_wr_addr[%0d] = 0x%0h", j, rand_wr_addr[j]), UVM_MEDIUM)
            end

            // for (int j = 0; j < i; j++) 
            begin
            `uvm_info("SEQ", $sformatf("AWADDR = 0x%0h", seq_item_inst.AWADDR), UVM_MEDIUM)
            end

            end
            end

        if (scenario == 28) 
        begin
        for (int i = 0; i < 20; i++) 
         begin

                int temp_arid    = rand_wr_id[i];
                int temp_araddr  = rand_wr_addr[i];
                int temp_arsize  = wr_size[i];
                int temp_arburst = wr_burst[i];
                int temp_arlen   = wr_len[i];

            `uvm_do_with(seq_item_inst,{
            seq_item_inst.RST       == 1'b1;
            seq_item_inst.wr_rd     == 1'b0;
            seq_item_inst.ARVALID   == 1'b0;
            seq_item_inst.RREADY    == 1'b0;
            seq_item_inst.ARID     == temp_arid;    
            seq_item_inst.ARADDR   == temp_araddr; 
            seq_item_inst.ARSIZE   == temp_arsize;
            seq_item_inst.ARBURST  == temp_arburst;
            seq_item_inst.ARLEN    == temp_arlen; 
            
            seq_item_inst.AWVALID   == 0;
            seq_item_inst.WVALID    == 0;
            seq_item_inst.BREADY    == 0;
            seq_item_inst.AWADDR    == 0;
            seq_item_inst.WDATA[0]  == 0;
            seq_item_inst.AWID      == 0;
            seq_item_inst.AWLEN     == 0;
            seq_item_inst.AWSIZE    == 0;
            seq_item_inst.AWBURST   == 0;
            seq_item_inst.WSTRB     == 0;
            seq_item_inst.WLAST     == 0; }); 

                
            `uvm_info("i", $sformatf("i value = %0d", i), UVM_MEDIUM) 
            end
            end
                    
  endtask
endclass 

