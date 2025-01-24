//
// Created by gesper on 19.06.20.
//

#include "tests/features/large_y_end.h"

// Intrinsic auxiliary library
#include "core_wrapper.h"
#include "simulator/helper/typeConversion.h"

#include "defines.h"
#include "helper.h"



bool large_y_end::perform_tests(){

    resetRF(1024);

    int xend = 15;
    int yend = 63;
    int alpha = 1;
    int beta = 16;

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

    int length = xend*alpha+yend*beta+1;
    verifyRF(1, 0, 0, length);
    verifyRF(0, 0, length, 1024-length);
    verifyRF(1, 1, 0, length);
    verifyRF(0, 1, length, 1024-length);

    return true;
}
