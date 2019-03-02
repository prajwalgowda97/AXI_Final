/*class axi_scoreboard extends uvm_scoreboard;
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
endclass */


/*class axi_scoreboard extends uvm_scoreboard;
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
    if(t.AWREADY && t.AWVALID) begin
        trans.addr    = t.AWADDR;
        trans.id      = t.AWID;
        trans.size    = t.AWSIZE;
        trans.burst   = t.AWBURST;
        trans.len     = t.AWLEN;
        trans.awvalid = t.AWVALID;
        trans.awready = t.AWREADY;
        
        `uvm_info("SCOREBOARD", 
            $sformatf("\nWRITE Address: AWADDR=0x%0h\t AWID=0x%0h\t AWLEN=%0h\t AWSIZE=%0d\t AWBURST=%0d\n", 
            t.AWADDR, t.AWID, t.AWLEN, t.AWSIZE, t.AWBURST), UVM_MEDIUM)

        end
 
    // W channel signals
    if(t.WVALID && t.WREADY)   begin   
        trans.wvalid  = t.WVALID;
        trans.wready  = t.WREADY;
        trans.wstrb   = t.WSTRB;
        trans.wlast   = t.WLAST;

        for (int i = 0; i <= t.AWLEN; i++) begin
            if (i < t.WDATA.size()) begin
                trans.data.push_back(t.WDATA[i]);
        `uvm_info("SCOREBOARD", 
            $sformatf("\nWRITE Data:\t WDATA=0x%0p\t WSTRB=0x%0h\t WLAST=%0d\n", 
            t.WDATA, t.WSTRB, t.WLAST), UVM_MEDIUM) 
            end        
         end
        end

        // B channel signals
     if(t.BVALID && t.BREADY) begin
        trans.bid     = t.BID;
        trans.bresp   = t.BRESP;
        trans.bvalid  = t.BVALID;
        trans.bready  = t.BREADY;
                
      `uvm_info("SCOREBOARD", 
            $sformatf("\nWRITE Response:\t BID=0x%0h\t BRESP=0x%0d\n", 
            t.BID, t.BRESP), UVM_MEDIUM)

     end        
        wr_queue.push_back(trans);

    endfunction

    // Read transaction handler
    function void write_rd(axi_seq_item t);
        axi_trans_t trans;

        // AR channel signals
     if(t.ARVALID && t.ARREADY) begin
        trans.addr    = t.ARADDR;
        trans.id      = t.ARID;
        trans.size    = t.ARSIZE;
        trans.burst   = t.ARBURST;
        trans.len     = t.ARLEN;
        trans.arvalid = t.ARVALID;
        trans.arready = t.ARREADY;
        `uvm_info("SCOREBOARD", 
            $sformatf("\nREAD Address: ARADDR=0x%0h\t ARID=0x%0h\t ARLEN=%0d\t ARSIZE=%0d\t ARBURST=%0d\n", 
            t.ARADDR, t.ARID, t.ARLEN, t.ARSIZE, t.ARBURST), UVM_MEDIUM)
        end

        // R channel signals

      if(t.RVALID && t.RREADY) begin
        trans.rvalid  = t.RVALID;
        trans.rready  = t.RREADY;
        trans.rlast   = t.RLAST;
        trans.rresp   = t.RRESP;
        trans.rid     = t.RID;
        
        trans.data.push_back(t.RDATA);

        `uvm_info("SCOREBOARD", 
            $sformatf("\nREAD Data: RDATA=0x%0h\t RRESP=0x%0h\t RLAST=0x%0h\n", 
            t.RDATA, t.RRESP, t.RLAST), UVM_MEDIUM)
        end
        
        rd_queue.push_back(trans);

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
            
            $display("Before Handshake: awvalid=0x%0b, awready=0x%0b",wr_trans.awvalid, wr_trans.awready );
            // ---- Address & ID Check ----
            if(wr_trans.awvalid && wr_trans.awready && rd_trans.arvalid && rd_trans.arready) begin
                $display("After Handshake: awvalid=0x%0b, awready=0x%0b",wr_trans.awvalid, wr_trans.awready );
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
endclass */


class axi_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi_scoreboard)
  
  // Analysis FIFOs for write and read transactions
  uvm_tlm_analysis_fifo #(axi_seq_item) wr_fifo;
  uvm_tlm_analysis_fifo #(axi_seq_item) rd_fifo;
  uvm_tlm_analysis_fifo #(axi_seq_item) handshake_fifo;
  
  // Memory model to store write transactions and compare with read transactions
  protected bit [31:0] mem [int unsigned];
  
  // Counters for transaction statistics
  int write_transactions;
  int read_transactions;
  int write_errors;
  int read_errors;
  int protocol_errors;
  
  // Transaction queues for checking outstanding transactions
  axi_seq_item write_queue[$];
  axi_seq_item read_queue[$];
  
  // Constructor
  function new(string name = "axi_scoreboard", uvm_component parent);
    super.new(name, parent);
    write_transactions = 0;
    read_transactions = 0;
    write_errors = 0;
    read_errors = 0;
    protocol_errors = 0;
  endfunction
  
  // Build phase - create analysis FIFOs
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    wr_fifo = new("wr_fifo", this);
    rd_fifo = new("rd_fifo", this);
    handshake_fifo = new("handshake_fifo", this);
  endfunction
  
  // Run phase - main scoreboard functionality
  task run_phase(uvm_phase phase);
    axi_seq_item wr_item, rd_item, hs_item;
    
    fork
      // Process write transactions
      forever begin
        wr_fifo.get(wr_item);
        process_write_transaction(wr_item);
      end
      
      // Process read transactions
      forever begin
        rd_fifo.get(rd_item);
        process_read_transaction(rd_item);
      end
      
      // Process handshake signals for protocol checking
      forever begin
        handshake_fifo.get(hs_item);
        check_handshake_protocol(hs_item);
      end
    join
  endtask
  
  // Process write transactions
  task process_write_transaction(axi_seq_item item);
    bit [31:0] address;
    bit [31:0] masked_data;
    int burst_len;
    
    // Verify this is a write transaction
    if (!item.wr_rd) begin
      `uvm_error("AXI_SCOREBOARD", "Expected write transaction but received read transaction")
      return;
    end
    
    // Basic write transaction validation
    if (!check_write_transaction(item)) begin
      write_errors++;
      return;
    end
    
    // Calculate effective addresses based on burst type
    address = item.AWADDR;
    burst_len = item.AWLEN + 1;
    
    // Store data in memory model with byte enables (WSTRB)
    for (int i = 0; i < item.WDATA.size(); i++) begin
      // Apply WSTRB (byte enables)
      if (!mem.exists(address)) mem[address] = 0;
      
      masked_data = apply_write_strobe(mem[address], item.WDATA[i], item.WSTRB);
      mem[address] = masked_data;
      
      // Calculate next address based on burst type
      address = get_next_address(address, item.AWSIZE, item.AWBURST, i, burst_len);
    end
    
    write_queue.push_back(item);
    write_transactions++;
    `uvm_info("AXI_SCOREBOARD", $sformatf("Write Transaction #%0d: Addr=0x%0h, ID=%0d, Len=%0d", 
              write_transactions, item.AWADDR, item.AWID, item.AWLEN), UVM_MEDIUM)
  endtask
  
  // Process read transactions
  task process_read_transaction(axi_seq_item item);
    bit [31:0] address;
    bit [31:0] expected_data;
    int burst_len;
    
    // Verify this is a read transaction
    if (item.wr_rd) begin
      `uvm_error("AXI_SCOREBOARD", "Expected read transaction but received write transaction")
      return;
    end
    
    // Basic read transaction validation
    if (!check_read_transaction(item)) begin
      read_errors++;
      return;
    end
    
    // Calculate effective addresses based on burst type
    address = item.ARADDR;
    burst_len = item.ARLEN + 1;

    // Compare read data with expected data from memory model
    for (int i = 0; i <= item.ARLEN; i++) begin
      // Check if the address exists in memory model
      if (!mem.exists(address)) begin
        `uvm_warning("AXI_SCOREBOARD", $sformatf("Read from uninitialized address 0x%0h", address))
        expected_data = 0;
      end else begin
        expected_data = mem[address];
      end
      
      // Compare data
      if (item.RDATA !== expected_data) begin
        `uvm_error("AXI_SCOREBOARD", $sformatf("Read data mismatch at address 0x%0h: Expected=0x%0h, Actual=0x%0h",
                  address, expected_data, item.RDATA))
        read_errors++;
      end
      
      // Calculate next address based on burst type
      address = get_next_address(address, item.ARSIZE, item.ARBURST, i, burst_len);
    end
    
    read_queue.push_back(item);
    read_transactions++;
    `uvm_info("AXI_SCOREBOARD", $sformatf("Read Transaction #%0d: Addr=0x%0h, ID=%0d, Len=%0d", 
              read_transactions, item.ARADDR, item.ARID, item.ARLEN), UVM_MEDIUM)
  endtask
  
  // Check handshake protocol rules
  task check_handshake_protocol(axi_seq_item item);
    if (item.handshake) begin
      if (item.wr_rd) begin
        // Write address handshake check
        if (item.AWVALID && item.AWREADY) begin
          `uvm_info("AXI_PROTOCOL", $sformatf("Valid AW handshake: AWADDR=0x%0h, AWID=%0d", 
                    item.AWADDR, item.AWID), UVM_HIGH)
        end else if (item.AWVALID && !item.AWREADY) begin
          `uvm_info("AXI_PROTOCOL", "AWVALID asserted but waiting for AWREADY", UVM_HIGH)
        end
      end else begin
        // Read address handshake check
        if (item.ARVALID && item.ARREADY) begin
          `uvm_info("AXI_PROTOCOL", $sformatf("Valid AR handshake: ARADDR=0x%0h, ARID=%0d", 
                    item.ARADDR, item.ARID), UVM_HIGH)
        end else if (item.ARVALID && !item.ARREADY) begin
          `uvm_info("AXI_PROTOCOL", "ARVALID asserted but waiting for ARREADY", UVM_HIGH)
        end
      end
    end
  endtask
  
  // Apply write strobe (byte enable) to data
  function bit [31:0] apply_write_strobe(bit [31:0] old_data, bit [31:0] new_data, bit [3:0] strb);
    bit [31:0] result = old_data;
    
    // Apply byte enables (each bit in WSTRB corresponds to a byte)
    for (int i = 0; i < 4; i++) begin
      if (strb[i]) begin
        result[8*i +: 8] = new_data[8*i +: 8];
      end
    end
    
    return result;
  endfunction
  
  // Calculate next address based on burst type
  function bit [31:0] get_next_address(bit [31:0] addr, bit [2:0] size, bit [1:0] burst_type, int beat, int burst_len);
    bit [31:0] next_addr = addr;
    int bytes_per_transfer = (1 << size);
    
    case (burst_type)
      // FIXED burst: address doesn't change
      2'b00: begin
        next_addr = addr;
      end
      
      // INCR burst: address increments by transfer size
      2'b01: begin
        next_addr = addr + bytes_per_transfer;
      end
      
      // WRAP burst: address wraps at boundary
      2'b10: begin
        int wrap_boundary = 2 * burst_len * bytes_per_transfer;
        bit [31:0] wrap_mask = ~(wrap_boundary - 1);
        bit [31:0] next_incr_addr = addr + bytes_per_transfer;
        
        // If next address crosses wrap boundary, wrap around
        if ((next_incr_addr & wrap_mask) != (addr & wrap_mask)) begin
          next_addr = (addr & wrap_mask) | ((next_incr_addr) & ~wrap_mask);
        end else begin
          next_addr = next_incr_addr;
        end
      end
      
      // Reserved burst type
      default: begin
        `uvm_error("AXI_SCOREBOARD", $sformatf("Invalid burst type: %0d", burst_type))
        next_addr = addr;
      end
    endcase
    
    return next_addr;
  endfunction
  
  // Check write transaction validity
  function bit check_write_transaction(axi_seq_item item);
    bit is_valid = 1;
    
    // Check AWVALID and AWREADY handshake
    if (!item.AWVALID) begin
      `uvm_error("AXI_PROTOCOL", "Write transaction received but AWVALID not asserted")
      is_valid = 0;
    end
    
    // Check WLAST is asserted on the last data beat
    if (!item.WLAST) begin
      `uvm_error("AXI_PROTOCOL", "WLAST not asserted on the last data beat")
      is_valid = 0;
    end
    
    // Validate AWSIZE against AXI4 spec (0-7 are valid, but practical limit is often 0-3)
    if (item.AWSIZE > 3'b111) begin
      `uvm_error("AXI_PROTOCOL", $sformatf("Invalid AWSIZE value: %0d", item.AWSIZE))
      is_valid = 0;
    end
    
    // Validate AWBURST against AXI4 spec (0, 1, 2 are valid)
    if (item.AWBURST > 2'b10) begin
      `uvm_error("AXI_PROTOCOL", $sformatf("Invalid AWBURST value: %0d", item.AWBURST))
      is_valid = 0;
    end
    
    // Check data array size matches burst length
    if (item.WDATA.size() != (item.AWLEN + 1)) begin
      `uvm_error("AXI_PROTOCOL", $sformatf("WDATA size (%0d) doesn't match AWLEN+1 (%0d)", 
                item.WDATA.size(), item.AWLEN + 1))
      is_valid = 0;
    end
    
    return is_valid;
  endfunction
  
  // Check read transaction validity
  function bit check_read_transaction(axi_seq_item item);
    bit is_valid = 1;
    
    // Check ARVALID and ARREADY handshake
    if (!item.ARVALID) begin
      `uvm_error("AXI_PROTOCOL", "Read transaction received but ARVALID not asserted")
      is_valid = 0;
    end
    
    // Validate ARSIZE against AXI4 spec
    if (item.ARSIZE > 3'b111) begin
      `uvm_error("AXI_PROTOCOL", $sformatf("Invalid ARSIZE value: %0d", item.ARSIZE))
      is_valid = 0;
    end
    
    // Validate ARBURST against AXI4 spec
    if (item.ARBURST > 2'b10) begin
      `uvm_error("AXI_PROTOCOL", $sformatf("Invalid ARBURST value: %0d", item.ARBURST))
      is_valid = 0;
    end
    
    return is_valid;
  endfunction
  
  // Check for ID ordering rule violations
  function void check_id_ordering();
    // Check for read responses with same ID coming out of order
    for (int i = 0; i < read_queue.size(); i++) begin
      for (int j = i + 1; j < read_queue.size(); j++) begin
        if (read_queue[i].ARID == read_queue[j].ARID) begin
          // Check that responses with the same ID are ordered correctly
          if (read_queue[i].RID != read_queue[j].RID) begin
            `uvm_error("AXI_PROTOCOL", $sformatf("Read responses with ID=%0d out of order", read_queue[i].ARID))
            protocol_errors++;
          end
        end
      end
    end
    
    // Similar check for write responses
    for (int i = 0; i < write_queue.size(); i++) begin
      for (int j = i + 1; j < write_queue.size(); j++) begin
        if (write_queue[i].AWID == write_queue[j].AWID) begin
          if (write_queue[i].BID != write_queue[j].BID) begin
            `uvm_error("AXI_PROTOCOL", $sformatf("Write responses with ID=%0d out of order", write_queue[i].AWID))
            protocol_errors++;
          end
        end
      end
    end
  endfunction
  
  // Report phase - print statistics
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    
    // Perform final checks
    check_id_ordering();
    
    // Report statistics
    `uvm_info("AXI_SCOREBOARD", 
              $sformatf("\n=== AXI Scoreboard Statistics ===\n" +
                       "  Write Transactions: %0d\n" +
                       "  Read Transactions: %0d\n" +
                       "  Write Errors: %0d\n" +
                       "  Read Errors: %0d\n" +
                       "  Protocol Errors: %0d\n",
                       write_transactions, read_transactions, 
                       write_errors, read_errors, protocol_errors), UVM_LOW)
                       
    // Final status
    if (write_errors == 0 && read_errors == 0 && protocol_errors == 0) begin
      `uvm_info("AXI_SCOREBOARD", "TEST PASSED: No errors detected", UVM_LOW)
    end else begin
      `uvm_error("AXI_SCOREBOARD", "TEST FAILED: Errors detected")
    end
  endfunction

endclass

// Additional AXI4 Protocol Checker class for comprehensive protocol checks
class axi4_protocol_checker extends uvm_subscriber #(axi_seq_item);
  `uvm_component_utils(axi4_protocol_checker)
  
  // Transaction tracking for protocol rules
  protected bit [7:0] outstanding_writes[bit [3:0]]; // Track outstanding writes by ID
  protected bit [7:0] outstanding_reads[bit [3:0]];  // Track outstanding reads by ID
  
  // Protocol violation counters
  int handshake_violations;
  int exclusivity_violations;
  int order_violations;
  int burst_violations;
  
  // Last seen sequence numbers for IDs
  protected int write_seq[bit [3:0]];
  protected int read_seq[bit [3:0]];
  
  // Constructor
  function new(string name = "axi4_protocol_checker", uvm_component parent);
    super.new(name, parent);
    handshake_violations = 0;
    exclusivity_violations = 0;
    order_violations = 0;
    burst_violations = 0;
  endfunction
  
  // Implement analysis_port write method to receive transactions
  function void write(axi_seq_item t);
    if (t.handshake) begin
      check_handshake_protocol(t);
    end else if (t.wr_rd) begin
      check_write_protocol(t);
    end else begin
      check_read_protocol(t);
    end
  endfunction
  
  // Check handshake protocol rules
  function void check_handshake_protocol(axi_seq_item t);
    // Rules for valid-ready handshakes
    if (t.wr_rd) begin
      // Write address channel checks
      if (t.AWVALID) begin
        if (!t.AWREADY) begin
          // Valid without ready is fine, waiting for handshake
        end else begin
          // Valid handshake, increment outstanding writes
          if (!outstanding_writes.exists(t.AWID)) outstanding_writes[t.AWID] = 0;
          outstanding_writes[t.AWID]++;
        end
      end else if (t.AWREADY) begin
        // Ready without valid is allowed in AXI4
      end
    end else begin
      // Read address channel checks
      if (t.ARVALID) begin
        if (!t.ARREADY) begin
          // Valid without ready is fine, waiting for handshake
        end else begin
          // Valid handshake, increment outstanding reads
          if (!outstanding_reads.exists(t.ARID)) outstanding_reads[t.ARID] = 0;
          outstanding_reads[t.ARID]++;
        end
      end else if (t.ARREADY) begin
        // Ready without valid is allowed in AXI4
      end
    end
  endfunction
  
  // Check write protocol
  function void check_write_protocol(axi_seq_item t);
    // Check for write response (B channel)
    if (t.BVALID && t.BREADY) begin
      // Verify we have outstanding write for this ID
      if (!outstanding_writes.exists(t.BID) || outstanding_writes[t.BID] == 0) begin
        `uvm_error("AXI_PROTOCOL", $sformatf("Write response received for ID=%0d but no outstanding write", t.BID))
        exclusivity_violations++;
      end else begin
        // Decrement outstanding writes
        outstanding_writes[t.BID]--;
      end
      
      // Check write response ordering (AXI4 allows out-of-order responses between IDs, but not within an ID)
      if (!write_seq.exists(t.BID)) write_seq[t.BID] = 0;
      write_seq[t.BID]++;
    end
    
    // Check WLAST on the last beat of a burst
    if (t.WVALID && t.WREADY) begin
      if (t.WLAST && t.WDATA.size() != (t.AWLEN + 1)) begin
        `uvm_error("AXI_PROTOCOL", "WLAST asserted but not on the expected last beat of burst")
        burst_violations++;
      end
    end
    
    // Check write burst addressing rules
    if (t.AWBURST == 2'b10) begin // WRAP burst
      if (t.AWLEN != 1 && t.AWLEN != 3 && t.AWLEN != 7 && t.AWLEN != 15) begin
        `uvm_error("AXI_PROTOCOL", $sformatf("WRAP burst with invalid length: %0d", t.AWLEN))
        burst_violations++;
      end
      
      // Address alignment check for wrap bursts
      if ((t.AWADDR & ((t.AWLEN * (1 << t.AWSIZE)) - 1)) != 0) begin
        `uvm_error("AXI_PROTOCOL", "WRAP burst with misaligned address")
        burst_violations++;
      end
    end
  endfunction
  
  // Check read protocol
  function void check_read_protocol(axi_seq_item t);
    // Check for read data (R channel)
    if (t.RVALID && t.RREADY) begin
      // Check we have outstanding read for this ID
      if (!outstanding_reads.exists(t.RID) || outstanding_reads[t.RID] == 0) begin
        `uvm_error("AXI_PROTOCOL", $sformatf("Read data received for ID=%0d but no outstanding read", t.RID))
        exclusivity_violations++;
      end
      
      // Check for RLAST
      if (t.RLAST) begin
        // Decrement outstanding reads
        if (outstanding_reads.exists(t.RID)) begin
          outstanding_reads[t.RID]--;
        end
      end
      
      // Check read response ordering
      if (!read_seq.exists(t.RID)) read_seq[t.RID] = 0;
      read_seq[t.RID]++;
    end
    
    // Check read burst addressing rules
    if (t.ARBURST == 2'b10) begin // WRAP burst
      if (t.ARLEN != 1 && t.ARLEN != 3 && t.ARLEN != 7 && t.ARLEN != 15) begin
        `uvm_error("AXI_PROTOCOL", $sformatf("WRAP burst with invalid length: %0d", t.ARLEN))
        burst_violations++;
      end
      
      // Address alignment check for wrap bursts
      if ((t.ARADDR & ((t.ARLEN * (1 << t.ARSIZE)) - 1)) != 0) begin
        `uvm_error("AXI_PROTOCOL", "WRAP burst with misaligned address")
        burst_violations++;
      end
    end
  endfunction
  
  // Report phase - print final statistics
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    
    // Check for outstanding transactions at end of test
    foreach (outstanding_writes[id]) begin
      if (outstanding_writes[id] > 0) begin
        `uvm_warning("AXI_PROTOCOL", $sformatf("Test ended with %0d outstanding write(s) for ID=%0d", 
                    outstanding_writes[id], id))
      end
    end
    
    foreach (outstanding_reads[id]) begin
      if (outstanding_reads[id] > 0) begin
        `uvm_warning("AXI_PROTOCOL", $sformatf("Test ended with %0d outstanding read(s) for ID=%0d", 
                    outstanding_reads[id], id))
      end
    end
    
    // Report statistics
    `uvm_info("AXI_PROTOCOL_CHECKER", 
              $sformatf("\n=== AXI4 Protocol Violations ===\n" +
                       "  Handshake Violations: %0d\n" +
                       "  Exclusivity Violations: %0d\n" +
                       "  Order Violations: %0d\n" +
                       "  Burst Violations: %0d\n",
                       handshake_violations, exclusivity_violations, 
                       order_violations, burst_violations), UVM_LOW)
  endfunction
endclass
