`timescale 1ns / 1ps

module AXILite_Wrapper(
// AXI4 LITE SLAVE signals
    // Global Signals
    input                       ACLK,
    input                       ARESET,
    // Write Address Channel
    input [31:0]                AWADDR,
    input                       AWVALID,
    input [2:0]                 AWPROT,
    output                      AWREADY,    //+
    // Write Data Channel
    input [31:0]                WDATA,
    input [3:0]                 WSTRB,
    input                       WVALID,
    output                      WREADY,     //+
    // Write Response Channel // Store, erase buradan gelcek
    input                       BREADY,
    output                      BVALID,     //+
    output [1:0]                BRESP,      //+
    // Read Address Channel
    input [31:0]                ARADDR,     // adresin en anlamli 8 biti hangi islemin gerceklestirilecegine karar vermek icin kullaniliyor 
    input                       ARVALID,
    input [2:0]                 ARPROT,
    output                      ARREADY,    //+
    // Read Data Channel // Load // read buradan gelcek
    input                       RREADY,
    output [31:0]               RDATA,      //+
    output                      RVALID,     //+
    output [1:0]                RRESP       //+
    );
    localparam [3:0] 
    WRITE   =4'h1      ,
    READ    =4'h2      ,
    ERASE   =4'h4      ,
    IDLE    =4'h8       ;
    
    reg [4:0] state, state_next;
    
    reg               in_dir, in_dir_next           ;
    reg               in_erase, in_erase_next       ;
    reg               in_start, in_start_next       ;
    reg [23:0]        in_address, in_address_next   ;
    reg [31:0]        in_word, in_word_next         ; 
    
    wire              out_busy                      ;
    wire [31:0]       out_word                      ;           
    wire              out_valid                     ;
    wire              out_qspi_sck                  ; 
    
    /////////////////////////////////////////////////
    /////            AXI Interface I/O
    /////////////////////////////////////////////////

    assign ARREADY  = ~out_busy;
    assign WREADY   = ~out_busy;
    assign AWREADY  = ~out_busy;
    
    assign RVALID   = (state == WRITE) && out_valid; 
    assign RDATA    = out_word; // Dogru mu?
    
    assign RRESP    = 2'b00;
    assign BRESP    = 2'b00;
    
    assign BVALID   = (state == WRITE) && out_valid;
    
    LLC_AXI a1(
     .i_clk(ACLK)  ,       
     .i_reset(ARESET),                                                                                                         
     .in_start(in_start),  
     .in_op_cont(1'b0),                                                        
     .in_address(in_address),                                                        
     .in_word(in_word),                                                           
     .in_spd(1'b1),         // QUAD okuma sirali okuma yapilmayacaksa(sadece 32 bit okunacaksa) daha yavas                                                             
     .in_dir(in_dir),   
     .in_erase(in_erase),                                                         
     .out_word(out_word),                                                          
     .out_valid(out_valid),                                                                                                                  
     .out_busy(out_busy),                                                                   
     .io_qspi_data(io_qspi_data),                                                      
     .out_qspi_cs(out_qspi_cs),
     .out_qspi_sck(out_qspi_sck)                                                  
    );                                                             
    ////***************************** 
	wire	[3:0]	su_nc;	// Startup primitive, no connect
  STARTUPE2 #(
		.PROG_USR("FALSE"),
		.SIM_CCLK_FREQ(0.0)
	) STARTUPE2_inst (
	.CFGCLK(su_nc[0]),
	.CFGMCLK(su_nc[1]),
	.EOS(su_nc[2]),
	.PREQ(su_nc[3]),
	.CLK(1'b0),
	.GSR(1'b0),
	.GTS(1'b0),
	.KEYCLEARB(1'b0),
	.PACK(1'b0),
	.USRCCLKO(out_qspi_sck),
	.USRCCLKTS(1'b0),
	.USRDONEO(1'b1),
	.USRDONETS(1'b1)
	);
  //  //*****************************
  
    always@* begin
        in_address_next = in_address;
        in_dir_next     = in_dir    ;
        in_erase_next   = in_erase  ;
        in_word_next    = in_word   ;
        in_start_next   = in_start  ;
        state_next      = state     ;
        
        case(state) 
        IDLE: 
        begin
            if ((~out_busy)&& (AWADDR[25] || AWADDR[26])) begin // ERASE
                state_next      = ERASE         ;
                in_erase_next   = 1'b1          ;
                in_start_next   = 1'b1          ;
                in_address_next = AWADDR[23:0]  ;
                in_dir_next     = AWADDR[26] ? 1:0;
            end
            else if((~out_busy)&& AWADDR[24] && WVALID) begin // Write Data //////WVALID -> write valid
                state_next      = WRITE         ;
                in_dir_next     = 1'b1          ;
                in_start_next   = 1'b1          ;
                in_address_next = AWADDR[23:0]  ;
                in_word_next    = WDATA         ;
            end
            else if((~out_busy)&& ARADDR[24] && ARVALID) begin 
                state_next      = READ          ;
                in_dir_next     = 1'b1          ;
                in_start_next   = 1'b1          ;
                in_address_next = ARADDR[23:0]  ;
            end
            else begin
                state_next  = IDLE  ;
            end
        end
        
        WRITE:
        begin
            if(out_valid) begin
                state_next      = IDLE  ;
                in_dir_next     = 1'b0  ;
                in_start_next   = 1'b0  ;
            end
            else begin
                state_next      = WRITE ;
            end
        end
        
        READ: 
        begin
            if(out_valid) begin
                state_next      = IDLE  ;
                in_dir_next     = 1'b0  ;
                in_start_next   = 1'b0  ;
            end
            else begin
                state_next      = READ  ;
            end
        end
        
        ERASE:
        begin
            if(out_valid) begin
                state_next      = IDLE  ;
                in_dir_next     = 1'b0  ;
                in_start_next   = 1'b0  ;
            end
            else begin
                state_next      = ERASE ;
            end
        end
        
        endcase 
    end
    
    always@(posedge ACLK) begin
        if(ARESET) begin
            in_address  <= 24'd0            ;
            in_dir      <= 1'b0             ;
            in_erase    <= 1'b0             ;
            in_word     <= 32'd0            ;
            in_start    <= 1'b0             ;
            state       <= IDLE             ;
        end
        else begin
            in_address  <= in_address_next  ;
            in_dir      <= in_dir_next      ;
            in_erase    <= in_erase_next    ;
            in_word     <= in_word_next     ;
            in_start    <= in_start_next    ;
            state       <= state_next       ;
        end
    end
    
    
endmodule
