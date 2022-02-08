`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.01.2022 10:51:35
// Design Name: 
// Module Name: Low_Level_Controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// Defined Flash Modes
`define	MOD_SPI	    3'b001
`define	MOD_QOUT	3'b010
`define	MOD_QIN	    3'b100

`define DUMMY_CYCLE     4'd8
`define ADDRESS_SIZE    5'd24
`define PRESCALE        32'd100


module Low_Level_Controller(
input               i_clk,          // Sistem frekansına sahip clock
input               i_reset,

// Üst seviye cihaza bağlı kontrol sinyalleri
input                in_write,       // İletimin başlayacağını gösterir
input                in_op_cont,     // İşlemin devam ettiğini gösterir 
input  [23:0]        in_address,  
input  [31:0]        in_word,        // Write modda flasha yazılacak veri 
input                in_spd,         // 0 -> SPI, 1 -> QSPI
input                in_dir,         // 0 -> read, 1 -> write
output [31:0]        out_word,       // Read modda flashtan okunan veri
output               out_valid,
//output               out_busy,

// Flash Cihazına Bağlı Giriş/Çıkışlar
inout  [3:0]        io_qspi_data,
output              out_qspi_cs,    // When driven low, places device in active power mode. 
output              out_qspi_sck   // On rising edge: Latches commands, addresses, and data on SI, On falling edge: Triggers output on SO 

    );
    //*****************************
    
	// The following primitive is necessary in many designs order to gain
	// access to the o_qspi_sck pin.  It's not necessary on the Arty,
	// simply because they provide two pins that can drive the QSPI
	// clock pin.
	wire	[3:0]	su_nc;	// Startup primitive, no connect
    STARTUPE2 #(
		// Leave PROG_USR false to avoid activating the program
		// event security feature.  Notes state that such a feature
		// requires encrypted bitstreams.
		.PROG_USR("FALSE"),
		// Sets the configuration clock frequency (in ns) for
		// simulation.
		.SIM_CCLK_FREQ(0.0)
	) STARTUPE2_inst (
	// CFGCLK, 1'b output: Configuration main clock output -- no connect
	.CFGCLK(su_nc[0]),
	// CFGMCLK, 1'b output: Configuration internal oscillator clock output
	.CFGMCLK(su_nc[1]),
	// EOS, 1'b output: Active high output indicating the End Of Startup.
	.EOS(su_nc[2]),
	// PREQ, 1'b output: PROGRAM request to fabric output
	//	Only enabled if PROG_USR is set.  This lets the fabric know
	//	that a request has been made (either JTAG or pin pulled low)
	//	to program the device
	.PREQ(su_nc[3]),
	// CLK, 1'b input: User start-up clock input
	.CLK(1'b0),
	// GSR, 1'b input: Global Set/Reset input
	.GSR(1'b0),
	// GTS, 1'b input: Global 3-state input
	.GTS(1'b0),
	// KEYCLEARB, 1'b input: Clear AES Decrypter Key input from BBRAM
	.KEYCLEARB(1'b0),
	// PACK, 1-bit input: PROGRAM acknowledge input
	//	This pin is only enabled if PROG_USR is set.  This allows the
	//	FPGA to acknowledge a request for reprogram to allow the FPGA
	//	to get itself into a reprogrammable state first.
	.PACK(1'b0),
	// USRCLKO, 1-bit input: User CCLK input -- This is why I am using this
	// module at all.
	.USRCCLKO(out_qspi_sck),
	// USRCCLKTS, 1'b input: User CCLK 3-state enable input
	//	An active high here places the clock into a high impedence
	//	state.  Since we wish to use the clock as an active output
	//	always, we drive this pin low.
	.USRCCLKTS(1'b0),
	// USRDONEO, 1'b input: User DONE pin output control
	//	Set this to "high" to make sure that the DONE LED pin is
	//	high.
	.USRDONEO(1'b1),
	// USRDONETS, 1'b input: User DONE 3-state enable output
	//	This enables the FPGA DONE pin to be active.  Setting this
	//	active high sets the DONE pin to high impedence, setting it
	//	low allows the output of this pin to be as stated above.
	.USRDONETS(1'b1)
	);
    
    //*****************************
    localparam [15:0] 
    IDLE        =16'h0001      ,
    SEND_CMD    =16'h0002      ,
    SPI_READ    =16'h0004      ,
    QSPI_READ   =16'h0008      ,
    SPI_WRITE 	=16'h0010      ,
    QSPI_WRITE  =16'h0020      ,
    QSPI_WRR	=16'h0040      ,
    QSPI_WREN	=16'h0080      ,
    QSPI_ERASE	=16'h0100      ,
    QSPI_RDSR	=16'h0200       ;
      
    // QSPI cihazına bağlı shift register
    reg [32:0]  r_qspi_fifo, r_qspi_fifo_next   ;

    // Giriş registerları
    reg         r_spd, r_spd_next, r_spd_nv ;   
    reg         r_dir, r_dir_next, r_dir_nv ;
    reg [23:0]  r_address, r_address_next   ; 
    
    assign      io_qspi_data = (!r_spd) ? ({2'b11,1'bZ,r_qspi_fifo[32]})                  
                                            : (r_dir ? (r_qspi_fifo[32:29]): (4'bZZZZ) )  ;// dir==0 -> okuma, spd==0 -> spı     
                                            
    // Çıkış Registerları
    reg [31:0]  r_out_word, r_out_word_next ;
    reg         r_valid   , r_valid_next    ;
    //reg         r_busy    , r_busy_next     ;
    
    reg         r_qspi_cs , r_qspi_cs_next  ; 
    reg         r_qspi_sck, r_qspi_sck_next ;
    
    assign      out_word    = r_out_word    ;   
    assign      out_valid   = r_valid       ;
    //assign      out_busy    = r_busy        ;  
    
    assign      out_qspi_cs = r_qspi_cs     ;
    assign      out_qspi_sck= r_qspi_sck    ;     
            
    // Kontrol Sinyalleri
    reg [31:0]  bit_ctr  , bit_ctr_next     ;  
    reg [15:0]  state    , state_next       ; 
    reg [31:0]  clock_ctr, clock_ctr_next   ;
    reg         erase_flag, erase_flag_next ;
    reg         write_flag, write_flag_next ;
    
    // Status register ve Configuration register'larına verilecek değerler. 
    reg [7:0]   qspi_inst                   ;
    reg [7:0]   rdsr_read_reg               ;
    reg [7:0]   rdsr_read_reg_next          ;
                
    always@* begin
        bit_ctr_next        = bit_ctr       ;
        clock_ctr_next      = clock_ctr     ; 
        state_next          = state         ;
      
        r_qspi_fifo_next    = r_qspi_fifo   ;
        r_qspi_sck_next     = r_qspi_sck    ;
        r_qspi_cs_next      = r_qspi_cs     ;
        
        r_dir_next          = r_dir         ;
        r_spd_next          = r_spd         ;
      
        r_out_word_next     = r_out_word    ;
        r_valid_next        = r_valid       ;
        //r_busy_next         = r_busy        ;
        r_address_next      = r_address     ;
        
        write_flag_next     = write_flag    ;
        erase_flag_next     = erase_flag    ;
        
        if(clock_ctr > 0) begin
            clock_ctr_next  = clock_ctr - 32'd1        ;
        end
        else if(clock_ctr == 32'd0) begin
            clock_ctr_next  = `PRESCALE - 32'd1        ; 
            case(state)
            
            IDLE: 
            begin
                if((in_write)) begin //(!r_busy)&&
                    r_spd_next      = 1'b0              ;
                    r_dir_next      = 1'b0              ;
                    r_spd_nv        = in_spd            ;
                    r_dir_nv        = in_dir            ;
                    r_address_next  = in_address        ;
                    r_qspi_cs_next  = 1'b0              ;
                    if(in_dir) begin // yazma işlemi
                        bit_ctr_next    = 32'd8         ;
                        state_next      = QSPI_WREN     ;   // WREN -> WRR -> RDSR -> WREN -> SECTOR ERASE -> RDSR -> SEND CMD -> WRITE
                        r_qspi_fifo_next= {8'h06,{24{1'b0}}} ;
                    end
                    else begin
                        state_next      = SEND_CMD      ; 
                        r_qspi_sck_next = 1'b0          ;       
                        bit_ctr_next    = 32'd32        ;
                        r_qspi_fifo_next= {(in_spd ? 8'h03:8'h6b),r_address}; 
                    end   
                end
                else begin
                    state_next      = IDLE          ;    
                    r_qspi_cs_next  = 1'b1          ;
                end
            end
            
            SEND_CMD:
            begin
                if( bit_ctr == 32'd0) begin
                    r_qspi_sck_next = 1'b0          ;
                    r_qspi_cs_next  = 1'b0          ;
                    r_spd_next      = r_spd_nv      ;
                    r_dir_next      = r_dir_nv      ; 
                    // Diger degiskenleri ekle
                    if((r_dir_nv == 1'b0) && (r_spd_nv == 1'b0)) begin 
                        bit_ctr_next    = 32'd32    ;
                        r_qspi_fifo_next= in_word   ;
                        state_next      = SPI_READ  ;
                    end
                    else if((r_dir_nv == 1'b0) && (r_spd_nv == 1'b1)) begin   
                        bit_ctr_next    = 32'd16    ;   // dummy + 8 cycles
                        r_qspi_fifo_next= in_word   ;
                        state_next      = QSPI_READ ;                         
                    end
                    else if((r_dir_nv == 1'b1) && (r_spd_nv == 1'b0)) begin
                        bit_ctr_next    = 32'd32    ;   
                        state_next      = SPI_WRITE ;
                    end
                    else if((r_dir_nv == 1'b1) && (r_spd_nv == 1'b1)) begin
                        bit_ctr_next    = 32'd16    ;   // dummy + 8 cycles
                        state_next      = QSPI_WRITE;
                    end
                end
                else begin
                    r_qspi_sck_next     = ~r_qspi_sck   ;
                    r_dir_next          = 1'b0          ;
                    r_spd_next          = 1'b0          ;
                    if(!r_qspi_sck) begin    
                        bit_ctr_next        = bit_ctr - 32'd1           ;
                        state_next          = SEND_CMD                  ;
                        r_qspi_fifo_next    = {r_qspi_fifo[31:0],1'b0}  ;    
                    end
                end
            end
            
            SPI_READ:   // 9.1
            begin
                if(bit_ctr == 32'd0) begin
                    r_out_word_next = r_qspi_fifo       ;
                    if(in_op_cont) begin
                        state_next      = SPI_READ      ;
                        r_qspi_cs_next  = 1'b0          ;
                        bit_ctr_next    = 32'd32        ;
                        r_qspi_sck_next = ~r_qspi_sck   ;
                    end
                    else begin
                        state_next      = IDLE          ;
                        r_qspi_cs_next  = 1'b1          ;   // transaction ends
                        r_qspi_sck_next = 1'b0          ;      
                    end
                end
                else begin
                    r_qspi_sck_next = ~r_qspi_sck       ;
                    state_next      = SPI_READ          ;
                    if(!r_qspi_sck) begin
                        bit_ctr_next    = bit_ctr - 32'd1                       ;
                        r_qspi_fifo_next= {r_qspi_fifo[31:0], io_qspi_data[1]}  ; // bitler fifoya kaydediliyor. // SO -> io_qspi_data[1]
                    end         
                end
            end
            
            QSPI_READ:  // 9.4
            begin
                if(bit_ctr == 32'd0) begin
                    r_qspi_sck_next = 1'b0              ;   
                    r_out_word_next = r_qspi_fifo       ;   // dummy cyclelar eksik
                    r_qspi_cs_next  = 1'b0              ;
                    if(in_op_cont) begin
                        state_next      = QSPI_READ     ;
                        r_qspi_cs_next  = 1'b0          ;
                        bit_ctr_next    = 32'd8         ;
                    end
                    else begin
                        r_qspi_cs_next  = 1'b1          ;
                        state_next      = IDLE          ;
                    end
                end           
                else begin
                    r_qspi_sck_next = ~r_qspi_sck       ;
                    state_next      =  QSPI_READ        ;
                    if(!r_qspi_sck) begin
                        bit_ctr_next    = bit_ctr - 32'd1                       ;
                        r_qspi_fifo_next= {r_qspi_fifo[28:0], io_qspi_data[3:0]};    
                    end  
                end
            end
            
            QSPI_WREN:  // 9.9: yazma işlemlerinden once yapılmalı
            begin
                if(bit_ctr == 32'd0) begin
                    r_qspi_sck_next = 1'b0          ;
                    if(r_qspi_cs) begin
                        r_qspi_cs_next  = 1'b0      ;
                        if(erase_flag) begin
                            erase_flag_next = 1'b0              ;
                            state_next      =  QSPI_ERASE       ;
                            bit_ctr_next    = 32'd32            ;
                            r_qspi_fifo_next= {8'h20, r_address};
                        end
                        else begin
                            state_next      =  QSPI_WRR ;
                            bit_ctr_next    = 32'd24    ;  
                            r_qspi_fifo_next= {8'h01, (r_spd ? 16'h04 : 16'h04), {8{1'b0}}}    ;   // degerleri bul
                        end           
                    end
                    else begin  // wren komutunun işlenmesi için cs high'a cekilmeli
                        state_next      =  QSPI_WREN;
                        r_qspi_cs_next  = 1'b1      ;   
                    end
                end
                else begin
                    r_qspi_sck_next = ~r_qspi_sck   ;
                    state_next      =  QSPI_WREN    ;
                    if(!r_qspi_sck) begin
                        bit_ctr_next    = bit_ctr - 32'd1       ;
                        r_qspi_fifo_next= {r_qspi_fifo[31:0],1'b0};   
                    end
                end
            end
            
            QSPI_WRR:   // 9.13
            begin
                if(bit_ctr == 32'd0) begin
                    r_qspi_sck_next = 1'b0          ;
                    if(r_qspi_cs) begin
                        r_qspi_cs_next  = 1'b0      ;
                        bit_ctr_next    = 32'd16    ;   
                        state_next      =  QSPI_RDSR;
                        r_qspi_fifo_next= {8'h05,{24{1'b0}}} ;  // rdsr command
                    end
                    else begin
                        state_next      =  QSPI_WRR ;
                        r_qspi_cs_next  = 1'b1      ;
                    end       
                end
                else begin
                    r_qspi_sck_next = ~r_qspi_sck   ;
                    state_next      =  QSPI_WRR     ; 
                    if(!r_qspi_sck) begin
                        bit_ctr_next    = bit_ctr - 32'd1       ;
                        r_qspi_fifo_next= {r_qspi_fifo[31:0],1'b0};   
                    end
                end
            end
            
            QSPI_RDSR:  // 9.11
            begin
                if(bit_ctr == 32'd0) begin 
                    if(rdsr_read_reg[0] == 1'b0) begin
                        r_qspi_sck_next = 1'b0          ;
                        if(r_qspi_cs) begin // WRR isleminden sonra           
                            if(write_flag_next) begin // QSPI_ERASE isleminden sonra
                                bit_ctr_next    = 32'd32    ; // degeri duzelt.
                                r_qspi_fifo_next= {(r_spd_nv ? 8'h02 : 8'h32),r_address};  
                                state_next      =  SEND_CMD ;
                                bit_ctr_next    = 32'd8     ;   
                                r_qspi_cs_next  = 1'b0      ;
                            end
                            else begin
                                r_qspi_cs_next  = 1'b0      ;
                                state_next      = QSPI_WREN ;
                                erase_flag_next = 1'b1      ;
                                r_qspi_fifo_next= {8'h06,{24{1'b0}}} ;
                                bit_ctr_next    = 32'd8     ;  
                            end
                        end
                        else begin  //  cs high'a cekilmeli
                            r_qspi_cs_next  = 1'b1          ;
                            state_next      =  QSPI_RDSR    ;
                        end
                    end
                    else begin // eger 0 degilse okumaya devam et      //////// calısıyormu kontrol et
                        r_qspi_sck_next = 1'b0              ;
                        state_next      =  QSPI_RDSR        ;
                        rdsr_read_reg   = 8'd0              ;
                        bit_ctr_next    = 32'd7             ;      
                    end
                end
                else begin
                    r_qspi_sck_next = ~r_qspi_sck   ;
                    state_next      =  QSPI_RDSR    ; 
                    if((!r_qspi_sck) && (bit_ctr > 8)) begin
                        bit_ctr_next    = bit_ctr - 32'd1       ;
                        r_qspi_fifo_next= {r_qspi_fifo[31:0],1'b0};
                    end
                    else if((!r_qspi_sck) && (bit_ctr <= 8)) begin
                        rdsr_read_reg_next  = {rdsr_read_reg[6:0], io_qspi_data[1]} ;
                        state_next          =  QSPI_RDSR                            ; 
                        bit_ctr_next        = bit_ctr - 32'd1                       ;  
                    end 
                end
            end
            
            QSPI_ERASE:
            begin
                if(bit_ctr == 32'd0) begin
                    r_qspi_sck_next = 1'b0              ;
                    if(r_qspi_cs) begin
                        r_qspi_cs_next  = 1'b0          ;
                        write_flag_next = 1'b1          ;
                        state_next      = QSPI_RDSR     ;
                        bit_ctr_next    = 32'd16        ;   
                        r_qspi_fifo_next= {8'h05,{24{1'b0}}} ;  // rdsr command   
                    end
                    else begin
                        r_qspi_cs_next  = 1'b1          ;
                        state_next      = QSPI_ERASE    ;
                    end
                end
                else begin
                    r_qspi_sck_next = ~r_qspi_sck       ;
                    state_next      = QSPI_ERASE        ;
                    if(!r_qspi_sck) begin
                        bit_ctr_next    = bit_ctr - 32'd1   ;
                        r_qspi_fifo_next= {r_qspi_fifo[31:0],1'b0};
                    end  
                end
            end
            
            SPI_WRITE: // 9.14
            begin
                if(bit_ctr == 32'd0) begin
                    r_qspi_sck_next = 1'b0          ;
                    if(in_op_cont) begin
                        // bu iki degeri her yerde guncellemek gerekiyor
                        r_qspi_cs_next  = 1'b0      ;   //***************************************
                        state_next      =  SPI_WRITE;
                        bit_ctr_next    = 32'd32    ;
                        r_qspi_fifo_next= {in_word,1'b0}   ;
                    end
                    else begin
                        r_qspi_cs_next  = 1'b1      ;
                        state_next      =  IDLE     ;
                    end
                end
                else begin
                    r_qspi_sck_next     = ~r_qspi_sck   ;
                    state_next          =  SPI_WRITE    ;
                    if(!r_qspi_sck) begin
                       bit_ctr_next     = bit_ctr - 32'd1           ;
                       r_qspi_fifo_next = {r_qspi_fifo[31:0],1'b0}  ;
                       r_valid_next     = (bit_ctr == 1) ? 1 : 0    ; //****** Bunu yapmanın daha iyi bir yolunu bul
                    end 
                end
            end
            
            QSPI_WRITE: // 9.15
            begin
                if(bit_ctr == 32'd0) begin
                    r_qspi_sck_next = 1'b0          ;
                    if(in_op_cont) begin
                        // bu iki degeri her yerde guncellemek gerekiyor
                        r_qspi_cs_next  = 1'b0      ;   //***************************************
                        state_next      = SPI_WRITE;
                        bit_ctr_next    = 32'd8     ;
                        r_qspi_fifo_next= in_word   ;
                    end
                    else begin
                        r_qspi_cs_next  = 1'b1      ;
                        state_next      = IDLE      ;
                    end
                end
                else begin
                    r_qspi_sck_next     = ~r_qspi_sck   ;
                    state_next          =  QSPI_WRITE   ;
                    if(!r_qspi_sck) begin
                       bit_ctr_next     = bit_ctr - 32'd1           ;
                       r_qspi_fifo_next = {r_qspi_fifo[28:0],4'd0}  ;
                       r_valid_next     = (bit_ctr == 1) ? 1 : 0    ; //****** Bunu yapmanın daha iyi bir yolunu bul
                    end 
                end
            end
            endcase
        end      
    end
    
    always@(posedge i_clk) begin
        if(i_reset) begin
            clock_ctr   <= `PRESCALE - 32'd1;
            bit_ctr     <= 32'd0            ;
            state       <= IDLE             ;
            
            erase_flag  <= 1'b0             ;
            write_flag  <= 1'b0             ;
            
            r_spd       <= 1'b0             ;
            r_dir       <= 1'b0             ;
            r_valid     <= 1'b0             ;
            
            r_address   <= 32'd0            ;
            r_out_word  <= 32'd0            ;    
            
            r_qspi_cs   <= 1'b1             ;
            r_qspi_sck  <= 1'b0             ;
            r_qspi_fifo <= 32'd0            ;
        end
        else begin
            clock_ctr   <= clock_ctr_next   ;
            bit_ctr     <= bit_ctr_next     ;
            state       <=  state_next      ;
            
            erase_flag  <= erase_flag_next  ;
            write_flag  <= write_flag_next  ;
            
            r_dir       <= r_dir_next       ;
            r_spd       <= r_spd_next       ;
            
            r_qspi_cs   <= r_qspi_cs_next   ;
            r_qspi_sck  <= r_qspi_sck_next  ;
            r_qspi_fifo <= r_qspi_fifo_next ;
            
            r_out_word  <= r_out_word_next  ;
            r_valid     <= r_valid_next     ;
            
            write_flag  <= write_flag_next  ;
            erase_flag  <= erase_flag_next  ;
            r_address   <= r_address_next   ;
        end
    end
         
    
    
   
    
    
    
    
     
    
endmodule
