module axi4_slave_write_address
#(
//=========================PARAMETERS=============================
      parameter ADDR_WIDTH   = 32   ,
      parameter DATA_WIDTH   = 32   ,
      parameter ID_WIDTH     = 4    ,
      parameter BURST_LENGTH = 8
) (
//=========================INPUT SIGNALS===========================
      input logic                            clk        ,   
      input logic                            rst        ,   
      input logic                            awvalid    ,   
      input logic   [ADDR_WIDTH - 1 : 0]     awaddr     ,  
      input logic   [ID_WIDTH   - 1 : 0]     awid       ,   
      input logic   [BURST_LENGTH - 1 : 0]   awlen      ,  
      input logic   [2:0]                    awsize     ,   
      input logic   [1:0]                    awburst    ,   

//=========================OUTPUT SIGNALS==========================
      output logic                           awready   ,   
      output logic  [ADDR_WIDTH-1:0]         stored_awaddr,
      output logic  [ID_WIDTH-1:0]           stored_awid  ,
      output logic  [7:0]                    stored_awlen ,
      output logic  [2:0]                    stored_awsize   ,
      output logic  [1:0]                    stored_awburst
);
//=========================FSM STATES==============================
    typedef enum logic [1:0] {
                                AW_IDLE = 2'b00,
                                AW_ADDR = 2'b01
                             } FSM_STATE;
    FSM_STATE present_state,next_state;

//===========================INTERNAL REGISTERS=======================
    logic                           SLV_AWREADY         ;
    logic [ADDR_WIDTH-1:0]          SLV_BURST_ADDR      ; 
    logic [BURST_LENGTH-1:0]        SLV_BURST_COUNTER   ;

//==========================RESET LOGIC=================================
    always_ff @(posedge clk or negedge rst)
      begin
        if(!rst)
              present_state <= AW_IDLE;
            else
              present_state <= next_state;
      end

//========================STATE LOGIC===============================
    always @(*)
      begin
        next_state = present_state;
        case(present_state)
           AW_IDLE : begin
              if(awvalid)
                     next_state = AW_ADDR;
               else
                     next_state = AW_IDLE;
                  end

          AW_ADDR : begin
                   if(!awvalid)
                               next_state = AW_IDLE;
                   else
                                next_state = AW_ADDR;
                end
            
       endcase
    end
//======================OUTPUT LOGIC=================================
    always_ff @(posedge clk or negedge rst)
       begin
        if(!rst)
           begin
                SLV_AWREADY        <= 1'b0;
                SLV_BURST_ADDR     <= 32'h0;
                SLV_BURST_COUNTER  <= {BURST_LENGTH{1'b0}};
                stored_awid        <= {ID_WIDTH{1'b0}};
                stored_awaddr      <= {ADDR_WIDTH{1'b0}};
                stored_awlen       <= 8'b0;
                stored_awsize      <= 3'b0;
                stored_awburst     <= 2'b0;
           end
        else

          begin
        case(present_state)
                AW_IDLE:
                begin
                    if (awvalid)
                    begin
                        SLV_AWREADY     <= 1'b1;
                        SLV_BURST_ADDR  <= awaddr;
                        SLV_BURST_COUNTER <= awlen;
                        stored_awid       <= awid;
                        stored_awaddr      <= awaddr;
                        stored_awlen       <= awlen;
                        stored_awsize      <= awsize;
                        stored_awburst     <= awburst;

                    end
                    else
                    begin
                        SLV_AWREADY <= 1'b0;
                    end
                end
                
                AW_ADDR:
                begin
                    SLV_AWREADY <= 1'b0;
                end
            endcase
        end
    end
assign awready = SLV_AWREADY;

endmodule 
