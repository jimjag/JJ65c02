add_executable(vga_core_lib)

# must match with pio filename and executable name from above
pico_generate_pio_header(vga_core_lib ${CMAKE_CURRENT_LIST_DIR}/hsync.pio)
pico_generate_pio_header(vga_core_lib ${CMAKE_CURRENT_LIST_DIR}/vsync.pio)
pico_generate_pio_header(vga_core_lib ${CMAKE_CURRENT_LIST_DIR}/scanline.pio)

# must match with executable name and source file names
target_sources(vga_core_lib PRIVATE
    vga_core_demo.c
    vga_core.c)

# must match with executable name
target_link_libraries(vga_core_lib PRIVATE
    pico_stdlib
    hardware_pio
    hardware_dma
    hardware_adc
    hardware_irq)

# must match with executable name
pico_add_extra_outputs(vga_core_lib)
