module axi4_slave_read_data 
#(
//=========================PARAMETERS=============================
      parameter DATA_WIDTH = 32,
      parameter ADDR_WIDTH = 32,
      parameter ID_WIDTH   = 4,
      parameter BURST_LENGTH = 8
) (
//=========================INPUT SIGNALS===========================
      input      logic                              clk,
      input      logic                              rst,

      input logic [ADDR_WIDTH-1:0]                  latched_araddr,       
      input logic [ID_WIDTH-1:0]                    latched_arid,         
      input logic [7:0]                             latched_arlen,        
      input logic [2:0]                             latched_arsize,      
      input logic [1:0]                             latched_arburst,
    
      input       logic                              arvalid,
      input       logic                              arready,
      output      logic                              rvalid,      
      output      logic    [DATA_WIDTH - 1 : 0]      rdata,       
      output      logic    [ID_WIDTH  - 1 : 0]       rid,         
      output      logic                              rlast,       
      output      logic    [1:0]                     rresp,

//=========================OUTPUT SIGNALS==========================
    input  logic                   rready,
    output logic                   mem_rd_en,          
    output logic [ADDR_WIDTH-1:0]  mem_addr,           
    input  logic [DATA_WIDTH-1:0]  mem_rd_data 
       
);
//=========================FSM STATES==============================
      typedef enum logic [1:0] {
                                  R_IDLE        = 2'b00,
                                  R_ACTIVE      = 2'b01,
                                  R_PAUSE       = 2'b10
                               } FMS_STATE;
      FMS_STATE state;

    //===================== INTERNAL REGISTERS / LOGIC =====================
    logic [7:0]            beat_count;  
    logic [ADDR_WIDTH-1:0] current_addr;     
    logic [ID_WIDTH-1:0]   stored_arid;       
    logic [2:0]            active_arsize;    
    logic [1:0]            active_arburst;   
    logic [7:0]            active_arlen;
    logic                  transaction_active;
    logic [1:0]            active_rresp;
    
    logic [ADDR_WIDTH-1:0] wrap_boundary;
    logic [ADDR_WIDTH-1:0] upper_wrap_limit;
    logic [$clog2(DATA_WIDTH/8):0] transfer_size_bytes;
    
    // Dynamic signal assignments
    assign rresp = active_rresp;
    assign rlast = transaction_active && (beat_count == active_arlen);
    
    // Conditional assignments based on control signals
    assign rid = rvalid ? stored_arid : '0;
    
    // Assign rdata based on current state to avoid delay
    assign rdata = (state == R_IDLE) ? '0 : mem_rd_data;
    
    // Memory read enable when master is ready to accept data
    assign mem_rd_en = rready && rvalid;
    
    // Main state machine
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= R_IDLE;
            rvalid <= 1'b0;
            transaction_active <= 1'b0;
            beat_count <= '0;
            current_addr <= '0;
            stored_arid <= '0;
            active_arsize <= '0;
            active_arburst <= '0;
            active_arlen <= '0;
            active_rresp <= 2'b00;
            mem_addr <= '0;
            wrap_boundary <= '0;
            upper_wrap_limit <= '0;
            transfer_size_bytes <= '0;
        end else begin
            case (state)
                R_IDLE: begin
                    if (arvalid && arready) begin
                        // Capture transaction parameters
                        transaction_active <= 1'b1;
                        beat_count <= '0;
                        current_addr <= latched_araddr;
                        stored_arid <= latched_arid;
                        active_arsize <= latched_arsize;
                        active_arburst <= latched_arburst;
                        active_arlen <= latched_arlen;
                        active_rresp <= 2'b00;
                        transfer_size_bytes <= (1 << latched_arsize);
                        
                        // Calculate wrap boundary for WRAP bursts
                        if (latched_arburst == 2'b10) begin
                            logic [ADDR_WIDTH:0] burst_len_bytes;
                            burst_len_bytes = (1 << latched_arsize) * (latched_arlen + 1);
                            
                            if (burst_len_bytes > 0) begin
                                wrap_boundary <= (latched_araddr / burst_len_bytes) * burst_len_bytes;
                                upper_wrap_limit <= (latched_araddr / burst_len_bytes) * burst_len_bytes + 
                                                  burst_len_bytes - (1 << latched_arsize);
                            end else begin
                                wrap_boundary <= latched_araddr;
                                upper_wrap_limit <= latched_araddr;
                            end
                        end
                        
                        // Setup memory address immediately
                        mem_addr <= latched_araddr;
                        
                        // Move to active state and set valid immediately
                        state <= R_ACTIVE;
                        rvalid <= 1'b1;
                    end else begin
                        rvalid <= 1'b0;
                    end
                end
                
                R_ACTIVE: begin
                    if (rready && rvalid) begin
                        // Data accepted by master
                        if (beat_count < active_arlen) begin
                            // More beats in burst
                            beat_count <= beat_count + 1;
                            
                            // Update address based on burst type
                            case (active_arburst)
                                2'b00: begin // FIXED burst
                                    // Address remains the same
                                end
                                2'b01: begin // INCR burst
                                    current_addr <= current_addr + transfer_size_bytes;
                                end
                                2'b10: begin // WRAP burst
                                    if (current_addr == upper_wrap_limit) begin
                                        current_addr <= wrap_boundary;
                                    end else begin
                                        current_addr <= current_addr + transfer_size_bytes;
                                    end
                                end
                                default: begin
                                    // Reserved, treat as INCR
                                    current_addr <= current_addr + transfer_size_bytes;
                                end
                            endcase
                            
                            // Update memory address immediately
                            mem_addr <= (active_arburst == 2'b00) ? current_addr : 
                                       ((active_arburst == 2'b10 && current_addr == upper_wrap_limit) ? 
                                         wrap_boundary : current_addr + transfer_size_bytes);
                            
                            // Keep rvalid high as we're still transferring
                            rvalid <= 1'b1;
                        end else begin
                            // Last beat complete, end transaction
                            transaction_active <= 1'b0;
                            rvalid <= 1'b0;
                            state <= R_IDLE;
                        end
                    end else if (!rready && rvalid) begin
                        // Master not ready, pause
                        state <= R_PAUSE;
                    end
                end
                
                R_PAUSE: begin
                    // Keep current values stable during pause
                    
                    if (rready) begin
                        // Master ready again, resume transfer
                        if (beat_count < active_arlen) begin
                            // More beats in burst
                            beat_count <= beat_count + 1;
                            
                            // Calculate next address based on burst type
                            case (active_arburst)
                                2'b00: begin // FIXED burst
                                    // Address remains the same
                                end
                                2'b01: begin // INCR burst
                                    current_addr <= current_addr + transfer_size_bytes;
                                end
                                2'b10: begin // WRAP burst
                                    if (current_addr == upper_wrap_limit) begin
                                        current_addr <= wrap_boundary;
                                    end else begin
                                        current_addr <= current_addr + transfer_size_bytes;
                                    end
                                end
                                default: begin
                                    // Reserved, treat as INCR
                                    current_addr <= current_addr + transfer_size_bytes;
                                end
                            endcase
                            
                            // Update memory address for next read
                            mem_addr <= (active_arburst == 2'b00) ? current_addr : 
                                       ((active_arburst == 2'b10 && current_addr == upper_wrap_limit) ? 
                                         wrap_boundary : current_addr + transfer_size_bytes);
                            
                            state <= R_ACTIVE;
                        end else begin
                            // Last beat complete
                            transaction_active <= 1'b0;
                            rvalid <= 1'b0;
                            state <= R_IDLE;
                        end
                    end
                    // Stay in PAUSE if rready still low
                end
                
                default: begin
                    state <= R_IDLE;
                end
            endcase
        end
    end

endmodule



