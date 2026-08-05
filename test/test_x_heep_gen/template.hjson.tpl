## Writes down all kwargs from mcu_gen, but only peripheral related ones should be checked

<%
    user_peripheral_domain = xheep.get_user_peripheral_domain()
    base_peripheral_domain = xheep.get_base_peripheral_domain()
    dma = base_peripheral_domain.get_dma()
    pdm2pcm = user_peripheral_domain.get_pdm2pcm()
    cpu = xheep.cpu()
    external_domains = base_peripheral_domain.get_power_manager().get_external_domains()
    address_map = xheep.address_map()
%>

{
    // CPU configuration
    cpu_type: "${cpu.get_name()}"
    % if cpu.is_defined("rv32e"):
    cve2_rv32e: "${cpu.get_sv_str("rv32e")}"
    % endif
    % if cpu.is_defined("rv32m"):
    cve2_rv32m: "${cpu.get_sv_str("rv32m")}"
    % endif
    external_domains: ${external_domains}

    // Memory map
    debug: {
        address: "${hex(address_map.get_region("debug").get_start_address())}"
        length: "${hex(address_map.get_region("debug").get_length())}"
    }

    // AO Peripherals
    ao_peripheral_start_address: "${base_peripheral_domain.get_start_address()}"
    ao_peripheral_size_address: "${base_peripheral_domain.get_length()}"
    ao_peripherals: {
        % for peripheral in base_peripheral_domain.get_peripherals():
        ${peripheral.get_name()}: {
            offset: ${peripheral.get_address()}
            size: ${peripheral.get_length()}
        }
        % endfor
    }
    ao_peripherals_count: ${len(base_peripheral_domain.get_peripherals())}

    // DMA Configuration
    dma_ch_count: "${dma.get_num_channels()}"
    dma_ch_size: "${dma.get_ch_length()}"
    num_dma_master_ports: "${dma.get_num_master_ports()}"
    num_dma_xbar_channels_per_master_port: "${dma.get_num_channels_per_master_port()}"
    fifo_depth: "${dma.get_fifo_depth()}"
    addr_mode_en: "${dma.get_addr_mode()}"
    subaddr_mode_en: "${dma.get_subaddr_mode()}"
    hw_fifo_mode_en: "${dma.get_hw_fifo_mode()}"
    zero_padding_en: "${dma.get_zero_padding()}"
    dma_xbar_masters_array: "${dma.get_xbar_array()}"

    // Optional Peripherals
    peripheral_start_address: "${user_peripheral_domain.get_start_address()}"
    peripheral_size_address: "${user_peripheral_domain.get_length()}"
    peripherals: {
        % for peripheral in user_peripheral_domain.get_peripherals():
        ${peripheral.get_name()}: {
            offset: ${peripheral.get_address()}
            size: ${peripheral.get_length()}
        }
        % endfor
    }
    peripherals_count: ${len(user_peripheral_domain.get_peripherals())}

    %if pdm2pcm != None:
    // PDM2PCM configuration
        %if pdm2pcm.get_cic_mode():
    pdm2pcm_cic_only: 0x1
        %else:
    pdm2pcm_cic_only: 0x0
        %endif
    %endif

    // External Slaves and Flash Memory
    ext_slaves: {
        address: "${address_map.get_region("ext_slaves").get_start_address()}"
        length: "${address_map.get_region("ext_slaves").get_length()}"
    }
    flash_mem: {
        address: "${address_map.get_region("flash_mem").get_start_address()}"
        length: "${address_map.get_region("flash_mem").get_length()}"
    }

    // Memory Configuration
    linker_script: {
        stack_size: "${format(xheep.stack_size(), 'X')}"
        heap_size: "${format(xheep.heap_size(), 'X')}"
    }

    // Interrupt Configuration
    interrupts: {
        used: ${plic_used_n_interrupts}
        total: ${plit_n_interrupts}
        list: ${interrupts}
    }

    // Pad Configuration
    pad_config: {
        total_pads: ${len(xheep.get_padring().pad_list)}
        total_muxed_pads: ${xheep.get_padring().num_muxed_pads()}
        max_mux_bits: ${xheep.get_padring().get_muxed_pad_select_width()}
        % if "bits" in xheep.get_padring().attributes:
        attributes: ${xheep.get_padring().attributes.get("bits")}
        % endif
    }
}
