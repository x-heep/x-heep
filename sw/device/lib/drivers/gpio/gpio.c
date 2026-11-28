/*
                              *******************
******************************* C SOURCE FILE *****************************
**                            *******************
**
** project  : X-HEEP
** filename : gpio.c
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
* @file     gpio.c
* @date     30/03/2023
* @author   Hossein taji
* @version  1
* @brief    GPIO driver
*/
#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus
/****************************************************************************/
/**                                                                        **/
/*                             MODULES USED                                 */
/**                                                                        **/
/****************************************************************************/

#include "gpio.h"
#include "gpio_regs.h"  // Generated.
#include "gpio_structs.h"
#include "core_v_mini_mcu.h"
#include "bitfield.h"
#include "x-heep.h"

/****************************************************************************/
/**                                                                        **/
/*                        DEFINITIONS AND MACROS                            */
/**                                                                        **/
/****************************************************************************/

/**
 * GPIO_AO pointer
 */
#define gpio_ao_peri ((volatile gpio *) GPIO_AO_START_ADDRESS)


/**
 * GPIO_EN values
 */
#define GPIO_EN__ENABLED     1
#define GPIO_EN__DISABLED    0

/**
 * GPIO_CLEAR and GPIO_SET mask bit: each bit written as one acts on its pin
 */
#define GPIO_PUT_MASK 0x01

/**
 * GPIO is set or reset. The value read from gpio_perif->GPIO_IN0 or
 * write to gpio_perif->GPIO_OUT0
 */
#define GPIO_IS_SET     1
#define GPIO_IS_RESET   0

/**
 * To enable and disable intr by wrting to INTR_EN registers
 */
#define GPIO_INTR_ENABLE    1
#define GPIO_INTR_DISABLE   0

/**
 * Values read after checking intr status registers to see they are
 * triggered or not
 */
#define GPIO_INTR_IS_TRIGGERED      1
#define GPIO_INTR_IS_NOT_TRIGGERED  0

/**
 * Clearing the status bit by writing one into int
 */
#define GPIO_INTR_CLEAR     1

/**
 * GPIO intr mode configration index inside GPIO_CFG register.
 */
#define GPIO_CFG_INTR_MODE_INDEX    0

/**
 * GPIO mode, number of pins it includes
 */
#define GPIO_MODE_NUM_PINS      16

/**
 * The first interrupt ID for the GPIOS
 */
#define GPIO_INTR_START GPIO_INTR_8

/**
 * The last interrupt ID for the GPIOS
 */
#define GPIO_INTR_END GPIO_INTR_31

/**
 * The number of GPIO interrupt IDs
 */
#define GPIO_INTR_QTY ( GPIO_INTR_END - GPIO_INTR_START + 1 )

/**
 * Array of handlers for the different GPIO interrupts.
 */
void (*gpio_handlers[ GPIO_INTR_QTY ])( void );


/****************************************************************************/
/**                                                                        **/
/*                      PROTOTYPES OF LOCAL FUNCTIONS                       */
/**                                                                        **/
/****************************************************************************/

/**
 * A dummy function to prevent unassigned irq to access a null pointer.
 */

__attribute__((optimize("O0"))) static void gpio_handler_irq_dummy(void);

/**
 * Return the bank of a pin. Each function keeps its own pointer, so an
 * interrupt callback that calls a GPIO function cannot redirect the caller.
 */
static inline volatile gpio *gpio_domain_registers(gpio_pin_number_t pin);

/**
 * Check an interrupt type before any register is changed, so a rejected
 * request leaves the pin's configuration as it was.
 */
static bool gpio_intr_type_is_valid(gpio_intr_type_t type);

/****************************************************************************/
/**                                                                        **/
/*                           EXPORTED FUNCTIONS                             */
/**                                                                        **/
/****************************************************************************/

gpio_result_t gpio_assign_irq_handler( uint32_t intr_id,
                                       void (*handler)() )
{
  if( intr_id >= GPIO_INTR_START && intr_id <= GPIO_INTR_END )
  {
    gpio_handlers[ intr_id - GPIO_INTR_START ] = (void (*)(void))handler;
    return GpioOk;
  }
  return GpioError;
}

void gpio_reset_handlers_list( )
{
    for( uint8_t i = 0; i < GPIO_INTR_QTY; i++ )
    {
        gpio_handlers[ i ] = gpio_handler_irq_dummy;
    }
}

void handler_irq_gpio( uint32_t id )
{
    gpio_handlers[ id - GPIO_INTR_START ]();
}

gpio_result_t gpio_config (gpio_cfg_t cfg)
{
    /* check that pin is in acceptable range. */
    if (cfg.pin > (MAX_PIN-1) || cfg.pin < 0)
        return GpioPinNotAcceptable;
    /* check mode and interrupt type before the reset, so a rejected request
     * leaves the pin unchanged. */
    if ((cfg.mode < GpioModeIn) || (cfg.mode > GpioModeoutOpenDrain1))
        return GpioModeNotAcceptable;
    if (cfg.en_intr == true && !gpio_intr_type_is_valid(cfg.intr_type))
        return GpioIntrTypeNotAcceptable;
    /* reset the pin configuration before the new one is set. */
    gpio_reset (cfg.pin);
    /* set mode. */
    gpio_set_mode (cfg.pin, cfg.mode);
    /* if input sampling is enabled */
    if (cfg.en_input_sampling == true)
        gpio_en_input_sampling (cfg.pin);
    /* if interrupt is enabled. Also after enabling check for error */
    if (cfg.en_intr == true)
        if (gpio_intr_en (cfg.pin, cfg.intr_type) != GpioOk)
            return GpioIntrTypeNotAcceptable;
    return GpioOk;
}

gpio_result_t gpio_set_mode (gpio_pin_number_t pin, gpio_mode_t mode)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    if ((mode < GpioModeIn) || (mode > GpioModeoutOpenDrain1))
        return GpioModeNotAcceptable;

    volatile gpio *gpio_perif = gpio_domain_registers(pin);

    if (pin >= 0 && pin < 1*GPIO_MODE_NUM_PINS)
        gpio_perif->GPIO_MODE0 = bitfield_write(gpio_perif->GPIO_MODE0,
                                               BIT_MASK_3, 2*pin, mode);
    else
        gpio_perif->GPIO_MODE1 = bitfield_write(gpio_perif->GPIO_MODE1,
                                               BIT_MASK_3, 2*(pin-GPIO_MODE_NUM_PINS), mode);
    return GpioOk;
}

gpio_result_t gpio_en_input_sampling (gpio_pin_number_t pin)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    gpio_perif->GPIO_EN0 = bitfield_write(gpio_perif->GPIO_EN0,
                                         BIT_MASK_1, pin, GPIO_EN__ENABLED);
    return GpioOk;
}

gpio_result_t gpio_dis_input_sampling (gpio_pin_number_t pin)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    gpio_perif->GPIO_EN0 = bitfield_write(gpio_perif->GPIO_EN0,
                                         BIT_MASK_1, pin, GPIO_EN__DISABLED);
    return GpioOk;
}

gpio_result_t gpio_reset (gpio_pin_number_t pin)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;

    gpio_intr_set_mode (pin, 0);
    gpio_set_mode (pin, GpioModeIn);
    gpio_dis_input_sampling (pin);
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    /* GPIO_CLEAR0 acts only on the bits written as one, so this clears the
     * output latch of this pin and keeps the other outputs of the bank. */
    gpio_perif->GPIO_CLEAR0 = (uint32_t)GPIO_PUT_MASK << pin;
    gpio_intr_dis_all(pin);
    gpio_intr_clear_stat(pin);
    return GpioOk;
}

gpio_result_t gpio_reset_all (void)
{

    /* first reset the GPIO in the AO domain by setting the GPIO pin to 0 */
    volatile gpio *gpio_perif = gpio_domain_registers(0);
    gpio_perif->GPIO_MODE0 = 0;
    gpio_perif->GPIO_MODE1 = 0;
    gpio_perif->GPIO_EN0 = 0;
    gpio_perif->GPIO_OUT0 = 0;
    gpio_perif->CFG = 0;
    gpio_perif->INTRPT_RISE_EN0 = 0;
    gpio_perif->INTRPT_FALL_EN0 = 0;
    gpio_perif->INTRPT_LVL_HIGH_EN0 = 0;
    gpio_perif->INTRPT_LVL_LOW_EN0 = 0;
    gpio_perif->INTRPT_STATUS0 = 0xFFFFFFFF;
    /* then reset the GPIO in the peripheral domain by setting the GPIO pin to GPIO_AO_DOMAIN_LIMIT */
    gpio_perif = gpio_domain_registers(GPIO_AO_DOMAIN_LIMIT);
    gpio_perif->GPIO_MODE0 = 0;
    gpio_perif->GPIO_MODE1 = 0;
    gpio_perif->GPIO_EN0 = 0;
    gpio_perif->GPIO_OUT0 = 0;
    gpio_perif->CFG = 0;
    gpio_perif->INTRPT_RISE_EN0 = 0;
    gpio_perif->INTRPT_FALL_EN0 = 0;
    gpio_perif->INTRPT_LVL_HIGH_EN0 = 0;
    gpio_perif->INTRPT_LVL_LOW_EN0 = 0;
    gpio_perif->INTRPT_STATUS0 = 0xFFFFFFFF;

    gpio_reset_handlers_list( );
    return GpioOk;
}

gpio_result_t gpio_read (gpio_pin_number_t pin, bool *val)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    *val = bitfield_read(gpio_perif->GPIO_IN0, BIT_MASK_1, pin);
    return GpioOk;
}

gpio_result_t gpio_toggle (gpio_pin_number_t pin)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    gpio_perif->GPIO_OUT0 = bitfield_write(gpio_perif->GPIO_OUT0, BIT_MASK_1,
        pin, !(bitfield_read(gpio_perif->GPIO_OUT0, BIT_MASK_1, pin)));
    return GpioOk;
}

gpio_result_t gpio_write (gpio_pin_number_t pin, bool val)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    gpio_perif->GPIO_OUT0 = bitfield_write(gpio_perif->GPIO_OUT0,
        BIT_MASK_1, pin, val);
    return GpioOk;

}

gpio_result_t gpio_intr_en_rise (gpio_pin_number_t pin)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    gpio_perif->INTRPT_RISE_EN0 =  bitfield_write(
        gpio_perif->INTRPT_RISE_EN0, BIT_MASK_1, pin, GPIO_INTR_ENABLE);
    return GpioOk;
}

gpio_result_t gpio_intr_en_fall (gpio_pin_number_t pin)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    gpio_perif->INTRPT_FALL_EN0 =  bitfield_write(gpio_perif->INTRPT_FALL_EN0,
        BIT_MASK_1, pin, GPIO_INTR_ENABLE);
    return GpioOk;
}

gpio_result_t gpio_intr_en_lvl_high (gpio_pin_number_t pin)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    gpio_perif->INTRPT_LVL_HIGH_EN0 =  bitfield_write(
        gpio_perif->INTRPT_LVL_HIGH_EN0, BIT_MASK_1, pin, GPIO_INTR_ENABLE);
    return GpioOk;
}

gpio_result_t gpio_intr_en_lvl_low (gpio_pin_number_t pin)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    gpio_perif->INTRPT_LVL_LOW_EN0 =  bitfield_write(
        gpio_perif->INTRPT_LVL_LOW_EN0, BIT_MASK_1, pin, GPIO_INTR_ENABLE);
    return GpioOk;
}

gpio_result_t gpio_intr_dis_rise (gpio_pin_number_t pin)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    gpio_perif->INTRPT_RISE_EN0 =  bitfield_write(
        gpio_perif->INTRPT_RISE_EN0, BIT_MASK_1, pin, GPIO_INTR_DISABLE);
    return GpioOk;
}

gpio_result_t gpio_intr_dis_fall (gpio_pin_number_t pin)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    gpio_perif->INTRPT_FALL_EN0 =  bitfield_write(
        gpio_perif->INTRPT_FALL_EN0, BIT_MASK_1, pin, GPIO_INTR_DISABLE);
    return GpioOk;
}

gpio_result_t gpio_intr_dis_lvl_high (gpio_pin_number_t pin)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    gpio_perif->INTRPT_LVL_HIGH_EN0 =  bitfield_write(
        gpio_perif->INTRPT_LVL_HIGH_EN0, BIT_MASK_1, pin, GPIO_INTR_DISABLE);
    return GpioOk;
}

gpio_result_t gpio_intr_dis_lvl_low (gpio_pin_number_t pin)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    gpio_perif->INTRPT_LVL_LOW_EN0 =  bitfield_write(
        gpio_perif->INTRPT_LVL_LOW_EN0, BIT_MASK_1, pin, GPIO_INTR_DISABLE);
    return GpioOk;
}

gpio_result_t gpio_intr_dis_all (gpio_pin_number_t pin){
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    gpio_perif->INTRPT_RISE_EN0 =  bitfield_write(
        gpio_perif->INTRPT_RISE_EN0, BIT_MASK_1, pin, GPIO_INTR_DISABLE);
    gpio_perif->INTRPT_FALL_EN0 =  bitfield_write(
        gpio_perif->INTRPT_FALL_EN0, BIT_MASK_1, pin, GPIO_INTR_DISABLE);
    gpio_perif->INTRPT_LVL_HIGH_EN0 =  bitfield_write(
        gpio_perif->INTRPT_LVL_HIGH_EN0, BIT_MASK_1, pin, GPIO_INTR_DISABLE);
    gpio_perif->INTRPT_LVL_LOW_EN0 =  bitfield_write(
        gpio_perif->INTRPT_LVL_LOW_EN0, BIT_MASK_1, pin, GPIO_INTR_DISABLE);
    return GpioOk;
}

gpio_result_t gpio_intr_en (gpio_pin_number_t pin, gpio_intr_type_t type)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    if (!gpio_intr_type_is_valid(type))
        return GpioIntrTypeNotAcceptable;
    gpio_intr_dis_all(pin);
    switch(type)
    {
    case GpioIntrEdgeRising:
        gpio_intr_en_rise(pin);
        break;
    case GpioIntrEdgeFalling:
        gpio_intr_en_fall(pin);
        break;
    case GpioIntrLevelLow:
        gpio_intr_en_lvl_low(pin);
        break;
    case GpioIntrLevelHigh:
        gpio_intr_en_lvl_high(pin);
        break;
    case GpioIntrEdgeRisingFalling:
        gpio_intr_en_rise(pin);
        gpio_intr_en_fall(pin);
        break;
    case GpioIntrEdgeRisingLevelLow:
        gpio_intr_en_rise(pin);
        gpio_intr_en_lvl_low(pin);
        break;
    case GpioIntrEdgeFallingLevelHigh:
        gpio_intr_en_fall(pin);
        gpio_intr_en_lvl_high(pin);
        break;
    default:
        return GpioIntrTypeNotAcceptable;
    }
    return GpioOk;
}

gpio_result_t gpio_intr_check_stat_rise (gpio_pin_number_t pin, bool *is_pending)
{
    if (pin > (MAX_PIN-1) || pin < 0)
    {
        *is_pending = GPIO_INTR_IS_NOT_TRIGGERED;
        return GpioPinNotAcceptable;
    }
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    *is_pending = bitfield_read(gpio_perif->INTRPT_RISE_STATUS0, BIT_MASK_1, pin);
    return GpioOk;
}

gpio_result_t gpio_intr_check_stat_fall (gpio_pin_number_t pin, bool *is_pending)
{
    if (pin > (MAX_PIN-1) || pin < 0)
    {
        *is_pending = GPIO_INTR_IS_NOT_TRIGGERED;
        return GpioPinNotAcceptable;
    }
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    *is_pending = bitfield_read(gpio_perif->INTRPT_FALL_STATUS0, BIT_MASK_1, pin);
    return GpioOk;
}

gpio_result_t gpio_intr_check_stat_lvl_low (gpio_pin_number_t pin, bool *is_pending)
{
    if (pin > (MAX_PIN-1) || pin < 0)
    {
        *is_pending = GPIO_INTR_IS_NOT_TRIGGERED;
        return GpioPinNotAcceptable;
    }
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    *is_pending = bitfield_read(gpio_perif->INTRPT_LVL_LOW_STATUS0, BIT_MASK_1, pin);
    return GpioOk;
}

gpio_result_t gpio_intr_check_stat_lvl_high (gpio_pin_number_t pin, bool *is_pending)
{
    if (pin > (MAX_PIN-1) || pin < 0)
    {
        *is_pending = GPIO_INTR_IS_NOT_TRIGGERED;
        return GpioPinNotAcceptable;
    }
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
     *is_pending = bitfield_read(gpio_perif->INTRPT_LVL_HIGH_STATUS0, BIT_MASK_1, pin);
    return GpioOk;
}

gpio_result_t gpio_intr_check_stat (gpio_pin_number_t pin, bool *is_pending)
{
    if (pin > (MAX_PIN-1) || pin < 0)
    {
        *is_pending = GPIO_INTR_IS_NOT_TRIGGERED;
        return GpioPinNotAcceptable;
    }
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    *is_pending = bitfield_read(gpio_perif->INTRPT_STATUS0, BIT_MASK_1, pin);
    return GpioOk;
}

gpio_result_t gpio_intr_clear_stat_rise (gpio_pin_number_t pin)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    /* The status registers are write-one-to-clear: a read-modify-write would
     * also acknowledge the other pending pins of the bank. */
    gpio_perif->INTRPT_RISE_STATUS0 = (uint32_t)GPIO_INTR_CLEAR << pin;
    return GpioOk;

}

gpio_result_t gpio_intr_clear_stat_fall (gpio_pin_number_t pin)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    gpio_perif->INTRPT_FALL_STATUS0 = (uint32_t)GPIO_INTR_CLEAR << pin;
    return GpioOk;
}

gpio_result_t gpio_intr_clear_stat_lvl_low (gpio_pin_number_t pin)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    gpio_perif->INTRPT_LVL_LOW_STATUS0 = (uint32_t)GPIO_INTR_CLEAR << pin;
    return GpioOk;
}

gpio_result_t gpio_intr_clear_stat_lvl_high (gpio_pin_number_t pin)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    gpio_perif->INTRPT_LVL_HIGH_STATUS0 = (uint32_t)GPIO_INTR_CLEAR << pin;
    return GpioOk;
}

gpio_result_t gpio_intr_clear_stat (gpio_pin_number_t pin)
{
    if (pin > (MAX_PIN-1) || pin < 0)
        return GpioPinNotAcceptable;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    gpio_perif->INTRPT_STATUS0 = (uint32_t)GPIO_INTR_CLEAR << pin;
    return GpioOk;
}

void gpio_intr_set_mode (gpio_pin_number_t pin, gpio_intr_general_mode_t mode)
{
    if (pin > (MAX_PIN-1) || pin < 0 || (mode != IntrOnePulse && mode != IntrAsserted))
        return;
    volatile gpio *gpio_perif = gpio_domain_registers(pin);
    gpio_perif->CFG = bitfield_write(
        gpio_perif->CFG, BIT_MASK_1, GPIO_CFG_INTR_MODE_INDEX, mode);
}

/****************************************************************************/
/**                                                                        **/
/*                            LOCAL FUNCTIONS                               */
/**                                                                        **/
/****************************************************************************/

__attribute__((optimize("O0"))) static void gpio_handler_irq_dummy(void)
{
  return;
}

static inline volatile gpio *gpio_domain_registers(gpio_pin_number_t pin)
{
    return pin < GPIO_AO_DOMAIN_LIMIT ? gpio_ao_peri : gpio_peri;
}

static bool gpio_intr_type_is_valid(gpio_intr_type_t type)
{
    /* Valid types run from 0 to GpioIntrEdgeFallingLevelHigh without gaps. */
    return (uint32_t)type <= (uint32_t)GpioIntrEdgeFallingLevelHigh;
}

/****************************************************************************/
/**                                                                        **/
/*                                 EOF                                      */
/**                                                                        **/
/****************************************************************************/


#ifdef __cplusplus
}
#endif  // __cplusplus