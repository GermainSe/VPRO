#!/bin/bash

#
# endianess flip the input word (stdin)
#

if [ -t 0 ]; then exit; fi

data=`cat /dev/stdin | od -An -vtx1 | tr -d ' ' | tr -d '\n'`
length=${#data}

i=0
while [ $i -lt $length ]; do
    echo -n -e "\x${data:$[$i+2]:2}"
    echo -n -e "\x${data:$[$i]:2}"
    i=$[$i+4]
done
