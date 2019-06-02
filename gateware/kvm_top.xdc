#HDMI RX
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports hdmi_rx_hpd]
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports hdmi_rx_scl]
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS33} [get_ports hdmi_rx_sda]
set_property -dict {PACKAGE_PIN W20 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_n[0]}]
set_property -dict {PACKAGE_PIN V20 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_p[0]}]
set_property -dict {PACKAGE_PIN U20 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_n[1]}]
set_property -dict {PACKAGE_PIN T20 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_p[1]}]
set_property -dict {PACKAGE_PIN P20 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_n[2]}]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_p[2]}]
set_property -dict {PACKAGE_PIN U19 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_n[3]}]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD TMDS_33} [get_ports {hdmi_rx_p[3]}]

#RGB LED 6
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {rgb_led[2]}]
set_property -dict {PACKAGE_PIN F17 IOSTANDARD LVCMOS33} [get_ports {rgb_led[1]}]
set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVCMOS33} [get_ports {rgb_led[0]}]

#HDMI RX Clock, maximum 100 MHz
create_clock -period 10.000 -name hdmi_rx_clk -waveform {0.000 5.000} [get_ports {hdmi_rx_p[3]}]

# 1 encoder per clock region, spaced out to add debug logic
# set_property LOC BUFHCE_X0Y9  [get_cells {video_capture_hdmi_inst/video_capture_inst/striped_encoders_inst/gen_encoders[0].buffered_encoder_inst/jpeg_enc_ce_inst/gated_clk_buffer}]
# set_property LOC BUFHCE_X1Y9  [get_cells {video_capture_hdmi_inst/video_capture_inst/striped_encoders_inst/gen_encoders[2].buffered_encoder_inst/jpeg_enc_ce_inst/gated_clk_buffer}]
# set_property LOC BUFHCE_X1Y14 [get_cells {video_capture_hdmi_inst/video_capture_inst/striped_encoders_inst/gen_encoders[1].buffered_encoder_inst/jpeg_enc_ce_inst/gated_clk_buffer}]
# set_property LOC BUFHCE_X1Y26 [get_cells {video_capture_hdmi_inst/video_capture_inst/striped_encoders_inst/gen_encoders[3].buffered_encoder_inst/jpeg_enc_ce_inst/gated_clk_buffer}]

# 2 encoders per clock region, crammed for when debug logic is removed
set_property LOC BUFHCE_X1Y14 [get_cells {video_capture_hdmi_inst/video_capture_inst/striped_encoders_inst/gen_encoders[0].buffered_encoder_inst/jpeg_enc_ce_inst/gated_clk_buffer}]
set_property LOC BUFHCE_X1Y21 [get_cells {video_capture_hdmi_inst/video_capture_inst/striped_encoders_inst/gen_encoders[2].buffered_encoder_inst/jpeg_enc_ce_inst/gated_clk_buffer}]
set_property LOC BUFHCE_X1Y26 [get_cells {video_capture_hdmi_inst/video_capture_inst/striped_encoders_inst/gen_encoders[1].buffered_encoder_inst/jpeg_enc_ce_inst/gated_clk_buffer}]
set_property LOC BUFHCE_X1Y33 [get_cells {video_capture_hdmi_inst/video_capture_inst/striped_encoders_inst/gen_encoders[3].buffered_encoder_inst/jpeg_enc_ce_inst/gated_clk_buffer}]

set_max_delay -datapath_only -from [get_clocks clk_fpga_0] -to [get_clocks -of_objects [get_pins video_capture_hdmi_inst/hdmi_rx_inst/dvi2rgb_inst/TMDS_ClockingX/PixelClkBuffer/O]] 7.0
set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins video_capture_hdmi_inst/hdmi_rx_inst/dvi2rgb_inst/TMDS_ClockingX/PixelClkBuffer/O]] -to [get_clocks clk_fpga_0] 7.0
set_max_delay -datapath_only -from [get_clocks clk_fpga_1] -to [get_clocks -of_objects [get_pins video_capture_hdmi_inst/hdmi_rx_inst/dvi2rgb_inst/TMDS_ClockingX/PixelClkBuffer/O]] 5.0
set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins video_capture_hdmi_inst/hdmi_rx_inst/dvi2rgb_inst/TMDS_ClockingX/PixelClkBuffer/O]] -to [get_clocks clk_fpga_1] 5.0
set_max_delay -datapath_only -from [get_clocks clk_fpga_1] -to [get_clocks clk_fpga_0] 5.0
set_max_delay -datapath_only -from [get_clocks clk_fpga_0] -to [get_clocks clk_fpga_1] 5.0
