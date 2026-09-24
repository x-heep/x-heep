// Copyright 2025 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Authors: Pierre Guillod <pierre.guillod@epfl.ch>, EPFL, STI-SEL
//          Jérémie Moullet<jeremie.moullet@epfl.ch>,EPFL, STI-SEL  
//
// Date: 06.2025

{ name: "pdm2pcm"
  clock_primary: "clk_i"
  bus_interfaces: [
    { protocol: "reg_iface", direction: "device" }
  ]
  regwidth: "32"
  registers: [

    // CLOCK DIVISION

    { name:     "CLKDIVIDX"
      desc:     "Decimation ratio from the sys_clk to the sampling frequency"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "15:0", name: "COUNT", desc: "Index at which clock divide." }
      ]
    }

    // STATUS & CONTROL REGISTERS

    { name:     "CONTROL"
      desc:     "Control register"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "0", name: "ENABL", desc: "Starts PDM data processing. The FIFO starts to fill with PCM data." }
        { bits: "1", name: "CLEAR", desc: "Clears the FIFO buffer." }
      ]
    }

    { name:     "STATUS"
      desc:     "Status register"
      swaccess: "ro"
      hwaccess: "hrw"
      fields: [
        { bits: "0", name: "EMPTY", desc: "The FIFO buffer is empty." }
        { bits: "1", name: "FULLL", desc: "The FIFO buffer is full."}
      ]
    }

    // CIC Filter stages

    //The maximal number of stage is determined by the number of bits of this field.
    { name:   "cic_activated_stages"
    desc:     "Thermometric value of the activated stages (The 1s should be contiguous and right-aligned)"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "5:0" }
      ]
    }

    { name:     "cic_delay_comb"
      desc:     "delay in each comb block (D)"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "3:0" }
      ]
    }

    // DECIMATORS

    { name:     "DECIMCIC"
      desc:     "Samples count after which to decimate in the CIC filter."
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "3:0", name: "COUNT", desc: "Set the samples count" }
      ]
    }

<%
  _dom = xheep.get_user_peripheral_domain()
  pdm2pcm = _dom.get_peripheral("pdm2pcm") if _dom is not None and _dom.contains_peripheral("pdm2pcm") else None
%>

% if pdm2pcm != None and not pdm2pcm.get_cic_mode() :
    { name:     "DECIMHB1"
      desc:     "Samples count after which to decimate after the first halfband filter."
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "4:0", name: "COUNT", desc: "Set the samples count" }
      ]
    }
    { name:     "DECIMHB2"
      desc:     "Samples count after which to decimate after the second halfband filter."
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "5:0", name: "COUNT", desc: "Set the samples count" }
      ]
    }

    // COEFFICIENTS
    // For Halfband filter #1

    { name:     "HB1COEF00"
      desc:     "Filter HB1 coefficient 0"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "HB1COEF01"
      desc:     "Filter HB1 coefficient 1"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "HB1COEF02"
      desc:     "Filter HB1 coefficient 2"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "HB1COEF03"
      desc:     "Filter HB1 coefficient 3"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }

    // COEFFICIENTS
    // For Halfband filter #2

    { name:     "HB2COEF00"
      desc:     "Filter HB2 coefficient 0"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "HB2COEF01"
      desc:     "Filter HB2 coefficient 1"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "HB2COEF02"
      desc:     "Filter HB2 coefficient 2"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "HB2COEF03"
      desc:     "Filter HB2 coefficient 3"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "HB2COEF04"
      desc:     "Filter HB2 coefficient 4"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "HB2COEF05"
      desc:     "Filter HB2 coefficient 5"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "HB2COEF06"
      desc:     "Filter HB2 coefficient 6"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }

    // COEFFICIENTS
    // For FIR filter

    { name:     "FIRCOEF00"
      desc:     "Filter FIR coefficient 0"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "FIRCOEF01"
      desc:     "Filter FIR coefficient 1"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "FIRCOEF02"
      desc:     "Filter FIR coefficient 2"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "FIRCOEF03"
      desc:     "Filter FIR coefficient 3"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "FIRCOEF04"
      desc:     "Filter FIR coefficient 4"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "FIRCOEF05"
      desc:     "Filter FIR coefficient 5"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "FIRCOEF06"
      desc:     "Filter FIR coefficient 6"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "FIRCOEF07"
      desc:     "Filter FIR coefficient 7"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "FIRCOEF08"
      desc:     "Filter FIR coefficient 8"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "FIRCOEF09"
      desc:     "Filter FIR coefficient 9"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "FIRCOEF10"
      desc:     "Filter FIR coefficient 10"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "FIRCOEF11"
      desc:     "Filter FIR coefficient 11"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "FIRCOEF12"
      desc:     "Filter FIR coefficient 12"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
    { name:     "FIRCOEF13"
      desc:     "Filter FIR coefficient 13"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "17:0", name: "COEFF", desc: "Set the coefficient" }
      ]
    }
% endif

    // WINDOW
    { window: {
        name: "RXDATA"
        items: "1"
        validbits: "32"
        desc: "Filtered output data"
        swaccess: "ro"
      }
    }
  ]
}

