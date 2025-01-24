//
// Created by gesper on 26.01.23.
//

#ifndef CONV2D_CMD_LOOP_H
#define CONV2D_CMD_LOOP_H

#include "generate_cmds.h"

class CommandLoop{

public:
    CommandLoop(COMMAND *list, uint size): command_list(list), total_commands(size) {

    };

    void execute();

private:
    COMMAND *command_list;
    uint total_commands;
};

#endif //CONV2D_CMD_LOOP_H
