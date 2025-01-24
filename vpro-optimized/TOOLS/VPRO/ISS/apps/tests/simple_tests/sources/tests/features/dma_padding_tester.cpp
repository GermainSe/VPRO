//
// Created by gesper on 12.06.20.
//

#include "tests/features/dma_padding_tester.h"

#include <stdint.h>
#include <math.h>

// Intrinsic auxiliary library
#include "core_wrapper.h"
#include "simulator/helper/typeConversion.h"

#include "defines.h"
#include "helper.h"


bool dma_padding_tester::perform_tests() {
    /**
     * Test 1 (region in MM load and pad)
     */
    {
        core_->dcma->reset();
        int length = 1024;
        resetLM(length);
        resetMM(length);

        setMM(0, -1, 512);
        int baseaddr = 100;
        // in mm is a 3x3 region at 0x100
        int width = 3;
        int height = 3;
        setMM(baseaddr, 0x123, width * height);

        printf("prepare done\n");
        int pad_width = 1;
        dma_set_pad_widths(pad_width, pad_width, pad_width, pad_width);
        dma_set_pad_value(0);

        // load 5x5 with 3x3 in middle. adjust base for having 3x3 in middle. adjust stride to use padding on correct mm input
        bool pad_flags[4];
        pad_flags[CommandDMA::PAD::TOP] = true;
        pad_flags[CommandDMA::PAD::RIGHT] = true;
        pad_flags[CommandDMA::PAD::BOTTOM] = true;
        pad_flags[CommandDMA::PAD::LEFT] = true;
        int width_padded = width + int(pad_flags[CommandDMA::PAD::LEFT]) * pad_width +
                           int(pad_flags[CommandDMA::PAD::RIGHT]) * pad_width;
        int height_padded = height + int(pad_flags[CommandDMA::PAD::TOP]) * pad_width +
                            int(pad_flags[CommandDMA::PAD::BOTTOM]) * pad_width;

        for (int cluster = 0; cluster < VPRO_CFG::CLUSTERS; ++cluster) {
            for (int unit = 0; unit < VPRO_CFG::UNITS; ++unit) {
                dma_ext2D_to_loc1D(cluster, baseaddr * 2, LM_BASE_VU(unit) + 0, 1, width_padded, height_padded,
                                   pad_flags);
            }
        }

        printf("waiting for dma to finish\n");
        dma_wait_to_finish(0xffffffff);

        printf("checking lm \n");

        printf("REGION: %i x %i\n", width_padded, height_padded);
        for (int cluster = 0; cluster < VPRO_CFG::CLUSTERS; ++cluster) {
            for (int unit = 0; unit < VPRO_CFG::UNITS; ++unit) {
                VectorUnit *u = core_->getClusters()[cluster]->getUnits()[unit];
                // for all 4 padd
                verifyLM(0, 0, width_padded * pad_width + pad_width, cluster, unit);
                for (int row = 0; row < height; row++) {
                    verifyLM(0x123, 0 + width_padded * pad_width + pad_width + width_padded * row, width, cluster,
                             unit);
                    verifyLM(0, 0 + width_padded * pad_width + pad_width + width + width_padded * row, 2 * pad_width,
                             cluster, unit);
                }
                verifyLM(0, 0 + (height + pad_width) * width_padded, width_padded, cluster, unit);


                for (int y = 0; y < height_padded; y++) {
                    printf_info("Row %i: ", y);
                    for (int x = 0; x < width_padded; x++) {
                        int addr = x + y * width_padded;
                        printf_info("%i ", u->getLocalMemoryData(addr));
                    }
                    printf("\n");
                }
            }
        }
        core_->dcma->flush();
        dma_wait_to_finish(0xffffffff);
    }






    /**
     * Test 2 (region in MM with stride)
     */
    {
        core_->dcma->reset();
        int length = 2048;
        resetLM(length);
        resetMM(length);

        setMM(0, -1, 2048);
        int baseaddr = 0;
        // in mm is a 3x3 region at 0x100
        int width = 8;
        int stride = 2;
        int height = 8;
        for (int h = 0; h < height; h++) {
            setMM(baseaddr + h * (width + stride), 0x123, width);
        }

        printf("prepare done\n");
        int pad_width = 1;
        dma_set_pad_widths(pad_width, pad_width * 2, pad_width, pad_width);   // TWICE in right dir
        dma_set_pad_value(0);

        // load 5x5 with 3x3 in middle. adjust base for having 3x3 in middle. adjust stride to use padding on correct mm input
        bool pad_flags[4];
        pad_flags[CommandDMA::PAD::TOP] = true;
        pad_flags[CommandDMA::PAD::RIGHT] = true;
        pad_flags[CommandDMA::PAD::BOTTOM] = true;
        pad_flags[CommandDMA::PAD::LEFT] = true;
        int width_padded = width + int(pad_flags[CommandDMA::PAD::LEFT]) * pad_width +
                           int(pad_flags[CommandDMA::PAD::RIGHT]) * pad_width * 2;
        int height_padded = height + int(pad_flags[CommandDMA::PAD::TOP]) * pad_width +
                            int(pad_flags[CommandDMA::PAD::BOTTOM]) * pad_width;

        for (int cluster = 0; cluster < VPRO_CFG::CLUSTERS; ++cluster) {
            for (int unit = 0; unit < VPRO_CFG::UNITS; ++unit) {
                dma_ext2D_to_loc1D(cluster, baseaddr * 2, LM_BASE_VU(unit) + 0, stride + 1, width_padded, height_padded,
                                   pad_flags);
            }
        }

        printf("waiting for dma to finish\n");
        dma_wait_to_finish(0xffffffff);

        printf("checking lm \n");

        printf("REGION: %i x %i\n", width_padded, height_padded);
        for (int cluster = 0; cluster < VPRO_CFG::CLUSTERS; ++cluster) {
            for (int unit = 0; unit < VPRO_CFG::UNITS; ++unit) {
                VectorUnit *u = core_->getClusters()[cluster]->getUnits()[unit];

                // for all 4 padd
                verifyLM(0, 0, width_padded * pad_width + pad_width, cluster, unit);
                for (int row = 0; row < height; row++) {
                    verifyLM(0x123, 0 + width_padded * pad_width + pad_width + width_padded * row, width, cluster,
                             unit);
                    verifyLM(0, 0 + width_padded * pad_width + pad_width + width + width_padded * row, 2 * pad_width,
                             cluster,
                             unit);
                }
                verifyLM(0, 0 + (height + pad_width) * width_padded, width_padded, cluster, unit);


                for (int y = 0; y < height_padded; y++) {
                    printf_info("Row %i: ", y);
                    for (int x = 0; x < width_padded; x++) {
                        int addr = x + y * width_padded;
                        printf_info("%i ", u->getLocalMemoryData(addr));
                    }
                    printf("\n");
                }
            }
        }
        core_->dcma->flush();
        dma_wait_to_finish(0xffffffff);
    }

    return true;
}
