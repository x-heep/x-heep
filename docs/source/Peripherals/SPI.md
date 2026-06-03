# SPI Host

```{contents} Table of Contents
:depth: 2
```

There are three instances of the _SPI Host IP_ in the X-HEEP platform. These will
be defined throughout the documentation as:

- SPI Host 1
- SPI Host 2
- SPI Flash

## Preliminary Definitions

### Transaction

A transaction is defined by one or multiple command segments.

### Command Segment

A command segment is a single instruction provided to the _SPI Host IP_ specifying 
speed, direction, and additional parameters discussed later.

### SPI Host

SPI Host refers to the particular hardware device for which this SDK and HAL have 
been developed. _SPI Host_, _SPI Host IP_, and _SPI Host device_ are used 
interchangeably.

### TX and RX

- TX: Transmission-related data or operations.

- RX: Reception-related data or operations.

### Slave and Target

_Slave_ and _target_ are used interchangeably, referring to the SPI device that 
responds to the SPI Host.

### Word

A word, when used as a unit of digital information, always refers to 32 bits
throughout the entire documentation.


## SDK Usage

The SDK facilitates communication with external SPI devices through the `spi_t` 
structure, which holds necessary information, including the specific _SPI Host IP_ 
and external _SPI slave_ data.

```c
typedef struct {
    spi_idx_e   idx;   // The identifier for the desired SPI device
    uint32_t    id;    // spi_t instance ID
    bool        init;  // Indicates if initialization was successful
    spi_slave_t slave; // The slave with whom to communicate configuration 
} spi_t;
```

- `idx` can be `SPI_IDX_FLASH`, `SPI_IDX_HOST` or `SPI_IDX_HOST_2`,
each referring to a specific _SPI Host IP_.

- `id` is the identifier of the specific `spi_t` instance.

- `init` is a boolean used to verify if the `spi_t` variable is properly initialized.

- `slave` is the structure containing all information about the external SPI slave.


### The Slave

The `spi_slave_t` structure is defined as:

```c
typedef struct {
    // The Chip Select line where device connected
    uint8_t        csid       : 2;
    // The data sampling and transmitting mode (polarity and phase)
    spi_datamode_e data_mode  : 2;
    // If 1 data is sampled a full cycle after shifting data out, instead of half cycle
    bool           full_cycle : 1;
    // The minimum number of sck half-cycles to hold cs_n high between commands
    uint8_t        csn_idle   : 4;
    // The number of half sck cycles, CSNTRAIL+1, to leave between last edge of sck 
    // and the rising edge of cs_n
    uint8_t        csn_trail  : 4;
    // The number of half sck cycles, CSNLEAD+1, to leave between the falling edge 
    // of cs_n and the first edge of sck
    uint8_t        csn_lead   : 4;
    // The maximum frequency in hertz of the slave
    uint32_t       freq       : 32;
} spi_slave_t;
```

These fields depend on the external SPI slave you intend to communicate with.

- `csid` is the _Chip Select_ ID (i.e. the line to which your slave is connected).
It can only be __0__ or __1__.

- `data_mode` specifies the phase and polarity the slave uses. Possible values are:

    - `SPI_DATA_MODE_0`: Clock polarity 0, phase 0. (__active-high__
    SCK, sampling data on the __leading__ edge, and asserting data on the __trailing__ edge)
    - `SPI_DATA_MODE_1`: Clock polarity 0, phase 1. (__active-high__
    SCK, sampling data on the __trailing__ edge, and asserting data on the __leading__ edge)
    - `SPI_DATA_MODE_2`: Clock polarity 1, phase 0. (__active-low__
    SCK, sampling data on the __leading__ edge, and asserting data on the __trailing__ edge)
    - `SPI_DATA_MODE_3`: Clock polarity 1, phase 1. (__active-low__
    SCK, sampling data on the __trailing__ edge, and asserting data on the __leading__ edge)

- `full_cycle` determines if data should be sampled _half SCK_ cycle or a _full SCK_ cycle 
after shifting out data. 

- `csn_idle`, `csn_trail`, and `csn_lead` indicate the number of _half SCK_ cycles to keep
the _CS_ line active between command segments, after segments, and before segments,
respectively. The actual number of cycles will be the specified number + 1. For instance, if
`csn_lead` is 5, the _CS_ line will go active 6 _half SCK_ cycles before executing the 
command segment.

- `freq` is the maximum desired frequency for the communication. The true frequency
will be an integer division of half the MCU core frequency. The integer divisor will
be computed by the SDK based on the maximum desired frequency provided, and will take
a value between 1 and 65536 (16 bits). This implies that the true frequency will never
be larger than half the MCU core frequency. The SDK will also return an invalid `spi_t` 
if the desired maximum frequency provided is lower than half the MCU core frequency 
divided by 65536.

````{tip}
It is possible to change the frequency of a particular slave after initialization if
you wish to decrease or increase the communication speed with:

```c
spi_codes_e spi_set_slave_freq(spi_t* spi, uint32_t freq);
```
````


### Initialization

To start using the SDK, you must create an `spi_slave_t` and an `spi_t`. However, 
the `spi_t` __can't__ be created directly; it must be created through the `spi_init` 
function of the SDK to avoid unexpected behaviour.

The function is defined as:
```c
spi_t spi_init(spi_idx_e idx, spi_slave_t slave);
```

This function checks the provided parameters and validates the slave configuration. 
If there is any error it will return an invalid `spi_t` structure. This can be verified 
by reading the `init` field of the structure.

Example:
```c
spi_slave_t slave = {
    .csid = 0,
    .csn_idle = 15,
    .csn_lead = 15,
    .csn_trail = 15,
    .data_mode = SPI_DATA_MODE_0,
    .full_cycle = false,
    .freq = FLASH_MAX_FREQ
};

spi_t spi = spi_init(SPI_IDX_FLASH, slave);

if (spi.init) {
    // Properly initialized
}
else {
    // Initialization error
}
```

````{tip}
A slave with predefined standard values can be created using the macro:
```c
#define SPI_SLAVE(csid, freq) (spi_slave_t) { \
    .csid       = csid, \
    .data_mode  = SPI_DATA_MODE_0, \
    .full_cycle = false, \
    .csn_lead   = 10, \
    .csn_trail  = 10, \
    .csn_idle   = 10, \
    .freq       = freq \
}
```
````

```{note}
After initialization, the `freq` field of the `spi_slave_t` structure of the 
`slave` field of the obtained `spi_t` structure, will provide the value of the 
_true_ frequency, no longer the maximum desired frequency provided!
```

### Transactions

Once the `spi_t` has been successfully initialized, communication with its slave 
device can be performed via transactions, which are lists of command segments executed 
by the _SPI Host IP_.

#### Command Segments

Each command segment consists of a simple instruction determining the direction of 
data transfer (TX, RX or Bidirectional), its speed (Standard, Dual, or Quad), and
the length of the data.

The command segment structure `spi_segment_t` is as:

```c
typedef struct {
    uint32_t   len  : 24;  // Length of data in bytes for the particular segment
    spi_mode_e mode : 4;   // Communication mode (TX, BIDIR, RX_QUAD, ...)
} spi_segment_t;
```

- `len` specifies the length in **bytes** of the data managed by this segment. 
For instance, to send 4 32-bit words, the length would be 16.

- `mode` indicates the data transfer direction and speed. Possible values are:

    - `SPI_MODE_DUMMY`  
    - `SPI_MODE_RX_STD` 
    - `SPI_MODE_TX_STD` 
    - `SPI_MODE_BIDIR`  
    - `SPI_MODE_RX_DUAL`
    - `SPI_MODE_TX_DUAL`
    - `SPI_MODE_RX_QUAD`
    - `SPI_MODE_TX_QUAD`

_DUMMY_ mode refers to a period where the _SPI Host IP_ sends _SCK_ pulses without 
reading or sending any data. The number of _SCK_ pulses is determined by the `len` 
field. For example, to send 10 _SCK_ pulses, `len` must be set to 10 (seems evident,
but I rather put it explicitly).

```{note}
There are no _Dual_ or _Quad_ speeds for _Bidirectional_ mode because the _SPI Host IP_ 
doesn't support it.
```

```{tip}
There are macros for each segment _mode_ simplifying command segment creation.

The macros are: `SPI_SEG_DUMMY`, `SPI_SEG_TX`, `SPI_SEG_RX`, `SPI_SEG_BIDIR`,
`SPI_SEG_TX_DUAL`, `SPI_SEG_RX_DUAL`, `SPI_SEG_TX_QUAD`, and `SPI_SEG_RX_QUAD`

Each macro takes one argument which sets the `len` field.
```

As mentioned above, a transaction comprises various command segments, so an array 
of segments is required.

For example:
```c
spi_segment_t segments[2] = { SPI_SEG_TX(4), SPI_SEG_RX(256) };
```

#### TX/RX Buffers

Since these segments transmit/receive data, appropriate TX and RX buffers are needed. 
These buffers must be large enough to contain the data being transmitted/received to 
avoid memory overwrites.

For our example with 4 bytes of TX and 256 bytes of RX, the buffers would be:

```c
uint32_t src_buffer      = 0;
uint32_t dest_buffer[64] = {0};
```

```{caution}
:name: caution-seglen-bufflen

While segments with lengths not multiple of 4 are allowed, buffers **must** be multiples 
of 4 bytes because the _SPI Host IP_ only allows reads from the RX _FIFO_ one word at
a time.

It is the _segment length_ that will ultimately determine the amount of bytes effectively
transmitted/received, not the buffer size.

For example, an RX segment of length 3 is fine, but the _dest\_buffer_ should be at least 
4 bytes to avoid unexpected behavior.

This design choice was made to avoid having various alignment computations, thus favoring 
computational speed at expense of minimal amount of superfluous bytes.
```

#### Execution

With the buffers and segments ready, the transaction can be issued using:

```c
spi_codes_e spi_execute(spi_t* spi, const spi_segment_t* segments, 
                        uint32_t segments_len, const uint32_t* src_buffer, 
                        uint32_t* dest_buffer);
```

This function returns `SPI_CODE_OK` if the transaction is successfully issued. Otherwise, 
it returns an error code.

And, after a transaction has completed, the result can be checked using:

```c
spi_state_e spi_get_state(spi_t* spi);
```

Which returns `SPI_STATE_DONE` if the transaction completed successfully
(i.e. all segments were completed), `SPI_STATE_ERROR` if a hardware error occurred
during the transaction, or `SPI_STATE_TIMEOUT` if the transaction has timed-out.

````{important}
The SDK completely relies on _SPI Host IP_ interrupts in order to execute any
transaction. Therefore, it is crucial to **enable _SPI Host_ interrupts** at machine-
level before any transaction is initiated.

Example

```c
// Enable global interrupt for machine-level interrupts
CSR_SET_BITS(CSR_REG_MSTATUS, CSR_INTR_EN);
// Set mie.MEIE bit to one to enable machine-level fast spi_flash interrupt
const uint32_t mask = 1 << FIC_FLASH_MEIE;
CSR_SET_BITS(CSR_REG_MIE, mask);
```
````

#### Example

A complete example of executing a transaction:

```c
// Assuming spi variable is properly initialized and machine-level interrupts have
// been enabled.

// Define transaction command segments
spi_segment_t segments[2] = { SPI_SEG_TX(4), SPI_SEG_RX(256) };
// Initialize data buffers
uint32_t src_buffer      = 0;
uint32_t dest_buffer[64] = {0};
// Execute the transaction
if (spi_execute(&spi, segments, 2, &src_buffer, dest_buffer) == SPI_CODE_OK)
{
    if (spi_get_state(&spi) == SPI_STATE_DONE)
    {
        // Transaction successful
    }
    else {
        // Transaction error
    }
}
else {
    // Configuration error
}
```

#### Simplified Transaction Functions

This method is the most configurable. However, there are simpler methods for common 
transactions:

```c
spi_codes_e spi_transmit  (spi_t* spi, const uint32_t* src_buffer, uint32_t len);
spi_codes_e spi_receive   (spi_t* spi, uint32_t* dest_buffer, uint32_t len);
spi_codes_e spi_transceive(spi_t* spi, const uint32_t* src_buffer, 
                           uint32_t* dest_buffer, uint32_t len);
```

```{caution}
The `len` parameter specifies the number of **bytes**, not words.
```

These functions execute basic standard transactions: `spi_transmit` performs a _TX Standard_ 
transaction, `spi_receive` performs an _RX Standard_ transaction, and `spi_transceive` 
performs a _Bidirectional Standard_ transaction. They work like `spi_execute` but do not 
require command segments to be provided.

#### Timeout

All blocking functions have a maximum allowed time from the start of a transaction 
to its complete execution. This duration can be easily configured and retrieved 
using the following functions:

```c
spi_codes_e spi_set_timeout(spi_t* spi, uint32_t timeout);

spi_codes_e spi_get_timeout(spi_t* spi, uint32_t* timeout);
```

This timeout is entirely independent for each _SPI Host_ device. It specifies the
maximum number of **milliseconds** permitted to elapse from the issuance of the 
first command segment to the hardware until the last 32-bit word is read from the 
RX FIFO.

The maximum allowed value for the timeout is {math}`2^{32}-1` (unless the core 
clock frequency exceeds 4 THz, which is unlikely to occur in the near future :) ). 
And the default timeout value is set to 100ms.


### Non-Blocking Transactions

To allow the main program to continue processing while a transaction executes, each 
transaction function has also a _non-blocking_ variant:

```c
spi_codes_e spi_transmit_nb(spi_t* spi, const uint32_t* src_buffer, uint32_t len,
                            spi_callbacks_t callbacks);

spi_codes_e spi_receive_nb(spi_t* spi, uint32_t* dest_buffer, uint32_t len, 
                           spi_callbacks_t callbacks);

spi_codes_e spi_transceive_nb(spi_t* spi, const uint32_t* src_buffer, 
                              uint32_t* dest_buffer, uint32_t len, 
                              spi_callbacks_t callbacks);

spi_codes_e spi_execute_nb(spi_t* spi, const spi_segment_t* segments, 
                           uint32_t segments_len, const uint32_t* src_buffer, 
                           uint32_t* dest_buffer, spi_callbacks_t callbacks);
```

These functions differ in two aspects from their _blocking_ counterpart. First, these 
functions return immediately after launching the transaction, allowing other data 
processing while the transaction completes. Secondly, they take an additional parameter 
of type `spi_callbacks_t`.

#### Callbacks

```c
// Callback type
typedef void (*spi_cb_t)(const uint32_t*, uint32_t, uint32_t*, uint32_t);

// Callbacks structure
typedef struct {
    spi_cb_t done_cb;   // Called once transaction is done
    spi_cb_t txwm_cb;   // Called each time TX watermark event is triggered
    spi_cb_t rxwm_cb;   // Called each time RX watermark event is triggered
    spi_cb_t error_cb;  // Called when there was an error during transaction
} spi_callbacks_t;
```

The _callback_ type (`spi_cb_t`) is invoked with four arguments whenever the corresponding 
event occurs:

1. The _TX buffer_ associated to the transaction.
1. The current number of words in the _TX buffer_.
1. The _RX buffer_ associated to the transaction.
1. The current number of words in the _RX buffer_.

Callbacks in `spi_callbacks_t` can be `NULL` if not needed.

```{note}
In this context, the function `spi_get_state` previously explained, can be used to 
check if the transaction is still ongoing (`SPI_STATE_BUSY`) or has finished. Once
finished the state will also become `SPI_STATE_DONE` or `SPI_STATE_ERROR` depending 
on the result of the transaction.
```

```{tip}
It is possible to get or set the watermark values with the functions `spi_set_txwm`,
`spi_set_rxwm`, `spi_get_txwm`, and `spi_get_rxwm`.
```

#### Example

```c
void done_cb(const uint32_t* txbuff, uint32_t txlen, uint32_t* rxbuff, uint32_t rxlen)
{
    // Do stuff with the data once the transaction is done
}

int main(int argc, char *argv[])
{
    // ...

    // We assume an spi variable has been created by properly initializing it and
    // that machine-level interrupts have been appropriately enabled.

    uint32_t src_buffer = 0x1234    // For example a command to send to slave
    uint32_t dest_buffer[12] = {0}  // Slave's response

    // Notice that the segments' length are not multiples of 4.
    spi_segment_t segments[2] = { SPI_SEG_TX(2), SPI_SEG_RX(45) };

    // Define the callbacks. Notice we can assign NULL when we do not want any
    // callback to be called
    spi_callbacks_t callbacks = {
        .done_cb  = &done_cb,
        .error_cb = NULL,
        .rxwm_cb  = NULL,
        .txwm_cb  = NULL
    };

    if (!spi_execute_nb(&spi, segments, 2, &src_buffer, dest_buffer, callbacks))
    {
        while(spi_get_state(spi) == SPI_STATE_BUSY)
        {
            // Do stuff while SPI is busy
        }
    }
    else {
        // There was an error in the transaction configuration
    }

    // ...
}
```

```{note}
In this example, the _TX segment length_ is 2 while _src\_buffer_ is 4 bytes long, 
and the _RX segment length_ is 45 while _dest\_buffer_ is 48 bytes long.
For explanation, please refer to [this directive](#caution-seglen-bufflen).
```


## HAL Usage

### Overview

The three instances of the _SPI Host IP_ of the X-HEEP platform can be referenced 
in the HAL with the macros:

- `spi_host1` for _SPI Host 1_.
- `spi_host2` for _SPI Host 2_.
- `spi_flash` for _SPI Flash_.

These macros expand to variables of type `spi_host_t*`. They must be passed to any 
HAL function requiring to reference the specific peripheral.


#### Return Flags

Most functions in the HAL return an enum value of type `spi_return_flags_e`, indicating 
the outcome of the operation. Below is the complete list of return flags:

```c
typedef enum {
    // Everything went well
    SPI_FLAG_OK                 = 0x0000,
    // The SPI variable passed was a null pointer
    SPI_FLAG_NULL_PTR           = 0x0001,
    // The Watermark exceeded SPI_HOST_PARAM_TX_DEPTH or SPI_HOST_PARAM_RX_DEPTH 
    // and was therefore not set
    SPI_FLAG_WATERMARK_EXCEEDS  = 0x0002,
    // The CSID was out of the bounds specified inSPI_HOST_PARAM_NUM_C_S 
    SPI_FLAG_CSID_INVALID       = 0x0004,
    // The CMD FIFO is currently full so couldn't write command
    SPI_FLAG_COMMAND_FULL       = 0x0008,
    // The specified speed is not valid so couldn't write command
    SPI_FLAG_SPEED_INVALID      = 0x0010,
    // The TX Queue is full, thus could not write to TX register
    SPI_FLAG_TX_QUEUE_FULL      = 0x0020,
    // The RX Queue is empty, thus could not read from RX register
    SPI_FLAG_RX_QUEUE_EMPTY     = 0x0040,
    // The SPI is not ready
    SPI_FLAG_NOT_READY          = 0x0080,
    // The event to enable is not a valid event
    SPI_FLAG_EVENT_INVALID      = 0x0100,
    // The error irq to enable is not a valid error irq
    SPI_FLAG_ERROR_INVALID      = 0x0200 
} spi_return_flags_e;
```


**Note**: All functions in the HAL returning a `spi_return_flags_e` will **always** 
return `SPI_FLAG_NULL_PTR` when the argument `spi_host_t* spi` is a `NULL` pointer 
and `SPI_FLAG_OK` if the operation has succeeded. To avoid repetition, `SPI_FLAG_NULL_PTR` 
and `SPI_FLAG_OK` will be omitted from discussions of function return values. Only
`spi_return_flags_e` different from these two will be mentioned. If there is any
doubt please refer to the functions documentation.


### Target Device Configuration

Using the HAL begins by configuring the slave device(s) you intend to communicate 
with. For this purpose, a configuration options structure, `spi_configopts_t`, is 
provided, along with functions to write the slave configuration options to the 
_SPI Host IP_.

#### Configuration Options Structure

```c
typedef struct spi_configopts_s {
    // The clock divider to use with a particular slave
    uint16_t clkdiv     : 16;
    // Indicates the minimum number of sck half-cycles to hold cs_n high between 
    // commands
    uint8_t  csnidle    : 4; 
    // Indicates the number of half sck cycles, CSNTRAIL+1, to leave between last 
    // edge of sck and the rising edge of cs_n
    uint8_t  csntrail   : 4;
    // Indicates the number of half sck cycles, CSNLEAD+1, to leave between the 
    // falling edge of cs_n and the first edge of sck
    uint8_t  csnlead    : 4;
    // Will be ignored by hardware
    bool     __rsvd0    : 1;
    // If 1 data is sampled a full cycle after shifting data out, instead of half cycle
    bool     fullcyc    : 1;
    // If 0 data lines change on trailing edge and sample done on leading edge, 
    // if 1 it is the opposite
    bool     cpha       : 1;
    // If 0 sck is low when idle, and emits high pulses. If 1 sck is high when idle, 
    // and emits of low pulses
    bool     cpol       : 1;
} spi_configopts_t;
```

#### Configuration Functions

```c
uint32_t spi_create_configopts(const spi_configopts_t configopts);

spi_return_flags_e spi_set_configopts(spi_host_t* spi, uint32_t csid, 
                                      const uint32_t conf_reg);
```

#### Configuration Steps

To create and write the configuration options to the hardware:

1. **Define Configuration**: Create a `spi_configopts_t` structure with the desired 
settings.
1. **Create Configuration Word**: Call `spi_create_configopts` with the structure 
to generate a 32-bit configuration word.
1. **Apply Configuration**: Call `spi_set_configopts` with the SPI instance, _Chip Select_ 
ID (`csid`), and the configuration word.
1. **Verify Configuration**: Ensure the function returns `SPI_FLAG_OK` to confirm 
successful configuration.

The configuration options persist until overwritten or the _SPI Host IP_ is reset.


### Enabling the SPI Host

After configuring the slave, enable the _SPI Host IP_ and its output buffers:

```c
spi_return_flags_e spi_set_enable(spi_host_t* spi, bool enable);
spi_return_flags_e spi_output_enable(spi_host_t* spi, bool enable);
```

Both functions must be called to start communication:

- `spi_set_enable`: Enables the _SPI Host IP_.
- `spi_output_enable`: Enables the output buffers for _SCK_, _CSB_, and _SD_ lines.



### Communication Commands

Communication with SPI slaves involves creating and inputting commands to the 
_SPI Host IP_. Each command instructs the _SPI Host IP_ to execute a transfer 
(transmit/receive) for a certain amount of bytes, in a specific direction and speed.


#### Command Structure

```c
typedef struct spi_command_s {
    // Length-1 in bytes for the command to transmit/receive
    uint32_t    len         : 24;
    // Keep CS line active after command has finished (allows to instruct series 
    // of commands)
    bool        csaat       : 1;
    // Speed of communication
    spi_speed_e speed       : 2;
    // Direction of communication
    spi_dir_e   direction   : 2;
} spi_command_t;
```

- `len`: Length of bytes - 1 to transmit/receive.
In the case of `SPI_DIR_DUMMY` direction, it represents the number of _SCK_ impulses 
to send without transmitting or receiving any data.
- `csaat`: Keeps CS line active after the command (see [Advanced Commands](#hal-advanced-commands)).
- `speed`: Communication speed (`SPI_SPEED_STANDARD`, `SPI_SPEED_DUAL`, `SPI_SPEED_QUAD`).
- `direction`:Communication direction (`SPI_DIR_DUMMY`, `SPI_DIR_RX_ONLY`, `SPI_DIR_TX_ONLY`,
`SPI_DIR_BIDIR`).

```{note}
The direction `SPI_DIR_BIDIR` can only use the speed `SPI_SPEED_STANDARD`. Configuring 
`SPI_DIR_BIDIR` with any other speed will return `SPI_FLAG_SPEED_INVALID` when issuing
the command.
```

#### Setting Chip Select ID

Specify the target device by setting the Chip Select line:

```c
spi_return_flags_e spi_set_csid(spi_host_t* spi, uint32_t csid);
```

- `csid`: _Chip Select_ line (0 or 1).

This function returns `SPI_FLAG_CSID_INVALID` if the `csid` is out of range.


#### Loading TX FIFO

If the command transmits data (`SPI_DIR_TX_ONLY` or `SPI_DIR_BIDIR`), load the 
TX _FIFO_ with data:

```c
spi_return_flags_e spi_write_word(spi_host_t* spi, uint32_t wdata);

spi_return_flags_e spi_write_byte(spi_host_t* spi, uint8_t bdata);
```

You can load only one 32-bit word or one byte at a time. Therefore, iterate over 
all the data you want to transmit until either the _FIFO_ is full or all the data 
is loaded.

Both write functions will return either `SPI_FLAG_TX_QUEUE_FULL` if the TX _FIFO_ is 
full or `SPI_FLAG_OK` if the data has been loaded into the _FIFO_.


#### Verifying Readiness

Ensure the _SPI Host IP_ is ready to receive commands:

```c
spi_tristate_e spi_get_ready(spi_host_t* spi);
```

- Returns `SPI_TRISTATE_TRUE` if ready, `SPI_TRISTATE_FALSE` if not, and 
`SPI_TRISTATE_ERROR` if the spi pointer is `NULL`.

Alternatively, you may wait for readiness:

```c
spi_return_flags_e spi_wait_for_ready(spi_host_t* spi);
```

#### Issuing Commands

```c
uint32_t spi_create_command(const spi_command_t command);

spi_return_flags_e spi_set_command(spi_host_t* spi, uint32_t cmd_reg);
```

Issue commands by following these steps:

1. **Create Command Word**: Call `spi_create_command` with the command structure.
1. **Send Command**: Call `spi_set_command` with the generated command word.
1. **Check for Errors**: `spi_set_command` returns `SPI_FLAG_SPEED_INVALID` for 
invalid speed or `SPI_FLAG_NOT_READY` if not ready.


#### Reading Received Data

For RX or Bidirectional commands, read received data with:

```c
spi_return_flags_e spi_read_word(spi_host_t* spi, uint32_t* dst);
```

This function returns `SPI_FLAG_RX_QUEUE_EMPTY` if no words are available. Otherwise, 
stores the read word in `uint32_t* dst`.

```{note}
There is no function to read single bytes from the RX _FIFO_ because the _SPI Host IP_ 
only offers entire words to be read. The unused bytes (when the RX command length 
parameter does not describe full words) will be zero-padded.
```


(hal-advanced-commands)=
#### Advanced Commands

For complex commands (e.g. TX followed by RX without deactivating the CS line, etc.), 
use the `csaat` field to keep the _CS_ line active:

- Set `csaat` to `true` to keep the _CS_ line active.
- Repeat the command steps until the last _segment_, where `csaat` should be `false`.



### SPI Host Status

To retrieve the current status of the _SPI Host IP_, a structure and a function 
are provided:

```c
typedef struct spi_status_s {
    // TX queue depth (how many unsent words are in the FIFO)
    uint8_t txqd        : 8;
    // RX queue depth (how many unread words are in the FIFO)
    uint8_t rxqd        : 8;
    // CMD queue depth (how many unprocessed commands are in the FIFO)
    uint8_t cmdqd       : 4;
    // Indicates whether rxqd is above the RX Watermark
    bool    rxwm        : 1;
    // Not used
    bool    __rsvd0     : 1;
    // The endianness of the SPI Peripheral
    bool    byteorder   : 1;
    // Indicates if the SPI still still has more data to read but the RX FIFO is full
    bool    rxstall     : 1;
    // Indicates RX FIFO is empty
    bool    rxempty     : 1;
    // Indicates RX FIFO is full
    bool    rxfull      : 1;
    // Indicates whether txqd is below the TX Watermark
    bool    txwm        : 1;
    // Indicates if the SPI still has more data to send but the TX FIFO is empty
    bool    txstall     : 1;
    // Indicates TX FIFO is empty
    bool    txempty     : 1;
    // Indicates TX FIFO is full
    bool    txfull      : 1;
    // Indicates if the SPI peripheral is currently processing a command
    bool    active      : 1;
    // Indicates if the SPI peripheral is ready to receive more commands
    bool    ready       : 1;
} spi_status_t;

const volatile spi_status_t* spi_get_status(spi_host_t* spi);
```

Calling this function provides read access to all the fields in `spi_status_t`, 
mapped to the `STATUS` register of the _SPI Host_ device.

If `spi_host_t* spi` is `NULL`, this function returns a `NULL` pointer.
Check for `NULL` before accessing fields.


### Interrupts

#### Overview of Interrupts

The SPI Host features two types of interrupts:

- **Error Interrupts**: Triggered by specific error conditions.
- **Event Interrupts**: Triggered by specific event conditions.

To manage these interrupts, you can select which conditions trigger them and 
then check the specific error/event in the interrupt handler.

#### Interrupt Handling

To use interrupts, first implement the _non-weak_ functions of the _weak_ functions 
defined in the HAL. Each _SPI Host IP_ instance has its own _weak_ error handling 
and event handling functions:

For error interrupts:

```c
void spi_intr_handler_error_host(spi_error_e errors);   // For SPI Host 1
void spi_intr_handler_error_host2(spi_error_e errors);  // For SPI Host 2
void spi_intr_handler_error_flash(spi_error_e errors);  // For SPI Flash
```

For event interrupts:

```c
void spi_intr_handler_event_host(spi_event_e events);   // For SPI Host 1
void spi_intr_handler_event_host2(spi_event_e events);  // For SPI Host 2
void spi_intr_handler_event_flash(spi_event_e events);  // For SPI Flash
```

These handlers receive an `enum` value indicating the specific error or event 
condition that triggered the interrupt.

For error interrupts:

```c
typedef enum {
    SPI_ERROR_NONE          = 0,
    // Triggers error interrupt whenever a command is issued while busy.
    SPI_ERROR_CMDBUSY       = (1 << SPI_HOST_ERROR_ENABLE_CMDBUSY_BIT),
    // Triggers error interrupt whenever the TX FIFO overflows.
    SPI_ERROR_OVERFLOW      = (1 << SPI_HOST_ERROR_ENABLE_OVERFLOW_BIT),
    // Triggers error interrupt whenever there is a read from RXDATA but the RX 
    // FIFO is empty. 
    SPI_ERROR_UNDERFLOW     = (1 << SPI_HOST_ERROR_ENABLE_UNDERFLOW_BIT),
    // Triggers error interrupt whenever a command is sent with invalid values for 
    // COMMAND.SPEED or COMMAND.DIRECTION.
    SPI_ERROR_CMDINVAL      = (1 << SPI_HOST_ERROR_ENABLE_CMDINVAL_BIT),
    // Triggers error interrupt whenever a command is submitted, but CSID exceeds 
    // NumCS.
    SPI_ERROR_CSIDINVAL     = (1 << SPI_HOST_ERROR_ENABLE_CSIDINVAL_BIT),
    // INDICATES that TLUL attempted to write to TXDATA with no bytes enabled.
    // This error cannot be set (enabled or disabled).
    // This error should never happen since it is the hardware that controls this.
    SPI_ERROR_ACCESSINVAL   = (1 << SPI_HOST_ERROR_STATUS_ACCESSINVAL_BIT),
    // All the above mentioned errors that can be set.
    SPI_ERROR_IRQALL        = (1 << SPI_HOST_ERROR_ENABLE_CSIDINVAL_BIT+1) - 1,
    // All the above mentioned errors.
    SPI_ERROR_ALL           = (1 << SPI_HOST_ERROR_STATUS_ACCESSINVAL_BIT+1) - 1
} spi_error_e;
```

For event interrupts:

```c
typedef enum {
    SPI_EVENT_NONE      = 0,
    // Triggers event when RX becomes full
    SPI_EVENT_RXFULL    = (1 << SPI_HOST_EVENT_ENABLE_RXFULL_BIT),
    // Triggers event when TX becomes empty
    SPI_EVENT_TXEMPTY   = (1 << SPI_HOST_EVENT_ENABLE_TXEMPTY_BIT),
    // Triggers event when RX goes above watermark
    SPI_EVENT_RXWM      = (1 << SPI_HOST_EVENT_ENABLE_RXWM_BIT),
    // Triggers event when TX falls below watermark
    SPI_EVENT_TXWM      = (1 << SPI_HOST_EVENT_ENABLE_TXWM_BIT),
    // Triggers event as soon as SPI Host IP is ready to receive more commands
    SPI_EVENT_READY     = (1 << SPI_HOST_EVENT_ENABLE_READY_BIT),
    // Triggers event as soon as SPI Host IP is not processing any command
    SPI_EVENT_IDLE      = (1 << SPI_HOST_EVENT_ENABLE_IDLE_BIT),
    // All the above mentioned events
    SPI_EVENT_ALL       = (1 << SPI_HOST_EVENT_ENABLE_IDLE_BIT+1) - 1
} spi_event_e;
```

```{attention}
The `spi_event_e events` passed to the event handler does not represent the event 
that _triggered_ the interrupt. Since the _SPI Host IP_ has no manner of determining
the specific event that triggered the interrupt, the implemented workaround consists
in reading the `STATUS` register to map the corresponding status to the related 
event. Therefore, the `events` variable received by the handler functions is 
actually the statuses mapped to `spi_event_e`.
```

##### Interrupt Acknowledgment

After handling an interrupt, it must be acknowledged to the _SPI Host_.

For event interrupts, the HAL handles acknowledgment automatically.

For error interrupts, the user must acknowledge the error once resolved. The 
_SPI Host_ will remain idle until the error is acknowledged. Use the following 
function to acknowledge errors:

```c
spi_return_flags_e spi_acknowledge_errors(spi_host_t* spi);
```

#### Enabling Interrupts

To enable or disable interrupts, use the following functions:

```c
// For Error Interrupts
spi_return_flags_e spi_enable_error_intr(spi_host_t* spi, bool enable);

// For Event Interrupts
spi_return_flags_e spi_enable_evt_intr(spi_host_t* spi, bool enable);
```

These functions enable/disable the interrupts but do not specify the conditions 
that trigger them. To set the conditions, use these functions:

```c
// For Error Conditions
spi_return_flags_e spi_set_errors_enabled(spi_host_t* spi, spi_error_e errors, bool enable);

// For Event Conditions
spi_return_flags_e spi_set_events_enabled(spi_host_t* spi, spi_event_e events, bool enable);
```

- `spi_set_errors_enabled` returns `SPI_FLAG_ERROR_INVALID` if the provided `errors` 
are not valid (note that `SPI_ERROR_ACCESSINVAL` and `SPI_ERROR_ALL` are
**not valid**).

- `spi_set_events_enabled` returns `SPI_FLAG_EVENT_INVALID` if the provided `events` 
are not valid.

When setting an error or event condition, the other conditions remain unaffected. 
For instance, if `SPI_EVENT_RXWM` and `SPI_EVENT_TXWM` are enabled and you call 
`spi_set_events_enabled` to enable `SPI_EVENT_IDLE`, both `SPI_EVENT_RXWM` and 
`SPI_EVENT_TXWM` will remain enabled.

```{tip}
It is possible to enable/disable multiple `events` or `errors` simultaneously by 
OR-ing the different `spi_error_e` or `spi_event_e` values.
```



## Using HAL Together With SDK

While it is possible to use the HAL together with the SDK, there are important 
considerations to be aware of. Also, consistency is key: do not mix SDK usage with HAL 
usage within the same context. If you need to use both, clearly separate the 
contexts in which each is used.

### Interrupt Handling

#### Event and Error Interrupts

Since the SDK already implements the weak interrupt handlers of the HAL, it is 
not possible to redefine handlers. This means that it is not possible to use any 
interrupt from the HAL when using the SDK.

Because the SDK uses interrupts to operate, it is **crucial not to change any 
interrupt triggering configuration**. In any case, it would be pointless to modify 
it since there is no way to use the interrupts.

### Configuration Management

#### Watermarks

It is possible to modify the TX and RX watermarks using the HAL, but they will 
not be implicitly reset by the SDK. Hence, if you modify any watermarks, they 
should be reset if you want to use different watermarks when using the SDK.

The SDK also provides functions to modify the watermarks. If setting the watermarks 
for SDK usage, it is advised to set them with the SDK's functions rather than with 
the HAL's functions because the SDK will also internally keep an instance of these 
watermarks.

#### Slave Configuration Options

It is possible to change the configuration options for a particular _CSID_ using 
the HAL, but, subsequently, the SDK will not reset the configuration if the same 
SDK `spi_t` instance was used in the previous SDK transaction.

For example, if you execute a transaction with an `spi_t` instance and then use HAL 
functions to change the configuration options of the same _CSID_, the SDK will not 
reset these options in subsequent transactions with the same `spi_t` instance. 
Therefore, it is important to maintain consistency with configuration changes.

### Transaction Management

#### SPI Host Activeness

Since the tracking of busyness by the SDK is managed internally, the `spi_get_state` 
function of the SDK will not return `SPI_STATE_BUSY` if the _SPI Host IP_ is 
processing a transaction that was executed through HAL functions.

It is, anyway, impossible to issue transactions through SDK functions while the _SPI 
Host IP_ is processing a transaction (whether issued by HAL or SDK), but it would 
be useless to check the state of the device using the `spi_get_state` function of 
the SDK.

### Summary of Key Points

- **Consistency**: Do not mix SDK and HAL usage in the same context. Clearly 
separate their usage.

- **Interrupts**: Do not alter interrupt triggering conditions; SDK relies on 
its interrupt handlers.

- **Watermarks**: Use SDK functions to modify watermarks when using SDK to 
maintain consistency.

- **Configuration**: Be consistent with configuration changes, especially when 
switching between HAL and SDK.

- **Activeness**: The `spi_get_state` function of the SDK will not reflect 
transactions initiated by HAL functions.


## 😎 X-pert Zone

Another option for speeding up transaction processing is to use the registers of 
the _SPI Host_ directly. However, this is not recommended unless you have a strong 
understanding of the process. For detailed information on the operation of the 
device, please refer to the following documentation on the _SPI Host_:
[SPI Host: Theory of Operation](https://opentitan.org/book/hw/ip/spi_host/doc/theory_of_operation.html).

To access the registers of the _SPI Host_ directly, the `spi_host` structure is 
defined in `spi_host_structs.h`, along with a pointer variable for each 
_SPI Host IP_, defined as follows:

- `spi_host1_peri ((volatile spi_host *) SPI_HOST_START_ADDRESS)`
- `spi_host2_peri ((volatile spi_host *) SPI2_START_ADDRESS)`
- `spi_flash_peri ((volatile spi_host *) SPI_FLASH_START_ADDRESS)`

Below is an example of implementing an SPI _Standard_ speed transaction with a 
_W25Q128JW_ Flash slave device using this method:

```c
#include "bitfield.h"
#include "soc_ctrl_structs.h"
#include "spi_host_regs.h"
#include "spi_host_structs.h"

// MCU frequency
#define SYS_FREQ (soc_ctrl_peri->SYSTEM_FREQUENCY_HZ)

// Flash parameters
#define FLASH_MAX_FREQ  (133*1000*1000)
#define FLASH_CSN_TIMES 0x0F
#define FLASH_POL       0
#define FLASH_PHA       0
#define FC_RD           0x03 /* Flash Read Data Command */

// SPI transaction parameters
#define SPI_TX  0x02
#define SPI_RX  0x01
#define SPI_STD 0x00

#define LEN_B = 4096 /* Amount of bytes of data to read from flash */

#define ADDRESS = 0x00800000 /* Flash address where to read */

int main(int argc, char *argv[])
{
    // Initialize RX buffer
    uint8_t dest_buff[LEN_B] = {0};

    // Compute frequency of SPI communication based on slave and MCU frequency
    uint16_t clk_div = 0;
    if (FLASH_MAX_FREQ < SYS_FREQ / 2) {
        clk_div = (SYS_FREQ / FLASH_MAX_FREQ - 2) / 2;
        if (SYS_FREQ / (2 * clk_div + 2) > FLASH_MAX_FREQ) clk_div++;
    }
    // Set slave configuration options
    spi_flash_peri->CONFIGOPTS0 = (FLASH_CSN_TIMES << SPI_HOST_CONFIGOPTS_0_CSNIDLE_0_OFFSET) |
                                  (FLASH_CSN_TIMES << SPI_HOST_CONFIGOPTS_0_CSNLEAD_0_OFFSET) |
                                  (FLASH_CSN_TIMES << SPI_HOST_CONFIGOPTS_0_CSNTRAIL_0_OFFSET) |
                                  (FLASH_PHA       << SPI_HOST_CONFIGOPTS_0_CPHA_0_BIT) |
                                  (FLASH_POL       << SPI_HOST_CONFIGOPTS_0_CPOL_0_BIT) |
                                  (clk_div         << SPI_HOST_CONFIGOPTS_0_CLKDIV_0_OFFSET);

    // Enable SPI Host device and output
    bitfield_write(spi_flash_peri->CONTROL, BIT_MASK_1, SPI_HOST_CONTROL_SPIEN_BIT,     true);
    bitfield_write(spi_flash_peri->CONTROL, BIT_MASK_1, SPI_HOST_CONTROL_OUTPUT_EN_BIT, true);

    // Set command to send to slave
    spi_flash_peri->TXDATA = ((bitfield_byteswap32(ADDRESS & 0x00ffffff)) | FC_RD);
    // Set CSID line where slave is connected
    spi_flash_peri->CSID = 0;
    // Wait for SPI Host to be ready before setting command
    while (!bitfield_read(spi_flash_peri->STATUS, BIT_MASK_1, SPI_HOST_STATUS_READY_BIT));
    // Set command
    spi_flash_peri->COMMAND = (SPI_TX   << SPI_HOST_COMMAND_DIRECTION_OFFSET) |
                              (SPI_STD  << SPI_HOST_COMMAND_SPEED_OFFSET) |
                              (0x01     << SPI_HOST_COMMAND_CSAAT_BIT) |
                              (0x03     << SPI_HOST_COMMAND_LEN_OFFSET);
    // Wait for SPI Host to be ready before setting command
    while (!bitfield_read(spi_flash_peri->STATUS, BIT_MASK_1, SPI_HOST_STATUS_READY_BIT));
    // Set command
    spi_flash_peri->COMMAND = (SPI_RX   << SPI_HOST_COMMAND_DIRECTION_OFFSET) |
                              (SPI_STD  << SPI_HOST_COMMAND_SPEED_OFFSET) |
                              (0x00     << SPI_HOST_COMMAND_CSAAT_BIT) |
                              (LEN_B-1  << SPI_HOST_COMMAND_LEN_OFFSET);

    // Setup RX word counter and set watermark
    uint32_t rxcnt = 0;
    const uint8_t watermark = 48;
    bitfield_write(spi_flash_peri->CONTROL, SPI_HOST_CONTROL_RX_WATERMARK_MASK, 
                   SPI_HOST_CONTROL_RX_WATERMARK_OFFSET, watermark);

    // While the SPI Host is active (i.e. still processing transaction)
    while (bitfield_read(spi_flash_peri->STATUS, BIT_MASK_1, SPI_HOST_STATUS_ACTIVE_BIT))
    {
        // If there are still more words to be read than watermark, then wait
        // for RX watermark to go high
        if ((LEN_B/4) - rxcnt > watermark)
            while (!bitfield_read(spi_flash_peri->STATUS, BIT_MASK_1, 
                                                          SPI_HOST_STATUS_RXWM_BIT))
        // Needed because too fast otherwise
        asm volatile ("nop");
        // Just read as much as possible (but no more than watermark words)
        for (int i = 0; i < watermark; i++)
        {
            // If there are words in the RX FIFO read them
            if (bitfield_read(spi_flash_peri->STATUS, SPI_HOST_STATUS_RXQD_MASK, 
                                                      SPI_HOST_STATUS_RXQD_OFFSET))
            {
                dest_buff[rxcnt] = spi_flash_peri->RXDATA;
                rxcnt++;
            }
        }
    }
    // Read the remaining words if there are any
    while (bitfield_read(spi_flash_peri->STATUS, SPI_HOST_STATUS_RXQD_MASK, 
                                                 SPI_HOST_STATUS_RXQD_OFFSET))
    {
        dest_buff[rxcnt] = spi_flash_peri->RXDATA;
        rxcnt++;
    }
}
```

```{note}
There are practically no sanity checks performed in this example in order to keep it
as simple as possible. In a practical application there should of course be sanity
checks wherever needed.
```


## Performance Analysis

A performance testing was carried out utilizing the _EPFL Programmer_, which includes
a _W25Q128JW_ flash memory, and the _PYNQ-Z2_ FPGA. The 
[SPI Flash Loading Boot Procedure](../How_to/ExecuteFromFlash.md#spi-flash-loading-boot-procedure)
was employed for all tests.

The test application used the 
[Clock Cycle Counter `mcycle(h)`](https://ibex-core.readthedocs.io/en/latest/03_reference/performance_counters.html) 
of X-HEEP, recording time via the `CSR_REG_MCYCLE` register. The test tracked the 
duration to create and execute a transaction of various command segments with the 
SDK, where each transaction involved reading 4KiB from the _W25Q128JW_ flash device. 
This read operation was repeated 500 times to obtain an average.

The exact same procedure was applied to the HAL and the _direct register_ method, 
which involves direct manipulation of _SPI Host_ registers without using the HAL or 
SDK. The tests were conducted at both _Standard_ SPI and _Quad_ SPI speeds. For 
accurate comparison, only essential steps for transaction execution were implemented, 
avoiding as many sanity checks as possible to maximize performance.

Results indicate that at _Standard_ SPI speed, _direct register_ manipulation was 
slightly faster than the HAL by approximately 0.8%. At _Quad_ SPI speed, _direct register_ 
manipulation showed a significant performance gain, being about 18.6% faster than 
the HAL. Comparing the HAL to the SDK, the HAL was about 1% faster at _Quad_ speed 
and 0.8% faster at _Standard_ speed.

Exact numbers are provided in the following tables.

```{table}
:widths: auto
:align: center

|          | SDK        | HAL        | Register   |
| :------: | :--------: | :--------: | :--------: |
| **Standard** | 4472.00 μs | 4437.40 μs | 4402.07 μs |
| **Quad**     | 1970.00 μs | 1951.40 μs | 1588.00 μs |
```

To illustrate these numbers rather in percentage of change, the following table 
shows the speed gain(-) and the speed loss(+) when changing method for a Quad speed 
read. For example, when switching from the _direct register_ method to the SDK, 
there is a

```{math}
\frac{SDK - Register}{Register}\ =\ 24.055\%
```

change, which means 24.055% slower.

```{table}
:widths: auto
:align: center

|          | SDK      | HAL      | Register |
| :------: | :------: | :------: | :------: |
| **SDK**      | 0%       | 0.953%   | 24.055%  |
| **HAL**      | -0.944%  | 0%       | 22.884%  |
| **Register** | -19.391% | -18.623% | 0%       |
```