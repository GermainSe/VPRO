// This file forces "make libnetgen" to compile netgen/*.h (if included in layers.h)

// Why this file?
// -> useful to check if everything under netgen/ compiles without building sth from nets/

// Problem:
// cmake only compiles *.cpp into libnetgen; headers not included in any .cpp will not be compiled
// There is no other .cpp in netgen/ that includes layers.h -> cmake does not compile some header files

#include "layers.h"
#include "base_net.h"
