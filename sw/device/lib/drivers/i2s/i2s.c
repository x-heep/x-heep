/*
                              *******************
******************************* C SOURCE FILE *******************************
**                            *******************                          **
**                                                                         **
** project  : x-heep                                                       **
** filename : i2s.c                                                        **
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
* @file   i2s.c
* @date   08/05/2023
* @author Tim Frey
* @brief  HAL of the I2S peripheral
*
*/


/****************************************************************************/
/**                                                                        **/
/*                             MODULES USED                                 */
/**                                                                        **/
/****************************************************************************/


#include "i2s.h"
#include "i2s_structs.h"


/****************************************************************************/
/**                                                                        **/
/*                           EXPORTED FUNCTIONS                             */
/**                                                                        **/
/****************************************************************************/

__attribute__((weak, optimize("O0"))) void handler_irq_i2s(uint32_t id)
{
 // Replace this function with a non-weak implementation
}

// i2s base functions
i2s_result_t i2s_init(uint16_t div_value, i2s_word_length_t word_length)
{
  // already on ?
  if (i2s_is_running()) {
    //printf("ERROR: [I2S HAL] I2S peripheral already running");
    return kI2sError;
  }

  // write clock divider value to register
  i2s_peri->CLKDIVIDX = div_value;

  // write word_length to register
  uint32_t control = i2s_peri->CONTROL;
  control = bitfield_field32_write(control, I2S_CONTROL_DATA_WIDTH_FIELD, word_length);

  // enable base modules
  control |= (
    + (1 << I2S_CONTROL_EN_BIT)     // enable SCK
    + (1 << I2S_CONTROL_EN_IO_BIT)  // connect signals to IO
  );
  i2s_peri->CONTROL = control;

  // wait for I2S clock domain to acknowledge startup
  while (! i2s_is_running()) ;

  control |= (1 << I2S_CONTROL_EN_WS_BIT); // enable WS gen
  i2s_peri->CONTROL = control;

  return kI2sOk;
}

void i2s_terminate(void)
{
  i2s_peri->CONTROL &= ~(
    (1 << I2S_CONTROL_EN_WS_BIT)    // disable WS gen
    + (1 << I2S_CONTROL_EN_BIT)     // disable SCK
    + (1 << I2S_CONTROL_EN_IO_BIT)  // disconnect IO
    + (1 << I2S_CONTROL_EN_TX_BIT)  // disable TX
  );
}

bool i2s_is_running(void)
{
  // check "running" bit in the STATUS register
  return (i2s_peri->STATUS & (1 << I2S_STATUS_RUNNING_BIT));
}

//
// RX Channel
//

i2s_result_t i2s_rx_start(i2s_channel_sel_t channels)
{
  if (! i2s_is_running()) {
    //printf("ERROR: [I2S HAL] I2S peripheral not running");
    return kI2sErrUninit;
  }

  if (channels == I2S_DISABLE) {
    // no channels selected -> disable
    return i2s_rx_stop();
  }

  if (i2s_rx_overflow()) {
    return kI2sOverflow;
  }

  uint32_t control = i2s_peri->CONTROL;

  if (bitfield_field32_read(control, I2S_CONTROL_EN_RX_FIELD) != 0x00) {
    //printf("ERROR: [I2S HAL] I2S rx was already running");
    return kI2sError;
  }

  control = bitfield_field32_write(control, I2S_CONTROL_EN_RX_FIELD, channels);
  control |= (1 << I2S_CONTROL_RESET_WATERMARK_BIT); // reset waterlevel

  i2s_peri->CONTROL = control;
  return kI2sOk;
}

i2s_result_t i2s_rx_stop(void)
{
  if (! i2s_is_running()) {
    //printf("ERROR: [I2S HAL] I2S peripheral not running");
    return kI2sErrUninit;
  }

  bool overflow = i2s_rx_overflow();

  // disable rx channel
  uint32_t control = i2s_peri->CONTROL;
  control &= ~(I2S_CONTROL_EN_RX_MASK << I2S_CONTROL_EN_RX_OFFSET);
  i2s_peri->CONTROL = control;

  if (overflow) {
    // trigger reset of the overflow flag
    i2s_peri->CONTROL = control | (1 << I2S_CONTROL_RESET_RX_OVERFLOW_BIT);

    // overflow bit is going to be reset by rx channel if the sck is running
    while (i2s_rx_overflow()) ; // wait for one SCK rise - this might take some time as the SCK can be much slower

    // disable WATERMARK counter
    i2s_peri->CONTROL = control & ~(1 << I2S_CONTROL_EN_WATERMARK_BIT);

    // CDC FIFO is not clearable, so we have to empty the FIFO manually
    // note: this uses much less resources
    for (int i = 0; i < 6; i++) {
      // 4 FIFO + 2 spill registers
      i2s_rx_read_data(); // read to empty FIFO
    }

    i2s_peri->CONTROL = control; // reset control register
    return kI2sOverflow;
  }
  return kI2sOk;
}


bool i2s_rx_data_available(void)
{
  // read data ready bit from STATUS register
  return (i2s_peri->STATUS & (1 << I2S_STATUS_RX_DATA_READY_BIT));
}

uint32_t i2s_rx_read_data(void)
{
  // read RXDATA register
  return i2s_peri->RXDATA;
}

bool i2s_rx_overflow(void)
{
  // read overflow bit from STATUS register
  return (i2s_peri->STATUS & (1 << I2S_STATUS_RX_OVERFLOW_BIT));
}


//
// TX Channel
//

i2s_result_t i2s_tx_start(void)
{
  uint32_t control = i2s_peri->CONTROL;

  if (control & (1 << I2S_CONTROL_EN_TX_BIT)) {
    return kI2sError;
  }

  if (i2s_tx_overflow()) {
    return kI2sOverflow;
  }

  i2s_peri->CONTROL = control | (1 << I2S_CONTROL_EN_TX_BIT);
  return kI2sOk;
}

i2s_result_t i2s_tx_stop(void)
{
  uint32_t control = i2s_peri->CONTROL & ~(1 << I2S_CONTROL_EN_TX_BIT);
  bool underflow = i2s_tx_underflow();
  bool overflow = i2s_tx_overflow();

  i2s_peri->CONTROL = control;

  if (underflow && i2s_is_running()) {
    i2s_peri->CONTROL = control | (1 << I2S_CONTROL_RESET_TX_UNDERFLOW_BIT);
    while (i2s_tx_underflow()) ;
    i2s_peri->CONTROL = control;
  }

  if (overflow) {
    i2s_peri->CONTROL = control | (1 << I2S_CONTROL_RESET_TX_OVERFLOW_BIT);
    i2s_peri->CONTROL = control;
  }

  if (overflow) {
    return kI2sOverflow;
  }
  if (underflow) {
    return kI2sUnderflow;
  }

  return kI2sOk;
}

bool i2s_tx_ready(void)
{
  return (i2s_peri->STATUS & (1 << I2S_STATUS_TX_READY_BIT));
}

i2s_result_t i2s_tx_write_data(uint32_t data)
{
  if (!i2s_tx_ready()) {
    return kI2sError;
  }

  i2s_peri->TXDATA = data;
  return kI2sOk;
}

bool i2s_tx_underflow(void)
{
  return (i2s_peri->STATUS & (1 << I2S_STATUS_TX_UNDERFLOW_BIT));
}

bool i2s_tx_overflow(void)
{
  return (i2s_peri->STATUS & (1 << I2S_STATUS_TX_OVERFLOW_BIT));
}


//
// RX Watermark
//
void i2s_rx_enable_watermark(uint16_t watermark, bool interrupt_en)
{
  // set watermark (= max of counter) triggers an interrupt if enabled
  i2s_peri->WATERMARK = watermark;

  uint32_t control = i2s_peri->CONTROL;
  // enable/disable interrupt
  control = bitfield_bit32_write(control, I2S_CONTROL_INTR_EN_BIT, interrupt_en);
  // enable counter
  control |= (1 << I2S_CONTROL_EN_WATERMARK_BIT);
  i2s_peri->CONTROL = control;
}

void i2s_rx_disable_watermark(void)
{
  // disable interrupt and disable watermark counter
  i2s_peri->CONTROL &= ~(
    (1 << I2S_CONTROL_INTR_EN_BIT)
    + (1 << I2S_CONTROL_EN_WATERMARK_BIT)
  );
}

uint16_t i2s_rx_read_waterlevel(void)
{
  // read WATERLEVEL register
  return (uint16_t) i2s_peri->WATERLEVEL;
}

void i2s_rx_reset_waterlevel(void)
{
  // set "reset watermark" bit in CONTROL register
  i2s_peri->CONTROL |= (1 << I2S_CONTROL_RESET_WATERMARK_BIT);
}



/****************************************************************************/
/**                                                                        **/
/*                                 EOF                                      */
/**                                                                        **/
/****************************************************************************/
