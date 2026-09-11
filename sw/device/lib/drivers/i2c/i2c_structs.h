/*
                              *******************
******************************* H SOURCE FILE *******************************
**                            *******************                          **
**                                                                         **
** project  : x-heep                                                       **
** filename : i2c_structs.h                                 **
**                                                                         **
*****************************************************************************
**                                                                         **
**                                                                         **
*****************************************************************************

*/

/**
* @file   i2c_structs.h
* @brief  Contains structs for every register
*
* This file contains the structs of the registes of the peripheral.
* Each structure has the various bit fields that can be accessed
* independently.
* 
*/

#ifndef _I2C_STRUCTS_H
#define _I2C_STRUCTS_H

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

#define i2c_peri ((volatile i2c *) I2C_START_ADDRESS)

/****************************************************************************/
/**                                                                        **/
/**                       TYPEDEFS AND STRUCTURES                          **/
/**                                                                        **/
/****************************************************************************/



typedef struct {

  uint32_t INTR_STATE;                            /*!< Interrupt State Register*/

  uint32_t INTR_ENABLE;                           /*!< Interrupt Enable Register*/

  uint32_t INTR_TEST;                             /*!< Interrupt Test Register*/

  uint32_t CTRL;                                  /*!< I2C control register (Functions TBD)*/

  uint32_t STATUS;                                /*!< I2C live status register*/

  uint32_t RDATA;                                 /*!< I2C read data*/

  uint32_t FDATA;                                 /*!< I2C Format Data*/

  uint32_t FIFO_CTRL;                             /*!< I2C FIFO control register*/

  uint32_t FIFO_STATUS;                           /*!< I2C FIFO status register*/

  uint32_t OVRD;                                  /*!< I2C override control register*/

  uint32_t VAL;                                   /*!< Oversampled RX values*/

  uint32_t TIMING0;                               /*!< Detailed I2C Timings (directly corresponding to table 10 in the I2C Specification). All values are expressed in units of the input clock period.*/

  uint32_t TIMING1;                               /*!< Detailed I2C Timings (directly corresponding to table 10 in the I2C Specification). All values are expressed in units of the input clock period.*/

  uint32_t TIMING2;                               /*!< Detailed I2C Timings (directly corresponding to table 10 in the I2C Specification). All values are expressed in units of the input clock period.*/

  uint32_t TIMING3;                               /*!< Detailed I2C Timings (directly corresponding to table 10, in the I2C Specification). All values are expressed in units of the input clock period.*/

  uint32_t TIMING4;                               /*!< Detailed I2C Timings (directly corresponding to table 10, in the I2C Specification). All values are expressed in units of the input clock period.*/

  uint32_t TIMEOUT_CTRL;                          /*!< I2C clock stretching timeout control*/

  uint32_t TARGET_ID;                             /*!< I2C target address and mask pairs*/

  uint32_t ACQDATA;                               /*!< I2C target acquired data*/

  uint32_t TXDATA;                                /*!< I2C target transmit data*/

  uint32_t STRETCH_CTRL;                          /*!< I2C target clock stretching control*/

  uint32_t HOST_TIMEOUT_CTRL;                     /*!< I2C host clock generation timeout value (in units of input clock frequency)*/

} i2c;

/****************************************************************************/
/**                                                                        **/
/**                          EXPORTED VARIABLES                            **/
/**                                                                        **/
/****************************************************************************/

#ifndef _I2C_STRUCTS_C_SRC



#endif  /* _I2C_STRUCTS_C_SRC */

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



#endif /* _I2C_STRUCTS_H */
/****************************************************************************/
/**                                                                        **/
/**                                EOF                                     **/
/**                                                                        **/
/****************************************************************************/
