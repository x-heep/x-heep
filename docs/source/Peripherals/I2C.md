# I2C SDK

This SDK provides utilities for basic interaction with the I2C peripheral. It includes functions to initialize the I2C host, configure timing and watermarks, and perform standard read and write operations to I2C target devices.

## Usage

The SDK provides a set of functions to interact with the hardware I2C peripheral for establishing communication, configuring bus parameters, and exchanging data.

### Initialize I2C

Initializes the I2C peripheral by calculating the necessary timer thresholds based on the current SoC frequency. It applies the timing configuration, sets the watermark levels, disables all interrupts, and enables the I2C host functionality. Call this function before performing any read or write operations. It returns `kDifI2cOk` if the initialization has been performed correctly.

```c
i2c_result_t initialize_i2c();
```

### Set Timing Configuration

Updates the dafault I2C timing configuration parameters. This allows customization of the target device speed, expected SDA rise and fall times, the SCL period, and data signal hold cycles. It must be called before `initialize_i2c()` to take effect.

```c
void set_timing_config(i2c_speed_t lowest_target_device_speed,
                       uint32_t sda_rise_ns,
                       uint32_t sda_fall_ns,
                       uint32_t scl_period_ns,
                       uint16_t data_signal_hold_cycles);
```

### Set Watermark Levels

Updates the dafault watermark levels for the RX (receive) and FMT (format) FIFOs. It must be called before `initialize_i2c()` to take effect.

```c
void set_watermark_levels(i2c_level_t rx_level, i2c_level_t fmt_level);
```

### I2C Write

Performs a standard I2C write transaction to a specific register on a target device. The sequence automatically handles the START condition, device address transmission (with the write bit), register address targeting, data transmission, and the final STOP condition. It returns `kDifI2cOk` if the write operation has been performed correctly.

```c
i2c_result_t i2c_write(uint8_t dev_addr, uint8_t reg, uint8_t *source, uint32_t num_bytes);
```

### I2C Read

Performs a standard I2C read transaction from a specific register on a target device. It executes a two-part transaction: first writing the target register address, followed by a RESTART condition to read the requested number of bytes into the destination buffer. The RX FIFO is automatically reset before the transaction begins. It returns `kDifI2cOk` if the read operation has been performed correctly.

```c
i2c_result_t i2c_read(uint8_t dev_addr, uint8_t reg, uint8_t *destination, uint32_t num_bytes);
```

## Example Usage

Examples of utilization of the I2C SDK can be found in `sw/applications/demo_i2c_lms6dso/main.c` and `sw/applications/demo_i2c_tmp112/main.c`.
