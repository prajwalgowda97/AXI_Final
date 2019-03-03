class axi_monitor extends uvm_monitor;
    `uvm_component_utils(axi_monitor)

    virtual axi_interface intf;

    // Analysis ports
    uvm_analysis_port #(axi_seq_item) wr_analysis_port;
    uvm_analysis_port #(axi_seq_item) rd_analysis_port;
    uvm_analysis_port #(axi_seq_item) handshake_port;
    
    // Separate control signal ports for write and read channels
    uvm_analysis_port #(axi_seq_item) write_control_signal_port;
    uvm_analysis_port #(axi_seq_item) read_control_signal_port;

    // Flag to trigger initial sampling
    bit first_sample = 1;

    function new(string name = "axi_monitor", uvm_component parent);
        super.new(name, parent);
        wr_analysis_port = new("wr_analysis_port", this);
        rd_analysis_port = new("rd_analysis_port", this);
        handshake_port = new("handshake_port", this);
        write_control_signal_port = new("write_control_signal_port", this);
        read_control_signal_port = new("read_control_signal_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi_interface)::get(this, "", "axi_interface", intf))
            `uvm_fatal("MONITOR", "Failed to get interface handle from config DB");
    endfunction

    // Core monitoring task
    task run_phase(uvm_phase phase);
        // Fork the control signal monitoring task
        fork
            monitor_write_control_signals();
            monitor_read_control_signals();
            monitor_transactions();
        join
    endtask

    // Dedicated task for write channel control signal monitoring
    task monitor_write_control_signals();
        axi_seq_item write_ctrl_item;
        
        // Initial sample at time 0 to capture reset state for write channel
        if (first_sample) begin
            write_ctrl_item = axi_seq_item::type_id::create("init_write_ctrl_item");
            
            // Sample write channel control signals
            write_ctrl_item.AWVALID = intf.AWVALID;
            write_ctrl_item.AWREADY = intf.AWREADY;
            write_ctrl_item.WVALID = intf.WVALID;
            write_ctrl_item.WREADY = intf.WREADY;
            write_ctrl_item.BVALID = intf.BVALID;
            write_ctrl_item.BREADY = intf.BREADY;
            write_ctrl_item.RST = intf.RST;
            write_ctrl_item.wr_rd = 1'b1; // Mark as write channel
            
            // Write to coverage collector
            write_control_signal_port.write(write_ctrl_item);
            
            `uvm_info("MONITOR_WRITE_CTRL", $sformatf("Initial write control signals: AWREADY=%0d, AWVALID=%0d, WREADY=%0d, WVALID=%0d, BREADY=%0d, BVALID=%0d", 
                write_ctrl_item.AWREADY, write_ctrl_item.AWVALID, write_ctrl_item.WREADY, write_ctrl_item.WVALID, write_ctrl_item.BREADY, write_ctrl_item.BVALID), UVM_MEDIUM)
        end
        
        forever begin
            @(posedge intf.CLK or posedge intf.RST);
            
            // Create item for write channel coverage on EVERY clock cycle
            write_ctrl_item = axi_seq_item::type_id::create("write_ctrl_item");
            
            // Sample write channel control signals
            write_ctrl_item.AWVALID = intf.AWVALID;
            write_ctrl_item.AWREADY = intf.AWREADY;
            write_ctrl_item.WVALID = intf.WVALID;
            write_ctrl_item.WREADY = intf.WREADY;
            write_ctrl_item.BVALID = intf.BVALID;
            write_ctrl_item.BREADY = intf.BREADY;
            write_ctrl_item.RST = intf.RST;
            write_ctrl_item.wr_rd = 1'b1; // Mark as write channel
            
            // Send for coverage collection
            write_control_signal_port.write(write_ctrl_item);
            
            // Debug logging
            `uvm_info("MONITOR_WRITE_CTRL", $sformatf("Write control signals: AWREADY=%0d, AWVALID=%0d, WREADY=%0d, WVALID=%0d, BREADY=%0d, BVALID=%0d", 
                write_ctrl_item.AWREADY, write_ctrl_item.AWVALID, write_ctrl_item.WREADY, write_ctrl_item.WVALID, write_ctrl_item.BREADY, write_ctrl_item.BVALID), UVM_HIGH)
        end
    endtask

    // Dedicated task for read channel control signal monitoring
    task monitor_read_control_signals();
        axi_seq_item read_ctrl_item;
        
        // Initial sample at time 0 to capture reset state for read channel
        if (first_sample) begin
            read_ctrl_item = axi_seq_item::type_id::create("init_read_ctrl_item");
            
            // Sample read channel control signals
            read_ctrl_item.ARVALID = intf.ARVALID;
            read_ctrl_item.ARREADY = intf.ARREADY;
            read_ctrl_item.RVALID = intf.RVALID;
            read_ctrl_item.RREADY = intf.RREADY;
            read_ctrl_item.RST = intf.RST;
            read_ctrl_item.wr_rd = 1'b0; // Mark as read channel
            
            // Write to coverage collector
            read_control_signal_port.write(read_ctrl_item);
            
            `uvm_info("MONITOR_READ_CTRL", $sformatf("Initial read control signals: ARREADY=%0d, ARVALID=%0d, RREADY=%0d, RVALID=%0d", 
                read_ctrl_item.ARREADY, read_ctrl_item.ARVALID, read_ctrl_item.RREADY, read_ctrl_item.RVALID), UVM_MEDIUM)
            
            first_sample = 0; // Clear the first sample flag after both write and read initial samples
        end
        
        forever begin
            @(posedge intf.CLK or posedge intf.RST);
            
            // Create item for read channel coverage on EVERY clock cycle
            read_ctrl_item = axi_seq_item::type_id::create("read_ctrl_item");
            
            // Sample read channel control signals
            read_ctrl_item.ARVALID = intf.ARVALID;
            read_ctrl_item.ARREADY = intf.ARREADY;
            read_ctrl_item.RVALID = intf.RVALID;
            read_ctrl_item.RREADY = intf.RREADY;
            read_ctrl_item.RST = intf.RST;
            read_ctrl_item.wr_rd = 1'b0; // Mark as read channel
            
            // Send for coverage collection
            read_control_signal_port.write(read_ctrl_item);
            
            // Debug logging
            `uvm_info("MONITOR_READ_CTRL", $sformatf("Read control signals: ARREADY=%0d, ARVALID=%0d, RREADY=%0d, RVALID=%0d", 
                read_ctrl_item.ARREADY, read_ctrl_item.ARVALID, read_ctrl_item.RREADY, read_ctrl_item.RVALID), UVM_HIGH)
        end
    endtask

    // Main transaction monitoring task
    task monitor_transactions();
        forever begin
            @(posedge intf.CLK);
            
            // ---- HANDSHAKE: AWVALID & AWREADY ----
            if (intf.AWVALID && intf.AWREADY) begin
                axi_seq_item hs_aw = axi_seq_item::type_id::create("hs_aw");
                hs_aw.handshake = 1'b1;
                hs_aw.wr_rd = 1'b1;
                hs_aw.AWID = intf.AWID;
                hs_aw.AWADDR = intf.AWADDR;
                hs_aw.AWVALID = intf.AWVALID;
                hs_aw.AWREADY = intf.AWREADY;
                handshake_port.write(hs_aw);
            end
             
            // ---- HANDSHAKE: ARVALID & ARREADY ----
            if (intf.ARVALID && intf.ARREADY) begin
                axi_seq_item hs_ar = axi_seq_item::type_id::create("hs_ar");
                hs_ar.handshake = 1'b1;
                hs_ar.wr_rd = 1'b0;
                hs_ar.ARID = intf.ARID;
                hs_ar.ARADDR = intf.ARADDR;
                hs_ar.ARVALID = intf.ARVALID;
                hs_ar.ARREADY = intf.ARREADY;
                handshake_port.write(hs_ar);
            end

            // ---- WRITE TRANSACTION ----
            if (intf.AWVALID && intf.AWREADY) begin
                axi_seq_item write_item = axi_seq_item::type_id::create("write_item");

                write_item.wr_rd = 1'b1;
                write_item.AWID = intf.AWID;
                write_item.AWADDR = intf.AWADDR;
                write_item.AWLEN = intf.AWLEN;
                write_item.AWSIZE = intf.AWSIZE;
                write_item.AWBURST = intf.AWBURST;
                write_item.AWVALID = intf.AWVALID;
                write_item.AWREADY = intf.AWREADY;
                write_item.RST = intf.RST;

                `uvm_info("MONITOR_WRITE", $sformatf("Write channel: AWREADY=%0d, AWVALID=%0d, AWADDR=0x%0h", 
                    write_item.AWREADY, write_item.AWVALID, write_item.AWADDR), UVM_MEDIUM)
            
                // Capture write data beats
                for (int i = 0; i <= intf.AWLEN; i++) begin
                    @(posedge intf.CLK);
                    
                    // Wait for write data handshake
                    do begin
                        @(posedge intf.CLK);
                    end while (!(intf.WVALID && intf.WREADY));

                    write_item.WDATA.push_back(intf.WDATA);
                    write_item.WSTRB = intf.WSTRB;
                    write_item.WLAST = intf.WLAST;
                    write_item.WVALID = intf.WVALID;
                    write_item.WREADY = intf.WREADY;

                    if (intf.WLAST) break;
                end

                // Capture write response
                do begin
                    @(posedge intf.CLK);
                end while (!(intf.BVALID && intf.BREADY));
                
                `uvm_info("MONITOR_WRITE_RESP", $sformatf(
                 "BREADY=0x%0b, BVALID=0x%0b, BID=0x%0h", intf.BREADY, intf.BVALID, intf.BID), UVM_MEDIUM);

                write_item.BRESP = intf.BRESP;
                write_item.BID = intf.BID;
                write_item.BVALID = intf.BVALID;
                write_item.BREADY = intf.BREADY;
            
                // Send to scoreboard
                wr_analysis_port.write(write_item);
            end

            // ---- READ TRANSACTION ----
            if (intf.ARVALID && intf.ARREADY) begin
                axi_seq_item read_item = axi_seq_item::type_id::create("read_item");

                read_item.wr_rd = 1'b0;
                read_item.ARID = intf.ARID;
                read_item.ARADDR = intf.ARADDR;
                read_item.ARLEN = intf.ARLEN;
                read_item.ARSIZE = intf.ARSIZE;
                read_item.ARBURST = intf.ARBURST;
                read_item.ARVALID = intf.ARVALID;
                read_item.ARREADY = intf.ARREADY;

                `uvm_info("MONITOR_READ", $sformatf("Read channel: ARREADY=%0d, ARVALID=%0d, ARADDR=0x%0h", 
                    read_item.ARREADY, read_item.ARVALID, read_item.ARADDR), UVM_MEDIUM)

                // Capture read data beats
                for (int i = 0; i <= intf.ARLEN; i++) begin
                    // Wait for read data handshake
                    do begin
                        @(posedge intf.CLK);
                    end while (!(intf.RVALID && intf.RREADY));

                    read_item.RDATA = intf.RDATA;
                    read_item.RRESP = intf.RRESP;
                    read_item.RLAST = intf.RLAST;
                    read_item.RVALID = intf.RVALID;
                    read_item.RREADY = intf.RREADY;

                    if (intf.RLAST) break;
                end

                // Send to scoreboard
                rd_analysis_port.write(read_item);
            end
        end
    endtask
endclass
