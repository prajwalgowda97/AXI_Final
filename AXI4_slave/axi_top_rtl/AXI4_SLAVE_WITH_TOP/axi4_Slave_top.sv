module axi4_slave_top 
#(
//=========================PARAMETERS=============================
    parameter ADDR_WIDTH     = 32   ,
    parameter DATA_WIDTH     = 32   ,
    parameter ID_WIDTH       = 4    ,
    parameter BURST_LENGTH   = 8    ,
    parameter LEN_WIDTH      = 8    ,
    parameter SIZE_WIDTH     = 3    ,
    parameter MEM_ADDR_BITS = 12
   )(
//========================Global Signals==========================
     input   logic                            CLK       ,    //Clock Signal
     input   logic                            RST       ,    //Reset Signal


//====================Write Address Channel Signals===============
     input   logic                            AWVALID   ,    //master indicating address is valid
     input   logic   [ADDR_WIDTH - 1 : 0]     AWADDR    ,    //write address
     input   logic   [ID_WIDTH   - 1 : 0]     AWID      ,    //write address: ID
     input   logic   [BURST_LENGTH - 1 : 0]   AWLEN     ,    //burst length
     input   logic   [2:0]                    AWSIZE    ,    //burst size
     input   logic   [1:0]                    AWBURST   ,    //burst type
     output  logic                            AWREADY   ,    //slave ready to accept write address

//====================Write Data Channel Signals==================
     output  logic                            WREADY    ,    //write ready
     input   logic                            WVALID    ,    //write valid
     input   logic   [DATA_WIDTH - 1 : 0]     WDATA     ,    //write data
     input   logic                            WLAST     ,    //write last beat
     input   logic   [ID_WIDTH - 1 : 0]       WSTRB     ,    //write strobe
//     input   logic   [ID_WIDTH - 1 : 0]       WID       ,    //Write Data ID is not required for AXI4

//====================Write Response Channel Signals===============
     output  logic                            BVALID    ,    //slave indicates response is valid
     output  logic   [ID_WIDTH - 1 : 0 ]      BID       ,    //response id
     output  logic   [1:0]                    BRESP     ,    //write response
     input   logic                            BREADY    ,    //master ready to accept the response
//=====================Read Address Channel Signals===============
     output  logic                            ARREADY   ,    //slave ready to accept write address
     input   logic                            ARVALID   ,    //master indicating address is valid
     input   logic   [ADDR_WIDTH - 1 : 0]     ARADDR    ,    //read address
     input   logic   [ID_WIDTH   - 1 : 0]     ARID      ,    //transaction ID
     input   logic   [LEN_WIDTH - 1 : 0]      ARLEN     ,    //burst length
     input   logic   [SIZE_WIDTH - 1 : 0]     ARSIZE    ,    //burst size
     input   logic   [1 : 0]                  ARBURST   , 

//=====================Read Data Channel Signals===============
     output  logic                            RVALID    ,    //slave indicates data is valid
     output  logic   [DATA_WIDTH - 1 : 0]     RDATA     ,    //read data
     output  logic   [ID_WIDTH  - 1 : 0]      RID       ,    //read ID
     output  logic                            RLAST     ,    //indicates last transfer in a burst
     output  logic   [1:0]                    RRESP     ,    //
     input   logic                            RREADY         //master is ready to accept data
 );

//----------------------------------//
//          Internal Signals        //
//----------------------------------//

 logic   [ID_WIDTH-1:0]             stored_awid;
 logic   [ADDR_WIDTH-1:0]           stored_awaddr;
 logic   [7:0]                      stored_awlen;
 logic   [2:0]                      stored_awsize;
 logic   [1:0]                      stored_awburst;
 logic    [ID_WIDTH - 1 : 0 ]       b_bid_out;     
 logic    [1:0]                     b_bresp_out;  
 logic                              b_transfer_done; 
 logic                              wready_in;
    
 logic                              mem_wr_en;
 logic [ADDR_WIDTH-1:0]             mem_wr_addr;
 logic [DATA_WIDTH-1:0]             mem_wr_data;
 logic [DATA_WIDTH/8-1:0]           mem_wr_byte_en;
 
 logic                              r_ar_transfer_occurred;
 logic [ADDR_WIDTH-1:0]             r_latched_araddr;
 logic [ID_WIDTH-1:0]               r_latched_arid;
 logic [7:0]                        r_latched_arlen;
 logic [2:0]                        r_latched_arsize;
 logic [1:0]                        r_latched_arburst;

 logic                              mem_rd_en;
 logic [ADDR_WIDTH-1:0]             mem_rd_addr;
 logic [DATA_WIDTH-1:0]             mem_rd_data_out;

   
 localparam MEM_DEPTH = 2**MEM_ADDR_BITS;

 initial begin
        if (MEM_ADDR_BITS > ADDR_WIDTH) begin
            $error("MEM_ADDR_BITS (%0d) cannot be larger than ADDR_WIDTH (%0d).", MEM_ADDR_BITS, ADDR_WIDTH);
            $finish;
        end
    end

    logic [DATA_WIDTH-1:0] slave_memory [MEM_DEPTH-1:0];


    always_ff @(posedge CLK) begin
        if (mem_wr_en) begin
            logic [MEM_ADDR_BITS-1:0] mem_index;
            mem_index = mem_wr_addr[MEM_ADDR_BITS-1:0];

            for (int i = 0; i < DATA_WIDTH/8; i++) begin
                if (mem_wr_byte_en[i]) begin
                    slave_memory[mem_index][(i*8)+:8] <= mem_wr_data[(i*8)+:8];
                end
            end
        end
    end

    assign mem_rd_data_out = slave_memory[mem_rd_addr[MEM_ADDR_BITS-1:0]];

//=========================Write Address Channel Initialization=================================
axi4_slave_write_address 
#(
                         .ADDR_WIDTH     (ADDR_WIDTH)   ,
                         .ID_WIDTH       (ID_WIDTH)     ,
                         .BURST_LENGTH   (BURST_LENGTH)
      ) write_addr (
                         .clk            (CLK)          ,
                         .rst            (RST)          ,
                         .awready        (AWREADY)      ,
                         .awvalid        (AWVALID)      ,
                         .awaddr         (AWADDR)       ,
                         .awid           (AWID)         ,
                         .awlen          (AWLEN)        ,
                         .awsize         (AWSIZE)       ,
                         .awburst        (AWBURST)      ,
                         .stored_awid    (stored_awid)  ,
                         .stored_awaddr  (stored_awaddr),
                         .stored_awlen   (stored_awlen) ,
                         .stored_awsize  (stored_awsize),
                         .stored_awburst (stored_awburst)
);

 //=========================Write Data Channel Initialization=================================
axi4_slave_data_channel 
#(
                        .DATA_WIDTH     (DATA_WIDTH     ),
                        .ADDR_WIDTH     (ADDR_WIDTH     ),
                        .ID_WIDTH       (ID_WIDTH       )    
      ) write_data (
                        .clk            (CLK            ),
                        .rst            (RST            ),
                        .stored_awid    (stored_awid    ),
                        .stored_awaddr  (stored_awaddr  ),
                        .stored_awlen   (stored_awlen   ),
                        .stored_awsize  (stored_awsize  ),
                        .stored_awburst (stored_awburst ),                        
                        .awvalid        (AWVALID        ),
                        .awready        (AWREADY        ),
                        .wready         (WREADY         ),
                        .burst_length   (AWLEN          ),
                        .wvalid         (WVALID         ),
                        .wdata          (WDATA          ),
                        .wlast          (WLAST          ),
                        .wstrb          (WSTRB          ),
                        .mem_wr_en      (mem_wr_en      ),            
                        .mem_addr       (mem_wr_addr    ),          
                        .mem_wr_data    (mem_wr_data    ),          
                        .mem_byte_en    (mem_wr_byte_en ),
//                      .wid            (WID            ),  // NOT REQUIRED FOR AXI4
                        .b_transfer_done(b_transfer_done),    
                        .b_bid          (b_bid_out      ),    
                        .b_bresp        (b_bresp_out    )         
);

//=========================Write Response Channel Initialization=================================
axi4_slave_write_response 
#(
                        .ID_WIDTH       (ID_WIDTH       )
      ) write_response (
                        .clk            (CLK            ),
                        .rst            (RST            ),
                        .bvalid         (BVALID         ),
                        .bid            (BID            ),
                        .bresp          (BRESP          ),
                        .bready         (BREADY         ),        
                        .b_transfer_done(b_transfer_done),      
                        .b_bid_in       (stored_awid    ),         
                        .b_status_in    (b_bresp_out    ),
                        .wready_in      (WREADY         )
);

//=========================Read Address Channel Initialization=================================
axi4_slave_read_address 
#(
                        .ADDR_WIDTH     (ADDR_WIDTH     ),
                        .ID_WIDTH       (ID_WIDTH       )
      ) read_address (
                        .clk            (CLK            ),
                        .rst            (RST            ),
                        .arready        (ARREADY        ),
                        .arvalid        (ARVALID        ),
                        .araddr         (ARADDR         ),
                        .arid           (ARID           ),
                        .arlen          (ARLEN          ),
                        .arsize         (ARSIZE         ),
                        .arburst        (ARBURST        ),
                        .ar_transfer_occurred (r_ar_transfer_occurred),
                        .latched_araddr       (r_latched_araddr      ),    
                        .latched_arid         (r_latched_arid        ),    
                        .latched_arlen        (r_latched_arlen       ),    
                        .latched_arsize       (r_latched_arsize      ),   
                        .latched_arburst      (r_latched_arburst     )   
);

//=========================Read Data Channel Initialization=================================
axi4_slave_read_data 
#(
                        .DATA_WIDTH     (DATA_WIDTH)    ,
                        .ADDR_WIDTH     (ADDR_WIDTH)    ,
                        .ID_WIDTH       (ID_WIDTH)      
      ) read_data (
                  .clk                  (CLK),
                  .rst                  (RST),
                  .arvalid              (ARVALID)       ,
                  .arready              (ARREADY)       ,
                  .latched_araddr       (r_latched_araddr),     
                  .latched_arid         (r_latched_arid),       
                  .latched_arlen        (r_latched_arlen),      
                  .latched_arsize       (r_latched_arsize),     
                  .latched_arburst      (r_latched_arburst),    
                  .rready               (RREADY),
                  .rvalid               (RVALID),               
                  .rdata                (RDATA),                
                  .rid                  (RID),                  
                  .rlast                (RLAST),                
                  .rresp                (RRESP),                
                  .mem_rd_en            (mem_rd_en),            
                  .mem_addr             (mem_rd_addr),          
                  .mem_rd_data          (mem_rd_data_out)           
);                                                                         

endmodule
