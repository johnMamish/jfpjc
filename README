#### JFPJC: "John's Field-Programmable JPEG Compressor"

This project consists of JPEG compressors written for mobile platforms. It includes a partial Verilog and a partial C implementation of the original JPEG spec.


What's the POINT of it?
  * I feel like it

What are some salient features?
  * Corners may be cut for the sake of power consumption
  * It will probably suck
  * It's a hardware device
  * It's a straightforward adaptation of standard

##### The Verilog one
The Verilog jpeg compressor can be found under the `jfpjc` directory. Right now, it only compresses 320x240 grayscale images and only synthesizes for an iCE40 UltraPlus FPGA, but I plan to make it more general.

It can compress 320x240 grayscale images on an iCE40 at 10fps while taking less than 4 milliWatts. The design has enough clock slack to work up to 90 frames per second, but I haven't tested beyond 10fps.

##### The C one
A C jpeg compressor for microcontrollers can be found under the `jmcujc` directory. It's been tested on an Apollo3 microcontroller, where it can compress images at 3fps while taking about 10 milliWatts.
