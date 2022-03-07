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
    QSPI_RDSR	=16'h0200              ;
      
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
    reg         wrr_flag, wrr_flag_next     ;
    reg         r_op_cont, r_op_cont_next   ;
    reg         q_rd_flag, q_rd_flag_next   ;
    
    
  
                
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
        r_op_cont_next      = r_op_cont     ;
        
        wrr_flag_next       = wrr_flag      ;
        write_flag_next     = write_flag    ;
        erase_flag_next     = erase_flag    ;
        write_flag_next     = write_flag    ;
        q_rd_flag_next      = q_rd_flag     ;
        
        if(clock_ctr > 0) begin
            clock_ctr_next  = clock_ctr - 32'd1        ;
        end
        else if(clock_ctr == 32'd0) begin
            clock_ctr_next  = `PRESCALE - 32'd1        ; 
            case(state)
            
            IDLE: 
            begin
                if((in_write)) begin //
                    r_spd_next      = 1'b0              ;
                    r_dir_next      = 1'b0              ;
                    r_spd_nv        = in_spd            ;
                    r_dir_nv        = in_dir            ;
                    r_address_next  = in_address        ;
                    r_qspi_cs_next  = 1'b0              ;
                    r_op_cont_next  = in_op_cont        ; 
                    r_qspi_sck_next = 1'b0              ; 
                    if(r_spd_nv) begin // Qspi write
                        bit_ctr_next    = 32'd8         ;
                        state_next      = QSPI_WREN     ;   // WREN -> WRR -> RDSR -> WREN -> SECTOR ERASE -> RDSR -> WREN-> SEND CMD -> WRITE -> RDSR
                        r_qspi_fifo_next= { 1'b0, 8'h06,{24{1'b0}}} ; 
                        if(!r_dir_nv) begin // qspi read mode
                            q_rd_flag_next  = 1'b1      ;        
                        end
                    end
                       
                    else if(!r_spd_nv && r_dir_nv) begin // Spi write
                        state_next      = QSPI_WREN     ;
                        erase_flag_next = 1'b1          ;        
                        bit_ctr_next    = 32'd8         ;
                        r_qspi_fifo_next= {1'b0, 8'h06,{24{1'b0}}} ;
                    end
                    
                    else begin  // Spi read
                        state_next      = SEND_CMD      ;       
                        bit_ctr_next    = 32'd32        ;
                        r_qspi_fifo_next= {1'b0, 8'h03,r_address_next}; 
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
                        state_next      = SPI_READ  ;
                    end
                    else if((r_dir_nv == 1'b0) && (r_spd_nv == 1'b1)) begin   
                        bit_ctr_next    = 32'd16    ;   // dummy + 8 cycles
                        state_next      = QSPI_READ ;                         
                    end
                    else if((r_dir_nv == 1'b1) && (r_spd_nv == 1'b0)) begin
                        bit_ctr_next    = 32'd32    ;   
                        state_next      = SPI_WRITE ;
                        r_qspi_fifo_next= in_word   ;
                    end
                    else if((r_dir_nv == 1'b1) && (r_spd_nv == 1'b1)) begin
                        bit_ctr_next    = 32'd16    ;   // dummy + 8 cycles
                        state_next      = QSPI_WRITE;
                        r_qspi_fifo_next= in_word   ;
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
                    r_out_word_next = r_qspi_fifo[32:1] ;
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
                        r_dir_next      = 1'b0          ;
                        r_spd_next      = 1'b0          ;  
                    end
                end
                else begin
                    r_qspi_sck_next = ~r_qspi_sck       ;
                    state_next      = SPI_READ          ;
                    r_op_cont_next  = in_op_cont        ;
                    if(!r_qspi_sck) begin
                        bit_ctr_next    = bit_ctr - 32'd1                       ;
                        r_qspi_fifo_next= {r_qspi_fifo[31:0], io_qspi_data[1]}  ; // bitler fifoya kaydediliyor. // SO -> io_qspi_data[1]
                        r_valid_next     = (bit_ctr == 1) ? 1 : 0    ;
                    end         
                end
            end
            
            QSPI_READ:  // 9.4
            begin
                if(bit_ctr == 32'd0) begin
                    r_out_word_next = r_qspi_fifo[32:1] ;   
                    if(in_op_cont) begin
                        state_next      = QSPI_READ     ;
                        r_qspi_cs_next  = 1'b0          ;
                        bit_ctr_next    = 32'd8         ;
                    end
                    else begin
                        r_qspi_sck_next = 1'b0          ; 
                        r_qspi_cs_next  = 1'b1          ;
                        state_next      = IDLE          ;
                        r_dir_next      = 1'b0          ;
                        r_spd_next      = 1'b0          ;
                    end
                end           
                else begin
                    r_qspi_sck_next = ~r_qspi_sck       ;
                    state_next      =  QSPI_READ        ;
                    r_op_cont_next  = in_op_cont        ;
                    if(!r_qspi_sck) begin
                        bit_ctr_next    = bit_ctr - 32'd1;
                        r_valid_next    = (bit_ctr == 1) ? 1 : 0    ;
                        if(bit_ctr <= 8) begin // 8 cycle dummy 
                            r_qspi_fifo_next= {r_qspi_fifo[28:0], io_qspi_data[3:0]};
                        end
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
                            r_qspi_fifo_next= {1'b0, 8'h20, r_address};
                        end
                        else if(write_flag) begin
                            write_flag_next = 1'b0              ;
                            state_next      = SEND_CMD          ;
                            bit_ctr_next    = 32'd32            ;
                            r_qspi_fifo_next= {1'b0, r_spd_nv ? 8'h32 : 8'h02, r_address};         
                        end
                        else begin
                            state_next      =  QSPI_WRR ;
                            bit_ctr_next    =  32'd24   ;  
                            r_qspi_fifo_next= {1'b0, 8'h01, 16'b0000_0010_0000_0010, {8{1'b0}}}    ;   // yanlis olabilir 
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
                        if(r_spd_nv)begin
                            wrr_flag_next   = 1'b1      ;
                        end
                        else begin
                            q_rd_flag_next  = 1'b1  ;
                        end
                        r_qspi_cs_next  = 1'b0      ;
                        bit_ctr_next    = 32'd16    ;   
                        state_next      = QSPI_RDSR ;
                        r_qspi_fifo_next= {1'b0,8'h05,{24{1'b0}}} ;  // rdsr command
                    end
                    
                    else begin
                        state_next      = QSPI_WRR  ;
                        r_qspi_cs_next  = 1'b1      ;
                    end       
                end
                else begin
                    r_qspi_sck_next = ~r_qspi_sck   ;
                    state_next      =  QSPI_WRR     ; 
                    if(!r_qspi_sck) begin
                        bit_ctr_next    = bit_ctr - 32'd1         ;
                        r_qspi_fifo_next= {r_qspi_fifo[31:0],1'b0};   
                    end
                end
            end
            
            QSPI_RDSR:  // 9.11
            begin
                if(bit_ctr == 32'd0) begin 
                    if(r_qspi_fifo[0] == 1'b0) begin
                        if(r_qspi_cs_next) begin
                            r_qspi_sck_next = 1'b0          ;
                            if(wrr_flag) begin // wrr isleminden sonra
                                wrr_flag_next   = 1'b0      ;
                                r_qspi_cs_next  = 1'b0      ;
                                
                                state_next      = QSPI_WREN ;
                                erase_flag_next = 1'b1      ;
                                r_qspi_fifo_next= {1'b0, 8'h06,{24{1'b0}}} ;
                                bit_ctr_next    = 32'd8     ;  
                            end     
                            else if(write_flag) begin // QSPI_WRITE isleminden sonra
                                write_flag_next = 1'b0      ;
                                bit_ctr_next    = 32'd0     ;  
                                state_next      =  IDLE     ;   
                                r_qspi_cs_next  = 1'b1      ;
                            end
                            else if(erase_flag) begin  // erase isleminden sonra 
                                erase_flag_next = 1'b0      ;
                                r_qspi_cs_next  = 1'b0      ;
                                state_next      = QSPI_WREN ;
                                write_flag_next = 1'b1      ;
                                r_qspi_fifo_next= {1'b0, 8'h06,{24{1'b0}}} ;
                                bit_ctr_next    = 32'd8     ;  
                            end
                            else if(q_rd_flag) begin
                                q_rd_flag_next  = 1'b0          ;
                                state_next      = SEND_CMD      ; 
                                r_qspi_sck_next = 1'b0          ;       
                                bit_ctr_next    = 32'd32        ;
                                r_qspi_fifo_next= {1'b0, 8'h6b, r_address_next};  
                            end
                        end
                        else begin
                            state_next      = QSPI_RDSR         ;
                            r_qspi_cs_next  = 1'b1              ;                      
                        end
                    end
                    else begin // eger 0 degilse okumaya devam et      //////// calısıyormu kontrol et
                        r_qspi_sck_next = 1'b0              ;
                        state_next      = QSPI_RDSR         ;
                        r_qspi_fifo_next= {r_qspi_fifo[32:8],8'd0} ;
                        bit_ctr_next    = 32'd8             ;      
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
                        r_qspi_fifo_next  = {r_qspi_fifo[31:0], io_qspi_data[1]}; // r_qspi_fifo ile yap
                        bit_ctr_next        = bit_ctr - 32'd1                   ;  
                        r_qspi_sck_next     = 1'b0                              ;
                    end 
                end
            end
            
            QSPI_ERASE: // 9.16
            begin
                if(bit_ctr == 32'd0) begin
                    r_qspi_sck_next = 1'b0              ;
                    if(r_qspi_cs) begin
                        r_qspi_cs_next  = 1'b0          ;
                        erase_flag_next = 1'b1          ;
                        state_next      = QSPI_RDSR     ;
                        bit_ctr_next    = 32'd16        ;   
                        r_qspi_fifo_next= {1'b0, 8'h05,{24{1'b0}}} ;  // rdsr command   
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
                    r_qspi_sck_next     = 1'b0      ;
                    if(in_op_cont) begin
                        r_qspi_cs_next  = 1'b0      ;   
                        state_next      = SPI_WRITE ;
                        bit_ctr_next    = 32'd32    ;
                        r_qspi_fifo_next= {in_word,1'b0}   ;
                    end
                    else begin
                    if(!r_qspi_cs) begin
                        r_qspi_cs_next  = 1'b0      ;
                        write_flag_next = 1'b1      ;
                        bit_ctr_next    = 32'd16    ;
                        state_next      = QSPI_RDSR ;
                        r_qspi_fifo_next= {1'b0, 8'h05,{24{1'b0}}} ;
                    end
                    else begin
                        r_qspi_cs_next  = 1'b1      ;
                        state_next      = SPI_WRITE ;
                    end
                    end
                end
                else begin
                    r_qspi_sck_next     = ~r_qspi_sck   ;
                    state_next          =  SPI_WRITE    ;
                    r_op_cont_next      = in_op_cont    ;
                    if(!r_qspi_sck) begin
                       bit_ctr_next     = bit_ctr - 32'd1           ;
                       r_qspi_fifo_next = {r_qspi_fifo[31:0],1'b0}  ;
                       r_valid_next     = (bit_ctr == 1) ? 1 : 0    ; 
                    end 
                end
            end
            
            QSPI_WRITE: // 9.15
            begin
                if(bit_ctr == 32'd0) begin
                        r_qspi_sck_next = 1'b0          ;
                        if(in_op_cont) begin
                            r_qspi_cs_next  = 1'b0      ;   
                            state_next      = QSPI_WRITE;
                            bit_ctr_next    = 32'd8     ;
                            r_qspi_fifo_next= in_word   ;
                        end
                        else begin
                            r_qspi_cs_next  = 1'b1      ;
                            write_flag_next = 1'b1      ;
                            bit_ctr_next    = 32'd16    ;
                            state_next      = QSPI_RDSR ;
                            r_qspi_fifo_next= {1'b0, 8'h05,{24{1'b0}}} ;
                        end
                end
                else begin
                    r_qspi_sck_next     = ~r_qspi_sck   ;
                    state_next          =  QSPI_WRITE   ;
                    r_op_cont_next      = in_op_cont    ;
                    if(!r_qspi_sck) begin
                       bit_ctr_next     = bit_ctr - 32'd1           ;
                       r_qspi_fifo_next = {r_qspi_fifo[28:0],4'd0}  ;
                       r_valid_next     = (bit_ctr == 1) ? 1 : 0    ; 
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
            wrr_flag    <= 1'b0             ;
            write_flag  <= 1'b0             ;
            q_rd_flag   <= 1'b0             ;
            
            
            r_spd       <= 1'b0             ;
            r_dir       <= 1'b0             ;
            r_valid     <= 1'b0             ;
            
            r_address   <= 32'd0            ;
            r_out_word  <= 32'd0            ;
            r_op_cont   <= 1'b0             ;    
            
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
            wrr_flag    <= wrr_flag_next    ;
            write_flag  <= write_flag_next  ;
            q_rd_flag   <= q_rd_flag_next   ;
            
            r_dir       <= r_dir_next       ;
            r_spd       <= r_spd_next       ;
            
            r_qspi_cs   <= r_qspi_cs_next   ;
            r_qspi_sck  <= r_qspi_sck_next  ;
            r_qspi_fifo <= r_qspi_fifo_next ;
            
            r_out_word  <= r_out_word_next  ;
            r_valid     <= r_valid_next     ;
            r_op_cont   <= r_op_cont_next   ;
            
            r_address   <= r_address_next   ;
        end
    end
         
    
    
   
    
    
    
    
     
    
endmodule
