Local Memory and Register Memory Check
===

> LMyRM

## Desc

This project intents to fill the _Register Memory_ (RM) from 1 to Max of currently 128. While in each _Local Memory_ (LM) the first two entries will be the current cluster id, followed by the current unit id in the next two entries.
__Currently supports Units with 2 lanes (exclude LS)__
When using a lower configuration the RM count might jump when switching Cluster.
This shall help to detect whether the Memory belongs truly to Cluster 2 Unit 3 Lane 1 or to that Unit.

## Build

1. Put path to SIM_LIB and AUX_LIB into there ENV VARS (see lib.cnf.example) | or rename the file to lib.cnf and put the paths there
2. $ mkdir build && cd build # create build dir and change into
3. $ cmake .. # run cmake
4. $ make # compile
5. $ ./LMyRM # execute
