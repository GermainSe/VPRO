# findFiles
# basedir - the directory to start looking in
# pattern - A pattern, as defined by the glob command, that the files must match
proc findFiles { basedir pattern } {

  # Fix the directory name, this ensures the directory name is in the
  # native format for the platform and contains a final directory seperator
  set basedir [string trimright [file join [file normalize $basedir] { }]]
  set fileList {}

  # Look in the current directory for matching files, -type {f r}
  # means ony readable normal files are looked at, -nocomplain stops
  # an error being thrown if the returned list is empty
  foreach fileName [glob -nocomplain -type {f r} -path $basedir $pattern] {
    lappend fileList $fileName
  }

  # Now look for any sub direcories in the current directory
  foreach dirName [glob -nocomplain -type {d  r} -path $basedir *] {
    # Recusively call the routine on the sub directory and append any
    # new files to the results
    set subDirList [findFiles $dirName $pattern]
    if { [llength $subDirList] > 0 } {
      foreach subDirFile $subDirList {
        lappend fileList $subDirFile
      }
    }
  }
  return $fileList
}

proc start {args} {
  variable operation

  set operation "compile"
  echo $args

  # parse arguments for test number
  foreach arg $args {
    if { [string compare -length 1 $arg "-"] == 0 } {
      if { [string match "-O:*" $arg] == 1 } {
        set operation $arg
        set operation [string range $operation 3 [string length $operation]]
      }
      if { [string match "-T:*" $arg] == 1 } {
	set testname $arg
	set testname [string range $testname 3 [string length $testname]]
      }
    }
  }

  ## start selected operation
  if { [string match "compile" $operation] } {
    sim_compile
  } elseif { [string match "compile-patara" $operation] } {
    sim_compile_patara
  } elseif { [string match "compile-net" $operation] } {
    sim_compile_net
  } elseif { [string match "simulate" $operation] } {
    sim_start_sim $testname
  } elseif { [string match "simulate-patara" $operation] } {
    sim_start_sim_patara $testname
  } elseif { [string match "simulate-net" $operation] } {
    sim_start_sim_net
  } elseif { [string match "clean" $operation] } {
    sim_clean
  }
}

### Compile sources (HDL)
proc sim_compile {} {
  
  # create & map libraries
  puts "-N- create library eisv"
  vlib eisv
  vmap eisv

  # create & map libraries
  puts "-N- create library core_v2pro"
  vlib core_v2pro
  vmap core_v2pro

  puts "-N- create library testbench"
  vlib testbench
  vmap testbench

  # compile source files for library core_v2pro
  puts "-N- compile library eisv"
  # Package
  eval vcom -quiet +cover=bcesfx -work eisv -check_synthesis ../risc-v-core/rtl/package/eisV_pkg.vhd
#  eval vcom -quiet +cover=bcesfx -work eisv -check_synthesis ../risc-v-core/rtl/package/eisV_sys_pkg.vhd

  # compile source files for library core_v2pro
  puts "-N- compile library core_v2pro"
  # Package
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/package/package_datawidths.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/package/package.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/package/package_specializations.vhd
  # Lane
#  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/lane/1024x26_dpram.vhd
#  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/lane/custom_regfile_cg.vhd
#  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/lane/custom_regfile_nocg.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/lane/ls_lane_top.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/lane/address_unit.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/lane/alu.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/lane/bs_unit.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/lane/dsp_unit.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/lane/vector_incrementer.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/lane/lane_top.vhd

  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/fifos/cdc_fifo.vhd
#  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/fifos/cdc_fifo_bram.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/fifos/sync_fifo.vhd
#  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/fifos/sync_fifo_register.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/fifos/cmd_fifo_wrapper.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/fifos/idma_fifo.vhd

  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/localmemory/local_mem.vhd
#  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/localmemory/local_mem_ram_single_port.asic.vhd
#  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/localmemory/local_mem_64bit_wrapper.asic.vhd

  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/unit/cmd_ctrl.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/unit/unit_top.vhd

  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/cluster/idma_localmem_interface.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/cluster/cluster_top.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/cluster/idma.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/cluster/idma_shift_reg_mem.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/cluster/idma_shift_reg.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/cluster/idma_access_counter.vhd

  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/dma_command_gen.vhd

  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/dcma/cache_line_replacer_fifo.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/dcma/dcma_async_mem.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/dcma/dcma_cache_line_access.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/dcma/dcma_controller.vhd
#  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/dcma/dcma_passthrough_mux_axi.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/dcma/dcma_top.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/dcma/dma_crossbar_dma_module.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/dcma/dma_crossbar.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/dcma/ram.vhd
  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/dcma/ram_axi_crossbar.vhd

  eval vcom -quiet +cover=bcesfx -work core_v2pro -check_synthesis rtl/top.vhd

  # compile source files for library testbench
  puts "-N- compile library testbench verilog"
#  eval vlog -quiet -work testbench ./verilog/sst25vf016B_80Mhz_mod.vp
  eval vlog -quiet -work testbench sim/questasim/sim_wrapper.v

  # generate foreign module declaration
  scgenmod -bool -lib testbench -sc_bv sim_wrapper > sim/questasim/sim_wrapper.hh
  
#  foreach fileNameEntry [findFiles "sim/questasim/systemc/" "*.c*"] {
#      puts "-N- eval sccom -work testbench $fileNameEntry"
#      eval sccom -work testbench $fileNameEntry
#  }

  puts "-N- compile library testbench systemc"
  eval sccom -work testbench sim/questasim/main.cc

  eval sccom -link -work testbench
  
}

### Compile sources (HDL)
proc sim_compile_patara {} {
  
  # create & map libraries
  puts "-N- create library socpkg"
  vlib socpkg
  vmap socpkg

  puts "-N- create library kavuaka"
  vlib kavuaka
  vmap kavuaka

  puts "-N- create library top_level"
  vlib top_level
  vmap top_level
  
  puts "-N- create library testbench"
  vlib testbench
  vmap testbench

  # compile source files for library socPkg
  puts "-N- compile library socPkg"
  eval vcom -quiet +cover=bcesfx -work socpkg -check_synthesis rtl/MOAI_PKG/soc_def_pkg.vhd

  # compile source files for library kavuaka
  puts "-N- compile library kavuaka"
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/MOAI_PKG/moai_def_pkg.vhd
  # MOAI_LIB PKG
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/MOAI_PKG/rf_def_pkg.vhd 
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/MOAI_PKG/config_x2_cmmu_def_pkg.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/MOAI_PKG/vu_def_pkg.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/MOAI_PKG/au_def_pkg.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/MOAI_PKG/cmm_def_pkg.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/MOAI_PKG/sru_def_pkg.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/MOAI_PKG/blu_def_pkg.vhd 
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/MOAI_PKG/per_def_pkg.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/MOAI_PKG/mmu_def_pkg.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/MOAI_PKG/cmmu_def_pkg.vhd
  # IF_VECTOR
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/VU_IF/vu_if.vhd
  # DE_VECTOR
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/VU_DE/vu_de_fir.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/VU_DE/vu_de.vhd
  # RA_VECTOR
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/VU_RA/vu_ra.vhd
  # RF_VECTOR
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/VU_RF/vu_ra_regs.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/VU_RF/vu_ra_reg_2RF_rf_dummy.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/VU_RF/vu_ra_reg.vhd
  # RFU 
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/RFU1/default.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/RFU2/clx_unit.vhd
  # EX_VECTOR
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/VU_EX/vu_ex_addsub.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/VU_EX/vu_ex_mmu.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/VU_EX/vu_ex_cmmu.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/VU_EX/vu_ex_cmm.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/VU_EX/vu_ex_per.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/VU_EX/vu_ex_shi.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/VU_EX/vu_ex_sru.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/VU_EX/vu_ex_aui.vhd 
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/VU_EX/vu_ex_blu.vhd
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/VU_EX/vu_ex.vhd
  # KAVUAKA
  eval vcom -quiet +cover=bcesfx -work kavuaka -check_synthesis rtl/TOP/kavuaka.vhd
  
#  # compile source files for library control
#  puts "-N- compile library control"
#  eval vcom -quiet -work control -check_synthesis ../rtl/pkg/ctrl.pkg.vhdl
#  eval vcom -quiet -work control -check_synthesis ../rtl/control/adc_ctrl.vhdl
#  eval vcom -quiet -work control -check_synthesis ../rtl/control/dbg_ctrl.vhdl
#  eval vcom -quiet -work control -check_synthesis ../rtl/control/dbg_uart.vhdl
#  eval vcom -quiet -work control -check_synthesis ../rtl/control/dbg_iface.vhdl
  
#  # compile source files for library top_level
#  puts "-N- compile library top_level"
#  eval vlog -quiet -work top_level /opt/ASIClibs/GFlib/22FDSOI/MEMORIES/IN22FDX_S1H_NFRG_W00256B008M16C128/model/verilog/IN22FDX_S1H_NFRG_W00256B008M16C128.v
#  eval vlog -quiet -work top_level /opt/ASIClibs/GFlib/22FDSOI/IO/IN22FDX_GPIO18_9M11S40PI_FE_RELV02R02SZ/model/verilog/IN22FDX_GPIO18_9M11S40PI.v
#  eval vlog -quiet -work top_level /opt/ASIClibs/GFlib/22FDSOI/IO/IN22FDX_GPIO18_LP_INLINE_9M11S_FDK_1.02a/model/verilog/IN22FDX_GPIO18_LP_INLINE.v
#  eval vcom -quiet -work top_level -check_synthesis ../rtl/top_level/nano_top.vhdl
#  eval vcom -quiet -work top_level -check_synthesis ../rtl/top_level/asic_top.gf.vhdl
#  eval vlog -quiet -work top_level ../rtl/top_level/asic_top_pad.v
  
  # compile source files for library testbench
  puts "-N- compile library testbench verilog"
#  eval vlog -quiet -work testbench ./verilog/sst25vf016B_80Mhz_mod.vp
  eval vlog -quiet -work testbench sim/questasim/kavuaka_core/sim_wrapper.v

  # generate foreign module declaration
  scgenmod -bool -lib testbench -sc_bv sim_wrapper > sim/questasim/kavuaka_core/sim_wrapper.hh

  
#  foreach fileNameEntry [findFiles "sim/questasim/systemc/" "*.c*"] {
#      puts "-N- eval sccom -work testbench $fileNameEntry"
#      eval sccom -work testbench $fileNameEntry
#  }

  puts "-N- compile library testbench systemc"
  eval sccom -scv -work testbench sim/questasim/kavuaka_core/main_patara.cc

  eval sccom -link -work testbench
  
}

### Compile sources (NETLIST)
proc sim_compile_net {} {
  
  # create & map libraries
  puts "-N- create library top_level"
  vlib top_level
  vmap top_level
  puts "-N- create library testbench"
  vlib testbench
  vmap testbench
  
  # compile source files for library top_level
  puts "-N- compile library top_level"
  eval vlog -quiet -work top_level /opt/ASIClibs/GFlib/22FDSOI/MEMORIES/IN22FDX_S1H_NFRG_W00256B008M16C128/model/verilog/IN22FDX_S1H_NFRG_W00256B008M16C128.v
  eval vlog -quiet -work top_level /opt/ASIClibs/GFlib/22FDSOI/IO/IN22FDX_GPIO18_9M11S40PI_FE_RELV02R02SZ/model/verilog/IN22FDX_GPIO18_9M11S40PI.v
  eval vlog -quiet -work top_level /opt/ASIClibs/GFlib/22FDSOI/IO/IN22FDX_GPIO18_LP_INLINE_9M11S_FDK_1.02a/model/verilog/IN22FDX_GPIO18_LP_INLINE.v
  eval vlog -quiet -work top_level ./verilog/IN22FDX_GPIO18_LP_INLINE.patch.v
  eval vlog -quiet -work top_level /opt/ASIClibs/GFlib/22FDSOI/LOGIC/GF22FDX_SC8T_116CPP_BASE_DDC28UH_FDK_RELV04R10/model/verilog/prim.v
  eval vlog -quiet -work top_level /opt/ASIClibs/GFlib/22FDSOI/LOGIC/GF22FDX_SC8T_116CPP_BASE_DDC28UH_FDK_RELV04R10/model/verilog/GF22FDX_SC8T_116CPP_BASE_DDC28UH.v
  eval vlog -quiet -work top_level /opt/ASIClibs/GFlib/22FDSOI/LOGIC/GF22FDX_SC8T_116CPP_BASE_DDC32UH_FDK_RELV04R10/model/verilog/GF22FDX_SC8T_116CPP_BASE_DDC32UH.v
  eval vlog -quiet -work top_level /opt/ASIClibs/GFlib/22FDSOI/LOGIC/GF22FDX_SC8T_116CPP_BASE_DDC36UH_FDK_RELV04R10/model/verilog/GF22FDX_SC8T_116CPP_BASE_DDC36UH.v
  eval vlog -quiet -work top_level /opt/ASIClibs/GFlib/22FDSOI/LOGIC/GF22FDX_SC8T_116CPP_HPK_DDC28UH_FDK_RELV03R10/model/verilog/GF22FDX_SC8T_116CPP_HPK_DDC28UH.v
  eval vlog -quiet -work top_level /opt/ASIClibs/GFlib/22FDSOI/LOGIC/GF22FDX_SC8T_116CPP_LPK_DDUH_FDK_RELV04R10/model/verilog/GF22FDX_SC8T_116CPP_LPK_DDUH.v
  eval vlog -quiet -work top_level ../000/cdns_pnr/export2signoff/verilog/asic_top_pad.routed.v
  
  # compile source files for library testbench
  puts "-N- compile library testbench"
  eval vlog -quiet -work testbench ./verilog/sst25vf016B_80Mhz_mod.vp
  eval vlog -quiet -work testbench ./verilog/sim_wrapper.v
  foreach fileNameEntry [findFiles "./systemc" "*.c*"] {
    eval sccom -work testbench $fileNameEntry
  }
  eval sccom -link -work testbench
  
}

### start simulation (HDL)
proc sim_start_sim {testname} {
  
  # run modelsim compile
  sim_compile

  # start simulation
  eval vsim -t ns -lib testbench -L kavuaka -voptargs=+acc +notimingchecks -coverage -permissive kavuaka.kavuaka_core -do {"set StdArithNoWarnings 1; set NumericStdNoWarnings 1"} main

  # save coverage (random testname)
  puts "testname = $testname"
  coverage attribute -name TESTNAME -value $testname
  coverage attribute -test $testname
  coverage save -codeAll -cvg -onexit coverage.ucdb
  
  # initialize flash memory and run the simulation
#  run 1800ns
#  mem load -infile img/nano_imem.mem -format hex /SYSTEM/inst0/flash/memory
#  run -all
#  quit -sim

}

### start simulation (PATARA)
proc sim_start_sim_patara {testname} {
  
  # run modelsim compile
  sim_compile_patara

  # start simulation
  eval vsim -t ns -lib testbench -L kavuaka -voptargs=+acc +notimingchecks -coverage -permissive kavuaka.kavuaka_core -do {"set StdArithNoWarnings 1; set NumericStdNoWarnings 1"} main

  # save coverage (random testname)
  puts "testname = $testname"
  coverage attribute -name TESTNAME -value $testname
  coverage attribute -test $testname
  coverage save -codeAll -cvg -onexit coverage.ucdb
  
  # initialize flash memory and run the simulation
#  run 1800ns
#  mem load -infile img/nano_imem.mem -format hex /SYSTEM/inst0/flash/memory
#  run -all
#  quit -sim
  
}

### start simulation (NETLIST)
proc sim_start_sim_net {} {
  
  # run modelsim compile
  sim_compile_net

  # start simulation
  #eval vsim -t ps -L top_level -voptargs=+acc +notimingchecks -sdfmax "/SYSTEM/inst0/dut/=../000/cdns_pnr/export2signoff/verilog/asic_top_pad.routed.sim.sdf" testbench.SYSTEM
  eval vsim -t ps -L top_level -voptargs=+acc -sdfmax "/SYSTEM/inst0/dut/=../000/cdns_pnr/export2signoff/verilog/asic_top_pad.routed.sim.sdf" testbench.SYSTEM

  # define register values for correct operation
  set siglist [find signals -r trig_ff]
  foreach sig $siglist { force -deposit $sig 1'h0 0 }
  set siglist [find signals -r func_o]
  foreach sig $siglist { force -deposit $sig 56'h00000000000000 0 }

  # initialize flash memory and run the simulation
  run 100ps
  mem load -infile img/nano_imem.mem -format hex /SYSTEM/inst0/flash/memory
  run -all
  quit -sim
  
}

### clean Modelsim project
proc sim_clean {} {
  
  puts "-N- remove library directory eisv"
  file delete -force eisv
  puts "-N- remove library directory core_v2pro"
  file delete -force core_v2pro
  puts "-N- remove library directory testbench"
  file delete -force testbench
  
}
