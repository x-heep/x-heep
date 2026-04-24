#include "serial_link_sdk.h"

volatile int8_t sl_wrapper_dma_intr_flag = 0;
volatile int8_t sl_wrapper_direct_write_intr_flag = 0;

void dma_intr_handler_trans_done(uint8_t channel) {
    sl_wrapper_dma_intr_flag = 1;
}

static dma_target_t sl_dma_tgt_src = {
    .ptr       = (uint8_t *)SL_READ,
    .inc_d1_du = 0,
    .type      = DMA_DATA_TYPE_WORD,
    .trig      = DMA_TRIG_SLOT_SL_FIFO_RX,
};

static dma_target_t sl_dma_tgt_dst = {
    .inc_d1_du = 1,
    .type      = DMA_DATA_TYPE_WORD,
    .trig      = DMA_TRIG_MEMORY,
};

static dma_trans_t sl_dma_trans = {
    .src     = &sl_dma_tgt_src,
    .dst     = &sl_dma_tgt_dst,
    .dim     = DMA_DIM_CONF_1D,
    .end     = DMA_TRANS_END_INTR,
    .channel = 0,
};

void __attribute__ ((optimize("00"))) sl_cpu_send(uint32_t *src_d,uint32_t *src,  uint32_t large ){

    for (int i = 0; i < large; i++) {
        *src = *(src_d + i);
    }
}

void __attribute__ ((optimize("00"))) sl_cpu_read(uint32_t *dst_d, uint32_t *dst,  uint32_t large ){
    
    for (int i = 0; i < large; i++) {
        *(dst_d + i) = *dst;
    }
}

void __attribute__ ((optimize("00"))) sl_dma_send(uint32_t *src_d, uint32_t *src,uint32_t large){
    volatile static dma_config_flags_t res;
    volatile static dma_target_t tgt_src_d;
    volatile static dma_target_t tgt_dst_d;
    volatile static dma_trans_t trans;


        dma_init(NULL);
        tgt_src_d.ptr = (uint8_t *)src_d;
        tgt_src_d.inc_d1_du = 1;
        tgt_src_d.trig = DMA_TRIG_MEMORY;
        tgt_src_d.type = DMA_DATA_TYPE_WORD;

        tgt_dst_d.ptr = (uint8_t *)src;
        tgt_dst_d.inc_d1_du = 0;
        tgt_dst_d.trig = DMA_TRIG_MEMORY;
        tgt_dst_d.type = DMA_DATA_TYPE_WORD;

        trans.src = &tgt_src_d;
        trans.dst = &tgt_dst_d;
        trans.size_d1_du = large;
        trans.mode = DMA_TRANS_MODE_SINGLE;
        trans.win_du = 0;
        trans.sign_ext = 0;
        trans.end = DMA_TRANS_END_INTR;

        res |= dma_validate_transaction(&trans, false, false);
        res |= dma_load_transaction(&trans);
        res |= dma_launch(&trans);
        
        if(!dma_is_ready(0)) {
            CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
                    if (!dma_is_ready(0)) {
                        wait_for_interrupt();
                    }
            CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
        }
}

void __attribute__ ((optimize("00"))) sl_dma_read( uint32_t *dst_d, uint32_t *dst,uint32_t large){
    volatile static dma_config_flags_t res;
    volatile static dma_target_t tgt_src_d;
    volatile static dma_target_t tgt_dst_d;
    volatile static dma_trans_t trans;
        dma_init(NULL);
        tgt_src_d.ptr = (uint8_t *)dst;
        tgt_src_d.inc_d1_du = 0;
        tgt_src_d.trig = DMA_TRIG_MEMORY;
        tgt_src_d.type = DMA_DATA_TYPE_WORD;

        tgt_dst_d.ptr = (uint8_t *)dst_d;
        tgt_dst_d.inc_d1_du = 1;
        tgt_dst_d.trig = DMA_TRIG_MEMORY;
        tgt_dst_d.type = DMA_DATA_TYPE_WORD;

        trans.src = &tgt_src_d;
        trans.dst = &tgt_dst_d;
        trans.size_d1_du = large;
        trans.mode = DMA_TRANS_MODE_SINGLE;
        trans.win_du = 0;
        trans.sign_ext = 0;
        trans.end = DMA_TRANS_END_INTR;

        res |= dma_validate_transaction(&trans, false, false);
        res |= dma_load_transaction(&trans);
        res |= dma_launch(&trans);

        if(!dma_is_ready(0)) {
            CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
                    if (!dma_is_ready(0)) {
                        wait_for_interrupt();
                    }
            CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
        }
}

dma_config_flags_t sl_wrapper_dma_read_launch(uint32_t *dst, uint32_t count) { 

    if (!dma_is_ready(0)) {
        return DMA_CONFIG_TRANS_OVERRIDE;
    }

    if (sl_wrapper_get_rx_mode() != SL_WRAPPER_RX_MODE_FIFO) {
        sl_wrapper_set_rx_mode(SL_WRAPPER_RX_MODE_FIFO);
    }

    sl_dma_tgt_dst.ptr      = (uint8_t *)dst;
    sl_dma_trans.size_d1_du = count;

    sl_wrapper_dma_intr_flag = 0;

    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);

    dma_init(NULL);

    dma_config_flags_t res;

    res = dma_validate_transaction(&sl_dma_trans, DMA_ENABLE_REALIGN,
                                   DMA_PERFORM_CHECKS_INTEGRITY);
    if (res != DMA_CONFIG_OK) return res;

    res = dma_load_transaction(&sl_dma_trans);
    if (res != DMA_CONFIG_OK) return res;

    res = dma_launch(&sl_dma_trans);
    return res;
}

void sl_wrapper_direct_write_arm(uint32_t count) {
    // Write expected word count to wrapper register
    volatile uint32_t *count_reg = (volatile uint32_t *)(
        SERIAL_LINK_WRAPPER_REG_START_ADDRESS +
        SERIAL_LINK_XHEEP_WRAPPER_DIRECT_WRITE_WORD_COUNT_REG_OFFSET);
    *count_reg = count;

    sl_wrapper_direct_write_intr_flag = 0;

    // Register handler, set priority, enable in PLIC, edge trigger (one-cycle pulse)
    plic_Init();
    plic_assign_external_irq_handler(SERIAL_LINK_DIRECT_WRITE_ID,
                                     &handler_irq_sl_direct_write);
    plic_irq_set_priority(SERIAL_LINK_DIRECT_WRITE_ID, 1);
    plic_irq_set_trigger(SERIAL_LINK_DIRECT_WRITE_ID, kPlicIrqTriggerEdge);
    plic_irq_set_enabled(SERIAL_LINK_DIRECT_WRITE_ID, kPlicToggleEnabled);

    // Enable global interrupts
    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
    const uint32_t mask = 1 << 11;
    CSR_SET_BITS(CSR_REG_MIE, mask);
}

__attribute__((weak, optimize("O0"))) void handler_irq_sl_direct_write(uint32_t id) {
    // Default empty handler - override in application
}
