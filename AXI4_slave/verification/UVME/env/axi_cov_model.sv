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
     // bins exokay = {1};
     // bins slverr = {2};
     // bins decerr = {3};
    }
       
    // Original cross coverage
    ADDR_BURST_CROSS: cross AWBURST, AWADDR {
      // Only sample when interesting
      ignore_bins not_interesting = binsof(AWBURST) intersect {3};
    }
    
    // Added cross coverage points as requested
       
    // 2. AWADDR × AWLEN × AWSIZE
    ADDR_LEN_SIZE_CROSS: cross AWADDR, AWLEN, AWSIZE;
    
    // 3. AWLEN × AWSIZE × AWBURST
    BURST_CONFIG_CROSS: cross AWLEN, AWSIZE, AWBURST {

    ignore_bins na_short_burst_awsize_0_1_fixed = binsof(AWLEN.short_burst) && binsof(AWSIZE.awsize_0_1) && binsof(AWBURST.fixed);
    ignore_bins na_short_burst_awsize_2_3_fixed = binsof(AWLEN.short_burst) && binsof(AWSIZE.awsize_2_3) && binsof(AWBURST.fixed);
    ignore_bins na_short_burst_awsize_4_7_fixed = binsof(AWLEN.short_burst) && binsof(AWSIZE.awsize_4_7) && binsof(AWBURST.fixed);
    ignore_bins na_single_beat_awsize_0_1_wrap = binsof(AWLEN.single_beat) && binsof(AWSIZE.awsize_0_1) && binsof(AWBURST.wrap);
    ignore_bins na_single_beat_awsize_2_3_wrap = binsof(AWLEN.single_beat) && binsof(AWSIZE.awsize_2_3) && binsof(AWBURST.wrap);
    ignore_bins na_single_beat_awsize_4_7_wrap = binsof(AWLEN.single_beat) && binsof(AWSIZE.awsize_4_7) && binsof(AWBURST.wrap);
    ignore_bins na_short_burst_awsize_4_7_wrap = binsof(AWLEN.short_burst) && binsof(AWSIZE.awsize_4_7) && binsof(AWBURST.wrap);
    ignore_bins invalid_burst = binsof(AWBURST) intersect {3};
    }
    
    // 4. AWID × AWLEN
    ID_LEN_CROSS: cross AWID, AWLEN;
    
    // 5. Handshake timing crosses
    AW_HANDSHAKE_CROSS: cross AWVALID, AWREADY {
    ignore_bins ignore_deasserted_asserted = binsof(AWVALID.deasserted) && binsof(AWREADY.asserted);
    }
   
    W_HANDSHAKE_CROSS: cross WVALID, WREADY {
    ignore_bins ignore_deasserted_asserted = binsof(WVALID.asserted) && binsof(WREADY.deasserted);
    }

    B_HANDSHAKE_CROSS: cross BVALID, BREADY {
    ignore_bins ignore_deasserted_asserted = binsof(BVALID.deasserted) && binsof(BREADY.asserted);
    ignore_bins ignore_asserted_deasserted = binsof(BVALID.asserted) && binsof(BREADY.deasserted);
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
     // bins exokay = {1};
     // bins slverr = {2};
     // bins decerr = {3};
    }

    // Using directly the RDATA value
    RDATA: coverpoint rdata {
      option.auto_bin_max = 16;  // Set number of auto bins
    }
    
    RLAST: coverpoint item.RLAST {
      bins asserted = {1};
      bins not_asserted = {0};
    }
    
    // Original cross coverage
    ADDR_BURST_CROSS: cross ARBURST, ARADDR {
      // Only sample when interesting
      ignore_bins not_interesting = binsof(ARBURST) intersect {3};
    }
      
    // 2. ARADDR × ARLEN × ARSIZE
    ADDR_LEN_SIZE_CROSS: cross ARADDR, ARLEN, ARSIZE;
    
    // 3. ARLEN × ARSIZE × ARBURST
    BURST_CONFIG_CROSS: cross ARLEN, ARSIZE, ARBURST {
    ignore_bins na_short_burst_arsize_0_1_fixed = binsof(ARLEN.short_burst) && binsof(ARSIZE.arsize_0_1) && binsof(ARBURST.fixed);
    ignore_bins na_short_burst_arsize_2_3_fixed = binsof(ARLEN.short_burst) && binsof(ARSIZE.arsize_2_3) && binsof(ARBURST.fixed);
    ignore_bins na_short_burst_arsize_4_7_fixed = binsof(ARLEN.short_burst) && binsof(ARSIZE.arsize_4_7) && binsof(ARBURST.fixed);
    ignore_bins na_single_beat_arsize_0_1_wrap = binsof(ARLEN.single_beat) && binsof(ARSIZE.arsize_0_1) && binsof(ARBURST.wrap);
    ignore_bins na_single_beat_arsize_2_3_wrap = binsof(ARLEN.single_beat) && binsof(ARSIZE.arsize_2_3) && binsof(ARBURST.wrap);
    ignore_bins na_single_beat_arsize_4_7_wrap = binsof(ARLEN.single_beat) && binsof(ARSIZE.arsize_4_7) && binsof(ARBURST.wrap);
    ignore_bins invalid_burst = binsof(ARBURST) intersect {3};
    }
    
    // 4. ARID × ARLEN
    ID_LEN_CROSS: cross ARID, ARLEN;
    
    // 5. RRESP × RLAST (response at different points in a burst)
    RRESP_RLAST_CROSS: cross RRESP, RLAST;
    
    // 6. Handshake timing crosses
    AR_HANDSHAKE_CROSS: cross ARVALID, ARREADY {
    ignore_bins ignore_deasserted_asserted = binsof(ARVALID.deasserted) && binsof(ARREADY.asserted);
    }

    R_HANDSHAKE_CROSS: cross RVALID, RREADY{
    ignore_bins ignore_deasserted_asserted = binsof(RVALID.deasserted) && binsof(RREADY.asserted);
    ignore_bins ignore_asserted_deasserted = binsof(RVALID.asserted) && binsof(RREADY.deasserted);
    }

  endgroup
  
  // Additional transaction-level cross-coverage
  covergroup axi_transaction_cg;
    option.per_instance = 1;
    
    // Transaction type (read vs write)
    TRANSACTION_TYPE: coverpoint item.wr_rd {
      bins write = {1};
      bins read = {0};
    }
        
    // Cross read and write burst types
    BURST_TYPE: coverpoint item.AWBURST {
      bins valid_types[] = {[0:2]};
      ignore_bins reserved = {3};
    }
    
    AR_BURST_TYPE: coverpoint item.ARBURST {
      bins valid_types[] = {[0:2]};
      ignore_bins reserved = {3};
    }
    
  endgroup

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
    
    // Initialize covergroups
    axi_write_cg = new();
    axi_read_cg = new();
    axi_transaction_cg = new();
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
    
    // Sample transaction-level coverage for all transactions
    axi_transaction_cg.sample();
    
    // Sample appropriate coverage group based on transaction type
    if (t.wr_rd == 1'b1) begin
      // This is a write transaction
      `uvm_info("COV_MODEL", $sformatf("Sampling write coverage for transaction: WSTRB=0x%0h, AWSIZE=0x%0h", t.WSTRB, t.AWSIZE), UVM_MEDIUM)
      axi_write_cg.sample();
        
        `uvm_info("MONITOR", 
            $sformatf("\nCOV Write Address signals:\t AWVALID=0x%0b\t AWREADY=0x%0b\n", 
            item.AWVALID, item.AWREADY), UVM_MEDIUM)
    end
    else begin
      // This is a read transaction
      `uvm_info("COV_MODEL", $sformatf("Sampling read coverage for transaction: ARSIZE=0x%0h", t.ARSIZE), UVM_MEDIUM)
      axi_read_cg.sample();
        
        `uvm_info("MONITOR", 
            $sformatf("\nCOV Write Address signals:\t ARVALID=0x%0b\t ARREADY=0x%0b\n", 
            item.ARVALID, item.ARREADY), UVM_MEDIUM)
    end
  endfunction

endclass
