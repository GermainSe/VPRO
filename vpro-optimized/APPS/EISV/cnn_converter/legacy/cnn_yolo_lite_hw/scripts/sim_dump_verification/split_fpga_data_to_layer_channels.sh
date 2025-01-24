#!/bin/bash


#data_input_path=fpga_data
data_input_path=sim_data

echo -e "############################################################################"
echo -e " Split Layer/Input Blob (binary) to Channel files"
echo -e "  (Dir: ${data_input_path})"
echo -e "############################################################################"

echo "Input Channel generation..."
mkdir -p ${data_input_path}/Layer_0
#dd if=fpga_data/input.bin.dump bs=$((224*224*2)) skip=$((224*224*2*0)) count=1 iflag=skip_bytes status=none > fpga_data/Layer_0/Channel_0.bin
#dd if=fpga_data/input.bin.dump bs=$((224*224*2)) skip=$((224*224*2*1)) count=1 iflag=skip_bytes status=none > fpga_data/Layer_0/Channel_1.bin
#dd if=fpga_data/input.bin.dump bs=$((224*224*2)) skip=$((224*224*2*2)) count=1 iflag=skip_bytes status=none > fpga_data/Layer_0/Channel_2.bin
size=$((224*224*2))
skip=${size}
head -c "$((skip*0 + size))" ${data_input_path}/input.bin.dump | tail -c "$((size))" > ${data_input_path}/Layer_0/Channel_0.bin
head -c "$((skip*1 + size))" ${data_input_path}/input.bin.dump | tail -c "$((size))" > ${data_input_path}/Layer_0/Channel_1.bin
head -c "$((skip*2 + size))" ${data_input_path}/input.bin.dump | tail -c "$((size))" > ${data_input_path}/Layer_0/Channel_2.bin

dim=(112 56 28 14 7 7 7)
in=(3 16 32 64 128 128 256)
out=(16 32 64 128 128 256 125)

for layer in {0..6}
do
	mkdir -p ${data_input_path}/Layer_$((layer + 1))
	echo "Output Channel generation... Folder: Layer_$((layer + 1))"
	dim_=${dim[${layer}]}
	in_=${in[${layer}]}
	out_=${out[${layer}]}
	size=$((dim_*dim_*2))
	skip=${size}
	echo "    [DIM: ${dim_} x ${dim_}, IN:  ${in_} -> OUT: ${out_}]"

	file=${data_input_path}/layer_${layer}.bin.dump
	minimumsize=$((size*out_))
	actualsize=$(wc -c <"$file")
	if [ $actualsize -lt $minimumsize ]; then
	    echo "[ERROR] Size is under $minimumsize bytes"
	    exit 1
	fi

	for (( oc=0; oc < out_; oc++ ))
	do
		head -c "$((skip*oc + size))" ${data_input_path}/layer_${layer}.bin.dump | tail -c "$((size))" > ${data_input_path}/Layer_$((layer + 1))/Channel_${oc}.bin.tmp
		if [ "$?" != "0" ]; then
			echo "copy ERROR"
			exit 1
		fi
		dd if=${data_input_path}/Layer_$((layer + 1))/Channel_${oc}.bin.tmp of=${data_input_path}/Layer_$((layer + 1))/Channel_${oc}.bin conv=swab status=none
		if [ "$?" != "0" ]; then
			echo "endian switch ERROR"
			exit 1
		fi
		rm -f ${data_input_path}/Layer_$((layer + 1))/Channel_${oc}.bin.tmp
		if [ "$?" != "0" ]; then
			echo "remove ERROR"
			exit 1
		fi
	done
done




reference_path=./fpga_data_correct
#../../cnn_yololite/cnn_yolo_lite_hw/data/reference_c/binary

echo -e "\n############################################################################"
echo -e " Verifikation"
echo -e "  (Reference: ${reference_path}, Host-Endianess)"
echo -e "  (Data: ${data_input_path}, RV/AXI/ARM-Endianess)"
echo -e "############################################################################"
echo "Checking input..."
for (( oc=0; oc < 3; oc++ ))
do
	dd if=${reference_path}/Layer_0/channel_${oc}.bin conv=swab status=none | diff ${data_input_path}/Layer_0/Channel_${oc}.bin -
	if [ "$?" != "0" ]; then
		echo "ERROR in Input Data Channel $oc"
		echo "    ${data_input_path}/Layer_0/Channel_${oc}.bin"
		echo -e "    ${reference_path}/Layer_0/channel_${oc}.bin \n"
		echo "    Details: "
		echo "        diff <(xxd ${data_input_path}/Layer_0/Channel_${oc}.bin) <(dd if=${reference_path}/Layer_0/channel_${oc}.bin conv=swab status=none | xxd) | less"
		#exit 1
	fi
done

echo "Checking Layers..."
for layer in {0..6}
do
        dim_=${dim[${layer}]}
        in_=${in[${layer}]}
        out_=${out[${layer}]}

	echo "Checking Channels ... Layer ${layer} in $((layer + 1))"
	for (( oc=0; oc < out_; oc++ ))
	do
		diff ${data_input_path}/Layer_$((layer+1))/Channel_${oc}.bin ${reference_path}/Layer_$((layer+1))/channel_${oc}.bin
		if [ "$?" != "0" ]; then
			echo "ERROR:"
			echo "    ${data_input_path}/Layer_$((layer+1))/Channel_${oc}.bin"
			echo -e "    ${reference_path}/Layer_$((layer+1))/channel_${oc}.bin \n"
			echo "    Details: "
			echo "        diff <(xxd ${data_input_path}/Layer_$((layer+1))/Channel_${oc}.bin) <(xxd ${reference_path}/Layer_$((layer+1))/channel_${oc}.bin) | less"
			exit 1
		fi
	done
done
