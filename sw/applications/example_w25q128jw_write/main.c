/**
 * @file main.c
 * @brief Example application for W25Q128JW flash write test.
 *
 * This application demonstrates writing data to the W25Q128JW flash memory
 * then reading it back and verifying the contents match the original data.
 *
 * Test parameters:
 * - Transfer size: 4100 bytes (spanning over 2 sectors) (write operation is word precise)
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include "memory.h"

#include "core_v_mini_mcu.h"
#include "x-heep.h"

#include "w25q128jw_controller.h"
#include "data.h"
#include "w25q128jw.h"
#include "dma.h"

/* Set to 1 if running on Verilator, 0 otherwise (QuestaSim or FPGA)
    It skips unsupported test cases (e.g., quad write)
*/
#if TARGET_SIM
    #define SIM_VERILATOR 1 // Set to 0 when running with QuestaSim
#else
    #define SIM_VERILATOR 0
#endif

/* Write operation flags */
#define FLAG_SW    (1)       /* Software write (default HW) */
#define FLAG_INT   (1 << 1)  /* Interrupt-driven write (default no interrupts) */
#define FLAG_QUAD  (1 << 2)  /* Quad SPI mode (default single mode) */

#define SRAM_GUARD_PATTERN 0xA5U

#define STOP_ON_FIRST_FAILURE 1    /* Stop on first failure (1) or run all tests (0) */

#define EXEC_WORD_TESTS 1  /* Word-aligned transfers */
#define EXEC_BYTE_TESTS 0  /* Sub-word or non-word-aligned transfers (does not work with a cache currently) */
#define EXEC_WRITEBACK_TESTS 1  /* Cache writeback (only meaningful if cache enabled) */

/* By default, printfs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   0

#if TARGET_SIM && PRINTF_IN_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

int test_counter = 0;

//
// ISR
//
void handler_irq_w25q128jw_controller(uint32_t id) {
    // Set the done flag
    w25q128jw_controller_set_done_flag();

    // Clear the interrupt status register (interrupt handled)
    w25q128jw_controller_clear_status_register();
}

/**
 * @brief Perform a write operation from SRAM to FLASH, either using software or hardware write.
 * @param sram_src: SRAM pointer
 * @param flash_dst: Flash pointer
 * @param len: number of bytes to write
 * @param flags: write operation flags (e.g., FLAG_SW, FLAG_INT, FLAG_QUAD)
 * @return 0 if the write operation is successful, 1 otherwise.
 */
static int do_write(
    const void *sram_src, void *flash_dst, uint32_t len, uint32_t flags
) {
    w25q_error_codes_t status = FLASH_OK;

    if (flags & FLAG_SW) {
        // Software write (standard speed, no interrupts, with DMA)
        status = w25q128jw_erase_and_write_standard_dma((uint32_t)(uintptr_t)flash_dst, (void *)sram_src, len);
        return (status == FLASH_OK) ? 0 : 1;
    } else {
        // Hardware write (using the controller)
        uint32_t interrupts = (flags & FLAG_INT)  ? 1U : 0U;
        uint32_t quad       = (flags & FLAG_QUAD) ? 1U : 0U;

        w25q128jw_controller_write((void *)flash_dst, (void *)sram_src, len, interrupts, quad);
        return 0;
    }
}

/**
 * @brief Trusted read from the FLASH device.
 *
 * @param flash_src: Flash pointer
 * @param sram_dst: SRAM pointer
 * @param len: number of bytes to read
 * @return 0 if the read is successful, 1 otherwise.
 */
static int safe_read(
    const void *flash_src, void *sram_dst, uint32_t len
) {
    // HW READ has been intensively tested and we assume it works correctly
    w25q128jw_controller_read((void *)sram_dst, (void *)flash_src, len, 1, 0);
    return 0;
}

/**
 * @brief Compare two buffers (byte by byte) and print mismatches.
 * @return 0 if the buffers match, 1 if there is a mismatch.
 */
static int compare_buffers(const void *expected, const void *actual, uint32_t len) {
    const uint8_t *expected_bytes = (const uint8_t *)(void *)expected;
    const uint8_t *actual_bytes   = (const uint8_t *)(void *)actual;

    int error = 0;

    for (uint32_t i = 0; i < len; ++i) {
        if (expected_bytes[i] != actual_bytes[i]) {
            PRINTF("Mismatch at %d: expected 0x%x, got 0x%x\n", i, expected_bytes[i], actual_bytes[i]);
            error = 1;
        }
    }

    return error;
}

/**
 * @brief Verify that bytes outside [offset, offset + len) still contain the guard pattern.
 * @return 0 if guard regions are intact, 1 otherwise.
 */
static int verify_guard_regions(
    const void *buffer,
    uint32_t buffer_len,
    uint32_t offset,
    uint32_t len,
    uint8_t guard_pattern
) {
    const uint8_t *bytes = (const uint8_t *)(void *)buffer;
    int error = 0;

    for (uint32_t i = 0; i < buffer_len; ++i) {
        if (i >= offset && i < (offset + len)) {
            continue;
        }

        if (bytes[i] != guard_pattern) {
            PRINTF("Guard mismatch at %d: expected 0x%x, got 0x%x\n", i, guard_pattern, bytes[i]);
            error = 1;
        }
    }

    return error;
}

/**
 * @brief Run a test case for writing to flash and verifying the contents.
 * @param name: test case name for logging
 * @param sram_source_base: base pointer for source data (SRAM)
 * @param flash_dest_base: base pointer for destination data (Flash)
 * @param sram_read_back_base: base pointer for read back data (SRAM)
 * @param sram_expected_base: base pointer for correct data (SRAM)
 * @param offset: offset in bytes to apply to the base pointers for this test case
 * @param len: number of bytes to write/read
 * @param flags: write operation flags (e.g., FLAG_SW, FLAG_INT, FLAG_QUAD)
 * @return 0 if the write operation and verification are successful, 1 otherwise.
 */
static int run_case(
    const char *name,
    const void *sram_source_base,
    const void *flash_dest_base,
    void *sram_read_back_base,
    const void *sram_expected_base,
    uint32_t offset,
    uint32_t len,
    uint32_t flags
) {
    const uint32_t sram_buffer_len = NUM_BYTES;

    void *src       = (void *)((char *)sram_source_base    + offset);
    void *dst       = (void *)((char *)flash_dest_base     + offset);
    void *read_back = (void *)((char *)sram_read_back_base + offset);
    void *expected  = (void *)((char *)sram_expected_base  + offset);

    memset((void *)sram_read_back_base, SRAM_GUARD_PATTERN, sram_buffer_len);

    PRINTF("%d) %s: ", test_counter++, name);

    // Step 1: Write SRAM -> Flash
    if (do_write(src, dst, len, flags) != 0) {
        PRINTF("write operation failed\n");

        #if STOP_ON_FIRST_FAILURE
            exit(EXIT_FAILURE);
        #else
            return 1;
        #endif
    }

    // Step 2: Read back Flash -> SRAM (using safe read, assumed to work correctly)
    if (safe_read(dst, read_back, len) != 0) {
        PRINTF("read back operation failed\n");

        #if STOP_ON_FIRST_FAILURE
            exit(EXIT_FAILURE);
        #else
            return 1;
        #endif
    }

    // Step 3: Compare read back data with expected data
    if (compare_buffers(expected, read_back, len) != 0) {
        PRINTF("FAIL\n");

        #if STOP_ON_FIRST_FAILURE
            exit(EXIT_FAILURE);
        #else
            return 1;
        #endif
    }

    // Step 4: Verify guard regions outside of the written area are intact
    if (verify_guard_regions(sram_read_back_base, sram_buffer_len, offset, len, SRAM_GUARD_PATTERN) != 0) {
        PRINTF("FAIL (guard region modified)\n");

        #if STOP_ON_FIRST_FAILURE
            exit(EXIT_FAILURE);
        #else
            return 1;
        #endif
    }

    PRINTF("PASS\n");
    return 0;
}

/**
 * @brief Test cache writeback by writing to sector 0 (marks it dirty), then writing to
 *        sector 4 (same cache set, forces eviction + writeback of sector 0), then
 *        reading back sector 0 from flash to verify the writeback committed.
 * @return 0 if writeback is verified, 1 otherwise.
 */
static int run_cache_writeback_test(
    const char *mode_name,
    const void *sram_source_base,
    const void *flash_dest_base,
    void *sram_read_back_base,
    uint32_t flags
) {
    char test_name[128];
    snprintf(test_name, sizeof(test_name), "%s, cache writeback (sector 0 evicted by sector 4)", mode_name);

    void *flash_sector0 = (void *)flash_dest_base;
    void *flash_sector4 = (void *)((const char *)flash_dest_base + 4U * SECTOR_SIZE_BYTES);

    PRINTF("%d) %s: ", test_counter++, test_name);

    // Write sector 0: loads it into cache as dirty
    if (do_write(sram_source_base, flash_sector0, SECTOR_SIZE_BYTES, flags) != 0) {
        PRINTF("write sector 0 failed\n");
        #if STOP_ON_FIRST_FAILURE
            exit(EXIT_FAILURE);
        #else
            return 1;
        #endif
    }

    // Write sector 4: same cache set as sector 0, forces eviction and writeback
    if (do_write(sram_source_base, flash_sector4, SECTOR_SIZE_BYTES, flags) != 0) {
        PRINTF("write sector 4 failed\n");
        #if STOP_ON_FIRST_FAILURE
            exit(EXIT_FAILURE);
        #else
            return 1;
        #endif
    }

    // Sector 0 has been evicted; read it back (cache miss -> fetch from flash)
    memset(sram_read_back_base, SRAM_GUARD_PATTERN, SECTOR_SIZE_BYTES);
    if (safe_read(flash_sector0, sram_read_back_base, SECTOR_SIZE_BYTES) != 0) {
        PRINTF("read back sector 0 failed\n");
        #if STOP_ON_FIRST_FAILURE
            exit(EXIT_FAILURE);
        #else
            return 1;
        #endif
    }

    if (compare_buffers(sram_source_base, sram_read_back_base, SECTOR_SIZE_BYTES) != 0) {
        PRINTF("FAIL\n");
        #if STOP_ON_FIRST_FAILURE
            exit(EXIT_FAILURE);
        #else
            return 1;
        #endif
    }

    PRINTF("PASS\n");
    return 0;
}

/**
 * @brief Run the standard set of write tests for a given mode.
 * @return Number of failing test cases.
 */
static uint32_t run_mode_tests(
    const char *mode_name,
    const void *sram_source_base,
    const void *flash_dest_base,
    void *sram_read_back_base,
    const void *sram_expected_base,
    uint32_t two_sectors_bytes,
    uint32_t unaligned_single_sector_offset_bytes,
    uint32_t unaligned_cross_sector_offset_bytes,
    uint32_t unaligned_length_bytes,
    uint32_t flags
) {
    uint32_t errors = 0;
    char test_name[128];

#if EXEC_WORD_TESTS
    snprintf(test_name, sizeof(test_name), "%s, single sector", mode_name);
    errors += run_case(
        test_name,
        sram_source_base, flash_dest_base, sram_read_back_base, sram_expected_base,
        0U, SECTOR_SIZE_BYTES, flags
    );

    snprintf(test_name, sizeof(test_name), "%s, two sectors", mode_name);
    errors += run_case(
        test_name,
        sram_source_base, flash_dest_base, sram_read_back_base, sram_expected_base,
        0U, two_sectors_bytes, flags
    );

    snprintf(test_name, sizeof(test_name), "%s, two sectors, 2nd time overwritting previous data", mode_name);
    errors += run_case(
        test_name,
        sram_source_base, flash_dest_base, sram_read_back_base, sram_expected_base,
        0U, two_sectors_bytes, flags
    );
#endif // EXEC_WORD_TESTS

#if EXEC_BYTE_TESTS
    snprintf(test_name, sizeof(test_name), "%s, single byte (1st within the word)", mode_name);
    errors += run_case(
        test_name,
        sram_source_base, flash_dest_base, sram_read_back_base, sram_expected_base,
        0U, 1U, flags
    );

    snprintf(test_name, sizeof(test_name), "%s, single byte (2nd within the word)", mode_name);
    errors += run_case(
        test_name,
        sram_source_base, flash_dest_base, sram_read_back_base, sram_expected_base,
        1U, 1U, flags
    );

    snprintf(test_name, sizeof(test_name), "%s, single byte (3rd within the word)", mode_name);
    errors += run_case(
        test_name,
        sram_source_base, flash_dest_base, sram_read_back_base, sram_expected_base,
        2U, 1U, flags
    );

    snprintf(test_name, sizeof(test_name), "%s, single byte (4th within the word)", mode_name);
    errors += run_case(
        test_name,
        sram_source_base, flash_dest_base, sram_read_back_base, sram_expected_base,
        3U, 1U, flags
    );

    snprintf(test_name, sizeof(test_name), "%s, 2 bytes (with head+tail)", mode_name);
    errors += run_case(
        test_name,
        sram_source_base, flash_dest_base, sram_read_back_base, sram_expected_base,
        3U, 2U, flags
    );

    snprintf(test_name, sizeof(test_name), "%s, 6 bytes (with head+body+tail)", mode_name);
    errors += run_case(
        test_name,
        sram_source_base, flash_dest_base, sram_read_back_base, sram_expected_base,
        2U, 8U, flags
    );

    snprintf(test_name, sizeof(test_name), "%s, 7 bytes (with body+tail)", mode_name);
    errors += run_case(
        test_name,
        sram_source_base, flash_dest_base, sram_read_back_base, sram_expected_base,
        4U, 7U, flags
    );

    snprintf(test_name, sizeof(test_name), "%s, unaligned cross sector", mode_name);
    errors += run_case(
        test_name,
        sram_source_base, flash_dest_base, sram_read_back_base, sram_expected_base,
        unaligned_cross_sector_offset_bytes, unaligned_length_bytes, flags
    );
#endif // EXEC_BYTE_TESTS

#if EXEC_WRITEBACK_TESTS
    errors += run_cache_writeback_test(
        mode_name, sram_source_base, flash_dest_base, sram_read_back_base, flags
    );
#endif // EXEC_WRITEBACK_TESTS

    return errors;
}

int main(void) {
    uint32_t errors = 0;
    const uint32_t two_sectors_bytes = 2U * SECTOR_SIZE_BYTES;

    // Random unaligned offset and length for testing reads
    const uint32_t unaligned_single_sector_offset_bytes = 0x2bU;
    const uint32_t unaligned_cross_sector_offset_bytes = SECTOR_SIZE_BYTES - 0x25U;
    const uint32_t unaligned_length_bytes = 0x71U;

    // Initialize the DMA
    dma_init(NULL);
    // Pick the correct spi device based on simulation type
    spi_host_t* spi;
    spi = spi_flash;

    // Init SPI host and SPI<->Flash bridge parameters and Flash Power Up
    if (w25q128jw_init(spi) != FLASH_OK) return EXIT_FAILURE;

    int32_t* flash_ptr_buffer = heep_get_flash_address_offset(flash_buffer);
    const void *expected_base = (const void *)sram_source_pattern;

    PRINTF("Starting flash write tests\n");

    errors += run_mode_tests(
        "Hardware Write, standard speed, DMA",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        two_sectors_bytes,
        unaligned_single_sector_offset_bytes,
        unaligned_cross_sector_offset_bytes,
        unaligned_length_bytes,
        0U
    );

    errors += run_mode_tests(
        "Hardware Write, standard speed, DMA, interrupt",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        two_sectors_bytes,
        unaligned_single_sector_offset_bytes,
        unaligned_cross_sector_offset_bytes,
        unaligned_length_bytes,
        FLAG_INT
    );

    #if SIM_VERILATOR == 0

    errors += run_mode_tests(
        "Hardware Write, quad speed, DMA",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        two_sectors_bytes,
        unaligned_single_sector_offset_bytes,
        unaligned_cross_sector_offset_bytes,
        unaligned_length_bytes,
        FLAG_QUAD
    );

    errors += run_mode_tests(
        "Hardware Write, quad speed, DMA, interrupt",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        two_sectors_bytes,
        unaligned_single_sector_offset_bytes,
        unaligned_cross_sector_offset_bytes,
        unaligned_length_bytes,
        FLAG_QUAD | FLAG_INT
    );

    #endif // SIM_VERILATOR

    // Final check: test that dma is still working
    errors += run_case(
        "Manual dma copy",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        0U, two_sectors_bytes, FLAG_SW
    );

    PRINTF("\n--------TEST FINISHED--------\n");
    if (errors == 0) {
        PRINTF("All tests passed!\n");
        return EXIT_SUCCESS;
    } else {
        PRINTF("Some tests failed (%d).\n", errors);
        return EXIT_FAILURE;
    }
}
