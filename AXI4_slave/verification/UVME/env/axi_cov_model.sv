class axi_cov_model extends uvm_subscriber #(axi_seq_item);
  `uvm_component_utils(axi_cov_model)
  
  axi_seq_item item;
  // Types adjusted to match actual signal types in axi_seq_item
  bit [31:0] wdata[$]; // WDATA is a queue of 32-bit values
  bit [31:0] rdata;    // RDATA is a single 32-bit value
  bit [31:0] awaddr, araddr;

  covergroup axi_write_cg;
    // AW Channel coverage
    RST: coverpoint item.RST {
      bins deasserted = {1};
      bins asserted   = {0};
    }

    AWREADY: coverpoint item.AWREADY {
      bins deasserted = {0};
      bins asserted   = {1};
    }

    AWVALID: coverpoint item.AWVALID {
      bins deasserted = {0};
      bins asserted   = {1};
    }
    
    AWID: coverpoint item.AWID {
      bins id[] = {[0:3]};
      illegal_bins invalid = {[4:$]};
    }
    
    AWADDR: coverpoint awaddr {
      // Using auto bins for address range
      option.auto_bin_max = 16;
      
      bins addr_range = {[0:32'hFFFFFFFF]};
    }
    
    AWLEN: coverpoint item.AWLEN {
      bins single_beat  = {0};
      bins short_burst  = {[1:7]};
    }
    
  AWSIZE: coverpoint item.AWSIZE {
    bins awsize_0_1 = {[0:1]};
    bins awsize_2_3 = {[2:3]};
    bins awsize_4_7 = {[4:7]};
  
  // Optional: Add illegal bins if needed
  illegal_bins invalid = {[8:$]};
}   
    AWBURST: coverpoint item.AWBURST {
      bins fixed  = {0};
      bins incr   = {1};
      bins wrap   = {2};
      ignore_bins reserved = {3};
    }

    WVALID: coverpoint item.WVALID {
      bins deasserted = {0};
      bins asserted   = {1};
    }

    WREADY: coverpoint item.WREADY {
      bins deasserted = {0};
      bins asserted   = {1};
    }

    // W Channel coverage - Fixed: added safety check for empty queue
    WDATA: coverpoint (wdata.size() > 0 ? wdata[0] : 0) {
      option.auto_bin_max = 16;  // Set number of auto bins
    }

    WSTRB: coverpoint item.WSTRB { 
      option.auto_bin_max = 4;
     } 
    
    WLAST: coverpoint item.WLAST {
      bins asserted = {1};
      bins not_asserted = {0};
    }

    BID: coverpoint item.BID {
      bins id_range[] = {[0:3]};
    }

    BVALID: coverpoint item.BVALID {
      bins deasserted = {0};
      bins asserted   = {1};
    }

    BREADY: coverpoint item.BREADY {
      bins deasserted = {0};
      bins asserted   = {1};
    }

    // B Channel coverage
    BRESP: coverpoint item.BRESP {
      bins okay = {0};
      //bins exokay = {1};
      //bins slverr = {2};
      //bins decerr = {3};
    }
       
    ADDR_BURST_CROSS: cross AWBURST, AWADDR {
      // Only sample when interesting
      ignore_bins not_interesting = binsof(AWBURST.reserved);
    }
      
  endgroup
  
  covergroup axi_read_cg;
    // AR Channel coverage
     option.per_instance = 1;
    ARREADY: coverpoint item.ARREADY {
      bins deasserted = {0};
      bins asserted   = {1};
    }

    ARVALID: coverpoint item.ARVALID {
      bins deasserted = {0};
      bins asserted   = {1};
    }

    ARID: coverpoint item.ARID {
      bins id[] = {[0:3]};
      illegal_bins invalid = {[4:$]};
    }
    
    ARADDR: coverpoint araddr {
      // Using auto bins for address range
      option.auto_bin_max = 16;
      
      bins word_aligned = {[0:32'hFFFFFFFF]};
    }
    
    ARLEN: coverpoint item.ARLEN {
      bins single_beat  = {0};
      bins short_burst  = {[1:7]};
    }
    
    ARSIZE: coverpoint item.ARSIZE {
  bins arsize_0_1 = {[0:1]};
  bins arsize_2_3 = {[2:3]};
  bins arsize_4_7 = {[4:7]};
  
  // Optional: Add illegal bins if needed
  illegal_bins invalid = {[8:$]};
}
    
    ARBURST: coverpoint item.ARBURST {
      bins fixed  = {0};
      bins incr   = {1};
      bins wrap   = {2};
      ignore_bins reserved = {3};
    }

    RREADY: coverpoint item.RREADY {
      bins deasserted = {0};
      bins asserted   = {1};
    }

    RVALID: coverpoint item.RVALID {
      bins deasserted = {0};
      bins asserted   = {1};
    }
    
    RRESP: coverpoint item.RRESP {
      bins okay = {0};
      //bins exokay = {1};
      //bins slverr = {2};
      //bins decerr = {3};
    }

    // Using directly the RDATA value
    RDATA: coverpoint rdata {
      option.auto_bin_max = 16;  // Set number of auto bins
    }
    
    RLAST: coverpoint item.RLAST {
      bins asserted = {1};
      bins not_asserted = {0};
    }
    
    
    ADDR_BURST_CROSS: cross ARBURST, ARADDR {
      // Only sample when interesting
      ignore_bins not_interesting = binsof(ARBURST.reserved);
    }    
  endgroup
  
  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
    
    // Initialize covergroups
    axi_write_cg = new();
    axi_read_cg = new();
  endfunction
  
  // Build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info("COV_MODEL", "Build phase executed", UVM_MEDIUM)
  endfunction

  // Write method - handles both read and write transactions
  function void write(axi_seq_item t);
    item = t;
    
    // Extract data for coverage sampling
    awaddr = t.AWADDR;
    araddr = t.ARADDR;
    
    // Handle WDATA (queue) - safety check for empty queue
    if (t.WDATA.size() > 0) begin
      wdata = t.WDATA;
    end
    else begin
      wdata = {};
    end
    
    // Handle RDATA (single value)
    rdata = t.RDATA;
    
    // Sample appropriate coverage group based on transaction type
    if (t.wr_rd == 1'b1) begin
      // This is a write transaction
      `uvm_info("COV_MODEL", $sformatf("Sampling write coverage for transaction: WSTRB=0x%0h, AWSIZE=0x%0h", t.WSTRB, t.AWSIZE), UVM_MEDIUM)
      axi_write_cg.sample();
      
    end
    else begin
      // This is a read transaction
      `uvm_info("COV_MODEL", $sformatf("Sampling read coverage for transaction: ARSIZE=0x%0h", t.ARSIZE), UVM_MEDIUM)
      axi_read_cg.sample();

    end
  endfunction

endclass
