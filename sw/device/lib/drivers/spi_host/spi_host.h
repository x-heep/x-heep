/*
                              *******************
******************************* C SOURCE FILE *****************************
**                            *******************
**
** project  : X-HEEP
** filename : spi_host.h
** version  : 1
** date     : 06/03/24
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
* @file   spi_host.h
* @date   06/03/24
* @author Llorenç Muela
* @brief  The Serial Peripheral Interface (SPI) driver to set up and use the
* SPI peripheral
*/

#ifndef _DRIVERS_SPI_HOST_H_
#define _DRIVERS_SPI_HOST_H_

/****************************************************************************/
/**                                                                        **/
/**                            MODULES USED                                **/
/**                                                                        **/
/****************************************************************************/

#include <stdint.h>
#include <stdbool.h>

#include "fast_intr_ctrl.h"

#include "spi_host_regs.h"       // Generated
#include "spi_host_structs.h"    // Generated

/****************************************************************************/
/**                                                                        **/
/**                       DEFINITIONS AND MACROS                           **/
/**                                                                        **/
/****************************************************************************/

#define SPI_CSID_INVALID(csid)  csid >= SPI_HOST_PARAM_NUM_C_S

#define spi_host1_peri ((volatile spi_host *) SPI_HOST_START_ADDRESS)
#define spi_host2_peri ((volatile spi_host *) SPI2_START_ADDRESS)
#define spi_flash_peri ((volatile spi_host *) SPI_FLASH_START_ADDRESS)

#define spi_host1 ((spi_host_t*) spi_host1_peri)
#define spi_host2 ((spi_host_t*) spi_host2_peri)
#define spi_flash ((spi_host_t*) spi_flash_peri)

#define SPI_HW(spi_inst) ((volatile spi_host *) spi_inst)

// Sanity check to return retval when spi is NULL.
// For development purposes. If 100% sure spi will NEVER be NULL, comment out
// the macro expansion to speed up SPI HAL.
#define SPI_NULL_CHECK(spi,retval) if (spi == NULL) return retval;

#ifdef __cplusplus
extern "C" {
#endif

/****************************************************************************/
/**                                                                        **/
/**                       TYPEDEFS AND STRUCTURES                          **/
/**                                                                        **/
/****************************************************************************/

/**
* SPI endianness
*/
typedef enum {
    SPI_BYTE_ORDER_BIG_ENDIAN      = 0,
    SPI_BYTE_ORDER_LITTLE_ENDIAN   = 1
} spi_byte_order_e;

/**
* SPI speed type
*/
typedef enum {
    SPI_SPEED_STANDARD   = 0,
    SPI_SPEED_DUAL       = 1,
    SPI_SPEED_QUAD       = 2
} spi_speed_e;

/**
* SPI directionality
*/
typedef enum {
    SPI_DIR_DUMMY       = 0,
    SPI_DIR_RX_ONLY     = 1,
    SPI_DIR_TX_ONLY     = 2,
    SPI_DIR_BIDIR       = 3
} spi_dir_e;

/**
* SPI events
*/
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

/**
* SPI errors
*/
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

/**
* SPI functions return flags, informs user what problem there was or if all OK
*/
typedef enum {
    // Everithing went well
    SPI_FLAG_OK                 = 0x0000,
    // The SPI variabled passed was a null pointer
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

/**
* Extended bool to return if a function catched an error
*/
typedef enum {
    SPI_TRISTATE_ERROR  = 0,
    SPI_TRISTATE_TRUE   = 1,
    SPI_TRISTATE_FALSE  = 2
} spi_tristate_e;

/**
 * Opaque structure definition to hide the registers.
 */
typedef struct spi_s spi_host_t;

/**
* SPI chip (slave) configuration structure
*/
typedef struct spi_configopts_s {
    // The clock divider to use with a paricular slave
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

/**
* SPI command structure
*/
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

/**
* SPI status structure
*/
typedef struct spi_status_s {
    union {
        struct {
            // TX queue depth (how many unsent words are in the FIFO)
            uint8_t txqd        : 8;
            // RX queue depth (how many unread words are in the FIFO)
            uint8_t rxqd        : 8;
            // CMD queue depth (how many unprocessed commands are in the FIFO)
            uint8_t cmdqd       : 4;
            // Indicates wether rxqd is above the RX Watermark
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
            // Indicates wether txqd is below the TX Watermark
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
        };
        uint32_t value; // This allows accessing all the bitfields as a single 32-bit integer
    };
} spi_status_t;


/****************************************************************************/
/**                                                                        **/
/**                          EXPORTED VARIABLES                            **/
/**                                                                        **/
/****************************************************************************/

/****************************************************************************/
/**                                                                        **/
/**                          EXPORTED FUNCTIONS                            **/
/**                                                                        **/
/****************************************************************************/

/**
 * @brief Get enabled events for a specified SPI peripheral.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param events Pointer to store enabled event interrupts.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
spi_return_flags_e spi_get_events_enabled(spi_host_t* spi, spi_event_e* events);

/**
 * @brief Set enabled events for a specified SPI peripheral.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param events Pointer to events to enable/disable and to store the currently enabled
 *               event interrupts.
 * @param enable Flag to enable (true) or disable (false) the specified event interrupts.
 * @return SPI_FLAG_NULL_PTR      if spi NULL pointer.
 * @return SPI_FLAG_EVENT_INVALID if events not valid.
 * @return SPI_FLAG_OK            if success.
 */
spi_return_flags_e spi_set_events_enabled(spi_host_t* spi, spi_event_e events, bool enable);

/**
 * @brief Get enabled error interrupts for a specified SPI peripheral.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param errors Pointer to store enabled error interrupts.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
spi_return_flags_e spi_get_errors_enabled(spi_host_t* spi, spi_error_e* errors);

/**
 * @brief Set enabled error interrupts for a specified SPI peripheral.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param errors Pointer to error interrupts to enable/disable and to store the currently
 *               enabled error interrupts.
 * @param enable Flag to enable (true) or disable (false) the specified error interrupts.
 * @return SPI_FLAG_NULL_PTR      if spi NULL pointer.
 * @return SPI_FLAG_ERROR_INVALID if errors not valid.
 * @return SPI_FLAG_OK            if success.
 */
spi_return_flags_e spi_set_errors_enabled(spi_host_t* spi, spi_error_e errors, bool enable);

/**
 * @brief Get the errors that have raised if any.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param errors Pointer to store the errors.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
spi_return_flags_e spi_get_errors(spi_host_t* spi, spi_error_e* errors);

/**
 * @brief Acknoledge the errors that have raised once solved in order to renable 
 *        the SPI peripheral operation.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
spi_return_flags_e spi_acknowledge_errors(spi_host_t* spi);

/**
 * @brief Enable or disable error interrupt test mode for a specified SPI peripheral.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param enable Flag to enable (true) or disable (false) error interrupt test mode.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
spi_return_flags_e spi_enable_error_intr_test(spi_host_t* spi, bool enable);

/**
 * @brief Enable or disable event interrupt test mode for a specified SPI peripheral.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param enable Flag to enable (true) or disable (false) event interrupt test mode.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
spi_return_flags_e spi_enable_evt_intr_test(spi_host_t* spi, bool enable);

/**
 * @brief Trigger a fatal fault test alert for a specified SPI peripheral.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
spi_return_flags_e spi_alert_test_fatal_fault_trigger(spi_host_t* spi);

/**
 * @brief Read the TX FIFO depth register.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return TX FIFO depth. UINT8_MAX if spi is NULL.
 */
volatile uint8_t spi_get_tx_queue_depth(spi_host_t* spi);

/**
 * @brief Read the RX FIFO depth register.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return RX FIFO depth. UINT8_MAX if spi is NULL.
 */
volatile uint8_t spi_get_rx_queue_depth(spi_host_t* spi);

/**
 * @brief Read the Chip Select (CS) ID register.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return Chip Select (CS) ID. UINT32_MAX if spi is NULL.
 */
volatile uint32_t spi_get_csid(spi_host_t* spi);

/**
 * @brief Reset the SPI from software.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
spi_return_flags_e spi_sw_reset(spi_host_t* spi);

/**
 * @brief Enable the SPI host.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param enable SPI enable register value.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
spi_return_flags_e spi_set_enable(spi_host_t* spi, bool enable);

/**
 * @brief Set the transmit queue watermark level (to enable interrupt triggering).
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param watermark Queue/fifo trigger level (minimum level).
 * @return SPI_FLAG_NULL_PTR          if spi NULL pointer.
 * @return SPI_FLAG_WATERMARK_EXCEEDS if watermark exceeds max (currently 76).
 * @return SPI_FLAG_OK                if success.
 */
spi_return_flags_e spi_set_tx_watermark(spi_host_t* spi, uint8_t watermark);

/**
 * @brief Set the receive queue watermark level (to enable interrupt triggering).
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param watermark Queue/fifo trigger level (maximum level).
 * @return SPI_FLAG_NULL_PTR          if spi NULL pointer.
 * @return SPI_FLAG_WATERMARK_EXCEEDS if watermark exceeds max (currently 64).
 * @return SPI_FLAG_OK                if success.
 */
spi_return_flags_e spi_set_rx_watermark(spi_host_t* spi, uint8_t watermark);

/**
 * @brief Set the requirement of a target device (slave).
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param csid Chip Select (CS) ID.
 * @param conf_reg Slave configuration.
 * @return SPI_FLAG_NULL_PTR     if spi NULL pointer.
 * @return SPI_FLAG_CSID_INVALID if csid out of range.
 * @return SPI_FLAG_OK           if success.
 */
spi_return_flags_e spi_set_configopts(spi_host_t* spi, uint32_t csid, const uint32_t conf_reg);

/**
 * @brief Get the requirement of a target device (slave).
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param csid Chip Select (CS) ID.
 * @param conf_reg Where slave configuration gets stored.
 * @return SPI_FLAG_NULL_PTR     if spi NULL pointer.
 * @return SPI_FLAG_CSID_INVALID if csid out of range.
 * @return SPI_FLAG_OK           if success.
 */
spi_return_flags_e spi_get_configopts(spi_host_t* spi, uint32_t csid, uint32_t* conf_reg);

/**
 * @brief Select which device to target with the next command.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param csid Chip Select (SC) ID.
 * @return SPI_FLAG_NULL_PTR     if spi NULL pointer.
 * @return SPI_FLAG_CSID_INVALID if csid out of range.
 * @return SPI_FLAG_OK           if success.
 */
spi_return_flags_e spi_set_csid(spi_host_t* spi, uint32_t csid);

/**
 * @brief Set the next command (one for all attached SPI devices).
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param cmd_reg Command register value (Length, speed, ...).
 * @return SPI_FLAG_NULL_PTR      if spi NULL pointer.
 * @return SPI_FLAG_SPEED_INVALID if direction and speed incompatible.
 * @return SPI_FLAG_NOT_READY     if SPI Host not ready.
 * @return SPI_FLAG_OK            if success.
 */
spi_return_flags_e spi_set_command(spi_host_t* spi, uint32_t cmd_reg);

/**
 * @brief Write one word to the TX FIFO.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param wdata Data to write.
 * @return SPI_FLAG_NULL_PTR      if spi NULL pointer.
 * @return SPI_FLAG_TX_QUEUE_FULL if TX FIFO is full.
 * @return SPI_FLAG_OK            if success.
 */
spi_return_flags_e spi_write_word(spi_host_t* spi, uint32_t wdata);

/**
 * @brief Write a byte of data to the transmit queue of a specified SPI peripheral.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param bdata Byte of data to write.
 * @return SPI_FLAG_NULL_PTR      if spi NULL pointer.
 * @return SPI_FLAG_TX_QUEUE_FULL if TX FIFO is full.
 * @return SPI_FLAG_OK            if success.
 */
spi_return_flags_e spi_write_byte(spi_host_t* spi, uint8_t bdata);

/**
 * @brief Read one word to the RX FIFO.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param rdata Read data.
 * @return SPI_FLAG_NULL_PTR       if spi NULL pointer.
 * @return SPI_FLAG_RX_QUEUE_EMPTY if RX FIFO is empty.
 * @return SPI_FLAG_OK             if success.
 */
spi_return_flags_e spi_read_word(spi_host_t* spi, uint32_t* dst);

/**
 * @brief Enable SPI event interrupt
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param enable SPI event interrupt bit value.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
spi_return_flags_e spi_enable_evt_intr(spi_host_t* spi, bool enable);

/**
 * @brief Enable SPI error interrupt
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param enable SPI error interrupt bit value.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
spi_return_flags_e spi_enable_error_intr(spi_host_t* spi, bool enable);

/**
 * @brief Enable SPI output
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param enable SPI TX empty interrupt bit value.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
spi_return_flags_e spi_output_enable(spi_host_t* spi, bool enable);

/****************************************************************************/
/**                                                                        **/
/**                          INLINE FUNCTIONS                              **/
/**                                                                        **/
/****************************************************************************/

/**
 * @brief Check if a given direction and speed are compatible.
 * i.e. bidirectional communication only possible at standard speed
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param direction spi_dir_e direction of communication.
 * @param speed spi_speed_e speed of communication.
 * @return true if compatible false otherwise.
 */
static inline __attribute__((always_inline)) 
bool spi_validate_cmd(uint8_t direction, uint8_t speed)
{
    if (speed > SPI_SPEED_QUAD || direction > SPI_DIR_BIDIR || 
       (direction == SPI_DIR_BIDIR && speed != SPI_SPEED_STANDARD))
        return false;
    else 
        return true;
}

/**
 * @brief Get the state of the event interrupt flag (indicates if event has been 
 *        triggered).
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_TRISTATE_ERROR if null pointer, else SPI_TRISTATE_TRUE if flag active 
 *         or SPI_TRISTATE_FALSE if not active.
 */
static inline __attribute__((always_inline)) 
spi_tristate_e spi_get_evt_intr_state(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_TRISTATE_ERROR)

    if (bitfield_read(SPI_HW(spi)->INTR_STATE, BIT_MASK_1, 
                      SPI_HOST_INTR_STATE_SPI_EVENT_BIT))
        return SPI_TRISTATE_TRUE;
    else
        return SPI_TRISTATE_FALSE;
}

/**
 * @brief Get the state of the error interrupt flag (indicates if error has been 
 *        triggered).
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_TRISTATE_ERROR if null pointer, else SPI_TRISTATE_TRUE if flag active 
 *         or SPI_TRISTATE_FALSE if not active.
 */
static inline __attribute__((always_inline)) 
spi_tristate_e spi_get_error_intr_state(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_TRISTATE_ERROR)

    if (bitfield_read(SPI_HW(spi)->INTR_STATE, BIT_MASK_1,
                      SPI_HOST_INTR_STATE_ERROR_BIT))
        return SPI_TRISTATE_TRUE;
    else
        return SPI_TRISTATE_FALSE;
}

/**
 * @brief Check if event interrupts are enabled.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_TRISTATE_ERROR if null pointer, else SPI_TRISTATE_TRUE if enabled 
 *         or SPI_TRISTATE_FALSE otherwise.
 */
static inline __attribute__((always_inline))
spi_tristate_e spi_get_evt_intr_enable(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_TRISTATE_ERROR)

    if (bitfield_read(SPI_HW(spi)->INTR_ENABLE, BIT_MASK_1,
                      SPI_HOST_INTR_ENABLE_SPI_EVENT_BIT))
        return SPI_TRISTATE_TRUE;
    else
        return SPI_TRISTATE_FALSE;
}

/**
 * @brief Check if error interrupts are enabled.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_TRISTATE_ERROR if null pointer, else SPI_TRISTATE_TRUE if enabled 
 *         or SPI_TRISTATE_FALSE otherwise.
 */
static inline __attribute__((always_inline))
spi_tristate_e spi_get_error_intr_enable(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_TRISTATE_ERROR)

    if (bitfield_read(SPI_HW(spi)->INTR_ENABLE, BIT_MASK_1,
                      SPI_HOST_INTR_ENABLE_ERROR_BIT))
        return SPI_TRISTATE_TRUE;
    else
        return SPI_TRISTATE_FALSE;
}

/**
 * @brief Read SPI status register
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return Pointer to spi_status_t structure. NULL if spi is NULL.
 */
static inline __attribute__((always_inline)) 
const volatile spi_status_t spi_get_status(spi_host_t* spi)
{
    spi_status_t status;
    status.value = SPI_HW(spi)->STATUS; // Assuming SPI_HW(spi)->STATUS returns a uint32_t value representing the status
    return status;
}

/**
 * @brief Read SPI active bit from status register (indicates if SPI peripheral 
 *        is currently processing a command)
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_TRISTATE_ERROR if null pointer, else SPI_TRISTATE_TRUE if active 
 *         or SPI_TRISTATE_FALSE otherwise.
 */
static inline __attribute__((always_inline)) 
spi_tristate_e spi_get_active(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_TRISTATE_ERROR)
    //return spi_get_status(spi)->active ? SPI_TRISTATE_TRUE : SPI_TRISTATE_FALSE;
    spi_status_t spi_status;
    spi_status.value = 0x00;
    spi_status.value = SPI_HW(spi)->STATUS;
}

/**
 * @brief Read SPI ready bit from status register (indicates if SPI peripheral 
 *        is ready to receive more commands)
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_TRISTATE_ERROR if null pointer, else SPI_TRISTATE_TRUE if ready 
 *         or SPI_TRISTATE_FALSE otherwise.
 */
static inline __attribute__((always_inline)) 
spi_tristate_e spi_get_ready(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_TRISTATE_ERROR)
    return spi_get_status(spi).ready ? SPI_TRISTATE_TRUE : SPI_TRISTATE_FALSE;
}

/**
 * @brief Wait SPI is ready to receive commands.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
static inline __attribute__((always_inline)) 
spi_return_flags_e spi_wait_for_ready(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    while (spi_get_ready(spi) == SPI_TRISTATE_FALSE);
    return SPI_FLAG_OK;
}

/**
 * @brief Wait SPI is no longer processing commands.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
static inline __attribute__((always_inline))
spi_return_flags_e spi_wait_for_idle(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    while (spi_get_active(spi) == SPI_TRISTATE_TRUE);
    return SPI_FLAG_OK;
}

/**
 * @brief Wait CMD FIFO not full.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
static inline __attribute__((always_inline))
spi_return_flags_e spi_wait_for_cmdqd_not_full(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    while (spi_get_status(spi).cmdqd >= SPI_HOST_PARAM_CMD_DEPTH);
    return SPI_FLAG_OK;
}

/**
 * @brief Wait TX FIFO reach watermark.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
static inline __attribute__((always_inline)) 
spi_return_flags_e spi_wait_for_tx_watermark(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    while (!spi_get_status(spi).txwm);
    return SPI_FLAG_OK;
}

/**
 * @brief Wait TX FIFO empty.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
static inline __attribute__((always_inline))
spi_return_flags_e spi_wait_for_tx_empty(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    while (!spi_get_status(spi).txempty);
    return SPI_FLAG_OK;
}

/**
 * @brief Wait TX FIFO not empty.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
static inline __attribute__((always_inline))
spi_return_flags_e spi_wait_for_tx_not_empty(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    while (spi_get_status(spi).txempty);
    return SPI_FLAG_OK;
}

/**
 * @brief Wait TX FIFO not full.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
static inline __attribute__((always_inline))
spi_return_flags_e spi_wait_for_tx_not_full(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    while (spi_get_status(spi).txfull);
    return SPI_FLAG_OK;
}

/**
 * @brief Wait RX FIFO empty.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
static inline __attribute__((always_inline))
spi_return_flags_e spi_wait_for_rx_empty(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    while (!spi_get_status(spi).rxempty);
    return SPI_FLAG_OK;
}

/**
 * @brief Wait RX FIFO not empty.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
static inline __attribute__((always_inline))
spi_return_flags_e spi_wait_for_rx_not_empty(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    while (spi_get_status(spi).rxempty);
    return SPI_FLAG_OK;
}

/**
 * @brief Wait RX FIFO full.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
static inline __attribute__((always_inline))
spi_return_flags_e spi_wait_for_rx_full(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    while (!spi_get_status(spi).rxfull);
    return SPI_FLAG_OK;
}

/**
 * @brief Wait RX FIFO reach watermark.
 *
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return SPI_FLAG_NULL_PTR if spi NULL pointer.
 * @return SPI_FLAG_OK       if success.
 */
static inline __attribute__((always_inline)) 
spi_return_flags_e spi_wait_for_rx_watermark(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    while (!spi_get_status(spi).rxwm);
    return SPI_FLAG_OK;
}

/**
 * @brief Create SPI target device configuration word.
 *
 * @param configopts Target device configuation structure.
 * @return uint32 representing the configopts.
 */
static inline __attribute__((always_inline)) __attribute__((const))
uint32_t spi_create_configopts(const spi_configopts_t configopts)
{
    uint32_t conf_reg = 0;
    conf_reg = bitfield_write(conf_reg, SPI_HOST_CONFIGOPTS_0_CLKDIV_0_MASK, 
                              SPI_HOST_CONFIGOPTS_0_CLKDIV_0_OFFSET, configopts.clkdiv);
    conf_reg = bitfield_write(conf_reg, SPI_HOST_CONFIGOPTS_0_CSNIDLE_0_MASK, 
                              SPI_HOST_CONFIGOPTS_0_CSNIDLE_0_OFFSET, configopts.csnidle);
    conf_reg = bitfield_write(conf_reg, SPI_HOST_CONFIGOPTS_0_CSNTRAIL_0_MASK, 
                              SPI_HOST_CONFIGOPTS_0_CSNTRAIL_0_OFFSET, configopts.csntrail);
    conf_reg = bitfield_write(conf_reg, SPI_HOST_CONFIGOPTS_0_CSNLEAD_0_MASK, 
                              SPI_HOST_CONFIGOPTS_0_CSNLEAD_0_OFFSET, configopts.csnlead);
    conf_reg = bitfield_write(conf_reg, BIT_MASK_1, 
                              SPI_HOST_CONFIGOPTS_0_FULLCYC_0_BIT, configopts.fullcyc);
    conf_reg = bitfield_write(conf_reg, BIT_MASK_1, 
                              SPI_HOST_CONFIGOPTS_0_CPHA_0_BIT, configopts.cpha);
    conf_reg = bitfield_write(conf_reg, BIT_MASK_1,
                              SPI_HOST_CONFIGOPTS_0_CPOL_0_BIT, configopts.cpol);
    return conf_reg;
}

/**
 * @brief Convert SPI target device configuration word to spi_configopts_t structure.
 *
 * @param configopts Target device configuation structure.
 * @return spi_configopts_t representing the config_reg.
 */
static inline __attribute__((always_inline)) __attribute__((const))
spi_configopts_t spi_create_configopts_structure(const uint32_t config_reg)
{
    spi_configopts_t configopts = {
        .clkdiv   = bitfield_read(config_reg, SPI_HOST_CONFIGOPTS_0_CLKDIV_0_MASK, 
                                  SPI_HOST_CONFIGOPTS_0_CLKDIV_0_OFFSET),
        .csnidle  = bitfield_read(config_reg, SPI_HOST_CONFIGOPTS_0_CSNIDLE_0_MASK, 
                                  SPI_HOST_CONFIGOPTS_0_CSNIDLE_0_OFFSET),
        .csntrail = bitfield_read(config_reg, SPI_HOST_CONFIGOPTS_0_CSNTRAIL_0_MASK, 
                                  SPI_HOST_CONFIGOPTS_0_CSNTRAIL_0_OFFSET),
        .csnlead  = bitfield_read(config_reg, SPI_HOST_CONFIGOPTS_0_CSNLEAD_0_MASK, 
                                  SPI_HOST_CONFIGOPTS_0_CSNLEAD_0_OFFSET),
        .fullcyc  = bitfield_read(config_reg, BIT_MASK_1, 
                                  SPI_HOST_CONFIGOPTS_0_FULLCYC_0_BIT),
        .cpha     = bitfield_read(config_reg, BIT_MASK_1, 
                                  SPI_HOST_CONFIGOPTS_0_CPHA_0_BIT),
        .cpol     = bitfield_read(config_reg, BIT_MASK_1, 
                                  SPI_HOST_CONFIGOPTS_0_CPOL_0_BIT)
    };
    return configopts;
}

/**
 * @brief Create SPI command word.
 *
 * @param command Command configuration structure.
 * @return uint32 representing the command.
 */
static inline __attribute__((always_inline)) __attribute__((const))
uint32_t spi_create_command(const spi_command_t command)
{
    uint32_t cmd_reg = 0;
    cmd_reg = bitfield_write(cmd_reg, SPI_HOST_COMMAND_LEN_MASK, 
                             SPI_HOST_COMMAND_LEN_OFFSET, command.len);
    cmd_reg = bitfield_write(cmd_reg, BIT_MASK_1, 
                             SPI_HOST_COMMAND_CSAAT_BIT, command.csaat);
    cmd_reg = bitfield_write(cmd_reg, SPI_HOST_COMMAND_SPEED_MASK, 
                             SPI_HOST_COMMAND_SPEED_OFFSET, command.speed);
    cmd_reg = bitfield_write(cmd_reg, SPI_HOST_COMMAND_DIRECTION_MASK, 
                             SPI_HOST_COMMAND_DIRECTION_OFFSET, command.direction);
    return cmd_reg;
}

/**
 * @brief Attends the plic interrupt for SPI Host 2.
 */
void handler_irq_spi(uint32_t id);

/**
 * @brief Attends the fic interrupt for SPI Host.
 */
void fic_irq_spi(void);

/**
 * @brief Attends the fic interrupt for SPI Flash.
 */
void fic_irq_spi_flash(void);

/**
 * @brief weak implementation of the function that gets called when an event 
 *        interrupt is triggered on the SPI Flash.
 *        Replace with your own implementation.
 */
void spi_intr_handler_event_flash(spi_event_e events);

/**
 * @brief weak implementation of the function that gets called when an error 
 *        interrupt is triggered on the SPI Flash.
 *        Replace with your own implementation.
 */
void spi_intr_handler_error_flash(spi_error_e errors);

/**
 * @brief weak implementation of the function that gets called when an event 
 *        interrupt is triggered on the SPI Host.
 *        Replace with your own implementation.
 */
void spi_intr_handler_event_host(spi_event_e events);

/**
 * @brief weak implementation of the function that gets called when an error 
 *        interrupt is triggered on the SPI Host.
 *        Replace with your own implementation.
 */
void spi_intr_handler_error_host(spi_error_e errors);

/**
 * @brief weak implementation of the function that gets called when an event 
 *        interrupt is triggered on the SPI Host 2.
 *        Replace with your own implementation.
 */
void spi_intr_handler_event_host2(spi_event_e events);

/**
 * @brief weak implementation of the function that gets called when an error 
 *        interrupt is triggered on the SPI Host 2.
 *        Replace with your own implementation.
 */
void spi_intr_handler_error_host2(spi_error_e errors);


#ifdef __cplusplus
}
#endif

#endif // _DRIVERS_SPI_HOST_H_

/****************************************************************************/
/**                                                                        **/
/**                                EOF                                     **/
/**                                                                        **/
/****************************************************************************/