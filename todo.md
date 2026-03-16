read_single:
Send read command at standard speed
Send length of data to read
Read back the requested data at standard speed with watermark



read_quad:
Send quad read command at standard speed
uint32_t cmd_read_quadIO = FC_RDQIO;

uint32_t read_byte_cmd = (REVERT_24b_ADDR(addr) | (0xFF << 24));
spi_write_word(spi, read_byte_cmd);

send dummy cycles

Read back the requested data at quad speed

loop for reading data
    set_rx_watermark
    wait_for_rx_watermark


    spi_read_word


read_dma:
Setup DMA
Validate and launch DMA transfer
Send SPI address
Send SPI length
Wait for DMA transfer to complete
memcpy last bytes if needed


read_quad_dma:
send quad read command at standard speed
send address
send dummy cycles
send length
setup DMA
validate and launch DMA transfer (this is the exaclty the same as standard speed DMA)
wait for DMA transfer to complete
memcpy last bytes if needed