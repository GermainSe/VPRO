# EIS-V

## GIT Config (EIS)

- Create empty directory for this repo: `mkdir EISV`
- Initialize Git: `git init`
- Edit Git configuration file: `nano .git/config`
```
[core]
        repositoryformatversion = 0
        filemode = true
        bare = false
        logallrefupdates = true

[remote "eis"]
        url = git@git.eis.tu-bs.de:asip/cores/eisv.git
        fetch = +refs/heads/*:refs/remotes/origin/*
[branch "master"]
        remote = eis
        merge = refs/heads/master

[remote "tu"]
        url = git@git.rz.tu-bs.de:theoretische-informatik/ti/zuse-ki-avf/eisv.git
        fetch = +refs/heads/behavioral:refs/remotes/tu/behavioral
[branch "behavioral"]
        remote = tu
        merge = refs/heads/behavioral
```
- Pull Master (default after init): `git pull`
        - All EIS Branches will be pulled
- Get Behavioral Branch: `git pull tu`

###### Two remotes: **tu** (external) and **eis** (internal)  
Branch **behavioral** is pulled from tu (external: `git checkout behavioral`  
Branch **master** and others are pulled from eis (internal): `git checkout master`  
On branch master, git will automatical push to eis (remote): `git push`  
On branch behavioral, git will automatical push to tu (remote): `git push`  

## RISC-V Specifications
- ISA: RV32IMC
- Stall due to HW Hazards (WB -> MEM, EX -> ID, MEM -> ID). Handled by ID
- Forwarding (available for: WB -> EX, MEM -> EX)
- unconditional Jumps/JAL: penalty of 1 cycle (IF Addr from ID)
- conditional Branches/JALR: penalty of 2 cycle (IF Addr from EX)
- Mult (MULL/MULH/MAC) in EX + MEM Stage
  - 2 cycles, can cause HW-Hazard if data dependent on Mul result. Handled by ID
- Div with multicycle
  - 32 cycles (WIP)

## RTL
VHDL  
Package: eisv  

###### IO-Fabric  
- VPRO Registers
- Counters
- Debug Fifo, Uart
- Simulation Dump / Exit Handling


###### Header
```
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;            -- @suppress "Non-standard package"

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;
```

## Applications
See ASIP/APPS/EISV/common/ ... for compiler, linker-scripts, etc.  
See ASIP/APPS/EISV/core_verification ... for verification applications  
