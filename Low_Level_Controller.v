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
input               i_clk,          // Sistem frekansýna sahip clock
input               i_reset,

// Üst seviye cihaza baðlý kontrol sinyalleri
input                in_write,       // Ýletimin baþlayacaðýný gösterir
input                in_op_cont,     // Ýþlemin devam ettiðini gösterir 
input  [23:0]        in_address,  
input  [31:0]        in_word,        // Write modda flasha yazýlacak veri 
input                in_spd,         // 0 -> SPI, 1 -> QSPI
input                in_dir,         // 0 -> read, 1 -> write
output [31:0]        out_word,       // Read modda flashtan okunan veri
output               out_valid,
//output               out_busy,

// Flash Cihazýna Baðlý Giriþ/Çýkýþlar
inout  [3:0]        io_qspi_data,
output              out_qspi_cs,    // When driven low, places device in active power mode. 
output              out_qspi_sck   // On rising edge: Latches commands, addresses, and data on SI, On falling edge: Triggers output on SO 

    );
    
    localparam [15:0] 
    IDLE        =16'b0000_0000_0000_0001      ,
    SEND_CMD    =16'b0000_0000_0000_0010      ,
    SPI_READ    =16'b0000_0000_0000_0100      ,
    QSPI_READ   =16'b0000_0000_0000_1000      ,
    SPI_WRITE 	=16'b0000_0000_0001_0000      ,
    QSPI_WRITE  =16'b0000_0000_0010_0000      ,
    QSPI_WRR	=16'b0000_0000_0100_0000      ,
    QSPI_WREN	=16'b0000_0000_1000_0000      ,
    QSPI_ERASE	=16'b0000_0001_0000_0000      ,
    QSPI_RDSR	=16'b0000_0010_0000_0000       ;
      
    // QSPI cihazýna baðlý shift register
    reg [32:0]  r_qspi_fifo, r_qspi_fifo_next   ;

    // Giriþ registerlarý
    reg         r_spd, r_spd_next, r_spd_nv ;   
    reg         r_dir, r_dir_next, r_dir_nv ;
    reg [23:0]  r_address, r_address_next   ; 
    
    assign      io_qspi_data = (!r_spd) ? ({2'b11,1'bZ,r_qspi_fifo[32]})                  
                                            : (r_dir ? (r_qspi_fifo[32:29]): (4'bZZZZ) )  ;// dir==0 -> okuma, spd==0 -> spý     
                                            
    // Çýkýþ Registerlarý
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
    
    // Status register ve Configuration register'larýna verilecek deðerler. 
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
                    if(in_dir) begin // yazma iþlemi
                        bit_ctr_next    = 32'd8         ;
                        state_next      = QSPI_WREN     ;   // WREN -> WRR -> RDSR -> WREN -> SECTOR ERASE ->RDSR -> SEND CMD -> WRITE
                        r_qspi_fifo_next= {8'h06,{24{1'b0}}} ;
                    end
                    else begin
                        state_next      = SEND_CMD     ;
                        r_qspi_cs_next  = 1'b0          ; 
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
                        state_next      = SPI_READ ;
                    end
                    else if((r_dir_nv == 1'b0) && (r_spd_nv == 1'b1)) begin   
                        bit_ctr_next    = 32'd16    ;   // dummy + 8 cycles
                        r_qspi_fifo_next= in_word   ;
                        state_next      = QSPI_READ;                        
                    end
                    else if((r_dir_nv == 1'b1) && (r_spd_nv == 1'b0)) begin
                        bit_ctr_next    = 32'd16    ;   // dummy + 8 cycles
                        state_next      = SPI_WRITE;
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
                        state_next          =  SEND_CMD                 ;
                        r_qspi_fifo_next    = {r_qspi_fifo[31:0],1'b0}  ;    
                    end
                end
            end
            
            SPI_READ:   // 9.1
            begin
                if(bit_ctr == 32'd0) begin
                    r_out_word_next = r_qspi_fifo       ;
                    if(in_op_cont) begin
                        state_next      = SPI_READ     ;
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
                    if(in_op_cont) begin
                        state_next      =  QSPI_READ    ;
                        r_qspi_cs_next  = 1'b0          ;
                        bit_ctr_next    = 32'd8         ;
                    end
                    else begin
                        r_qspi_cs_next  = 1'b1          ;
                        state_next      =  IDLE         ;
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
            
            QSPI_WREN:  // 9.9: yazma iþlemlerinden once yapýlmalý
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
                    else begin  // wren komutunun iþlenmesi için cs high'a cekilmeli
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
                    else begin // eger 0 degilse okumaya devam et      //////// calýsýyormu kontrol et
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
                    if(r_qspi_cs) begin
                        r_qspi_cs_next  = 1'b0          ;
                        write_flag_next = 1'b1          ;
                        state_next      =  QSPI_RDSR    ;
                        bit_ctr_next    = 32'd16        ;   
                        r_qspi_fifo_next= {8'h05,{24{1'b0}}} ;  // rdsr command   
                    end
                    else begin
                        r_qspi_cs_next  = 1'b1          ;
                        state_next      =  QSPI_ERASE   ;
                    end
                end
                else begin
                    r_qspi_sck_next = ~r_qspi_sck   ;
                    state_next      =  QSPI_ERASE   ;
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
                        r_qspi_fifo_next= in_word   ;
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
                       r_valid_next     = (bit_ctr == 1) ? 1 : 0    ; //****** Bunu yapmanýn daha iyi bir yolunu bul
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
                       r_valid_next     = (bit_ctr == 1) ? 1 : 0    ; //****** Bunu yapmanýn daha iyi bir yolunu bul
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
            
            r_qspi_cs   <= r_qspi_cs_next   ;
            r_qspi_sck  <= r_qspi_sck_next  ;
            r_qspi_fifo <= r_qspi_fifo_next ;
            
            r_out_word  <= r_out_word_next  ;
            
            write_flag  <= write_flag_next  ;
            erase_flag  <= erase_flag_next  ;
            r_address   <= r_address_next   ;
        end
    end
         
    
    
   
    
    
    
    
     
    
endmodule
