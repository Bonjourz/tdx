/* SPDX-License-Identifier: GPL-2.0 */
#include <asm/asm-offsets.h>
#include <asm/asm.h>
#include <asm/frame.h>
#include <asm/unwind_hints.h>

#include <linux/linkage.h>
#include <linux/bits.h>
#include <linux/errno.h>

#include "../../virt/vmx/tdx/tdxcall.S"

.section .noinstr.text, "ax"

/*
 * __tdcall()  - Used by TDX guests to request services from the TDX
 * module using TDCALL instruction.
 *
 * __tdcall() function ABI:
 *
 * @fn   (RDI)          - TDCALL Leaf ID, moved to RAX
 * @args (RSI)          - struct tdx_module_args for input
 *
 * Return status of TDCALL via RAX.
 */
SYM_FUNC_START(__tdcall)
	TDX_MODULE_CALL host=0 ret=0 saved=0
SYM_FUNC_END(__tdcall)

/*
 * __tdcall_ret() - Used by TDX guests to request services from the TDX
 * module using TDCALL instruction.
 *
 * __tdcall_ret() function ABI:
 *
 * @fn   (RDI)          - TDCALL Leaf ID, moved to RAX
 * @args (RSI)          - struct tdx_module_args for input and output
 *
 * Return status of TDCALL via RAX.
 */
SYM_FUNC_START(__tdcall_ret)
	TDX_MODULE_CALL host=0 ret=1 saved=0
SYM_FUNC_END(__tdcall_ret)

/*
 * __tdcall_saved() - Used by the TDX guests to request services from the
 * TDX module using TDCALL instruction with additional callee-saved
 * registers as input.
 *
 * __tdcall_saved() function ABI:
 *
 * @fn   (RDI)	- TDCALL leaf ID, moved to RAX
 * @args (RSI)	- struct 'struct tdx_module_args' for input
 *
 * Return the TDCALL return code (RAX)
 */
SYM_FUNC_START(__tdcall_saved)
	TDX_MODULE_CALL host=0 ret=0 saved=1
SYM_FUNC_END(__tdcall_saved)

/*
 * __tdcall_saved_ret() - Used by the TDX guests to request services from the
 * TDX module using TDCALL instruction with additional callee-saved registers
 * as input/output.
 *
 * __tdcall_saved_ret() function ABI:
 *
 * @fn   (RDI)	- TDCALL leaf ID, moved to RAX
 * @args (RDI)	- struct 'struct tdx_module_args' for input and output
 *
 * Return the TDCALL return code (RAX)
 */
SYM_FUNC_START(__tdcall_saved_ret)
	TDX_MODULE_CALL host=0 ret=1 saved=1
SYM_FUNC_END(__tdcall_saved_ret)
