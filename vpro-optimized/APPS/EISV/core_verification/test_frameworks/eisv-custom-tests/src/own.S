
#include "model_test.h"
#include "arch_test.h"
RVTEST_ISA("RV32I")

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN

#ifdef TEST_CASE_1

RVTEST_CASE(0,"//check ISA:=regex(.*32.*);check ISA:=regex(.*I.*);def TEST_CASE_1=True;",own)

RVTEST_SIGBASE( x2,signature_x2_1)

#
# lw -> branch 
#
inst1:
li	gp, 0x7f000000
li	s8, 0x1
sw	s8, 0(gp)
li	s8, 0
lw	s8, 0(gp)	# load 1
beqz	s8, fail1	# do not branch!
end1:
li	a4, 0x1010	# result data section
li	t2, 0xcafe0001
sw	t2, 0(a4)
j	inst2
fail1:
li	a4, 0x1010	# result data section
li	t2, 0xdead0001
sw	t2, 0(a4)

#
# ex -> sw
#
inst2:
addi	sp,sp,-16
sw	s0,8(sp)
sw	s1,4(sp)
sw	ra,12(sp)
lw	t0,12(sp)
lw	t1,8(sp)
lw	t2,4(sp)
bne	t0, ra, fail2	# dont branch, loaded = stored	ra = x1, t0 = x5
bne	t2, s1, fail2	# dont branch, loaded = stored	s1 = x9, t2 = x7
bne	t1, s0, fail2	# dont branch, loaded = stored	s0 = x8, t1 = x6
j	end2
fail2:
li	a4, 0x1014	# result data section
li	t2, 0xdead0002
sw	t2, 0(a4)
j	inst2a
end2:
addi	sp,sp,16
li	a4, 0x1014	# result data section
li	t2, 0xcafe0002
sw	t2, 0(a4)

inst2a:
addi	sp,sp,-16
sw	s1,4(sp)
sw	s0,8(sp)
sw	ra,12(sp)
lw	t0,12(sp)
lw	t1,8(sp)
lw	t2,4(sp)
bne	t2, s1, fail2a	# dont branch, loaded = stored
j	end2a
fail2a:
li	a4, 0x1018	# result data section
li	t2, 0xdead0003
sw	t2, 0(a4)
j	inst2b
end2a:
addi	sp,sp,16
li	a4, 0x1018	# result data section
li	t2, 0xcafe0003
sw	t2, 0(a4)

inst2b:
addi	sp,sp,-16
sw	s1,4(sp)
sw	s0,8(sp)
sw	ra,12(sp)
lw	t0,12(sp)
lw	t1,8(sp)
lw	t2,4(sp)
bne	t1, s0, fail2b	# dont branch, loaded = stored
j	end2b
fail2b:
li	a4, 0x101c	# result data section
li	t2, 0xdead0004
sw	t2, 0(a4)
j	inst2c
end2b:
addi	sp,sp,16
li	a4, 0x101c	# result data section
li	t2, 0xcafe0004
sw	t2, 0(a4)

inst2c:
addi	sp,sp,-16
sw	s1,4(sp)
sw	s0,8(sp)
sw	ra,12(sp)
lw	t0,12(sp)
lw	t1,8(sp)
lw	t2,4(sp)
bne	t0, ra, fail2c	# dont branch, loaded = stored
j	end2c
fail2c:
li	a4, 0x1020	# result data section
li	t2, 0xdead0005
sw	t2, 0(a4)
j	inst3
end2c:
addi	sp,sp,16
li	a4, 0x1020	# result data section
li	t2, 0xcafe0005
sw	t2, 0(a4)



# TODO

inst3:
j	end3
fail3:
li	a4, 0x1024	# result data section
li	t2, 0xdead0006
sw	t2, 0(a4)
j	finish

end3:
li	a4, 0x1024	# result data section
li	t2, 0xcafe0006
sw	t2, 0(a4)

finish:

#endif

RVTEST_CODE_END
RVMODEL_HALT

RVTEST_DATA_BEGIN
.align 4
rvtest_data:
.word 0xbabecafe
RVTEST_DATA_END

RVMODEL_DATA_BEGIN


signature_x2_0:
    .fill 0*(XLEN/32),4,0xdeadbeef


signature_x2_1:
    .fill 22*(XLEN/32),4,0xdeadbeef


signature_x3_0:
    .fill 512*(XLEN/32),4,0xdeadbeef


signature_x3_1:
    .fill 32*(XLEN/32),4,0xdeadbeef

#ifdef rvtest_mtrap_routine

mtrap_sigptr:
    .fill 64*(XLEN/32),4,0xdeadbeef

#endif

#ifdef rvtest_gpr_save

gpr_save:
    .fill 32*(XLEN/32),4,0xdeadbeef

#endif

RVMODEL_DATA_END
