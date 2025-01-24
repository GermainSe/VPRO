
#target_branch="vpro1.0"
target_branch="vpro1.0_dev"
#target_branch="dev"


echo -e "\n\nFetching Branch: \e[92m${target_branch}\e[0m\n\n"


echo -e "\e[36m[GIT] Fetching: CORES/EISV\e[0m"
cd CORES/EISV/
git checkout ${target_branch}
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd -

echo -e "\e[36m[GIT] Fetching: CORES/VPRO -> mach_operand_switch!!!!!!!!!!!!!!!!!!\e[0m"
cd CORES/VPRO
git checkout mach_operand_switch
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd -



######## Specializations

echo -e "\e[36m[GIT] Fetching: CORES/EISV_Specialization\e[0m"
cd CORES/EISV_Specialization/
git checkout ${target_branch}
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd -

echo -e "\e[36m[GIT] Fetching: CORES/VPRO_Specialization\e[0m"
cd CORES/VPRO_Specialization/
git checkout ${target_branch}
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd -

#############################




echo -e "\e[36m[GIT] Fetching: SYS/axi\e[0m"
cd SYS/axi/
git checkout ${target_branch}
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd -

echo -e "\e[36m[GIT] Fetching: TOOLS/VPRO/ISS -> mach_operand_switch!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\e[0m"
cd TOOLS/VPRO/ISS
git checkout mach_operand_switch
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd -


########## Softwares


echo -e "\e[36m[GIT] Fetching: APPS/EISV/cnn_converter -> mach_shift_in_kernelLoad_reduced_precisiondirty!!!!!!!!!!!!!!!!!!!!!!!!!!!\e[0m"
cd APPS/EISV/cnn_converter/
git checkout mach_shift_in_kernelLoad_reduced_precisiondirty
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd -

echo -e "\e[36m[GIT] Fetching: APPS/EISV/core_verification\e[0m"
cd APPS/EISV/core_verification/
git checkout ${target_branch}
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd -

echo -e "\e[36m[GIT] Fetching: APPS/EISV/nn_quantization\e[0m"
cd APPS/EISV/nn_quantization/
git checkout ${target_branch}
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd -

########## ASIC


echo -e "\e[36m[GIT] Fetching: ASIC/vpro-refflow-gf-22fdsoi_2_3\e[0m"
cd ASIC/vpro-refflow-gf-22fdsoi_2_3/
git checkout master
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd -
