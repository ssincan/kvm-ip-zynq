create_project zybo_z7_kvm ./zybo_z7_kvm -part xc7z020clg400-1
set_property board_part digilentinc.com:zybo-z7-20:part0:1.0 [current_project]
set_property target_language VHDL [current_project]
set_property default_lib work [current_project]

create_bd_design "zynq_ps"
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]
set_property -dict [list CONFIG.PCW_USE_M_AXI_GP1 {1} CONFIG.PCW_USE_S_AXI_HP0 {1} CONFIG.PCW_USE_S_AXI_HP1 {1} CONFIG.PCW_USE_S_AXI_HP2 {1} CONFIG.PCW_USE_S_AXI_HP3 {1} CONFIG.PCW_TTC0_PERIPHERAL_ENABLE {1} CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {142.857} CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {200} CONFIG.PCW_EN_CLK1_PORT {1} CONFIG.PCW_EN_RST1_PORT {1}] [get_bd_cells processing_system7_0]
make_bd_pins_external -name REF_CLK [get_bd_pins processing_system7_0/FCLK_CLK1]
make_bd_pins_external -name ACLK [get_bd_pins processing_system7_0/FCLK_CLK0]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0
connect_bd_net [get_bd_pins proc_sys_reset_0/ext_reset_in] [get_bd_pins processing_system7_0/FCLK_RESET0_N]
connect_bd_net [get_bd_pins proc_sys_reset_0/slowest_sync_clk] [get_bd_ports ACLK]
connect_bd_net [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK] [get_bd_ports ACLK]
connect_bd_net [get_bd_pins processing_system7_0/M_AXI_GP1_ACLK] [get_bd_ports ACLK]
connect_bd_net [get_bd_pins processing_system7_0/S_AXI_HP0_ACLK] [get_bd_ports ACLK]
connect_bd_net [get_bd_pins processing_system7_0/S_AXI_HP1_ACLK] [get_bd_ports ACLK]
connect_bd_net [get_bd_pins processing_system7_0/S_AXI_HP2_ACLK] [get_bd_ports ACLK]
connect_bd_net [get_bd_pins processing_system7_0/S_AXI_HP3_ACLK] [get_bd_ports ACLK]

create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 ref_rst_inv
set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not} CONFIG.LOGO_FILE {data/sym_notgate.png}] [get_bd_cells ref_rst_inv]
connect_bd_net [get_bd_pins ref_rst_inv/Op1] [get_bd_pins processing_system7_0/FCLK_RESET1_N]
create_bd_port -dir O -from 0 -to 0 -type rst REF_RST
connect_bd_net [get_bd_ports REF_RST] [get_bd_pins ref_rst_inv/Res]
set_property CONFIG.ASSOCIATED_RESET {REF_RST} [get_bd_ports /REF_CLK]

make_bd_pins_external -name ARESET [get_bd_pins proc_sys_reset_0/peripheral_reset]
set_property CONFIG.ASSOCIATED_RESET {ARESET} [get_bd_ports /ACLK]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_protocol_converter:2.1 axi_proto_conv_reg0
connect_bd_net [get_bd_pins axi_proto_conv_reg0/aclk] [get_bd_ports ACLK]
connect_bd_net [get_bd_pins axi_proto_conv_reg0/aresetn] [get_bd_pins proc_sys_reset_0/interconnect_aresetn]
connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] [get_bd_intf_pins axi_proto_conv_reg0/S_AXI]
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI_REG0
set_property -dict [list CONFIG.PROTOCOL {AXI4LITE}] [get_bd_intf_ports M_AXI_REG0]
connect_bd_intf_net [get_bd_intf_ports M_AXI_REG0] [get_bd_intf_pins axi_proto_conv_reg0/M_AXI]
set_property CONFIG.ASSOCIATED_BUSIF {M_AXI_REG0} [get_bd_ports /ACLK]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_protocol_converter:2.1 axi_proto_conv_reg1
connect_bd_net [get_bd_pins axi_proto_conv_reg1/aclk] [get_bd_ports ACLK]
connect_bd_net [get_bd_pins axi_proto_conv_reg1/aresetn] [get_bd_pins proc_sys_reset_0/interconnect_aresetn]
connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP1] [get_bd_intf_pins axi_proto_conv_reg1/S_AXI]
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI_REG1
set_property -dict [list CONFIG.PROTOCOL {AXI4LITE}] [get_bd_intf_ports M_AXI_REG1]
connect_bd_intf_net [get_bd_intf_ports M_AXI_REG1] [get_bd_intf_pins axi_proto_conv_reg1/M_AXI]
set_property CONFIG.ASSOCIATED_BUSIF {M_AXI_REG0:M_AXI_REG1} [get_bd_ports /ACLK]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_protocol_converter:2.1 axi_proto_conv_dram0
connect_bd_intf_net [get_bd_intf_pins axi_proto_conv_dram0/M_AXI] [get_bd_intf_pins processing_system7_0/S_AXI_HP0]
connect_bd_net [get_bd_pins axi_proto_conv_dram0/aclk] [get_bd_ports ACLK]
connect_bd_net [get_bd_pins axi_proto_conv_dram0/aresetn] [get_bd_pins proc_sys_reset_0/interconnect_aresetn]
create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_DRAM0
set_property -dict [list CONFIG.MAX_BURST_LENGTH {16} CONFIG.DATA_WIDTH {64}] [get_bd_intf_ports S_AXI_DRAM0]
set_property CONFIG.ASSOCIATED_BUSIF {M_AXI_REG0:M_AXI_REG1:S_AXI_DRAM0} [get_bd_ports /ACLK]
connect_bd_intf_net [get_bd_intf_ports S_AXI_DRAM0] [get_bd_intf_pins axi_proto_conv_dram0/S_AXI]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_protocol_converter:2.1 axi_proto_conv_dram1
connect_bd_intf_net [get_bd_intf_pins axi_proto_conv_dram1/M_AXI] [get_bd_intf_pins processing_system7_0/S_AXI_HP1]
connect_bd_net [get_bd_pins axi_proto_conv_dram1/aclk] [get_bd_ports ACLK]
connect_bd_net [get_bd_pins axi_proto_conv_dram1/aresetn] [get_bd_pins proc_sys_reset_0/interconnect_aresetn]
create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_DRAM1
set_property -dict [list CONFIG.MAX_BURST_LENGTH {16} CONFIG.DATA_WIDTH {64}] [get_bd_intf_ports S_AXI_DRAM1]
set_property CONFIG.ASSOCIATED_BUSIF {M_AXI_REG0:M_AXI_REG1:S_AXI_DRAM0:S_AXI_DRAM1} [get_bd_ports /ACLK]
connect_bd_intf_net [get_bd_intf_ports S_AXI_DRAM1] [get_bd_intf_pins axi_proto_conv_dram1/S_AXI]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_protocol_converter:2.1 axi_proto_conv_dram2
connect_bd_intf_net [get_bd_intf_pins axi_proto_conv_dram2/M_AXI] [get_bd_intf_pins processing_system7_0/S_AXI_HP2]
connect_bd_net [get_bd_pins axi_proto_conv_dram2/aclk] [get_bd_ports ACLK]
connect_bd_net [get_bd_pins axi_proto_conv_dram2/aresetn] [get_bd_pins proc_sys_reset_0/interconnect_aresetn]
create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_DRAM2
set_property -dict [list CONFIG.MAX_BURST_LENGTH {16} CONFIG.DATA_WIDTH {64}] [get_bd_intf_ports S_AXI_DRAM2]
set_property CONFIG.ASSOCIATED_BUSIF {M_AXI_REG0:M_AXI_REG1:S_AXI_DRAM0:S_AXI_DRAM1:S_AXI_DRAM2} [get_bd_ports /ACLK]
connect_bd_intf_net [get_bd_intf_ports S_AXI_DRAM2] [get_bd_intf_pins axi_proto_conv_dram2/S_AXI]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_protocol_converter:2.1 axi_proto_conv_dram3
connect_bd_intf_net [get_bd_intf_pins axi_proto_conv_dram3/M_AXI] [get_bd_intf_pins processing_system7_0/S_AXI_HP3]
connect_bd_net [get_bd_pins axi_proto_conv_dram3/aclk] [get_bd_ports ACLK]
connect_bd_net [get_bd_pins axi_proto_conv_dram3/aresetn] [get_bd_pins proc_sys_reset_0/interconnect_aresetn]
create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_DRAM3
set_property -dict [list CONFIG.MAX_BURST_LENGTH {16} CONFIG.DATA_WIDTH {64}] [get_bd_intf_ports S_AXI_DRAM3]
set_property CONFIG.ASSOCIATED_BUSIF {M_AXI_REG0:M_AXI_REG1:S_AXI_DRAM0:S_AXI_DRAM1:S_AXI_DRAM2:S_AXI_DRAM3} [get_bd_ports /ACLK]
connect_bd_intf_net [get_bd_intf_ports S_AXI_DRAM3] [get_bd_intf_pins axi_proto_conv_dram3/S_AXI]

assign_bd_address [get_bd_addr_segs {M_AXI_REG0/Reg }]
set_property offset 0x40000000 [get_bd_addr_segs {processing_system7_0/Data/SEG_M_AXI_REG0_Reg}]
set_property range 1G [get_bd_addr_segs {processing_system7_0/Data/SEG_M_AXI_REG0_Reg}]

assign_bd_address [get_bd_addr_segs {M_AXI_REG1/Reg }]
set_property offset 0x80000000 [get_bd_addr_segs {processing_system7_0/Data/SEG_M_AXI_REG1_Reg}]
set_property range 1G [get_bd_addr_segs {processing_system7_0/Data/SEG_M_AXI_REG1_Reg}]

assign_bd_address [get_bd_addr_segs {processing_system7_0/S_AXI_HP0/HP0_DDR_LOWOCM }]
set_property range 256M [get_bd_addr_segs {S_AXI_DRAM0/SEG_processing_system7_0_HP0_DDR_LOWOCM}]
set_property offset 0x30000000 [get_bd_addr_segs {S_AXI_DRAM0/SEG_processing_system7_0_HP0_DDR_LOWOCM}]

assign_bd_address [get_bd_addr_segs {processing_system7_0/S_AXI_HP1/HP1_DDR_LOWOCM }]
set_property range 256M [get_bd_addr_segs {S_AXI_DRAM1/SEG_processing_system7_0_HP1_DDR_LOWOCM}]
set_property offset 0x30000000 [get_bd_addr_segs {S_AXI_DRAM1/SEG_processing_system7_0_HP1_DDR_LOWOCM}]

assign_bd_address [get_bd_addr_segs {processing_system7_0/S_AXI_HP2/HP2_DDR_LOWOCM }]
set_property range 256M [get_bd_addr_segs {S_AXI_DRAM2/SEG_processing_system7_0_HP2_DDR_LOWOCM}]
set_property offset 0x30000000 [get_bd_addr_segs {S_AXI_DRAM2/SEG_processing_system7_0_HP2_DDR_LOWOCM}]

assign_bd_address [get_bd_addr_segs {processing_system7_0/S_AXI_HP3/HP3_DDR_LOWOCM }]
set_property range 256M [get_bd_addr_segs {S_AXI_DRAM3/SEG_processing_system7_0_HP3_DDR_LOWOCM}]
set_property offset 0x30000000 [get_bd_addr_segs {S_AXI_DRAM3/SEG_processing_system7_0_HP3_DDR_LOWOCM}]

regenerate_bd_layout
validate_bd_design
save_bd_design
close_bd_design [get_bd_designs zynq_ps]
set my_bd_wrapper [make_wrapper -files [get_files -filter {FILE_TYPE == "Block Designs"} zynq_ps.bd] -top]
add_files -norecurse $my_bd_wrapper

set my_files [list]
lappend my_files "./dvi2rgb/DVI_Constants.vhd"
lappend my_files "./dvi2rgb/ChannelBond.vhd"
lappend my_files "./dvi2rgb/SyncAsync.vhd"
lappend my_files "./dvi2rgb/GlitchFilter.vhd"
lappend my_files "./dvi2rgb/TWI_SlaveCtl.vhd"
lappend my_files "./dvi2rgb/EEPROM_8b.vhd"
lappend my_files "./dvi2rgb/InputSERDES.vhd"
lappend my_files "./dvi2rgb/PhaseAlign.vhd"
lappend my_files "./dvi2rgb/SyncAsyncReset.vhd"
lappend my_files "./dvi2rgb/SyncBase.vhd"
lappend my_files "./dvi2rgb/TMDS_Clocking.vhd"
lappend my_files "./dvi2rgb/TMDS_Decoder.vhd"
lappend my_files "./dvi2rgb/ResyncToBUFG.vhd"
lappend my_files "./dvi2rgb/dvi2rgb.vhd"
lappend my_files "./jpeg_enc/mdct/finiteprecrndnrst.v"
lappend my_files "./jpeg_enc/jfifgen/headerram.v"
lappend my_files "./jpeg_enc/huffman/ac_cr_rom.vhd"
lappend my_files "./jpeg_enc/huffman/ac_rom.vhd"
lappend my_files "./jpeg_enc/common/jpeg_pkg.vhd"
lappend my_files "./jpeg_enc/buffifo/sub_ramz.vhd"
lappend my_files "./jpeg_enc/buffifo/multiplier.vhd"
lappend my_files "./jpeg_enc/buffifo/sub_ramz_lut.vhd"
lappend my_files "./jpeg_enc/buffifo/buf_fifo.vhd"
lappend my_files "./jpeg_enc/hostif/hostif_emu.vhd"
lappend my_files "./jpeg_enc/common/singlesm.vhd"
lappend my_files "./jpeg_enc/control/ctrlsm.vhd"
lappend my_files "./jpeg_enc/common/ramz.vhd"
lappend my_files "./jpeg_enc/mdct/mdct_pkg.vhd"
lappend my_files "./jpeg_enc/mdct/dct1d.vhd"
lappend my_files "./jpeg_enc/mdct/dct2d.vhd"
lappend my_files "./jpeg_enc/mdct/ram.vhd"
lappend my_files "./jpeg_enc/mdct/dbufctl.vhd"
lappend my_files "./jpeg_enc/mdct/rome.vhd"
lappend my_files "./jpeg_enc/mdct/romo.vhd"
lappend my_files "./jpeg_enc/mdct/mdct.vhd"
lappend my_files "./jpeg_enc/common/fifo.vhd"
lappend my_files "./jpeg_enc/mdct/fdct.vhd"
lappend my_files "./jpeg_enc/zigzag/zigzag.vhd"
lappend my_files "./jpeg_enc/zigzag/zz_top.vhd"
lappend my_files "./jpeg_enc/quantizer/romr.vhd"
lappend my_files "./jpeg_enc/quantizer/r_divider.vhd"
lappend my_files "./jpeg_enc/quantizer/quantizer.vhd"
lappend my_files "./jpeg_enc/quantizer/quant_top.vhd"
lappend my_files "./jpeg_enc/rle/rle.vhd"
lappend my_files "./jpeg_enc/rle/rledoublefifo.vhd"
lappend my_files "./jpeg_enc/rle/rle_top.vhd"
lappend my_files "./jpeg_enc/huffman/dc_rom.vhd"
lappend my_files "./jpeg_enc/huffman/dc_cr_rom.vhd"
lappend my_files "./jpeg_enc/huffman/doublefifo.vhd"
lappend my_files "./jpeg_enc/huffman/huffman.vhd"
lappend my_files "./jpeg_enc/bytestuffer/bytestuffer.vhd"
lappend my_files "./jpeg_enc/jfifgen/jfifgen.vhd"
lappend my_files "./jpeg_enc/outmux/outmux.vhd"
lappend my_files "./jpeg_enc/top/jpegenc.vhd"
lappend my_files "./common/pkg_general.vhd"
lappend my_files "./common/pkg_axi.vhd"
lappend my_files "./common/axi4lite_reg_file.vhd"
lappend my_files "./common/sreg_inferred.vhd"
lappend my_files "./common/cdc_synchro.vhd"
lappend my_files "./common/cdc_pulse.vhd"
lappend my_files "./common/rst_synchro.vhd"
lappend my_files "./video_capture/jpeg_enc_ce.vhd"
lappend my_files "./video_capture/clk_activity_detect.vhd"
lappend my_files "./video_capture/resolution_detect.vhd"
lappend my_files "./video_capture/csc_comp.vhd"
lappend my_files "./video_capture/colorspace_conv.vhd"
lappend my_files "./video_capture/image_shim.vhd"
lappend my_files "./video_capture/image_stripe.vhd"
lappend my_files "./video_capture/buffered_encoder.vhd"
lappend my_files "./video_capture/triple_frame_buffer_controller.vhd"
lappend my_files "./video_capture/striped_encoders.vhd"
lappend my_files "./video_capture/hdmi_rx.vhd"
lappend my_files "./video_capture/hdmi_rx_control.vhd"
lappend my_files "./video_capture/video_capture.vhd"
lappend my_files "./video_capture/video_capture_hdmi.vhd"
lappend my_files "./zynq_ps_wrap.vhd"
lappend my_files "./kvm_top.vhd"

add_files -norecurse $my_files
set_property top kvm_top [current_fileset]

add_files -fileset constrs_1 -norecurse ./kvm_top.xdc
set_property target_constrs_file ./kvm_top.xdc [current_fileset -constrset]

set my_sim_files [list]
lappend my_sim_files "./video_capture/sim/video_sync.vhd"
lappend my_sim_files "./video_capture/sim/memory_model.sv"
lappend my_sim_files "./video_capture/sim/video_capture_tb.vhd"
lappend my_sim_files "jpeg_enc/buffifo/counter_8.data"
lappend my_sim_files "jpeg_enc/jfifgen/header.data"
lappend my_sim_files "dvi2rgb/custom_edid.data"
set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 -norecurse $my_sim_files
set_property top video_capture_tb [get_filesets sim_1]
exec unzip -o ./video_capture/sim/stim_img.zip -d ./video_capture/sim
add_files -fileset sim_1 -norecurse [glob ./video_capture/sim/stim_img_*.data]
set_property -name {xsim.simulate.runtime} -value {300ms} -objects [get_filesets sim_1]
