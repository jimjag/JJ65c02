add_executable(pico_core_code)

# must match with pio filename and executable name from above
pico_generate_pio_header(pico_core_code ${CMAKE_CURRENT_LIST_DIR}/hsync.pio)
pico_generate_pio_header(pico_core_code ${CMAKE_CURRENT_LIST_DIR}/vsync.pio)
pico_generate_pio_header(pico_core_code ${CMAKE_CURRENT_LIST_DIR}/scanline.pio)
pico_generate_pio_header(pico_core_code ${CMAKE_CURRENT_LIST_DIR}/ps2_keyboard.pio)
pico_generate_pio_header(pico_core_code ${CMAKE_CURRENT_LIST_DIR}/memin.pio)

# must match with executable name and source file names
if(DEFINED ENV{PICO_DEMO})
    target_sources(pico_core_code PRIVATE
        pico_core_demo.c
        vga_core.c
        ps2_keyboard.c)
elseif(DEFINED ENV{SPRITE_DEMO})
    target_sources(pico_core_code PRIVATE
            pico_core_demo-sprite.c
            vga_core.c
            ps2_keyboard.c)
else()
    target_sources(pico_core_code PRIVATE
        pico_6502.c
        vga_core.c
        ps2_keyboard.c)
endif()
# must match with executable name
target_link_libraries(pico_core_code PRIVATE
    pico_stdlib
    hardware_pio
    hardware_dma
    hardware_adc
    hardware_irq)

# must match with executable name
pico_add_extra_outputs(pico_core_code)
