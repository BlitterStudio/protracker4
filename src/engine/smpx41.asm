; more samples: 32-63 live in a table (smx_Mem), slots 1-31 stay in the
; module. a selected sample > 31 is swapped into slot 31; the replayer
; maps logical numbers to the slot or table entry. file: normal mod, then
; 'PT4X', count, headers, data of the table entries.

SMX_MAX		EQU	63
SMX_N		EQU	SMX_MAX-31	; table entries
SMX_HDR		EQU	0		; 30 b each
SMX_PTR		EQU	SMX_N*30
SMX_LEN		EQU	SMX_PTR+SMX_N*4
SMX_FLG		EQU	SMX_LEN+SMX_N*4	; dyn flag
SMX_FX		EQU	SMX_FLG+SMX_N
SMX_SIZE	EQU	SMX_FX+SMX_N*2

; d2.w logical -> d2.w physical: 1-31 slot, 32-63 table entry + 32
pt_SmxPhys:
	CMP.W	#SMX_MAX,D2
	BLS.S	.a
	MOVEQ	#SMX_MAX,D2
.a:	MOVE.W	smx_Swp,D4
	BEQ.S	.r
	CMP.W	D4,D2
	BNE.S	.b
	MOVEQ	#31,D2
	RTS
.b:	CMP.W	#31,D2
	BNE.S	.r
	MOVE.W	D4,D2
.r:	RTS

; pt_RpReadNote: d2.l = sample (not 0), a3 = module+12, a6 = channel
; -> a1/d2.l start pointer, a3/d4.l length word, chunk flag, physical nr
pt_SmxNote:
	BSR.W	pt_SmxPhys
	CMP.W	#31,D2
	BHI.S	.x
	LEA	dat_RpSampleStarts,A1
	MOVE.L	dat_RpChunkedSamples,D4
	BTST	D2,D4
	SNE	(n_pt4_chunked,A6)
	MOVE.W	D2,D4
	MOVE.B	D2,(n_pt4_samplenum,A6)
	SUBQ.L	#1,D2
	LSL.L	#2,D2
	MULU.W	#s_SIZEOF,D4
	RTS
.x:	MOVE.B	D2,(n_pt4_samplenum,A6)
	IFD	DEBUGAUTO
	ADDQ.W	#1,smx_DbgHit		; notes on table entries (test)
	ENDC
	SUB.W	#32,D2
	MOVE.L	smx_Mem,D4
	BEQ.S	.z
	MOVEA.L	D4,A1
	ADDA.W	#SMX_FLG,A1
	TST.B	(A1,D2.W)
	SNE	(n_pt4_chunked,A6)
	MOVEA.L	D4,A1
	MOVE.W	D2,D4
	MULU.W	#s_SIZEOF,D4
	ADD.L	A1,D4
	LSL.W	#2,D2
	LEA	SMX_PTR(A1),A1
	BRA.S	.h
.z:	SF	(n_pt4_chunked,A6)
	LEA	smx_Zero,A1
	MOVE.L	A1,D4
	LEA	30(A1),A1
	MOVEQ	#0,D2
.h:	ADD.L	#22,D4			; length word of the header
	SUB.L	A3,D4
	RTS

; pt_BuildChunkList: d0.w = physical nr * 4 -> a1 = sample start
pt_SmxChunkPtr:
	CMP.W	#31*4,D0
	BHI.S	.x
	LEA	dat_ModulePtr,A1
	MOVEA.L	(0,A1,D0.W),A1
	RTS
.x:	MOVE.L	D0,-(A7)
	SUB.W	#32*4,D0
	MOVEA.L	smx_Mem,A1
	ADDA.W	#SMX_PTR,A1
	MOVEA.L	(A1,D0.W),A1
	MOVE.L	(A7)+,D0
	RTS

; d0.w logical -> a0 = its header (name), other registers kept
pt_SmxHdr:
	MOVEM.L	D2/D4,-(A7)
	MOVEQ	#0,D2
	MOVE.W	D0,D2
	BSR.W	pt_SmxPhys
	CMP.W	#31,D2
	BHI.S	.x
	MOVEA.L	dat_ModulePtr,A0
	LEA	-10(A0),A0
	MULU	#s_SIZEOF,D2
	ADDA.L	D2,A0
	BRA.S	.r
.x:	SUB.W	#32,D2
	MULU	#s_SIZEOF,D2
	LEA	smx_Zero,A0
	TST.L	smx_Mem
	BEQ.S	.r
	MOVEA.L	smx_Mem,A0
	ADDA.L	D2,A0
.r:	MOVEM.L	(A7)+,D2/D4
	RTS

; info page name edit: d7 = logical -> a6 = header
pt_SmxHdrA6:
	MOVE.L	A0,-(A7)
	CMP.W	#31,D7
	BLS.S	.h
	TST.L	smx_Mem
	BNE.S	.h
	BSR.W	pt_SmxAlloc		; no memory: edits the empty header
.h:	MOVE.W	D7,D0
	BSR.W	pt_SmxHdr
	MOVEA.L	A0,A6
	MOVEA.L	(A7)+,A0
	RTS

; logical current sample
pt_SmxCur:
	MOVE.W	dat_CurrentSample,D0
	CMP.W	#31,D0
	BNE.S	.r
	TST.W	smx_Swp
	BEQ.S	.r
	MOVE.W	smx_Swp,D0
.r:	RTS

; pattern functions: d3 = logical current sample, flags set
pt_SmxCurD3:
	MOVE.L	D0,-(A7)
	BSR.W	pt_SmxCur
	MOVE.W	D0,D3
	MOVE.L	(A7)+,D0
	TST.W	D3
	RTS

; sample gadget display
pt_SmxShow:
	MOVE.L	D0,-(A7)
	BSR.W	pt_SmxCur
	MOVE.W	D0,dat_DisplayParam
	MOVE.L	(A7)+,D0
	RTS

; note entry: d0.l = logical of dat_SamplePlayMode
pt_SmxEntry:
	MOVEQ	#0,D0
	MOVE.W	dat_SamplePlayMode,D0
	CMP.W	#31,D0
	BNE.S	.r
	TST.W	smx_Swp
	BEQ.S	.r
	MOVE.W	smx_Swp,D0
.r:	RTS

; sample gadget up/down
pt_SmxUp:
	BSR.W	pt_SmxCur
	CMP.W	#SMX_MAX,D0
	BCC.S	pt_SmxSel
	ADDQ.W	#1,D0
	BRA.S	pt_SmxSel
pt_SmxDown:
	BSR.W	pt_SmxCur
	CMP.W	#1,D0
	BLS.S	.o
	SUBQ.W	#1,D0
	BRA.S	pt_SmxSel
.o:	MOVEQ	#1,D0
; d0.w = logical 0-63 becomes the current sample
pt_SmxSel:
	MOVEM.L	D0-D2/A0-A1,-(A7)
	MOVE.W	smx_Swp,D1
	BEQ.S	.n
	CMP.W	D1,D0
	BEQ.S	.k			; already in slot 31
	BSR.W	pt_SmxUnswap
.n:	CMP.W	#31,D0
	BLS.S	.s
	TST.L	smx_Mem
	BNE.S	.m
	BSR.W	pt_SmxAlloc
	BEQ.S	.r			; no memory: stay
.m:	BSR.W	pt_SmxSwap
.k:	MOVEQ	#31,D0
.s:	MOVE.W	D0,dat_CurrentSample
.r:	MOVEM.L	(A7)+,D0-D2/A0-A1
	RTS

; -> z=1 no memory
pt_SmxAlloc:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVE.L	#SMX_SIZE,D0
	MOVE.L	#$10000,D1		; clear
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-198,A6)
	MOVE.L	D0,smx_Mem
	BEQ.S	.f
	MOVEA.L	D0,A0			; empty entries: replen 1 as in pt
	MOVEQ	#SMX_N-1,D1
.i:	MOVE.W	#1,28(A0)
	LEA	s_SIZEOF(A0),A0
	DBF	D1,.i
	MOVEQ	#1,D0
	BRA.S	.r
.f:	LEA	smx_MsgMem(PC),A0
	JSR	pt_ShowStatusMsg
	MOVEQ	#0,D0
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

pt_SmxUnswap:
	MOVE.L	D0,-(A7)
	MOVE.W	smx_Swp,D0
	BEQ.S	.r
	BSR.W	pt_SmxSwap
.r:	MOVE.L	(A7)+,D0
	RTS

; d0.w = logical 32-63: exchange slot 31 and its table entry (toggles)
pt_SmxSwap:
	MOVEM.L	D0-D3/A0-A2/A6,-(A7)
	MOVE.W	D0,D3
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-120,A6)		; Disable: replayer and mixer irqs
	MOVE.W	D3,D0
	SUB.W	#32,D0			; entry
	MOVEA.L	smx_Mem,A2
	MOVE.W	D0,D1
	MULU	#s_SIZEOF,D1
	LEA	SMX_HDR(A2,D1.L),A0
	MOVEA.L	dat_ModulePtr,A1
	LEA	20+30*s_SIZEOF(A1),A1	; header of slot 31
	MOVEQ	#s_SIZEOF/2-1,D1
.h:	MOVE.W	(A0),D2
	MOVE.W	(A1),(A0)+
	MOVE.W	D2,(A1)+
	DBF	D1,.h
	MOVE.W	D0,D1
	LSL.W	#2,D1
	LEA	SMX_PTR(A2),A0
	ADDA.W	D1,A0
	LEA	dat_ModulePtr+31*4,A1
	BSR.W	.xl
	LEA	SMX_LEN(A2),A0
	ADDA.W	D1,A0
	LEA	dat_ModulePtr+124+31*4,A1
	BSR.W	.xl
	MOVE.W	D0,D1			; dyn table: entry nr + 32
	ADD.W	#32,D1
	LSL.W	#3,D1
	LEA	SECSTRT_4,A0
	ADDA.W	D1,A0
	LEA	SECSTRT_4+31*8,A1
	BSR.W	.xl
	BSR.W	.xl
	MOVE.W	D0,D1
	ADD.W	D1,D1
	LEA	SMX_FX(A2),A0
	ADDA.W	D1,A0
	LEA	dat_EffectParamVar+31*2,A1
	MOVE.W	(A0),D2
	MOVE.W	(A1),(A0)
	MOVE.W	D2,(A1)
	LEA	SMX_FLG(A2),A0		; dyn flag <-> bit 31
	ADDA.W	D0,A0
	MOVE.L	dat_RpChunkedSamples,D1
	BTST	#31,D1
	SNE	D2
	BCLR	#31,D1
	TST.B	(A0)
	BEQ.S	.f
	BSET	#31,D1
.f:	MOVE.B	D2,(A0)
	MOVE.L	D1,dat_RpChunkedSamples
	MOVE.W	smx_Swp,D1		; toggle
	CLR.W	smx_Swp
	CMP.W	D1,D3
	BEQ.S	.e
	MOVE.W	D3,smx_Swp
.e:	JSR	(-126,A6)		; Enable
	MOVEM.L	(A7)+,D0-D3/A0-A2/A6
	RTS
.xl:	MOVE.L	(A0),D2
	MOVE.L	(A1),(A0)+
	MOVE.L	D2,(A1)+
	RTS

; pt_061A (all samples freed): table entries too, table away
pt_SmxFree:
	MOVEM.L	D0-D2/A0-A2/A6,-(A7)
	CLR.W	smx_Swp
	MOVE.L	smx_Mem,D0
	BEQ.S	.r
	MOVEA.L	D0,A2
	MOVEA.L	ABSEXECBASE.W,A6
	MOVEQ	#SMX_N-1,D2
.s:	MOVE.W	D2,D0
	LSL.W	#2,D0
	LEA	SMX_PTR(A2),A0
	MOVE.L	(A0,D0.W),D1
	BEQ.S	.d
	MOVEA.L	D1,A1
	LEA	SMX_LEN(A2),A0
	MOVE.L	(A0,D0.W),D0
	JSR	(-210,A6)
.d:	MOVE.W	D2,D0
	ADD.W	#32,D0
	LSL.W	#3,D0
	LEA	SECSTRT_4,A0
	ADDA.W	D0,A0
	MOVE.L	(A0),D1
	BEQ.S	.n
	MOVE.L	4(A0),D0
	CLR.L	(A0)
	CLR.L	4(A0)
	MOVEA.L	D1,A1
	JSR	(-210,A6)
.n:	DBF	D2,.s
	CLR.L	smx_Mem
	MOVEA.L	A2,A1
	MOVE.L	#SMX_SIZE,D0
	JSR	(-210,A6)
.r:	MOVEM.L	(A7)+,D0-D2/A0-A2/A6
	MOVE.W	#$0001,dat_TimeDisplayInit	; replaced
	RTS

; -> d0 = number of used table entries (last used + 1), table unswapped
pt_SmxCount:
	MOVEM.L	D1/A0,-(A7)
	MOVEQ	#0,D0
	TST.L	smx_Mem
	BEQ.S	.r
	MOVEA.L	smx_Mem,A0
	MOVEQ	#0,D1
.s:	ADDQ.W	#1,D1
	TST.B	(A0)			; name
	BNE.S	.u
	TST.W	22(A0)			; length
	BEQ.S	.n
.u:	MOVE.W	D1,D0
.n:	LEA	s_SIZEOF(A0),A0
	CMP.W	#SMX_N,D1
	BNE.S	.s
.r:	MOVEM.L	(A7)+,D1/A0
	TST.W	D0
	RTS

; disk op save module: ask if samples > 31, unswap around the save
pt_SmxSave:
	MOVE.W	smx_Swp,smx_Sv
	BSR.W	pt_SmxUnswap
	BSR.W	pt_SmxCount
	BEQ.S	.s
	LEA	smx_AskSave(PC),A0
	JSR	pt_ShowYesNoDialog
	BNE.S	.e
.s:	MOVE.W	dat_CurrentSample,-(A7)
	ST	smx_Saving
	JSR	pt_LoadModule		; saves
	SF	smx_Saving
	MOVE.W	(A7)+,dat_CurrentSample
.e:	MOVE.W	smx_Sv,D0
	BEQ.S	.r
	CMP.W	#31,dat_CurrentSample
	BNE.S	.r
	BRA.W	pt_SmxSwap		; back into slot 31
.r:	RTS

; save error text: again after the caller clears the status line
pt_SaveErrPal41:
	TST.B	smx_Saving
	BEQ.S	.p
	TST.L	stat_Later		; write error text queued: keep it
	BNE.S	.p
	JSR	pt_StatusLater41
.p:	JMP	pt_SetPaletteEdit

; xpk packing failed (no folder, no memory): the notice, then the text
; stays on the status line after the save like any other save error
pt_XpkFail41:
	JSR	pt_SetupEditScreen
	TST.B	smx_Saving
	BEQ.S	.r
	TST.L	stat_Later
	BNE.S	.r
	MOVE.L	A0,-(A7)
	LEA	smx_MsgXpk(PC),A0
	JSR	pt_StatusLater41
	MOVEA.L	(A7)+,A0
.r:	RTS
smx_MsgXpk:	DC.B	"ERROR WHILE XPK-PACKING!",0
	EVEN

; disk op save exe: the player knows 31 samples
pt_SmxExe:
	MOVE.W	smx_Swp,smx_Sv
	BSR.W	pt_SmxUnswap
	BSR.W	pt_SmxCount
	BNE.S	.n
	JSR	pt_0EB9
	BRA.S	.b
.n:	LEA	smx_MsgExe(PC),A0
	JSR	pt_ShowStatusMsg
.b:	MOVE.W	smx_Sv,D0
	BEQ.S	.r
	CMP.W	#31,dat_CurrentSample
	BNE.S	.r
	BRA.W	pt_SmxSwap
.r:	RTS

; save: after sample 31 -> block PT4X, headers, data of the entries
pt_SmxWrite:
	MOVEM.L	D1-D7/A0-A6,-(A7)
	BSR.W	pt_SmxCount
	BEQ.W	.ok
	MOVE.W	D0,smx_WrN		; d7 = file handle, d6 = sample for pt_0EDD
	TST.W	dat_FileSizeMode	; packed: buffer sized for 1-31
	BNE.S	.pk
	TST.L	dat_XPKWriteActive
	BEQ.S	.w
.pk:	LEA	smx_MsgPack(PC),A0
	JSR	pt_StatusLater41
	BRA.W	.ok
.w:
	MOVE.L	#'PT4X',smx_Tag
	MOVE.L	D0,smx_Tag+4
	LEA	smx_Tag,A0
	MOVE.L	A0,dat_FileWriteAddr
	MOVE.L	#8,dat_FileWriteSize
	JSR	pt_WriteFileData
	BNE.W	.r
	MOVEA.L	smx_Mem,A0		; headers with dyn flag in bit 7 of finetune
	MOVE.W	smx_WrN,D1
	SUBQ.W	#1,D1
	MOVEQ	#0,D2
.f:	BCLR	#7,24(A0)
	MOVEA.L	smx_Mem,A1
	ADDA.W	#SMX_FLG,A1
	TST.B	(A1,D2.W)
	BEQ.S	.f2
	BSET	#7,24(A0)
.f2:	LEA	s_SIZEOF(A0),A0
	ADDQ.W	#1,D2
	DBF	D1,.f
	MOVE.L	smx_Mem,dat_FileWriteAddr
	MOVE.W	smx_WrN,D0
	MULU	#s_SIZEOF,D0
	MOVE.L	D0,dat_FileWriteSize
	JSR	pt_WriteFileData
	BNE.S	.r
	MOVE.W	#32,smx_WrL
.d:	MOVE.W	smx_WrL,D0
	BSR.W	pt_SmxSwap		; entry into slot 31, written as 31
	MOVE.W	#31,dat_CurrentSample
	MOVEQ	#31,D6
	JSR	pt_0EDD
	SNE	D5
	MOVE.W	smx_WrL,D0
	BSR.W	pt_SmxSwap
	TST.B	D5
	BNE.S	.r
	ADDQ.W	#1,smx_WrL
	SUBQ.W	#1,smx_WrN
	BNE.S	.d
.ok:	MOVEQ	#0,D0
.r:	MOVEM.L	(A7)+,D1-D7/A0-A6
	RTS

; load: end of the sample loop (dat_CurrentSample just incremented)
; -> z=0 load sample dat_CurrentSample (31 = a table entry), z=1 done
pt_SmxNext:
	MOVEM.L	D0-D3/A0-A1/A6,-(A7)
	MOVE.W	smx_Ld,D0
	BNE.W	.e
	CMP.W	#32,dat_CurrentSample
	BNE.W	.more
	MOVE.L	dat_FileHandle,D1	; after sample 31: block?
	BEQ.W	.done
	TST.L	dat_FileIOState		; packed: from memory, no block
	BNE.W	.done
	TST.W	dat_XpkLibFlag
	BNE.W	.done
	CLR.L	smx_Tag
	MOVE.L	#smx_Tag,D2
	MOVEQ	#8,D3
	MOVEA.L	dat_DosLibBase,A6
	JSR	(-42,A6)		; Read
	CMP.L	#8,D0
	BNE.W	.done
	CMP.L	#'PT4X',smx_Tag
	BNE.W	.done
	MOVE.L	smx_Tag+4,D0
	BEQ.W	.done
	CMP.L	#SMX_N,D0
	BHI.W	.done
	MOVE.W	D0,smx_LdN
	TST.L	smx_Mem
	BNE.S	.a
	BSR.W	pt_SmxAlloc
	BEQ.W	.done
.a:	MOVE.L	dat_FileHandle,D1
	MOVE.L	smx_Mem,D2
	MOVEQ	#0,D3
	MOVE.W	smx_LdN,D3
	MULU	#s_SIZEOF,D3
	MOVEA.L	dat_DosLibBase,A6
	JSR	(-42,A6)
	BSR.S	pt_SmxClampHdrs
	MOVEQ	#32,D0
	BRA.S	.ld
.e:	BSR.W	pt_SmxSwap		; loaded entry back into the table
	ADDQ.W	#1,D0
	MOVE.W	D0,D1
	SUB.W	#32,D1
	CMP.W	smx_LdN,D1
	BCC.S	.end
.ld:	MOVE.W	D0,smx_Ld
	BSR.W	pt_SmxSwap
	MOVE.W	#31,dat_CurrentSample
	BRA.S	.more
.end:	CLR.W	smx_Ld
.done:	MOVE.W	#32,dat_CurrentSample
	MOVEM.L	(A7)+,D0-D3/A0-A1/A6
	ORI	#4,CCR
	RTS
.more:	MOVEM.L	(A7)+,D0-D3/A0-A1/A6
	ANDI	#$fb,CCR
	RTS

; headers of the entries just read: same clamps as slots 1-31
pt_SmxClampHdrs:
	MOVEA.L	smx_Mem,A1
	MOVE.W	smx_LdN,D3
	SUBQ.W	#1,D3
.c:	JSR	pt_FmtClampSmp
	LEA	s_SIZEOF(A1),A1
	DBF	D3,.c
	RTS

; load ended or aborted: entry in loading back into the table
pt_SmxLdEnd:
	MOVE.L	D0,-(A7)
	MOVE.W	smx_Ld,D0
	BEQ.S	.r
	CLR.W	smx_Ld
	BSR.W	pt_SmxSwap
.r:	MOVE.L	(A7)+,D0
	ST	chg_Due			; fingerprint of the loaded module
	MOVE.W	#$0001,dat_CurrentSample	; replaced
	RTS

; info page switch: 0, 16, 32, 47
pt_SmxPage:
	MOVE.W	dat_FileFlags,D0
	ADD.W	#16,D0
	CMP.W	#SMX_MAX-16,D0
	BLS.S	.s
	CMP.W	#SMX_MAX-16+16,D0
	BCC.S	.z
	MOVEQ	#SMX_MAX-16,D0
	BRA.S	.s
.z:	MOVEQ	#0,D0
.s:	MOVE.W	D0,dat_FileFlags
	RTS

; keypad: d1.w = sample 0-31
pt_SmxSelD1:
	MOVE.L	D0,-(A7)
	MOVE.W	D1,D0
	BSR.W	pt_SmxSel
	MOVE.L	(A7)+,D0
	RTS

; all-samples loops (boost, filter, save all): 1-31, then the entries
pt_SmxAllBeg:
	MOVE.W	smx_Swp,smx_AllSv
	BSR.W	pt_SmxUnswap
	CLR.W	smx_AllL
	MOVE.W	dat_CurrentSample,dat_PatternKeyVar	; replaced
	RTS
; after ADDQ of dat_CurrentSample -> c=1 next sample, c=0 done
pt_SmxAllNext:
	MOVEM.L	D0-D1,-(A7)
	MOVE.W	smx_AllL,D0
	BNE.S	.e
	CMP.W	#32,dat_CurrentSample
	BCS.S	.c
	BSR.W	pt_SmxCount
	BEQ.S	.d
	MOVE.W	D0,smx_AllN
	MOVEQ	#32,D0
	BRA.S	.s
.e:	BSR.W	pt_SmxSwap		; back into the table
	ADDQ.W	#1,D0
	MOVE.W	D0,D1
	SUB.W	#31,D1
	CMP.W	smx_AllN,D1
	BHI.S	.z
.s:	MOVE.W	D0,smx_AllL
	BSR.W	pt_SmxSwap
	MOVE.W	#31,dat_CurrentSample
.c:	MOVEM.L	(A7)+,D0-D1
	ORI	#1,CCR
	RTS
.z:	CLR.W	smx_AllL
.d:	MOVEM.L	(A7)+,D0-D1
	ANDI	#$fe,CCR
	RTS
pt_SmxAllEnd:
	MOVE.W	dat_PatternKeyVar,dat_CurrentSample	; replaced
	MOVE.L	D0,-(A7)
	MOVE.W	smx_AllSv,D0
	BEQ.S	.r
	CMP.W	#31,dat_CurrentSample
	BNE.S	.r
	BSR.W	pt_SmxSwap
.r:	MOVE.L	(A7)+,D0
	RTS

smx_AskSave:
	DC.B	10,"Module uses more",10
	DC.B	"than 31 samples. Std",10
	DC.B	"players skip 32-63!",10
	DC.B	"      Save it?",0
smx_MsgExe:	DC.B	"EXE: ONLY SAMPLES 1-31",0
smx_MsgPack:	DC.B	"PACKED: SAMPLES 32-63 NOT SAVED",0
smx_MsgMem:	DC.B	"NO MEMORY FOR SAMPLES 32-63",0
	EVEN
