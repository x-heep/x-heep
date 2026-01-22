/*
                              *******************
******************************* C SOURCE FILE *****************************
**                            *******************
**
** project  : X-HEEP
** filename : dma.c
** version  : 1
** date     : 13/02/23
**
***************************************************************************
**
** Copyright (c) EPFL contributors.
** All rights reserved.
**
***************************************************************************
*/

/***************************************************************************/
/***************************************************************************/
/**
* @file   dma.c
* @date   13/02/23
* @brief  The Direct Memory Access (DMA) driver to set up and use the DMA
* peripheral
*/

/****************************************************************************/
/**                                                                        **/
/*                             MODULES USED                                 */
/**                                                                        **/
/****************************************************************************/

#ifdef __cplusplus
extern "C"
{
#endif // __cplusplus

#include "dma.h"

/* To manage addresses. */
#include "mmio.h"

/* To manage interrupts. */
#include "fast_intr_ctrl.h"
#include "csr.h"
#include "stdasm.h"

/****************************************************************************/
/**                                                                        **/
/*                        DEFINITIONS AND MACROS                            */
/**                                                                        **/
/****************************************************************************/

 /**
 * Static DMA ASSERT.
 */
#define DMA_STATIC_ASSERT(expr, msg)// _Static_assert(!expr, msg);

/**
 * Returns the mask to enable/disable DMA transaction done interrupts.
 */
#define DMA_DONE_CSR_REG_MIE_MASK (( 1 << 19 )) // 19 is DMA fast interrupt bit in MIE CSR

/**
 * Returns the mask to enable/disable DMA window interrupts.
 */
#define DMA_WINDOW_CSR_REG_MIE_MASK (( 1 << 30 )) // 30 is DMA fast interrupt bit in MIE CSR

/**
 * Mask to determine if an address is multiple of 4 (Word aligned).
 */
#define DMA_WORD_ALIGN_MASK 3

/**
 * Mask to determine if an address is multiple of 2 (Half Word aligned).
 */
#define DMA_HALF_WORD_ALIGN_MASK 1

/**
 * Selection offset to be used as index for when a register is written from
 * the beginning.
*/
#define DMA_SELECTION_OFFSET_START 0

/**
 * A small window size might result in loss of syncronism. If the processing
 * of the window takes longer than the time it takes to the DMA to finish the
 * next window, the application will not be able to cope. Although "how small
 * is too small" is highly dependent on the length of the processing, this
 * flag will be raised when the transaction and window size ratio is smaller
 * than this arbitrarily chosen ratio as a mere reminder.
 */
#define DMA_DEFAULT_TRANS_TO_WIND_SIZE_RATIO_THRESHOLD 4


/****************************************************************************/
/**                                                                        **/
/*                        TYPEDEFS AND STRUCTURES                           */
/**                                                                        **/
/****************************************************************************/

/**
 * Interrupts must be enabled in the INTERRUPT register of the DMA.
 * Only one at a time. In case more than one is interrupt is to be triggered,
 * at the same time (last byte of a transaction of size multiple of the window
 * size) only the lowest ID is triggered.
 */
typedef enum
{
    INTR_EN_NONE        = 0x0, /*!< No interrupts should be triggered. */
    INTR_EN_TRANS_DONE  = 0x1, /*!< The TRANS_DONE interrupt is a fast
    interrupt that is triggered once the whole transaction has finished. */
    INTR_EN_WINDOW_DONE = 0x2, /*!< The WINDOW_DONE interrupt is a PLIC
    interrupt that is triggered every given number of bytes (set in the
    transaction configuration as win_du). */
    INTR_EN__size,
} inter_en_t;

/****************************************************************************/
/**                                                                        **/
/*                      PROTOTYPES OF LOCAL FUNCTIONS                       */
/**                                                                        **/
/****************************************************************************/

/**
 * @brief Creates a target that can be used to perform transactions.
 * @param p_tgt Pointer to the dma_target_t structure where configuration
 * should be allocated. The content of this pointer must be a static variable.
 * @return A configuration flags mask. Each individual flag can be accessed with
 * a bitwise AND ( ret & DMA_CONFIG_* ).
 */
dma_config_flags_t validate_target( dma_target_t *p_tgt, dma_trans_t *p_trans );

/**
 * @brief Creates an environment where targets can be added. An environment
 * is, for instance, a RAM block, or section of memory that can be used by
 * the DMA.
 * Properly defining an environment can prevent the DMA from accessing
 * restricted memory regions.
 * Targets for peripherals do not need an environment.
 * @param p_env Pointer to the dma_env_t structure where configuration
 * should be allocated. The content of this pointer must be a static variable.
 * @return A configuration flags mask. Each individual flag can be accessed
 * with a bitwise AND ( ret & DMA_CONFIG_* ). It is not recommended to query
 * the result from inside environment structure as an error could have
 * appeared before the creation of the structure.
 */
dma_config_flags_t validate_environment( dma_env_t *p_env );

/**
 * @brief Gets how misaligned a pointer is, taking into account the data type
 * size.
 * @param p_ptr The source or destination pointer.
 * @return How misaligned the pointer is, in bytes.
 */
static inline uint8_t get_misalignment_b(   uint8_t         *p_ptr,
                                            dma_data_type_t p_type );


/**
 * @brief Determines whether a given region will fit before the end of an
 * environment.
 * @param p_start Pointer to the beginning of the region.
 * @param p_end Pointer to the last byte of the environment.
 * @param p_type The data type to be transferred.
 * @param p_size_d1_du The number of data units to be transferred. Must be
 * non-zero.
 * @param p_inc_d1_du The size in data units of each increment.
 * @retval 1 There is an outbound.
 * @retval 0 There is NOT an outbound.
 */
static inline uint8_t is_region_outbound_1D(   uint8_t  *p_start,
                                            uint8_t  *p_end,
                                            uint32_t p_type,
                                            uint32_t p_size_d1_du,
                                            uint32_t p_inc_d1_du );

/**
 * @brief Determines whether a given region will fit before the end of an
 * environment with a 2D transaction.
 * @param p_start Pointer to the beginning of the region.
 * @param p_end Pointer to the last byte of the environment.
 * @param p_type The data type to be transferred.
 * @param p_size_d1_du The number of data units to be transferred. Must be
 * non-zero.
 * @param p_inc_d1_du The size in data units of each increment.
 * @retval 1 There is an outbound.
 * @retval 0 There is NOT an outbound.
 */
static inline uint8_t is_region_outbound_2D(   uint8_t  *p_start,
                                            uint8_t  *p_end,
                                            uint32_t p_type,
                                            uint32_t p_size_d1_du,
                                            uint32_t p_size_d2_du,
                                            uint32_t p_inc_d1_du,
                                            uint32_t p_inc_d2_du );

/**
 * @brief Analyzes a target to determine the size of its D1 increment (in bytes).
 * @param p_tgt A pointer to the target to analyze.
 * @param channel The channel to use as target.
 * @return The number of bytes of the increment.
 */
static inline uint32_t get_increment_b_1D( dma_target_t * p_tgt,
                                    uint8_t channel );

/**
 * @brief Analyzes a target to determine the size of its D2 increment (in bytes).
 * @param p_tgt A pointer to the target to analyze.
 * @param channel The channel to use as target.
 * @return The number of bytes of the increment.
 */
static inline uint32_t get_increment_b_2D( dma_target_t * p_tgt,
                                    uint8_t channel  );


/****************************************************************************/
/**                                                                        **/
/*                           EXPORTED VARIABLES                             */
/**                                                                        **/
/****************************************************************************/

/****************************************************************************/
/**                                                                        **/
/*                            GLOBAL VARIABLES                              */
/**                                                                        **/
/****************************************************************************/

/**
 * Control Block (CB) of a single DMA channel.
 * Has variables and constant necessary/useful for its control.
 */
typedef struct
{
    /**
    * Pointer to the transaction to be performed.
    */
    dma_trans_t* trans;

    /**
    * Flag to lower as soon as a transaction is launched, and raised by the
    * interrupt handler once it has finished. Only used when the end event is
    * set to INTR_WAIT.
    */
    uint8_t intrFlag;

    /**
     * memory mapped structure of a DMA.
     */
    dma *peri;

}dma_ch_cb;

/* Allocate the channel's memory space */
static dma_ch_cb dma_subsys_per[DMA_CH_NUM];

/* High priority interrupts counters */
uint16_t dma_hp_tr_intr_counter = 0;
uint16_t dma_hp_win_intr_counter = 0;


/****************************************************************************/
/**                                                                        **/
/*                           EXPORTED FUNCTIONS                             */
/**                                                                        **/
/****************************************************************************/

void fic_irq_dma_window(void)
{
    /* 
     * Find out which channel raised the interrupt and call
     * either the weak implementation provided in this module,
     * or the non-weak implementation.
     */

    for (int i = 0; i < DMA_CH_NUM; i++)
    {
        if (dma_subsys_per[i].peri->WINDOW_IFR == 1)
        {
            dma_intr_handler_window_done(i);

             #ifdef DMA_HP_INTR_INDEX
            /* 
             * If the channel that raised the interrupt is among the high priority channels,
             * return to break the loop. 
             */
            #ifdef DMA_NUM_HP_INTR
            if (i <= DMA_HP_INTR_INDEX && dma_hp_win_intr_counter < DMA_NUM_HP_INTR)
            {
                dma_hp_win_intr_counter++;
                return;
            } else if (i > DMA_HP_INTR_INDEX)
            {
                dma_hp_win_intr_counter = 0;
            }

            #else

            if (i <= DMA_HP_INTR_INDEX)
            {
                return;
            }
            #endif

            #endif
        }
    }
    return;
}

void fic_irq_dma_done(void)
{
    /* 
     * Find out which channel raised the interrupt and call
     * either the weak implementation provided in this module,
     * or the non-weak implementation.
     */
    
    for (int i = 0; i < DMA_CH_NUM; i++)
    {
        if (dma_subsys_per[i].peri->TRANSACTION_IFR == 1)
        {
            dma_subsys_per[i].intrFlag = 1;
            dma_intr_handler_trans_done(i);

            #ifdef DMA_HP_INTR_INDEX
            /* 
             * If the channel that raised the interrupt is among the high priority channels,
             * return to break the loop. 
             */
            #ifdef DMA_NUM_HP_INTR
            if (i <= DMA_HP_INTR_INDEX && dma_hp_tr_intr_counter < DMA_NUM_HP_INTR)
            {
                dma_hp_tr_intr_counter++;
                return;
            }
            else if (i > DMA_HP_INTR_INDEX)
            {
                dma_hp_tr_intr_counter = 0;
            }

            #else

            if (i <= DMA_HP_INTR_INDEX)
            {
                return;
            }
            #endif

            #endif
        }
    }
    return;
}
uint32_t dma_set_hw_configuration_mode(uint32_t hw_config_mode, int dma_ch)
{
    uint32_t old_hw_config_mode = dma_subsys_per[dma_ch].peri->HW_CONFIG_MODE;
    dma_peri(dma_ch)->HW_CONFIG_MODE = hw_config_mode;
    return old_hw_config_mode;
}

uint32_t dma_set_slot_wait_counter(uint32_t slot_wait_counter, int dma_ch)
{
    uint32_t old_slot_wait_counter = dma_subsys_per[dma_ch].peri->SLOT_WAIT_COUNTER;
    dma_peri(dma_ch)->SLOT_WAIT_COUNTER = (uint32_t)(slot_wait_counter & DMA_SLOT_WAIT_COUNTER_SLOT_WAIT_COUNTER_MASK);
    return old_slot_wait_counter;
}

void dma_init( dma *dma_peri )
{
    /*
     * If a DMA peripheral was provided, use that one, otherwise use the
     * integrated one.
     */

    for (int i = 0; i < DMA_CH_NUM; i++)
    {
        dma_subsys_per[i].peri = dma_peri ? dma_peri : dma_peri(i);

        /* Clear the loaded transaction */
        dma_subsys_per[i].trans = NULL;

        /* Clear all values in the DMA registers. */
        dma_subsys_per[i].peri->SRC_PTR           = 0;
        dma_subsys_per[i].peri->DST_PTR           = 0;
        dma_subsys_per[i].peri->SIZE_D1           = 0;
        dma_subsys_per[i].peri->SIZE_D2           = 0;
        dma_subsys_per[i].peri->SRC_PTR_INC_D1    = 0;
        dma_subsys_per[i].peri->SRC_PTR_INC_D2    = 0;
        dma_subsys_per[i].peri->DST_PTR_INC_D1    = 0;
        dma_subsys_per[i].peri->DST_PTR_INC_D2    = 0;
        dma_subsys_per[i].peri->DIM_CONFIG        = 0;
        dma_subsys_per[i].peri->DIM_INV           = 0;
        dma_subsys_per[i].peri->SLOT              = 0;
        dma_subsys_per[i].peri->SRC_DATA_TYPE     = 0;
        dma_subsys_per[i].peri->DST_DATA_TYPE     = 0;
        dma_subsys_per[i].peri->SIGN_EXT          = 0;
        dma_subsys_per[i].peri->MODE              = 0;
        dma_subsys_per[i].peri->WINDOW_SIZE       = 0;
        dma_subsys_per[i].peri->INTERRUPT_EN      = 0;
        dma_subsys_per[i].peri->HW_CONFIG_MODE    = 0;
        dma_subsys_per[i].peri->SLOT_WAIT_COUNTER = 0;

        #if DMA_ADDR_MODE
        dma_subsys_per[i].peri->ADDR_PTR       = 0;
        #endif

        #if DMA_ZERO_PADDING
        dma_subsys_per[i].peri->PAD_TOP        = 0;
        dma_subsys_per[i].peri->PAD_BOTTOM     = 0;
        dma_subsys_per[i].peri->PAD_LEFT       = 0;
        dma_subsys_per[i].peri->PAD_RIGHT      = 0;
        #endif
    }
}

dma_config_flags_t dma_validate_transaction(    dma_trans_t        *p_trans,
                                                dma_en_realign_t   p_enRealign,
                                                dma_perf_checks_t  p_check )
{
    /*
    * SANITY CHECKS
    */

    /* Data type is not necessary. If something is provided anyways it should
     be valid.*/
    DMA_STATIC_ASSERT( p_trans->type   < DMA_DATA_TYPE__size,
                       "Data type not valid");
    /* Transaction mode should be a valid mode. */
    DMA_STATIC_ASSERT( p_trans->mode   < DMA_TRANS_MODE__size,
                       "Transaction mode not valid");
    /* The end event should be a valid end event. */
    DMA_STATIC_ASSERT( p_trans->end    < DMA_TRANS_END__size,
                       "End event not valid");
    /* The alignment permission should be a valid permission. */
    DMA_STATIC_ASSERT( p_enRealign     < DMA_ENABLE_REALIGN__size,
                       "Alignment not valid");
    /* The checks request should be a valid request. */
    DMA_STATIC_ASSERT( p_check         < DMA_PERFORM_CHECKS__size,
                       "Check request not valid");
    /* The padding should be a valid number (if enabled) */
    #if DMA_ZERO_PADDING
    DMA_STATIC_ASSERT( ((p_trans->pad_top_du >= 0 && p_trans->pad_top_du < 64) && 
                        (p_trans->pad_bottom_du >= 0 && p_trans->pad_bottom_du < 64) && 
                        (p_trans->pad_left_du >= 0 && p_trans->pad_left_du < 64) &&
                        (p_trans->pad_right_du >= 0 && p_trans->pad_right_du < 64)), 
                       "Padding not valid");
    #endif
    /* The dimensionality should be valid*/
    DMA_STATIC_ASSERT( p_trans->dim < DMA_DIM_CONF__size, "Dimensionality not valid");

    /*
     * CHECK IF TARGETS HAVE ERRORS
     */

    /*
     * The transaction is NOT created if the targets include errors.
     * A successful target validation has to be done before loading it to the
     * DMA.
     */
    uint8_t errorSrc = validate_target( p_trans->src, p_trans);
    uint8_t errorDst = validate_target( p_trans->dst, p_trans);

    /*
     * If there are any errors or warnings in the valdiation of the targets,
     * they are added to the transaction flags, adding the source/destination
     * identifying flags as well.
     */
    p_trans->flags |= errorSrc ? (errorSrc | DMA_CONFIG_SRC ) : DMA_CONFIG_OK;
    p_trans->flags |= errorDst ? (errorDst | DMA_CONFIG_SRC ) : DMA_CONFIG_OK;

    /* If a critical error was detected, no further action is performed. */
    if( p_trans->flags & DMA_CONFIG_CRITICAL_ERROR )
    {
        return p_trans->flags;
    }

    /*
     * CHECK IF THERE ARE INCREMENTS INCONSISTENCIES
     */

    /*
     * A transaction is considered 2D if the source and/or the destination has a 2D increment.
     * e.g. It's possible to copy a 1x9 matrix to a 3x3 matrix or to copy a 3x3 matrix to a 1x9 one.
     */

    if (p_check)
    {
        // If the transaction is 2D, check that the D2 increment of the targets are non zero.
        // If the transaction is 1D, check that the D2 increment of the targets are zero.
        if((p_trans->dim == DMA_DIM_CONF_2D && (p_trans->src->inc_d2_du == 0 || p_trans->dst->inc_d2_du == 0)) ||
           (p_trans->dim == DMA_DIM_CONF_1D && (p_trans->src->inc_d2_du != 0 || p_trans->dst->inc_d2_du != 0)))
        {
            p_trans->flags |= DMA_CONFIG_INCOMPATIBLE;
            p_trans->flags |= DMA_CONFIG_CRITICAL_ERROR;
            return p_trans->flags;
        }
    }

    /*
     * CHECK IF THERE ARE PADDING INCONSISTENCIES
     */
    
    #if DMA_ZERO_PADDING
    if (p_check)
    {
        // If the transaction is 1D, check that the top and bottom paddings are set to zero.
        if((p_trans->dim == DMA_DIM_CONF_1D && (p_trans->pad_top_du != 0 || p_trans->pad_bottom_du != 0)))
        {
            p_trans->flags |= DMA_CONFIG_INCOMPATIBLE;
            p_trans->flags |= DMA_CONFIG_CRITICAL_ERROR;
            return p_trans->flags;
        }
    }
    #endif

    /*
     * CHECK IF THERE ARE TRIGGER INCONSISTENCIES
     */

    /*
     * The DMA can only handle one trigger at a time, therefore, if the two
     * targets require a trigger, the transaction has to be discarded.
     * None of the two values can be taken by default because this
     * inconsistency is probably a result of an error (likely wrong target
     * selection).
     */
    if( p_check )
    {
        if(     p_trans->src->trig != DMA_TRIG_MEMORY
            &&  p_trans->dst->trig != DMA_TRIG_MEMORY )
        {
            p_trans->flags |= DMA_CONFIG_INCOMPATIBLE;
            p_trans->flags |= DMA_CONFIG_CRITICAL_ERROR;
            return p_trans->flags;
        }
    }

    /*
     * CHECK IF THERE IS A MODE INCONSISTENCY
     */

    /*
     * Memory to Memory in circular mode is not only of dubious usefulness, but also
     * risky. Depending on the MCU properties, the buffer size, the window size and
     * length of the ISR, the CPU could miss consecutive interrupts or even enter in
     * an irreversible loop state.
     * This issue is less likely to happen with a properly set Memory-to-peripheral
     * configuration, so circular mode is allowed.
     */
    if( p_check )
    {
        if(    p_trans->src->trig == DMA_TRIG_MEMORY
            && p_trans->dst->trig == DMA_TRIG_MEMORY
            && p_trans->mode      == DMA_TRANS_MODE_CIRCULAR )
        {
            p_trans->flags |= DMA_CONFIG_INCOMPATIBLE;
            p_trans->flags |= DMA_CONFIG_CRITICAL_ERROR;
            return p_trans->flags;
        }
    }

    /*
     * SET UP THE DEFAULT CONFIGURATIONS
     */

    /* The flags are cleaned in case the structure was used before.*/
    p_trans->flags = DMA_CONFIG_OK;

    p_trans->src_type = p_trans->src->type;
    p_trans->dst_type = p_trans->dst->type;

    /*
     * By default, the transaction increment is set to 0 and, if required,
     * it will be changed to 1 (in which case both src and dst will have an
     * increment of 1 data unit).
     */
    p_trans->inc_b = 0;

    /*
     * CHECK IF THERE ARE MISALIGNMENTS
     */

    if( p_check  )
    {
        /*
         * The source and destination targets are analyzed.
         * If the target is a peripheral (i.e. uses one of trigger slots)
         * then the misalignment is not checked.
         */
        uint8_t misalignment = 0;
        uint8_t dstMisalignment = 0;

        if( p_trans->src->trig == DMA_TRIG_MEMORY )
        {
            misalignment = get_misalignment_b( p_trans->src->ptr, p_trans->src_type );
        }

        if( p_trans->dst->trig == DMA_TRIG_MEMORY )
        {
            dstMisalignment = get_misalignment_b( p_trans->dst->ptr, p_trans->dst_type );
        }

        p_trans->flags  |= ( misalignment ? DMA_CONFIG_SRC : DMA_CONFIG_OK );
        p_trans->flags  |= ( dstMisalignment ? DMA_CONFIG_DST : DMA_CONFIG_OK );

        /* Only the largest misalignment is preserved.*/
        if( misalignment < dstMisalignment )
        {
            misalignment = dstMisalignment;
        }

        if( misalignment != 0 )
        {
            /*
             * Misalignment flags will only be stored in the transaction, as
             * they are data type dependent, and could vary from transaction
             * to transaction, even with the same pair of targets.
             */
            p_trans->flags |= DMA_CONFIG_MISALIGN;

            /*
             * If a misalignment is detected and realignment is not allowed,
             * an error is returned. No operation should be performed by the DMA.
             * No further operations are done to prevent corrupting information
             * that could be useful for debugging purposes.
             */
            if( !p_enRealign)
            {
                return p_trans->flags |= DMA_CONFIG_CRITICAL_ERROR;
            }

            /*
             * CHECK IF THERE IS A DISCONTINUITY
             */

            /*
             * If there is a misalignment AND the source or destination
             * arrangements are discontinuous, it is not possible to use the
             * DMA. An error is returned.
             * A discontinuity in an arrangement is defined as the increment
             * being larger than the data type size.
             * e.g.
             * |AAAA|AAAA|BBBB|BBBB|      |____|AAAA|AAAA|____|
             * 0    1    2    3           0    1    2    3
             *
             * |CCCC|CCCC|____|____| ==>  |____|BBBB|BBBB|____|
             * 4    5    6    7           4    5    6    7
             *
             * |____|____|____|____|      |____|CCCC|CCCC|____|
             * 8    9    10   11          8    9    10   11
             *
             * In this case the source arrangement has 16bit HALF WORDs, with
             * an increment of 1 data unit, so all data is continuous.
             * The destination arrangement has also 16bit HALF WORDs, but
             * misaligned and with 2 data units of increment.
             * To copy a misaligned arrangement of HALF WORDs, the DMA should
             * use BYTEs. However, by using bytes it would not be able to
             * write twice and skip twice, as it has a single skip increment.
             *
             * The misalignment and discontinuity can be found in the source
             * and destination respectively and vice versa, and this
             * limitation would still exist.
             *
             * The discontinuous flag is added (the misaligned one was
             * already there), and it is turned into a critical error.'
             *
             * No further operations are done to prevent corrupting
             * information that could be useful for debugging purposes.
             */
            if(    ( p_trans->src->inc_d1_du > 1 )
                || ( p_trans->dst->inc_d1_du > 1 ) )
            {
                p_trans->flags |= DMA_CONFIG_DISCONTINUOUS;
                p_trans->flags |= DMA_CONFIG_CRITICAL_ERROR;
                return p_trans->flags;
            }

            /*
             * PERFORM THE REALIGNMENT
             */

            /*
             * If realignment is allowed and there are no discontinuities,
             * a more granular data type is used according to the detected
             * misalignment in order to overcome it.
             */ 
            p_trans->dst_type = p_trans->dst_type + misalignment;

           /*
             * Source and destination increment should now be of the size
             * of the data.
             * As increments are given in bytes, in both cases should be the
             * size of a data unit.
             */
            p_trans->inc_b = DMA_DATA_TYPE_2_SIZE( p_trans->dst_type );
            /* The copy size does not change, as it is already stored in bytes.*/
        }

        /*
         * CHECK IF SOURCE HAS ZERO SIZE(s)
         */

        /*
         * No further operations are done to prevent corrupting information
         * that could be useful for debugging purposes.
         */
        if(p_trans->size_d1_du == 0 || (p_trans->dim == DMA_DIM_CONF_2D && p_trans->size_d2_du == 0))
        {
            p_trans->flags |= DMA_CONFIG_SRC;
            p_trans->flags |= DMA_CONFIG_CRITICAL_ERROR;
            return p_trans->flags;
        }

        /*
         * CHECK IF THERE IS CROSS-OUTBOUND
         */

        /*
         * As the source target does not know the constraints of the
         * destination target, it is possible that the copied information
         * ends up beyond the bounds of the destination environment.
         * This check is not performed if no destination environment was set.
         *
         * e.g.
         * If 10 HALF WORDs are to be transferred with a HALF WORD in between
         * (increment of 2 data units: writes 2 bytes, skips 2 bytes, ...),
         * then ( 10 data units * 2 bytes ) + ( 9 data units * 2 bytes ) are
         * traveled for each = 38 bytes
         * that need to be gone over in order to complete the transaction.
         * Having the transaction size in bytes, they need to be converted
         * to data units:
         * size [data units] = size [bytes] / convertionRatio [bytes/data unit].
         *
         * The transaction can be performed if the whole affected area can fit
         * inside the destination environment
         * (i.e. The start pointer + the 38 bytes -in this case-, is smaller
         * than the end pointer of the environment).
         *
         * No further operations are done to prevent corrupting information
         * that could be useful for debugging purposes.
         */
        uint8_t isEnv = (p_trans->dst->env != NULL);

        if(isEnv) {
            uint8_t isOutb = is_region_outbound_1D(
                                        p_trans->dst->ptr,
                                        p_trans->dst->env->end,
                                        p_trans->dst_type,
                                        p_trans->size_d1_du,
                                        p_trans->dst->inc_d1_du );
            if( isOutb )
            {
                p_trans->flags |= DMA_CONFIG_DST;
                p_trans->flags |= DMA_CONFIG_OUTBOUNDS;
                p_trans->flags |= DMA_CONFIG_CRITICAL_ERROR;

                return p_trans->flags;
            }
        }
        // @ToDo: It should also be checked that the destination is behind the
        // source if there will be overlap.
        // @ToDo: Consider if (when a destination target has no environment)
        // the destination size should be used as limit.

        /*
         * CHECK IF THE WINDOW SIZE IS ADEQUATE
         */

        /*
         * The window size cannot be larger than the transaction size. Although
         * this would not cause any error, the transaction is rejected because
         * it is likely a mistake.
         * UNLESS the transaction is using the circular mode, in which case this
         * check does not make sense as the window count is carried over different
         * transactions
          */
        if( p_trans->win_du > p_trans->size_d1_du && p_trans->mode != DMA_TRANS_MODE_CIRCULAR )
        {
            p_trans->flags |= DMA_CONFIG_WINDOW_SIZE;
            p_trans->flags |= DMA_CONFIG_CRITICAL_ERROR;
            return p_trans->flags;
        }

        /*
         * If the ratio between the transaction size and the window size is too
         * large, the window size might be too small for the application to
         * properly handle. The threshold is set in a weak implementation that
         * can be overriden to adopt a custom value or set to return 0 to bypass
         * this check.
         * The window size can also be set to 0 to not enable this trigger.
         * This check only raises a warning, not a critical error as there is no
         * certainty that an real error will occur.
         */
        uint32_t threshold = dma_window_ratio_warning_threshold();
        uint32_t ratio = p_trans->size_d1_du / p_trans->win_du;
        if(     p_trans->win_du
            &&  threshold
            &&  ( ratio > threshold) )
        {
            p_trans->flags |= DMA_CONFIG_WINDOW_SIZE;
        }

    }

    return p_trans->flags;
}

dma_config_flags_t dma_load_transaction( dma_trans_t *p_trans)
{
    uint8_t channel = p_trans->channel;
    /*
     * CHECK FOR CRITICAL ERRORS
     */

    /*
     * The transaction is not allowed if it contain a critical error.
     * A successful transaction creation has to be done before loading it to
     * the DMA.
     */
    if( p_trans->flags & DMA_CONFIG_CRITICAL_ERROR )
    {
        dma_subsys_per[channel].trans = NULL;
        return DMA_CONFIG_CRITICAL_ERROR;
    }

    /*
     * CHECK IF THERE IS A TRANSACTION RUNNING
     */

    /*
     * Modifying the DMA registers during the execution of a transaction can be
     * dangerous.
     * This is prevented by blocking any modification of the current transaction
     * until it has ended.
     * Transactions can still be validated in the meantime.
     */
    if( !dma_is_ready(channel) )
    {
        return DMA_CONFIG_TRANS_OVERRIDE;
    }

    /* Save the current transaction */
    dma_subsys_per[channel].trans = p_trans;

    /*
     * ENABLE/DISABLE INTERRUPTS
     */

    /*
     * If the selected end event is polling, interrupts are disabled.
     * Otherwise the mie.MEIE bit is set to one to enable machine-level
     * fast DMA interrupt.
     */
    dma_subsys_per[channel].peri->INTERRUPT_EN = INTR_EN_NONE;
    CSR_CLEAR_BITS(CSR_REG_MIE, DMA_DONE_CSR_REG_MIE_MASK );
    CSR_CLEAR_BITS(CSR_REG_MIE, DMA_WINDOW_CSR_REG_MIE_MASK );

    if( dma_subsys_per[channel].trans->end != DMA_TRANS_END_POLLING )
    {
        /* Enable global interrupt. */
        CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
        /* Enable machine-level fast interrupt. */
        CSR_SET_BITS(CSR_REG_MIE, DMA_DONE_CSR_REG_MIE_MASK );
        CSR_SET_BITS(CSR_REG_MIE, DMA_WINDOW_CSR_REG_MIE_MASK );

        /* Enable the transaction interrupt for the channel by setting the corresponding bit in Transaction IFR */
        write_register(  
                        0x1,
                        DMA_INTERRUPT_EN_REG_OFFSET,
                        0xffff,
                        DMA_INTERRUPT_EN_TRANSACTION_DONE_BIT,
                        dma_subsys_per[channel].peri
                    );

        /* Only if a window is used should the window interrupt be set. */
        if( p_trans->win_du > 0 )
        {
            write_register(  
                        0x1,
                        DMA_INTERRUPT_EN_REG_OFFSET,
                        0xffff,
                        DMA_INTERRUPT_EN_WINDOW_DONE_BIT,
                        dma_subsys_per[channel].peri
                    );
        }
    }

    /*
     * SET THE PADDING (If enabled)
     */

    /*
    * In the case of a 1D transaction with padding enabled, the DMA has to be configured to treat
    * the transaction as a 2D one with a second dimension of 1 du and a second dimension increment of 1 du.
    */

    #if DMA_ZERO_PADDING
    if (p_trans->dim == DMA_DIM_CONF_1D && (p_trans->pad_left_du != 0 || p_trans->pad_right_du != 0))
    {
        p_trans->dim = DMA_DIM_CONF_2D;
        /* Set the d2 size and increment to just the minimum */
        p_trans->size_d2_du = 1;
        p_trans->src->inc_d2_du = DMA_DATA_TYPE_2_SIZE( p_trans->dst_type );
        
        write_register( dma_subsys_per[channel].trans->pad_left_du,
                        DMA_PAD_LEFT_REG_OFFSET,
                        DMA_PAD_LEFT_PAD_MASK,
                        DMA_PAD_LEFT_PAD_OFFSET,
                        dma_subsys_per[channel].peri);

        write_register( dma_subsys_per[channel].trans->pad_right_du,
                        DMA_PAD_RIGHT_REG_OFFSET,
                        DMA_PAD_RIGHT_PAD_MASK,
                        DMA_PAD_RIGHT_PAD_OFFSET,
                        dma_subsys_per[channel].peri);
    }
    else if (p_trans->dim == DMA_DIM_CONF_2D)
    {
        write_register( dma_subsys_per[channel].trans->pad_top_du,
                        DMA_PAD_TOP_REG_OFFSET,
                        DMA_PAD_TOP_PAD_MASK,
                        DMA_PAD_TOP_PAD_OFFSET,
                        dma_subsys_per[channel].peri);

        write_register( dma_subsys_per[channel].trans->pad_bottom_du,
                        DMA_PAD_BOTTOM_REG_OFFSET,
                        DMA_PAD_BOTTOM_PAD_MASK,
                        DMA_PAD_BOTTOM_PAD_OFFSET,
                        dma_subsys_per[channel].peri);

        write_register( dma_subsys_per[channel].trans->pad_left_du,
                        DMA_PAD_LEFT_REG_OFFSET,
                        DMA_PAD_LEFT_PAD_MASK,
                        DMA_PAD_LEFT_PAD_OFFSET,
                        dma_subsys_per[channel].peri);

        write_register( dma_subsys_per[channel].trans->pad_right_du,
                        DMA_PAD_RIGHT_REG_OFFSET,
                        DMA_PAD_RIGHT_PAD_MASK,
                        DMA_PAD_RIGHT_PAD_OFFSET,
                        dma_subsys_per[channel].peri);
    }
    #endif

    /*
     * SET THE POINTERS
     */
    dma_subsys_per[channel].peri->SRC_PTR = (uint32_t)dma_subsys_per[channel].trans->src->ptr;

    #if DMA_ADDR_MODE
    if(dma_subsys_per[channel].trans->mode != DMA_TRANS_MODE_ADDRESS)
    {
        /*
        Write to the destination pointers only if we are not in address mode,
        otherwise the destination address is read in a separate port in parallel with the data
        from the address port
        */
        dma_subsys_per[channel].peri->DST_PTR = (uint32_t)dma_subsys_per[channel].trans->dst->ptr;
    }
    else
    {
        dma_subsys_per[channel].peri->ADDR_PTR = (uint32_t)dma_subsys_per[channel].trans->src_addr->ptr;
    }
    #else
    
    dma_subsys_per[channel].peri->DST_PTR = (uint32_t)dma_subsys_per[channel].trans->dst->ptr;
    
    #endif

    /*
     * SET THE TRANSPOSITION MODE
     */

    write_register(dma_subsys_per[channel].trans->dim_inv,
                   DMA_DIM_INV_REG_OFFSET,
                   0x1 << DMA_DIM_INV_SEL_BIT,
                   DMA_DIM_INV_SEL_BIT,
                   dma_subsys_per[channel].peri);

    /*
     * SET THE INCREMENTS
     */

    /*
     * The increments might have been changed (vs. the original value of
     * the target) due to misalignment issues. If they have, use the changed
     * values, otherwise, use the target-specific ones.
     * Other reason to overwrite the target increment is if a trigger is used.
     * In that case, a increment of 0 is necessary.
     * In case of DMA Address mode transaction, the dst pointer is ignored
     * as the values read from the second port are instead used.
     * In case of a 2D DMA transaction, the second dimension increment is set.
     */

    write_register(  get_increment_b_1D( dma_subsys_per[channel].trans->src, channel),
                    DMA_SRC_PTR_INC_D1_REG_OFFSET,
                    DMA_SRC_PTR_INC_D1_INC_MASK,
                    DMA_SRC_PTR_INC_D1_INC_OFFSET,
                    dma_subsys_per[channel].peri);

    if(dma_subsys_per[channel].trans->dim == DMA_DIM_CONF_2D)
    {
        write_register(  get_increment_b_2D( dma_subsys_per[channel].trans->src, channel),
                        DMA_SRC_PTR_INC_D2_REG_OFFSET,
                        DMA_SRC_PTR_INC_D2_INC_MASK,
                        DMA_SRC_PTR_INC_D2_INC_OFFSET,
                        dma_subsys_per[channel].peri );
    }

    #if DMA_ADDR_MODE
    if(dma_subsys_per[channel].trans->mode != DMA_TRANS_MODE_ADDRESS)
    {
        write_register(  get_increment_b_1D( dma_subsys_per[channel].trans->dst, channel),
                        DMA_DST_PTR_INC_D1_REG_OFFSET,
                        DMA_DST_PTR_INC_D1_INC_MASK,
                        DMA_DST_PTR_INC_D1_INC_OFFSET,
                        dma_subsys_per[channel].peri );
        
        if(dma_subsys_per[channel].trans->dim == DMA_DIM_CONF_2D)
        {
            write_register(  get_increment_b_2D( dma_subsys_per[channel].trans->dst, channel),
                        DMA_DST_PTR_INC_D2_REG_OFFSET,
                        DMA_DST_PTR_INC_D2_INC_MASK,
                        DMA_DST_PTR_INC_D2_INC_OFFSET,
                        dma_subsys_per[channel].peri );
        }
    }
    #else 
    write_register(  get_increment_b_1D( dma_subsys_per[channel].trans->dst, channel),
                        DMA_DST_PTR_INC_D1_REG_OFFSET,
                        DMA_DST_PTR_INC_D1_INC_MASK,
                        DMA_DST_PTR_INC_D1_INC_OFFSET,
                        dma_subsys_per[channel].peri );
        
    if(dma_subsys_per[channel].trans->dim == DMA_DIM_CONF_2D)
    {
        write_register(  get_increment_b_2D( dma_subsys_per[channel].trans->dst, channel),
                    DMA_DST_PTR_INC_D2_REG_OFFSET,
                    DMA_DST_PTR_INC_D2_INC_MASK,
                    DMA_DST_PTR_INC_D2_INC_OFFSET,
                    dma_subsys_per[channel].peri );
    }
    #endif

    /*
     * SET THE OPERATION MODE AND WINDOW SIZE
     */

    dma_subsys_per[channel].peri->MODE = dma_subsys_per[channel].trans->mode;
    /* The window size is set to the transaction size if it was set to 0 in
    order to disable the functionality (it will never be triggered). */

    dma_subsys_per[channel].peri->WINDOW_SIZE =   dma_subsys_per[channel].trans->win_du
                            ? dma_subsys_per[channel].trans->win_du
                            : dma_subsys_per[channel].trans->size_d1_du;

    /* 
     * ENABLE THE HW FIFO (IF ENABLED)
     */
    #if DMA_HW_FIFO_MODE
    if( dma_subsys_per[channel].trans->hw_fifo_en == 1)
    {
      write_register(  1,
                    DMA_HW_FIFO_EN_REG_OFFSET,
                    0x1,
                    DMA_HW_FIFO_EN_HW_FIFO_MODE_BIT,
                    dma_subsys_per[channel].peri );
    }
    #endif

    /* 
     * SET THE DIMENSIONALITY
     */
    write_register(  dma_subsys_per[channel].trans->dim,
                    DMA_DIM_CONFIG_REG_OFFSET,
                    0x1,
                    DMA_DIM_CONFIG_DMA_DIM_BIT,
                    dma_subsys_per[channel].peri );

    /*
     * SET THE SIGN EXTENSION BIT
     */
    write_register( dma_subsys_per[channel].trans->sign_ext,
                    DMA_SIGN_EXT_REG_OFFSET,
                    0x1 << DMA_SIGN_EXT_SIGNED_BIT,
                    DMA_SIGN_EXT_SIGNED_BIT,
                    dma_subsys_per[channel].peri  );

    /*
     * SET TRIGGER SLOTS AND DATA TYPE
     */
    write_register(  dma_subsys_per[channel].trans->src->trig,
                    DMA_SLOT_REG_OFFSET,
                    DMA_SLOT_RX_TRIGGER_SLOT_MASK,
                    DMA_SLOT_RX_TRIGGER_SLOT_OFFSET,
                    dma_subsys_per[channel].peri );

    write_register(  dma_subsys_per[channel].trans->dst->trig,
                    DMA_SLOT_REG_OFFSET,
                    DMA_SLOT_TX_TRIGGER_SLOT_MASK,
                    DMA_SLOT_TX_TRIGGER_SLOT_OFFSET,
                    dma_subsys_per[channel].peri );

    write_register(  dma_subsys_per[channel].trans->dst_type,
                    DMA_DST_DATA_TYPE_REG_OFFSET,
                    DMA_DST_DATA_TYPE_DATA_TYPE_MASK,
                    DMA_SELECTION_OFFSET_START,
                    dma_subsys_per[channel].peri  );
    
    write_register(  dma_subsys_per[channel].trans->src_type,
                    DMA_SRC_DATA_TYPE_REG_OFFSET,
                    DMA_SRC_DATA_TYPE_DATA_TYPE_MASK,
                    DMA_SELECTION_OFFSET_START,
                    dma_subsys_per[channel].peri );

    return DMA_CONFIG_OK;
}

dma_config_flags_t dma_launch( dma_trans_t *p_trans)
{
    uint8_t channel = p_trans->channel;

    /*
     * Make sure that the loaded transaction is the intended transaction.
     * If the loaded trans was NULL'd, then this the transaction is never
     * launched.
     */
    if(     ( p_trans == NULL )
        ||  ( dma_subsys_per[channel].trans != p_trans ) ) // @ToDo: Check per-element.
    {
        return DMA_CONFIG_CRITICAL_ERROR;
    }

    /*
     * CHECK IF THERE IS A TRANSACTION RUNNING
     */

    /*
     * Modifying the DMA registers during the execution of a transaction can be
     * dangerous.
     * This is prevented by blocking any modification of the current transaction
     * until it has ended.
     * Transactions can still be validated in the meantime.
     */
    if( !dma_is_ready(channel) )
    {
        return DMA_CONFIG_TRANS_OVERRIDE;
    }

    /*
     * This has to be done prior to writing the register because otherwise
     * the interrupt could arrive before it is lowered.
     */
    dma_subsys_per[channel].intrFlag = 0;

    /* Load the size(s) and start the transaction. */

    if(dma_subsys_per[channel].trans->dim == DMA_DIM_CONF_2D)
    {
        write_register( dma_subsys_per[channel].trans->size_d2_du,
                        DMA_SIZE_D2_REG_OFFSET,
                        DMA_SIZE_D2_SIZE_MASK,
                        DMA_SIZE_D2_SIZE_OFFSET,
                        dma_subsys_per[channel].peri
                      );
    }

    write_register( dma_subsys_per[channel].trans->size_d1_du,
                    DMA_SIZE_D1_REG_OFFSET,
                    DMA_SIZE_D1_SIZE_MASK,
                    DMA_SIZE_D1_SIZE_OFFSET,
                    dma_subsys_per[channel].peri
    ); 
    /*
     * If the end event was set to wait for the interrupt, the dma_launch
     * will not return until the interrupt arrives.
     */

    
    while(    p_trans->end == DMA_TRANS_END_INTR_WAIT
          && ( dma_subsys_per[channel].intrFlag != 0x0 ) ) {
            wait_for_interrupt();
    }

    return DMA_CONFIG_OK;
}

__attribute__((optimize("O0"))) uint32_t dma_is_ready(uint8_t channel)
{
    /* The transaction READY bit is read from the status register*/
    uint32_t ret = ( dma_subsys_per[channel].peri->STATUS & (1<<DMA_STATUS_READY_BIT) );
    return ret;
}
/* @ToDo: Reconsider this decision.
 * In case a return wants to be forced in case of an error, there are 2
 * alternatives:
 *    1) Consider any value != 0 to be a valid 1 using a LOGIC AND:
 *  return ( 1 && dma_subsys_per[channel].peri->DONE );
 *    2) Consider only the LSB == 1 to be a valid 1 using a BITWISE AND.
 *  return ( 1 &  dma_subsys_per[channel].peri->DONE );
 * This would be fixed if the DONE register was a 1 bit field.
 */


uint32_t dma_get_window_count(uint8_t channel)
{
    return dma_subsys_per[channel].peri->WINDOW_COUNT;
}


void dma_stop_circular(uint8_t channel)
{
    /*
     * The DMA finishes the current transaction before and does not start
     * a new one.
     */
    dma_subsys_per[channel].peri->MODE = DMA_TRANS_MODE_SINGLE;
}


__attribute__((weak, optimize("O0"))) void dma_intr_handler_trans_done(uint8_t channel)
{
    /*
     * The DMA transaction has finished!
     * This is a weak implementation.
     * Create your own function called
     * void dma_intr_handler_trans_done()
     * to override this one.
     */
}

__attribute__((weak, optimize("O0"))) void dma_intr_handler_window_done(uint8_t channel)
{
    /*
     * The DMA has copied another window.
     * This is a weak implementation.
     * Create your own function called
     * void dma_intr_handler_window_done()
     * to override this one.
     */
}

__attribute__((weak, optimize("O0"))) uint8_t dma_window_ratio_warning_threshold()
{
    /*
     * This is a weak implementation.
     * Create your own function called
     * void dma_window_ratio_warning_threshold()
     * to override this one.
     * Make it return 0 to disable this warning.
     */
    return DMA_DEFAULT_TRANS_TO_WIND_SIZE_RATIO_THRESHOLD;
}

/****************************************************************************/
/**                                                                        **/
/*                            LOCAL FUNCTIONS                               */
/**                                                                        **/
/****************************************************************************/

dma_config_flags_t validate_target( dma_target_t *p_tgt, dma_trans_t *p_trans )
{
    /* Flags variable to pass encountered errors. */
    dma_config_flags_t flags = DMA_CONFIG_OK;
    /*
     * SANITY CHECKS
     */

    /* Increment can be 0 when a trigger is used. */
    DMA_STATIC_ASSERT( p_tgt->inc_d1_du   >= 0  &&  p_tgt->inc_d1_du < 64 , "Increment not valid");
    /* Increment on D2 has to be 0 for 1D operations */
    DMA_STATIC_ASSERT( p_tgt->inc_d2_du  >= 0  &&  p_tgt->inc_d2_du < 4194304 , "Increment d2 not valid");
    /* The size could be 0 if the target is only going to be used as a
    destination. */
    DMA_STATIC_ASSERT( p_tgt->size_d1_du  >= 0 && p_tgt->size_d1_du  < 65536 , "Size not valid");
    /* The size can be 0 or 1 if the target is involved in a 1D padded transaction */
    DMA_STATIC_ASSERT( p_tgt->size_d2_du >= 0 && p_tgt->size_d1_du  < 65536  , "Size d2 not valid");
    /* The data type must be a valid type */
    DMA_STATIC_ASSERT( p_tgt->type     < DMA_DATA_TYPE__size , "Source type not valid");
    /* The trigger must be among the valid trigger values. */
    DMA_STATIC_ASSERT( p_tgt->trig     < DMA_TRIG__size , "Trigger not valid");
    

    /*
     * INTEGRITY CHECKS
     */

    /*
     * Check if the copy will always be inside the target's environments
     * boundaries.
     * This check is only performed if an environment was set.
     */
    if( p_tgt->env != NULL )
    {
        /* Check if the environment was properly formed.*/
        flags |= validate_environment( p_tgt->env );
        /*
         * Check if the transaction size goes beyond the boundaries of
         * the environment.
         */
        
        if( p_trans->size_d2_du != 0 )
        {
            uint8_t isOutb = is_region_outbound_2D(  p_tgt->ptr,
                                          p_tgt->env->end,
                                          p_tgt->type,
                                          p_trans->size_d1_du,
                                          p_trans->size_d2_du,
                                          p_tgt->inc_d1_du,
                                          p_tgt->inc_d2_du);
            if( isOutb )
            {
                flags |= DMA_CONFIG_OUTBOUNDS;
            }
        } else {
            uint8_t isOutb = is_region_outbound_1D(  p_tgt->ptr,
                                          p_tgt->env->end,
                                          p_tgt->type,
                                          p_trans->size_d1_du,
                                          p_tgt->inc_d1_du );
            if( isOutb )
            {
                flags |= DMA_CONFIG_OUTBOUNDS;
            }
        }

        /* Check if the target starts before the environment starts. */
        uint8_t beforeEnv = ( p_tgt->ptr < p_tgt->env->start );
        /* Check if the target starts after the environment ends. */
        uint8_t afterEnv  = ( p_tgt->ptr > p_tgt->env->end );
        if( beforeEnv || afterEnv )
        {
            flags |= DMA_CONFIG_OUTBOUNDS;
        }
    }

    /*
    * If there is a trigger, there should not be environments
    * nor increments (or it is an incompatible peripheral).
    * Otherwise, an increment is needed (or it is an incompatible
    * memory region).
    */

    if( p_tgt->trig == DMA_TRIG_MEMORY ){ /* If it is a memory region. */
        /* It should have an increment. */
        if( ( p_tgt->inc_d1_du == 0 ) ){
            flags |= DMA_CONFIG_INCOMPATIBLE;
        }
    }
    else /* If it is a peripheral. */
    {
        /* It should not have neither an environment nor an increment. */
        if( (     (p_tgt->env != NULL)
              ||  ( p_tgt->inc_d1_du != 0 ) ) )
        {
            flags |= DMA_CONFIG_INCOMPATIBLE;
        }
    }

    /*
     * This is returned so this function can be called as:
     * if( validate_target == DMA_CONFIG_OK ){ go ahead }
     * or if( validate_target() ){ check for errors }
     */
    return flags;
}

dma_config_flags_t validate_environment( dma_env_t *p_env )
{
    /*
     * SANITY CHECKS
     */
    if( (uint8_t*)p_env->end < (uint8_t*)p_env->start )
    {
        return DMA_CONFIG_INCOMPATIBLE;
    }
    return DMA_CONFIG_OK;
}
/* @ToDo: Prevent validation of targets whose environment was not validated. */

static inline uint8_t get_misalignment_b(   uint8_t         *p_ptr,
                                            dma_data_type_t p_type )
{
    /*
     * Note: These checks only make sense when the target is memory. This is
     * not performed when the target is a peripheral (i.e. uses a trigger).
     * Check for word alignment:
     * The 2 LSBs of the data type must coincide with the 2 LSBs of the SRC
     * pointer.
     * This guarantees word alignment.
     * |____|____|____|____|____|____|____|____|    Memory address 0x*******y
     * 0    1    2    3    4    5    6    7     = y (In bytes)
     *  Byte words can start in any of these positions
     *  Half Words can only start on 0, 2, 4 or 6
     *  Words can only start on 0 or 4
     *  For example, if there was a Word starting on address ended in 2:
     * |____|____|\\\\|\\\\|\\\\|\\\\|____|____|
     * 0    1    2    3    4    5    6    7
     * The DMA could only grab bytes 0-3 and 4-7, so it CANNOT copy into the
     * destination pointer (x) the desired Word as follows:
     * |\\\\|\\\\|\\\\|\\\\|
     * x   x+1  x+2  x+3
     *
     * To overcome this, the ALLOW REALIGN flag is available in the DMA
     * control block.
     * If the user set the ALLOW REALIGN flag, WORD reading from misaligned
     * pointers will be converted to two HALF WORD readings with a HALF WORD
     * increment on both source and destination.
     *
     * HALF WORD misalignment is solved through the same method using two WORD
     * readings.
     *
     */

    uint8_t misalignment = 0;

    /*
     * If the data type is WORD and the two LSBs of pointer are not 00,
     * there is a misalignment.
     */

    if(  p_type == DMA_DATA_TYPE_WORD )
    {
        if( ( (uint32_t)p_ptr & DMA_WORD_ALIGN_MASK )  != 0 )
        {
            misalignment++;
        }
    }

    /*
     * If the data type is WORD or HALF WORD and the LSB of pointer
     * is not 0, there is a misalignment.
     * The inequality is of special importance because WORDs stored in odd
     * pointers need to turn into BYTE as well.
     */
    if( p_type <= DMA_DATA_TYPE_HALF_WORD )
    {
        if( ( (uint32_t)p_ptr & DMA_HALF_WORD_ALIGN_MASK ) != 0 )
        {
            misalignment++;

        }
    }

    /*
     * These two operations will end up with:
     * misalignment == 0 if no realignment is needed.
     * misalignment == 1 if realignment is needed, but switching to half
     * the word size would fix it
     * misalignment == 2 if a WORD is to be read from an odd pointer, so
     * BYTE data type is needed necessarily.
     */
    return misalignment;
}

static inline uint8_t is_region_outbound_1D(   uint8_t  *p_start,
                                            uint8_t  *p_end,
                                            uint32_t p_type,
                                            uint32_t p_size_d1_du,
                                            uint32_t p_inc_d1_du )
{
  /* 000 = A data unit to be copied
   * xxx = A data unit to be skipped
   *
   * v The start               /------------\ The size of each increment
   * |OOOO|xxxx|xxxx|OOOO|xxxx|xxxx| . . . |OOOO|xxxx|xxxx|OOOO|xxxx|xxxx|
   *  \--/ The size of a type
   *  \------------------- Each increment n-1 times ------/
   *                              + 1 word (w/o increment) \--/
   *  \------ All the affected region (rangeSize) ------------/
   *                                   The last affected byte ^
   *
   * If the environment ends before the last affected byte, then there is
   * outbound writing and the function returns 1.
   */
    uint32_t affectedUnits      = ( p_size_d1_du - 1 ) * p_inc_d1_du + 1;
    uint32_t rangeSize          = DMA_DATA_TYPE_2_SIZE(p_type) * affectedUnits;
    uint32_t lastByteInsideRange = (uint32_t)p_start + rangeSize -1;
    return ( p_end < lastByteInsideRange );
    // Size is be guaranteed to be non-zero before calling this function.
}

static inline uint8_t is_region_outbound_2D(   uint8_t  *p_start,
                                            uint8_t  *p_end,
                                            uint32_t p_type,
                                            uint32_t p_size_d1_du,
                                            uint32_t p_size_d2_du,
                                            uint32_t p_inc_d1_du,
                                            uint32_t p_inc_d2_du )
{
  /* 
   * If the environment ends before the last affected byte, then there is
   * outbound writing and the function returns 1.
   */

    uint32_t affectedUnits      = (( p_size_d1_du - 1 ) * p_inc_d1_du + 1) * (p_size_d2_du) + p_inc_d2_du * (p_size_d2_du - 1);
    uint32_t rangeSize          = DMA_DATA_TYPE_2_SIZE(p_type) * affectedUnits;
    uint32_t lastByteInsideRange = (uint32_t)p_start + rangeSize -1;
    return ( p_end < lastByteInsideRange );

    // Size is be guaranteed to be non-zero before calling this function.
}

static inline uint32_t get_increment_b_1D( dma_target_t * p_tgt,
                                           uint8_t        channel)
{
    uint32_t inc_b = 0;
    /* If the target uses a trigger, the increment remains 0. */
    if(  p_tgt->trig  == DMA_TRIG_MEMORY )
    {
        /*
         * If the transaction increment has been overriden (due to
         * misalignments), then that value is used (it's always set to 1).
         */
        inc_b = dma_subsys_per[channel].trans->inc_b;

        /*
        * Otherwise, the target-specific increment is used transformed into
        * bytes).
        */
        if( inc_b == 0 )
        {
            uint8_t dataSize_d1_du = DMA_DATA_TYPE_2_SIZE( p_tgt->type );
            inc_b = ( p_tgt->inc_d1_du * dataSize_d1_du );
        }
    }
    return inc_b;
}

static inline uint32_t get_increment_b_2D( dma_target_t * p_tgt,
                                           uint8_t channel )
{
    uint32_t inc_b = 0;
    /* If the target uses a trigger, the increment remains 0. */
    if(  p_tgt->trig  == DMA_TRIG_MEMORY )
    {
        /*
         * If the transaction increment has been overriden (due to
         * misalignments), then that value is used (it's always set to 1).
         */
        inc_b = dma_subsys_per[channel].trans->inc_b;

        /*
        * Otherwise, the target-specific increment is used transformed into
        * bytes).
        */
        if( inc_b == 0 )
        {
            uint8_t dataSize_d1_du = DMA_DATA_TYPE_2_SIZE( p_tgt->type );
            inc_b = ( p_tgt->inc_d2_du * dataSize_d1_du );
        }
    }
    return inc_b;
}


#ifdef __cplusplus
}
#endif // __cplusplus

/****************************************************************************/
/**                                                                        **/
/*                                 EOF                                      */
/**                                                                        **/
/****************************************************************************/