/* SPDX-License-Identifier: GPL-2.0 */
#include <asm/asm-offsets.h>
#include <asm/frame.h>
#include <asm/tdx.h>
#include <asm/asm.h>

/*
 * TDCALL and SEAMCALL are supported in Binutils >= 2.36.
 */
#define tdcall		.byte 0x66,0x0f,0x01,0xcc
#define seamcall	.byte 0x66,0x0f,0x01,0xcf

/*
 * TDX_MODULE_CALL - common helper macro for both
 *                 TDCALL and SEAMCALL instructions.
 *
 * TDCALL   - used by TDX guests to make requests to the
 *            TDX module and hypercalls to the VMM.
 * SEAMCALL - used by TDX hosts to make requests to the
 *            TDX module.
 *
 *-------------------------------------------------------------------------
 * TDCALL/SEAMCALL ABI:
 *-------------------------------------------------------------------------
 * Input Registers:
 *
 * RAX                        - TDCALL/SEAMCALL Leaf number.
 * RCX,RDX,RDI,RSI,RBX,R8-R15 - TDCALL/SEAMCALL Leaf specific input registers.
 *
 * Output Registers:
 *
 * RAX                        - TDCALL/SEAMCALL Leaf number.
 * RCX,RDX,RDI,RSI,RBX,R8-R15 - TDCALL/SEAMCALL Leaf specific output registers.
 *
 *-------------------------------------------------------------------------
 *
 * So while the common core (RAX,RCX,RDX,R8-R11) fits nicely in the
 * callee-clobbered registers and even leaves RDI,RSI free to act as a
 * base pointer, some leafs (e.g., VP.ENTER) make a giant mess of things.
 *
 * For simplicity, assume that anything that needs the callee-saved regs
 * also tramples on RDI,RSI.  This isn't strictly true, see for example
 * TDH.EXPORT.MEM.
 */
.macro TDX_MODULE_CALL host:req ret:req saved:req
	FRAME_BEGIN

	/* Move Leaf ID to RAX */
	mov %rdi, %rax

	/* Move other input regs from 'struct tdx_module_args' */
	movq	TDX_MODULE_rcx(%rsi), %rcx
	movq	TDX_MODULE_rdx(%rsi), %rdx
	movq	TDX_MODULE_r8(%rsi), %r8
	movq	TDX_MODULE_r9(%rsi), %r9
	movq	TDX_MODULE_r10(%rsi), %r10
	movq	TDX_MODULE_r11(%rsi), %r11

	.if \saved
	/*
	 * Move additional input regs from the structure.  For simplicity
	 * assume that anything needs the callee-saved regs also tramples
	 * on %rdi/%rsi (see VP.ENTER).
	 */
	/* Save those callee-saved GPRs as mandated by the x86_64 ABI */
	pushq	%rbx
	pushq	%r12
	pushq	%r13
	pushq	%r14
	pushq	%r15

	movq	TDX_MODULE_r12(%rsi), %r12
	movq	TDX_MODULE_r13(%rsi), %r13
	movq	TDX_MODULE_r14(%rsi), %r14
	movq	TDX_MODULE_r15(%rsi), %r15
	movq	TDX_MODULE_rbx(%rsi), %rbx

	.if \ret
	/* Save the structure pointer as %rsi is about to be clobbered */
	pushq	%rsi
	.endif

	movq	TDX_MODULE_rdi(%rsi), %rdi
	/* %rsi needs to be done at last */
	movq	TDX_MODULE_rsi(%rsi), %rsi
	.endif	/* \saved */

	.if \host
1:
	seamcall
	/*
	 * SEAMCALL instruction is essentially a VMExit from VMX root
	 * mode to SEAM VMX root mode.  VMfailInvalid (CF=1) indicates
	 * that the targeted SEAM firmware is not loaded or disabled,
	 * or P-SEAMLDR is busy with another SEAMCALL.  %rax is not
	 * changed in this case.
	 *
	 * Set %rax to TDX_SEAMCALL_VMFAILINVALID for VMfailInvalid.
	 * This value will never be used as actual SEAMCALL error code as
	 * it is from the Reserved status code class.
	 */
	mov $TDX_SEAMCALL_VMFAILINVALID, %rdi
	cmovc %rdi, %rax
2:
	.else
	tdcall
	.endif

	.if \ret
	.if \saved
	/*
	 * Restore the structure from stack to saved the output registers
	 *
	 * In case of VP.ENTER returns due to TDVMCALL, all registers are
	 * valid thus no register can be used as spare to restore the
	 * structure from the stack (see "TDH.VP.ENTER Output Operands
	 * Definition on TDCALL(TDG.VP.VMCALL) Following a TD Entry").
	 * For this case, need to make one register as spare by saving it
	 * to the stack and then manually load the structure pointer to
	 * the spare register.
	 *
	 * Note for other TDCALLs/SEAMCALLs there are spare registers
	 * thus no need for such hack but just use this for all for now.
	 */
	pushq	%rax		/* save the TDCALL/SEAMCALL return code */
	movq	8(%rsp), %rax	/* restore the structure pointer */
	movq	%rsi, TDX_MODULE_rsi(%rax)	/* save %rsi */
	movq	%rax, %rsi	/* use %rsi as structure pointer */
	popq	%rax		/* restore the return code */
	popq	%rsi		/* pop the structure pointer */

	/* Copy additional output regs to the structure  */
	movq %r12, TDX_MODULE_r12(%rsi)
	movq %r13, TDX_MODULE_r13(%rsi)
	movq %r14, TDX_MODULE_r14(%rsi)
	movq %r15, TDX_MODULE_r15(%rsi)
	movq %rbx, TDX_MODULE_rbx(%rsi)
	movq %rdi, TDX_MODULE_rdi(%rsi)
	.endif	/* \saved */

	/* Copy output regs to the structure */
	movq %rcx, TDX_MODULE_rcx(%rsi)
	movq %rdx, TDX_MODULE_rdx(%rsi)
	movq %r8,  TDX_MODULE_r8(%rsi)
	movq %r9,  TDX_MODULE_r9(%rsi)
	movq %r10, TDX_MODULE_r10(%rsi)
	movq %r11, TDX_MODULE_r11(%rsi)
	.endif	/* \ret */

	.if \saved
	.if \ret
	/*
	 * Clear registers shared by guest for VP.ENTER and VP.VMCALL to
	 * prevent speculative use of values from guest/VMM, including
	 * those are restored from the stack.
	 *
	 * See arch/x86/kvm/vmx/vmenter.S:
	 *
	 * In theory, a L1 cache miss when restoring register from stack
	 * could lead to speculative execution with guest's values.
	 *
	 * Note: RBP/RSP are not used as shared register.  RSI has been
	 * restored already.
	 *
	 * XOR is cheap, thus unconditionally do for all leafs.
	 */
	xorq %rcx, %rcx
	xorq %rdx, %rdx
	xorq %r8,  %r8
	xorq %r9,  %r9
	xorq %r10, %r10
	xorq %r11, %r11
	xorq %r12, %r12
	xorq %r13, %r13
	xorq %r14, %r14
	xorq %r15, %r15
	xorq %rbx, %rbx
	xorq %rdi, %rdi
	.endif	/* \ret */

	/* Restore callee-saved GPRs as mandated by the x86_64 ABI */
	popq	%r15
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbx
	.endif	/* \saved */

	FRAME_END
	RET

	.if \host
3:
	/*
	 * SEAMCALL caused #GP or #UD.  By reaching here %eax contains
	 * the trap number.  Convert the trap number to the TDX error
	 * code by setting TDX_SW_ERROR to the high 32-bits of %rax.
	 *
	 * Note cannot OR TDX_SW_ERROR directly to %rax as OR instruction
	 * only accepts 32-bit immediate at most.
	 */
	movq $TDX_SW_ERROR, %r12
	orq  %r12, %rax
	jmp  2b

	_ASM_EXTABLE_FAULT(1b, 3b)
	.endif	/* \host */
.endm
