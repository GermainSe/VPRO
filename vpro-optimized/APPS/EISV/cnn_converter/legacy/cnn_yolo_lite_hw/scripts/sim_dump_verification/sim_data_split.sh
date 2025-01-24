#!/bin/bash


#
# these data are 32-bit dump'ed with endianess as host (not fpga)
#

# Folder of Data:
data_input_path=sim_data
# Sim Dump file:
input_dump=${data_input_path}/ramdump.bin

echo -e "############################################################################"
echo -e " Split MM Dump (start @ input data, channel 0 to Input & Layer Output files"
echo -e "  (Dump: ${input_dump}, Host-Endianess)"
echo -e "  (Data: ${data_input_path}, RV/AXI/ARM-Endianess)"
echo -e "############################################################################"

echo "    Input extraction..."
size=$((224*224*2*3))
skip=0
head -c "$((skip + size))" ${input_dump} | tail -c "$((size))" > ${data_input_path}/input.bin.dump.tmp
hexdump -v -e '1/4 "%08x"' -e '"\n"' ${data_input_path}/input.bin.dump.tmp | xxd -r -p > ${data_input_path}/input.bin.dump
#dd if=${data_input_path}/input.bin.dump.tmp of=${data_input_path}/input.bin.dump conv=swab status=none
echo "[Info] Created ${data_input_path}/input.bin.dump"
skip=$((skip + size))

dim=(112 56 28 14 7 7 7)
in=(3 16 32 64 128 128 256)
out=(16 32 64 128 128 256 125)
for layer in {0..6} 
do
	dim_=${dim[${layer}]}
	in_=${in[${layer}]}
	out_=${out[${layer}]}
	size=$((dim_*dim_*2*out_))
	echo "    Layer extraction... [Layer $layer, $dim_ x $dim_, $in_ -> $out_, size: $size Byte]"
	
	
	minimumsize=$((size + skip))
	actualsize=$(wc -c <"$input_dump")
	if [ $actualsize -lt $minimumsize ]; then
	    echo "[ERROR] Size is under $minimumsize bytes"
	    exit 1
	fi
	
	head -c "$((skip + size))" ${input_dump} | tail -c "$((size))" > ${data_input_path}/layer_${layer}.bin.dump.tmp
	hexdump -v -e '1/4 "%08x"' -e '"\n"' ${data_input_path}/layer_${layer}.bin.dump.tmp | xxd -r -p > ${data_input_path}/layer_${layer}.bin.dump
	#dd if=${data_input_path}/layer_${layer}.bin.dump.tmp of=${data_input_path}/layer_${layer}.bin.dump conv=swab status=none
	skip=$((skip + size))
	
	echo "[Info] Created ${data_input_path}/layer_${layer}.bin.dump"
done

rm ${data_input_path}/*.tmp

