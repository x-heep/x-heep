/*
                              *******************
******************************* H SOURCE FILE *******************************
**                            *******************                          **
**                                                                         **
** project  : x-heep                                                       **
** filename : uart_structs.h                                 **
**                                                                         **
*****************************************************************************
**                                                                         **
**                                                                         **
*****************************************************************************

*/

/**
* @file   uart_structs.h
* @brief  Contains structs for every register
*
* This file contains the structs of the registes of the peripheral.
* Each structure has the various bit fields that can be accessed
* independently.
* 
*/

#ifndef _UART_STRUCTS_H
#define _UART_STRUCTS_H

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

#define uart_peri ((volatile uart *) UART_START_ADDRESS)

/****************************************************************************/
/**                                                                        **/
/**                       TYPEDEFS AND STRUCTURES                          **/
/**                                                                        **/
/****************************************************************************/



typedef struct {

  uint32_t INTR_STATE;                            /*!< Interrupt State Register*/

  uint32_t INTR_ENABLE;                           /*!< Interrupt Enable Register*/

  uint32_t INTR_TEST;                             /*!< Interrupt Test Register*/

  uint32_t CTRL;                                  /*!< UART control register*/

  uint32_t STATUS;                                /*!< UART live status register*/

  uint32_t RDATA;                                 /*!< UART read data*/

  uint32_t WDATA;                                 /*!< UART write data*/

  uint32_t FIFO_CTRL;                             /*!< UART FIFO control register*/

  uint32_t FIFO_STATUS;                           /*!< UART FIFO status register*/

  uint32_t OVRD;                                  /*!< TX pin override control. Gives direct SW control over TX pin state*/

  uint32_t VAL;                                   /*!< UART oversampled values*/

  uint32_t TIMEOUT_CTRL;                          /*!< UART RX timeout control*/

} uart;

/****************************************************************************/
/**                                                                        **/
/**                          EXPORTED VARIABLES                            **/
/**                                                                        **/
/****************************************************************************/

#ifndef _UART_STRUCTS_C_SRC



#endif  /* _UART_STRUCTS_C_SRC */

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



#endif /* _UART_STRUCTS_H */
/****************************************************************************/
/**                                                                        **/
/**                                EOF                                     **/
/**                                                                        **/
/****************************************************************************/
