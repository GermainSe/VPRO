#!/bin/bash

AC_FILE="ACTIVE"
runs=0
while [ -f "${AC_FILE}" ]
do

echo "executing run $runs"
((runs=runs + 1))
make patara-excessive
mv eisv-patara-tests/coverage/excessive eisv-patara-tests/coverage/excessive-${runs}
sleep 0.2
done
