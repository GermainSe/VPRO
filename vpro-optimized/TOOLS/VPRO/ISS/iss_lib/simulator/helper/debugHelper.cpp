// ########################################################
// # VPRO instruction & system simulation library         #
// # Sven Gesper, IMS, Uni Hannover, 2019                 #
// ########################################################
// # debug settings and functions                         #
// ########################################################

#include "debugHelper.h"
#include <stdarg.h>  // For va_start, etc.
#include <memory>    // For std::unique_ptr
#include <string>
#include "../setting.h"

uint64_t debug = 0;

QString debugToText(DebugOptions op) {
    switch (op) {
        case DEBUG_INSTRUCTIONS:
            return {"DEBUG_INSTRUCTIONS"};
        case DEBUG_DMA:
            return {"DEBUG_DMA"};
        case DEBUG_DEV_NULL:
            return {"DEBUG_DEV_NULL"};
        case DEBUG_FIFO_MSG:
            return {"DEBUG_FIFO_MSG"};
        case DEBUG_PRINTF:
            return {"DEBUG_PRINTF"};
        case DEBUG_USER_DUMP:
            return {"DEBUG_USER_DUMP"};
        case DEBUG_INSTR_STATISTICS:
            return {"DEBUG_INSTR_STATISTICS"};
        case DEBUG_MODE:
            return {"DEBUG_USER_DUMP"};
        case DEBUG_TICK:
            return {"DEBUG_TICK"};
        case DEBUG_GLOBAL_TICK:
            return {"DEBUG_GLOBAL_TICK"};
        case DEBUG_INSTRUCTION_SCHEDULING:
            return {"DEBUG_INSTRUCTION_SCHEDULING"};
        case DEBUG_INSTRUCTION_DATA:
            return {"DEBUG_INSTRUCTION_DATA"};
        case DEBUG_PIPELINE:
            return {"DEBUG_PIPELINE"};
        case DEBUG_PIPELINE_9:
            return {"DEBUG_PIPELINE_9"};
        case DEBUG_DMA_DETAIL:
            return {"DEBUG_DMA_DETAIL"};
        case DEBUG_GLOBAL_VARIABLE_CHECK:
            return {"DEBUG_GLOBAL_VARIABLE_CHECK"};
        case DEBUG_CHAINING:
            return {"DEBUG_CHAINING"};
        case DEBUG_DUMP_FLAGS:
            return {"DEBUG_DUMP_FLAGS"};
        case DEBUG_INSTRUCTION_SCHEDULING_BASIC:
            return {"DEBUG_INSTRUCTION_SCHEDULING_BASIC"};
        case DEBUG_INSTR_STATISTICS_ALL:
            return {"DEBUG_INSTR_STATISTICS_ALL"};
        case DEBUG_DMA_ACCESS_TO_EXT_VARIABLE:
            return {"DEBUG_DMA_ACESS_TO_EXT_VARIABLE"};
        case DEBUG_PIPELINELENGTH_CHANGES:
            return {"DEBUG_PIPELINELENGTH_CHANGES"};
        case DEBUG_LANE_STALLS:
            return {"DEBUG_LANE_STALLS"};
        case DEBUG_LOOPER:
            return {"DEBUG_LOOPER"};
        case DEBUG_LOOPER_DETAILED:
            return {"DEBUG_LOOPER_DETAILED"};
        case DEBUG_DMA_DCACHE_ISSUE:
            return {"DEBUG_DMA_DCACHE_ISSUE"};
        case DEBUG_EXT_MEM:
            return {"DEBUG_EXT_MEM"};
        case DEBUG_LANE_ACCU_RESET:
            return {"DEBUG_LANE_ACCU_RESET"};
        case end:
            return {"end"};
        default:
            return "unknown";
    }
}

int printf_warning(const char* format, ...) {
    va_list ap;
    va_start(ap, format);
    printf(ORANGE);
    //    printf("\n");
    vprintf(format, ap);
    //    printf("\n");
    printf(RESET_COLOR);
    va_end(ap);
    if (PAUSE_ON_WARNING_PRINT) {
        printf(ORANGE);
        printf("Press [Enter] to continue...\n");
        getchar();
        printf("execution resumed!\n");
        printf(RESET_COLOR);
    }
    return 0;
}

int printf_error(const char* format, ...) {
    va_list ap;
    va_start(ap, format);
    printf(RED);
    vprintf(format, ap);
    printf(RESET_COLOR);
    va_end(ap);
    if (PAUSE_ON_ERROR_PRINT) {
        printf(ORANGE);
        printf("Press [Enter] to continue...\n");
        getchar();
        printf("execution resumed!\n");
        printf(RESET_COLOR);
    }
    return 0;
}

int printf_failure(const char* format, ...) {
    va_list ap;
    va_start(ap, format);
    printf(RED);
    vprintf(format, ap);
    printf(RESET_COLOR);
    va_end(ap);
    if (PAUSE_ON_ERROR_PRINT) {
        printf(ORANGE);
        printf("Press [Enter] to continue...\n");
        getchar();
        printf("execution resumed!\n");
        printf(RESET_COLOR);
    }
    exit(1);
    return 0;
}

int printf_info(const char* format, ...) {
    va_list ap;
    va_start(ap, format);
    printf(LBLUE);
    vprintf(format, ap);
    printf(RESET_COLOR);
    va_end(ap);
    return 0;
}

int printf_success(const char* format, ...) {
    va_list ap;
    va_start(ap, format);
    printf(LGREEN);
    vprintf(format, ap);
    printf(RESET_COLOR);
    va_end(ap);
    return 0;
}

int printf_success_highlight(const char* format, ...) {
    va_list ap;
    va_start(ap, format);
    printf(BLACK);
    printf(GREENBG);
    printf("##############################################################\n");
    vprintf(format, ap);
    printf("##############################################################");
    printf(RESET_COLOR);
    printf(RESET_BG);
    printf("\n");
    va_end(ap);
    return 0;
}

// ***********************************************************************
// Print Instruction
// ***********************************************************************

void print_cmd(CommandVPRO* cmd) {
    printf("VPRO-Command: ");
    cmd->print();
#if old_print_cmd
    if (cmd->type != CommandVPRO::NONE && cmd->type != CommandVPRO::IDMASK_GLOBAL &&
        cmd->type != CommandVPRO::WAIT_BUSY) {
        printf("\n\t\t details: (x: %i, y: %i) ", cmd->x, cmd->y);
        print_cmd(cmd->vector_unit_sel,
            cmd->vector_lane_sel,
            cmd->blocking,
            cmd->is_chain,
            cmd->fu_sel,
            cmd->func,
            cmd->flag_update,
            cmd->dst,
            cmd->src1,
            cmd->src2,
            cmd->x_end,
            cmd->y_end,
            cmd->id_mask);
    }
#endif
}
void print_cmd(CommandDMA* cmd) {
    printf("DMA-Command: ");
    cmd->print();
}
void print_cmd(CommandBase* cmd) {
    printf("BASE-Command: ");
    cmd->print_class_type();
}

bool if_debug(DebugOptions op) {
    return (debug & op);
}

void ifm_debug(DebugOptions op, const char* msg) {
    if (if_debug(op)) {
        printf("%s", msg);
    }
}
