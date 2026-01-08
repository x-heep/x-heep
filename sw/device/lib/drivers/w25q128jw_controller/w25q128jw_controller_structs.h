/*
                              *******************
******************************* H SOURCE FILE *******************************
**                            *******************                          **
**                                                                         **
** project  : x-heep                                                       **
** filename : w25q128jw_controller_structs.h                                 **
** date     : 22/12/2025                                                      **
**                                                                         **
*****************************************************************************
**                                                                         **
**                                                                         **
*****************************************************************************

*/

/**
* @file   w25q128jw_controller_structs.h
* @date   22/12/2025
* @brief  Contains structs for every register
*
* This file contains the structs of the registes of the peripheral.
* Each structure has the various bit fields that can be accessed
* independently.
* 
*/

#ifndef _W25Q128JW_CONTROLLER_STRUCTS_H
#define W25Q128JW_CONTROLLER_STRUCTS

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

#define w25q128jw_controller_peri ((volatile w25q128jw_controller *) W25Q128JW_CONTROLLER_START_ADDRESS)

/****************************************************************************/
/**                                                                        **/
/**                       TYPEDEFS AND STRUCTURES                          **/
/**                                                                        **/
/****************************************************************************/



typedef struct {

  uint32_t CONTROL;                               /*!< Control register for flash controller*/

  uint32_t STATUS;                                /*!< Status register for flash controller*/

  uint32_t F_ADDRESS;                             /*!< Address in flash to read from/write to*/

  uint32_t S_ADDRESS;                             /*!< Address to store read data from SPI_FLASH*/

  uint32_t MD_ADDRESS;                            /*!< Address where data with which we have to modify the flash is*/

  uint32_t LENGTH;                                /*!< Length of data to W/R*/

  uint32_t INTR_STATUS;                           /*!< Interrupt status register*/

} w25q128jw_controller;

/****************************************************************************/
/**                                                                        **/
/**                          EXPORTED VARIABLES                            **/
/**                                                                        **/
/****************************************************************************/

#ifndef _W25Q128JW_CONTROLLER_STRUCTS_C_SRC



#endif  /* _W25Q128JW_CONTROLLER_STRUCTS_C_SRC */

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



#endif /* _W25Q128JW_CONTROLLER_STRUCTS_H */
/****************************************************************************/
/**                                                                        **/
/**                                EOF                                     **/
/**                                                                        **/
/****************************************************************************/
