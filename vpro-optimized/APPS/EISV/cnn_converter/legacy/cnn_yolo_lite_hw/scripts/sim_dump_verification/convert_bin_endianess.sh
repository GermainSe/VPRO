#!/bin/bash

FILES="bin/*.bin"
for f in $FILES
do
  echo "Processing $f file..."
  # take action on each file. $f store current file name
  objcopy -I binary -O binary --reverse-bytes=4 $f $f.end
  mv $f.end $f
done


FILES="bin/data/*.bin"
for f in $FILES
do
  echo "Processing $f file..."
  # take action on each file. $f store current file name
  #objcopy -I binary -O binary --reverse-bytes=4 $f $f.end
  #mv $f.end $f
done
