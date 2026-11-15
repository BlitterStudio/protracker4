; ahi output filter: paula's led and a500 rc low pass for the card
; stages y += c*(x-y), c = 1/2 +- 2^-a +- 2^-b, 8 fraction bits
; a3 = end of left half (right half at +AHI_HALF*2), all regs kept
FSTAGE	MACRO				; \1 = in, \2 = state, \3/\4 = shift/sub of term a, \5/\6 of term b
	MOVE.L	\1,D5
	SUB.L	\2,D5
	MOVE.L	D5,D6
	ASR.L	#1,D6
	MOVE.L	D5,D1
	ASR.L	#\3,D1
	IFEQ	\4
	ADD.L	D1,D6
	ELSE
	SUB.L	D1,D6
	ENDC
	ASR.L	#\5,D5
	IFEQ	\6
	ADD.L	D5,D6
	ELSE
	SUB.L	D5,D6
	ENDC
	ADD.L	D6,\2
	ENDM

; \1: 1 = rc, 2 = led (2 stages), 3 = both; coefs from F_*
FLOOP	MACRO
	MOVE.W	#AHI_HALF-1,D7
.l:	MOVE.W	(A0),D0
	EXT.L	D0
	LSL.L	#8,D0
	IF	\1&1
	FSTAGE	D0,D2,F_RA,F_RS,F_RB,F_RT
	ENDC
	IF	\1=3
	FSTAGE	D2,D3,F_LA,F_LS,F_LB,F_LT
	ENDC
	IF	\1=2
	FSTAGE	D0,D3,F_LA,F_LS,F_LB,F_LT
	ENDC
	IF	\1&2
	FSTAGE	D3,D4,F_LA,F_LS,F_LB,F_LT
	MOVE.L	D4,D0
	ELSE
	MOVE.L	D2,D0
	ENDC
	ASR.L	#8,D0
	MOVE.W	D0,(A0)+
	DBF	D7,.l
	RTS
	ENDM

; all three variants of one rate
FSET	MACRO
flt_\1_1:
	FLOOP	1
flt_\1_2:
	FLOOP	2
flt_\1_3:
	FLOOP	3
	ENDM

; clear states (start, resync, rate change)
pt_CardFltReset41:
	ST	ahi_FltRst		; soundfunc clears before the next half
	RTS
flt_Clr:
	SF	ahi_FltRst
	CLR.L	ahi_FltSt
	CLR.L	ahi_FltSt+4
	CLR.L	ahi_FltSt+8
	CLR.L	ahi_FltSt+12
	CLR.L	ahi_FltSt+16
	CLR.L	ahi_FltSt+20
	CLR.B	ahi_FltLed
	RTS

	IFD	DEBUGAUTO
pt_CardFlt41:
	BSR.W	flt_DbgPre
	BSR.S	flt_Run
	BRA.W	flt_DbgPost
	ELSE
pt_CardFlt41:
	ENDC
flt_Run:
	TST.B	ahi_FltRst
	BEQ.S	.nr
	BSR.S	flt_Clr
.nr:	TST.B	ahi_FltMode
	BEQ.W	.r
	MOVEM.L	D0-D7/A0-A3,-(A7)
	MOVEQ	#0,D6			; led on = cia bit 1 clear
	BTST	#1,CIAA_PRA
	BNE.S	.nl
	MOVEQ	#1,D6
.nl:	MOVE.B	ahi_FltLed,D0
	MOVE.B	D6,ahi_FltLed
	NOT.B	D0
	AND.B	D6,D0			; led just switched on
	MOVE.B	D0,ahi_FltInit
	MOVEQ	#0,D4			; 1 rc, 2 led
	CMPI.B	#2,ahi_FltMode
	BNE.S	.a12
	MOVEQ	#1,D4
.a12:	ADD.B	D6,D6
	ADD.B	D6,D4
	BEQ.S	.x
	MOVEQ	#0,D5			; rate set: 14000 / 22050 / 28604
	MOVE.W	mix_Rate,D1
	BEQ.S	.hi
	CMP.W	#18025,D1
	BLO.S	.sel
	MOVEQ	#3,D5
	CMP.W	#25327,D1
	BLO.S	.sel
.hi:	MOVEQ	#6,D5
.sel:	ADD.W	D4,D5
	SUBQ.W	#1,D5
	ADD.W	D5,D5
	LEA	flt_Tab(PC),A2
	MOVE.W	(A2,D5.W),D5
	ADDA.W	D5,A2
	LEA	-AHI_HALF*2(A3),A0
	LEA	ahi_FltSt,A1
	TST.B	ahi_FltInit
	BEQ.S	.go
	BSR.S	.ini			; led states from rc state or first sample
	LEA	AHI_HALF*2(A3),A0
	LEA	ahi_FltSt+12,A1
	BSR.S	.ini
.go:	LEA	-AHI_HALF*2(A3),A0
	LEA	ahi_FltSt,A1
	BSR.S	.one
	LEA	AHI_HALF*2(A3),A0
	LEA	ahi_FltSt+12,A1
	BSR.S	.one
.x:	MOVEM.L	(A7)+,D0-D7/A0-A3
.r:	RTS
.one:	MOVEM.L	(A1),D2-D4
	JSR	(A2)
	MOVEM.L	D2-D4,(A1)
	RTS
.ini:	MOVE.L	(A1),D0
	BTST	#0,D4
	BNE.S	.rc
	MOVE.W	(A0),D0
	EXT.L	D0
	LSL.L	#8,D0
.rc:	MOVE.L	D0,4(A1)
	MOVE.L	D0,8(A1)
	RTS

flt_Tab:
	DC.W	flt_14_1-flt_Tab,flt_14_2-flt_Tab,flt_14_3-flt_Tab
	DC.W	flt_22_1-flt_Tab,flt_22_2-flt_Tab,flt_22_3-flt_Tab
	DC.W	flt_28_1-flt_Tab,flt_28_2-flt_Tab,flt_28_3-flt_Tab

;--- coefficient sets: c = 1/2 +- 2^-a +- 2^-b (sub = 1)
F_RA	SET	2
F_RS	SET	0
F_RB	SET	5
F_RT	SET	0
F_LA	SET	2
F_LS	SET	0
F_LB	SET	7
F_LT	SET	0
	FSET	14
F_RA	SET	3
F_RS	SET	0
F_RB	SET	6
F_RT	SET	0
F_LA	SET	4
F_LS	SET	0
F_LB	SET	6
F_LT	SET	0
	FSET	22
F_RA	SET	4
F_RS	SET	0
F_RB	SET	7
F_RT	SET	1
F_LA	SET	6
F_LS	SET	1
F_LB	SET	7
F_LT	SET	1
	FSET	28

	IFD	DEBUGAUTO
;--- capture: mode led rate states, in l/r, out l/r
FLT_CAPN	EQU	150
flt_DbgPre:
	MOVEM.L	D0-D1/A0-A1,-(A7)
	MOVE.L	flt_CapPtr,D0
	BEQ.S	.r
	MOVEA.L	D0,A1
	TST.B	3(A1)
	BNE.S	.r
	TST.B	ahi_FltRst		; states cleared in this half: not in the model
	BNE.S	.r
	ADDQ.W	#1,flt_CapCnt
	CMP.W	#FLT_CAPN,flt_CapCnt
	BNE.S	.r
	ST	flt_CapArm
	MOVE.B	ahi_FltMode,(A1)+
	MOVEQ	#0,D0
	BTST	#1,CIAA_PRA
	BNE.S	.nl
	MOVEQ	#1,D0
.nl:	MOVE.B	D0,(A1)+
	MOVE.B	ahi_FltLed,(A1)+
	CLR.B	(A1)+
	MOVE.W	mix_Rate,(A1)+
	CLR.W	(A1)+
	LEA	ahi_FltSt,A0
	MOVEQ	#5,D0
.s:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.s
	BSR.S	flt_DbgCopy
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1
	RTS
flt_DbgPost:
	MOVEM.L	D0-D1/A0-A1,-(A7)
	TST.B	flt_CapArm
	BEQ.S	.r
	SF	flt_CapArm
	MOVEA.L	flt_CapPtr,A1
	ST	3(A1)
	LEA	FLT_CAPOUT(A1),A1
	BSR.S	flt_DbgCopy
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1
	RTS
; task ctx (ahi setup, 020 only): capture buffer, not in the bss
flt_DbgAlloc:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	TST.L	flt_CapPtr
	BNE.S	.have
	MOVE.L	#FLT_CAPOUT+AHI_HALF*4,D0
	MOVE.L	#$10001,D1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-198,A6)
	MOVE.L	D0,flt_CapPtr
.have:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS
; a3 = end of left half -> both halves to (a1)+
flt_DbgCopy:
	LEA	-AHI_HALF*2(A3),A0
	MOVE.W	#AHI_HALF/2-1,D0
.l:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.l
	LEA	AHI_HALF*2(A3),A0
	MOVE.W	#AHI_HALF/2-1,D0
.m:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.m
	RTS
	ENDC
