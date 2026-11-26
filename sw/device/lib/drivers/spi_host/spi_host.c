/*
                              *******************
******************************* C SOURCE FILE *****************************
**                            *******************
**
** project  : X-HEEP
** filename : spi_host.c
** version  : 1
** date     : 06/03/24
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
* @file   spi_host.c
* @date   06/03/24
* @author Llorenç Muela
* @brief  The Serial Peripheral Interface (SPI) driver to set up and use the
* SPI peripheral
*/

/****************************************************************************/
/**                                                                        **/
/*                             MODULES USED                                 */
/**                                                                        **/
/****************************************************************************/
#ifdef __cplusplus
extern "C" {
#endif
#include "spi_host.h"

#include "bitfield.h"


/****************************************************************************/
/**                                                                        **/
/*                        DEFINITIONS AND MACROS                            */
/**                                                                        **/
/****************************************************************************/

#define SPI_EVENTS_INDEX    0
#define SPI_ERRORS_INDEX    0

/* One CONFIGOPTS register per chip select. Callers check csid first. */
#define SPI_CONFIGOPTS_ADDR(spi, csid) \
    ((csid) == 0 ? &SPI_HW(spi)->CONFIGOPTS0 : &SPI_HW(spi)->CONFIGOPTS1)
#if SPI_HOST_PARAM_NUM_C_S != 2
#error "SPI_CONFIGOPTS_ADDR selects CONFIGOPTS0 or CONFIGOPTS1 only"
#endif

/****************************************************************************/
/**                                                                        **/
/*                        TYPEDEFS AND STRUCTURES                           */
/**                                                                        **/
/****************************************************************************/

/****************************************************************************/
/**                                                                        **/
/*                      PROTOTYPES OF LOCAL FUNCTIONS                       */
/**                                                                        **/
/****************************************************************************/

/**
 * @brief Function that translates the status register to spi_event_e type. This
 * has been implemented because the SPI peripheral has no other way to know which
 * event was triggered other than reading the status.
 * This function has been made local since only the event interrupt handler should
 * need it.
 * 
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @param events Pointer to store the events that were triggered.
 * @return spi_return_flags_e indicating problems, SPI_FLAG_OK if all went well.
 */
spi_return_flags_e spi_get_events(spi_host_t* spi, spi_event_e* events);

/**
 * @brief Function to acknoledge event interrupts once received to prevent them
 * from triggering again.
 * 
 * @param spi Pointer to spi_host_t representing the target SPI.
 * @return spi_return_flags_e indicating problems, SPI_FLAG_OK if all went well.
 */
spi_return_flags_e spi_acknowledge_event(spi_host_t* spi);

/****************************************************************************/
/**                                                                        **/
/*                           EXPORTED VARIABLES                             */
/**                                                                        **/
/****************************************************************************/

/****************************************************************************/
/**                                                                        **/
/*                            GLOBAL VARIABLES                              */
/**                                                                        **/
/****************************************************************************/

/****************************************************************************/
/**                                                                        **/
/*                           EXPORTED FUNCTIONS                             */
/**                                                                        **/
/****************************************************************************/

spi_return_flags_e spi_get_events_enabled(spi_host_t* spi, spi_event_e* events) 
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    *events = bitfield_read(SPI_HW(spi)->EVENT_ENABLE, SPI_EVENT_ALL, SPI_EVENTS_INDEX);
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_set_events_enabled(spi_host_t* spi, spi_event_e events, bool enable) 
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    if (events > SPI_EVENT_ALL) return SPI_FLAG_EVENT_INVALID;
    // Since spi_event_e is mapped to EVENT_ENABLE: | = set, & ~ = clear
    if (enable) SPI_HW(spi)->EVENT_ENABLE |= events;
    else        SPI_HW(spi)->EVENT_ENABLE &= ~events;

    return SPI_FLAG_OK;
}

spi_return_flags_e spi_get_errors_enabled(spi_host_t* spi, spi_error_e* errors) 
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    *errors = bitfield_read(SPI_HW(spi)->ERROR_ENABLE, SPI_ERROR_IRQALL, SPI_ERRORS_INDEX);
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_set_errors_enabled(spi_host_t* spi, spi_error_e errors, bool enable)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    if (errors > SPI_ERROR_IRQALL) return SPI_FLAG_ERROR_INVALID;
    // Since spi_error_e is mapped to ERROR_ENABLE: | = set, & ~ = clear
    if (enable) SPI_HW(spi)->ERROR_ENABLE |= errors;
    else        SPI_HW(spi)->ERROR_ENABLE &= ~errors;

    return SPI_FLAG_OK;
}

spi_return_flags_e spi_get_errors(spi_host_t* spi, spi_error_e* errors)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    *errors = bitfield_read(SPI_HW(spi)->ERROR_STATUS, SPI_ERROR_ALL, SPI_ERRORS_INDEX);
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_acknowledge_errors(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    // Write a one to each bit in ERROR_STATUS to clear these bits
    SPI_HW(spi)->ERROR_STATUS = bitfield_write(SPI_HW(spi)->ERROR_STATUS, 
                                               SPI_ERROR_ALL, SPI_ERRORS_INDEX, 
                                               SPI_ERROR_ALL);
    // Write a one to INTR_STATE error bit to clear the error
    SPI_HW(spi)->INTR_STATE   = bitfield_write(SPI_HW(spi)->INTR_STATE, BIT_MASK_1, 
                                               SPI_HOST_INTR_STATE_ERROR_BIT, true);
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_enable_error_intr_test(spi_host_t* spi, bool enable)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    SPI_HW(spi)->INTR_TEST = bitfield_write(SPI_HW(spi)->INTR_TEST, BIT_MASK_1, 
                                            SPI_HOST_INTR_TEST_ERROR_BIT, enable);
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_enable_evt_intr_test(spi_host_t* spi, bool enable)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    SPI_HW(spi)->INTR_TEST = bitfield_write(SPI_HW(spi)->INTR_TEST, BIT_MASK_1, 
                                            SPI_HOST_INTR_TEST_SPI_EVENT_BIT, enable);
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_alert_test_fatal_fault_trigger(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    SPI_HW(spi)->ALERT_TEST = bitfield_write(SPI_HW(spi)->ALERT_TEST, BIT_MASK_1, 
                                             SPI_HOST_ALERT_TEST_FATAL_FAULT_BIT, true);
    return SPI_FLAG_OK;
}

volatile uint8_t spi_get_tx_queue_depth(spi_host_t* spi)
{
    // A NULL host returns UINT8_MAX, above any TX queue depth.
    SPI_NULL_CHECK(spi, UINT8_MAX)
    return spi_get_status(spi).txqd;
}

volatile uint8_t spi_get_rx_queue_depth(spi_host_t* spi)
{
    // Returning an impossible value (rx fifo is 64 words long...)
    SPI_NULL_CHECK(spi, UINT8_MAX)
    return spi_get_status(spi).rxqd;
}

volatile uint32_t spi_get_csid(spi_host_t* spi)
{
    SPI_NULL_CHECK(spi, UINT32_MAX)
    return SPI_HW(spi)->CSID;
}

spi_return_flags_e spi_sw_reset(spi_host_t* spi)
{
    spi_status_t status;

    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    // Assert spi reset bit
    SPI_HW(spi)->CONTROL = bitfield_write(SPI_HW(spi)->CONTROL, BIT_MASK_1, 
                                          SPI_HOST_CONTROL_SW_RST_BIT, true);

    // Wait for spi active and txqd & rxqd both go to 0
    do {
        status = spi_get_status(spi);
    } while (status.active || status.txqd || status.rxqd);
    // Deassert spi reset bit
    SPI_HW(spi)->CONTROL = bitfield_write(SPI_HW(spi)->CONTROL, BIT_MASK_1, 
                                          SPI_HOST_CONTROL_SW_RST_BIT, false);
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_set_enable(spi_host_t* spi, bool enable)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    SPI_HW(spi)->CONTROL = bitfield_write(SPI_HW(spi)->CONTROL, BIT_MASK_1, 
                                          SPI_HOST_CONTROL_SPIEN_BIT, enable);
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_set_tx_watermark(spi_host_t* spi, uint8_t watermark)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    // Check that watermark is not bigger than the fifo size (makes no sense otherwise)
    if (watermark > SPI_HOST_PARAM_TX_DEPTH) return SPI_FLAG_WATERMARK_EXCEEDS;

    SPI_HW(spi)->CONTROL = bitfield_write(SPI_HW(spi)->CONTROL, 
                                          SPI_HOST_CONTROL_TX_WATERMARK_MASK, 
                                          SPI_HOST_CONTROL_TX_WATERMARK_OFFSET, 
                                          watermark);
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_set_rx_watermark(spi_host_t* spi, uint8_t watermark)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    // Check that watermark is not bigger than the fifo size (makes no sense otherwise)
    if (watermark > SPI_HOST_PARAM_RX_DEPTH) return SPI_FLAG_WATERMARK_EXCEEDS;

    SPI_HW(spi)->CONTROL = bitfield_write(SPI_HW(spi)->CONTROL, 
                                          SPI_HOST_CONTROL_RX_WATERMARK_MASK, 
                                          SPI_HOST_CONTROL_RX_WATERMARK_OFFSET, 
                                          watermark);
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_set_configopts(spi_host_t* spi, uint32_t csid, const uint32_t conf_reg)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    if (SPI_CSID_INVALID(csid)) return SPI_FLAG_CSID_INVALID;
    *SPI_CONFIGOPTS_ADDR(spi, csid) = conf_reg;
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_get_configopts(spi_host_t* spi, uint32_t csid, uint32_t* conf_reg)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    if (SPI_CSID_INVALID(csid)) return SPI_FLAG_CSID_INVALID;
    *conf_reg = *SPI_CONFIGOPTS_ADDR(spi, csid);
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_set_csid(spi_host_t* spi, uint32_t csid)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    if (SPI_CSID_INVALID(csid)) return SPI_FLAG_CSID_INVALID;

    SPI_HW(spi)->CSID = csid;
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_set_command(spi_host_t* spi, const uint32_t cmd_reg)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)

    spi_return_flags_e flags = SPI_FLAG_OK;
    spi_speed_e speed   = bitfield_read(cmd_reg, SPI_HOST_COMMAND_SPEED_MASK, 
                                        SPI_HOST_COMMAND_SPEED_OFFSET);
    spi_dir_e direction = bitfield_read(cmd_reg, SPI_HOST_COMMAND_DIRECTION_MASK, 
                                        SPI_HOST_COMMAND_DIRECTION_OFFSET);

    // Incompatible speed and direction produces an error
    if (!spi_validate_cmd(direction, speed))     flags |= SPI_FLAG_SPEED_INVALID;
    // Writing a command while not ready produces an error
    if (spi_get_ready(spi) != SPI_TRISTATE_TRUE) flags |= SPI_FLAG_NOT_READY;
    if (flags) return flags;

    SPI_HW(spi)->COMMAND = cmd_reg;
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_write_word(spi_host_t* spi, uint32_t wdata)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    // Check we're not overflowing
    if (spi_get_tx_queue_depth(spi) >= SPI_HOST_PARAM_TX_DEPTH) 
        return SPI_FLAG_TX_QUEUE_FULL;
    SPI_HW(spi)->TXDATA = wdata;
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_write_byte(spi_host_t* spi, uint8_t bdata)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    // Check we're not overflowing
    if (spi_get_tx_queue_depth(spi) >= SPI_HOST_PARAM_TX_DEPTH) 
        return SPI_FLAG_TX_QUEUE_FULL;
    SPI_HW(spi)->TXDATA = bdata;
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_read_word(spi_host_t* spi, uint32_t* dst)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    // Check we're not underflowing
    if (spi_get_rx_queue_depth(spi) == 0) return SPI_FLAG_RX_QUEUE_EMPTY;
    *dst = SPI_HW(spi)->RXDATA;
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_enable_evt_intr(spi_host_t* spi, bool enable)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    SPI_HW(spi)->INTR_ENABLE = bitfield_write(SPI_HW(spi)->INTR_ENABLE, BIT_MASK_1, 
                                              SPI_HOST_INTR_ENABLE_SPI_EVENT_BIT, 
                                              enable);
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_enable_error_intr(spi_host_t* spi, bool enable)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    SPI_HW(spi)->INTR_ENABLE = bitfield_write(SPI_HW(spi)->INTR_ENABLE, BIT_MASK_1, 
                                              SPI_HOST_INTR_STATE_ERROR_BIT, 
                                              enable);
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_output_enable(spi_host_t* spi, bool enable)
{
    SPI_NULL_CHECK(spi, SPI_FLAG_NULL_PTR)
    SPI_HW(spi)->CONTROL = bitfield_write(SPI_HW(spi)->CONTROL, BIT_MASK_1, 
                                          SPI_HOST_CONTROL_OUTPUT_EN_BIT, enable);
    return SPI_FLAG_OK;
}

// PLIC handles SPI Host 2 interrupts
void handler_irq_spi(uint32_t id)
{
    spi_error_e errors;
    // Get errors and check if error triggered the interrupt
    spi_get_errors(spi_host2, &errors);
    if (errors) {
        // Call either weak error handler in this module, or user implementation
        spi_intr_handler_error_host2(errors);
    }
    else {
        // If it wasn't an error it must have been an event
        spi_event_e events;
        // We need to acknowledge the event to avoid triggering in loop
        spi_acknowledge_event(spi_host2);
        spi_get_events(spi_host2, &events);
        // Call either weak event handler in this module, or user implementation
        spi_intr_handler_event_host2(events);
    }
}

// FIC SPI Host 1 interrupt handler
void fic_irq_spi(void)
{
    spi_error_e errors;
    // Get errors and check if error triggered the interrupt
    spi_get_errors(spi_host1, &errors);
    if (errors) {
        // Call either weak error handler in this module, or user implementation
        spi_intr_handler_error_host(errors);
    }
    else {
        // If it wasn't an error it must have been an event
        spi_event_e events;
        // We need to acknowledge the event to avoid triggering in loop
        spi_acknowledge_event(spi_host1);
        spi_get_events(spi_host1, &events);
        // Call either weak event handler in this module, or user implementation
        spi_intr_handler_event_host(events);
    }
}

// FIC SPI Flash interrupt handler
void fic_irq_spi_flash(void)
{
    spi_error_e errors;
    // Get errors and check if error triggered the interrupt
    spi_get_errors(spi_flash, &errors);
    if (errors) {
        // Call either weak error handler in this module, or user implementation
        spi_intr_handler_error_flash(errors);
    }
    else {
        // If it wasn't an error it must have been an event
        spi_event_e events;
        // We need to acknowledge the event to avoid triggering in loop
        spi_acknowledge_event(spi_flash);
        spi_get_events(spi_flash, &events);
        // Call either weak event handler in this module, or user implementation
        spi_intr_handler_event_flash(events);
    }
}

__attribute__((weak, optimize("O0"))) void spi_intr_handler_event_flash(spi_event_e events) {

}

__attribute__((weak, optimize("O0"))) void spi_intr_handler_error_flash(spi_error_e errors) {

}

__attribute__((weak, optimize("O0"))) void spi_intr_handler_event_host(spi_event_e events) {

}

__attribute__((weak, optimize("O0"))) void spi_intr_handler_error_host(spi_error_e errors) {

}

__attribute__((weak, optimize("O0"))) void spi_intr_handler_event_host2(spi_event_e events) {

}

__attribute__((weak, optimize("O0"))) void spi_intr_handler_error_host2(spi_error_e errors) {

}

/****************************************************************************/
/**                                                                        **/
/*                            LOCAL FUNCTIONS                               */
/**                                                                        **/
/****************************************************************************/

spi_return_flags_e spi_get_events(spi_host_t* spi, spi_event_e* events) {
    // This function is somewhat a little cheat. Since there is no hardware implementation
    // telling which event triggered the interrupt, we just read the status register and
    // map the statuses to their respective event. This allows to pass a pseudo-event
    // variable to the event handlers.
    volatile spi_status_t status = spi_get_status(spi);
    *events = SPI_EVENT_NONE;
    // Also, we do not need any NULL check since this function is made to be called
    // __ONLY__ from `handler_irq_spi`, `fic_irq_spi`, `fic_irq_spi_flash`.
    // Therefore we know that spi argument will not be NULL.
    *events = bitfield_write(*events, BIT_MASK_1, 
                             SPI_HOST_EVENT_ENABLE_RXFULL_BIT,  status.rxfull);
    *events = bitfield_write(*events, BIT_MASK_1, 
                             SPI_HOST_EVENT_ENABLE_TXEMPTY_BIT, status.txempty);
    *events = bitfield_write(*events, BIT_MASK_1, 
                             SPI_HOST_EVENT_ENABLE_RXWM_BIT,    status.rxwm);
    *events = bitfield_write(*events, BIT_MASK_1, 
                             SPI_HOST_EVENT_ENABLE_TXWM_BIT,    status.txwm);
    *events = bitfield_write(*events, BIT_MASK_1, 
                             SPI_HOST_EVENT_ENABLE_READY_BIT,   status.ready);
    *events = bitfield_write(*events, BIT_MASK_1, 
                             SPI_HOST_EVENT_ENABLE_IDLE_BIT,   ~status.active);
    return SPI_FLAG_OK;
}

spi_return_flags_e spi_acknowledge_event(spi_host_t* spi) {
    // We do not need any NULL check since this function is made to be called
    // __ONLY__ from `handler_irq_spi`, `fic_irq_spi`, `fic_irq_spi_flash`.
    // Therefore we know that spi argument will not be NULL.
    SPI_HW(spi)->INTR_STATE = bitfield_write(SPI_HW(spi)->INTR_STATE, BIT_MASK_1, 
                                             SPI_HOST_INTR_STATE_SPI_EVENT_BIT, true);
    return SPI_FLAG_OK;
}
#ifdef __cplusplus
}
#endif
/****************************************************************************/
/**                                                                        **/
/*                                 EOF                                      */
/**                                                                        **/
/****************************************************************************/