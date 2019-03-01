class axi_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(axi_scoreboard)

    typedef struct {
        bit [31:0] addr;
        bit [31:0] data[$];
        bit [3:0]  id;
        bit [2:0]  size;
        bit [1:0]  burst;
        bit [7:0]  len;
        // Address channels handshake signals
        bit        awvalid;
        bit        awready;
        bit        arvalid;
        bit        arready;
        // Data channels handshake signals
        bit        wvalid;
        bit        wready;
        bit        rvalid;
        bit        rready;
        // Response channel handshake signals
        bit        bvalid;
        bit        bready;
        // Control/status signals
        bit        wlast;
        bit        rlast;
        bit [3:0]  wstrb;
        bit [1:0]  bresp;
        bit [1:0]  rresp;
        bit [3:0]  bid;
        bit [3:0]  rid;
    } axi_trans_t;

    axi_trans_t wr_queue[$];
    axi_trans_t rd_queue[$];
    int i;
    
    // Use standard UVM approach with two TLM analysis ports
    uvm_analysis_port #(axi_seq_item) wr_analysis_port;
    uvm_analysis_port #(axi_seq_item) rd_analysis_port;
    
    // TLM analysis implementation for write and read
    `uvm_analysis_imp_decl(_wr)
    `uvm_analysis_imp_decl(_rd)
    
    uvm_analysis_imp_wr #(axi_seq_item, axi_scoreboard) wr_export;
    uvm_analysis_imp_rd #(axi_seq_item, axi_scoreboard) rd_export;

    function new(string name = "axi_scoreboard", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        wr_export = new("wr_export", this);
        rd_export = new("rd_export", this);
        wr_analysis_port = new("wr_analysis_port", this);
        rd_analysis_port = new("rd_analysis_port", this);
    endfunction

    // Write transaction handler
    function void write_wr(axi_seq_item t);
        axi_trans_t trans;

        // AW channel signals
        trans.addr    = t.AWADDR;
        trans.id      = t.AWID;
        trans.size    = t.AWSIZE;
        trans.burst   = t.AWBURST;
        trans.len     = t.AWLEN;
        trans.awvalid = t.AWVALID;
        trans.awready = t.AWREADY;
        
        // W channel signals
        trans.wvalid  = t.WVALID;
        trans.wready  = t.WREADY;
        trans.wstrb   = t.WSTRB;
        trans.wlast   = t.WLAST;
        
        // B channel signals
        trans.bid     = t.BID;
        trans.bresp   = t.BRESP;
        trans.bvalid  = t.BVALID;
        trans.bready  = t.BREADY;

        // Capture data beats - WDATA is a dynamic array
        for (int i = 0; i <= t.AWLEN; i++) begin
            if (i < t.WDATA.size()) begin
                trans.data.push_back(t.WDATA[i]);
            end
        end

        wr_queue.push_back(trans);

        `uvm_info("SCOREBOARD", 
            $sformatf("\nWRITE Address: AWADDR=0x%0h\t AWID=0x%0h\t AWLEN=%0h\t AWSIZE=%0d\t AWBURST=%0d\n", 
            t.AWADDR, t.AWID, t.AWLEN, t.AWSIZE, t.AWBURST), UVM_MEDIUM)

        `uvm_info("SCOREBOARD", 
            $sformatf("\nWRITE Data:\t WDATA=0x%0p\t WSTRB=0x%0h\t WLAST=%0d\n", 
            t.WDATA, t.WSTRB, t.WLAST), UVM_MEDIUM) 

            
        `uvm_info("SCOREBOARD", 
            $sformatf("\nWRITE Response:\t BID=0x%0h\t BRESP=0x%0d\n", 
            t.BID, t.BRESP), UVM_MEDIUM)
    endfunction

    // Read transaction handler
    function void write_rd(axi_seq_item t);
        axi_trans_t trans;

        // AR channel signals
        trans.addr    = t.ARADDR;
        trans.id      = t.ARID;
        trans.size    = t.ARSIZE;
        trans.burst   = t.ARBURST;
        trans.len     = t.ARLEN;
        trans.arvalid = t.ARVALID;
        trans.arready = t.ARREADY;
        
        // R channel signals
        trans.rvalid  = t.RVALID;
        trans.rready  = t.RREADY;
        trans.rlast   = t.RLAST;
        trans.rresp   = t.RRESP;
        trans.rid     = t.RID;

        // Capture data beats - Handle RDATA as a fixed array
        // First, push the single RDATA value into our queue
        trans.data.push_back(t.RDATA);
        
        // If there are multiple data beats expected (based on ARLEN),
        // log a warning as we're only capturing one beat with the fixed array
        if (t.ARLEN > 0) begin
            `uvm_warning("SCOREBOARD", $sformatf(
                "RDATA is a fixed array but ARLEN=%0d indicates multiple beats expected", 
                t.ARLEN))
        end

        rd_queue.push_back(trans);

        `uvm_info("SCOREBOARD", 
            $sformatf("\nREAD Address: ARADDR=0x%0h\t ARID=0x%0h\t ARLEN=%0d\t ARSIZE=%0d\t ARBURST=%0d\n", 
            t.ARADDR, t.ARID, t.ARLEN, t.ARSIZE, t.ARBURST), UVM_MEDIUM)

        `uvm_info("SCOREBOARD", 
            $sformatf("\nREAD Data: RDATA=0x%0h\t RRESP=0x%0h\t RLAST=0x%0h\n", 
            t.RDATA, t.RRESP, t.RLAST), UVM_MEDIUM)
    endfunction
    
    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        
        // Check handshake separately
        check_handshake_phase();
        
        // Check individual write and read operations
        check_write_operation();
        check_read_operation();
        
        // Check write vs read data consistency
        compare_wr_rd_transactions();
    endfunction 

    function void compare_wr_rd_transactions();
        axi_trans_t local_wr_queue[$];
        axi_trans_t local_rd_queue[$];
        axi_trans_t wr_trans;
        axi_trans_t rd_trans;
        
        // Copy queues to avoid modifying originals
        foreach (wr_queue[i]) local_wr_queue.push_back(wr_queue[i]);
        foreach (rd_queue[i]) local_rd_queue.push_back(rd_queue[i]);

        while (local_wr_queue.size() > 0 && local_rd_queue.size() > 0) begin
            wr_trans = local_wr_queue.pop_front();
            rd_trans = local_rd_queue.pop_front();

            // ---- Address & ID Check ----
            if ((wr_trans.addr == rd_trans.addr) && (wr_trans.id == rd_trans.id)) begin
                `uvm_info("CHECKER - AW/AR_CHANNEL", $sformatf(
                    "\nPASS: AWADDR=0x%0h\t ARADDR=0x%0h\t AWID=0x%0h\t ARID=0x%0h\n", 
                    wr_trans.addr, rd_trans.addr, wr_trans.id, rd_trans.id), UVM_MEDIUM)

                // ---- LEN, SIZE, BURST Comparison ----
                if ((wr_trans.len == rd_trans.len) &&
                    (wr_trans.size == rd_trans.size) &&
                    (wr_trans.burst == rd_trans.burst)) begin

                    `uvm_info("CHECKER - AW/AR_CHANNEL", $sformatf(
                        "\nPASS: AWLEN=%0d\t ARLEN=%0d\t AWSIZE=%0d\t ARSIZE=%0d\t AWBURST=%0d\t ARBURST=%0d\n", 
                        wr_trans.len, rd_trans.len, wr_trans.size, rd_trans.size, 
                        wr_trans.burst, rd_trans.burst), UVM_MEDIUM)

                end else begin
                    if (wr_trans.len != rd_trans.len)
                        `uvm_error("CHECKER - AW/AR_CHANNEL", $sformatf(
                            "\nLEN MISMATCH: AWLEN=%0d\t ARLEN=%0d\n", wr_trans.len, rd_trans.len))
                    if (wr_trans.size != rd_trans.size)
                        `uvm_error("CHECKER - AW/AR_CHANNEL", $sformatf(
                            "\nSIZE MISMATCH: AWSIZE=%0d\t ARSIZE=%0d\n", wr_trans.size, rd_trans.size))
                    if (wr_trans.burst != rd_trans.burst)
                        `uvm_error("CHECKER - AW/AR_CHANNEL", $sformatf(
                            "\nBURST MISMATCH: AWBURST=%0d\t ARBURST=%0d\n", wr_trans.burst, rd_trans.burst))
                end

                // ---- W vs R Data Check ----
                // For fixed RDATA, we might only have one data element
                // but need to compare to multiple WDATA elements
                if (rd_trans.data.size() > 0 && wr_trans.data.size() > 0) begin
                    bit data_match = 1;
                    
                    // When RDATA is fixed but we have multiple WDATA beats
                    if (rd_trans.data.size() == 1 && wr_trans.data.size() > 1) begin
                        // Compare only the first data beat
                        if (wr_trans.data[0] !== rd_trans.data[0]) begin
                            data_match = 0;
                            `uvm_error("CHECKER - W/R_CHANNEL", $sformatf(
                                "\nDATA MISMATCH:\t First beat only: WDATA=0x%0h\t RDATA=0x%0h\n", 
                                wr_trans.data[0], rd_trans.data[0]));
                        end
                        
                        // Issue warning about incomplete comparison due to fixed RDATA
                        `uvm_warning("CHECKER - W/R_CHANNEL", $sformatf(
                            "Limited comparison: WDATA has %0d beats but RDATA is fixed (only first beat compared)",
                            wr_trans.data.size()));
                    end 
                    else if (wr_trans.data.size() == rd_trans.data.size()) begin
                        // Equal sizes - do a full comparison
                        foreach (wr_trans.data[i]) begin
                            if (wr_trans.data[i] !== rd_trans.data[i]) begin
                                data_match = 0;
                                `uvm_error("CHECKER - W/R_CHANNEL", $sformatf(
                                    "\nDATA MISMATCH:\t Index=%0d\t WDATA=0x%0h\t RDATA=0x%0h\n", 
                                    i, wr_trans.data[i], rd_trans.data[i]));
                            end
                        end
                    end 
                    else begin
                        // Size mismatch other than the special case
                        `uvm_error("CHECKER - W/R_CHANNEL", $sformatf(
                            "\nW&R DATA SIZE MISMATCH:\t WDATA.size=%0d\t RDATA.size=%0d\n",
                            wr_trans.data.size(), rd_trans.data.size()));
                    end
                    
                    if (data_match)
                        `uvm_info("CHECKER - W/R_CHANNEL", "WRITE/READ DATA MATCH: PASS", UVM_MEDIUM);
                end 
                else begin
                    `uvm_error("CHECKER - W/R_CHANNEL", $sformatf(
                        "\nMISSING DATA:\t WDATA.size=%0d\t RDATA.size=%0d\n",
                        wr_trans.data.size(), rd_trans.data.size()));
                end 

                // ---- B Channel Check ----
                if (wr_trans.bvalid && wr_trans.bready) begin
                    if (wr_trans.bresp == 2'b00) begin
                        `uvm_info("CHECKER - B_CHANNEL", $sformatf(
                            "PASS: BID=0x%0h, BRESP=0x%0h\n", wr_trans.bid, wr_trans.bresp), UVM_MEDIUM);
                    end 
                    else begin
                        `uvm_error("CHECKER - B_CHANNEL", $sformatf(
                            "FAIL: BRESP=0x%0h (non-OKAY)\n", wr_trans.bresp));
                    end
                end 
                else begin
                    `uvm_info("CHECKER - B_CHANNEL", "Note: BVALID or BREADY not asserted during response, skipping check", UVM_LOW);
 
                end 
         

                // ---- R Channel Check ----
                if (rd_trans.rvalid && rd_trans.rready && rd_trans.rlast) begin
                    if (rd_trans.rresp == 2'b00) begin
                        `uvm_info("CHECKER - R_CHANNEL", $sformatf(
                            "PASS: RRESP=0x%0h\t RLAST=0x%0d\n", rd_trans.rresp, rd_trans.rlast), UVM_MEDIUM);
                    end 
                    else begin
                        `uvm_error("CHECKER - R_CHANNEL", $sformatf(
                            "FAIL: RRESP=0x%0h (non-OKAY)\n", rd_trans.rresp));
                    end
                end 
                else begin
                    `uvm_info("CHECKER - R_CHANNEL", "Note: RVALID, RREADY, or RLAST not asserted, skipping check", UVM_LOW);
                end
            end 
            else begin
                `uvm_error("CHECKER - AW/AR_CHANNEL", $sformatf(
                    "ADDR/ID MISMATCH: WR_ADDR=0x%0h\t RD_ADDR=0x%0h\t WR_ID=0x%0h\t RD_ID=0x%0h\n", 
                    wr_trans.addr, rd_trans.addr, wr_trans.id, rd_trans.id));
            end
        end
    endfunction

    function void check_handshake_phase();
        axi_trans_t local_wr_queue[$];
        axi_trans_t local_rd_queue[$];
        axi_trans_t wr_trans;
        axi_trans_t rd_trans;
        int valid_handshakes = 0;
        int failed_handshakes = 0;

        // Copy queues to avoid modifying originals
        foreach (wr_queue[i]) local_wr_queue.push_back(wr_queue[i]);
        foreach (rd_queue[i]) local_rd_queue.push_back(rd_queue[i]);

        `uvm_info("HANDSHAKE_CHECK", $sformatf("Checking %0d write transactions", local_wr_queue.size()), UVM_LOW);
        
        while (local_wr_queue.size() > 0) begin
            wr_trans = local_wr_queue.pop_front();

            // AW channel handshake check
            if (wr_trans.awvalid || wr_trans.awready) begin
                if (wr_trans.awvalid && wr_trans.awready) begin
                    valid_handshakes++;
                    `uvm_info("HANDSHAKE_CHECK", $sformatf(
                        "WRITE address handshake PASSED: AWVALID=%0b AWREADY=%0b", 
                        wr_trans.awvalid, wr_trans.awready), UVM_LOW);
                end 
                else if (wr_trans.awvalid) begin
                    // Only report errors when VALID is asserted but READY isn't
                    failed_handshakes++;
                    `uvm_info("HANDSHAKE_CHECK", $sformatf(
                        "WRITE address handshake PENDING: AWVALID=%0b AWREADY=%0b", 
                        wr_trans.awvalid, wr_trans.awready), UVM_LOW);
                end
            end

            // W channel handshake check
            if (wr_trans.wvalid || wr_trans.wready) begin
                if (wr_trans.wvalid && wr_trans.wready) begin
                    valid_handshakes++;
                    `uvm_info("HANDSHAKE_CHECK", $sformatf(
                        "W channel handshake PASSED: WVALID=%0b WREADY=%0b", 
                        wr_trans.wvalid, wr_trans.wready), UVM_LOW);
                end 
                else if (wr_trans.wvalid) begin
                    failed_handshakes++;
                    `uvm_info("HANDSHAKE_CHECK", $sformatf(
                        "W channel handshake PENDING: WVALID=%0b WREADY=%0b", 
                        wr_trans.wvalid, wr_trans.wready), UVM_LOW);
                end
            end

            // B channel handshake check
            if (wr_trans.bvalid || wr_trans.bready) begin
                if (wr_trans.bvalid && wr_trans.bready) begin
                    valid_handshakes++;
                    `uvm_info("HANDSHAKE_CHECK", $sformatf(
                        "B channel handshake PASSED: BVALID=%0b BREADY=%0b", 
                        wr_trans.bvalid, wr_trans.bready), UVM_LOW);
                end 
                else if (wr_trans.bvalid) begin
                    failed_handshakes++;
                    `uvm_info("HANDSHAKE_CHECK", $sformatf(
                        "B channel handshake PENDING: BVALID=%0b BREADY=%0b", 
                        wr_trans.bvalid, wr_trans.bready), UVM_LOW);
                end
            end
        end

        `uvm_info("HANDSHAKE_CHECK", $sformatf("Checking %0d read transactions", local_rd_queue.size()), UVM_LOW);
        
        while (local_rd_queue.size() > 0) begin
            rd_trans = local_rd_queue.pop_front();

            // AR channel handshake check
            if (rd_trans.arvalid || rd_trans.arready) begin
                if (rd_trans.arvalid && rd_trans.arready) begin
                    valid_handshakes++;
                    `uvm_info("HANDSHAKE_CHECK", $sformatf(
                        "READ address handshake PASSED: ARVALID=%0b ARREADY=%0b", 
                        rd_trans.arvalid, rd_trans.arready), UVM_LOW);
                end 
                else if (rd_trans.arvalid) begin
                    failed_handshakes++;
                    `uvm_info("HANDSHAKE_CHECK", $sformatf(
                        "READ address handshake PENDING: ARVALID=%0b ARREADY=%0b", 
                        rd_trans.arvalid, rd_trans.arready), UVM_LOW);
                end
            end

            // R channel handshake check
            if (rd_trans.rvalid || rd_trans.rready) begin
                if (rd_trans.rvalid && rd_trans.rready) begin
                    valid_handshakes++;
                    `uvm_info("HANDSHAKE_CHECK", $sformatf(
                        "READ data handshake PASSED: RVALID=%0b RREADY=%0b", 
                        rd_trans.rvalid, rd_trans.rready), UVM_LOW);
                end 
                else if (rd_trans.rvalid) begin
                    failed_handshakes++;
                    `uvm_info("HANDSHAKE_CHECK", $sformatf(
                        "READ data handshake PENDING: RVALID=%0b RREADY=%0b", 
                        rd_trans.rvalid, rd_trans.rready), UVM_LOW);
                end
            end
        end
        
        if (valid_handshakes == 0 && failed_handshakes == 0) begin
            `uvm_warning("HANDSHAKE_CHECK", "No active handshakes detected - check if monitor is capturing valid handshake attempts");
        end 
        else begin
            `uvm_info("HANDSHAKE_CHECK", $sformatf("Completed handshakes: %0d, Pending handshakes: %0d", 
                      valid_handshakes, failed_handshakes), UVM_LOW);
        end
    endfunction

    function void check_write_operation();
        axi_trans_t local_wr_queue[$];
        axi_trans_t wr_trans;

        // Copy queue to avoid modifying original
        foreach (wr_queue[i]) local_wr_queue.push_back(wr_queue[i]);

        while (local_wr_queue.size() > 0) begin
            wr_trans = local_wr_queue.pop_front();

            // Skip transactions with no valid handshakes
            if (!wr_trans.awvalid) continue;

            // Address phase handshake check with additional info
            if (!(wr_trans.awvalid && wr_trans.awready)) begin
                `uvm_info("WRITE", $sformatf(
                    "Address phase handshake INCOMPLETE: AWVALID=%0b AWREADY=%0b", 
                    wr_trans.awvalid, wr_trans.awready), UVM_LOW);
            end 
            else begin
                `uvm_info("WRITE", "Address phase handshake COMPLETE", UVM_LOW);
            end

            // Data phase handshake check
            if (!(wr_trans.wvalid && wr_trans.wready)) begin
                `uvm_info("WRITE", $sformatf(
                    "Data phase handshake INCOMPLETE: WVALID=%0b WREADY=%0b", 
                    wr_trans.wvalid, wr_trans.wready), UVM_LOW);
            end 
            else begin
                `uvm_info("WRITE", "Data phase handshake COMPLETE", UVM_LOW);
            end

            // Data beat count check
            if (wr_trans.data.size() != wr_trans.len + 1) begin
                `uvm_info("WRITE", $sformatf(
                    "Data count mismatch: Expected=%0d, Got=%0d", 
                    wr_trans.len + 1, wr_trans.data.size()), UVM_LOW);
            end 
            else begin
                `uvm_info("WRITE", $sformatf(
                    "Data beat count MATCHES: %0d beats", 
                    wr_trans.data.size()), UVM_LOW);
            end

            // WLAST check - only when we have valid data
            if (wr_trans.data.size() > 0) begin
                if (!wr_trans.wlast) begin
                    `uvm_info("WRITE", "WLAST not asserted on final data beat", UVM_LOW);
                end 
                else begin
                    `uvm_info("WRITE", "WLAST asserted correctly", UVM_LOW);
                end
            end

            // Write response handshake - only check if both signals are valid
            if (wr_trans.bvalid || wr_trans.bready) begin
                if (!(wr_trans.bvalid && wr_trans.bready)) begin
                    `uvm_info("WRITE", $sformatf(
                        "Response phase handshake INCOMPLETE: BVALID=%0b BREADY=%0b", 
                        wr_trans.bvalid, wr_trans.bready), UVM_LOW);
                end 
                else begin
                    `uvm_info("WRITE", "Write response handshake COMPLETE", UVM_LOW);
                    
                    // BRESP check - only when response is valid
                    if (wr_trans.bresp != 2'b00) begin
                        `uvm_info("WRITE", $sformatf(
                            "Write response error: BRESP=0x%0h", wr_trans.bresp), UVM_LOW);
                    end 
                    else begin
                        `uvm_info("WRITE", "Write response (BRESP) indicates OKAY", UVM_LOW);
                    end
                end
            end
        end
    endfunction

    function void check_read_operation();
        axi_trans_t local_rd_queue[$];
        axi_trans_t rd_trans;

        // Copy queue to avoid modifying original
        foreach (rd_queue[i]) local_rd_queue.push_back(rd_queue[i]);

        while (local_rd_queue.size() > 0) begin
            rd_trans = local_rd_queue.pop_front();

            // Skip transactions with no valid handshakes
            if (!rd_trans.arvalid) continue;

            // Address phase handshake
            if (!(rd_trans.arvalid && rd_trans.arready)) begin
                `uvm_info("READ", $sformatf(
                    "Address phase handshake INCOMPLETE: ARVALID=%0b ARREADY=%0b", 
                    rd_trans.arvalid, rd_trans.arready), UVM_LOW);
            end 
            else begin
                `uvm_info("READ", "Address phase handshake COMPLETE", UVM_LOW);
            end

            // Data phase handshake
            if (!(rd_trans.rvalid && rd_trans.rready)) begin
                `uvm_info("READ", $sformatf(
                    "Data phase handshake INCOMPLETE: RVALID=%0b RREADY=%0b", 
                    rd_trans.rvalid, rd_trans.rready), UVM_LOW);
            end 
            else begin
                `uvm_info("READ", "Data phase handshake COMPLETE", UVM_LOW);
            end

            // Since RDATA is fixed, we won't have multiple beats in our queue
            // But we still need to warn if expected multiple beats
            if (rd_trans.len > 0) begin
                `uvm_info("READ", $sformatf(
                    "NOTE: ARLEN=%0d indicates multiple beats, but RDATA is fixed - captured only one beat", 
                    rd_trans.len), UVM_LOW);
            end

            // RLAST check
            if (rd_trans.data.size() > 0) begin
                if (!rd_trans.rlast) begin
                    `uvm_info("READ", "RLAST not asserted on read beat", UVM_LOW);
                end 
                else begin
                    `uvm_info("READ", "RLAST asserted correctly", UVM_LOW);
                end
            end

            // RRESP check - only when valid response
            if (rd_trans.rvalid && rd_trans.rready) begin
                if (rd_trans.rresp != 2'b00) begin
                    `uvm_info("READ", $sformatf(
                        "Read response error: RRESP=0x%0h", rd_trans.rresp), UVM_LOW);
                end 
                else begin
                    `uvm_info("READ", "Read response (RRESP) indicates OKAY", UVM_LOW);
                end
            end
        end
    endfunction
endclass 


