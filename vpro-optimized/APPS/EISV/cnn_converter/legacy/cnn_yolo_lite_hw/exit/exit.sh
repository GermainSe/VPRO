echo "[Exit-Script] start"
# in dir: $PWD"

#convert ../data/out_0.png ../data/out_1.png ../data/out_2.png ../data/out_3.png +append ../data/row1.png
#convert ../data/out_4.png ../data/out_5.png ../data/out_6.png ../data/out_7.png +append ../data/row2.png
#convert ../data/out_8.png ../data/out_9.png ../data/out_10.png ../data/out_11.png +append ../data/row3.png
#convert ../data/out_12.png ../data/out_13.png ../data/out_14.png +append ../data/row4.png
#convert ../data/row1.png ../data/row2.png ../data/row3.png ../data/row4.png -append ../data/output_ref_all.png
#rm -rf row*.png

RED='\033[0;31m'
NC='\033[0m' # No Color
cd ../tf_ref/cnn_converter_tf_v2/ || echo "${RED}Could not cd into Dir: tf_ref/cnn_converter_tf_v2!${NC}"
source venv/bin/activate
python3 vpro_postprocessing.py -x "$x" -y "$y" -img ../../data/image_in.png
#python3 vpro_postprocessing.py 

#find ../data/out*.png > convert +append ../data/result_out.png
#eog ../data/result_out.png
