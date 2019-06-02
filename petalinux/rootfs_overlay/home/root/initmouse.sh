#!/bin/sh
modprobe libcomposite
cd /sys/kernel/
mkdir config/usb_gadget/g1
cd config/usb_gadget/g1
mkdir configs/c.1
mkdir functions/hid.usb0
echo 2 > functions/hid.usb0/protocol
echo 1 > functions/hid.usb0/subclass
echo 8 > functions/hid.usb0/report_length
echo -ne \\x05\\x01\\x09\\x02\\xa1\\x01\\x09\\x01\\xa1\\x00\\x05\\x09\\x19\\x01\\x29\\x03\\x15\\x00\\x25\\x01\\x95\\x03\\x75\\x01\\x81\\x02\\x95\\x01\\x75\\x05\\x81\\x03\\x05\\x01\\x09\\x30\\x09\\x31\\x15\\x81\\x25\\x7f\\x75\\x08\\x95\\x02\\x81\\x06\\xc0\\xc0 > functions/hid.usb0/report_desc
mkdir strings/0x409
mkdir configs/c.1/strings/0x409
echo 0x0100 > bcdDevice
echo 0x0200 > bcdUSB
echo 0x00 > bDeviceClass
echo 0x00 > bDeviceProtocol
echo 0x00 > bDeviceSubClass
echo 0x08 > bMaxPacketSize0
echo 0x201c > idProduct
echo 0x03eb > idVendor
echo serial > strings/0x409/serialnumber
echo manufacturer > strings/0x409/manufacturer
echo HID Mouse > strings/0x409/product
echo "Conf 1" > configs/c.1/strings/0x409/configuration
echo 120 > configs/c.1/MaxPower
ln -s functions/hid.usb0 configs/c.1
#ls -a /sys/class/udc/
echo ci_hdrc.0 > UDC
cd ~
if [[ ! -e web_to_mouse ]]; then
    mkfifo web_to_mouse
fi
hidgadgettest /dev/hidg0 mouse &
