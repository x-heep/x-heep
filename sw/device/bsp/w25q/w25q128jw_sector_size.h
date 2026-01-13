/*
                              *******************
******************************* H HEADER FILE *****************************
**                            *******************
**
** project  : X-HEEP
** filename : w25q128jw.h
** version  : 1
** date     : 1/11/2023
**
***************************************************************************
**
** Copyright (c) EPFL contributors.
** All rights reserved.
**
***************************************************************************
*/

/***************************************************************************/
/***************************************************************************/

/**
* @file   w25q128jw.h
* @date   13/02/23
* @brief  Header file for the W25Q128JW flash memory.
*/

#ifndef W25Q128JW_SECTOR_SIZE_H
#define W25Q128JW_SECTOR_SIZE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Dimension of a flash sector, in bytes.
*/
#define FLASH_SECTOR_SIZE 4096

#ifdef __cplusplus
} // extern "C"
#endif

#endif /* W25Q128JW_SECTOR_SIZE_H */
/****************************************************************************/
/**                                                                        **/
/**                                EOF                                     **/
/**                                                                        **/
/****************************************************************************/