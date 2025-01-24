echo "[Init-Script] start"
# in dir: $PWD"
echo "empty - test"

x="224"
y="224"

#convert ../data/image.png -resize "$x"x"$y"\! -quality 100 ../data/image_in.png

#python3 ../init/img2bin.py ../data/image_in.png "$x" "$y" ../data/input 2 0
#python3 ../init/img2bin.py ../data/image_in.png "$x" "$y" ../data/input 2 1
#python3 ../init/img2bin.py ../data/image_in.png "$x" "$y" ../data/input 2 2

#
# the input is written out by load_model.py (in tf_ref folder)!!!!!!!!!!!!!!!!!
#

# cd into tf script dir. no relative call possible... (python import fails)
#RED='\033[0;31m'
#NC='\033[0m' # No Color
#cd ../tf_ref || echo "${RED}Could not cd into Dir: tf_ref!${NC}"
#./activate.sh
#python3 load_model.py -x "$x" -y "$y" -img ../data/image_in.png

# prepare output folder
mkdir -p ../data/simulation_final

echo "[Init-Script] done"
