# Camera OV7670 — current state

## Hardware [datasheet](https://www.olimex.com/Products/Components/Camera/CAMERA-OV7670/resources/OV7670.pdf)

- The camera peripheral is declared as its own IP in [hw/ip/camera](hw/ip/camera):
  - [camera_if.sv](hw/ip/camera/rtl/camera_if.sv) — the camera interface logic (capture/timing).
  - [camera_reg_top.sv](hw/ip/camera/rtl/camera_reg_top.sv) / [camera_reg_pkg.sv](hw/ip/camera/rtl/camera_reg_pkg.sv) — register file generated from [data/camera.hjson](hw/ip/camera/data/camera.hjson).
  - [camera_window.sv](hw/ip/camera/rtl/camera_window.sv) — windowing logic.
  - [fake_signals.sv](hw/ip/camera/rtl/fake_signals.sv) — synthetic/test-pattern signal generator, used to exercise the pipeline without a real sensor attached (`UseTestPattern`).

- Signals are connected to GPIO (see [config/pad_cfg.py](config/pad_cfg.py)) and muxed; `pad_control_set_mux` needs to be called before use (see [sw/applications/camera/main.c](sw/applications/camera/main.c)).
- I2C internal pull-ups are enabled to make the I2C bus work without external pull-up resistors on the PYNQ-Z2.
- On the PYNQ-Z2, the camera can be directly connected to the GPIO pins, but they are not close together, so wires are necessary.

- The module directly sends pixel data. There is no manipulation of data to obtain the different colors.

## Software

[sw/applications/camera/main.c](sw/applications/camera/main.c):

- Configure GPIO.
- Initialize and check I2C communication with the camera sensor.
- Configure the camera sensor registers (resolution, pixel format, etc.).
- Launch a DMA transfer of 1000 words from the camera peripheral to memory.

# Video (HDMI) — current state

## Hardware

- The HDMI peripheral is declared as its own IP in [hw/ip/hdmi](hw/ip/hdmi):
  - [hdmi_if.sv](hw/ip/hdmi/rtl/hdmi_if.sv) — the HDMI/DVI-D transmitter front end, spanning the bus clock domain (register file) and the pixel clock domain (video path).
  - [hdmi_timing.sv](hw/ip/hdmi/rtl/hdmi_timing.sv) — video timing generator (defaults to 640x480@60).
  - [hdmi_pattern.sv](hw/ip/hdmi/rtl/hdmi_pattern.sv) — built-in test pattern generator (color bars, xor texture, checkerboard, solid color).
  - [hdmi_pixel_stream.sv](hw/ip/hdmi/rtl/hdmi_pixel_stream.sv) — pixel source fed by software/DMA through the PIXEL register window, one word per screen pixel, no frame buffer.
  - [hdmi_window.sv](hw/ip/hdmi/rtl/hdmi_window.sv) — write-only pass-through for the PIXEL window (mirrors camera_window.sv, but for pushes).
  - [hdmi_tmds_encoder.sv](hw/ip/hdmi/rtl/hdmi_tmds_encoder.sv) — TMDS channel encoder (DVI 1.0), one instance per channel.
  - [hdmi_reg_top.sv](hw/ip/hdmi/rtl/hdmi_reg_top.sv) / [hdmi_reg_pkg.sv](hw/ip/hdmi/rtl/hdmi_reg_pkg.sv) — register file generated from [data/hdmi.hjson](hw/ip/hdmi/data/hdmi.hjson).

- Unlike the camera, the HDMI pins bypass the pad ring entirely (no GPIO muxing): `hdmi_pclk_i` and `hdmi_tmds_ch0/1/2_o` are dedicated top-level ports on [core_v_mini_mcu.sv](hw/core-v-mini-mcu/core_v_mini_mcu.sv), since the pixel clock comes from the FPGA's own clocking resources and the TMDS words feed device-specific serializers.
- The device-specific serialization (four 10:1 OSERDESE2 lanes plus OBUFDS drivers) lives outside the portable RTL, in [hw/fpga/hdmi_tmds_out_xilinx.sv](hw/fpga/hdmi_tmds_out_xilinx.sv), for 7-series FPGAs (PYNQ-Z2).

## Software

[sw/applications/hdmi/main.c](sw/applications/hdmi/main.c) — standalone test (works on PYNQ-Z2):

- Cycle through the built-in test patterns (color bars, xor, checkerboard, solid colors).
- Check the frame counter advances, to confirm the pixel clock is alive.

[sw/applications/hdmi_camera_test/main.c](sw/applications/hdmi_camera_test/main.c) — camera-to-HDMI bridge (not tested with camera, only with the fake signals generator):

- Enable HDMI output in pixel-stream mode and start the camera.
- Set up a DMA transaction from the camera's DATA window straight into the HDMI's PIXEL window and loop it forever.

The synchronization should be automatic; however, it doesn't seem to work properly.

# Miscellaneous

- Pinout of the PYNQ-Z2: [docs/source/FPGA/PYNQ-Z2.md](docs/source/FPGA/PYNQ-Z2.md)
- Verilator builds with the w25q128jw excluded.
- A raw memory dump of the RAM is done with Verilator at the end of the simulation (memory_dump.hex).
- The test image in the testbench is a 640x480 RGB565 image (test_image.hex) that can be used to test the HDMI output.
