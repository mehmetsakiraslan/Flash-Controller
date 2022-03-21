# Clock signal
set_property PACKAGE_PIN W5 [get_ports i_clk]
set_property IOSTANDARD LVCMOS33 [get_ports i_clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports i_clk]


create_generated_clock -name cclk -source [get_pins STARTUPE2_inst/USRCCLKO] -combinational [get_pins STARTUPE2_inst/USRCCLKO]

# Switches
set_property PACKAGE_PIN W17 [get_ports i_reset]
set_property IOSTANDARD LVCMOS33 [get_ports i_reset]
##set_property PACKAGE_PIN V16 [get_ports i_dir]
##set_property IOSTANDARD LVCMOS33 [get_ports i_dir]
##set_property PACKAGE_PIN V17 [get_ports i_spd]
##set_property IOSTANDARD LVCMOS33 [get_ports i_spd]

##Quad SPI Flash
##Note that CCLK_0 cannot be placed in 7 series devices. You can access it using the
##STARTUPE2 primitive.
set_property PACKAGE_PIN D18 [get_ports {io_qspi_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_qspi_data[0]}]
set_property PACKAGE_PIN D19 [get_ports {io_qspi_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_qspi_data[1]}]
set_property PACKAGE_PIN G18 [get_ports {io_qspi_data[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_qspi_data[2]}]
set_property PACKAGE_PIN F18 [get_ports {io_qspi_data[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_qspi_data[3]}]
set_property PACKAGE_PIN K19 [get_ports out_qspi_cs]
set_property IOSTANDARD LVCMOS33 [get_ports out_qspi_cs]


##########************************************************************************************************
#clock
##set_property LOC H9  [get_ports { i_clk }]
##set_property LOC G9  [get_ports { i_clk }]
##set_property IOSTANDARD DIFF_SSTL15 [get_ports { i_clk }]
##create_clock -name sys_clk -period 5 [get_ports i_clk]


#  Quad SPI Flash / qspi0_sclk / MIO[6]
#set_property iostandard "LVCMOS18" [get_ports out_qspi_sck]
#set_property PACKAGE_PIN "D24" [get_ports out_qspi_sck]
#set_property slew "slow" [get_ports out_qspi_sck]
#set_property drive "8" [get_ports out_qspi_sck]
#set_property PIO_DIRECTION "OUTPUT" [get_ports out_qspi_sck]

##set_property iostandard LVCMOS18 [get_ports out_qspi_sck]
##set_property PACKAGE_PIN D24 [get_ports out_qspi_sck]
##set_property slew slow [get_ports out_qspi_sck]
##set_property drive 8 [get_ports out_qspi_sck]
##set_property PIO_DIRECTION INPUT [get_ports out_qspi_sck]
###  Quad SPI Flash / qspi0_io[3] / MIO[5]
##set_property iostandard LVCMOS18 [get_ports {io_qspi_data[3]}]
##set_property PACKAGE_PIN "C24" [get_ports {io_qspi_data[3]}]
##set_property slew "slow" [get_ports {io_qspi_data[3]}]
##set_property drive "8" [get_ports {io_qspi_data[3]}]
##set_property PIO_DIRECTION "BIDIR" [get_ports {io_qspi_data[3]}]
##
###  Quad SPI Flash / qspi0_io[2] / MIO[4]
##set_property iostandard LVCMOS18 [get_ports {io_qspi_data[2]}]
##set_property PACKAGE_PIN "E23" [get_ports {io_qspi_data[2]}]
##set_property slew "slow" [get_ports {io_qspi_data[2]}]
##set_property drive "8" [get_ports {io_qspi_data[2]}]
##set_property PIO_DIRECTION "BIDIR" [get_ports {io_qspi_data[2]}]
##
###  Quad SPI Flash / qspi0_io[1] / MIO[3]
##set_property iostandard LVCMOS18 [get_ports {io_qspi_data[1]}]
##set_property PACKAGE_PIN "C23" [get_ports {io_qspi_data[1]}]
##set_property slew "slow" [get_ports {io_qspi_data[1]}]
##set_property drive "8" [get_ports {io_qspi_data[1]}]
##set_property PIO_DIRECTION "BIDIR" [get_ports {io_qspi_data[1]}]
##
###  Quad SPI Flash / qspi0_io[0] / MIO[2]
##set_property iostandard LVCMOS18 [get_ports {io_qspi_data[0]}]
##set_property PACKAGE_PIN "F23" [get_ports {io_qspi_data[0]}]
##set_property slew "slow" [get_ports {io_qspi_data[0]}]
##set_property drive "8" [get_ports {io_qspi_data[0]}]
##set_property PIO_DIRECTION "BIDIR" [get_ports {io_qspi_data[0]}]
##
###  Quad SPI Flash / qspi0_ss_b / MIO[1]
##set_property iostandard LVCMOS18 [get_ports out_qspi_cs]
##set_property PACKAGE_PIN "D23" [get_ports out_qspi_cs]
##set_property slew "slow" [get_ports out_qspi_cs]
##set_property drive "8" [get_ports out_qspi_cs]
##set_property pullup "TRUE" [get_ports out_qspi_cs]
##set_property PIO_DIRECTION "OUTPUT" [get_ports out_qspi_cs]



#######################################################################










create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 32768 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list i_clk_IBUF_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 4 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {a1/io_qspi_data_IBUF[0]} {a1/io_qspi_data_IBUF[1]} {a1/io_qspi_data_IBUF[2]} {a1/io_qspi_data_IBUF[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 8 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {a1/r_qspi_fifo[0]} {a1/r_qspi_fifo[1]} {a1/r_qspi_fifo[2]} {a1/r_qspi_fifo[3]} {a1/r_qspi_fifo[4]} {a1/r_qspi_fifo[5]} {a1/r_qspi_fifo[6]} {a1/r_qspi_fifo[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 11 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {a1/state[0]} {a1/state[1]} {a1/state[2]} {a1/state[3]} {a1/state[4]} {a1/state[5]} {a1/state[6]} {a1/state[7]} {a1/state[8]} {a1/state[9]} {a1/state[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 4 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {a1/io_qspi_data_OBUF[0]} {a1/io_qspi_data_OBUF[1]} {a1/io_qspi_data_OBUF[2]} {a1/io_qspi_data_OBUF[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list out_qspi_cs_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list out_qspi_sck]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list a1/r_dir]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list a1/r_spd]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets i_clk_IBUF_BUFG]
