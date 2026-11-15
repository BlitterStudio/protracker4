; second start, intuition patch guard
; d0 = FindTask(pt name), a6 = execbase: pt runs already -> it comes to
; front by ctrl-f, this one ends at once (rc 5), no requester: intuition
; carries the other pt's patch, its code would run on this task
pt_DupChk41:
	MOVE.L	D0,dat_DosBase
	BNE.S	.dup
	RTS
.dup:	JSR	(-132,A6)		; Forbid: other pt must not quit now
	LEA	str_PTProcessName,A1
	JSR	(-294,A6)		; FindTask again
	TST.L	D0
	BEQ.S	.gone
	MOVEA.L	D0,A1
	MOVE.L	#$8000,D0		; ctrl-f
	JSR	(-324,A6)		; Signal
.gone:	JSR	(-138,A6)		; Permit
	BSR.S	pt_DupMsg41
	MOVEA.L	dat_StackPointer,A7
	MOVEQ	#5,D0			; warn
	RTS

; cli start: one line on output, a6 = execbase
pt_DupMsg41:
	MOVEA.L	276(A6),A0		; ThisTask
	TST.L	172(A0)			; pr_CLI
	BEQ.S	.r
	LEA	str_DosLib,A1
	MOVEQ	#0,D0
	JSR	(-552,A6)		; OpenLibrary
	TST.L	D0
	BEQ.S	.r
	MOVEA.L	D0,A6
	JSR	(-60,A6)		; Output
	MOVE.L	D0,D1
	BEQ.S	.c
	MOVE.L	#.msg,D2
	MOVEQ	#.msge-.msg,D3
	JSR	(-48,A6)		; Write
.c:	MOVEA.L	A6,A1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-414,A6)		; CloseLibrary
.r:	RTS
.msg:	DC.B	"ProTracker is already running.",10
.msge:
	EVEN

; every input loop (replaces pt_BreakQuit41): ctrl-f = second start,
; pt to front; then ctrl-c as before
pt_BreakChk41:
	MOVEM.L	D0/A0/A6,-(A7)
	MOVEA.L	ABSEXECBASE.W,A6
	MOVEA.L	276(A6),A0
	MOVE.L	26(A0),D0		; tc_SigRecvd
	BTST	#15,D0
	BEQ.S	.nf
	MOVEQ	#0,D0
	MOVE.L	#$8000,D1
	JSR	(-306,A6)		; SetSignal: take ctrl-f
	BSR.S	pt_ToFront41
.nf:	MOVEM.L	(A7)+,D0/A0/A6
	JMP	pt_BreakQuit41

; pt window or screen to the front
pt_ToFront41:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	ADDQ.B	#1,req_Front
	MOVEA.L	dat_IntuiLibBase,A6
	CMPI.B	#1,rtg_ProcState
	BNE.S	.scr
	TST.B	rtg_RunWin
	BEQ.S	.card
	MOVE.L	rtg_Window,D0
	BEQ.S	.scr
	MOVEA.L	D0,A0
	JSR	(-312,A6)		; WindowToFront
	MOVEA.L	rtg_Window,A0
	JSR	(-450,A6)		; ActivateWindow
	BRA.S	.r
.card:	MOVE.L	rtg_Screen,D0
	BNE.S	.fr
.scr:	MOVE.L	dat_ScreenPtr,D0
	BEQ.S	.r
.fr:	MOVEA.L	D0,A0
	JSR	(-252,A6)		; ScreenToFront
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

; intuition patch only once: a second install would keep its own
; handler as the old vector; off only when in place
pt_VecOn41:
	MOVEA.L	ABSEXECBASE.W,A6
	TST.B	req_Patch
	BNE.S	pt_VecSkip41
	ST	req_Patch
	JMP	(-132,A6)		; Forbid, on into pt_SetVectorAud0
pt_VecOff41:
	MOVEA.L	ABSEXECBASE.W,A6
	TST.B	req_Patch
	BEQ.S	pt_VecSkip41
	SF	req_Patch
	JMP	(-132,A6)		; Forbid, on into pt_RestoreIntVecs
pt_VecSkip41:
	ADDQ.L	#4,A7			; skip the rest of the caller
	RTS
