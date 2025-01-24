//
// Created by gesper on 14.12.23.
//

#include "testsequences/TestSequence.h"
#include <string.h>
#include "constants.h"
#include "instructions/loadstore/loadstore.h"
#include "instructions/loadstore/store.h"

TestSequence::TestSequence(const int reserve) {
    name = "?";
    instructions.reserve(reserve);
    //    printf("TestCase instanziated!\n");
}

void TestSequence::clear(){
//    for (auto &i : instructions){
//        delete i;
//    }
    instructions.clear();
}

void TestSequence::setName(const char * testname){
    this->name = testname;
}

void TestSequence::printInstructions(const char * prefix) {
    int c = 1, max_c = instructions.size();
    for (Instruction* instruction : instructions) {
        printf("%s %i/%i ", prefix, c, max_c);
        if (instruction != nullptr) {
            printf("%s\n", instruction->c_str());
        } else {
            printf("[Nullptr - unimplemented Generic Instr!?]\n");
        }
        c++;
    }
}

bool TestSequence::check() {
    bool valid = true;
    for (Instruction* instruction : instructions) {
        if (instruction == nullptr) {
            valid = false;
        }
    }
    return valid;
}

const char* TestSequence::c_str_all(char *buffer) {
    int j = sprintf(buffer, "Sequence: \n");
    for (Instruction* instruction : instructions) {
        if (instruction != nullptr) {
             j += sprintf(buffer+j, "%s", instruction->c_str());
        } else {
            j += sprintf(buffer+j, "[Nullptr - unimplemented Generic Instr!?]\n");
        }
    }
    return buffer;
}
const char* TestSequence::c_str_vpro(char * buffer){
    int j = sprintf(buffer, "// vpro calls\n");
    char buf[2000];
    for (auto instr : instructions) {
        j += sprintf(buffer+j, "__vpro(%s, %s, %s, FUNC_%s, %s, ",
            print(instr->getLane()),
            instr->getBlocking()?"BLOCKING":"NONBLOCKING",
            instr->getIsChain()?"IS_CHAIN":"NO_CHAIN",
            instr->getInstructionName(),
            instr->getUpdateFlags()?"FLAG_UPDATE":"NO_FLAG_UPDATE");
        instr->getDst()->__c_str_vpro(buf);
        j += sprintf(buffer+j, "%s, ", buf);
        instr->getSrc1()->__c_str_vpro(buf);
        j += sprintf(buffer+j, "%s, ", buf);
        instr->getSrc2()->__c_str_vpro(buf);
        j += sprintf(buffer+j, "%s, ", buf);
        j += sprintf(buffer+j, "%i, %i, %i);\n",
            instr->getXEnd(),
            instr->getYEnd(),
            instr->getZEnd());
    }
    return buffer;
}
const char* TestSequence::c_str_seq_gen(char *buffer){
    int j = sprintf(buffer, "// Sequence...\n");
    char buf[2000];

    j += sprintf(buffer+j, "DefaultConfiurationModes::MAC_INIT_SOURCE = VPRO::MAC_INIT_SOURCE::%s;\n", print(DefaultConfiurationModes::MAC_INIT_SOURCE));
    j += sprintf(buffer+j, "DefaultConfiurationModes::MAC_RESET_MODE = VPRO::MAC_RESET_MODE::%s;\n", print(DefaultConfiurationModes::MAC_RESET_MODE));
    j += sprintf(buffer+j, "DefaultConfiurationModes::MAC_H_BIT_SHIFT = %i;\n", DefaultConfiurationModes::MAC_H_BIT_SHIFT);
    j += sprintf(buffer+j, "DefaultConfiurationModes::MUL_H_BIT_SHIFT = %i;\n", DefaultConfiurationModes::MUL_H_BIT_SHIFT);

    for (auto instr : instructions) {

        // first letter large (default), remaining in lower letters!
        auto n = instr->getInstructionName();
        buf[0] = n[0];
        int i = 1;
        for (char *c = const_cast<char*>(&n[1]); *c != '\0'; ++c) {
            buf[i] = (char)tolower((int)*c);
            i++;
        }
        buf[i] = '\0';

        if (dynamic_cast<LoadStore *>(instr) != nullptr){
            j += sprintf(buffer+j, "seq.append(new %s(/*x*/ %i, /*y*/ %i, /*z*/ %i, \n"
                "\t/*SRC2 Imm*/  %i, \n"
                "\t/*SRC1 O*/ %i, /*SRC1 A*/ %i, /*SRC1 B*/ %i, /*SRC1 G*/ %i",
                buf, //instr->getInstructionName(),
                instr->getXEnd(),
                instr->getYEnd(),
                instr->getZEnd(),
                instr->getSrc2()->getImmediate(),
                instr->getSrc1()->getOffset(),
                instr->getSrc1()->getAlpha(),
                instr->getSrc1()->getBeta(),
                instr->getSrc1()->getGamma()
            );
            auto store = dynamic_cast<Store *>(instr);
            if (store != nullptr){
                j += sprintf(buffer+j,", %s));\n", print(store->getSourceLane()));
            } else {
                j += sprintf(buffer+j,"));\n");
            }
        } else {
            j += sprintf(buffer+j,"seq.append(new %s(%s, /*x*/ %i, /*y*/ %i, /*z*/ %i, \n"
                "\t/*DST*/  Addressing::fromAddr(%i), \n"
                "\t/*SRC1*/ Addressing::fromAddr(%i), \n"
                "\t/*SRC2*/ Addressing::fromAddr(%i), \n"
                "\t/*chain*/ %s, /*update*/ %s, /*blocking*/ %s));\n",
                buf, //instr->getInstructionName(),
                print(instr->getLane()),
                instr->getXEnd(),
                instr->getYEnd(),
                instr->getZEnd(),
                instr->getDst()->getAddress(),
                instr->getSrc1()->getAddress(),
                instr->getSrc2()->getAddress(),
                instr->getIsChain()?"true":"false",
                instr->getUpdateFlags()?"true":"false",
                instr->getBlocking()?"true":"false"
            );
        }
    }
    return buffer;
}

char* TestSequence::c_str(char *buffer, bool includeOpcode, bool includeOperands, bool includeVectorLen) {
    int j;
    j = sprintf(buffer, "Sequence: ");

    // short form of chain (e.g. "[L0->L1]")
    j += sprintf(buffer+j, "[");
    size_t nr = 0;
    j += sprintf(buffer+j, "%10s", name);
    if (includeOpcode){
        j += sprintf(buffer+j, ", ");
        nr = 0;
        for (Instruction* instruction : instructions) {
            j += sprintf(buffer+j, "%s",  instruction->getInstructionName());
            if (nr+1 != instructions.size()){   // not after last
                j += sprintf(buffer+j, "|");
            }
            nr++;
        }
    }
    if (includeOperands){
        j += sprintf(buffer+j, ", ");
        nr = 0;
        for (Instruction* instruction : instructions) {
            char buf[4096];
            instruction->getOperands(buf);
            if (strstr(buf, "IMM") != nullptr){
                j += sprintf(buffer+j, "IMM");
            } else if (strstr(buf, "Chain") != nullptr){
                j += sprintf(buffer+j, "CHAIN");
            } else {
                j += sprintf(buffer+j, "ADDR");
            }
            if (nr+1 != instructions.size()){   // not after last
                j += sprintf(buffer+j, "|");
            }
            nr++;
        }
    }
    if (includeVectorLen){
        j += sprintf(buffer+j, ", ");
        j += sprintf(buffer+j, "x:%i, y:%i, z:%i",
            instructions[0]->getXEnd(), instructions[0]->getYEnd(), instructions[0]->getZEnd());
    }
    j += sprintf(buffer+j, ", #%zu]", instructions.size());

    return buffer;
}
void TestSequence::vproExec() {

    for (Instruction* instr : instructions) {
        (*instr).vproInstruction();
    }

    // TODO split into individual vector instructions (len: 1)
    // TODO split into long generating (len: max) + short receiving (len: 1)
    // TODO reorder (if possible)
}
