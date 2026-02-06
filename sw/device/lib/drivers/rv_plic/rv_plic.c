/*
                              *******************
******************************* C SOURCE FILE *******************************
**                            *******************                          **
**                                                                         **
** project  : x-heep                                                       **
** filename : rv_plic.c                                                    **
** date     : 26/04/2023                                                   **
**                                                                         **
*****************************************************************************
**                                                                         **
**                                                                         **
*****************************************************************************

*/

/***************************************************************************/
/***************************************************************************/

/**
* @file   rv_plic.c
* @date   26/04/2023
* @brief  This is the main file for the HAL of the RV_PLIC peripheral
*
* In this file there are the defintions of the HAL functions for the RV_PLIC
* peripheral. They provide many low level functionalities to interact
* with the registers content, reading and writing them according to the specific
* function of each one.
*
*/

/****************************************************************************/
/**                                                                        **/
/*                             MODULES USED                                 */
/**                                                                        **/
/****************************************************************************/
#ifdef __cplusplus
extern "C" {
#endif

#include "rv_plic.h"
#include "rv_plic_structs.h"
#include <stddef.h>
#include "bitfield.h"
#include "rv_plic_regs.h"  // Generated.
#include "handler.h"

// Peripheral modules from where to obtain the irq handlers
#include "uart.h"
#include "gpio.h"
#include "i2c.h"
#include "i2s.h"
#include "dma.h"
#include "spi_host.h"
#include "w25q128jw_controller.h"

/****************************************************************************/
/**                                                                        **/
/*                        DEFINITIONS AND MACROS                            */
/**                                                                        **/
/****************************************************************************/

/**
 * Minimum and Maximum priority that an interrupt source can have
*/
const uint32_t plicMinPriority = 0;
const uint32_t plicMaxPriority = RV_PLIC_PRIO0_PRIO0_MASK;

/****************************************************************************/
/**                                                                        **/
/*                        TYPEDEFS AND STRUCTURES                           */
/**                                                                        **/
/****************************************************************************/

/**
 * Pointer used to dynamically access the different interrupt handlers.
*/
typedef void (*handler_funct_t)(uint32_t);
//#endif
/****************************************************************************/
/**                                                                        **/
/*                      PROTOTYPES OF LOCAL FUNCTIONS                       */
/**                                                                        **/
/****************************************************************************/

/**
 * @brief Get an IE, IP or LE register offset (e.g. IE0_0) from an IRQ ID.
 *
 * With more than 32 IRQ sources, there is a multiple of these registers to
 * accommodate all the bits (1 bit per IRQ source). This function calculates
 * the offset for a specific IRQ source ID (ID 32 would be IE01, ...).
 *  
 * @param irq An interrupt source identification
 */
static ptrdiff_t plic_offset_from_reg0( uint32_t irq);

/**
 *
 * @brief Get an IE, IP, LE register bit index from an IRQ source ID.
 *
 * With more than 32 IRQ sources, there is a multiple of these registers to
 * accommodate all the bits (1 bit per IRQ source). This function calculates
 * the bit position within a register for a specific IRQ source ID (ID 32 would
 * be bit 0).
 *  
 * @param irq An interrupt source identification
 */
static uint8_t plic_irq_bit_index( uint32_t irq);

/**
 * @brief A dummy function to prevent unassigned irq to access a null pointer.
 */
__attribute__((optimize("O0"))) static void handler_irq_dummy( uint32_t dummy );


/****************************************************************************/
/**                                                                        **/
/*                           EXPORTED VARIABLES                             */
/**                                                                        **/
/****************************************************************************/

/****************************************************************************/
/**                                                                        **/
/*                            GLOBAL VARIABLES                              */
/**                                                                        **/
/****************************************************************************/

/**
 * Array for the ISRs. Length automatically generated when compiling and 
 * assigned to QTY_INTR.
 * Each element will be initialized to be the address of the handler function
 * relative to its index. So each element will be a callable function.
*/
handler_funct_t handlers[QTY_INTR];

/****************************************************************************/
/**                                                                        **/
/*                           EXPORTED FUNCTIONS                             */
/**                                                                        **/
/****************************************************************************/

void handler_irq_external(void)
{
  uint32_t int_id = NULL_INTR;
  plic_result_t res = plic_irq_claim(&int_id);

    // Calls the proper handler
    handlers[int_id](int_id);
    plic_irq_complete(&int_id);
}

/*!
  Resets relevant registers of the PLIC (Level/Edge,
  priority, target, threshold, interrupts).
  It writes the default value 0 in them and read back
  the value into the proper register struct
*/
plic_result_t plic_Init(void)
{

  /* Clears all the Level/Edge registers */
  for(uint8_t i=0; i<RV_PLIC_LE_MULTIREG_COUNT; i++)
  {
    (&rv_plic_peri->LE0)[i] = 0;
  }


  /* Clears all the priority registers */
  for(uint8_t i=0; i<RV_PLIC_PARAM_NUM_SRC; i++)
  {
    (&rv_plic_peri->PRIO0)[i] = 0;
  }

  /* Clears the Interrupt Enable registers */
  for(uint8_t i=0; i<RV_PLIC_IE0_MULTIREG_COUNT; i++)
  {
    (&rv_plic_peri->IE00)[i] = 0;
  }

  /* Clears all the threshold registers */
  rv_plic_peri->THRESHOLD0 = 0;
  if(rv_plic_peri->THRESHOLD0 != 0)
  {
    return kPlicError;
  }

  /* clears software interrupts registers */
  rv_plic_peri->MSIP0 = 0;
  if(rv_plic_peri->MSIP0 != 0)
  {
    return kPlicError;
  }

  /* Fill the handlers array with the fixed peripherals. */
  plic_reset_handlers_list();

  return kPlicOk;
}


plic_result_t plic_irq_set_enabled( uint32_t irq,
                                    plic_toggle_t state)
{
  if(irq >= RV_PLIC_PARAM_NUM_SRC)
  {
    return kPlicBadArg;
  }

  // Check that `state` is an accettable value
  if (state != kPlicToggleEnabled && state!=kPlicToggleDisabled)
  {
    return kPlicBadArg;
  }

  // Get the offset of the register in which to write given the irq ID
  ptrdiff_t offset = plic_offset_from_reg0(irq);

  // Get the destination bit in which to write
  uint16_t bit_index = plic_irq_bit_index(irq);

  // Writes `state` in the amount of bits defined by the mask
  // at position `bit_index` inside the proper Interrupt Enable register
  (&rv_plic_peri->IE00)[offset] = bitfield_write((&rv_plic_peri->IE00)[offset],
                                                  BIT_MASK_1,
                                                  bit_index,
                                                  state);

  return kPlicOk;
}


plic_result_t plic_irq_get_enabled( uint32_t irq,
                                    plic_toggle_t *state)
{
  if(irq >= RV_PLIC_PARAM_NUM_SRC)
  {
    return kPlicBadArg;
  }

  // Get the destination register
  ptrdiff_t offset = plic_offset_from_reg0(irq);

  // Get the destination bit in which to write
  uint16_t bit_index = plic_irq_bit_index(irq);

  // Reads the enabled/disabled bit
  *state = bitfield_read((&rv_plic_peri->IE00)[offset], BIT_MASK_1, bit_index);

  return kPlicOk;

}


plic_result_t plic_irq_set_trigger( uint32_t irq,
                                           plic_irq_trigger_t trigger)
{
  if(irq >= RV_PLIC_PARAM_NUM_SRC)
  {
    return kPlicBadArg;
  }

  // Get the destination register
  ptrdiff_t offset = plic_offset_from_reg0(irq);

  // Get the destination bit in which to write
  uint16_t bit_index = plic_irq_bit_index(irq);

  // Updated the register with the new bit
  (&rv_plic_peri->LE0)[offset] = bitfield_write((&rv_plic_peri->LE0)[offset],
                                                 BIT_MASK_1,
                                                 bit_index,
                                                 trigger);

  return kPlicOk;

}


plic_result_t plic_irq_set_priority( uint32_t irq, uint32_t priority)
{
  if(irq >= RV_PLIC_PARAM_NUM_SRC || priority > plicMaxPriority)
  {
    return kPlicBadArg;
  }

  // Writes the new priority into the proper register
  (&rv_plic_peri->PRIO0)[irq] = priority;

  return kPlicOk;
}


plic_result_t plic_target_set_threshold(uint32_t threshold)
{
  if(threshold > plicMaxPriority)
  {
    return kPlicBadArg;
  }

  rv_plic_peri->THRESHOLD0 = threshold;

  return kPlicOk;

}


plic_result_t plic_irq_is_pending( uint32_t irq,
                                          bool *is_pending)
{
  if(irq >= RV_PLIC_PARAM_NUM_SRC || is_pending == NULL)
  {
    return kPlicBadArg;
  }

  // Get the destination register
  ptrdiff_t offset = plic_offset_from_reg0(irq);

  // Get the destination bit in which to write
  uint16_t bit_index = plic_irq_bit_index(irq);

  *is_pending = bitfield_read((&rv_plic_peri->IP0)[offset], BIT_MASK_1, bit_index);

  return kPlicOk;
}


plic_result_t plic_irq_claim( uint32_t *claim_data)
{
  if (claim_data == NULL)
  {
    return kPlicBadArg;
  }

  *claim_data = rv_plic_peri->CC0;

  return kPlicOk;
}


plic_result_t plic_irq_complete(const uint32_t *complete_data)
{
  if (complete_data == NULL)
  {
    return kPlicBadArg;
  }

  // Write back the claimed IRQ ID to the target specific CC register,
  // to notify the PLIC of the IRQ completion.
  rv_plic_peri->CC0 = *complete_data;

  return kPlicOk;
}


void plic_software_irq_force(void)
{
  rv_plic_peri->MSIP0 = 1;
}


void plic_software_irq_acknowledge(void)
{
  rv_plic_peri->MSIP0 = 0;
}


plic_result_t plic_software_irq_is_pending(void)
{
  return rv_plic_peri->MSIP0;
}


plic_result_t plic_assign_external_irq_handler( uint32_t id, void *handler )                                             
{
  if( id >= EXT_IRQ_START && id <= QTY_INTR )
  {
    handlers[ id ] = (handler_funct_t) handler;
    return kPlicOk;
  }
  return kPlicBadArg;
}


void plic_reset_handlers_list(void)
{
  handlers[NULL_INTR] = &handler_irq_dummy;

  for( uint8_t i = NULL_INTR +1; i < QTY_INTR; i++ )
  {
    if ( i <= UART_ID_END)
    {
      handlers[i] = &handler_irq_uart;
    }
    else if ( i <= GPIO_ID_END)
    {
      handlers[i] = &handler_irq_gpio;
    }
    else if ( i <= I2C_ID_END)
    {
      handlers[i] = &handler_irq_i2c;
    }
    else if ( i == SPI_ID)
    {
      handlers[i] = &handler_irq_spi;
    }
    else if ( i == I2S_ID)
    {
      handlers[i] = &handler_irq_i2s;
    }
    else if (i == W25Q128JW_CONTROLLER_ID)
    {
      handlers[i] = &handler_irq_w25q128jw_controller;
    }
    else
    {
      handlers[i] = &handler_irq_dummy;
    }
  }
}

/****************************************************************************/
/**                                                                        **/
/*                            LOCAL FUNCTIONS                               */
/**                                                                        **/
/****************************************************************************/

__attribute__((optimize("O0"))) static void handler_irq_dummy( uint32_t dummy )
{
}

static ptrdiff_t plic_offset_from_reg0( uint32_t irq)
{
  return irq / RV_PLIC_PARAM_REG_WIDTH;
}

static uint8_t plic_irq_bit_index( uint32_t irq)
{
  return irq % RV_PLIC_PARAM_REG_WIDTH;
}
#ifdef __cplusplus
}
#endif
/****************************************************************************/
/**                                                                        **/
/*                                 EOF                                      */
/**                                                                        **/
/****************************************************************************/
