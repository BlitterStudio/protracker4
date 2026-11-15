; checked dos Write for user files: same call as Write (d1 fh, d2 buf,
; d3 len, a6 dos, d0 = result). short or failed write (disk full, write
; error) -> message once the caller has written its own status

pt_Write41:
	BSR.S	pt_WriteQuiet41
	CMP.L	D3,D0
	BEQ.S	.r
	ST	io_WrFail
	MOVE.L	A0,-(A7)
	LEA	io_MsgWrite(PC),A0
	JSR	pt_StatusLater41
	MOVEA.L	(A7)+,A0
.r:	RTS

; dos Write without system requesters: "volume is full" would open on
; the workbench screen behind pt and stop it; dos returns the error
pt_WriteQuiet41:
	MOVE.W	#-48,-(A7)		; Write
	BRA.S	pt_DosQuiet41
; delete / rename without requesters: d1 (d2), a6 dos
pt_DelQuiet41:
	MOVE.W	#-72,-(A7)		; Delete
	BRA.S	pt_DosQuiet41
pt_RenQuiet41:
	MOVE.W	#-78,-(A7)		; Rename
	BRA.S	pt_DosQuiet41
; dos Close without requesters (ffs writes its last blocks here)
pt_CloseQuiet41:
	MOVE.W	#-36,-(A7)		; Close
pt_DosQuiet41:
	MOVEM.L	D1-D4/A0-A2/A6,-(A7)
	MOVEA.L	ABSEXECBASE.W,A6
	SUBA.L	A1,A1
	JSR	(-294,A6)		; FindTask(0)
	MOVEA.L	D0,A2
	MOVE.L	(184,A2),D4		; pr_WindowPtr
	MOVE.L	#-1,(184,A2)
	MOVE.L	(A7),D1			; fh back
	MOVEA.L	28(A7),A6		; dos
	MOVE.W	32(A7),D0		; lvo
	JSR	(A6,D0.W)
	MOVE.L	D4,(184,A2)
	MOVEM.L	(A7)+,D1-D4/A0-A2/A6
	ADDQ.L	#2,A7
	RTS

io_MsgWrite:	DC.B	"WRITE ERR, FILE INCOMPLETE",0
io_MsgKept:	DC.B	"WRITE ERR, OLD FILE KEPT",0
io_BakExt:	DC.B	".~PT",0
	EVEN

; save open (a6 dos, d1 name, d2 mode as Open): a file that is there is
; renamed to name.~PT first; the new file replaces it only once it was
; written whole (pt_CloseSave41), else the old one comes back. no
; backup (name too long, rename fails): plain open as before
pt_OpenSave41:
	MOVEM.L	D1-D5/A0-A2,-(A7)
	TST.B	io_BakOn		; second open of the same save
	BNE.S	.open
	CLR.B	io_WrFail
	LEA	dat_FileNameBuf,A0
	LEA	io_BakName,A1
	MOVEQ	#119,D3
.c:	MOVE.B	(A0)+,D0
	BEQ.S	.e
	MOVE.B	D0,(A1)+
	DBF	D3,.c
	BRA.S	.open
.e:	LEA	io_BakExt(PC),A0
.x:	MOVE.B	(A0)+,(A1)+
	BNE.S	.x
	MOVE.L	#dat_FileNameBuf,D1
	MOVEQ	#-2,D2
	JSR	(-84,A6)		; Lock: is there an old file
	MOVE.L	D0,D1
	BEQ.S	.open
	JSR	(-90,A6)		; UnLock
	MOVE.L	#io_BakName,D1
	BSR.W	pt_DelQuiet41		; leftover of a failed run
	MOVE.L	#dat_FileNameBuf,D1
	MOVE.L	#io_BakName,D2
	BSR.W	pt_RenQuiet41
	TST.L	D0
	BEQ.S	.open
	ST	io_BakOn
.open:	MOVE.L	#dat_FileNameBuf,D1
	MOVE.L	#$000003ee,D2
	JSR	(-30,A6)		; Open
	TST.L	D0
	BNE.S	.r
	JSR	pt_WideSaveFree		; save ends here: wide block too
	TST.B	io_BakOn		; no new file: old one back
	BEQ.S	.r
	CLR.B	io_BakOn
	MOVE.L	#io_BakName,D1
	MOVE.L	#dat_FileNameBuf,D2
	BSR.W	pt_RenQuiet41
	MOVEQ	#0,D0
.r:	MOVEM.L	(A7)+,D1-D5/A0-A2
	RTS

; save close (a6 dos, d1 handle): whole file -> backup goes, else the
; partial file goes and the old one comes back
pt_CloseSave41:
	BSR.W	pt_CloseQuiet41
	TST.B	io_BakOn
	BEQ.S	.r
	MOVEM.L	D0-D2/A0/A6,-(A7)
	CLR.B	io_BakOn
	TST.L	D0
	BEQ.S	.f
	TST.B	io_WrFail
	BNE.S	.f
	MOVE.L	#io_BakName,D1
	BSR.W	pt_DelQuiet41
	BRA.S	.d
.f:	MOVE.L	#dat_FileNameBuf,D1
	BSR.W	pt_DelQuiet41
	MOVE.L	#io_BakName,D1
	MOVE.L	#dat_FileNameBuf,D2
	BSR.W	pt_RenQuiet41
	LEA	io_MsgKept(PC),A0
	JSR	pt_StatusLater41
.d:	MOVEM.L	(A7)+,D0-D2/A0/A6
.r:	RTS

; save sample: open failed -> say so (beta 2 only blinked); the caller
; writes its own status after us, so the text comes on the next pass
pt_SaveSmpFail41:
	JSR	pt_RestorePalette
	LEA	dat_0FEA,A0
	JSR	pt_StatusLater41
	JMP	pt_SetPaletteEdit

;--- disk ops: result checks, text comes on the next main pass
; a0 = text
pt_OpFail41:
	JSR	pt_StatusLater41
	RTS

; delete: d0 = result
pt_DelDone41:
	MOVE.L	D0,-(A7)
	JSR	pt_ClearStatusMsg
	MOVE.L	(A7)+,D0
	BNE.S	.r
	LEA	io_MsgNoDel(PC),A0
	BSR.S	pt_OpFail41
.r:	RTS

; rename: d0 = result
pt_RenDone41:
	MOVE.L	D0,-(A7)
	JSR	pt_RestorePalette
	MOVE.L	(A7)+,D0
	BNE.S	.r
	LEA	io_MsgNoRen(PC),A0
	BSR.S	pt_OpFail41
.r:	RTS

; makedir: d1 = path, a6 = dos
pt_MkDir41:
	JSR	(-120,A6)		; CreateDir
	MOVE.L	D0,D1
	BEQ.S	.f
	JSR	(-90,A6)		; UnLock
	BRA.S	.r
.f:	LEA	io_MsgNoDir(PC),A0
	BSR.S	pt_OpFail41
.r:	JMP	pt_RestorePalette

; disk free: no lock -> empty info instead of Info(0)
pt_InfoDo41:
	MOVE.L	#dat_14ED,D2
	TST.L	D1
	BEQ.S	.z
	JMP	(-114,A6)		; Info
.z:	MOVEA.L	D2,A0
	MOVEQ	#8,D0
.c:	CLR.L	(A0)+
	DBF	D0,.c
	RTS

io_MsgNoDel:	DC.B	"CAN'T DELETE FILE!",0
io_MsgNoRen:	DC.B	"CAN'T RENAME FILE!",0
io_MsgNoDir:	DC.B	"CAN'T CREATE DIR!",0
	EVEN

; packed save: d0 = 0 unless everything was written
pt_PackWrite41:
	BSR.W	pt_WriteQuiet41
	CMP.L	D3,D0
	BEQ.S	.r
	ST	io_WrFail
	MOVEQ	#0,D0
.r:	TST.L	D0
	RTS

; header read came up short: close, tell, song stays as it is
pt_ShortFile41:
	JSR	pt_CloseFileHandle
	LEA	io_MsgShort(PC),A0
	JSR	pt_StatusLater41
	JMP	pt_FinishPaletteEdit

; pattern file header: form size = data size
pt_PatHdr41:
	MOVE.L	#dat_0235,D2
	BTST	#5,dat_ModeFlags	; set = 4ch
	BNE.S	.r
	MOVE.L	#io_PatHdr8,D2
.r:	RTS
io_PatHdr8:	DC.L	"FORM",$800,"PTCF","PATT"

io_MsgShort:	DC.B	"FILE TOO SHORT, NOT LOADED",0
	EVEN

; add path: d0 = lock; none -> text, Z set
pt_PathLock41:
	MOVE.L	D0,dat_PatternIndexBuf
	BNE.S	.r
	LEA	dat_02C4,A0
	JSR	pt_StatusLater41
	MOVEQ	#0,D0
.r:	RTS

; sample body written (d0 = result): failed -> out of pt_0EDD, nz;
; else z=0 for a dyn envelope to follow
pt_SmpWrChk41:
	TST.L	D0
	BNE.S	.e
	TST.B	dat_FileHandleVar
	RTS
.e:	ADDQ.L	#4,A7
	MOVEQ	#-1,D0
	RTS

; pp password window: the screen comes back (pt_OpenScreenInit) only if
; pt_ScrBack41 really sent it away; in window mode only the window
; returns, a second port and input handler would corrupt the handler list
pt_PwBack41:
	SF	req_PwBack
	JSR	dat_03FB
	BNE.S	.r
	ST	req_PwBack
.r:	RTS

pt_PwFront41:
	TST.B	req_PwBack
	BEQ.S	.win
	SF	req_PwBack
	MOVEA.L	dat_ScreenPtr,A0	; orig left the closed window here
	JMP	pt_OpenScreenInit
.win:	JSR	pt_ToFront41
	SUBQ.B	#1,req_Front		; not a ctrl-f
	RTS
