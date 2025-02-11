# RISC-V Architecture Test RV32I Makefrag
#
# Copyright (c) 2017, Codasip Ltd.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#      * Redistributions of source code must retain the above copyright
#        notice, this list of conditions and the following disclaimer.
#      * Redistributions in binary form must reproduce the above copyright
#        notice, this list of conditions and the following disclaimer in the
#        documentation and/or other materials provided with the distribution.
#      * Neither the name of the Codasip Ltd. nor the
#        names of its contributors may be used to endorse or promote products
#        derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Codasip Ltd. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Description: Makefrag for RV32I architectural tests

rv32_vpro_sc_tests = \
  INDIRECT_LOAD \
  DMA_FIFO2 \
  DMA_LOOPER \
  FFT \
  LS_LANE0 \
  LS_LANE1 \
  LS_LANE2 \
  LS_LANE3 \
  IDLE \
  NOTHING \
  MIPS_DIV \
  MIPS_LOOP \
  MIPS_FIBONACCI \
  MIPS_VARIABLE_VPRO \
  DMA_VU_1DL_1DE \
  DMA_VU_1DL_1DE_size1 \
  DMA_VU_1DL_2DE \
  DMA_2DE_1DL_1DE \
  DMA_2DE_1DL_2DE \
  DMA_1DE_1DL_1DE \
  DMA_1DE_1DL_2DE \
  DMA_PADDING_ALL_1 \
  DMA_PADDING_ALL_2 \
  DMA_PADDING_L \
  DMA_PADDING_R \
  DMA_PADDING_T \
  DMA_PADDING_B \
  DMA_PADDING_L_STRIDE \
  DMA_PADDING_R_STRIDE \
  DMA_PADDING_T_STRIDE \
  DMA_PADDING_B_STRIDE \
  DMA_PADDING_STRIDE \
  DMA_BROADCAST_LOAD_1D \
  DMA_BROADCAST_LOAD_2D \
  LOADB \
  LOADBS \
  LOADS \
  LOAD \
  STOREA \
  STOREB \
  ADD \
  ADDI \
  SUB \
  SUBI \
  MULL \
  MULH \
  MULHI \
  MULLI \
  MACL \
  MACH \
  MACH_PRE \
  MACL_PRE \
  MULH_NEG \
  MULH_POS \
  MULL_NEG \
  MULL_POS \
  MULH_SHIFT \
  MACH_SHIFT \
  AND \
  NAND \
  NOR \
  OR \
  XNOR \
  XOR \
  ABS \
  MAX \
  MIN \
  SHIFT_AR \
  SHIFT_AR_NEG \
  SHIFT_AR_POS \
  SHIFT_LR \
  MV_MI \
  MV_NZ \
  MV_PL \
  MV_ZE \
  VPRO_COMPLEX_ADRS_EXT \
  VPRO_COMPLEX_ADRS_EXT2 \
  BLOCKING_SIMPLE \
  CHAINING_FLAGS \
  CMD_BROADCAST_UNITS \
  CMD_BROADCAST_LANES \
  CMD_FIFO \
  SIGMOID
  LOADS_Shift_R \ # Works on ISS (device not tested)
  LOADS_Shift_L \ # Works on ISS (device not tested)
  BIT_REVERSAL \ # Works on ISS (device not tested)
  MIN_VECTOR_VAL \ # Works on ISS (device not tested)
  MAX_VECTOR_VAL \ # Works on ISS (device not tested)
  MIN_VECTOR_INDEX \ # Works on ISS (device not tested)
  MAX_VECTOR_INDEX \ # Works on ISS (device not tested)
#  DMA_FIFO \ - ISS Target ToDO

  # complex - long test:
  #DMA_OVERLOAD \


rv32_vpro_tests = $(addsuffix .elf, $(rv32_vpro_sc_tests))

target_tests += $(rv32_vpro_tests)
