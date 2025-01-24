
config.hex: ${OUT_DIR}/${APP}.readelf ${OUT_DIR}/data/YOLO_config_segments.bin ${OUT_DIR}/data/YOLO_config_weights.bin ${OUT_DIR}/data/input0.bin ${OUT_DIR}/data/input1.bin ${OUT_DIR}/data/input2.bin ${OUT_DIR}/data/YOLO_config_layers.bin
	mkdir -p ${OUT_DIR}/data
	@echo "Converting ${OUT_DIR}/data/input0.bin to ${OUT_DIR}/data/input0.hex"
	@xxd -g 4 -e ${OUT_DIR}/data/input0.bin | cut -d " " -f 2-5 > ${OUT_DIR}/data/input0.hex
	@echo "Converting ${OUT_DIR}/data/input1.bin to ${OUT_DIR}/data/input1.hex"
	@xxd -g 4 -e ${OUT_DIR}/data/input1.bin | cut -d " " -f 2-5 > ${OUT_DIR}/data/input1.hex
	@echo "Converting ${OUT_DIR}/data/input2.bin to ${OUT_DIR}/data/input2.hex"
	@xxd -g 4 -e ${OUT_DIR}/data/input2.bin | cut -d " " -f 2-5 > ${OUT_DIR}/data/input2.hex

	$(eval size0=$(shell echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L0_Segments$$ | awk '{print $$3;}' | sed 's/^0x//g' | tr '[:lower:]' '[:upper:]' `" | bc))
	$(eval size1=$(shell echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L1_Segments$$ | awk '{print $$3;}' | sed 's/^0x//g' | tr '[:lower:]' '[:upper:]' `" | bc))
	$(eval size2=$(shell echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L2_Segments$$ | awk '{print $$3;}' | sed 's/^0x//g' | tr '[:lower:]' '[:upper:]' `" | bc))
	$(eval size3=$(shell echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L3_Segments$$ | awk '{print $$3;}' | sed 's/^0x//g' | tr '[:lower:]' '[:upper:]' `" | bc))
	$(eval size4=$(shell echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L4_Segments$$ | awk '{print $$3;}' | sed 's/^0x//g' | tr '[:lower:]' '[:upper:]' `" | bc))
	$(eval size5=$(shell echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L5_Segments$$ | awk '{print $$3;}' | sed 's/^0x//g' | tr '[:lower:]' '[:upper:]' `" | bc))
	$(eval size6=$(shell echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L6_Segments$$ | awk '{print $$3;}' | sed 's/^0x//g' | tr '[:lower:]' '[:upper:]' `" | bc))
	$(eval start0=0)
	$(eval start1=$(shell echo $$(($(start0)+$(size0)))))
	$(eval start2=$(shell echo $$(($(start1)+$(size1)))))
	$(eval start3=$(shell echo $$(($(start2)+$(size2)))))
	$(eval start4=$(shell echo $$(($(start3)+$(size3)))))
	$(eval start5=$(shell echo $$(($(start4)+$(size4)))))
	$(eval start6=$(shell echo $$(($(start5)+$(size5)))))
	dd skip=${start0} bs=${size0}    if=${OUT_DIR}/data/YOLO_config_segments.bin of=${OUT_DIR}/data/YOLO_config_segments0.bin count=1 iflag=skip_bytes status=none
	dd skip=${start1} bs=${size1}    if=${OUT_DIR}/data/YOLO_config_segments.bin of=${OUT_DIR}/data/YOLO_config_segments1.bin count=1 iflag=skip_bytes status=none
	dd skip=${start2} bs=${size2}    if=${OUT_DIR}/data/YOLO_config_segments.bin of=${OUT_DIR}/data/YOLO_config_segments2.bin count=1 iflag=skip_bytes status=none
	dd skip=${start3} bs=${size3}    if=${OUT_DIR}/data/YOLO_config_segments.bin of=${OUT_DIR}/data/YOLO_config_segments3.bin count=1 iflag=skip_bytes status=none
	dd skip=${start4} bs=${size4}    if=${OUT_DIR}/data/YOLO_config_segments.bin of=${OUT_DIR}/data/YOLO_config_segments4.bin count=1 iflag=skip_bytes status=none
	dd skip=${start5} bs=${size5}    if=${OUT_DIR}/data/YOLO_config_segments.bin of=${OUT_DIR}/data/YOLO_config_segments5.bin count=1 iflag=skip_bytes status=none
	dd skip=${start6} bs=${size6}    if=${OUT_DIR}/data/YOLO_config_segments.bin of=${OUT_DIR}/data/YOLO_config_segments6.bin count=1 iflag=skip_bytes status=none

	$(eval size0=$(shell echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv0$$ | awk '{print $$3;}' | sed 's/^0x//g' | tr '[:lower:]' '[:upper:]' `" | bc))
	$(eval size1=$(shell echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv1$$ | awk '{print $$3;}' | sed 's/^0x//g' | tr '[:lower:]' '[:upper:]' `" | bc))
	$(eval size2=$(shell echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv2$$ | awk '{print $$3;}' | sed 's/^0x//g' | tr '[:lower:]' '[:upper:]' `" | bc))
	$(eval size3=$(shell echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv3$$ | awk '{print $$3;}' | sed 's/^0x//g' | tr '[:lower:]' '[:upper:]' `" | bc))
	$(eval size4=$(shell echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv4$$ | awk '{print $$3;}' | sed 's/^0x//g' | tr '[:lower:]' '[:upper:]' `" | bc))
	$(eval size5=$(shell echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv5$$ | awk '{print $$3;}' | sed 's/^0x//g' | tr '[:lower:]' '[:upper:]' `" | bc))
	$(eval size6=$(shell echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv6$$ | awk '{print $$3;}' | sed 's/^0x//g' | tr '[:lower:]' '[:upper:]' `" | bc))
	$(eval start0=0)
	$(eval start1=$(shell echo $$(($(start0)+$(size0)))))
	$(eval start2=$(shell echo $$(($(start1)+$(size1)))))
	$(eval start3=$(shell echo $$(($(start2)+$(size2)))))
	$(eval start4=$(shell echo $$(($(start3)+$(size3)))))
	$(eval start5=$(shell echo $$(($(start4)+$(size4)))))
	$(eval start6=$(shell echo $$(($(start5)+$(size5)))))
	dd skip=${start0} bs=${size0}    if=${OUT_DIR}/data/YOLO_config_weights.bin of=${OUT_DIR}/data/YOLO_config_weights0.bin count=1 iflag=skip_bytes status=none
	dd skip=${start1} bs=${size1}    if=${OUT_DIR}/data/YOLO_config_weights.bin of=${OUT_DIR}/data/YOLO_config_weights1.bin count=1 iflag=skip_bytes status=none
	dd skip=${start2} bs=${size2}    if=${OUT_DIR}/data/YOLO_config_weights.bin of=${OUT_DIR}/data/YOLO_config_weights2.bin count=1 iflag=skip_bytes status=none
	dd skip=${start3} bs=${size3}    if=${OUT_DIR}/data/YOLO_config_weights.bin of=${OUT_DIR}/data/YOLO_config_weights3.bin count=1 iflag=skip_bytes status=none
	dd skip=${start4} bs=${size4}    if=${OUT_DIR}/data/YOLO_config_weights.bin of=${OUT_DIR}/data/YOLO_config_weights4.bin count=1 iflag=skip_bytes status=none
	dd skip=${start5} bs=${size5}    if=${OUT_DIR}/data/YOLO_config_weights.bin of=${OUT_DIR}/data/YOLO_config_weights5.bin count=1 iflag=skip_bytes status=none
	dd skip=${start6} bs=${size6}    if=${OUT_DIR}/data/YOLO_config_weights.bin of=${OUT_DIR}/data/YOLO_config_weights6.bin count=1 iflag=skip_bytes status=none

	@echo "Converting ${OUT_DIR}/data/YOLO_config_segments.bin to ${OUT_DIR}/data/YOLO_config_segments.hex"
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_segments0.bin | cut -d " " -f 2-5 > ${OUT_DIR}/data/YOLO_config_segments0.hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_segments1.bin | cut -d " " -f 2-5 > ${OUT_DIR}/data/YOLO_config_segments1.hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_segments2.bin | cut -d " " -f 2-5 > ${OUT_DIR}/data/YOLO_config_segments2.hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_segments3.bin | cut -d " " -f 2-5 > ${OUT_DIR}/data/YOLO_config_segments3.hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_segments4.bin | cut -d " " -f 2-5 > ${OUT_DIR}/data/YOLO_config_segments4.hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_segments5.bin | cut -d " " -f 2-5 > ${OUT_DIR}/data/YOLO_config_segments5.hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_segments6.bin | cut -d " " -f 2-5 > ${OUT_DIR}/data/YOLO_config_segments6.hex

	@echo "Converting ${OUT_DIR}/data/YOLO_config_layers.bin to ${OUT_DIR}/data/YOLO_config_layers.hex"
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_layers.bin | cut -d " " -f 2-5 > ${OUT_DIR}/data/YOLO_config_layers.hex

	@echo "Converting ${OUT_DIR}/data/YOLO_config_weights.bin to ${OUT_DIR}/data/YOLO_config_weights.hex"
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_weights0.bin | cut -d " " -f 2-5 > ${OUT_DIR}/data/YOLO_config_weights0.hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_weights1.bin | cut -d " " -f 2-5 > ${OUT_DIR}/data/YOLO_config_weights1.hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_weights2.bin | cut -d " " -f 2-5 > ${OUT_DIR}/data/YOLO_config_weights2.hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_weights3.bin | cut -d " " -f 2-5 > ${OUT_DIR}/data/YOLO_config_weights3.hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_weights4.bin | cut -d " " -f 2-5 > ${OUT_DIR}/data/YOLO_config_weights4.hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_weights5.bin | cut -d " " -f 2-5 > ${OUT_DIR}/data/YOLO_config_weights5.hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_weights6.bin | cut -d " " -f 2-5 > ${OUT_DIR}/data/YOLO_config_weights6.hex

config.32hex: config.hex
	@xxd -g 4 -e ${OUT_DIR}/data/input0.bin | cut -d " " -f 2-5 | sed 's/ /\n/g' > ${OUT_DIR}/data/input0.32hex
	@xxd -g 4 -e ${OUT_DIR}/data/input1.bin | cut -d " " -f 2-5 | sed 's/ /\n/g' > ${OUT_DIR}/data/input1.32hex
	@xxd -g 4 -e ${OUT_DIR}/data/input2.bin | cut -d " " -f 2-5 | sed 's/ /\n/g' > ${OUT_DIR}/data/input2.32hex

	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_segments0.bin | cut -d " " -f 2-5 | sed 's/ /\n/g' > ${OUT_DIR}/data/YOLO_config_segments0.32hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_segments1.bin | cut -d " " -f 2-5 | sed 's/ /\n/g' > ${OUT_DIR}/data/YOLO_config_segments1.32hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_segments2.bin | cut -d " " -f 2-5 | sed 's/ /\n/g' > ${OUT_DIR}/data/YOLO_config_segments2.32hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_segments3.bin | cut -d " " -f 2-5 | sed 's/ /\n/g' > ${OUT_DIR}/data/YOLO_config_segments3.32hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_segments4.bin | cut -d " " -f 2-5 | sed 's/ /\n/g' > ${OUT_DIR}/data/YOLO_config_segments4.32hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_segments5.bin | cut -d " " -f 2-5 | sed 's/ /\n/g' > ${OUT_DIR}/data/YOLO_config_segments5.32hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_segments6.bin | cut -d " " -f 2-5 | sed 's/ /\n/g' > ${OUT_DIR}/data/YOLO_config_segments6.32hex

	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_layers.bin | cut -d " " -f 2-5 | sed 's/ /\n/g' > ${OUT_DIR}/data/YOLO_config_layers.32hex

	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_weights0.bin | cut -d " " -f 2-5 | sed 's/ /\n/g' > ${OUT_DIR}/data/YOLO_config_weights0.32hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_weights1.bin | cut -d " " -f 2-5 | sed 's/ /\n/g' > ${OUT_DIR}/data/YOLO_config_weights1.32hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_weights2.bin | cut -d " " -f 2-5 | sed 's/ /\n/g' > ${OUT_DIR}/data/YOLO_config_weights2.32hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_weights3.bin | cut -d " " -f 2-5 | sed 's/ /\n/g' > ${OUT_DIR}/data/YOLO_config_weights3.32hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_weights4.bin | cut -d " " -f 2-5 | sed 's/ /\n/g' > ${OUT_DIR}/data/YOLO_config_weights4.32hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_weights5.bin | cut -d " " -f 2-5 | sed 's/ /\n/g' > ${OUT_DIR}/data/YOLO_config_weights5.32hex
	@xxd -g 4 -e ${OUT_DIR}/data/YOLO_config_weights6.bin | cut -d " " -f 2-5 | sed 's/ /\n/g' > ${OUT_DIR}/data/YOLO_config_weights6.32hex

	#@sed 's/ /\n/g' ${OUT_DIR}/data/YOLO_config_segments0.hex > ${OUT_DIR}/data/YOLO_config_segments0.32hex
	#@sed 's/ /\n/g' ${OUT_DIR}/data/YOLO_config_segments1.hex > ${OUT_DIR}/data/YOLO_config_segments1.32hex
	#@sed 's/ /\n/g' ${OUT_DIR}/data/YOLO_config_segments2.hex > ${OUT_DIR}/data/YOLO_config_segments2.32hex
	#@sed 's/ /\n/g' ${OUT_DIR}/data/YOLO_config_segments3.hex > ${OUT_DIR}/data/YOLO_config_segments3.32hex
	#@sed 's/ /\n/g' ${OUT_DIR}/data/YOLO_config_segments4.hex > ${OUT_DIR}/data/YOLO_config_segments4.32hex
	#@sed 's/ /\n/g' ${OUT_DIR}/data/YOLO_config_segments5.hex > ${OUT_DIR}/data/YOLO_config_segments5.32hex
	#@sed 's/ /\n/g' ${OUT_DIR}/data/YOLO_config_segments6.hex > ${OUT_DIR}/data/YOLO_config_segments6.32hex
	
	#@sed 's/ /\n/g' ${OUT_DIR}/data/YOLO_config_weights0.hex > ${OUT_DIR}/data/YOLO_config_weights0.32hex
	#@sed 's/ /\n/g' ${OUT_DIR}/data/YOLO_config_weights1.hex > ${OUT_DIR}/data/YOLO_config_weights1.32hex
	#@sed 's/ /\n/g' ${OUT_DIR}/data/YOLO_config_weights2.hex > ${OUT_DIR}/data/YOLO_config_weights2.32hex
	#@sed 's/ /\n/g' ${OUT_DIR}/data/YOLO_config_weights3.hex > ${OUT_DIR}/data/YOLO_config_weights3.32hex
	#@sed 's/ /\n/g' ${OUT_DIR}/data/YOLO_config_weights4.hex > ${OUT_DIR}/data/YOLO_config_weights4.32hex
	#@sed 's/ /\n/g' ${OUT_DIR}/data/YOLO_config_weights5.hex > ${OUT_DIR}/data/YOLO_config_weights5.32hex
	#@sed 's/ /\n/g' ${OUT_DIR}/data/YOLO_config_weights6.hex > ${OUT_DIR}/data/YOLO_config_weights6.32hex
	
	#@sed 's/ /\n/g' ${OUT_DIR}/data/YOLO_config_layers.hex > ${OUT_DIR}/data/YOLO_config_layers.32hex
	
	#@sed 's/ /\n/g' ${OUT_DIR}/data/input0.hex > ${OUT_DIR}/data/input0.32hex
	#@sed 's/ /\n/g' ${OUT_DIR}/data/input1.hex > ${OUT_DIR}/data/input1.32hex
	#@sed 's/ /\n/g' ${OUT_DIR}/data/input2.hex > ${OUT_DIR}/data/input2.32hex

mm_init_file: config.hex config.32hex
	@echo "${PWD}/${OUT_DIR}/data/input0.hex" > ${OUT_DIR}/main.mm_init
	@echo "285212672" >> ${OUT_DIR}/main.mm_init	# = 0x11000000
	@echo "${PWD}/${OUT_DIR}/data/input1.hex" >> ${OUT_DIR}/main.mm_init
	@echo "285313024" >> ${OUT_DIR}/main.mm_init	# = 0x11018800
	@echo "${PWD}/${OUT_DIR}/data/input2.hex" >> ${OUT_DIR}/main.mm_init
	@echo "285413376" >> ${OUT_DIR}/main.mm_init	# = 0x11031000
	@#
	@echo "${PWD}/${OUT_DIR}/data/YOLO_config_segments0.hex" >> ${OUT_DIR}/main.mm_init
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L0_Segments$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init
	@echo "${PWD}/${OUT_DIR}/data/YOLO_config_segments1.hex" >> ${OUT_DIR}/main.mm_init
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L1_Segments$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init
	@echo "${PWD}/${OUT_DIR}/data/YOLO_config_segments2.hex" >> ${OUT_DIR}/main.mm_init
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L2_Segments$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init
	@echo "${PWD}/${OUT_DIR}/data/YOLO_config_segments3.hex" >> ${OUT_DIR}/main.mm_init
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L3_Segments$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init
	@echo "${PWD}/${OUT_DIR}/data/YOLO_config_segments4.hex" >> ${OUT_DIR}/main.mm_init
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L4_Segments$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init
	@echo "${PWD}/${OUT_DIR}/data/YOLO_config_segments5.hex" >> ${OUT_DIR}/main.mm_init
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L5_Segments$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init
	@echo "${PWD}/${OUT_DIR}/data/YOLO_config_segments6.hex" >> ${OUT_DIR}/main.mm_init
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L6_Segments$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init
	@#
	@echo "${PWD}/${OUT_DIR}/data/YOLO_config_layers.hex" >> ${OUT_DIR}/main.mm_init
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*yolo$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc  | awk '{ print $$0+28; }' >> ${OUT_DIR}/main.mm_init # error due to index offset... this is an array of pointer to those structures - check fix of adding 28 (base modification of yolo struct)
	@#
	@echo "${PWD}/${OUT_DIR}/data/YOLO_config_weights0.hex" >> ${OUT_DIR}/main.mm_init
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv0$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init
	@echo "${PWD}/${OUT_DIR}/data/YOLO_config_weights1.hex" >> ${OUT_DIR}/main.mm_init
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv1$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init
	@echo "${PWD}/${OUT_DIR}/data/YOLO_config_weights2.hex" >> ${OUT_DIR}/main.mm_init
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv2$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init
	@echo "${PWD}/${OUT_DIR}/data/YOLO_config_weights3.hex" >> ${OUT_DIR}/main.mm_init
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv3$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init
	@echo "${PWD}/${OUT_DIR}/data/YOLO_config_weights4.hex" >> ${OUT_DIR}/main.mm_init
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv4$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init
	@echo "${PWD}/${OUT_DIR}/data/YOLO_config_weights5.hex" >> ${OUT_DIR}/main.mm_init
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv5$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init
	@echo "${PWD}/${OUT_DIR}/data/YOLO_config_weights6.hex" >> ${OUT_DIR}/main.mm_init
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv6$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init

	@echo "Generated ${OUT_DIR}/main.mm_init file for (bram) simulation: "
	@cat ${OUT_DIR}/main.mm_init | sed 's/^/  /'
#   -g 4 byte groups (32-bit) for imem word size
#   -e little endian byte order
#   cut removes address and ascii tranlsation


mm_init_file.bin: config.hex
	@echo "input0.bin" > ${OUT_DIR}/main.mm_init.bin
	@echo "285212672" >> ${OUT_DIR}/main.mm_init.bin	# = 0x11000000
	@echo "input1.bin" >> ${OUT_DIR}/main.mm_init.bin
	@echo "285313024" >> ${OUT_DIR}/main.mm_init.bin	# = 0x11018800
	@echo "input2.bin" >> ${OUT_DIR}/main.mm_init.bin
	@echo "285413376" >> ${OUT_DIR}/main.mm_init.bin	# = 0x11031000
	@#
	@echo "YOLO_config_segments0.bin" >> ${OUT_DIR}/main.mm_init.bin
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L0_Segments$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init.bin
	@echo "YOLO_config_segments1.bin" >> ${OUT_DIR}/main.mm_init.bin
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L1_Segments$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init.bin
	@echo "YOLO_config_segments2.bin" >> ${OUT_DIR}/main.mm_init.bin
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L2_Segments$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init.bin
	@echo "YOLO_config_segments3.bin" >> ${OUT_DIR}/main.mm_init.bin
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L3_Segments$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init.bin
	@echo "YOLO_config_segments4.bin" >> ${OUT_DIR}/main.mm_init.bin
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L4_Segments$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init.bin
	@echo "YOLO_config_segments5.bin" >> ${OUT_DIR}/main.mm_init.bin
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L5_Segments$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init.bin
	@echo "YOLO_config_segments6.bin" >> ${OUT_DIR}/main.mm_init.bin
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*L6_Segments$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init.bin
	@#
	@echo "YOLO_config_layers.bin" >> ${OUT_DIR}/main.mm_init.bin
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*yolo$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc  | awk '{ print $$0+28; }' >> ${OUT_DIR}/main.mm_init.bin # error due to index offset... this is an array of pointer to those structures - check fix of adding 28 (base modification of yolo struct)
	@#
	@echo "YOLO_config_weights0.bin" >> ${OUT_DIR}/main.mm_init.bin
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv0$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init.bin
	@echo "YOLO_config_weights1.bin" >> ${OUT_DIR}/main.mm_init.bin
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv1$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init.bin
	@echo "YOLO_config_weights2.bin" >> ${OUT_DIR}/main.mm_init.bin
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv2$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init.bin
	@echo "YOLO_config_weights3.bin" >> ${OUT_DIR}/main.mm_init.bin
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv3$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init.bin
	@echo "YOLO_config_weights4.bin" >> ${OUT_DIR}/main.mm_init.bin
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv4$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init.bin
	@echo "YOLO_config_weights5.bin" >> ${OUT_DIR}/main.mm_init.bin
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv5$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init.bin
	@echo "YOLO_config_weights6.bin" >> ${OUT_DIR}/main.mm_init.bin
	@echo "obase=10; ibase=16; `cat ${OUT_DIR}/${APP}.readelf | grep OBJECT.*conv6$$ | awk '{print $$2;}' | tr '[:lower:]' '[:upper:]' `" | bc >> ${OUT_DIR}/main.mm_init.bin

	@echo "Generated ${OUT_DIR}/main.mm_init.bin file for emulation: "
	@cat ${OUT_DIR}/main.mm_init.bin | sed 's/^/  /'
#   -g 4 byte groups (32-bit) for imem word size
#   -e little endian byte order
#   cut removes address and ascii tranlsation
