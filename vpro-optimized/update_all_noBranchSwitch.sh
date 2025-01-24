echo -e "\e[36m[GIT] Fetching: CORES/EISV\e[0m"
cd CORES/EISV/
#git checkout behavioral
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd -

echo -e "\e[36m[GIT] Fetching: CORES/VPRO\e[0m"
cd CORES/VPRO
#git checkout behavioral
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd -




######## Specializations

echo -e "\e[36m[GIT] Fetching: CORES/EISV_Specialization\e[0m"
cd CORES/EISV_Specialization/
#git checkout main
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd -

echo -e "\e[36m[GIT] Fetching: CORES/VPRO_Specialization\e[0m"
cd CORES/VPRO_Specialization/
#git checkout main
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd -

#############################




echo -e "\e[36m[GIT] Fetching: SYS/axi\e[0m"
cd SYS/axi/
#git checkout master
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd -

echo -e "\e[36m[GIT] Fetching: TOOLS/VPRO/ISS\e[0m"
cd TOOLS/VPRO/ISS
#git checkout dev
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd -

echo -e "\e[36m[GIT] Fetching: APPS/EISV/cnn_converter\e[0m"
cd APPS/EISV/cnn_converter/
#git checkout main
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd - 

echo -e "\e[36m[GIT] Fetching: APPS/EISV/nn_quantization\e[0m"
cd APPS/EISV/nn_quantization/
#git checkout main
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd - 

echo -e "\e[36m[GIT] Fetching: APPS/EISV/core_verification\e[0m"
cd APPS/EISV/core_verification/
#git checkout main
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd -

echo -e "\e[36m[GIT] Fetching: ASIC/vpro-refflow-gf-22fdsoi_2_3\e[0m"
cd ASIC/vpro-refflow-gf-22fdsoi_2_3/
#git checkout master
git pull 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd -
