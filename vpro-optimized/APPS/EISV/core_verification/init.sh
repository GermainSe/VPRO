#!/bin/bash

git submodule init
git submodule update


cd test_frameworks/riscv-compliance
git checkout 9141cf9274b610d059199e8aa2e21f54a0bc6a6e
cd -



cd test_frameworks/riscv-compliance/riscv-target
rm eisv
ln -s ../../eisv-target eisv
cd -
cd test_frameworks/riscv-compliance/riscv-test-suite/rv32i_m
rm Own
rm VPRO
rm Patara
ln -s ../../../eisv-vpro-tests VPRO
ln -s ../../../eisv-custom-tests Own
ln -s ../../../eisv-patara-tests Patara
cd -

cd test_frameworks/riscv-compliance
git apply --reject --whitespace=fix ../riscv-compliance_vpro.patch
#git apply --reject --whitespace=fix ../0001-EIS-V-changes-to-the-riscv-compliance.patch
#git apply --reject --whitespace=fix ../0001-patara-ref-folder-added.patch
#git apply --reject --whitespace=fix ../0001-makefile-flags-for-16-bit-version-included-TODO-chec.patch
