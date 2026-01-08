/*
                              *******************
******************************* C SOURCE FILE *******************************
**                            *******************                          **
**                                                                         **
** project  : x-heep                                                       **
** filename : rv_plic.h                                                    **
** date     : 18/04/2023                                                   **
**                                                                         **
*****************************************************************************
**                                                                         **
**                                                                         **
*****************************************************************************

*/

/***************************************************************************/
/***************************************************************************/

/**
* @file   rv_plic.h
* @date   18/04/2023
* @brief  This is the main file for the HAL of the RV_PLIC peripheral
*
* In this file there are the defintions of the public HAL functions for the RV_PLIC
* peripheral. They provide many low level functionalities to interact
* with the registers content, reading and writing them according to the specific
* function of each one.
*
*/

#ifndef _RV_PLIC_H_
#define _RV_PLIC_H_

/****************************************************************************/
/**                                                                        **/
/*                             MODULES USED                                 */
/**                                                                        **/
/****************************************************************************/

#include <stdbool.h>
#include <stdint.h>

#include "mmio.h"
#include "macros.h"


/****************************************************************************/
/**                                                                        **/
/*                        DEFINITIONS AND MACROS                            */
/**                                                                        **/
/****************************************************************************/

/**
 * Start and end ID of the UART interrupt request lines
*/
#define UART_ID_END     UART_INTR_RX_PARITY_ERR

/**
 * Start and end ID of the GPIO interrupt request lines
*/
#define GPIO_ID_END     GPIO_INTR_31

/**
 * Start and end ID of the I2C interrupt request lines
*/
#define I2C_ID_END      INTR_HOST_TIMEOUT

/**
 * ID of the SPI interrupt request line
*/
#define SPI_ID          SPI2_INTR_EVENT

/**
 * ID of the I2S interrupt request lines
 */
#define I2S_ID          I2S_INTR_EVENT

/**
 * ID of the W25Q128JW_CONTROLLER interrupt request lines
 */
#define W25Q128JW_CONTROLLER_ID          W25Q128JW_CONTROLLER_INTR_EVENT


/**
 * ID of the external interrupt request lines
*/
#define EXT_IRQ_START   EXT_INTR_0

/****************************************************************************/
/**                                                                        **/
/*                        TYPEDEFS AND STRUCTURES                           */
/**                                                                        **/
/****************************************************************************/

/**
 * A PLIC interrupt target.
 *
 * This corresponds to a specific system that can service an interrupt. In
 * OpenTitan's case, that is the Ibex core. If there were multiple cores in the
 * system, each core would have its own specific interrupt target ID.
 *
 * This is an unsigned 32-bit value that is at least 0 and is less than the
 * `NumTarget` instantiation parameter of the `rv_plic` device.
 */
typedef uint32_t plic_target_t;


/**
 * The result of a PLIC operation.
 */
typedef enum plic_result {
  /**
   * Indicates that the operation succeeded.
   */
  kPlicOk = 0,
  /**
   * Indicates some unspecified failure.
   */
  kPlicError = 1,
  /**
   * Indicates that some parameter passed into a function failed a
   * precondition.
   *
   * When this value is returned, no hardware operations occurred.
   */
  kPlicBadArg = 2,
} plic_result_t;


/**
 * A toggle state: enabled, or disabled.
 *
 * This enum may be used instead of a `bool` when describing an enabled/disabled
 * state.
 */
typedef enum plic_toggle {
  /**
   * The "disabled" state.
   */
  kPlicToggleDisabled,
  /*
   * The "enabled" state.
   */
  kPlicToggleEnabled
} plic_toggle_t;


/**
 * An interrupt trigger type.
 */
typedef enum plic_irq_trigger {
  /**
   * Trigger on a level (when the signal remains high).
   */
  kPlicIrqTriggerLevel,
  /**
   * Trigger on an edge (when the signal changes from low to high).
   */
  kPlicIrqTriggerEdge
} plic_irq_trigger_t;


/****************************************************************************/
/**                                                                        **/
/*                          EXPORTED FUNCTIONS                              */
/**                                                                        **/
/****************************************************************************/

/**
 * Generic handler for the interrupts in inputs to RV_PLIC.
 * Its basic purpose is to understand which source generated
 * the interrupt and call the proper specific handler. The source
 * is detected by reading the CC0 register (claim interrupt), containing
 * the ID of the source.
 * Once the interrupt routine is finished, this function sets to 1 the
 * external_intr_flag and calls plic_irq_complete() function to conclude
 * the handling.
*/
void handler_irq_external(void);

/**
 * Initilises the PLIC peripheral's registers with default values.
 *
 * @return The result of the operation.
 */
plic_result_t plic_Init(void);


/**
 * Sets wherher a particular interrupt is curently enabled or disabled.
 * This is done by setting a specific bit in the Interrupt Enable registers.
 *
 * For a specific target, each interrupt source has a dedicated enable/disable bit
 * inside the relative Interrupt Enable registers, basing on the interrupt
 * source id.
 *
 * This function sets that bit to 0 or 1 depending on the state that it is specified
 *
 * @param irq An interrupt source identification
 * @param state The new toggle state for the interrupt
 * @return The result of the operation
*/
plic_result_t plic_irq_set_enabled( uint32_t irq,
                                    plic_toggle_t state);


/**
 * Reads a specific bit of the Interrupt Enable registers to understand
 * if the corresponding interrupt is enabled or disabled.
 *
 * For a specific target, each interrupt source has a dedicated enable/disable bit
 * inside the relative Interrupt Enable registers, basing on the interrupt
 * source id.
 *
 * The resulting bit is saved inside the state variable passed as parameter
 *
 * @param irq An interrupt source identification
 * @param state The toggle state of the interrupt, as read from the IE registers
 * @return The result of the operation
*/
plic_result_t plic_irq_get_enabled( uint32_t irq,
                                    plic_toggle_t *state);

/**
 * Sets the interrupt request trigger type.
 *
 * For a specific interrupt line, identified by irq, sets if its trigger
 * type has to be edge or level.
 * Edge means that the interrupt is triggered when the source passes from low to high.
 * Level means that the interrupt is triggered when the source stays at a high level.
 *
 * @param irq An interrupt source identification
 * @param triggger The trigger state for the interrupt
 * @result The result of the operation
 *
*/
plic_result_t plic_irq_set_trigger( uint32_t irq,
                                    plic_irq_trigger_t trigger);

/**
 * Sets a priority value for a specific interrupt source
 *
 * @param irq An interrupt source identification
 * @param priority A priority value to set
 * @return The result of the operation
*/
plic_result_t plic_irq_set_priority(  uint32_t irq,
                                      uint32_t priority);

/**
 * Sets the priority threshold.
 *
 * PLIC will only interrupt a target when
 * IRQ source priority is set higher than the priority threshold for the
 * corresponding target.
 *
 * @param threshold The threshold value to be set
 * @return The result of the operation
*/
plic_result_t plic_target_set_threshold(uint32_t threshold);

/**
 * Returns whether a particular interrupt is currently pending.
 *
 * @param irq An interrupt source identification
 * @param[out] is_pending Boolean flagcorresponding to whether an interrupt is pending or not
*/
plic_result_t plic_irq_is_pending( uint32_t irq,
                                   bool *is_pending);

/**
 * Claims an IRQ and gets the information about the source.
 *
 * Claims an IRQ and returns the IRQ related data to the caller. This function
 * reads a target specific Claim/Complete register. #plic_irq_complete must
 * be called in order to allow another interrupt with the same source id to be
 * delivered. This usually would be done once the interrupt has been serviced.
 *
 * Another IRQ can be claimed before a prior IRQ is completed. In this way, this
 * functionality is compatible with nested interrupt handling. The restriction
 * is that you must Complete a Claimed IRQ before you will be able to claim an
 * IRQ with the same ID. This allows a pair of Claim/Complete calls to be
 * overlapped with another pair -- and there is no requirement that the
 * interrupts should be Completed in the reverse order of when they were
 * Claimed.
 *
 * @param[out] claim_data Data that describes the origin of the IRQ.
 * @return The result of the operation.
 */
plic_result_t plic_irq_claim( uint32_t *claim_data);

/**
 * Completes the claimed interrupt request.
 *
 * After an interrupt request is served, the core writes the interrupt source
 * ID into the Claim/Complete register.
 *
 * This function must be called after plic_irq_claim(), when the core is
 * ready to service others interrupts with the same ID. If this function
 * is not called, future claimed interrupts will not have the same ID.
 *
 * @param complete_data Previously claimed IRQ data that is used to signal
 * PLIC of the IRQ servicing completion.
 * @return The result of the operation
*/
plic_result_t plic_irq_complete(const uint32_t *complete_data );


/**
 * Forces the software interrupt.
 *
 * This function causes an interrupt to the to be serviced as if
 * hardware had asserted it.
 *
 * An interrupt handler is expected to call `plic_software_irq_acknowledge`
 * when the interrupt has been handled.
 *
 * @return The result of the operation
 */
void plic_software_irq_force(void);


/**
 * Acknowledges the software interrupt.
 *
 * This function indicates to the hardware that the software interrupt has been
 * successfully serviced. It is expected to be called from a software interrupt
 * handler.
 *
 * @return The result of the operation
 */
void plic_software_irq_acknowledge(void);

/**
 * Returns software interrupt pending state
 *
 * @return The result of the operation
*/
plic_result_t plic_software_irq_is_pending(void);

/**
 * Adds a handler function for an external interrupt to the handlers list.
 * @param id The interrupt ID of an external interrupt (from core_v_mini_mcu.h)
 * @param handler A pointer to a function that will be called upon interrupt.
 * @return The result of the operation
*/
plic_result_t plic_assign_external_irq_handler( uint32_t id,
                                                void  *handler );

/**
 * Resets all peripheral handlers to their pre-set ones. All external handlers
 * are re-set to the dummy handler.
 */
void plic_reset_handlers_list(void);

#endif /* _RV_PLIC_H_ */

/****************************************************************************/
/**                                                                        **/
/*                                 EOF                                      */
/**                                                                        **/
/****************************************************************************/
