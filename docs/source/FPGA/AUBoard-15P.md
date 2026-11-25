# AUBoard-15P: Getting Started

This guide covers X-HEEP on the Avnet (Tria) [AUBoard-15P](https://avnet.me/AUBoard-15P), a board built around the AMD Artix™ UltraScale+™ `xcau15p-ffvb676-2-e`. The device has no processing system, so X-HEEP runs in the FPGA fabric and uses the board's own USB port, buttons, switches and LEDs.

The general flow is the one of the [Run on FPGA](./RunOnFPGA.md) guide. This page lists what is specific to the board.

## Building the bitstream

```bash
make mcu-gen
make vivado-fpga FPGA_BOARD=auboard-15p
```

Vivado needs no board files for this target: the part is set directly and every pin is assigned in `hw/fpga/xheep_fpga_support/constraints/auboard-15p/pin_assign.xdc`. The X-HEEP clock is 15 MHz, made from the board's 300 MHz oscillator.

The target has been built with Vivado 2026.2.

## Connecting the board

1. Power the board with its supply.
2. Connect the board's USB JTAG/UART port to your computer. It is an FT2232 with two channels:
   - the first is the FPGA's JTAG, which Vivado uses to program the bitstream;
   - the second is X-HEEP's UART. It appears as the second `ttyUSB` device of the board, for example `/dev/ttyUSB1`.

Program the bitstream from the Vivado Hardware Manager, or with:

```bash
make vivado-fpga-pgm FPGA_BOARD=auboard-15p
```

The bitstream is not stored on the board. After a power cycle, or after pressing the FPGA program button (printed `PB2`), the board loads its factory design from flash again and X-HEEP has to be programmed again.

To see the output of `printf`:

```bash
picocom -b 9600 -r -l --imap lfcrlf /dev/ttyUSB1
```

## Buttons, switches and LEDs

The labels printed on the board are not the names used in Avnet's board files. Both are given here.

| X-HEEP signal   | Board                                  | Notes                                      |
|-----------------|----------------------------------------|--------------------------------------------|
| `rst_i`         | Reset push button `SYS_RST_N`, printed `PB3` | Active low                           |
| `boot_select_i` | Slide switch 1 (`SLIDE_SW1`)           | Keep it at 0 to boot from JTAG             |
| `rst_led_o`     | Red LED 1                              | On while X-HEEP is in reset                |
| `clk_led_o`     | Red LED 2                              | Blinks while the 15 MHz clock runs         |
| `exit_valid_o`  | Red LED 3                              |                                            |
| `exit_value_o`  | Red LED 4                              |                                            |
| `gpio_io[0..3]` | Push buttons `PB_SW1` to `PB_SW4`      | `PB_SW1` to `PB_SW3` are printed `PB4` to `PB6`. Active high |
| `gpio_io[4..6]` | Slide switches 2 to 4                  |                                            |
| `gpio_io[7]`    | Click header J20, `PWM` pin            | 3.3 V                                      |
| `gpio_io[8..10]`| RGB LED 1: blue, green, red            | Active high                                |
| `gpio_io[11..12]`| RGB LED 2: blue, green                | Active high                                |
| `uart_tx_o`, `uart_rx_i` | USB JTAG/UART port, second channel |                                       |
| `i2c_scl_io`, `i2c_sda_io` | The board's main I2C bus     | See [I2C devices](#i2c-devices)            |

The printed `PB2` button is the FPGA program button. It is not an X-HEEP input: it replaces X-HEEP with the board's factory design.

## JTAG

X-HEEP's debug JTAG is not the board's USB JTAG. The USB port reaches the FPGA's own JTAG, which only programs the bitstream. X-HEEP's JTAG is on the mikroBUS (Click) header J20, which must hold no Click board:

| X-HEEP signal  | J20 pin | Name printed for the Click pin |
|----------------|---------|--------------------------------|
| `jtag_trst_ni` | 2       | RST                            |
| `jtag_tms_i`   | 3       | CS                             |
| `jtag_tdi_i`   | 4       | SCK                            |
| `jtag_tck_i`   | 5       | MISO                           |
| `jtag_tdo_o`   | 6       | MOSI                           |
| Ground         | 8       | GND                            |

- The Click names are only the header's labels. The FPGA pins behind them carry JTAG.
- All signals are 3.3 V. Leave J20 pin 7 (3.3 V) unconnected and share only the ground with the probe.
- `jtag_trst_ni` may stay unconnected: the FPGA pulls it high. The other inputs are pulled to their idle level too, so X-HEEP runs normally with no probe attached.

The board has no Pmod connector, so the [ESL programmer](https://github.com/esl-epfl/x-heep-programmer-pmod) cannot be plugged in. Use a JTAG probe with flying leads, for example a Digilent HS2, and wire it to J20 with jumper wires of 10 to 20 cm. Then follow the [Debug](./../How_to/Debug.md) guide with the OpenOCD configuration of your probe (`tb/core-v-mini-mcu-nexsys-hs2.cfg` for the HS2) to load and run an application:

```bash
make app PROJECT=hello_world TARGET=auboard-15p
```

## Flash and the other peripherals

The board has no flash that X-HEEP can reach on a header. The flash pads and the remaining peripherals are routed to the FMC connector, on `LA` pins of bank 66 at 1.8 V. They are connected to nothing unless a mezzanine card is fitted, and they need jumper J46 in its default position (1.8 V).

| X-HEEP signals                 | FMC pins               |
|--------------------------------|------------------------|
| `spi_flash_*`                  | `LA00`, `LA02`, `LA03` |
| `spi_slave_*`                  | `LA01`, `LA04`         |
| `spi_*` (SPI host)             | `LA05`, `LA06`, `LA08` |
| `spi2_*`                       | `LA09`, `LA10`, `LA12`, `LA13_P` |
| `pdm2pcm_*`                    | `LA14`                 |
| `i2s_*`                        | `LA15`, `LA16`         |

The exact pins are in `pin_assign.xdc`. Without a flash on the FMC connector, load applications over JTAG with the `on_chip` linker (the default).

## I2C devices

X-HEEP's I2C is on the board's main I2C bus. The bus has an I2C multiplexer (PCA9544A) at address `0x70`. The temperature sensor (STTS22H) is behind channel 3 of the multiplexer and answers at `0x3F`. The MAC-ID EEPROM is on the bus itself, at `0x50` and `0x58`.

```{note}
The board's user guide gives other addresses for the temperature sensor (`0x3C` and `0x30`). The address above is the one the sensor answered at on the board.
```
