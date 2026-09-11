/*
                              *******************
******************************* H SOURCE FILE *******************************
**                            *******************                          **
**                                                                         **
** project  : x-heep                                                       **
** filename : RV_PLIC_structs.h                                 **
**                                                                         **
*****************************************************************************
**                                                                         **
**                                                                         **
*****************************************************************************

*/

/**
* @file   RV_PLIC_structs.h
* @brief  Contains structs for every register
*
* This file contains the structs of the registes of the peripheral.
* Each structure has the various bit fields that can be accessed
* independently.
* 
*/

#ifndef _RV_PLIC_STRUCTS_H
#define _RV_PLIC_STRUCTS_H

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

#define rv_plic_peri ((volatile RV_PLIC *) RV_PLIC_START_ADDRESS)

/****************************************************************************/
/**                                                                        **/
/**                       TYPEDEFS AND STRUCTURES                          **/
/**                                                                        **/
/****************************************************************************/



typedef struct {

  uint32_t IP0;                                   /*!< Interrupt Pending*/

  uint32_t IP1;                                   /*!< Interrupt Pending*/

  uint32_t LE0;                                   /*!< Interrupt Source mode. 0: Level, 1: Edge-triggered*/

  uint32_t LE1;                                   /*!< Interrupt Source mode. 0: Level, 1: Edge-triggered*/

  uint32_t PRIO0;                                 /*!< Interrupt Source 0 Priority*/

  uint32_t PRIO1;                                 /*!< Interrupt Source 1 Priority*/

  uint32_t PRIO2;                                 /*!< Interrupt Source 2 Priority*/

  uint32_t PRIO3;                                 /*!< Interrupt Source 3 Priority*/

  uint32_t PRIO4;                                 /*!< Interrupt Source 4 Priority*/

  uint32_t PRIO5;                                 /*!< Interrupt Source 5 Priority*/

  uint32_t PRIO6;                                 /*!< Interrupt Source 6 Priority*/

  uint32_t PRIO7;                                 /*!< Interrupt Source 7 Priority*/

  uint32_t PRIO8;                                 /*!< Interrupt Source 8 Priority*/

  uint32_t PRIO9;                                 /*!< Interrupt Source 9 Priority*/

  uint32_t PRIO10;                                /*!< Interrupt Source 10 Priority*/

  uint32_t PRIO11;                                /*!< Interrupt Source 11 Priority*/

  uint32_t PRIO12;                                /*!< Interrupt Source 12 Priority*/

  uint32_t PRIO13;                                /*!< Interrupt Source 13 Priority*/

  uint32_t PRIO14;                                /*!< Interrupt Source 14 Priority*/

  uint32_t PRIO15;                                /*!< Interrupt Source 15 Priority*/

  uint32_t PRIO16;                                /*!< Interrupt Source 16 Priority*/

  uint32_t PRIO17;                                /*!< Interrupt Source 17 Priority*/

  uint32_t PRIO18;                                /*!< Interrupt Source 18 Priority*/

  uint32_t PRIO19;                                /*!< Interrupt Source 19 Priority*/

  uint32_t PRIO20;                                /*!< Interrupt Source 20 Priority*/

  uint32_t PRIO21;                                /*!< Interrupt Source 21 Priority*/

  uint32_t PRIO22;                                /*!< Interrupt Source 22 Priority*/

  uint32_t PRIO23;                                /*!< Interrupt Source 23 Priority*/

  uint32_t PRIO24;                                /*!< Interrupt Source 24 Priority*/

  uint32_t PRIO25;                                /*!< Interrupt Source 25 Priority*/

  uint32_t PRIO26;                                /*!< Interrupt Source 26 Priority*/

  uint32_t PRIO27;                                /*!< Interrupt Source 27 Priority*/

  uint32_t PRIO28;                                /*!< Interrupt Source 28 Priority*/

  uint32_t PRIO29;                                /*!< Interrupt Source 29 Priority*/

  uint32_t PRIO30;                                /*!< Interrupt Source 30 Priority*/

  uint32_t PRIO31;                                /*!< Interrupt Source 31 Priority*/

  uint32_t PRIO32;                                /*!< Interrupt Source 32 Priority*/

  uint32_t PRIO33;                                /*!< Interrupt Source 33 Priority*/

  uint32_t PRIO34;                                /*!< Interrupt Source 34 Priority*/

  uint32_t PRIO35;                                /*!< Interrupt Source 35 Priority*/

  uint32_t PRIO36;                                /*!< Interrupt Source 36 Priority*/

  uint32_t PRIO37;                                /*!< Interrupt Source 37 Priority*/

  uint32_t PRIO38;                                /*!< Interrupt Source 38 Priority*/

  uint32_t PRIO39;                                /*!< Interrupt Source 39 Priority*/

  uint32_t PRIO40;                                /*!< Interrupt Source 40 Priority*/

  uint32_t PRIO41;                                /*!< Interrupt Source 41 Priority*/

  uint32_t PRIO42;                                /*!< Interrupt Source 42 Priority*/

  uint32_t PRIO43;                                /*!< Interrupt Source 43 Priority*/

  uint32_t PRIO44;                                /*!< Interrupt Source 44 Priority*/

  uint32_t PRIO45;                                /*!< Interrupt Source 45 Priority*/

  uint32_t PRIO46;                                /*!< Interrupt Source 46 Priority*/

  uint32_t PRIO47;                                /*!< Interrupt Source 47 Priority*/

  uint32_t PRIO48;                                /*!< Interrupt Source 48 Priority*/

  uint32_t PRIO49;                                /*!< Interrupt Source 49 Priority*/

  uint32_t PRIO50;                                /*!< Interrupt Source 50 Priority*/

  uint32_t PRIO51;                                /*!< Interrupt Source 51 Priority*/

  uint32_t PRIO52;                                /*!< Interrupt Source 52 Priority*/

  uint32_t PRIO53;                                /*!< Interrupt Source 53 Priority*/

  uint32_t PRIO54;                                /*!< Interrupt Source 54 Priority*/

  uint32_t PRIO55;                                /*!< Interrupt Source 55 Priority*/

  uint32_t PRIO56;                                /*!< Interrupt Source 56 Priority*/

  uint32_t PRIO57;                                /*!< Interrupt Source 57 Priority*/

  uint32_t PRIO58;                                /*!< Interrupt Source 58 Priority*/

  uint32_t PRIO59;                                /*!< Interrupt Source 59 Priority*/

  uint32_t PRIO60;                                /*!< Interrupt Source 60 Priority*/

  uint32_t PRIO61;                                /*!< Interrupt Source 61 Priority*/

  uint32_t PRIO62;                                /*!< Interrupt Source 62 Priority*/

  uint32_t PRIO63;                                /*!< Interrupt Source 63 Priority*/

  uint32_t _reserved_0[60];                       /*!< reserved addresses*/

  uint32_t IE00;                                  /*!< Interrupt Enable for Target 0*/

  uint32_t IE01;                                  /*!< Interrupt Enable for Target 0*/

  uint32_t THRESHOLD0;                            /*!< Threshold of priority for Target 0*/

  uint32_t CC0;                                   /*!< Claim interrupt by read, complete interrupt by write for Target 0. Value read/written is interrupt ID. Reading a value of 0 means no pending interrupts.*/

  uint32_t MSIP0;                                 /*!< msip for Hart 0. Write 1 to here asserts software interrupt for Hart msip_o[0], write 0 to clear.*/

} RV_PLIC;

/****************************************************************************/
/**                                                                        **/
/**                          EXPORTED VARIABLES                            **/
/**                                                                        **/
/****************************************************************************/

#ifndef _RV_PLIC_STRUCTS_C_SRC



#endif  /* _RV_PLIC_STRUCTS_C_SRC */

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



#endif /* _RV_PLIC_STRUCTS_H */
/****************************************************************************/
/**                                                                        **/
/**                                EOF                                     **/
/**                                                                        **/
/****************************************************************************/
