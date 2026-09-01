# FPGA PYNQ-Z2

## Pinout

### Raspberry Pi 40-pin Header 

| Pin Number | FPGA | Pin Name         | Info          |
|------------|------|------------------|---------------|
| 1          |      | 3.3V Power       |               |
| 2          |      | 5V Power         |               |
| 3          | W18  | SPI flash SD 2   | Also on PMODA |
| 4          |      | 5V Power         |               |
| 5          | W19  | jtag trst ni     | Also on PMODA |
| 6          |      | Ground           |               |
| 7          | V6   | spi slave cs io  |               |
| 8          | Y18  | spi flash sck o  | Also on PMODA |
| 9          |      | Ground           |               |
| 10         | Y19  | SPI flash SD 1   | Also on PMODA |
| 11         | U7   | spi slave sck io |               |
| 12         | C20  | spi2 sck o       |               |
| 13         | V7   | GPIO 10          |               |
| 14         |      | Ground           |               |
| 15         | U8   | GPIO 9           |               |
| 16         | W6   | spi2 csb o       |               |
| 17         |      | 3.3V Power       |               |
| 18         | U18  | SPI flash sck o  | Also on PMODA |
| 19         | V8   | GPIO 8           |               |
| 20         |      | Ground           |               |
| 21         | V10  | GPIO 7           |               |
| 22         | U19  | SPI flash SD 0   | Also on PMODA |
| 23         | W10  | GPIO 6           |               |
| 24         | F19  |                  |               |
| 25         |      | Ground           |               |
| 26         | F20  | ddr snd clk o    |               |
| 27         | Y16  | SPI flash SD 3   | Also on PMODA |
| 28         | Y17  | ddr rcv clk i    | Also on PMODA |
| 29         | Y6   | GPIO 4           |               |
| 30         |      | Ground           |               |
| 31         | Y7   | GPIO 3           |               |
| 32         | B20  | i2s ws           |               |
| 33         | W8   | GPIO 2           |               |
| 34         |      | Ground           |               |
| 35         | Y8   | GPIO 1           |               |
| 36         | B19  | i2s sck          |               |
| 37         | W9   | i2s sd           |               |
| 38         | A20  | pdm2pcm pdm      |               |
| 39         |      | Ground           |               |
| 40         | Y9   | pdm2pcm clk      |               |


GPIO 11 to 13 (M15/G14/L14) are connected to LD5

### Arduino Header TOP

| Pin Number | FPGA    | Pin Name         | Info          |
|------------|---------|------------------|---------------|
| SCL        | P15     | i2c scl          |               |
| SDA        | P16     | i2c sda          |               |
| A          | Y13     |                  |               |
| GND        |         |                  |               |
| AR13       | N17     | SPI sd 3         |               |
| AR12       | P18     | SPI sd 2         |               |
| AR11       | R17     | SPI2 sd 3        |               |
| AR10       | T16     |                  |               |
| AR9        | V18     | SPI2 sd 1        |               |
| AR8        | V17     | SPI2 sd 0        |               |
| AR7        | U17     |                  |               |
| AR6        | R16     |                  |               |
| AR5        | T15     | SPI2 csb 1       |               |
| AR4        | V15     |                  |               |
| AR3        | V13     | SPI slave mosi   |               |
| AR2        | U13     | SPI slave miso   |               |
| AR1        | U12     | GPIO 5           |               |
| AR0        | T14     | GPIO 0           |               |


Nothing is connected to the Arduino header BOTTOM. 
