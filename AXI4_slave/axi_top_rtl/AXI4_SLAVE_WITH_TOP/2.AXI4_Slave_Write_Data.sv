module axi4_slave_data_channel 
#(
    parameter DATA_WIDTH   = 32,
    parameter ADDR_WIDTH   = 32,
    parameter ID_WIDTH     = 4,
    parameter BURST_LENGTH = 8
)(
    //========================INPUT SIGNALS===========================
    input  logic                        clk,
    input  logic                        rst,  
 
     input  logic  [ADDR_WIDTH-1 : 0]   stored_awaddr,
     input  logic  [ID_WIDTH-1 : 0]     stored_awid  ,
     input  logic  [7:0]                stored_awlen ,
     input  logic  [2:0]                stored_awsize   ,
     input  logic  [1:0]                stored_awburst   ,

    input  logic                        awvalid,
    input  logic                        awready,

    input  logic [BURST_LENGTH-1:0]     burst_length,
    input  logic                        wvalid,
    input  logic [DATA_WIDTH-1:0]       wdata,
    input  logic                        wlast,
    input  logic [DATA_WIDTH/8-1:0]     wstrb,  
    output logic                        mem_wr_en,         
    output logic [ADDR_WIDTH-1:0]       mem_addr,        
    output logic [DATA_WIDTH-1:0]       mem_wr_data,       
    output logic [DATA_WIDTH/8-1:0]     mem_byte_en,
    //=====================OUTPUT SIGNALS================================

    output logic                        wready,
    output logic                        b_transfer_done,
    output logic [ID_WIDTH-1:0]         b_bid,
    output logic [1:0]                  b_bresp
);

//======================FSM STATES===================================
typedef enum logic [1:0] {
    W_IDLE = 2'b00,
    W_DATA = 2'b01
} FMS_STATE;
FMS_STATE present_state, next_state;

//=====================INTERNAL REGISTERS=============================

    logic [7:0]            beats_remaining;  
    logic [ADDR_WIDTH-1:0] current_addr;     
    logic [ID_WIDTH-1:0]   active_bid;       
    logic [2:0]            active_awsize;    
    logic [1:0]            active_awburst;   
    logic                  wready_reg;       
    logic                  wready_next;      
    logic                  burst_active;     
    logic [1:0]            b_bresp_reg;      
    logic                  last_beat_transfer;


    logic [ADDR_WIDTH-1:0] wrap_boundary;
    logic [ADDR_WIDTH-1:0] upper_addr_limit;
    logic [$clog2(DATA_WIDTH/8):0] num_bytes;

assign num_bytes = 1 << active_awsize;
assign last_beat_transfer = (beats_remaining == 1) && burst_active;
assign b_bid           = active_bid;  
assign b_bresp         = b_bresp_reg; 

    assign mem_addr        = current_addr; 
    assign mem_wr_data     = wdata;       

//======================RESET LOGIC===================================
always_ff @(posedge clk or negedge rst) begin
    if (!rst)
        present_state <= W_IDLE;
    else 
        present_state <= next_state;
end

//===========================STATE LOGIC=============================
  always_comb begin
        next_state    = present_state;
        wready_next     = 1'b0;           
        mem_wr_en       = 1'b0;          
        mem_byte_en     = '0;            
        b_transfer_done = 1'b0;          

        case (present_state)
            W_IDLE: begin
                wready_next = 1'b0;
                if (awvalid && awready) begin
                    next_state = W_DATA;
                end else begin
                    next_state = W_IDLE;
                end
            end

            W_DATA: begin
                wready_next = 1'b1;

                if (wvalid && wready_next) begin
                    mem_wr_en   = 1'b1;    
                    mem_byte_en = wstrb; 
                    if (last_beat_transfer) begin
                        b_transfer_done = 1'b1; 
                        next_state = W_IDLE; 
                        wready_next = 1'b0; 
                    end else begin
                        next_state = W_DATA;
                    end
                end else begin
                    next_state = W_DATA;
                end
            end

            default: begin 
                next_state = W_IDLE;
            end
        endcase
    end 


always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
              active_bid      <= '0;
            end else begin
            if(wready)
                      active_bid      <= stored_awid;
           end
           end

    // Burst Parameter Latching, Counter, Address Calculation, Status
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            burst_active    <= 1'b0;
            beats_remaining <= '0;
            active_awsize   <= '0;
            active_awburst  <= '0;
            current_addr    <= '0;
            b_bresp_reg     <= 2'b00;
            wrap_boundary   <= '0;
            upper_addr_limit<= '0;
        end else begin

            if (awvalid && awready) begin
                burst_active    <= 1'b1;
                beats_remaining <= stored_awlen + 1; 
                current_addr    <= stored_awaddr;  
                active_awsize   <= stored_awsize;
                active_awburst  <= stored_awburst;
                b_bresp_reg     <= 2'b00; 

                if (stored_awburst == 2'b10) begin 
                    logic [$clog2(DATA_WIDTH/8):0] size_in_bytes; 
                    logic [ADDR_WIDTH:0]           burst_len_bytes;
                    size_in_bytes = 1 << stored_awsize;
                    burst_len_bytes = size_in_bytes * (stored_awlen + 1);
                    if (burst_len_bytes > 0) begin
                         wrap_boundary = (stored_awaddr / burst_len_bytes) * burst_len_bytes;
                    end else begin
                         wrap_boundary = stored_awaddr; 
                    end
                    upper_addr_limit = wrap_boundary + burst_len_bytes - size_in_bytes;
                end
            end


            if (present_state == W_DATA && wvalid && wready_reg) begin
                if (last_beat_transfer && !wlast) begin
                    b_bresp_reg <= 2'b11; 
                end else if (!last_beat_transfer && wlast) begin
                     b_bresp_reg <= 2'b11; 
                end
                if (beats_remaining > 0) begin
                    beats_remaining <= beats_remaining - 1;
                end
                 if (!last_beat_transfer) begin
                    case (active_awburst)
                        2'b00: current_addr <= current_addr; 
                        2'b01: current_addr <= current_addr + num_bytes; 
                        2'b10: begin // WRAP
                             if (current_addr == upper_addr_limit) begin
                                 current_addr <= wrap_boundary;
                             end else begin
                                 current_addr <= current_addr + num_bytes;
                             end
                        end
                        default: begin 
                            current_addr <= current_addr;
                        end
                    endcase
                end
            end           
            if (burst_active && next_state == W_IDLE && present_state == W_DATA) begin
                 burst_active <= 1'b0;
            end
        end 
    end 
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            wready_reg <= 1'b0;
        end else 
        if (wvalid)
            wready_reg <= 1'b1;
        else begin
            wready_reg <= wready_next;         
            end
    end
    assign wready = wready_reg; 

endmodule
