; status line: text wider than the field scrolls (marquee), nothing is
; drawn past the field

STAT_W		EQU	26		; chars in the field
STAT_MAX	EQU	80		; longest text kept
STAT_STEP	EQU	8		; ticks (1/50 s) a char
STAT_HOLD	EQU	75		; ticks at both ends

; from pt_ShowStatusMsg (a0 text, d0 length, d1 field pos): draw
pt_StatusDraw41:
	CMP.W	#STAT_W,D0
	BHI.S	.long
	CLR.W	stat_Len
	JMP	pt_DrawTextAt
.long:	MOVEM.L	D0/A0-A1,-(A7)
	CMP.W	#STAT_MAX,D0
	BLS.S	.c
	MOVEQ	#STAT_MAX,D0
.c:	MOVE.W	D0,stat_Len		; own copy: callers reuse their buffers
	LEA	stat_Buf,A1
	SUBQ.W	#1,D0
.cp:	MOVE.B	(A0)+,(A1)+
	DBF	D0,.cp
	CLR.W	stat_Pos
	MOVE.W	D1,stat_Field
	BSR.W	pt_StatusTicks
	ADD.L	#STAT_HOLD,D0
	MOVE.L	D0,stat_Next
	MOVEM.L	(A7)+,D0/A0-A1
	LEA	stat_Buf,A0
	MOVEQ	#STAT_W,D0
	JMP	pt_DrawTextAt

; a0 = text shown again on the next main pass (callers that return
; into code which writes its own status right after)
pt_StatusLater41:
	MOVE.L	A0,stat_Later
	RTS

; main loop: pending text, next marquee step when due
pt_StatusPoll41:
	TST.L	stat_Later
	BEQ.S	.nl
	MOVEM.L	A0,-(A7)
	MOVEA.L	stat_Later,A0
	CLR.L	stat_Later
	JSR	pt_ShowStatusMsg
	MOVEM.L	(A7)+,A0
.nl:	TST.W	stat_Len
	BEQ.S	.r
	MOVEM.L	D0-D7/A0-A6,-(A7)
	BSR.W	pt_StatusTicks
	MOVE.L	stat_Next,D1		; due (or the clock passed midnight)
	SUB.L	D0,D1
	BLE.S	.due
	CMP.L	#2*STAT_HOLD,D1
	BLS.S	.x
.due:
	MOVE.W	stat_Len,D2
	SUB.W	#STAT_W,D2		; last start
	MOVE.W	stat_Pos,D1
	MOVEQ	#STAT_STEP,D3
	CMP.W	D2,D1
	BLT.S	.adv
	MOVEQ	#0,D1			; at the end: back to the start
	MOVE.W	#STAT_HOLD,D3
	BRA.S	.set
.adv:	ADDQ.W	#1,D1
	CMP.W	D2,D1
	BLT.S	.set
	MOVE.W	#STAT_HOLD,D3		; reached the end: hold
.set:	MOVE.W	D1,stat_Pos
	TST.W	D1
	BNE.S	.nh
	MOVE.W	#STAT_HOLD,D3		; start: hold
.nh:	ADD.L	D3,D0
	MOVE.L	D0,stat_Next
	LEA	stat_Buf,A0
	ADDA.W	D1,A0
	MOVEQ	#STAT_W,D0
	MOVE.W	stat_Field,D1
	JSR	pt_DrawTextAt
.x:	MOVEM.L	(A7)+,D0-D7/A0-A6
.r:	RTS

; d0 = ticks since midnight (dos DateStamp, 50 a second)
pt_StatusTicks:
	MOVEM.L	D1-D2/A0-A1/A6,-(A7)
	LEA	stat_Date,A0
	MOVE.L	A0,D1
	MOVEA.L	dat_DosLibBase,A6
	JSR	(-192,A6)		; DateStamp
	MOVE.L	stat_Date+4,D0		; minutes
	MULU	#3000,D0
	ADD.L	stat_Date+8,D0
	MOVEM.L	(A7)+,D1-D2/A0-A1/A6
	RTS
