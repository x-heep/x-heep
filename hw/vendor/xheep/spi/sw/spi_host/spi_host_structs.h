/*
                              *******************
******************************* H SOURCE FILE *******************************
**                            *******************                          **
**                                                                         **
** project  : x-heep                                                       **
** filename : spi_host_structs.h                                 **
** date     : 10/06/2026                                                      **
**                                                                         **
*****************************************************************************
**                                                                         **
**                                                                         **
*****************************************************************************

*/

/**
* @file   spi_host_structs.h
* @date   10/06/2026
* @brief  Contains structs for every register
*
* This file contains the structs of the registes of the peripheral.
* Each structure has the various bit fields that can be accessed
* independently.
* 
*/

#ifndef _SPI_HOST_STRUCTS_H
#define SPI_HOST_STRUCTS

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

#define spi_host_peri ((volatile spi_host *) SPI_HOST_START_ADDRESS)

/****************************************************************************/
/**                                                                        **/
/**                       TYPEDEFS AND STRUCTURES                          **/
/**                                                                        **/
/****************************************************************************/



typedef struct {

  uint32_t INTR_STATE;                            /*!< Interrupt State Register*/

  uint32_t INTR_ENABLE;                           /*!< Interrupt Enable Register*/

  uint32_t INTR_TEST;                             /*!< Interrupt Test Register*/

  uint32_t ALERT_TEST;                            /*!< Alert Test Register*/

  uint32_t CONTROL;                               /*!< Control register*/

  uint32_t STATUS;                                /*!< Status register*/

  uint32_t CONFIGOPTS0;                           /*!< Configuration options register.     Contains options for controlling each peripheral. One register per    cs_n line*/

  uint32_t CONFIGOPTS1;                           /*!< Configuration options register.     Contains options for controlling each peripheral. One register per    cs_n line*/

  uint32_t CSID;                                  /*!< Chip-Select ID     Controls which device to target with the next command.  This register    is passed to the core whenever !!COMMAND is written.  The core then    asserts cio_csb_o[!!CSID] during the execution of the command.*/

  uint32_t COMMAND;                               /*!< Command Register     Parameters specific to each command segment.  Unlike the !!CONFIGOPTS multi-register,    there is only one command register for controlling all attached SPI devices*/

  uint32_t RXDATA;                                /*!< SPI Receive Data.     Reads from this window pull data from the RXFIFO.     The serial order of bit transmission    is chosen to match SPI flash devices. Individual bytes    are always transmitted with the most significant bit first.    Only four-bute reads are supported. If ByteOrder = 0,    the first byte received is packed in the MSB of !!RXDATA.    For some processor architectures, this could lead to shuffling    of flash data as compared to how it is written in memory.    In which case, choosing ByteOrder = 1 can reverse the    byte-order of each data read, causing the first byte    received to be packed into the LSB of !!RXDATA. (Though within    each byte the most significant bit is always pulled    from the bus first.)    */

  uint32_t TXDATA;                                /*!< SPI Transmit Data.     Data written to this window is placed into the TXFIFO.    Byte-enables are supported for writes.     The serial order of bit transmission    is chosen to match SPI flash devices. Individual bytes    are always transmitted with the most significant bit first.    Multi-byte writes are also supported, and if ByteOrder = 0,    the bits of !!TXDATA are transmitted strictly in order of    decreasing signficance (i.e. most signicant bit first).    For some processor architectures, this could lead to shuffling    of flash data as compared to how it is written in memory.    In which case, choosing ByteOrder = 1 can reverse the    byte-order of multi-byte data writes.  (Though within    each byte the most significant bit is always sent first.)    */

  uint32_t ERROR_ENABLE;                          /*!< Controls which classes of errors raise an interrupt.*/

  uint32_t ERROR_STATUS;                          /*!< Indicates that any errors that have occurred.    When an error    occurs, the corresponding bit must be cleared here before    issuing any further commands.*/

  uint32_t EVENT_ENABLE;                          /*!< Controls which classes of SPI events raise an interrupt.*/

} spi_host;

/****************************************************************************/
/**                                                                        **/
/**                          EXPORTED VARIABLES                            **/
/**                                                                        **/
/****************************************************************************/

#ifndef _SPI_HOST_STRUCTS_C_SRC



#endif  /* _SPI_HOST_STRUCTS_C_SRC */

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



#endif /* _SPI_HOST_STRUCTS_H */
/****************************************************************************/
/**                                                                        **/
/**                                EOF                                     **/
/**                                                                        **/
/****************************************************************************/
