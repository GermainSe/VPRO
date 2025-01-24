





.section .text.trap, "ax"
.option norvc
.global vector_table
_trap_start:
	j _trap_exception
	j END_SIMULATION
	j END_SIMULATION
	j END_SIMULATION
	j END_SIMULATION
	j END_SIMULATION
	j END_SIMULATION
	j END_SIMULATION
	j END_SIMULATION
	j END_SIMULATION
	j END_SIMULATION
	j END_SIMULATION
	j END_SIMULATION

_trap_exception:
	csrr	t3, mcause
	li 		t4, 11		# 0xb = CAUSE_MACHINE_ECALL
	fence
	beq 	t3, t4, CONTINUE_SIM	
	j		END_SIMULATION
	
CONTINUE_SIM:
	csrr t0, mepc
	addi t0, t0, 0x4
	csrw mepc, t0
	mret









.section .traphandler, "ax"
trap_vector:
	csrr	t3, mcause
	li 		t4, 11
	fence
	beq 	t3, t4, CONTINUE_SIM
	li	t5,-52
	li  t6, 0xaffedead
	nop
	nop
	nop
	nop
	nop
	nop
	sw	t6,0(t5)
	fence
	ecall
	
	
	
	
	


.section .text.init, "ax"
.global _start

# 0x80: entry point to app (label: _start)
_start:
	j		crt0

# will be 0x84
EXCEPTION_11:
	li	t5,-52
	li  t6, 0xcafedead
	nop
	nop
	nop
	nop
	nop
	nop
	sw	t6,0(t5)
	fence
	ecall
	
crt0:
	csrr	a0, mhartid			# read hardwareid, expect 0
	bnez	a0, END_SIMULATION	# 
	li		a0, -1
	CSRRC	x1, mtvec, a0		# read to x1, clear with mask: -1
	la 		t0, trap_vector
	csrw	mtvec,t0

start2:
	li x1, 0
	li x2, 0
	li x3, 0
	li x4, 0
	li x5, 0
	li x6, 0
	li x7, 0
	li x8, 0
	li x9, 0
	li x10, 0
	li x11, 0
	li x12, 0
	li x13, 0
	li x14, 0
	li x15, 0
	li x16, 0
	li x17, 0
	li x18, 0
	li x19, 0
	li x20, 0
	li x21, 0
	li x22, 0
	li x23, 0
	li x24, 0
	li x25, 0
	li x26, 0
	li x27, 0
	li x28, 0
	li x29, 0
	li x30, 0
	li x31, 0

	ecall
	
	li	t5, -60
	li  t2, 0					
	sw	t2, 0(t5)				# signature dump = 0
	li	t5,-52
	li  t6, 0xcafecafe			# app exit code = 0
	nop
	nop
	nop
	nop
	nop
	nop
	sw	t6,0(t5)
	fence
	li	gp,1
	ecall
		
END_SIMULATION:
	li	t5,-52
	li  t6, 0x0
	nop
	nop
	nop
	nop
	nop
	nop
	sw	t6,0(t5)
	fence
	li	gp,1
	ecall
	

