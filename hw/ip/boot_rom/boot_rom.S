// See LICENSE.SiFive for license details.

#include "core_v_mini_mcu.h"
#include "soc_ctrl_regs.h"
#include "spi_memio_regs.h"
#include "power_manager_regs.h"
#include "spi_host_regs.h"

#define SOC_CTRL_START_ADDRESS_20bit (SOC_CTRL_START_ADDRESS >> 12)
#define FLASH_MEM_START_ADDRESS_20bit (FLASH_MEM_START_ADDRESS >> 12)
#define SPI_MEMIO_START_ADDRESS_20bit (SPI_MEMIO_START_ADDRESS >> 12)
#define POWER_MANAGER_START_ADDRESS_20bit (POWER_MANAGER_START_ADDRESS >> 12)
#define SPI_FLASH_START_ADDRESS_20bit (SPI_FLASH_START_ADDRESS >> 12)

#define SEXT_IMM(x) ((x) | (-(((x) >> 11) & 1) << 11))

       .global entry

entry:
       // Check if recovering from sleep state
       lui     a1, POWER_MANAGER_START_ADDRESS_20bit
       lbu     a0, POWER_MANAGER_WAKEUP_STATE_REG_OFFSET(a1)
       beqz    a0, boot
       // Restoring
       lw      a0, POWER_MANAGER_RESTORE_ADDRESS_REG_OFFSET(a1)
       jalr    a0
boot:
       // Read boot sel register
       lui     a1, SOC_CTRL_START_ADDRESS_20bit
       lbu     a0, SOC_CTRL_BOOT_SELECT_REG_OFFSET(a1)
       bnez    a0, _jump_to_flash

_jump_to_debug_rom:
       lbu    a0, SOC_CTRL_BOOT_EXIT_LOOP_REG_OFFSET(a1)
       // Check whether exit_loop flag is 1, otherwise jump back to entry
       beqz   a0, entry
       lw     a1, SOC_CTRL_BOOT_ADDRESS_REG_OFFSET(a1)
       jalr   a1

_jump_to_flash:
       lbu    a0, SOC_CTRL_USE_SPIMEMIO_REG_OFFSET(a1)
       beqz   a0, _copy_from_flash

_execute_from_flash:
       lui    a1, SPI_MEMIO_START_ADDRESS_20bit
       addi   a0, zero, 1
       sw     a0, OBI_SPIMEMIO_START_SPIMEM_REG_OFFSET(a1)
       lui    a1, FLASH_MEM_START_ADDRESS_20bit
       addi   a1, a1, SEXT_IMM(0x180)
       jalr   a1

_copy_from_flash:
       lui    a1, SPI_FLASH_START_ADDRESS_20bit
       // Enable spi
       lui    a0, 0xa0000
       lw     a4, SPI_HOST_CONTROL_REG_OFFSET(a1)
       or     a4, a4, a0
       sw     a4, SPI_HOST_CONTROL_REG_OFFSET(a1)
       // Create config_opt: 0x0FFF0001
       lui    a4, 0xfff0
       addi   a4, a4, 1
       sw     a4, SPI_HOST_CONFIGOPTS_0_REG_OFFSET(a1)
       // Set spi csid
       li     a0, 0
       sw     a0, SPI_HOST_CSID_REG_OFFSET(a1)
       // Set spi receiver watermark to 8
       lw     a4, SPI_HOST_CONTROL_REG_OFFSET(a1)
       andi   a4, a4, -256 # ~SPI_HOST_CONTROL_RX_WATERMARK_MASK
       ori    a4, a4, 8
       sw     a4, SPI_HOST_CONTROL_REG_OFFSET(a1)

       // Power up flash (0xab flash command)
       li     a4, 0xab
       sw     a4, SPI_HOST_TXDATA_REG_OFFSET(a1)
       // Power up command: 0x10000003 (transmit 4 words)
       lui    a4, 0x10000
       addi   a4, a4, 3
       sw     a4, SPI_HOST_COMMAND_REG_OFFSET(a1)

_wait_spi_ready_cmd_pwr:
       // Wait spi is ready for next command
       lw     a4, SPI_HOST_STATUS_REG_OFFSET(a1)
       bgez   a4, _wait_spi_ready_cmd_pwr

       // Fill TX FIFO with TX data (read command 0x03 + 3B address 0x000)
       li     a4, 0x03
       sw     a4, SPI_HOST_TXDATA_REG_OFFSET(a1)
       nop    # otherwise ready bit check is too fast

_wait_spi_ready_tx_init:
       lw     a4, SPI_HOST_STATUS_REG_OFFSET(a1)
       bgez   a4, _wait_spi_ready_tx_init
       // Read command: 0x11000003
       lui    a4, 0x11000
       addi   a4, a4, 3 # spi cmd: txonly + stdspeed + csaat + 4B
       sw     a4, SPI_HOST_COMMAND_REG_OFFSET(a1)
       nop    # otherwise ready bit check is too fast

_wait_spi_ready_read_prog:
       lw     a5, SPI_HOST_STATUS_REG_OFFSET(a1)
       bgez   a5, _wait_spi_ready_read_prog
       li     a3, 2048 # 2KB copy size
       li     s1, 0 # dst ptr (ram)

       // For loop until the 1KB copy from flash to ram is done
       // 256-bytes copies are done
       li     t1, 256
       // Read command: 0x90000FF
       lui    s0, 0x9000
       addi   tp, s0, 255 # spi cmd: rxonly + stdspeed + csaat + 255 bytes

_32B_chunk_loop:
       blt    t1, a3, _read_32B_chunk
       // End the transaction if last 256 bytes
       // Read command: 0x80000FF
       lui    s0, 0x8000
       addi   tp, s0, 255 # spi cmd: rxonly + stdspeed + 255 bytes

_read_32B_chunk:
       sw     tp, SPI_HOST_COMMAND_REG_OFFSET(a1)
       nop    # otherwise ready bit check is too fast

_wait_spi_ready_read_32B_chunk:
       lw     a5, SPI_HOST_STATUS_REG_OFFSET(a1)
       bgez   a5, _wait_spi_ready_read_32B_chunk
       addi   t2, s1, 256 # add 32*8 (256 bytes) to dst ptr

_wait_spi_rxwm_8_words:
       lw     a5, SPI_HOST_STATUS_REG_OFFSET(a1)
       srli   a5, a5, 0x14
       andi   a5, a5, 1 # SPI_HOST_STATUS_RXWM_BIT
       beqz   a5, _wait_spi_rxwm_8_words
       addi   a2, s1, 32 # add 32 bytes (4 words) to dst ptr

_spi_fifo_read_8_words:
       // Read 32B (8 words) from RX FIFO
       lw     t0, SPI_HOST_RXDATA_REG_OFFSET(a1)
       sw     t0, 0(s1)
       addi   s1, s1, 4
       bne    s1, a2, _spi_fifo_read_8_words
       bne    s1, t2, _wait_spi_rxwm_8_words
       addi   a3, a3, -256
       bnez   a3, _32B_chunk_loop

       // 1 KB copy from flash to ram finished, jump to ram boot address
       lui    a1, SOC_CTRL_START_ADDRESS_20bit
       // Load ram boot address
       lw     a2, SOC_CTRL_BOOT_ADDRESS_REG_OFFSET(a1)
       jalr   a2
