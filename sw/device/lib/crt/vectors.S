/*
* Copyright 2019 ETH Zürich and University of Bologna
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

#include "core_v_mini_mcu.h"

.section .vectors, "ax"
.option norvc
vector_table:
	//  0 : exception Handler and user software interrupt
	j handler_exception
	//  1 : supervisor software interrupt
	j __no_irq_handler
	//  2 : unmapped
	j __no_irq_handler
	//  3 : machine software interrupt handler
	j handler_irq_software
	//  4 : user timer interrupt
	j __no_irq_handler
	//  5 : supervisor timer interrupt
	j __no_irq_handler
	//  6 : unmapped
	j __no_irq_handler
	//  7 : machine timer interrupt handler
	j handler_irq_timer
	//  8 : user external interrupt
	j __no_irq_handler
	//  9 : supervisor external interrupt
	j __no_irq_handler
	// 10 : unmapped
	j __no_irq_handler
	// 11 : machine external interrupt handler
	j handler_irq_external
	// 12 : unmapped
	j __no_irq_handler
	// 13 : unmapped
	j __no_irq_handler
	// 14 : unmapped
	j __no_irq_handler
	// 15 : unmapped
	j __no_irq_handler
	// 16 : fast interrupt - timer_1
	j handler_irq_fast_timer_1
	// 17 : fast interrupt - timer_2
	j handler_irq_fast_timer_2
	// 18 : fast interrupt - timer_3
	j handler_irq_fast_timer_3
#ifdef DMA_IS_INCLUDED
	// 19 : fast interrupt - dma_done
	j handler_irq_fast_dma_done
#else
	j __no_irq_handler
#endif
#ifdef SPI_HOST_IS_INCLUDED
	// 20 : fast interrupt - spi
	j handler_irq_fast_spi
#else
	j __no_irq_handler
#endif
#ifdef SPI_FLASH_IS_INCLUDED
	// 21 : fast interrupt - spi_flash
	j handler_irq_fast_spi_flash
#else
	j __no_irq_handler
#endif
	// 22 : fast interrupt - gpio_0
	j handler_irq_fast_gpio_0
	// 23 : fast interrupt - gpio_1
	j handler_irq_fast_gpio_1
	// 24 : fast interrupt - gpio_2
	j handler_irq_fast_gpio_2
	// 25 : fast interrupt - gpio_3
	j handler_irq_fast_gpio_3
	// 26 : fast interrupt - gpio_4
	j handler_irq_fast_gpio_4
	// 27 : fast interrupt - gpio_5
	j handler_irq_fast_gpio_5
	// 28 : fast interrupt - gpio_6
	j handler_irq_fast_gpio_6
	// 29 : fast interrupt - gpio_7
	j handler_irq_fast_gpio_7
#ifdef DMA_IS_INCLUDED
	// 30 : fast interrupt - dma_window
	j handler_irq_fast_dma_window
#else
	j __no_irq_handler
#endif
	// 31 : fast interrupt - external peripheral
	j handler_irq_fast_external_peripheral


.section .text.vecs
/* exception handling */
.globl __no_irq_handler
__no_irq_handler:
	/*
	REMOVING THIS CALL REDUCES CODE SIZE CONSIDERABLY
	This will not print an error message in case of not finding
	the proper handler to manage an interrupt.
	la a0, no_exception_handler_msg
	jal ra, puts
	*/
	j __no_irq_handler

/*
THESE STRINGS ARE NOT LONGER NEEDED
Only the last two were used, and their
call was removed to reduce base code size
.section .rodata
illegal_insn_msg:
	.string "illegal instruction exception handler entered\n"
ecall_msg:
	.string "ecall exception handler entered\n"
ebreak_msg:
	.string "ebreak exception handler entered\n"
unknown_msg:
	.string "unknown exception handler entered\n"
no_exception_handler_msg:
	.string "no exception handler installed\n"
*/