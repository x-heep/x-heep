/*
                              *******************
******************************* H SOURCE FILE *******************************
**                            *******************                          **
**                                                                         **
** project  : x-heep                                                       **
** filename : gpio_structs.h                                 **
**                                                                         **
*****************************************************************************
**                                                                         **
**                                                                         **
*****************************************************************************

*/

/**
* @file   gpio_structs.h
* @brief  Contains structs for every register
*
* This file contains the structs of the registes of the peripheral.
* Each structure has the various bit fields that can be accessed
* independently.
* 
*/

#ifndef _GPIO_STRUCTS_H
#define _GPIO_STRUCTS_H

/****************************************************************************/
/**                                                                        **/
/**                            MODULES USED                                **/
/**                                                                        **/
/****************************************************************************/

#include <inttypes.h>
#include "core_v_mini_mcu.h"

/****************************************************************************/
/**                                                                        **/
/**                       DEFINITIONS AND MACROS                           **/
/**                                                                        **/
/****************************************************************************/

#define gpio_peri ((volatile gpio *) GPIO_START_ADDRESS)

/****************************************************************************/
/**                                                                        **/
/**                       TYPEDEFS AND STRUCTURES                          **/
/**                                                                        **/
/****************************************************************************/



typedef struct {

  uint32_t INFO;                                  /*!< Info register that contains information about this peripheral.*/

  uint32_t CFG;                                   /*!< Global configuration register for the peripheral*/

  uint32_t GPIO_MODE0;                            /*!< Set the IO Mode of the GPIO.*/

  uint32_t GPIO_MODE1;                            /*!< Set the IO Mode of the GPIO.*/

  uint32_t _reserved_0[28];                       /*!< reserved addresses*/

  uint32_t GPIO_EN0;                              /*!< Enable sampling on the corresponding GPIO*/

  uint32_t _reserved_1[31];                       /*!< reserved addresses*/

  uint32_t GPIO_IN0;                              /*!< Read the current input values of all GPIOs.*/

  uint32_t _reserved_2[31];                       /*!< reserved addresses*/

  uint32_t GPIO_OUT0;                             /*!< Set the output value of the corresponding GPIOs.*/

  uint32_t _reserved_3[31];                       /*!< reserved addresses*/

  uint32_t GPIO_SET0;                             /*!< For each asserted bit in this register, set the corresponding bit in the padout register.*/

  uint32_t _reserved_4[31];                       /*!< reserved addresses*/

  uint32_t GPIO_CLEAR0;                           /*!< For each asserted bit in this register, clear the corresponding bit in the padout register.*/

  uint32_t _reserved_5[31];                       /*!< reserved addresses*/

  uint32_t GPIO_TOGGLE0;                          /*!< For each asserted bit in this register, toggle the corresponding bit in the padout register.*/

  uint32_t _reserved_6[31];                       /*!< reserved addresses*/

  uint32_t INTRPT_RISE_EN0;                       /*!< Enable Interrupts on rising edges for the corresponding GPIO*/

  uint32_t _reserved_7[31];                       /*!< reserved addresses*/

  uint32_t INTRPT_FALL_EN0;                       /*!< Enable Interrupts on falling edges for the corresponding GPIO*/

  uint32_t _reserved_8[31];                       /*!< reserved addresses*/

  uint32_t INTRPT_LVL_HIGH_EN0;                   /*!< Enable logic high level-sensitive Interrupts on the corresponding GPIO*/

  uint32_t _reserved_9[31];                       /*!< reserved addresses*/

  uint32_t INTRPT_LVL_LOW_EN0;                    /*!< Enable logic low level-sensitive Interrupts on the corresponding GPIO*/

  uint32_t _reserved_10[31];                      /*!< reserved addresses*/

  uint32_t INTRPT_STATUS0;                        /*!< Asserted if there is any pending interrupts on corresponding GPIOs. Writing 1 to a specific bit clears all pending interrupts (rise, fall, low, high) of the corresponding GPIO.*/

  uint32_t _reserved_11[31];                      /*!< reserved addresses*/

  uint32_t INTRPT_RISE_STATUS0;                   /*!< Asserted if there is a pending rise interrupts on corresponding GPIOs. Writing 1 to a specific bit clears the pending interrupt of the corresponding GPIO.*/

  uint32_t _reserved_12[31];                      /*!< reserved addresses*/

  uint32_t INTRPT_FALL_STATUS0;                   /*!< Asserted if there is any pending fall interrupts on corresponding GPIOs. Writing 1 to a specific bit clears the pending interrupt of the corresponding GPIO.*/

  uint32_t _reserved_13[31];                      /*!< reserved addresses*/

  uint32_t INTRPT_LVL_HIGH_STATUS0;               /*!< Asserted if there is any pending high-level interrupts on corresponding GPIOs. Writing 1 to a specific bit clears the pending interrupt of the corresponding GPIO.*/

  uint32_t _reserved_14[31];                      /*!< reserved addresses*/

  uint32_t INTRPT_LVL_LOW_STATUS0;                /*!< Asserted if there is any pending low-level interrupts on corresponding GPIOs. Writing 1 to a specific bit clears the pending interrupt of the corresponding GPIO.*/

} gpio;

/****************************************************************************/
/**                                                                        **/
/**                          EXPORTED VARIABLES                            **/
/**                                                                        **/
/****************************************************************************/

#ifndef _GPIO_STRUCTS_C_SRC



#endif  /* _GPIO_STRUCTS_C_SRC */

/****************************************************************************/
/**                                                                        **/
/**                          EXPORTED FUNCTIONS                            **/
/**                                                                        **/
/****************************************************************************/


/****************************************************************************/
/**                                                                        **/
/**                          INLINE FUNCTIONS                              **/
/**                                                                        **/
/****************************************************************************/



#endif /* _GPIO_STRUCTS_H */
/****************************************************************************/
/**                                                                        **/
/**                                EOF                                     **/
/**                                                                        **/
/****************************************************************************/
