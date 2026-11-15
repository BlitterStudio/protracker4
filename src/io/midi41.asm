; midi in: serial port at 31250 baud, rbf irq fills a ring, the main
; task parses it; note on enters a note like a key (48 = c-1)
MID_RING	EQU	256
MID_QLEN	EQU	16		; notes waiting for the main loop
MID_NOTE0	EQU	48		; midi note of c-1
MID_UNITS	EQU	2		; misc.resource: serial port, serial bits
MID_SERDATR	EQU	$DFF018
MID_SERPER	EQU	$DFF032
MID_INTREQ	EQU	$DFF09C

; on: claim the port, irq on; d0 = 0 ok, -1 port in use
pt_MidiOn:
	MOVEM.L	D1-D2/A0-A2/A6,-(A7)
	TST.B	mid_On
	BNE.W	.ok
	MOVEA.L	ABSEXECBASE.W,A6
	LEA	mid_MiscName(PC),A1
	JSR	(-498,A6)		; OpenResource
	MOVE.L	D0,mid_Misc
	BEQ.W	.fail
	MOVEQ	#0,D2			; unit
.al:	MOVEA.L	mid_Misc,A6
	MOVE.L	D2,D0
	LEA	mid_Owner(PC),A1
	JSR	(-6,A6)			; AllocMiscResource
	TST.L	D0
	BNE.W	.busy
	ADDQ.W	#1,D2
	CMP.W	#MID_UNITS,D2
	BNE.W	.al
	MOVEA.L	ABSEXECBASE.W,A6
	MOVE.W	#$0800,INTENA		; rbf off while the vector changes
	MOVEQ	#11,D0			; INTB_RBF
	LEA	mid_Int,A1
	MOVE.B	#2,8(A1)		; NT_INTERRUPT
	LEA	mid_Owner(PC),A0
	MOVE.L	A0,10(A1)
	MOVE.L	#pt_MidiIrq,18(A1)
	JSR	(-162,A6)		; SetIntVector
	MOVE.L	D0,mid_OldInt
	MOVE.L	(568,A6),D0		; ex_EClockFrequency
	MOVE.L	D0,D1
	LSL.L	#2,D0
	ADD.L	D1,D0			; x5 = colour clock
	ADD.L	#31250/2,D0
	DIVU	#31250,D0
	SUBQ.W	#1,D0
	MOVE.W	D0,MID_SERPER		; 8 bit, 31250 baud
	CLR.B	mid_Head
	CLR.B	mid_Tail
	CLR.B	mid_Status
	CLR.B	mid_Cnt
	CLR.B	mid_QHead
	CLR.B	mid_QTail
	MOVE.W	#$0800,MID_INTREQ
	MOVE.W	#$8800,INTENA
	ST	mid_On
.ok:	MOVEQ	#0,D0
	BRA.W	.r
.busy:	SUBQ.W	#1,D2			; free the units we got
	BMI.W	.fail
	MOVEA.L	mid_Misc,A6
	MOVE.L	D2,D0
	JSR	(-12,A6)		; FreeMiscResource
	BRA.W	.busy
.fail:	MOVEQ	#-1,D0
.r:	MOVEM.L	(A7)+,D1-D2/A0-A2/A6
	RTS

; off: irq off, old vector back, port free
pt_MidiOff:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	TST.B	mid_On
	BEQ.W	.r
	SF	mid_On
	MOVE.W	#$0800,INTENA
	MOVE.W	#$0800,MID_INTREQ
	MOVEA.L	ABSEXECBASE.W,A6
	MOVEQ	#11,D0
	MOVEA.L	mid_OldInt,A1
	JSR	(-162,A6)		; SetIntVector, rbf stays off
	MOVEA.L	mid_Misc,A6
	MOVEQ	#1,D0
	JSR	(-12,A6)		; FreeMiscResource
	MOVEQ	#0,D0
	JSR	(-12,A6)
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

; rbf irq: byte into the ring
pt_MidiIrq:
	MOVE.W	MID_SERDATR,D0
	MOVE.W	#$0800,MID_INTREQ
	MOVEQ	#0,D1
	MOVE.B	mid_Head,D1
	LEA	mid_Ring,A1
	TST.W	D0			; overrun: a byte was lost before this one
	BPL.S	.nov
	MOVE.B	#$f7,(A1,D1.W)		; gap marker: running status ends there
	ADDQ.B	#1,D1
	CMP.B	mid_Tail,D1
	BEQ.W	.r
	MOVE.B	D1,mid_Head
.nov:	MOVE.B	D0,(A1,D1.W)
	ADDQ.B	#1,D1
	CMP.B	mid_Tail,D1		; full: drop
	BEQ.W	.r
	MOVE.B	D1,mid_Head
.r:	RTS

; from pt_SetPoll, every input loop: a loop that is not the main loop
; (dialog, requester) drops what arrives, else it would be entered when
; the main loop is back
pt_MidiTask:
	TST.B	mid_On
	BEQ.S	.r
	MOVE.L	D0,-(A7)
	MOVE.B	mid_Pass,D0
	CMP.B	mid_PassSeen,D0
	BNE.S	.main
	MOVE.B	mid_Head,mid_Tail
	MOVE.B	mid_QHead,mid_QTail
	CLR.B	mid_Status
	CLR.B	mid_Cnt
	MOVE.L	(A7)+,D0
.r:	RTS
.main:	MOVE.B	D0,mid_PassSeen
	MOVE.L	(A7)+,D0
	BRA.W	pt_MidiPoll

; main task: parse the ring; note on -> note entry
pt_MidiPoll:
	TST.B	mid_On
	BEQ.W	.r
	MOVEM.L	D0-D7/A0-A6,-(A7)
.next:	MOVEQ	#0,D1
	MOVE.B	mid_Tail,D1
	CMP.B	mid_Head,D1
	BEQ.W	.x
	LEA	mid_Ring,A0
	MOVE.B	(A0,D1.W),D0
	ADDQ.B	#1,mid_Tail
	CMP.B	#$f8,D0			; realtime: ignore, status stays
	BCC.W	.next
	TST.B	D0
	BPL.W	.data
	CLR.B	mid_Cnt
	CMP.B	#$f0,D0			; sysex, common: no running status
	BCS.W	.st
	MOVEQ	#0,D0
.st:	MOVE.B	D0,mid_Status
	BRA.W	.next
.data:	MOVE.B	mid_Status,D2
	BEQ.W	.next
	MOVE.B	D2,D3
	AND.B	#$f0,D3
	MOVEQ	#0,D4
	MOVE.B	mid_Cnt,D4
	LEA	mid_Data,A0
	MOVE.B	D0,(A0,D4.W)
	ADDQ.B	#1,D4
	CMP.B	#$c0,D3			; program, pressure: one data byte
	BEQ.W	.one
	CMP.B	#$d0,D3
	BEQ.W	.one
	CMP.B	#2,D4
	BCS.W	.keep
.one:	CLR.B	mid_Cnt
	CMP.B	#$90,D3
	BNE.W	.next
	TST.B	mid_Data+1		; velocity 0 = note off
	BEQ.W	.next
	MOVE.B	mid_Chan,D3		; 0 = all, 1..16
	BEQ.W	.ch
	SUBQ.B	#1,D3
	AND.B	#$0f,D2
	CMP.B	D2,D3
	BNE.W	.next
.ch:	MOVEQ	#0,D1			; queue for the main loop
	MOVE.B	mid_QHead,D1
	LEA	mid_Q,A0
	MOVE.B	mid_Data,(A0,D1.W)
	ADDQ.B	#1,D1
	AND.B	#MID_QLEN-1,D1
	CMP.B	mid_QTail,D1		; full: drop
	BEQ.W	.next
	MOVE.B	D1,mid_QHead
	BRA.W	.next
.keep:	MOVE.B	D4,mid_Cnt
	BRA.W	.next
.x:	MOVEM.L	(A7)+,D0-D7/A0-A6
.r:	RTS

; main loop (after the keys): queued notes are entered like keys;
; dialogs run their own loops and never get here
pt_MidiMain:
	TST.B	mid_On
	BEQ.S	.r
	ADDQ.B	#1,mid_Pass		; the main loop is running
	MOVEM.L	D0-D7/A0-A6,-(A7)
	BSR.W	pt_MidiPoll
.l:	MOVEQ	#0,D1
	MOVE.B	mid_QTail,D1
	CMP.B	mid_QHead,D1
	BEQ.S	.x
	LEA	mid_Q,A0
	MOVE.B	(A0,D1.W),mid_Data
	ADDQ.B	#1,D1
	AND.B	#MID_QLEN-1,D1
	MOVE.B	D1,mid_QTail
	BSR.S	pt_MidiNote
	BRA.S	.l
.x:	MOVEM.L	(A7)+,D0-D7/A0-A6
.r:	RTS

; mid_Data = note: c-1..b-3, with notes EXT c-4..g-4 (key path)
pt_MidiNote:
	IFD	DEBUGAUTO
	ADDQ.B	#1,mid_DbgCnt
	ENDC
	MOVEQ	#0,D0
	MOVE.B	mid_Data,D0
	SUB.W	#MID_NOTE0,D0
	BMI.W	.r
	SF	note_Up41
	CMP.W	#36,D0
	BCS.W	.go
	TST.B	note_Ext41
	BEQ.W	.r
	CMP.W	#36+8,D0
	BCC.W	.r
	SUB.W	#12,D0			; octave 4: one octave up
	ST	note_Up41
.go:	JMP	pt_0505			; as a key (edit, record, play)
.r:	RTS

mid_MiscName:	DC.B	"misc.resource",0
mid_Owner:	DC.B	"ProTracker MIDI",0
	EVEN
