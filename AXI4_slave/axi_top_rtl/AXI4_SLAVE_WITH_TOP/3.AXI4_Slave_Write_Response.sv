module axi4_slave_write_response 
#(
//=========================PARAMETERS=============================
         parameter ID_WIDTH = 4
)(
//=========================INPUT SIGNALS===========================
         input      logic                           clk,
         input      logic                           rst,
         input      logic                           bready,  
         input      logic                           wready_in,
         
//=========================OUTPUT SIGNALS==========================
         output     logic    [ID_WIDTH - 1 : 0 ]    bid,     
         output     logic    [1:0]                  bresp,   
         output     logic                           bvalid,  
         input      logic                           b_transfer_done,
         input      logic    [ID_WIDTH-1 : 0]       b_bid_in,       
         input      logic    [1:0]                  b_status_in
);

//=========================FSM STATES==============================

         typedef enum logic [1:0] {
                                    IDLE            = 2'b00,
                                    READ_RESPONSE   = 2'b01
                                  } FMS_STATE;
         FMS_STATE present_state,next_state;

//===========================INTERNAL REGISTERS======================
 
    logic [ID_WIDTH-1:0] stored_bid;   
    logic [1:0]          stored_bresp; 
    logic                bvalid_reg;   

//==========================RESET LOGIC==============================
         always_ff @(posedge clk or negedge rst)
           begin
             if(!rst)
                 begin
                   present_state <= IDLE;
                 end
             else
                 begin
                       present_state <= next_state;
                 end
            end

//========================STATE LOGIC===============================
         always_comb begin
              next_state = present_state;
             case(present_state)
                IDLE : begin
                          if(b_transfer_done)
                              begin
                                next_state = READ_RESPONSE;
                              end
                              end

                READ_RESPONSE : begin
                                  if(bvalid_reg && bready)
                                     begin
                                            next_state = IDLE;  
                                     end
                                  end
                                  default: next_state = IDLE;             
                     endcase
           end
    assign bresp = stored_bresp;         
    assign bid = wready_in ? b_bid_in : 1'b0;

always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            stored_bid   <= '0;
            end
            else if(wready_in)
                stored_bid <= b_bid_in;
                end
always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            stored_bresp <= 2'b00; 
            bvalid_reg   <= 1'b0;  
        end else begin
            if (b_transfer_done) begin 
                stored_bresp <= b_status_in;
                bvalid_reg <=1;
            end

            if (wready_in) begin
                 bvalid_reg <= 1'b1;
            end else if (next_state == IDLE && present_state == READ_RESPONSE) begin
                 bvalid_reg <= 1'b0;
            end
        end
    end

    assign bvalid = bready? 1:0;

endmodule
