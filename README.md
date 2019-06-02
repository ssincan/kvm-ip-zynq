# KVM over IP Gateway

A KVM over IP Gateway, enabling transparent remote access over an IP network, implemented on the Xilinx Zynq-7020 SoC (Zybo Z7-20 development board).

[Demo Video](https://www.youtube.com/watch?v=QUVDMDh9kc4)

![Usage](/doc/usage.png)

## Architecture

The Zynq Programmable Logic implements DVI capture and JPEG encoding. The JPEG-encoded image is transferred to the DRAM via the AXI HP Ports, and served by busybox httpd running under PetaLinux in the Zynq Processor Subsystem.

In the opposite direction, mouse events are captured in the browser using the [Pointer Lock API](https://developer.mozilla.org/en-US/docs/Web/API/Pointer_Lock_API), sent as requests to the HTTP server, and piped to a HID Gadget implementing a mouse.

Keyboard functionality is not yet implemented. (I guess this makes it a ~~K~~VM over IP Gateway.)

## State of Code Base

The SW side of the project (CGI scripts and browser-based client) should be regarded as a PoC or "technology demonstrator". It's mostly pre-existing code, glued together in the simplest (if a bit hackish) way possible.

## Tools

Built and tested with Xilinx Vivado 2018.3 (WebPACK) and PetaLinux 2018.3.

### Building the Vivado Project

Open Vivado, change the current working directory to `gateware`, and run `source ./zybo_z7_kvm_prj.tcl` from the Vivado TCL Console. This will create the Vivado project under `gateware/zybo_z7_kvm`. You can then run all implementation and/or simulation steps.

### Simulation

The behavioral simulation is already configured in the project generated above. After a some time (at least 150 milliseconds simulation time, see `gateware/video_capture/sim/video_capture_tb.vhd`), JPEG images will be generated in `gateware/zybo_z7_kvm/zybo_z7_kvm.sim/sim_1/behav/xsim`.

The input images are included in `gateware/video_capture/sim/stim_img.zip` and extracted by `gateware/zybo_z7_kvm_prj.tcl`. They have been generated with the Python script found in `gateware/video_capture/sim/gen_stim_img.py`.

### Building the PetaLinux Image

The PetaLinux project is under `petalinux/zybo_z7_kvm_plnx`. Follow the instructions in [Xilinx UG1144](https://www.xilinx.com/support/documentation/sw_manuals/xilinx2018_3/ug1144-petalinux-tools-reference-guide.pdf) in order to build the project.

Upon extracting ROOTFS to the corresponding SD Card partition, you will need to add the files included in `petalinux/rootfs_overlay` to the same partition. TODO: include them in a Yocto layer and have petalinux-build do this automatically.

The network interface is configured with a static IPv4 address, 192.168.2.10. This can be changed from the PetaLinux project configuration.

The root password for the image is the PetaLinux default one.

### Initialization

Boot the development board from the SD Card. SSH to the PetaLinux instance and source /home/root/initmouse.sh. TODO: source it automatically at PetaLinux boot.

## Future Development

### Area reduction

Ideally the project would fit in Zynq-7010 to enable porting to even cheaper hardware.

### Remove Clocking Limitations

DRP can be used to reconfigure the MMCM in the DVI2RGB IP in order to dynamically support different clock ranges.

### Implement Keyboard

The solution which would work with the cuurrent HW is a composite Mouse + Keyboard HID Gadget.

### Implement Virtual Storage

Some more expensive commercial KVM over IP Gateways can emulate a removable drive, populated with a disk image that is controlled by the client. This can be done with the Zybo-Z7 USB OTG port (see equivalent ZC702 example [here](https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/18842264/Zynq-7000+AP+SoC+USB+Mass+Storage+Device+Class+Design+Example+Techtip)), but that means either creating a composite device with Mouse + Keyboard + Mass Storage, or finding another solution for Mouse + Keyboard, which brings us to the next point.

### Alternate Mouse/Keyboard Implementation

A potential solution to free up the USB OTG port for use as a Mass Storage Peripheral, is to use one or two [3.3V Pro Micro](https://www.sparkfun.com/products/12587) boards to implement the HID devices, as shown e.g. [here](https://www.sparkfun.com/tutorials/337). These would receive the mouse/keyboard events from the Zybo-Z7 board through an UART, connected via a PMOD port.

## License

The `gateware` (FPGA bitstream) part of this project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

There are some less permissive exceptions to this for reused components in the SW side. These are noted in the corresponding source files (e.g. `petalinux/zybo_z7_kvm_plnx/project-spec/meta-user/recipes-apps/hidgadgettest/files/hidgadgettest.c` is a derivative of [hid_gadget_test](https://www.kernel.org/doc/Documentation/usb/gadget_hid.txt)).

## Acknowledgments

* Michal Krepa for the [mkjpeg IP](https://opencores.org/projects/mkjpeg/news).
* Digilent Inc. for the [DVI2RGB IP](https://github.com/Digilent/vivado-library/tree/master/ip/dvi2rgb).
* [Tom Hebb](https://github.com/tchebb) for [memdump](https://github.com/tchebb/memdump), used in the CGI scripts to serve the images from RAM.
