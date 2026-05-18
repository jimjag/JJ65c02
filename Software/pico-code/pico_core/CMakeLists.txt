add_executable(pico_core_code)

# must match with pio filename and executable name from above
pico_generate_pio_header(pico_core_code ${CMAKE_CURRENT_LIST_DIR}/hsync.pio)
pico_generate_pio_header(pico_core_code ${CMAKE_CURRENT_LIST_DIR}/vsync.pio)
pico_generate_pio_header(pico_core_code ${CMAKE_CURRENT_LIST_DIR}/scanline.pio)
pico_generate_pio_header(pico_core_code ${CMAKE_CURRENT_LIST_DIR}/ps2_keyboard.pio)
pico_generate_pio_header(pico_core_code ${CMAKE_CURRENT_LIST_DIR}/memin.pio)
#pico_generate_pio_header(pico_core_code ${CMAKE_CURRENT_LIST_DIR}/clk.pio)

# must match with executable name and source file names
if(DEFINED ENV{PICO_DEMO})
    target_sources (
        pico_core_code PRIVATE
        pico_core_demo.c
        vga_core.c
        ps2_keyboard.c
        pico_synth_ex.c
    )

elseif(DEFINED ENV{SPRITE_DEMO})
    target_sources (
        pico_core_code PRIVATE
        pico_core_demo-sprite.c
        vga_core.c
        ps2_keyboard.c
        pico_synth_ex.c
    )

else()
    target_sources (
        pico_core_code PRIVATE
        pico_6502.c
        vga_core.c
        ps2_keyboard.c
        pico_synth_ex.c
    )
endif()

# must match with executable name
target_link_libraries (
    pico_core_code PRIVATE
    pico_stdlib
    hardware_pio
    hardware_dma
    hardware_pwm
    hardware_adc
    pico_multicore
    hardware_irq
)

# On RP2350 use the custom linker script that places the two VGA frame buffers
# in bank-isolated SRAM regions to prevent pixel-DMA / utility-DMA contention.
# Note: the bare "rp2350" value is normalised to "rp2350-arm-s" by the SDK's
# pico_pre_load_platform.cmake before this if() is evaluated, so it is not
# listed here. All three concrete RP2350 variants are covered.
if(PICO_PLATFORM STREQUAL "rp2350-arm-s" OR
   PICO_PLATFORM STREQUAL "rp2350-arm-ns" OR
   PICO_PLATFORM STREQUAL "rp2350-riscv")
    pico_set_linker_script(pico_core_code ${CMAKE_CURRENT_LIST_DIR}/memmap_vga_rp2350.ld)
endif()

if(DEFINED ENV{PICO_DEMO})
    pico_enable_stdio_usb(pico_core_code 1)
    pico_enable_stdio_uart(pico_core_code 0)
endif()
# must match with executable name
pico_add_extra_outputs(pico_core_code)
