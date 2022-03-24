`timescale 1ns / 1ps


module Top_Module_for_Test(
input            i_clk, // Sistem frekansına sahip clock
input            i_reset,          

// Flash Controller i/o
inout  [3:0]        io_qspi_data,
output              out_qspi_cs

 
    );
    
 reg               i_dir;
 reg               i_spd;
 reg               in_write  ;
 reg               in_op_cont;
 reg [23:0]        in_address;
 reg [31:0]        in_word   ;
 
 
 
 wire [31:0]       t_out_word;           
 wire              out_valid ;
 
 //wire              out_qspi_sck;
 
 reg [31:0] counter;
 reg [11:0] t_state;
 
 wire out_qspi_sck; 
 
 wire out_busy    ;
 reg in_erase;
 
  LLC_AXI a1(
   .i_clk(i_clk)  ,       
   .i_reset(i_reset),                                                           
                                                                      
   .in_write(in_write),  
   .in_op_cont(in_op_cont),                                                        
   .in_address(in_address),                                                        
   .in_word(in_word),                                                           
   .in_spd(i_spd),                                                            
   .in_dir(i_dir),
   .in_erase(in_erase),                                                            
   .out_word(t_out_word),                                                          
   .out_valid(out_valid),                                                                                                                  
   .out_busy(out_busy),                                                                   
   .io_qspi_data(io_qspi_data),                                                      
   .out_qspi_cs(out_qspi_cs),
   .out_qspi_sck(out_qspi_sck)                                                  
  );                                                             
  
  ////*****************************
  //  
	//// The following primitive is necessary in many designs order to gain
	//// access to the o_qspi_sck pin.  It's not necessary on the Arty,
	//// simply because they provide two pins that can drive the QSPI
	//// clock pin.
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
  //  //*****************************
    
    
   
    
    always@(posedge i_clk) begin
        if(i_reset) begin
            counter = 0;
            t_state = 12'h001;
        end
        
        else begin
        case(t_state) 
        
        12'h001: // spi write
        begin
            t_state = 12'h001;
            in_write = 0;
            in_erase = 1;
            i_dir = 1;
            i_spd = 0;
            in_address = 24'h00f000;
            in_op_cont = 0;
            in_word = 32'ha5a5a5a5;
            if(out_valid) begin
                counter = counter + 1;
                if(counter == 5) begin
                    t_state = 12'h002; 
                end
            end    
        end
        
        12'h002: // spi read
        begin
            t_state = 12'h002;
            in_write = 1;
            i_dir = 0;
            i_spd = 1;
            in_address = 24'h00f000; 
            in_op_cont = 0;
         
            if(out_valid) begin
                counter = counter + 1;
                if(counter == 5) begin
                    t_state = 12'h004; 
                end
            end   
        end
        
        12'h004: // spi read
        begin
            t_state = 12'h004;
            in_write = 1;
            i_dir = 0;
            i_spd = 0;
            in_address = 24'h00f000;  //
            in_op_cont = 0;
            in_word = 32'd67;
            if(out_valid) begin
                counter = counter + 1;
                if(counter == 5) begin
                    t_state = 12'h008; 
                end
            end    
        end
        
        12'h008: // spi read
        begin
            t_state = 12'h008;
            in_write = 1;
            i_dir = 1;
            i_spd = 1;
            in_address = 24'h0aa000;
            in_op_cont = 1;
            in_word = 32'd67;
            
            
            if(out_valid) begin
                counter = counter + 1;
                if(counter == 15) begin
                    t_state = 12'h001; 
                end
            end    
        end
        
        endcase
        end
    end
                                                                 
    
endmodule
