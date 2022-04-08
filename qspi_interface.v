`timescale 1ns / 1ps

`define PRESCALE        32'd5

module qspi_interface(
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
    output [1:0]                RRESP,       //+
    // Flash Controller i/o
    inout  [3:0]        io_qspi_data,
    output              out_qspi_cs
    );
    
 reg               i_dir,       i_dir_next;
 reg               i_spd,       i_spd_next;
 reg               in_start,    in_start_next;
 reg [23:0]        in_address,  in_address_next;
 reg [31:0]        in_word,     in_word_next;
 reg               in_erase,    in_erase_next;
 reg [11:0]        t_state, t_state_next;
 reg [31:0]        clock_ctr, clock_ctr_next;
 
 
 wire [31:0]       out_word;           
 wire              out_valid ;
 
 wire out_qspi_sck; 

 
 (*dont_touch = "true"*) wire out_busy;
 
 (*dont_touch = "true"*)wire in_axisync;
 assign in_axisync = t_state[5];
 
  LLC_AXI LLC(
   .i_clk(ACLK)  ,       
   .i_reset(ARESET),                                                                                                        
   .in_start(in_start),  
   .in_op_cont(1'b0),                                                        
   .in_address(in_address),                                                        
   .in_word(in_word),                                                           
   .in_spd(1'b1),                                                            
   .in_dir(i_dir),
   .in_erase(in_erase),                                                            
   .out_word(out_word),                                                          
   .out_valid(out_valid), 
   .in_axisync(in_axisync),                                                                                                                 
   .out_busy(out_busy),                                                                   
   .io_qspi_data(io_qspi_data),                                                      
   .out_qspi_cs(out_qspi_cs),
   .out_qspi_sck(out_qspi_sck),     
   .in_clock_ctr(clock_ctr)                                             
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
 
 
    assign ARREADY  = ~out_busy;
    assign WREADY   = ~out_busy;
    assign AWREADY  = ~out_busy;
    
    assign RVALID   = (t_state == 12'h002) && out_valid; 
    assign RDATA    = out_word; // Dogru mu?
    
    assign RRESP    = 2'b00;
    assign BRESP    = 2'b00;
    
    assign BVALID   = (t_state == 12'h004) && out_valid;   
 
 
    always@* begin
        clock_ctr_next      = clock_ctr ;
        i_dir_next          = i_dir     ;
        i_spd_next          = i_spd     ;
        in_start_next       = in_start  ;
        in_address_next     = in_address;
        in_word_next        = in_word   ;
        in_erase_next       = in_erase  ;
        t_state_next        = t_state   ;
        if(clock_ctr > 0) begin
            clock_ctr_next  = clock_ctr - 32'd1 ;
        end
        else if(clock_ctr == 32'd0) begin

            case(t_state)
            
            12'h008: // IDLE
            begin
                if ((~out_busy)&& (AWADDR[25] || AWADDR[26])) begin // ERASE
                    t_state_next    = 12'h001           ;
                    i_dir_next      = AWADDR[26] ? 1:0  ;         
                    in_start_next   = 1'b1              ;
                    in_erase_next   = 1'b1              ;
                    in_address_next = AWADDR[23:0]      ;
                    clock_ctr_next  = `PRESCALE - 32'd1 ;
                end
                
                else if((~out_busy)&& AWADDR[24] && WVALID) begin // Write Data //////WVALID -> write valid
                    t_state_next    = 12'h002       ;
                    i_dir_next      = 1'b1          ;
                    in_start_next   = 1'b1          ;
                    in_erase_next   = 1'b0          ;
                    in_address_next = AWADDR[23:0]  ;
                    in_word_next    = WDATA         ;
                    clock_ctr_next  = `PRESCALE - 32'd1 ;
                end
                
                else if((~out_busy)&& ARADDR[24] && ARVALID) begin // Read
                    t_state_next    = 12'h004       ;
                    i_dir_next      = 1'b0          ;
                    in_start_next   = 1'b1          ;
                    in_erase_next   = 1'b0          ;
                    in_address_next = ARADDR[23:0]  ;
                    clock_ctr_next  = `PRESCALE - 32'd1 ;
                end
                
                else begin
                    clock_ctr_next  = 32'd0         ;   
                    t_state_next    = 12'h020       ;
                end
            end
            
            
            12'h001: // erase,
            begin
                if(out_valid) begin
                    t_state_next    = 12'h020   ; 
                    i_dir_next      = 1'b0      ;         
                    in_start_next   = 1'b0      ;
                    in_erase_next   = 1'b0      ;
                    in_address_next = 24'd0     ;
                    clock_ctr_next  = 32'd0     ;
                end
                else begin
                    t_state_next    = 12'h001           ;
                    clock_ctr_next  = `PRESCALE - 32'd1 ;
                end
            end
            
            12'h002: // qspi write,
            begin
                if(out_valid) begin
                    t_state_next    = 12'h020   ; 
                    i_dir_next      = 1'b0      ;         
                    in_start_next   = 1'b0      ;
                    in_erase_next   = 1'b0      ;
                    in_address_next = 24'd0     ;
                    clock_ctr_next  = 32'd0     ;    
                end
                else begin
                    t_state_next    = 12'h002           ;
                    clock_ctr_next  = `PRESCALE - 32'd1 ;
                end
            end
            
            
            12'h004: // qspi read,
            begin       
                if(out_valid) begin
                    t_state_next    = 12'h020   ; 
                    i_dir_next      = 1'b0      ;         
                    in_start_next   = 1'b0      ;
                    in_erase_next   = 1'b0      ;
                    in_address_next = 24'd0     ;
                    clock_ctr_next  = 32'd0     ;
                end
                else begin
                    t_state_next    = 12'h004           ;
                    clock_ctr_next  = `PRESCALE - 32'd1 ;
                end
            end   
            endcase
        end
    end
    
    always@(posedge ACLK) begin
        if(ARESET) begin
            clock_ctr      <= 32'd0 ;
            i_dir          <= 1'b0  ;
            i_spd          <= 1'b0  ;    
            in_start       <= 1'b0  ;     
            in_address     <= 24'd0 ;  
            in_word        <= 32'd0 ;
            in_erase       <= 1'b0  ;
            t_state        <= 12'h020 ;
        end
        else begin
            clock_ctr      <= clock_ctr_next ;
            i_dir          <= i_dir_next     ;
            i_spd          <= i_spd_next     ;    
            in_start       <= in_start_next  ;     
            in_address     <= in_address_next;  
            in_word        <= in_word_next   ;
            in_erase       <= in_erase_next  ;
            t_state        <= t_state_next   ;
        end
        
    end
    
endmodule
