#include <stdint.h>
#include <stdlib.h>

#include "x-heep.h"
#include "spi_host.h"
#include "spi_slave_sdk.h"


/*
Connections to test on the pynq-z2 FPGA:
_____________________________________________________
                          11                         |
  ...[  ][  ][  ][  ][  ](Ck)[  ][  ][  ][  ][  ] 1  |    }
  ...[  ][  ][  ][  ][  ][  ][  ](Cs)[  ][  ][  ] 2  |    }
                                   8             ____|_   }-- Slave
             ... AR3 AR2 AR1 AR0                 |    |   }
 [  ][  ][  ][  ](Mo)(Mi)[  ][  ] J4             |HDMI|   }
                                                 |____|
                               SPI               ____|_
                         {   (Mi)[  ]            |    |
                Master --{   (Ck)(Mo)            |PMOD|
                         {   (Cs)[  ]            |  A |
                                                 |____|
                                                     |
*/


/* By default, printfs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA 1
#define PRINTF_IN_SIM 0

#if TARGET_SIM && PRINTF_IN_SIM
#define PRINTF(fmt, ...) printf(fmt, ##__VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
#define PRINTF(fmt, ...) printf(fmt, ##__VA_ARGS__)
#else
#define PRINTF(...)
#endif

#define DUMMY_CYCLES  32

#define DATA_LENGTH_B   100
#define DATA_CHUNK_W    1
#define DATA_CHUNK_B    1
#define CHUNKS_NW       (DATA_LENGTH_B/(DATA_CHUNK_W*4)) + ((DATA_LENGTH_B%(DATA_CHUNK_W*4))!=0)
#define CHUNKS_NB       (DATA_LENGTH_B/DATA_CHUNK_B)

// Buffer from where the SPI host will take data to write through the SPI slave
uint8_t buffer_write_from[DATA_LENGTH_B] = {
      1,   2,   3,   4,   5,   6,   7,   8,   9,  10,  11,  12,  13,  14,  15,  16,  17,  18,  19,  20,
     21,  22,  23,  24,  25,  26,  27,  28,  29,  30,  31,  32,  33,  34,  35,  36,  37,  38,  39,  40,
     41,  42,  43,  44,  45,  46,  47,  48,  49,  50,  51,  52,  53,  54,  55,  56,  57,  58,  59,  60,
     61,  62,  63,  64,  65,  66,  67,  68,  69,  70,  71,  72,  73,  74,  75,  76,  77,  78,  79,  80,
     81,  82,  83,  84,  85,  86,  87,  88,  89,  90,  91,  92,  93,  94,  95,  96,  97,  98,  99, 100
};

// Buffer where the SPI slave will write data to.
uint8_t buffer_write_to [DATA_LENGTH_B];

// Buffer from where we will ask the SPI slave to read from. 
uint8_t buffer_read_from[DATA_LENGTH_B] = {
    101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120,
    121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140,
    141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160,
    161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180,
    181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200
};

// Buffer where we will copy the data read by the SPI host. 
uint8_t buffer_read_to  [DATA_LENGTH_B];

int main(){
    uint16_t i;

    // Initialize the SPI host. 
    if( spi_host_init(spi_host1, 0)!= SPI_FLAG_SUCCESS) return EXIT_FAILURE;

    // Use the SPI Host SDK to write into the SPI slave.
    // In the SPI Slave SDK there are the needed SPI HOST functions to control the SPI Slave. 
    // The SPI slave per se cannot be controlled from X-HEEP's SW. 
    spi_slave_write(spi_host1, buffer_write_to, buffer_write_from, DATA_LENGTH_B);

    // Check that the written values match the source ones. 
    // Also increment those values +1 to use as new data.
    for(int i=0; i < DATA_LENGTH_B; i++){
        if(buffer_write_from[i] != buffer_write_to[i]) return EXIT_FAILURE;
    }
    PRINTF("Write Ok\n\r");

    // Use the SPI Host SDK to request the SPI slave to read from memory and return the values. 
    // This can be done in different ways:

    // Reading byte per byte (bpb, B/B). We ask the SPI slave to read one single byte. 
    // The SPI slave will read one full word, and then n the SDK this is masked to 
    // return only the desired byte. 
    // When reading from the SPI Host buffer (spi_copy_byte) we need to specify the position 
    // of that byte inside the word. Because here we know the address, it's simply the remainder
    // of the address with 4.
    // We repeat this for N bytes. 
    uint8_t bpb_length_b = 10;
    for( i=0; i<bpb_length_b; i++){
        spi_slave_request_read(spi_host1,&buffer_read_from[i],  1, DUMMY_CYCLES );
        spi_wait_for_rx_watermark(spi_host1);
        buffer_read_to[i] = spi_copy_byte(spi_host1, i%4 );
    }
    // Check if the read values are ok. 
    for(int i=0; i < bpb_length_b; i++){
        if(buffer_read_from[i] != buffer_read_to[i]) return EXIT_FAILURE;
    }
    PRINTF("B/B Ok\n\r");

    // Reading word per word (wpw, W/W). We ask the SPI to copy full words. For the SPI slave
    // it's the same as copying byte per byte, as the SPI host will always require it to send full
    // words. 
    // We receive the 32-bit word, no masking needed. 
    // We start from the last full word read. This will overlap with the read bpb if the length was not 
    // a multiple of 4, but that should not affect the result. 
    uint8_t wpw_length_w = 10;
    uint8_t start_w = bpb_length_b/4;
    for( i=0; i<wpw_length_w; i++){
        spi_slave_request_read(spi_host1,(uint8_t*)(&((uint32_t*)buffer_read_from)[start_w + i]),  4, DUMMY_CYCLES );
        spi_wait_for_rx_watermark(spi_host1);
        ((uint32_t*)buffer_read_to)[ start_w + i ] = spi_copy_word(spi_host1);
    }
    // Check if the read values are ok.
    for(int i=start_w; i < start_w+wpw_length_w*4; i++){
        if(buffer_read_from[i] != buffer_read_to[i]) return EXIT_FAILURE;
    }
    PRINTF("W/W Ok\n\r");

    // Reading in chunks of word (C/C). We ask for several words at a time, let them buffer in the 
    // SPI host FIFO and then copy them to memory. 
    // We do this in N chunks of M words each. 
    // This time we pass a pointer where to store the read values. 
    uint8_t chunk_w     = 4;
    uint8_t chunks_n    = 3;
    start_w               += wpw_length_w;
    for( i=0; i<chunks_n; i++){
        spi_slave_request_read(spi_host1,(uint8_t*)(&((uint32_t*)buffer_read_from)[start_w + i*chunk_w]),  chunk_w*4, DUMMY_CYCLES );
        spi_wait_for_rx_watermark(spi_host1);
        spi_copy_words( spi_host1, &((uint32_t*)buffer_read_to)[start_w + i*chunk_w],  chunk_w );
    }
    // Check if the read values are ok.
    for( i=start_w*4; i < start_w*4 + chunks_n*chunk_w*4; i++){
        if(buffer_read_from[i] != buffer_read_to[i]) return EXIT_FAILURE;
    }
    PRINTF("C/C Ok\n\r");

    return EXIT_SUCCESS;
}





