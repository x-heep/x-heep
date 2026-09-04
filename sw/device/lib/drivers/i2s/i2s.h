/*
                              *******************
******************************* C SOURCE FILE *******************************
**                            *******************                          **
**                                                                         **
** project  : x-heep                                                       **
** filename : i2s.h                                                        **
** date     : 18/04/2023                                                   **
**                                                                         **
*****************************************************************************
**                                                                         **
** Copyright (c) EPFL contributors.                                        **
** All rights reserved.                                                    **
**                                                                         **
*****************************************************************************

*/

/***************************************************************************/
/***************************************************************************/

/**
* @file   i2s.h
* @date   08/05/2023
* @author Tim Frey
* @brief  HAL of the I2S peripheral
*
*/

#ifndef _DRIVERS_I2S_H_
#define _DRIVERS_I2S_H_

/**
 * Address of the I2S data of the read channel to be passed as address to the DMA
 */
#define I2S_RX_DATA_ADDRESS (uint32_t)(I2S_RXDATA_REG_OFFSET+I2S_START_ADDRESS)

/**
 * Address of the I2S TX data register.
 */
#define I2S_TX_DATA_ADDRESS (uint32_t)(I2S_TXDATA_REG_OFFSET+I2S_START_ADDRESS)


/****************************************************************************/
/**                                                                        **/
/*                             MODULES USED                                 */
/**                                                                        **/
/****************************************************************************/

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#include "bitfield.h"
#include "i2s_regs.h"


#ifdef __cplusplus
extern "C" {
#endif


/****************************************************************************/
/**                                                                        **/
/*                        TYPEDEFS AND STRUCTURES                           */
/**                                                                        **/
/****************************************************************************/


/**
 * The result of a PLIC operation.
 */
typedef enum i2s_result {
  /**
   * Indicates that the operation succeeded.
   */
  kI2sOk = 0,
  /**
   * errors i2s is uninitialized
   */
  kI2sErrUninit = 1,
  /**
   * Indicates overflow.
   */
  kI2sOverflow = 2,
  /**
   * Indicates underflow.
   */
  kI2sUnderflow = 3,
  /**
   * Indicates some unspecified failure.
   */
  kI2sError = 0xFF,
} i2s_result_t;


typedef enum i2s_word_length {
  I2S_08_BITS = I2S_CONTROL_DATA_WIDTH_VALUE_8_BITS,
  I2S_16_BITS = I2S_CONTROL_DATA_WIDTH_VALUE_16_BITS,
  I2S_24_BITS = I2S_CONTROL_DATA_WIDTH_VALUE_24_BITS,
  I2S_32_BITS = I2S_CONTROL_DATA_WIDTH_VALUE_32_BITS
} i2s_word_length_t;


typedef enum i2s_channel_sel {
  I2S_DISABLE = I2S_CONTROL_EN_RX_VALUE_DISABLED,
  I2S_LEFT_CH = I2S_CONTROL_EN_RX_VALUE_ONLY_LEFT,
  I2S_RIGHT_CH = I2S_CONTROL_EN_RX_VALUE_ONLY_RIGHT,
  I2S_BOTH_CH = I2S_CONTROL_EN_RX_VALUE_BOTH_CHANNELS
} i2s_channel_sel_t;


/****************************************************************************/
/**                                                                        **/
/*                          EXPORTED FUNCTIONS                              */
/**                                                                        **/
/****************************************************************************/

/**
 * @brief Attends the plic interrupt.
 */
__attribute__((weak, optimize("O0"))) void handler_irq_i2s(uint32_t id);

/**
 * Initialize I2S peripheral
 * Starts devices connected on the I2S bus
 * This function has to be called before any other function of the I2S hal.
 *
 * Generates SCK and WS
 * (with the given parameters frequency and word length)
 *
 * @note to change clock freq or word length call `i2s_terminate` first
 *
 * @param div_value Divider value = src_clk_freq / gen_clk_freq
 *        (odd values are allowed, for 0 and 1 the src clock is used)
 * @param word_length (see i2s_word_length_t)
 * @return kI2sOk initialized successful
 * @return kI2sError if peripheral was already running
 */
i2s_result_t i2s_init(uint16_t div_value, i2s_word_length_t word_length);

/**
 * Terminate I2S peripheral
 * Afterwards the init funciton has to be called to reinit the peripheral
 *
 * Stops SCK and WS
 */
void i2s_terminate(void);


/**
 * check if i2s peripheral has been initialized
 *
 * @return true if i2s peripheral enable
 */
bool i2s_is_running(void);


//
// RX Channel
//

/**
 * I2S start rx channels
 *
 * (Start the DMA before)
 *
 * @param channels to be enabled (see i2s_channel_sel_t) (I2S_DISABLE calls i2s_rx_stop())
 *
 * @return kI2sOk success
 * @return kI2sError RX already started
 * @return kI2sErrUninit error peripheral was not initialized
 * @return kI2sOverflow indicates overflow. (to clear call i2s_rx_stop())
 */
i2s_result_t i2s_rx_start(i2s_channel_sel_t channels);

/**
 * I2S stop rx channels and cleans overflow
 *
 * (DMA must not be reading from I2S RX data)
 *
 * @return kI2sOk success
 * @return kI2sErrUninit error peripheral was not initialized
 * @return kI2sOverflow the RX-FIFO overflowed since the RX has been started.
 */
i2s_result_t i2s_rx_stop(void);


/**
 * I2S check RX data availability
 *
 * @return true if RX data is available
 */
bool i2s_rx_data_available(void);

/**
 * I2S read RX word
 *
 * @note The MSBs outside of word_length are 0.
 *
 * @return uint32_t RX word
 */
uint32_t i2s_rx_read_data(void);

/**
 * I2S check RX FIFO overflow
 *
 * To clear overflow:
 *  1. stop DMA
 *  2. call i2s_rx_stop()
 *  3. start DMA
 *  4. call i2s_rx_start()
 *
 * @return true if RX FIFO overflowed
 * @return false
 */
bool i2s_rx_overflow(void);

//
// TX Channel
//

/**
 * I2S start TX channel.
 *
 * This can be called before i2s_init() to arm a preloaded TX FIFO. Data is
 * shifted only once SCK and WS are running.
 *
 * @return kI2sOk success
 * @return kI2sError TX already started
 */
i2s_result_t i2s_tx_start(void);

/**
 * I2S stop TX channel and clear TX status flags when possible.
 *
 * @return kI2sOk success
 * @return kI2sOverflow the TX FIFO overflowed since TX was started
 * @return kI2sUnderflow the TX FIFO underflowed since TX was started
 */
i2s_result_t i2s_tx_stop(void);

/**
 * I2S check if TX FIFO can accept a sample.
 *
 * @return true if TX FIFO can accept a sample
 */
bool i2s_tx_ready(void);

/**
 * I2S enqueue TX word.
 *
 * @param data TX word
 * @return kI2sOk success
 * @return kI2sError TX FIFO is full
 */
i2s_result_t i2s_tx_write_data(uint32_t data);

/**
 * I2S check TX underflow.
 *
 * @return true if TX needed data while the TX FIFO was empty
 */
bool i2s_tx_underflow(void);

/**
 * I2S check TX overflow.
 *
 * @return true if software wrote TXDATA while the TX FIFO was full
 */
bool i2s_tx_overflow(void);



// Watermark

/**
 * I2S enable and configure watermark counter
 *
 * @param watermark number to trigger interrupt
 * @param interrupt_en enable/disable interrupt
 */
void i2s_rx_enable_watermark(uint16_t watermark, bool interrupt_en);

/**
 * I2S disable watermark counter
 */
void i2s_rx_disable_watermark(void);


/**
 * I2S read value of watermark counter
 *
 * @return uint16_t current counter value
 */
uint16_t i2s_rx_read_waterlevel(void);


/**
 * I2S reset RX Watermark counter to 0
 *
 */
void i2s_rx_reset_waterlevel(void);


#ifdef __cplusplus
}
#endif

#endif // _DRIVERS_I2S_H_

/****************************************************************************/
/**                                                                        **/
/*                                 EOF                                      */
/**                                                                        **/
/****************************************************************************/
