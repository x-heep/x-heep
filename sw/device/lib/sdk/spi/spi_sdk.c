/*
                              *******************
******************************* C SOURCE FILE *****************************
**                            *******************
**
** project  : X-HEEP
** filename : spi_sdk.c
** version  : 1
** date     : 18/04/24
**
***************************************************************************
**
** Copyright (c) EPFL contributors.
** All rights reserved.
**
***************************************************************************
*/

/***************************************************************************/
/***************************************************************************/
/**
* @file   spi_sdk.c
* @date   18/04/24
* @author Llorenç Muela
* @brief  The Serial Peripheral Interface (SPI) SDK to set up and use the
* SPI peripheral
*/

/****************************************************************************/
/**                                                                        **/
/**                            MODULES USED                                **/
/**                                                                        **/
/****************************************************************************/

#include "spi_sdk.h"
#include "spi_host.h"
#include "spi_host_regs.h"
#include "soc_ctrl_structs.h"
#include "bitfield.h"
#include "csr.h"

/****************************************************************************/
/**                                                                        **/
/**                       DEFINITIONS AND MACROS                           **/
/**                                                                        **/
/****************************************************************************/

#define DATA_MODE_CPHA_OFFS 0
#define DATA_MODE_CPOL_OFFS 1

#define SPI_MAX_IDX 2
#define SPI_IDX_INVALID(idx) idx > SPI_MAX_IDX

#define SYS_FREQ      (soc_ctrl_peri->SYSTEM_FREQUENCY_HZ)
#define SPI_MIN_FREQ  (SYS_FREQ / (2 * 65535 + 2))           // 65535 = 2^16 - 1

// Maximum length of data (in bytes) for a command segment (currently 2^24)
#define MAX_COMMAND_LENGTH SPI_HOST_COMMAND_LEN_MASK
#define BYTES_PER_WORD     4
// Convert byte count to word count
#define LEN_WORDS(bytes)   ((bytes / BYTES_PER_WORD) + (bytes % BYTES_PER_WORD ? 1 : 0))

// Bitmasks for speed and direction relative to spi_mode_e
#define DIR_SPD_MASK 0b11
#define DIR_INDEX    0
#define SPD_INDEX    2

#define TRIGGERING_EVENTS (SPI_EVENT_IDLE | SPI_EVENT_READY | SPI_EVENT_TXWM | SPI_EVENT_RXWM)

// The standard watermark for all transactions (seems reasonable)
#define TXWM_DEFAULT (SPI_HOST_PARAM_TX_DEPTH / 4)  // Arbirarily chosen
#define RXWM_DEFAULT (SPI_HOST_PARAM_RX_DEPTH - 12) // Arbirarily chosen

#define NULL_CALLBACKS (spi_callbacks_t) {NULL, NULL, NULL, NULL}

// SPI peripheral busy checks
#define SPI_BUSY(peri)     (peri.state == SPI_STATE_BUSY)
#define SPI_NOT_BUSY(peri) (peri.state != SPI_STATE_BUSY)

// Check command length validity
#define SPI_INVALID_LEN(len) (len == 0 || len > MAX_COMMAND_LENGTH)

/**
 * @brief Allows easy TX Transaction instantiation.
 */
#define SPI_TXN_TX(segment, txbuff, len) (spi_transaction_t) { \
    .segments = segment, \
    .seglen   = 1, \
    .txbuffer = txbuff, \
    .txlen    = len, \
    .rxbuffer = NULL, \
    .rxlen    = 0 \
}

/**
 * @brief Allows easy RX Transaction instantiation.
 */
#define SPI_TXN_RX(segment, rxbuff, len) (spi_transaction_t) { \
    .segments = segment, \
    .seglen   = 1, \
    .txbuffer = NULL, \
    .txlen    = 0, \
    .rxbuffer = rxbuff, \
    .rxlen    = len \
}

/**
 * @brief Allows easy BIDIR Transaction instantiation.
 */
#define SPI_TXN_BIDIR(segment, txbuff, rxbuff, len) (spi_transaction_t) { \
    .segments = segment, \
    .seglen   = 1, \
    .txbuffer = txbuff, \
    .txlen    = len, \
    .rxbuffer = rxbuff, \
    .rxlen    = len \
}

/**
 * @brief Allows easy generic Transaction instantiation.
 */
#define SPI_TXN(segment, seg_len, txbuff, rxbuff) (spi_transaction_t) { \
    .segments = segment, \
    .seglen   = seg_len, \
    .txbuffer = txbuff, \
    .txlen    = 0, \
    .rxbuffer = rxbuff, \
    .rxlen    = 0 \
}

/****************************************************************************/
/**                                                                        **/
/**                       TYPEDEFS AND STRUCTURES                          **/
/**                                                                        **/
/****************************************************************************/

/**
 * @brief Transaction Structure. Holds all information relevant to a transaction.
 */
typedef struct {
    const spi_segment_t* segments;  // Pointer to array/buffer of command segments
    uint8_t              seglen;    // Size of the command segents array/buffer
    const uint32_t*      txbuffer;  // Pointer to array/buffer of TX data
    uint32_t             txlen;     // Size of TX array/buffer
    uint32_t*            rxbuffer;  // Pointer to array/buffer for RX data
    uint32_t             rxlen;     // Size of RX array/buffer
} spi_transaction_t;

/**
 * @brief Structure to hold all relative information about a particular peripheral.
 *  peripherals variable in this file holds an instance of this structure for every
 *  SPI peripheral defined in the HAL. This is in order to store relevant information
 *  of the peripheral current status, transaction info, and peripheral instance.
 */
typedef struct {
    spi_host_t*       instance;  // Instance of peripheral defined in HAL
    uint8_t           txwm;      // TX watermark for this particular peripheral
    uint8_t           rxwm;      // RX watermark for this particular peripheral
    uint32_t          last_id;   // ID of last used spi_t to avoid resetting slave
    uint32_t          timeout;   // Timeout for blocking transactions in ms
    spi_state_e       state;     // Current state of device
    spi_transaction_t txn;       // Current transaction being processed
    uint32_t          scnt;      // Counter to track segment to process
    uint32_t          txcnt;     // Counter to track TX word being processed
    uint32_t          rxcnt;     // Counter to track RX word being processed
    spi_callbacks_t   callbacks; // Callback functions to call
} spi_peripheral_t;

/****************************************************************************/
/**                                                                        **/
/*                      PROTOTYPES OF LOCAL FUNCTIONS                       */
/**                                                                        **/
/****************************************************************************/

/**
 * @brief Validates the idx and init variables of spi_t.
 * 
 * @param spi Pointer to spi_t structure obtained through spi_init call
 * @return spi_codes_e information about error. SPI_CODE_OK if all went well
 */
spi_codes_e spi_check_valid(spi_t* spi);

/**
 * @brief Validates slave csid.
 * 
 * @param slave to validate
 * @return spi_codes_e information about error. SPI_CODE_OK if all went well
 */
spi_codes_e spi_validate_slave(spi_slave_t slave);

/**
 * @brief Sets the slave configuration options and the slave CSID.
 * 
 * @param spi Pointer to spi_t structure obtained through spi_init call
 * @return spi_codes_e information about error. SPI_CODE_OK if all went well
 */
spi_codes_e spi_set_slave(spi_t* spi);

/**
 * @brief Validation and configuration of device prior to any transaction.
 * 
 * @param spi Pointer to spi_t structure obtained through spi_init call
 * @return spi_codes_e information about error. SPI_CODE_OK if all went well
 */
spi_codes_e spi_prepare_transfer(spi_t* spi);

/**
 * @brief Computes the true frequency that will be set based on the user desired 
 *  frequency.
 * 
 * @param freq Frequency defined by user
 * @return uint32_t True frequency after determining the SPI clk divider
 */
uint32_t spi_true_slave_freq(uint32_t freq);

/**
 * @brief Validates all the provided segments and counts the number of words for
 *  TX and RX buffers.
 * 
 * @param segments An array of segments to validate
 * @param segments_len The length of the array of segments
 * @param tx_count Variable to store the counted TX words
 * @param rx_count Variable to store the counted RX words
 * @return true if all segments are valid
 * @return false otherwise
 */
bool spi_validate_segments(const spi_segment_t* segments, uint32_t segments_len, 
                           uint32_t* tx_count, uint32_t* rx_count);

/**
 * @brief Fills the TX FIFO until no more space or no more data.
 * 
 * @param peri Pointer to the spi_peripheral_t instance with the relevant data
 * @return true if the TX buffer had words left to send on entry; txcnt
 * then holds the number of words written so far in the transaction.
 * @return false otherwise
 */
bool spi_fill_tx(spi_peripheral_t* peri);

/**
 * @brief Empties the RX FIFO.
 * 
 * @param peri Pointer to the spi_peripheral_t instance with the relevant data
 * @return true if the RX buffer still expected words on entry; rxcnt
 * then holds the number of words read so far in the transaction.
 * @return false otherwise
 */
bool spi_empty_rx(spi_peripheral_t* peri);

/**
 * @brief Proceeds to initiate transaction once all tests passed.
 * 
 * @param peri Pointer to the relevant spi_peripheral_t instance
 * @param spi Pointer to the spi_t that requested transaction
 * @param txn Transaction data (segments, buffers, lengths)
 * @param done_cb The callback to be called once transaction is over
 * @param error_cb The callback to be called if a Hardware error occurs
 */
void spi_launch(spi_peripheral_t* peri, spi_t* spi, spi_transaction_t txn, 
                spi_callbacks_t callbacks);

/**
 * @brief Issues a command segment and increments counter (post inc.).
 *  Determines value of CSAAT bit based on if it is last segment of transaction 
 *  or not.
 * 
 * @param peri Pointer to the relevant spi_peripheral_t instance
 */
void spi_wait_transaction_done(spi_peripheral_t* peri);

/**
 * @brief Issues a command segment and increments counter (post inc.).
 *  Determines value of CSAAT bit based on if it is last segment of transaction 
 *  or not.
 * 
 * @param peri Pointer to the relevant spi_peripheral_t instance
 */
void spi_issue_next_seg(spi_peripheral_t* peri);

/**
 * @brief Resets the entire peripheral, hardware included
 * 
 * @param peri Pointer to the relevant spi_peripheral_t instance
 */
void spi_reset_peri(spi_peripheral_t* peri);

/**
 * @brief Resets the transaction-related variables of the spi_peripheral_t to 
 *  their initial values
 * 
 * @param peri Pointer to the relevant spi_peripheral_t instance
 */
void spi_reset_transaction(spi_peripheral_t* peri);

/**
 * @brief Function that gets called on each Event Interrupt. Handles all the logic
 *  of a transacton since all transactions use the interrupt.
 * 
 * @param peri Pointer to the relevant spi_peripheral_t instance
 * @param events Variable holding all the current events
 */
void spi_event_handler(spi_peripheral_t* peri, spi_event_e events);

/**
 * @brief Function that handles the harware errors. It is responsible of aborting
 *  any current transaction, resetting variables and calling the error callback if any.
 * 
 * @param peri Pointer to the relevant spi_peripheral_t instance
 * @param error Variable holding all the errors that occured
 */
void spi_error_handler(spi_peripheral_t* peri, spi_error_e error);

/****************************************************************************/
/**                                                                        **/
/**                          EXPORTED VARIABLES                            **/
/**                                                                        **/
/****************************************************************************/

/****************************************************************************/
/**                                                                        **/
/*                            GLOBAL VARIABLES                              */
/**                                                                        **/
/****************************************************************************/

/**
 * @brief Global SDK spi_t instance counter to assign each instance a unique ID.
 */
static uint32_t global_id = 0;

/**
 * @brief Static variable representing each SPI peripheral (FLASH, HOST, HOST2)
 *  We can have infinitely many spi_t variables but all reference one of these 
 *  spi_peripheral_t. Each variable here holds all the relevant information about 
 *  the current transaction the peripheral is executing.
 */
static volatile spi_peripheral_t peripherals[] = {
    (spi_peripheral_t) {
        .instance  = spi_flash,
        .txwm      = TXWM_DEFAULT,
        .rxwm      = RXWM_DEFAULT,
        .last_id   = 0,
        .timeout   = SPI_TIMEOUT_DEFAULT,
        .state     = SPI_STATE_NONE,
        .txn       = {0},
        .scnt      = 0,
        .txcnt     = 0,
        .rxcnt     = 0,
        .callbacks = {0}
    },
    (spi_peripheral_t) {
        .instance  = spi_host1,
        .txwm      = TXWM_DEFAULT,
        .rxwm      = RXWM_DEFAULT,
        .last_id   = 0,
        .timeout   = SPI_TIMEOUT_DEFAULT,
        .state     = SPI_STATE_NONE,
        .txn       = {0},
        .scnt      = 0,
        .txcnt     = 0,
        .rxcnt     = 0,
        .callbacks = {0}
    },
    (spi_peripheral_t) {
        .instance  = spi_host2,
        .txwm      = TXWM_DEFAULT,
        .rxwm      = RXWM_DEFAULT,
        .last_id   = 0,
        .timeout   = SPI_TIMEOUT_DEFAULT,
        .state     = SPI_STATE_NONE,
        .txn       = {0},
        .scnt      = 0,
        .txcnt     = 0,
        .rxcnt     = 0,
        .callbacks = {0}
    }
};

/****************************************************************************/
/**                                                                        **/
/**                          EXPORTED FUNCTIONS                            **/
/**                                                                        **/
/****************************************************************************/

spi_t spi_init(spi_idx_e idx, spi_slave_t slave) 
{
    // Make sure all parameters of the slave are valid.
    spi_codes_e error = spi_validate_slave(slave);
    // Check that the SPI peripheral identifier is valid.
    if (SPI_IDX_INVALID(idx))       error |= SPI_CODE_IDX_INVAL;
    // Since watermark is set here, not a good idea to allow for initialization.
    // Anyways not very elegant to initialize while being busy... right?
    else if (SPI_BUSY(peripherals[idx])) error |= SPI_CODE_IS_BUSY;
    if (error)
        return (spi_t) {
            .idx   = UINT32_MAX,
            .id    = 0,
            .init  = false,
            .slave = (spi_slave_t) {0}
        };
    // Enable SPI peripheral. We do not check return value since we know here that
    // it will never return an error.
    spi_set_enable(peripherals[idx].instance, true);
    spi_output_enable(peripherals[idx].instance, true);
    // Enable all error interrupts so that the SPI peripheral doesn't get stuck if
    // there is an error. And we don't check return value since we know it's error free.
    spi_set_errors_enabled(peripherals[idx].instance, SPI_ERROR_IRQALL, true);
    spi_enable_error_intr(peripherals[idx].instance, true);
    // Set the watermarks for the specific peripheral
    spi_set_tx_watermark(peripherals[idx].instance, peripherals[idx].txwm);
    spi_set_rx_watermark(peripherals[idx].instance, peripherals[idx].rxwm);
    // Just set a state so user can see it has been initialized somewhen.
    peripherals[idx].state = SPI_STATE_INIT;
    // Set the true frequency at which the SCK will be for that particular slave
    // so the user can know the real frequency.
    slave.freq = spi_true_slave_freq(slave.freq);
    return (spi_t) {
        .idx   = idx,
        .id    = ++global_id, // Pre-increment because id 0 defined as invalid
        .init  = true,
        .slave = slave
    };
}

void spi_deinit(spi_t* spi) 
{
    // Set all values to something that will prevent spi variable to be used.
    spi->idx   = UINT32_MAX;
    spi->id    = 0;
    spi->init  = false;
    spi->slave = (spi_slave_t) {0};
}

spi_codes_e spi_reset(spi_t* spi) 
{
    spi_codes_e error = spi_check_valid(spi);
    if (error) return error;
    // Reset entire peripheral
    spi_reset_peri(&peripherals[spi->idx]);

    return SPI_CODE_OK;
}

spi_codes_e spi_set_txwm(spi_t* spi, uint8_t watermark)
{
    spi_codes_e error = spi_check_valid(spi);
    if (error) return error;
    // Do not change watermark if SPI is busy
    if (SPI_BUSY(peripherals[spi->idx])) return SPI_CODE_IS_BUSY;
    // Set the new value at hardware level
    if (spi_set_tx_watermark(peripherals[spi->idx].instance, watermark))
        return SPI_CODE_WM_EXCEEDS;
    // Store the watermark if previous operation succeeded
    peripherals[spi->idx].txwm = watermark;

    return SPI_CODE_OK;
}

spi_codes_e spi_get_txwm(spi_t* spi, uint8_t* watermark)
{
    spi_codes_e error = spi_check_valid(spi);
    if (error) return error;

    *watermark = peripherals[spi->idx].txwm;

    return SPI_CODE_OK;
}

spi_codes_e spi_set_rxwm(spi_t* spi, uint8_t watermark)
{
    spi_codes_e error = spi_check_valid(spi);
    if (error) return error;
    // Do not change watermark if SPI is busy
    if (SPI_BUSY(peripherals[spi->idx])) return SPI_CODE_IS_BUSY;
    // Set the new value at hardware level
    if (spi_set_rx_watermark(peripherals[spi->idx].instance, watermark))
        return SPI_CODE_WM_EXCEEDS;
    // Store the watermark if previous operation succeeded
    peripherals[spi->idx].rxwm = watermark;

    return SPI_CODE_OK;
}

spi_codes_e spi_get_rxwm(spi_t* spi, uint8_t* watermark)
{
    spi_codes_e error = spi_check_valid(spi);
    if (error) return error;

    *watermark = peripherals[spi->idx].rxwm;

    return SPI_CODE_OK;
}

spi_codes_e spi_set_timeout(spi_t* spi, uint32_t timeout)
{
    spi_codes_e error = spi_check_valid(spi);
    if (error) return error;

    peripherals[spi->idx].timeout = timeout;

    return SPI_CODE_OK;
}

spi_codes_e spi_get_timeout(spi_t* spi, uint32_t* timeout)
{
    spi_codes_e error = spi_check_valid(spi);
    if (error) return error;

    *timeout = peripherals[spi->idx].timeout;

    return SPI_CODE_OK;
}

spi_codes_e spi_set_slave_freq(spi_t* spi, uint32_t freq)
{
    spi_codes_e error = spi_check_valid(spi);
    if (error) return error;
    // Save current freq and change to new freq to check validity
    const uint32_t old_freq = spi->slave.freq;
    spi->slave.freq = freq;
    error = spi_validate_slave(spi->slave);
    if (error) {
        // If not valid reset the frequency and return error
        spi->slave.freq = old_freq;
        return error;
    }
    // If valid set the true frequency and return OK
    spi->slave.freq = spi_true_slave_freq(freq);
    return SPI_CODE_OK;
}

spi_state_e spi_get_state(spi_t* spi) 
{
    spi_codes_e error = spi_check_valid(spi);
    if (error) return SPI_STATE_ARG_INVAL; // The spi parameter passed is invalid

    return peripherals[spi->idx].state;
}

spi_codes_e spi_transmit(spi_t* spi, const uint32_t* src_buffer, uint32_t len) 
{
    // Make validity checks and set the slave at hardware level
    spi_codes_e error = spi_prepare_transfer(spi);
    // Check that length doesn't exceed maximum and is not 0
    if (SPI_INVALID_LEN(len)) error |= SPI_CODE_TXN_LEN_INVAL;
    if (error) return error;

    // Create command segment for TX transaction
    spi_segment_t     seg = SPI_SEG_TX(len);
    // Create the transaction with the created segment
    spi_transaction_t txn = SPI_TXN_TX(&seg, src_buffer, LEN_WORDS(len));

    // Launch the transaction. All data has been verified, launch doesn't check 
    // anything. No callbacks since function is blocking.
    spi_launch(&peripherals[spi->idx], spi, txn, NULL_CALLBACKS);

    spi_wait_transaction_done(&peripherals[spi->idx]);
    // while (SPI_BUSY(peripherals[spi->idx])) wait_for_interrupt();

    return SPI_CODE_OK;
}

spi_codes_e spi_receive(spi_t* spi, uint32_t* dest_buffer, uint32_t len) 
{
    // Make validity checks and set the slave at hardware level
    spi_codes_e error = spi_prepare_transfer(spi);
    // Check that length doesn't exceed maximum and is not 0
    if (SPI_INVALID_LEN(len)) error |= SPI_CODE_TXN_LEN_INVAL;
    if (error) return error;

    // Create command segment for RX transaction
    spi_segment_t     seg = SPI_SEG_RX(len);
    // Create the transaction with the created segment
    spi_transaction_t txn = SPI_TXN_RX(&seg, dest_buffer, LEN_WORDS(len));

    // Launch the transaction. All data has been verified, launch doesn't check 
    // anything. No callbacks since function is blocking.
    spi_launch(&peripherals[spi->idx], spi, txn, NULL_CALLBACKS);

    spi_wait_transaction_done(&peripherals[spi->idx]);
    // while (SPI_BUSY(peripherals[spi->idx])) wait_for_interrupt();

    return SPI_CODE_OK;
}

spi_codes_e spi_transceive(spi_t* spi, const uint32_t* src_buffer, 
                           uint32_t* dest_buffer, uint32_t len) 
{
    // Make validity checks and set the slave at hardware level
    spi_codes_e error = spi_prepare_transfer(spi);
    // Check that length doesn't exceed maximum and is not 0
    if (SPI_INVALID_LEN(len)) error |= SPI_CODE_TXN_LEN_INVAL;
    if (error) return error;

    // Create command segment for BIDIR transaction
    spi_segment_t     seg = SPI_SEG_BIDIR(len);
    // Create the transaction with the created segment
    spi_transaction_t txn = SPI_TXN_BIDIR(&seg, src_buffer, dest_buffer, LEN_WORDS(len));

    // Launch the transaction. All data has been verified, launch doesn't check 
    // anything. No callbacks since function is blocking.
    spi_launch(&peripherals[spi->idx], spi, txn, NULL_CALLBACKS);

    spi_wait_transaction_done(&peripherals[spi->idx]);
    // while (SPI_BUSY(peripherals[spi->idx])) wait_for_interrupt();

    return SPI_CODE_OK;
}

spi_codes_e spi_execute(spi_t* spi, const spi_segment_t* segments, 
                        uint32_t segments_len, const uint32_t* src_buffer, 
                        uint32_t* dest_buffer) 
{
    // Make validity checks and set the slave at hardware level
    spi_codes_e error = spi_prepare_transfer(spi);
    if (error) return error;

    // Create the transaction with the provided segments
    spi_transaction_t txn = SPI_TXN(segments, segments_len, src_buffer, dest_buffer);

    // We check every segment for validity since they are defined by user.
    // This function also counts the number of words of TX and RX the entire
    // transaction is composed of.
    if (!spi_validate_segments(txn.segments, txn.seglen, &txn.txlen, &txn.rxlen)) 
        return SPI_CODE_SEGMENT_INVAL;

    // Launch the transaction. All data has been verified, launch doesn't check 
    // anything. No callbacks since function is blocking.
    spi_launch(&peripherals[spi->idx], spi, txn, NULL_CALLBACKS);

    spi_wait_transaction_done(&peripherals[spi->idx]);
    // while (SPI_BUSY(peripherals[spi->idx])) wait_for_interrupt();

    return SPI_CODE_OK;
}

spi_codes_e spi_transmit_nb(spi_t* spi, const uint32_t* src_buffer, uint32_t len, 
                            spi_callbacks_t callbacks) 
{
    // Make validity checks and set the slave at hardware level
    spi_codes_e error = spi_prepare_transfer(spi);
    // Check that length doesn't exceed maximum and is not 0
    if (SPI_INVALID_LEN(len)) error |= SPI_CODE_TXN_LEN_INVAL;
    if (error) return error;

    // Create command segment for TX transaction
    spi_segment_t     seg = SPI_SEG_TX(len);
    // Create the transaction with the created segment
    spi_transaction_t txn = SPI_TXN_TX(&seg, src_buffer, LEN_WORDS(len));

    // Launch the transaction. All data has been verified, launch doesn't check 
    // anything. Here user callbacks are used because non-blocking function.
    spi_launch(&peripherals[spi->idx], spi, txn, callbacks);

    return SPI_CODE_OK;
}

spi_codes_e spi_receive_nb(spi_t* spi, uint32_t* dest_buffer, uint32_t len, 
                           spi_callbacks_t callbacks) 
{
    // Make validity checks and set the slave at hardware level
    spi_codes_e error = spi_prepare_transfer(spi);
    // Check that length doesn't exceed maximum and is not 0
    if (SPI_INVALID_LEN(len)) error |= SPI_CODE_TXN_LEN_INVAL;
    if (error) return error;

    // Create command segment for RX transaction
    spi_segment_t     seg = SPI_SEG_RX(len);
    // Create the transaction with the created segment
    spi_transaction_t txn = SPI_TXN_RX(&seg, dest_buffer, LEN_WORDS(len));

    // Launch the transaction. All data has been verified, launch doesn't check 
    // anything. Here user callbacks are used because non-blocking function.
    spi_launch(&peripherals[spi->idx], spi, txn, callbacks);

    return SPI_CODE_OK;
}

spi_codes_e spi_transceive_nb(spi_t* spi, const uint32_t* src_buffer, 
                              uint32_t* dest_buffer, uint32_t len, 
                              spi_callbacks_t callbacks) 
{
    // Make validity checks and set the slave at hardware level
    spi_codes_e error = spi_prepare_transfer(spi);
    // Check that length doesn't exceed maximum and is not 0
    if (SPI_INVALID_LEN(len)) error |= SPI_CODE_TXN_LEN_INVAL;
    if (error) return error;

    // Create command segment for BIDIR transaction
    spi_segment_t     seg = SPI_SEG_BIDIR(len);
    // Create the transaction with the created segment
    spi_transaction_t txn = SPI_TXN_BIDIR(&seg, src_buffer, dest_buffer, LEN_WORDS(len));

    // Launch the transaction. All data has been verified, launch doesn't check 
    // anything. Here user callbacks are used because non-blocking function.
    spi_launch(&peripherals[spi->idx], spi, txn, callbacks);

    return SPI_CODE_OK;
}

spi_codes_e spi_execute_nb(spi_t* spi, const spi_segment_t* segments, 
                           uint32_t segments_len, const uint32_t* src_buffer, 
                           uint32_t* dest_buffer, spi_callbacks_t callbacks) 
{
    // Make validity checks and set the slave at hardware level
    spi_codes_e error = spi_prepare_transfer(spi);
    if (error) return error;

    // Create the transaction with the provided segments
    spi_transaction_t txn = SPI_TXN(segments, segments_len, src_buffer, dest_buffer);

    // We check every segment for validity since they are defined by user.
    // This function also counts the number of words of TX and RX the entire
    // transaction is composed of.
    if (!spi_validate_segments(txn.segments, txn.seglen, &txn.txlen, &txn.rxlen)) 
        return SPI_CODE_SEGMENT_INVAL;

    // Launch the transaction. All data has been verified, launch doesn't check 
    // anything. Here user callbacks are used because non-blocking function.
    spi_launch(&peripherals[spi->idx], spi, txn, callbacks);

    return SPI_CODE_OK;
}

/****************************************************************************/
/**                                                                        **/
/*                            LOCAL FUNCTIONS                               */
/**                                                                        **/
/****************************************************************************/

spi_codes_e spi_check_valid(spi_t* spi) 
{
    // Is SPI peripheral identifier valid?
    if (SPI_IDX_INVALID(spi->idx)) return SPI_CODE_IDX_INVAL;
    // Has the spi been initialized (i.e. base validity checks made)?
    if (!spi->init)                return SPI_CODE_NOT_INIT;
    return SPI_CODE_OK;
}

spi_codes_e spi_validate_slave(spi_slave_t slave) 
{
    spi_codes_e error = SPI_CODE_OK;
    // Is chip select line number a valid one?
    if (SPI_CSID_INVALID(slave.csid)) error |= SPI_CODE_SLAVE_CSID_INVAL;
    // Is the slave max frequency less than the minimum frequency?
    if (slave.freq < SPI_MIN_FREQ)    error |= SPI_CODE_SLAVE_FREQ_INVAL;
    return error;
}

spi_codes_e spi_set_slave(spi_t* spi) 
{
    // Compute the best clock divider
    uint16_t clk_div = 0;
    if (spi->slave.freq < SYS_FREQ / 2)
    {
        clk_div = (SYS_FREQ / spi->slave.freq - 2) / 2;
        if (SYS_FREQ / (2 * clk_div + 2) > spi->slave.freq) clk_div++;
    }
    // Build the HAL configopts to be set based on our slave
    spi_configopts_t config = {
        .clkdiv   = clk_div,
        .csnidle  = spi->slave.csn_idle,
        .csntrail = spi->slave.csn_trail,
        .csnlead  = spi->slave.csn_lead,
        .fullcyc  = spi->slave.full_cycle,
        .cpha     = bitfield_read(spi->slave.data_mode, BIT_MASK_1, DATA_MODE_CPHA_OFFS),
        .cpol     = bitfield_read(spi->slave.data_mode, BIT_MASK_1, DATA_MODE_CPOL_OFFS)
    };
    // Set the configopts
    spi_return_flags_e config_error = spi_set_configopts(peripherals[spi->idx].instance, 
                                                         spi->slave.csid,
                                                         spi_create_configopts(config));
    // CSID is invalid! This can only happen if user didn't properly initialize spi_t!
    if (config_error) return SPI_CODE_SLAVE_INVAL;
    // We already made sure csid was valid by calling spi_set_configopts. And we know
    // instance is not NULL by definition. Hence won't return any errors.
    spi_set_csid(peripherals[spi->idx].instance, spi->slave.csid);
    return SPI_CODE_OK;
}

spi_codes_e spi_prepare_transfer(spi_t* spi) 
{
    // Check the idx and init of spi_t parameter.
    // Notice that we do not check for slave's validity. This is because we assume
    // that the user properly initialized his spi_t and didn't change its slave.
    // Anyway spi_set_slave will give an error if the slave is invalid. But user
    // should follow guidelines!
    spi_codes_e error = spi_check_valid(spi);
    if (error) return error;

    // If busy don't start a new transaction...
    if (SPI_BUSY(peripherals[spi->idx])) return SPI_CODE_IS_BUSY;
    // Check also at hardware level if busy, we don't know if maybe there is a
    // problem somewhere
    if (spi_get_active(peripherals[spi->idx].instance) == SPI_TRISTATE_TRUE) 
        return SPI_CODE_NOT_IDLE;

    // If the last spi instance was NOT the same as the current, slave may have
    // changed, therefore set the "new" slave. Otherwise don't bother.
    if (spi->id != peripherals[spi->idx].last_id)
    {
        error = spi_set_slave(spi);
        if (error) return error;
    }

    return SPI_CODE_OK;
}

uint32_t spi_true_slave_freq(uint32_t freq) 
{
    // Compute the best clock divider
    uint16_t clk_div = 0;
    if (freq < SYS_FREQ / 2) 
    {
        clk_div = (SYS_FREQ / freq - 2) / 2;
        if (SYS_FREQ / (2 * clk_div + 2) > freq) clk_div++;
    }
    // Based on the computed divider return the true frequency the SCK will be at
    return SYS_FREQ / (2 * clk_div + 2);
}

bool spi_validate_segments(const spi_segment_t* segments, uint32_t segments_len, 
                           uint32_t* tx_count, uint32_t* rx_count) 
{
    // Check that there are any segments
    if (segments_len == 0) return false;

    // Make sure our word counters start at 0
    *tx_count = 0;
    *rx_count = 0;

    for (int i = 0; i < segments_len; i++)
    {
        // Check that speed and direction are compatible and valid.
        // Unfortunately this check will be done twice since when we set the command
        // through the HAL the check will be done again.
        // The problem is that, since starting a full transaction before being sure
        // that all segments are valid would be undesirable, we have to check each
        // segment before initiating a transaction.
        uint8_t direction = bitfield_read(segments[i].mode, DIR_SPD_MASK, DIR_INDEX);
        uint8_t speed     = bitfield_read(segments[i].mode, DIR_SPD_MASK, SPD_INDEX);
        if (!spi_validate_cmd(direction, speed)) return false;
        // Translate bytes len to words len
        uint32_t word_len = LEN_WORDS(segments[i].len);
        // Increase corresponding counter. There are dummy cycles, hence we need to
        // specifically check for the exact direction.
        if (direction == SPI_DIR_TX_ONLY || direction == SPI_DIR_BIDIR) 
            *tx_count += word_len;
        if (direction == SPI_DIR_RX_ONLY || direction == SPI_DIR_BIDIR) 
            *rx_count += word_len;
    }

    return true;
}

bool spi_fill_tx(spi_peripheral_t* peri) 
{
    // If we have a TX buffer and didn't exceed the count then fill the TX FIFO
    if (peri->txn.txbuffer != NULL && peri->txcnt < peri->txn.txlen) {
        // While there is still data to be fed and there wasn't an error from HAL
        // continue. HAL error in this case means that the fifo is full since
        // it's the only possibility.
        while (
            peri->txcnt < peri->txn.txlen 
            && !spi_write_word(peri->instance, peri->txn.txbuffer[peri->txcnt])
        ) peri->txcnt++; // Keep track of counter
        return true;
    }
    return false;
}

bool spi_empty_rx(spi_peripheral_t* peri) 
{
    // If we have a RX buffer and didn't exceed the count then read from RX FIFO
    if (peri->txn.rxbuffer != NULL && peri->rxcnt < peri->txn.rxlen) {
        // While there is still data to be read and there wasn't an error from HAL
        // continue. HAL error in this case means that the fifo is empty since
        // it's the only possibility.
        while (
            peri->rxcnt < peri->txn.rxlen 
            && !spi_read_word(peri->instance, &peri->txn.rxbuffer[peri->rxcnt])
        ) peri->rxcnt++; // Keep track of counter
        return true;
    }
    return false;
}

void spi_launch(spi_peripheral_t* peri, spi_t* spi, spi_transaction_t txn, 
                spi_callbacks_t callbacks) 
{
    // All checks have been made, therefore there can't be any error here.
    // This also means that we can safely set the state since we know we will
    // proceed to launch without any doubt.
    peri->state     = SPI_STATE_BUSY;
    // Set all transaction data to our static peripheral variable
    peri->txn       = txn;
    // Indicate the callbacks that should be called
    peri->callbacks = callbacks;

    // Fill the TX fifo before starting so there is data once command launched
    spi_fill_tx(peri);

    // Enable event interrupts since they are enabled only during a transaction
    spi_set_events_enabled(peri->instance, TRIGGERING_EVENTS, true);
    spi_enable_evt_intr   (peri->instance, true);

    // Wait for the SPI peripheral to be ready before writing a command segment.
    spi_wait_for_ready(peri->instance);
    // Write command segment. This immediately triggers the SPI peripheral into action.
    spi_issue_next_seg(peri);
}

void spi_wait_transaction_done(spi_peripheral_t* peri) 
{
    // Convert ms timeout to clock ticks
    uint64_t timeout_ticks = ((uint64_t) peri->timeout) * (SYS_FREQ / 1000);
    uint32_t start[2];
    uint32_t end[2];

    // Enable tick counter
    CSR_CLEAR_BITS(CSR_REG_MCOUNTINHIBIT, 0x1);
    // Record start tick counter value
    CSR_READ(CSR_REG_MCYCLE,  &start[0]);
    CSR_READ(CSR_REG_MCYCLEH, &start[1]);

    // Wait until transaction has finished or timed-out
    do
    {
        // Read tick counter value
        CSR_READ(CSR_REG_MCYCLE,  &end[0]);
        CSR_READ(CSR_REG_MCYCLEH, &end[1]);
        // If ticks elapsed exceed timeout ticks, cancel transaction and return
        if (*((uint64_t*)end) - *((uint64_t*)start) > timeout_ticks)
        {
            // Fully reset spi peripheral to cancel transaction, empty fifos, etc.
            spi_reset_peri(peri);
            // Indicate to user the transaction has timed-out
            peri->state = SPI_STATE_TIMEOUT;
            break;
        }
        
    } while (SPI_BUSY((*peri)));
}

void spi_issue_next_seg(spi_peripheral_t* peri) 
{
    const spi_segment_t seg = peri->txn.segments[peri->scnt];
    peri->scnt++;
    // Construct our word command to be passed to HAL
    uint32_t cmd_reg = spi_create_command((spi_command_t) {
        .len       = seg.len - 1, // -1 because of SPI Host IP specifications
        .csaat     = peri->txn.seglen == peri->scnt ? false : true,
        .speed     = bitfield_read(seg.mode, DIR_SPD_MASK, SPD_INDEX),
        .direction = bitfield_read(seg.mode, DIR_SPD_MASK, DIR_INDEX),
    });
    // Since all checks were already made we do not need to check the result of function
    spi_set_command(peri->instance, cmd_reg);
}

void spi_reset_peri(spi_peripheral_t* peri) 
{
    // Reset static peripheral variables
    spi_reset_transaction(peri);
    // Reset the SPI peripheral (at hardware level)
    spi_sw_reset(peri->instance);
    // Enable SPI peripheral. We do not check return value since we know here that
    // it will never return an error.
    spi_set_enable(peri->instance, true);
    spi_output_enable(peri->instance, true);
    // Enable all error interrupts so that the SPI peripheral doesn't get stuck if
    // there is an error. And we don't check return value since we know it's error free.
    spi_set_errors_enabled(peri->instance, SPI_ERROR_IRQALL, true);
    spi_enable_error_intr(peri->instance, true);
    // Set the watermarks for the specific peripheral.
    spi_set_tx_watermark(peri->instance, peri->txwm);
    spi_set_rx_watermark(peri->instance, peri->rxwm);
    // Just reset the state.
    peri->state = SPI_STATE_INIT;
    // Force the next transaction to set the slave at hardware level
    peri->last_id = 0;
}

void spi_reset_transaction(spi_peripheral_t* peri) 
{
    // Reset all variables relative to the transaction of the static peripheral
    // instance
    peri->scnt      = 0;
    peri->txcnt     = 0;
    peri->rxcnt     = 0;
    peri->txn       = (spi_transaction_t) {0};
    peri->callbacks = NULL_CALLBACKS;
}

void spi_event_handler(spi_peripheral_t* peri, spi_event_e events) 
{
    // Ready means it is ready to accept new command segments. So we have two
    // possibilities if the device is ready:
    //  1) It is ready but not idle
    //  2) It is ready and idle
    if (events & SPI_EVENT_READY) 
    {
        // If SPI is ready and there are still commands to execute, issue next command
        if (peri->txn.segments != NULL && peri->scnt < peri->txn.seglen) 
        {
            spi_issue_next_seg(peri);
        }
        // If no more commands and SPI is idle, it means the transaction is over
        else if (events & SPI_EVENT_IDLE) 
        {
            // Disable all event interrupts
            spi_set_events_enabled(peri->instance, SPI_EVENT_ALL, false);
            spi_enable_evt_intr   (peri->instance, false);
            // Read the last data from the RX fifo
            bool rx_read = spi_empty_rx(peri);
            // A callback can start a new transaction, so end this one first
            // and call its callbacks with copies of its arguments.
            const spi_callbacks_t callbacks = peri->callbacks;
            const uint32_t* txbuffer = peri->txn.txbuffer;
            uint32_t* rxbuffer = peri->txn.rxbuffer;
            uint32_t txcnt = peri->txcnt;
            uint32_t rxcnt = peri->rxcnt;
            // Set the state to Transaction is done (meaning successful)
            peri->state = SPI_STATE_DONE;
            // Reset all transaction related variables
            spi_reset_transaction(peri);
            // The same status sample can also hold RXWM, and the return below
            // skips the RXWM block, so call the RXWM callback here.
            if (rx_read && (events & SPI_EVENT_RXWM) && callbacks.rxwm_cb != NULL)
            {
                callbacks.rxwm_cb(txbuffer, txcnt, rxbuffer, rxcnt);
            }
            // If there is a callback defined call it
            if (callbacks.done_cb != NULL)
            {
                callbacks.done_cb(txbuffer, txcnt, rxbuffer, rxcnt);
            }
            return;
        }
    }
    if (events & SPI_EVENT_TXWM)
    {
        // TX watermark reached. Refill TX fifo if more data
        // If there is a callback defined call it
        if (spi_fill_tx(peri) && peri->callbacks.txwm_cb != NULL)
        {
            peri->callbacks.txwm_cb(peri->txn.txbuffer, peri->txcnt, 
                                    peri->txn.rxbuffer, peri->rxcnt);
        }
    }
    if (events & SPI_EVENT_RXWM)
    {
        // RX watermark reached. Empty RX fifo to get more data
        // If there is a callback defined call it
        if (spi_empty_rx(peri) && peri->callbacks.rxwm_cb != NULL)
        {
            peri->callbacks.rxwm_cb(peri->txn.txbuffer, peri->txcnt, 
                                    peri->txn.rxbuffer, peri->rxcnt);
        }
    }
}

void spi_error_handler(spi_peripheral_t* peri, spi_error_e error) 
{
    // Disable event interrupts
    spi_set_events_enabled(peri->instance, SPI_EVENT_ALL, false);
    spi_enable_evt_intr   (peri->instance, false);
    // If there is a callback defined invoke it
    if (peri->callbacks.error_cb != NULL) 
    {
        peri->callbacks.error_cb(peri->txn.txbuffer, peri->txcnt, 
                                 peri->txn.rxbuffer, peri->rxcnt);
    }
    spi_reset_peri(peri);
    // Set the state to error
    peri->state = SPI_STATE_ERROR;
}

/****************************************************************************/
/**                                                                        **/
/*                               INTERRUPTS                                 */
/**                                                                        **/
/****************************************************************************/

/**
 * @brief Implementation of the weak function of the HAL
 */
void spi_intr_handler_event_flash(spi_event_e events) 
{
    if (SPI_NOT_BUSY(peripherals[SPI_IDX_FLASH])) return;
    spi_event_handler(&peripherals[SPI_IDX_FLASH], events);
}

/**
 * @brief Implementation of the weak function of the HAL
 */
void spi_intr_handler_error_flash(spi_error_e errors) 
{
    if (SPI_NOT_BUSY(peripherals[SPI_IDX_FLASH])) return;
    spi_error_handler(&peripherals[SPI_IDX_FLASH], errors);
}

/**
 * @brief Implementation of the weak function of the HAL
 */
void spi_intr_handler_event_host(spi_event_e events) 
{
    if (SPI_NOT_BUSY(peripherals[SPI_IDX_HOST])) return;
    spi_event_handler(&peripherals[SPI_IDX_HOST], events);
}

/**
 * @brief Implementation of the weak function of the HAL
 */
void spi_intr_handler_error_host(spi_error_e errors) 
{
    if (SPI_NOT_BUSY(peripherals[SPI_IDX_HOST])) return;
    spi_error_handler(&peripherals[SPI_IDX_HOST], errors);
}

/**
 * @brief Implementation of the weak function of the HAL
 */
void spi_intr_handler_event_host2(spi_event_e events) 
{
    if (SPI_NOT_BUSY(peripherals[SPI_IDX_HOST_2])) return;
    spi_event_handler(&peripherals[SPI_IDX_HOST_2], events);
}

/**
 * @brief Implementation of the weak function of the HAL
 */
void spi_intr_handler_error_host2(spi_error_e errors) 
{
    if (SPI_NOT_BUSY(peripherals[SPI_IDX_HOST_2])) return;
    spi_error_handler(&peripherals[SPI_IDX_HOST_2], errors);
}

/****************************************************************************/
/**                                                                        **/
/**                                EOF                                     **/
/**                                                                        **/
/****************************************************************************/
