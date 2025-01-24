echo "[Init-Script] start"
# in dir: $PWD"

echo "empty"

#
# before loading data to mm this script is called (first action of simulator)
# can be used to convert data to binary ...
#
# e.g.:
x="224"
y="224"
#convert ../data/input_image.png -resize "$x"x"$y"\> ../data/image_small_crop.png
#python3 ../init/img2bin.py ../data/image_small_crop.png "$x" "$y" ../data/input 2 0

echo "[Init-Script] done"
