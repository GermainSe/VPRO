echo "[Init-Script] start"
# in dir: $PWD"
echo "converting input Image... "
echo "test_in"
#../../../helper/main_memory_file_generator/img2bin ../data/test_in_layer_0_CNN_Input_0.bmp 224 224 ../data/test_in_layer_0_CNN_Input_0.bin 2
#../../../helper/main_memory_file_generator/img2bin ../data/test_in_layer_0_CNN_Input_1.bmp 224 224 ../data/test_in_layer_0_CNN_Input_1.bin 2
#../../../helper/main_memory_file_generator/img2bin ../data/test_in_layer_0_CNN_Input_2.bmp 224 224 ../data/test_in_layer_0_CNN_Input_2.bin 2

python3 ../../../helper/main_memory_file_generator/img2bin.py ../data/image_small.png 224 224 ../data/input 2 0
python3 ../../../helper/main_memory_file_generator/img2bin.py ../data/image_small.png 224 224 ../data/input 2 1
python3 ../../../helper/main_memory_file_generator/img2bin.py ../data/image_small.png 224 224 ../data/input 2 2
#python3 ../../../helper/main_memory_file_generator/img2bin.py ../data/test_image_in.png 60 60 ../data/test 2 2

echo "[Init-Script] done"
