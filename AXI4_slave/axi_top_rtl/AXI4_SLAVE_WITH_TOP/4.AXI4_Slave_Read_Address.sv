module axi4_slave_read_address
#(
//=========================PARAMETERS=============================
      parameter ADDR_WIDTH   = 32,
      parameter ID_WIDTH     = 4,
      parameter BURST_LENGTH = 8
) (
//=========================INPUT SIGNALS===========================
      input  logic                            clk,
      input  logic                            rst,
      input  logic                            arvalid,    
      input  logic   [ADDR_WIDTH - 1 : 0]     araddr,     
      input  logic   [ID_WIDTH   - 1 : 0]     arid,       
      input  logic   [BURST_LENGTH - 1 : 0]   arlen,  
      input  logic   [2:0]                    arsize,    
      input  logic   [1:0]                    arburst,    
        
//=========================OUTPUT SIGNALS==========================
    output logic                            arready,
    output logic                            ar_transfer_occurred, 
    output logic [ADDR_WIDTH-1:0]           latched_araddr,       
    output logic [ID_WIDTH-1:0]             latched_arid,         
    output logic [7:0]                      latched_arlen,        
    output logic [2:0]                      latched_arsize,       
    output logic [1:0]                      latched_arburst
);
//=========================FSM STATES==============================
    typedef enum logic [1:0] {
                                IDLE       = 2'b00,
                                ADDR_STATE = 2'b01
                             } FMS_STATE;
    FMS_STATE present_state,next_state;

    //===================== Internal Signals ========================
    logic arready_next;             
    logic ar_transfer_occurred_comb;
    logic ar_transfer_occurred_ff; 

    //===================== Combinational Logic =======================

    always_comb begin
        next_state             = present_state;
        arready_next              = 1'b0;
        ar_transfer_occurred_comb = 1'b0;

        case (present_state)
            IDLE: begin
                if (arvalid) begin
                arready_next = 1'b1;
                end
                if (arvalid && arready_next) begin
                    ar_transfer_occurred_comb = 1'b1; 
                    next_state = ADDR_STATE;       
                end else begin
                    next_state = IDLE;      
                end
            end

            ADDR_STATE: begin
                 arready_next = 1'b0;
                 next_state = IDLE;
            end

            default: begin 
                next_state = IDLE;
            end
        endcase
    end

    //===================== Sequential Logic ==========================

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            present_state <= IDLE;
        end else begin
            present_state <= next_state;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            arready <= 1'b0; 
            ar_transfer_occurred_ff <= 1'b0;
            latched_araddr  <= '0;
            latched_arid    <= '0;
            latched_arlen   <= '0;
            latched_arsize  <= '0;
            latched_arburst <= '0;
        end else begin
            arready <= arready_next; 
            ar_transfer_occurred_ff <= ar_transfer_occurred_comb; 
            if (ar_transfer_occurred_comb) begin
                latched_araddr  <= araddr;
                latched_arid    <= arid;
                latched_arlen   <= arlen;  
                latched_arsize  <= arsize;
                latched_arburst <= arburst;
            end
        end
    end

    assign ar_transfer_occurred = ar_transfer_occurred_ff;

endmodule 


