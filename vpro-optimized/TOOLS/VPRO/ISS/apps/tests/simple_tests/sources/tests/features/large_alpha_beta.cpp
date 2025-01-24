//
// Created by gesper on 19.06.20.
//

#include "tests/features/large_alpha_beta.h"

// Intrinsic auxiliary library
#include "core_wrapper.h"
#include "simulator/helper/typeConversion.h"

#include "defines.h"
#include "helper.h"


bool large_alpha_beta::perform_tests(){

    resetRF(1024);

    int xend = 1;
    int yend = 1;
    int alpha = 61;
    int beta = 63;

    printf("Testing: \n\talpha = %i\n\tbeta = %i\n\tx_end = %i\n\ty_end = %i\n", alpha, beta, xend, yend);

    printf("This will test RF addresses: \n");
    int count = 0;
    for(int x = 0; x <= xend; x++){
        for(int y = 0; y <= yend; y++){
            int address = x * alpha + y * beta;
            printf ("%4i, ", address);
            count++;
            if (count % 16 == 0) printf("\n");
            if (count > 100){
                printf("...");
                x = xend;
                y = yend; // skips further prints
            }
        }
    }
    printf(" %i [last], ", xend * alpha + yend * beta);
    printf("Length: %i\n", (xend+1) * (yend+1));

    __vpro(L0_1, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(0, alpha, beta),
                                    SRC1_ADDR(0, alpha, beta),
                                    SRC2_IMM_2D(1),
                                    xend, yend);

    vpro_wait_busy(0xffffffff, 0xffffffff);

    verifyRF(1, 0, 0, 1);
    verifyRF(1, 0, 1*61, 1);
    verifyRF(1, 0, 1*63, 1);
    verifyRF(1, 0, 1*63+1*61, 1);
    verifyRF(0, 1, 1, 60);
    verifyRF(0, 1, 62, 1);
    verifyRF(0, 1, 64, 1*63+1*61-64);
    verifyRF(0, 1, 1*63+1*61+1, 1024-(1*63+1*61+1));

    return true;
}
