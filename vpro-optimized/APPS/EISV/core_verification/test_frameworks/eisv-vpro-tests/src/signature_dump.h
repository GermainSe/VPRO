



#ifndef SIGNATURE_DUMP_H
#define SIGNATURE_DUMP_H

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "test_defines.h"

#ifdef SIMULATION
#include <QString>
#include <cstdio>
#include <fstream>
#include <string>
#endif

template<class T>
void dump(volatile T *base, size_t count = NUM_TEST_ENTRIES){

#ifndef SIMULATION
    for (int i = 0; i < count; ++i){
        SIGNATURE_ADDRESS = base[i];
    }
#else    
    QString testname(TEST);
    testname.replace(".cpp",".signature_dump");
    std::string file = DUMP_DIR;
    file += "/" + testname.toStdString();
    FILE* fp = fopen(file.c_str(), "w+");
    if (!fp) {
        perror("File opening failed");
        sim_stop();
        return;
    }
    for (size_t i = 0; i < count; ++i){    	
    	std::fprintf(fp, "%08X\n", base[i]);
    }
    fclose(fp);
    printf("Signature dumped in %s\n", DUMP_DIR);
    sim_stop();
#endif

}
    
    
#endif // SIGNATURE_DUMP_H
