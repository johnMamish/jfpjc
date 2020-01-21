#include <stdint.h>
#include <stdbool.h>

#include "am_mcu_apollo.h"
#include "am_bsp.h"
#include "am_bsp_pins.h"

const am_hal_gpio_pincfg_t g_AM_BSP_GPIO_LED_RED =
{
    //.uFuncSel            = AM_HAL_PIN_46_GPIO,
    .uFuncSel            = 3,
    .eDriveStrength      = AM_HAL_GPIO_PIN_DRIVESTRENGTH_12MA
};


int main(void)
{
    //am_util_id_t sIdDevice;
    uint32_t ui32StrBuf;

    //
    // Set the clock frequency.
    //
    am_hal_clkgen_control(AM_HAL_CLKGEN_CONTROL_SYSCLK_MAX, 0);


    //
    // Set the default cache configuration
    //
    am_hal_cachectrl_config(&am_hal_cachectrl_defaults);
    am_hal_cachectrl_enable();

    //
    // Configure the board for low power operation.
    //
    am_bsp_low_power_init();

    //am_hal_gpio_pinconfig(AM_BSP_GPIO_COM_UART_TX, g_AM_BSP_GPIO_COM_UART_TX);
    //am_hal_gpio_pinconfig(AM_BSP_GPIO_COM_UART_RX, g_AM_BSP_GPIO_COM_UART_RX);
    am_hal_gpio_pinconfig(46, g_AM_BSP_GPIO_LED_RED);

    int result = am_hal_gpio_state_write(46, AM_HAL_GPIO_OUTPUT_SET);
    while(1);
    while(1)
    {
        for (volatile int i = 0; i < 10000000; i++);
        am_hal_gpio_state_write(46, AM_HAL_GPIO_OUTPUT_SET);
        for (volatile int i = 0; i < 10000000; i++);
        am_hal_gpio_state_write(46, AM_HAL_GPIO_OUTPUT_CLEAR);
    }
}
