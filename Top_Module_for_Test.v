`timescale 1ns / 1ps

`define PRESCALE        32'd5

module Top_Module_for_Test(
input            i_clk, // Sistem frekans�na sahip clock
input            i_reset,          

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
 
 
 wire [31:0]       t_out_word;           
 wire              out_valid ;
 
 wire out_qspi_sck; 
 wire out_busy    ;
 
 (*dont_touch = "true"*) wire out_busy;
 
 (*dont_touch = "true"*)wire in_axisync;
 assign in_axisync = t_state[5];
 
  LLC_AXI LLC(
   .i_clk(i_clk)  ,       
   .i_reset(i_reset),                                                                                                        
   .in_start(in_start),  
   .in_op_cont(1'b0),                                                        
   .in_address(in_address),                                                        
   .in_word(in_word),                                                           
   .in_spd(i_spd),                                                            
   .in_dir(i_dir),
   .in_erase(in_erase),                                                            
   .out_word(t_out_word),                                                          
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
    
 reg [2:0] state_ctr, state_ctr_next; // 000-> erase, 001-> qspi write, 010->  qspi read, 011-> spi write, 100-> spi read  

 
    always@* begin
        clock_ctr_next      = clock_ctr     ;
        i_dir_next          = i_dir     ;
        i_spd_next          = i_spd     ;
        in_start_next       = in_start  ;
        in_address_next     = in_address;
        in_word_next        = in_word   ;
        in_erase_next       = in_erase  ;
        t_state_next        = t_state   ;
        
        state_ctr_next      = state_ctr;
        
        if(clock_ctr > 0) begin
            clock_ctr_next  = clock_ctr - 32'd1 ;
        end
        else if(clock_ctr == 32'd0) begin
            
            
            
            case(t_state)
            
            12'h020: // IDLE
            begin
                
                    clock_ctr_next  = 32'd0         ;
                    t_state_next    = 12'h020       ;
                
                    case(state_ctr)
                    
                    3'b000: begin // erase
                        t_state_next    = 12'h001       ;
                        i_dir_next      = 1'b0          ;
                        i_spd_next      = 1'b0          ;
                        in_start_next   = 1'b1          ;
                        in_erase_next   = 1'b1          ;
                        in_address_next = 24'h00aa00    ;
                        clock_ctr_next  = `PRESCALE - 32'd1 ;
                    end
                    
                    3'b001: begin //  qspi write
                        t_state_next    = 12'h002       ;
                        i_dir_next      = 1'b1          ;
                        i_spd_next      = 1'b1          ;
                        in_start_next   = 1'b1          ;
                        in_erase_next   = 1'b0          ;
                        in_address_next = 24'h00aa00    ;
                        in_word_next    = 32'h33333333  ;
                        clock_ctr_next  = `PRESCALE - 32'd1 ;
                    end
                    
                    3'b010: begin //  qspi read
                        t_state_next    = 12'h004       ;
                        i_dir_next      = 1'b0          ;
                        i_spd_next      = 1'b1          ;
                        in_start_next   = 1'b1          ;
                        in_erase_next   = 1'b0          ;
                        in_address_next = 24'h00aa00    ;
                        clock_ctr_next  = `PRESCALE - 32'd1 ;
                    end
                    
                    3'b011: begin //  spi write
                        t_state_next    = 12'h008       ;
                        i_dir_next      = 1'b1          ;
                        i_spd_next      = 1'b0          ;
                        in_start_next   = 1'b1          ;
                        in_erase_next   = 1'b0          ;
                        in_address_next = 24'h00aa00    ;
                        in_word_next    = 32'hff00ff00  ;
                        clock_ctr_next  = `PRESCALE - 32'd1 ;
                    end
                    
                    3'b100: begin //  spi read
                        t_state_next    = 12'h010       ; 
                        i_dir_next      = 1'b0          ;
                        i_spd_next      = 1'b0          ;
                        in_start_next   = 1'b1          ;
                        in_erase_next   = 1'b0          ;
                        in_address_next = 24'h00aa00    ;
                        clock_ctr_next  = `PRESCALE - 32'd1 ;
                    end
                    endcase 
            end
            
            
            12'h001: // erase,
            begin
                if(out_valid) begin
                    t_state_next    = 12'h020      ; 
                    
                    state_ctr_next = 3'b001;
                end
                else begin
                    t_state_next    = 12'h001     ;
                    clock_ctr_next  = `PRESCALE - 32'd1 ;
                end
            end
            
            12'h002: // qspi write,
            begin
                if(out_valid) begin
                     t_state_next    = 12'h020      ; 
                    
                    state_ctr_next = 3'b010;
                end
                else begin
                    t_state_next    = 12'h002      ;
                    clock_ctr_next  = `PRESCALE - 32'd1 ;
                end
            end
            
            
            12'h004: // qspi read,
            begin       
                if(out_valid) begin
                    t_state_next    = 12'h020      ; 
                    
                    state_ctr_next = 3'b011;
                end
                else begin
                    t_state_next    = 12'h004       ;
                    clock_ctr_next  = `PRESCALE - 32'd1 ;
                end
            end
            
            12'h008: // spi write,
            begin           
                if(out_valid) begin
                    t_state_next    = 12'h020      ; 
                    
                    state_ctr_next = 3'b100;
                end
                else begin
                    t_state_next    = 12'h008      ; 
                    clock_ctr_next  = `PRESCALE - 32'd1 ;
                end
            end
            
            12'h010: // spi read,
            begin          
                if(out_valid) begin
                    t_state_next    = 12'h020      ; 
                    
                    state_ctr_next = 3'b000;
                end
                else begin
                    t_state_next    = 12'h010       ;
                    clock_ctr_next  = `PRESCALE - 32'd1 ;
                end
            end
            
            endcase
        end
    end
    
    always@(posedge i_clk) begin
        if(i_reset) begin
            clock_ctr      <= 32'd0 ;
            i_dir          <= 1'b0  ;
            i_spd          <= 1'b0  ;    
            in_start       <= 1'b0  ;     
            in_address     <= 24'd0 ;  
            in_word        <= 32'd0 ;
            in_erase       <= 1'b0  ;
            t_state        <= 12'h020 ;
            
            state_ctr <= 3'b000;
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
            
            state_ctr <= state_ctr_next;
        end
        
    end
    
    
    
    //always@(posedge i_clk) begin
    //    if(i_reset) begin
    //        counter = 0;
    //        t_state = 12'h001;
    //    end
    //    
    //    else begin
    //    case(t_state) 
    //    
    //    12'h001: // spi write
    //    begin
    //        t_state = 12'h001;
    //        in_start = 1;
    //        in_erase = 0;
    //        i_dir = 0;
    //        i_spd = 1;
    //        in_address = 24'h00b000;
    //        in_op_cont = 0;
    //        in_word = 32'ha5a5a5a5;
    //        if(out_valid && (!out_busy)) begin
    //            counter = counter + 1;
    //            if(counter == 25) begin
    //                t_state = 12'h002; 
    //            end
    //        end    
    //    end
    //    
    //    12'h002: // spi read
    //    begin
    //        t_state = 12'h002;
    //        in_start = 1;
    //        in_erase = 1;
    //        i_dir = 1;
    //        i_spd = 1;
    //        in_address = 24'h00b000; 
    //        in_op_cont = 0;
    //     
    //        if(out_valid && (!out_busy)) begin
    //            counter = counter + 1;
    //            if(counter == 5) begin
    //                t_state = 12'h004; 
    //            end
    //        end   
    //    end
    //    
    //    12'h004: // spi read
    //    begin
    //        t_state = 12'h004;
    //        in_start = 1;
    //        in_erase = 1;
    //        i_dir = 0;
    //        i_spd = 0;
    //        in_address = 24'h00f000;  //
    //        in_op_cont = 0;
    //        in_word = 32'd67;
    //        if(out_valid && (!out_busy)) begin
    //            counter = counter + 1;
    //            if(counter == 5) begin
    //                t_state = 12'h008; 
    //            end
    //        end    
    //    end
    //    
    //    12'h008: // spi read
    //    begin
    //        t_state = 12'h008;
    //        in_start = 1;
    //        in_erase = 0;
    //        i_dir = 1;
    //        i_spd = 0;
    //        in_address = 24'h0aa000;
    //        in_op_cont = 1;
    //        in_word = 32'd67;
    //        
    //        
    //        if(out_valid && (!out_busy)) begin
    //            counter = counter + 1;
    //            if(counter == 15) begin
    //                t_state = 12'h001; 
    //            end
    //        end    
    //    end
    //    
    //    endcase
    //    end
    //end
                                                                 
    
endmodule
