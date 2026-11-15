; test build: amigus card in ram, register write log
	IFD	DEBUGAUTO
AGLOG_N		EQU	4096		; ring records

; amigus.library card struct: wave regs at 4, type id at 32
dbg_FakeCard:
	DS.B	4
	DC.L	dbg_FakeRegs
	DS.B	24
	DC.W	$7001
	DS.B	2
	EVEN

; bsr, then dc.w reg: log the write just done (voice = bank reg)
dbg_AgRec:
	MOVEM.L	D0-D3/A0-A2,-(A7)
	MOVEA.L	28(A7),A0
	MOVEQ	#0,D1
	MOVE.W	(A0)+,D1
	MOVE.L	A0,28(A7)
	MOVEA.L	agus_Wave,A1
	MOVEQ	#0,D0
	MOVE.W	AW_BANK(A1),D0
	AND.W	#31,D0
	MOVEQ	#0,D3
	MOVE.W	0(A1,D1.W),D3		; ctrl is a word
	MOVEQ	#0,D2
	CMP.W	#AW_CTRL,D1
	BEQ.S	.k
	MOVE.L	0(A1,D1.W),D3
	MOVEQ	#1,D2
	CMP.W	#AW_START,D1
	BEQ.S	.k
	MOVEQ	#2,D2
	CMP.W	#AW_LOOP,D1
	BEQ.S	.k
	MOVEQ	#3,D2
	CMP.W	#AW_END,D1
	BEQ.S	.k
	MOVEQ	#4,D2
	CMP.W	#AW_RATE,D1
	BEQ.S	.k
	MOVEQ	#5,D2
.k:	MOVE.W	D0,D1			; d1 = voice (reg offset no longer needed)
	LEA	dbg_AgShadow,A2
	MULU	#24,D1
	ADDA.L	D1,A2
	ADD.W	D2,D2
	ADD.W	D2,D2
	MOVE.L	D3,0(A2,D2.W)
	TST.W	D2			; ctrl start bit
	BNE.S	.nc
	BTST	#15,D3
	BEQ.S	.nc
	LEA	dbg_AgStarts,A2
	ADD.W	D0,D0
	ADDQ.W	#1,0(A2,D0.W)
	LSR.W	#1,D0
.nc:	MOVE.L	dbg_AgHead,D1
	AND.W	#AGLOG_N-1,D1
	LSL.W	#3,D1
	LEA	dbg_AgRing,A2
	ADDA.W	D1,A2
	MOVE.W	dbg_TickCnt,(A2)+
	MOVE.B	D0,(A2)+
	MOVEA.L	28(A7),A0
	MOVE.W	-2(A0),D1		; the reg offset word
	MOVE.B	D1,(A2)+
	MOVE.L	D3,(A2)
	ADDQ.L	#1,dbg_AgHead
	MOVEM.L	(A7)+,D0-D3/A0-A2
	RTS
	
; end of a card run: stage lengths in lines, summed (average = sum / n)
; and the longest tick kept: update, tick, levels, advance, total from the
; irq entry, replayer before the run
dbg_AgDone:
	MOVEM.L	D1-D4/A0-A2,-(A7)
	LEA	dbg_AgTime,A0
	LEA	dbg_AgLen,A1
	MOVEQ	#3,D3
.l:	MOVE.W	2(A0),D1
	SUB.W	(A0)+,D1
	BSR.S	.m
	MOVE.W	D1,(A1)+
	DBF	D3,.l
	MOVE.W	dbg_AgTime+8,D1
	SUB.W	dbg_AgTime+10,D1
	BSR.S	.m
	MOVE.W	D1,(A1)+
	MOVE.W	dbg_AgTime,D1
	SUB.W	dbg_AgTime+10,D1
	BSR.S	.m
	MOVE.W	D1,(A1)
	LEA	dbg_AgLen,A0
	LEA	dbg_AgSum,A1
	MOVEQ	#5,D3
.s:	MOVEQ	#0,D1
	MOVE.W	(A0)+,D1
	ADD.L	D1,(A1)+
	DBF	D3,.s
	ADDQ.L	#1,(A1)
	LEA	dbg_AgLen,A0
	LEA	dbg_AgMaxT,A1
	MOVE.W	8(A0),D1
	CMP.W	8(A1),D1
	BLS.S	.r
	MOVEQ	#5,D3
.c:	MOVE.W	(A0)+,(A1)+
	DBF	D3,.c
.r:	MOVEM.L	(A7)+,D1-D4/A0-A2
	RTS
.m:	BPL.S	.o
	ADD.W	#313,D1
.o:	RTS
	ENDC
