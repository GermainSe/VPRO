#include "addressing/lane.h"

Lane::Lane(
    LANE id, ChainMemory& own, ChainMemory& ls, ChainMemory& left, ChainMemory& right,
    bool verbose)
    : lane_state(IDLE),
      m_id(id),
      own_chain(own),
      left_chain(left),
      right_chain(right),
      ls_chain(ls),
      verbose(verbose){
    reset();
    if (m_id == L0_1) {
        printf_error("L0_1 cannot be the id of a lane!\n");
        sim_stop();
        exit(-1);
    }
}

void Lane::newInstruction(Instruction* inst) {
    current_instr = inst;
    lane_state = BUSY;
    m_x = 0;
    m_y = 0;
    m_z = 0;
    if (verbose)
        printf("%s new instruction: %s\n", print((LANE)m_id), inst->c_str());
}

/**
 * @brief 
 * 
 * @return true lane has finished.
 * @return false lane has not finished, but is stalled, because of missing/still blocked chained data.
 */
void Lane::iteration(int32_t* rf, int16_t* lm) {
    if (current_instr == nullptr)
        return;

    for (size_t z = 0; z <= current_instr->getZEnd(); z++) {
        for (size_t y = 0; y <= current_instr->getYEnd(); y++) {
            for (size_t x = 0; x <= current_instr->getXEnd(); x++) {

                /**
                 * load previous
                 */
                if (restore_saved_state){
                    x = m_x;
                    y = m_y;
                    z = m_z;
                    restore_saved_state = false;
                }

                if (lane_state == CHAINING_ACTIVE){
                    m_x = x;
                    m_y = y;
                    m_z = z;
                    restore_saved_state = true;
//                    if (verbose)
//                        printf("%s Saved Next: x: %zu, y:%zu, z: %zu\n", print((LANE)m_id), x, y, z);
                    // stop iteration as it had read chaining data -> not valid data in chain fifo until next iteration (other lane will generate new data)
                    lane_state = BUSY;
                    return;
                }
                // check if input chain data available
                if (current_instr->isInputChainStall(ls_chain, left_chain, right_chain)) {
//                    if (verbose)
//                        printf("%s (New) Input Empty. Stall! Next: x: %zu, y:%zu, z: %zu\n", print((LANE)m_id), x, y, z);
                    m_x = x;
                    m_y = y;
                    m_z = z;
                    restore_saved_state = true;
                    // stop iteration as it requires fifo data -> stall this lane
                    lane_state = BUSY_STALLED;
                    return;
                }
                // check if output chain possible
                if (current_instr->getIsChain() && own_chain.isFull()) {
//                    if (verbose)
//                        printf("%s (New) Output Full. Stall!! Next: x: %zu, y:%zu, z: %zu\n", print((LANE)m_id), x, y, z);
                    m_x = x;
                    m_y = y;
                    m_z = z;
                    restore_saved_state = true;
                    // stop iteration as it generates too much fifo data -> stall this lane
                    lane_state = BUSY_STALLED;
                    return;
                }
                lane_state = BUSY;
//                if (verbose)
//                    printf("%s executed: x: %zu, y:%zu, z: %zu\n", print((LANE)m_id), x, y, z);

                // execute this iteration's command
                current_instr->riscvInstruction(rf, lm, x, y, z, m_accu, own_chain, ls_chain, left_chain, right_chain);
                if (current_instr->isInputChain() || current_instr->getIsChain()){  // if read/write to/from chain memory -> let data pass through
                    lane_state = CHAINING_ACTIVE;
//                    if (verbose)
//                        printf("%s Done. fifo accessed! wait for next iteration.\n", print((LANE)m_id));
                }
            }
        }
    }

    // done
    lane_state = IDLE;
    current_instr = nullptr;
}
