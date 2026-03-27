// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

<%
  dma = xheep.get_base_peripheral_domain().get_dma()
  dma_addr_mode = dma.get_addr_mode() == 1
  dma_subaddr_mode = dma.get_subaddr_mode() == 1
  dma_hw_fifo_mode = dma.get_hw_fifo_mode() == 1
  dma_zero_padding = dma.get_zero_padding() == 1
%>

{ name: "dma"
  clock_primary: "clk_i"
  bus_interfaces: [
    { protocol: "reg_iface", direction: "device" }
  ]
  regwidth: "32"
  registers: [
    { name:     "SRC_PTR"
      desc:     "Input data pointer (word aligned)"
      swaccess: "rw"
      hwaccess: "hrw"
      fields: [
        { bits: "31:0", name: "PTR_IN", desc: "Input data pointer (word aligned)" }
      ]
    }
    { name:     "DST_PTR"
      desc:     "Output data pointer (word aligned)"
      swaccess: "rw"
      hwaccess: "hrw"
      fields: [
        { bits: "31:0", name: "PTR_OUT", desc: "Output data pointer (word aligned)" }
      ]
    }
    % if dma_addr_mode:
    { name:     "ADDR_PTR"
      desc:     "Addess data pointer (word aligned)"
      swaccess: "rw"
      hwaccess: "hrw"
      fields: [
        { bits: "31:0", name: "PTR_ADDR", desc: "Address data pointer (word aligned) - used only in Address mode" }
      ]
    }
    % endif
    { name:     "SIZE_D1"
      desc:     "Number of elements to copy from, defined with respect to the first dimension - Once a value is written, the copy starts"
      swaccess: "rw"
      hwaccess: "hrw"
      hwqe:     "true" // enable `qe` latched signal of software write pulse
      // Dimensioned to 16 bits to allow for 64kB transfers on 1D
      fields: [
        { bits: "15:0", name: "SIZE", desc: "DMA counter D1 and start" }
      ]
    }
    { name:     "SIZE_D2"
      desc:     "Number of elements to copy from, defined with respect to the second dimension"
      swaccess: "rw"
      hwaccess: "hrw"
      // Dimensioned to 16 bits to allow for 64kB transfers on 2D
      fields: [
        { bits: "15:0", name: "SIZE", desc: "DMA counter D2" }
      ]
    }
    { name:     "STATUS"
      desc:     '''Status bits are set to one if a given event occurred'''
      swaccess: "ro"
      hwaccess: "hrw"
      hwext: "true"
      hwre:     "true" // enable `re` latched signal of software read pulse
      resval:   1
      fields: [
        { bits: "0", name: "READY", desc: "Transaction is done"}
        { bits: "1", name: "WINDOW_DONE", desc: "set if DMA is copying second half"}
      ]
    }
    { name:     "SRC_PTR_INC_D1"
      desc:     "Increment the D1 source pointer every time a word is copied"
      swaccess: "rw"
      hwaccess: "hrw"
      // Dimensioned to allow a maximum of a 15 element stride for a data_type_word case
      fields: [
        { bits: "5:0"
          name: "INC"
          desc: "Source pointer d1 increment"
          resval:4
        }
      ]
    }
    { name:     "SRC_PTR_INC_D2"
      desc:     "Increment the D2 source pointer every time a word is copied"
      swaccess: "rw"
      hwaccess: "hrw"
      // Dimensioned to allow a maximum of 15 element stride for a data_type_word
      fields: [
        { bits: "22:0"
          name: "INC"
          desc: "Source pointer d2 increment"
          resval:4
        }
      ]
    }
    { name:     "DST_PTR_INC_D1"
      desc:     "Increment the D1 destination pointer every time a word is copied"
      swaccess: "rw"
      hwaccess: "hrw"
      fields: [
        { bits: "5:0"
          name: "INC"
          desc: "Destination pointer d1 increment"
          resval:4
        }
      ]
    }
    { name:     "DST_PTR_INC_D2"
      desc:     "Increment the D2 destination pointer every time a word is copied"
      swaccess: "rw"
      hwaccess: "hrw"
      fields: [
        { bits: "22:0"
          name: "INC"
          desc: "Destination pointer d2 increment"
          resval:4
        }
      ]
    }
    { name:     "SLOT"
      desc:     '''The DMA will wait for the signal 
                   connected to the selected trigger_slots to be high
                   on the read and write side respectively'''
      swaccess: "rw"
      hwaccess: "hrw"
      resval:   0
      fields: [
        { bits: "15:0", name: "RX_TRIGGER_SLOT"
          desc: "Slot selection mask"
        }
        { bits: "31:16", name: "TX_TRIGGER_SLOT"
          desc: "Slot selection mask"
        }
      ]
    }
    { name:     "SRC_DATA_TYPE"
      desc:     '''Width/type of the source data to transfer'''
      swaccess: "rw"
      hwaccess: "hrw"
      resval:   0
      fields: [
        { bits: "1:0", name: "DATA_TYPE"
          desc: "Data type"
          enum: [
            { value: "0", name: "DMA_32BIT_WORD", desc: "Transfers 32 bits"}
            { value: "1", name: "DMA_16BIT_WORD", desc: "Transfers 16 bits"}
            { value: "2", name: "DMA_8BIT_WORD" , desc: "Transfers  8 bits"}
            { value: "3", name: "DMA_8BIT_WORD_2",desc: "Transfers  8 bits"}
          ]
        }
      ]
    }
    { name:     "DST_DATA_TYPE"
      desc:     '''Width/type of the destination data to transfer'''
      swaccess: "rw"
      hwaccess: "hrw"
      resval:   0
      fields: [
        { bits: "1:0", name: "DATA_TYPE"
          desc: "Data type"
          enum: [
            { value: "0", name: "DMA_32BIT_WORD", desc: "Transfers 32 bits"}
            { value: "1", name: "DMA_16BIT_WORD", desc: "Transfers 16 bits"}
            { value: "2", name: "DMA_8BIT_WORD" , desc: "Transfers  8 bits"}
            { value: "3", name: "DMA_8BIT_WORD_2",desc: "Transfers  8 bits"}
          ]
        }
      ]
    }
    {
      name:     "SIGN_EXT"
      desc:     '''Is the data to be sign extended? (Checked only if the dst data type is wider than the src data type)'''
      swaccess: "rw"
      hwaccess: "hrw"
      resval:   0
      fields: [
        { bits: "0", name: "SIGNED"
          desc: "Extend the sign to the destination data"
          enum: [
            { value: "0", name: "NO_EXTEND", desc: "Does not extend the sign"}
            { value: "1", name: "EXTEND", desc: "Extends the sign"}
          ]
        }
      ]
    }
    { name:     "MODE"
      desc:     '''Set the operational mode of the DMA'''
      swaccess: "rw"
      hwaccess: "hrw"
      resval:   0
      fields: [
        { bits: "1:0", name: "MODE"
          desc: "DMA operation mode"
          enum: [
            { value: "0", name: "LINEAR_MODE", desc: "Transfers data linearly"}
            { value: "1", name: "CIRCULAR_MODE", desc: "Transfers data in circular mode"}
            { value: "2", name: "ADDRESS_MODE", desc: "Transfers data using as destination address the data from ADD_PTR"}
            { value: "3", name: "SUBADDRESS_MODE", desc: "Implements transferring of data when SRC_PTR is fixed and related to a peripheral"}
          ]
        }
      ]
    }
    { name:     "HW_FIFO_EN"
      desc:     '''Enable the HW FIFO mode'''
    % if dma_hw_fifo_mode:
      swaccess: "rw"
    % else:
      swaccess: "ro"
    % endif
      hwaccess: "hrw"
      resval:   0
      fields: [
        { bits: "0", name: "HW_FIFO_MODE", desc: "Mode for exploting external stream accelerators"}
      ]
    }
    { name:     "DIM_CONFIG"
      desc:     '''Set the dimensionality of the DMA'''
      swaccess: "rw"
      hwaccess: "hrw"
      resval:   0
      fields: [
        { bits: "0", name: "DMA_DIM", desc: "DMA transfer dimensionality"}
      ]
    }                          
    { name:     "DIM_INV"
      desc:     '''DMA dimensionality inversion selector'''
      swaccess: "rw"
      hwaccess: "hrw"
      resval:   0
      fields: [
        { bits: "0", name: "SEL", desc: "DMA dimensionality inversion, used to perform transposition"}
      ]
    }
    % if dma_zero_padding:
    { name:     "PAD_TOP"
      desc:     '''Set the top padding'''
      swaccess: "rw"
      hwaccess: "hrw"
      resval:   0
      fields: [
        { bits: "5:0", name: "PAD", desc: "Top margin padding (2D)"}
      ]
    }
    { name:     "PAD_BOTTOM"
      desc:     '''Set the bottom padding'''
      swaccess: "rw"
      hwaccess: "hrw"
      resval:   0
      fields: [
        { bits: "5:0", name: "PAD", desc: "Bottom margin padding (2D)"}
      ]
    }
    { name:     "PAD_RIGHT"
      desc:     '''Set the right padding'''
      swaccess: "rw"
      hwaccess: "hrw"
      resval:   0
      fields: [
        { bits: "5:0", name: "PAD", desc: "Right margin padding (1D/2D)"}
      ]
    }
    { name:     "PAD_LEFT"
      desc:     '''Set the left padding'''
      swaccess: "rw"
      hwaccess: "hrw"
      resval:   0
      fields: [
        { bits: "5:0", name: "PAD", desc: "Left margin padding (1D/2D)"}
      ]
    }
    % endif
    { name:    "WINDOW_SIZE"
      desc:    '''Will trigger a every "WINDOW_SIZE" writes
                  Set to 0 to disable.'''
      swaccess: "rw"
      hwaccess: "hrw"
      hwqe:     "true" // enable `qe` latched signal of software write pulse
      resval:   0
      fields: [
        { bits: "12:0", name: "WINDOW_SIZE", desc: ""}
      ]
    }
    { name:    "WINDOW_COUNT"
      desc:    '''Number of times the end of the window was reached since the beginning.
                  Reset at start'''
      swaccess: "ro"
      hwaccess: "hrw"
      resval: 0
      fields: [
        { bits: "7:0", name: "WINDOW_COUNT", desc: "Number of windows transferred in the transaction" }
      ]
    }
    { name:    "INTERRUPT_EN"
      desc:    '''Interrupt Enable Register 
                  (Only the interrupt with the lowest id will be triggered)'''
      swaccess: "rw"
      hwaccess: "hrw"
      resval:   0
      fields: [
        { bits: "0", name: "TRANSACTION_DONE", desc: "Enables transaction done interrupt" }
        { bits: "1", name: "WINDOW_DONE", desc: "Enables window done interrupt" }
      ]
    }
    { name:    "TRANSACTION_IFR"
      desc:    '''Interrupt Flag Register for transactions'''
      swaccess: "ro"
      hwaccess: "hrw"
      hwext:    "true"
      hwre:     "true" // latched signal of software write pulse
      resval:        0
      fields: [
        { bits: "0", name: "FLAG", desc: "Set for transaction done interrupt" }
      ]
    }
    { name:    "WINDOW_IFR"
      desc:    '''Interrupt Flag Register for windows'''
      swaccess: "ro"
      hwaccess: "hrw"
      hwext:    "true"
      hwre:     "true" // latched signal of software write pulse
      resval:        0
      fields: [
        { bits: "0", name: "FLAG", desc: "Set for window done interrupt" }
      ]
    }
    { name:    "HW_CONFIG_MODE"
      desc:    '''Hardware configuration mode'''
      swaccess: "rw"
      hwaccess: "hro"
      resval:        0
      fields: [
        { bits: "0", name: "HW_CONFIG_MODE", desc: "Whether the registers are configured in HW (1) or SW (0, default)" }
      ]
    }
    { name:    "SLOT_WAIT_COUNTER"
      desc:    '''A counter to wait before submitting the next req when using slots'''
      swaccess: "rw"
      hwaccess: "hrw"
      resval:        0
      fields: [
        { bits: "7:0", name: "SLOT_WAIT_COUNTER", desc: "A counter to wait before submitting the next req when using slots"}
      ]
    }
  ]
}
