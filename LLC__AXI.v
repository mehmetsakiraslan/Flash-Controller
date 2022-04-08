`timescale 1ns / 1ps

`define DUMMY_CYCLE     4'd8
`define ADDRESS_SIZE    5'd24

 
module LLC_AXI(
input               i_clk,          // Sistem frekans�na sahip clock
input               i_reset,

// �st seviye cihaza ba�l� kontrol sinyalleri
input                in_start,       // �letimin ba�layaca��n� g�sterir
input                in_op_cont,     // ��lemin devam etti�ini g�sterir 
input  [23:0]        in_address,  
input  [31:0]        in_word,        // Write modda flasha yaz�lacak veri 
input                in_spd,         // 0 -> SPI, 1 -> QSPI
input                in_dir,         // 0 -> read, 1 -> write
input                in_erase,       
output [31:0]        out_word,       // Read modda flashtan okunan veri
output               out_valid,
(*dont_touch = "true"*)output               out_busy,

// Flash Cihaz�na Ba�l� Giri�/��k��lar
inout  [3:0]        io_qspi_data,
output              out_qspi_cs,   // When driven low, places device in active power mode. 
output              out_qspi_sck,  // On rising edge: Latches commands, addresses, and data on SI, On falling edge: Triggers output on SO 
input [31:0]        in_clock_ctr
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
    QSPI_RDSR	=16'h0200      ,
    QSPI_START  =16'h0400        ;
      
    // QSPI cihazina bagli shift register
    reg [35:0]  r_qspi_fifo, r_qspi_fifo_next   ;

    // Giris registerlari
    reg         r_spd, r_spd_next           ;   
    reg         r_dir, r_dir_next           ;
    reg         r_spd_v, r_spd_nv           ;
    reg         r_valid, r_valid_next       ;
    reg         r_dir_v, r_dir_nv           ; 
    reg [23:0]  r_address, r_address_next   ; 
    
   assign      io_qspi_data = (!r_spd) ? ({2'b11,1'bZ,r_qspi_fifo[32]})                  
                                           : (r_dir ? {(r_qspi_fifo[35:32])}:{(4'bZZZZ)} )  ;// dir==0 -> okuma, spd==0 -> spi     
   
   assign       out_valid   = r_valid       ;
                                       
    // Cikis Registerlari
    reg [31:0]  r_out_word, r_out_word_next ;
    
    reg         r_qspi_cs , r_qspi_cs_next  ; 
    reg         r_qspi_sck, r_qspi_sck_next ;
    reg         r_qspi_sr, r_qspi_sr_next   ;   // 1 i_clk cycle retarted sck to prevent race conditions while driving slave device,
                                                // would not work if prescale is 1.
    assign      out_qspi_cs = r_qspi_cs     ;
    assign      out_qspi_sck= r_qspi_sr     ;     
            
    // Kontrol Sinyalleri
    reg [31:0]  bit_ctr  , bit_ctr_next     ;  
(*dont_touch = "true"*)    reg [15:0]  state;
(*dont_touch = "true"*)    reg [15:0]  state_next                  ;           
    reg         erase_flag, erase_flag_next ;
    reg         write_flag, write_flag_next ;
    reg         wrr_flag, wrr_flag_next     ;
    reg         r_op_cont, r_op_cont_next   ;
    reg         q_rd_flag, q_rd_flag_next   ;
    
    reg         startup_sequence,startup_sequence_next;
    
    
    assign      out_word        = r_out_word    ;    
    assign      out_busy        = ~state[0]     ;
                
    always@* begin
        bit_ctr_next        = bit_ctr       ;      
        state_next          = state         ;
      
        r_qspi_fifo_next    = r_qspi_fifo   ;
        r_qspi_sck_next     = r_qspi_sck    ;
        r_qspi_cs_next      = r_qspi_cs     ;
        
        r_dir_next          = r_dir         ;
        r_spd_next          = r_spd         ;
        
        r_dir_nv            = r_dir_v       ;
        r_spd_nv            = r_spd_v       ;
      
        r_out_word_next     = r_out_word    ;
        r_address_next      = r_address     ;
        r_op_cont_next      = r_op_cont     ;
        r_valid_next        = r_valid       ;
        
        startup_sequence_next = startup_sequence;
        
        wrr_flag_next       = wrr_flag      ;
        write_flag_next     = write_flag    ;
        erase_flag_next     = erase_flag    ;
        q_rd_flag_next      = q_rd_flag     ;
        
        r_qspi_sr_next  = r_qspi_sck        ;
        
        
        
        if(in_clock_ctr == 32'd0) begin
             
            
            case(state)
            
            QSPI_START:
            begin
                    if(bit_ctr == 32'd0) begin
                        state_next = IDLE;
                       
                        startup_sequence_next = 1'b0;
                        r_qspi_cs_next  = 1'b1;
                    end
                    else begin
                        
                        state_next = QSPI_START;
                        if(bit_ctr == 501) begin
                             bit_ctr_next   = bit_ctr - 32'd1   ;
                             r_qspi_cs_next = 1'b0              ;          
                        end
                        
                        else if(bit_ctr > 452) begin
                            r_qspi_sck_next     = ~r_qspi_sck   ;
                            if(!r_qspi_sck) begin    
                                bit_ctr_next        = bit_ctr - 32'd1           ;
                                r_qspi_fifo_next    = {r_qspi_fifo[34:0],1'b0}  ;    
                            end
                        end
                        else if(bit_ctr > 400) begin
                            r_qspi_sck_next     = ~r_qspi_sck               ;
                            bit_ctr_next        = bit_ctr - 32'd1           ;
                            r_qspi_fifo_next    = {4'b0, 8'h06,24'h000000}  ;
                            r_qspi_cs_next      = (bit_ctr == 32'd452) ? 1'b1 : 1'b0; 
                        end
                        else if(bit_ctr > 392) begin
                            r_qspi_sck_next     = ~r_qspi_sck   ;
                            if(!r_qspi_sck) begin    
                                bit_ctr_next        = bit_ctr - 32'd1           ;
                                r_qspi_fifo_next    = {r_qspi_fifo[34:0],1'b0}  ;    
                            end
                        end
                        
                        else begin
                            bit_ctr_next        = bit_ctr - 32'd1;
                            r_qspi_fifo_next    = {36{1'b0}}    ;
                            r_qspi_cs_next      = 1'b1          ;
                            r_qspi_sck_next     = 1'b0          ;
                        end
                    end
            end
            
            IDLE: 
            begin
                if(startup_sequence && (!i_reset)) begin
                    state_next  = QSPI_START                ; 
                    bit_ctr_next= 32'd501                   ;
                    r_qspi_fifo_next= {4'b0, 8'h90,24'h000000} ;
                end
                else begin
                    
                    if((in_start)) begin //
                        r_spd_next      = 1'b0              ;
                        r_dir_next      = 1'b0              ;
                        r_spd_nv        = in_spd            ;
                        r_dir_nv        = in_dir            ;
                        r_address_next  = in_address        ;
                        r_qspi_cs_next  = 1'b0              ;
                        r_valid_next    = 1'b0              ; 
                        r_op_cont_next  = in_op_cont        ; 
                        r_qspi_sck_next = 1'b0              ; 
                        
                        if(in_erase) begin                                  //  WREN -> ERASE -> RDSR 
                            bit_ctr_next    = 32'd8         ;
                            state_next      = QSPI_WREN     ;   
                            r_qspi_fifo_next= { 4'b0, 8'h06,{24{1'b0}}} ;
                            erase_flag_next = 1'b1          ; 
                        end
                        else if(in_spd) begin // Qspi write
                            bit_ctr_next    = 32'd8         ;               // QSPI READ mode  || WREN -> WRR -> RDSR -> SEND CMD -> QSPI READ
                            state_next      = QSPI_WREN     ;               // QSPI WRITE mode || WREN -> WRR -> RDSR -> WREN-> SEND CMD -> QSPI WRITE -> RDSR
                            r_qspi_fifo_next= { 4'b0, 8'h06,{24{1'b0}}} ; 
                        end
                        else if(!in_spd && in_dir) begin                    // Spi write || WREN -> SEND CMD -> WRITE -> RDSR
                            state_next      = QSPI_WREN ;
                            write_flag_next = 1'b1      ;
                            r_qspi_fifo_next= {4'b0, 8'h06,{24{1'b0}}} ;
                            bit_ctr_next    = 32'd8     ; 
                        end
                        else begin                                          // Spi read  || SEND CMD -> SPI READ 
                            state_next      = SEND_CMD      ;       
                            bit_ctr_next    = 32'd32        ;
                            r_qspi_fifo_next= {4'b0, 8'h03,r_address_next}; 
                        end 
                    end
                    else begin
                        state_next      = IDLE          ;    
                        r_qspi_cs_next  = 1'b1          ;
                        r_valid_next    = 1'b0          ; 
                    end
                end
            end
            
            SEND_CMD:
            begin
                if( bit_ctr == 32'd0) begin
                    r_qspi_sck_next = 1'b0          ;
                    r_qspi_cs_next  = 1'b0          ;
                    r_spd_next      = r_spd_v      ;
                    r_dir_next      = r_dir_v      ; 
                    // Diger degiskenleri ekle
                    if((r_dir_v == 1'b0) && (r_spd_v == 1'b0)) begin 
                        bit_ctr_next    = 32'd32    ;
                        state_next      = SPI_READ  ;
                    end
                    else if((r_dir_v == 1'b0) && (r_spd_v == 1'b1)) begin   
                        bit_ctr_next    = 32'd16    ;   // dummy + 8 cycles
                        state_next      = QSPI_READ ;                     
                    end
                    else if((r_dir_v == 1'b1) && (r_spd_v == 1'b0)) begin
                        bit_ctr_next    = 32'd32    ;   
                        state_next      = SPI_WRITE ;
                        r_qspi_fifo_next= in_word   ;
                    end
                    else if((r_dir_v == 1'b1) && (r_spd_v == 1'b1)) begin
                        bit_ctr_next    = 32'd8     ;   
                        state_next      = QSPI_WRITE;
                        r_qspi_fifo_next= in_word   ;
                    end
                end
                else begin
                    r_qspi_sck_next     = ~r_qspi_sck   ;
                    r_dir_next          = 1'b0          ;
                    r_spd_next          = 1'b0          ;
                    state_next          = SEND_CMD                  ;
                    if(!r_qspi_sck) begin    
                        bit_ctr_next        = bit_ctr - 32'd1       ;
                        r_qspi_fifo_next    = {r_qspi_fifo[34:0],1'b0}  ;    
                    end
                end
            end
            
            SPI_READ:   // 9.1
            begin
                if(bit_ctr == 32'd0) begin
                    r_out_word_next = r_qspi_fifo[31:0] ;
                    if(in_op_cont) begin
                        state_next      = SPI_READ      ;
                        r_qspi_cs_next  = 1'b0          ;
                        bit_ctr_next    = 32'd32        ;
                        r_qspi_sck_next = ~r_qspi_sck   ;
                    end
                    else begin
                        state_next      = IDLE          ;
                        r_qspi_cs_next  = 1'b1          ;   // transaction ends
                        r_valid_next    = 1'b1          ;   // same logic if in_op_cont == 0;
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
                        r_qspi_fifo_next= {r_qspi_fifo[34:0], io_qspi_data[1]}  ; // bitler fifoya kaydediliyor. // SO -> io_qspi_data[1]
                    end         
                end
            end
            
            QSPI_READ:  // 9.4
            begin
                if(bit_ctr == 32'd0) begin
                    r_out_word_next = r_qspi_fifo[31:0] ; 
                    if(in_op_cont) begin
                        state_next      = QSPI_READ     ;
                        r_qspi_cs_next  = 1'b0          ;
                        bit_ctr_next    = 32'd8         ;
                    end
                    else begin
                        if(r_valid) begin
                            r_qspi_sck_next = 1'b0          ; 
                            r_qspi_cs_next  = 1'b1          ;
                            r_valid_next    = 1'b0          ; 
                            state_next      = IDLE          ;
                            r_dir_next      = 1'b0          ;
                            r_spd_next      = 1'b0          ;
                        end
                        else begin
                            r_valid_next    = 1'b1      ;
                        end
                    end
                    
                end           
                else begin
                    r_qspi_sck_next = ~r_qspi_sck       ;
                    state_next      =  QSPI_READ        ;
                    r_op_cont_next  = in_op_cont        ;
                    if(!r_qspi_sck) begin
                        bit_ctr_next    = bit_ctr - 32'd1;
                        if(bit_ctr <= 8) begin // 8 cycle dummy 
                            r_qspi_fifo_next= {r_qspi_fifo[31:0], io_qspi_data[3:0]};
                        end
                    end  
                end
            end
            
            QSPI_WREN:  // 9.9: yazma islemlerinden once yapilmali
            begin
                if(bit_ctr == 32'd0) begin
                    r_qspi_sck_next = 1'b0              ;
                    if(r_qspi_cs) begin         
                        r_qspi_cs_next  = 1'b0              ;      
                        if(erase_flag) begin
                            erase_flag_next = 1'b0          ;
                            state_next      =  QSPI_ERASE   ;
                            bit_ctr_next    = in_dir ? 8:32 ;
                            r_qspi_fifo_next= {4'b0, in_dir ? 8'hc7 : 8'h20, r_address}; // bulk erase yapiyormu dene
                        end
                        else if(write_flag) begin
                            write_flag_next = 1'b0              ;
                            state_next      = SEND_CMD          ;
                            bit_ctr_next    = 32'd32            ;
                            r_qspi_fifo_next= {4'b0, r_spd_v ? 8'h32 : 8'h02, r_address};    /////gereklimi?     
                        end
                        else begin
                            state_next      =  QSPI_WRR ;
                            bit_ctr_next    =  32'd24   ;  
                            r_qspi_fifo_next= {4'b0, 8'h01, 16'b0000_0010_0000_0010, {8{1'b0}}}    ;   // yanlis olabilir 
                        end           
                    end
                    else begin
                        r_qspi_cs_next  = 1'b1;
                        state_next      = QSPI_WREN;
                    end
                end
                else begin ///// 1 ms delay ekle
                    state_next      =  QSPI_WREN    ; 
                    r_qspi_sck_next = ~r_qspi_sck   ;  
                    if(!r_qspi_sck) begin
                        bit_ctr_next    = bit_ctr - 32'd1       ;
                        r_qspi_fifo_next= {r_qspi_fifo[34:0],1'b0};   
                    end
                end
            end
            
            QSPI_WRR:   // 9.13
            begin
                if(bit_ctr == 32'd0) begin
                    r_qspi_sck_next = 1'b0          ;
                    if(r_qspi_cs) begin
                        if(r_dir_v)begin 
                            wrr_flag_next   = 1'b1  ; // Quad Write  
                        end
                        else begin
                            q_rd_flag_next  = 1'b1  ; // Quad Read
                        end
                        r_qspi_cs_next  = 1'b0      ;
                        bit_ctr_next    = 32'd16    ;   
                        state_next      = QSPI_RDSR ;
                        r_qspi_fifo_next= {4'b0,8'h05,{24{1'b0}}} ;  // rdsr command
                    end
                    else begin
                        state_next      = QSPI_WRR  ;
                        r_qspi_cs_next  = 1'b1      ;
                    end       
                end
                else begin
                    state_next      =  QSPI_WRR     ; 
                    r_qspi_sck_next = ~r_qspi_sck   ;
                    if(!r_qspi_sck) begin
                        bit_ctr_next    = bit_ctr - 32'd1         ;
                        r_qspi_fifo_next= {r_qspi_fifo[34:0],1'b0};   
                    end
                end
            end
            
            QSPI_RDSR:  // 9.11
            begin
                if(bit_ctr == 32'd0) begin 
                    if(r_qspi_fifo[0] == 1'b0) begin
                            r_qspi_sck_next = 1'b0          ;
                            if(r_qspi_cs) begin
                                r_qspi_cs_next  = 1'b0          ;
                                r_qspi_sck_next = 1'b0          ;
                                r_valid_next    = 1'b0          ; 
                                if(wrr_flag) begin // wrr isleminden sonra, QSPI write
                                    wrr_flag_next   = 1'b0      ;
                                    state_next      = QSPI_WREN ;
                                    write_flag_next = 1'b1      ;
                                    r_qspi_fifo_next= {4'b0, 8'h06,{24{1'b0}}} ;
                                    bit_ctr_next    = 32'd8     ;  
                                end     
                                else if(write_flag) begin // QSPI_WRITE isleminden sonra
                                    write_flag_next = 1'b0      ;
                                    state_next      =  IDLE     ;   
                                    r_qspi_cs_next  = 1'b1      ;
                                end
                                else if(erase_flag) begin  // erase isleminden sonra IDLE'a geri done
                                    erase_flag_next = 1'b0      ;
 
                                    state_next      = IDLE      ;
                                    r_qspi_cs_next  = 1'b1      ;
                                end
                                else if(q_rd_flag) begin
                                    q_rd_flag_next  = 1'b0          ;
                                    state_next      = SEND_CMD      ; 
                                    r_qspi_sck_next = 1'b0          ;       
                                    bit_ctr_next    = 32'd32        ;
                                    r_qspi_fifo_next= {4'b0, 8'h6b, r_address_next};  
                                end
                            end
                            else begin
                                r_qspi_cs_next  = 1'b1;
                                state_next      = QSPI_RDSR;
                                if(erase_flag || write_flag) begin
                                    r_valid_next    = 1'b1      ;
                                end
                            end
                    end
                    else begin // eger 0 degilse okumaya devam et      //////// cal�s�yormu kontrol et
                        r_qspi_sck_next = 1'b0              ;
                        state_next      = QSPI_RDSR         ;
                        r_qspi_fifo_next= {r_qspi_fifo[35:16],16'd0} ;
                        bit_ctr_next    = 32'd8             ;      
                    end
                end
                else begin
                    r_qspi_sck_next = ~r_qspi_sck   ;
                    state_next      =  QSPI_RDSR    ; 
                    if((!r_qspi_sck) && (bit_ctr > 8)) begin
                        bit_ctr_next    = bit_ctr - 32'd1       ;
                        r_qspi_fifo_next= {r_qspi_fifo[34:0],1'b0};
                    end
                    else if((!r_qspi_sck) && (bit_ctr <= 8)) begin
                        r_qspi_fifo_next  = {r_qspi_fifo[34:0], io_qspi_data[1]} ; // r_qspi_fifo ile yap
                        bit_ctr_next        = bit_ctr - 32'd1                    ;  
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
                        r_qspi_fifo_next= {4'b0, 8'h05,{24{1'b0}}} ;  // rdsr command   
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
                        r_qspi_fifo_next= {r_qspi_fifo[34:0],1'b0};
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
                        if(r_qspi_cs) begin
                            r_qspi_cs_next  = 1'b0      ;
                            
                            write_flag_next = 1'b1      ;
                            bit_ctr_next    = 32'd16    ;
                            state_next      = QSPI_RDSR ;
                            r_qspi_fifo_next= {4'b0, 8'h05,{24{1'b0}}} ;
                        end
                        else begin
                            r_dir_next      = 1'b0      ;
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
                       r_qspi_fifo_next = {r_qspi_fifo[34:0],1'b0}  ;
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
                            if(r_qspi_cs) begin
                                r_qspi_cs_next  = 1'b0      ;
                                 
                                write_flag_next = 1'b1      ;
                                bit_ctr_next    = 32'd16    ;
                                state_next      = QSPI_RDSR ;
                                r_qspi_fifo_next= {4'b0, 8'h05,{24{1'b0}}} ;
                            end
                            else begin
                                r_dir_next      = 1'b0      ;
                                r_spd_next      = 1'b0      ;
                                r_qspi_cs_next  = 1'b1      ;
                                
                                state_next      = QSPI_WRITE;
                            end
                        end
                end
                else begin
                    r_qspi_sck_next     = ~r_qspi_sck   ;
                    state_next          =  QSPI_WRITE   ;
                    r_op_cont_next      = in_op_cont    ;
                    if(!r_qspi_sck) begin
                       bit_ctr_next     = bit_ctr - 32'd1           ;
                       r_qspi_fifo_next = {r_qspi_fifo[31:0],4'd0}  ;
                    end 
                end
            end
            endcase
        end      
    end
    
    always@(posedge i_clk) begin
        if(i_reset) begin
            
            bit_ctr     <= 32'd0            ;
            state       <= IDLE             ;
            
            erase_flag  <= 1'b0             ;
            wrr_flag    <= 1'b0             ;
            write_flag  <= 1'b0             ;
            q_rd_flag   <= 1'b0             ;
            
            startup_sequence <= 1'b1        ;
            
            r_spd       <= 1'b0             ;
            r_dir       <= 1'b0             ;
            
            r_address   <= 32'd0            ;
            r_out_word  <= 32'd0            ;
            r_op_cont   <= 1'b0             ;
            r_valid     <= 1'b0             ;     
            
            r_qspi_cs   <= 1'b1             ;
            r_qspi_sck  <= 1'b0             ;
            r_qspi_fifo <= 36'd0            ;  
            
            r_qspi_sr <= 1'b0               ;
            
            r_dir_v <= 1'b0                 ;
            r_spd_v <= 1'b0                 ;
        end
        else begin
            
            bit_ctr     <= bit_ctr_next     ;
            state       <=  state_next      ;
            
            erase_flag  <= erase_flag_next  ;
            write_flag  <= write_flag_next  ;
            wrr_flag    <= wrr_flag_next    ;
            q_rd_flag   <= q_rd_flag_next   ;
            
            startup_sequence <= startup_sequence_next;
            
            r_dir       <= r_dir_next       ;
            r_spd       <= r_spd_next       ;
            
            r_qspi_cs   <= r_qspi_cs_next   ;
            r_qspi_sck  <= r_qspi_sck_next  ;
            
            
            r_out_word  <= r_out_word_next  ;
            r_op_cont   <= r_op_cont_next   ;
            r_valid     <= r_valid_next     ; 
            
            r_qspi_fifo <= r_qspi_fifo_next ;
            
            r_address   <= r_address_next   ;
            
            r_qspi_sr   <= r_qspi_sr_next   ;
            
            r_dir_v <= r_dir_nv             ;
            r_spd_v <= r_spd_nv             ;
            
        end
    end
    
endmodule
