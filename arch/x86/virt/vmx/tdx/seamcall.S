/* SPDX-License-Identifier: GPL-2.0 */
#include <linux/linkage.h>
#include <asm/frame.h>

#include "tdxcall.S"

/*
 * __seamcall() - Host-side interface functions to SEAM software
 *                (the P-SEAMLDR or the TDX module).
 *
 * __seamcall() function ABI:
 *
 * @fn   (RDI)  - SEAMCALL Leaf number, moved to RAX
 * @args (RSI)  - struct tdx_module_args for input
 *
 * Return (via RAX) TDX_SEAMCALL_VMFAILINVALID if the SEAMCALL itself
 * fails, or the completion status of the SEAMCALL leaf function.
 */
SYM_FUNC_START(__seamcall)
	TDX_MODULE_CALL host=1 ret=0 saved=0
SYM_FUNC_END(__seamcall)

/*
 * __seamcall_ret() - Host-side interface functions to SEAM software
 *                    (the P-SEAMLDR or the TDX module).
 *
 * __seamcall_ret() function ABI:
 *
 * @fn   (RDI)  - SEAMCALL Leaf number, moved to RAX
 * @args (RSI)  - struct tdx_module_args for input and output
 *
 * Return (via RAX) TDX_SEAMCALL_VMFAILINVALID if the SEAMCALL itself
 * fails, or the completion status of the SEAMCALL leaf function.
 */
SYM_FUNC_START(__seamcall_ret)
	TDX_MODULE_CALL host=1 ret=1 saved=0
SYM_FUNC_END(__seamcall_ret)

/*
 * __seamcall_saved_ret() - Host-side interface functions to SEAM software
 *                          (the P-SEAMLDR or the TDX module) with extra
 *                          "callee-saved" registers as input/output.
 *
 * __seamcall_saved_ret() function ABI:
 *
 * @fn   (RDI)          - SEAMCALL Leaf number, moved to RAX
 * @args (RSI)          - struct tdx_module_args for input and output
 *
 * Return (via RAX) TDX_SEAMCALL_VMFAILINVALID if the SEAMCALL itself
 * fails, or the completion status of the SEAMCALL leaf function.
 */
SYM_FUNC_START(__seamcall_saved_ret)
	TDX_MODULE_CALL host=1 ret=1 saved=0
SYM_FUNC_END(__seamcall_saved_ret)
