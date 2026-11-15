; wide module, native screen: 4 or 8 channels, slider over the heads
; slider geometry: WB_* in bss41.i

; main loop: key wishes, view follows the screen (8 native, 4 rtg track
; view), slider back after a redraw of its rows
pt_WidePoll41:
	BSR.W	pt_ChnCells41
	TST.B	wide_On
	BEQ.W	.r
	TST.W	dat_SamplerActive
	BNE.W	pt_WBarSamp41
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.W	trk_HeadReq,D0
	BEQ.S	.nh
	CLR.W	trk_HeadReq
	SUBQ.W	#1,D0
	MOVEQ	#1,D1
	LSL.L	D0,D1
	EOR.L	D1,wide_Mute
	JSR	pt_WideBtns41		; buttons, mask and heads of this view
	MOVE.B	#10,trk_HeadHot		; rtg heads read again
.nh:	TST.B	wnat_Req
	BEQ.S	.nq
	MOVEQ	#0,D0
	MOVE.B	wnat_Req,D0
	EXT.W	D0
	CLR.B	wnat_Req
	JSR	pt_WideNat41
	BEQ.S	.nq
	ADD.W	trk_Grp,D0
	BSR.W	pt_WNatGrp41
.nq:	IFD	DEBUGAUTO
	TST.B	dbg_Wide4
	BNE.S	.b
	ENDC
	TST.B	wide_NoView
	BNE.S	.b
	BTST	#5,dat_ModeFlags
	BEQ.S	.n8
	TST.L	rtg_Proc		; 4 view: 8 unless the rtg wide layout
	BEQ.S	.v8
	TST.B	rtg_Wide
	BNE.S	.b
.v8:	MOVEQ	#8,D0
	JSR	pt_WideView41
	BRA.S	.x
.n8:	TST.L	rtg_Proc		; 8 view: rtg wide layout wants 4
	BEQ.S	.b
	TST.B	rtg_Wide
	BEQ.S	.b
	MOVEQ	#4,D0
	JSR	pt_WideView41
	BRA.S	.x
.b:	BSR.W	pt_WBarChk41
.x:	MOVEM.L	(A7)+,D0-D7/A0-A6
.r:	RTS

; z=1 left button down (the pointer may sit over the rtg stage)
pt_LmbRaw41:
	IFD	DEBUGAUTO
	JMP	dbg_LMB
	ELSE
	BTST	#6,CIAA_PRA
	RTS
	ENDC

; rtg track view, mouse (d0 = channel): head of another group, once a
; press; the main loop switches the channel
pt_TrkHeadReq41:
	MOVEM.L	D0,-(A7)
	BSR.S	pt_LmbRaw41
	BNE.S	.r
	TST.B	trk_HeadLatch
	BNE.S	.r
	ST	trk_HeadLatch
	ADDQ.W	#1,D0
	MOVE.W	D0,trk_HeadReq
.r:	MOVEM.L	(A7)+,D0
	RTS

; native view to group d0 (0 .. last)
pt_WNatGrp41:
	MOVEM.L	D0-D1,-(A7)
	TST.W	D0
	BPL.S	.p
	MOVEQ	#0,D0
.p:	MOVE.W	D0,D1
	JSR	pt_WideGMax41
	CMP.W	D0,D1
	BHI.S	.s
	MOVE.W	D1,D0
.s:	JSR	pt_TrkGrpSet
	MOVEM.L	(A7)+,D0-D1
	RTS

; tab, native view (from pt_TrkTab): past the last shown track the view
; moves one group on, the cursor stays on the next channel; shift: before
; track 1 one group back; both wrap
pt_WNatTab41:
	MOVEQ	#0,D1
	MOVE.W	dat_CursorColumn,D1
	DIVU	#6,D1			; track in the view
	JSR	pt_TrkN41
	TST.W	dat_KeyQual1		; shift
	BNE.S	.bk
	ADDQ.W	#1,D1
	CMP.W	D0,D1
	BCS.S	.r			; inside the view: pt's tab
	JSR	pt_WideGMax41
	CMP.W	trk_Grp,D0
	BLS.S	.w0
	MOVE.W	trk_Grp,D0
	ADDQ.W	#1,D0
	SUBQ.W	#4,D1
	BRA.S	.set
.w0:	MOVEQ	#0,D0			; past the last channel: track 1
	MOVEQ	#0,D1
	BRA.S	.set
.bk:	TST.W	D1
	BNE.S	.r
	MOVE.W	trk_Grp,D0
	SUBQ.W	#1,D0
	MOVEQ	#3,D1
	TST.W	D0
	BPL.S	.set
	JSR	pt_WideGMax41		; before track 1: the last channel
	MOVEQ	#-1,D1
.set:	BSR.S	pt_WNatGrp41
	TST.W	D1
	BPL.S	.c
	JSR	pt_TrkN41
	MOVE.W	D0,D1
	SUBQ.W	#1,D1
.c:	MULU	#6,D1
	MOVE.W	D1,dat_CursorColumn
	ADDQ.L	#4,A7			; tab done
	JMP	pt_ReturnFromPlay
.r:	RTS

; head text (pt_SaveRegsProcess): d6 = slot, a1 -> digit of "TRK#x" /
; "TRACK #x"; native wide view: the channel, two digits from 10. d0 kept
pt_TrkHeadNum41:
	BTST	#5,dat_ModeFlags
	BNE.S	.four
	MOVE.B	#'K',-2(A1)
	MOVE.B	#'#',-1(A1)
	JSR	pt_WideNat41
	BEQ.S	.d
	BSR.S	.chan
	CMP.W	#8,D6
	BLS.S	.d
	ADDQ.W	#1,D6
	DIVU	#10,D6
	MOVE.B	#'#',-2(A1)
	ADD.B	#'0',D6
	MOVE.B	D6,-1(A1)
	SWAP	D6
	ADD.B	#'0',D6
	MOVE.B	D6,(A1)
	RTS
.four:	JSR	pt_WideNat41
	BEQ.S	.d
	BSR.S	.chan
	CMP.W	#8,D6
	BLS.S	.d
	ADDQ.W	#1,D6
	DIVU	#10,D6
	ADD.B	#'0',D6
	MOVE.B	D6,(A1)
	SWAP	D6
	ADD.B	#'0',D6
	MOVE.B	D6,1(A1)
	RTS
.d:	ADD.B	#'1',D6
	MOVE.B	D6,(A1)
	RTS
; d6 = slot -> channel (0 based)
.chan:	MOVE.L	D0,-(A7)
	MOVE.W	trk_Grp,D0
	LSL.W	#2,D0
	AND.L	#$ffff,D6
	ADD.W	D0,D6
	MOVE.L	(A7)+,D0
	RTS

; hook in pt_AgusRun: a0 = first channel of the vu copy, a1 = vu slot 1,
; d7 = count - 1 (4 or 8 tracks of the view, from its group on)
pt_WideVuSet41:
	MOVEA.L	agus_ChBase,A0
	LEA	dat_Channel1,A1
	MOVE.L	D0,-(A7)
	MOVEQ	#0,D0
	MOVE.W	trk_Grp,D0
	MULU	#4*n_SIZEOF,D0
	ADDA.L	D0,A0
	MOVE.L	(A7)+,D0
	MOVEQ	#3,D7
	BTST	#5,dat_ModeFlags
	BNE.S	.r
	MOVEQ	#7,D7
.r:	RTS

;--- slider
; a0/a1 = planes 0/1 at the first slider byte
pt_WBarPl41:
	LEA	SECSTRT_2+WB_Y0*80+WB_B0,A0
	LEA	chip_ScreenBitplanes+WB_Y0*80+WB_B0,A1
	RTS

; d4 = knob start, d5 = knob end (bytes in the bar): the view wide of
; wide_Ch, trk_Grp along the travel
pt_WBarKnob41:
	MOVE.L	D0,-(A7)
	MOVEQ	#0,D5
	MOVE.W	#WB_NB*8,D5
	BTST	#5,dat_ModeFlags
	BEQ.S	.w
	LSR.W	#1,D5
.w:	DIVU	wide_Ch,D5
	CMP.W	#WB_KMIN,D5
	BCC.S	.k
	MOVEQ	#WB_KMIN,D5
.k:	MOVEQ	#WB_NB,D4
	SUB.W	D5,D4			; travel
	BPL.S	.t
	MOVEQ	#0,D4
.t:	MULU	trk_Grp,D4
	JSR	pt_WideGMax41
	TST.W	D0
	BEQ.S	.z
	DIVU	D0,D4
	BRA.S	.s
.z:	MOVEQ	#0,D4
.s:	AND.L	#$ffff,D4
	TST.B	wbar_DrOn
	BEQ.S	.n
	MOVE.W	wbar_DrK,D4		; dragged: where the pointer holds it
.n:	AND.L	#$ffff,D5
	ADD.W	D4,D5
	MOVE.L	(A7)+,D0
	RTS

; d6 = half (0 rows 136-137, 1 rows 138-139), d5 = 0: rows -> wbar_Save,
; else back
pt_WBarCopy41:
	MOVEM.L	D0-D2/A0-A3,-(A7)
	BSR.S	pt_WBarPl41
	LEA	wbar_Save,A2
	TST.W	D6
	BEQ.S	.h
	LEA	2*80(A0),A0
	LEA	2*80(A1),A1
	LEA	2*WB_NB(A2),A2
.h:	LEA	WB_PL(A2),A3
	MOVEQ	#1,D2
.r:	MOVEQ	#WB_NB-1,D0
.c:	TST.W	D5
	BNE.S	.b
	MOVE.B	(A0)+,(A2)+
	MOVE.B	(A1)+,(A3)+
	BRA.S	.n
.b:	MOVE.B	(A2)+,(A0)+
	MOVE.B	(A3)+,(A1)+
.n:	DBF	D0,.c
	LEA	80-WB_NB(A0),A0
	LEA	80-WB_NB(A1),A1
	DBF	D2,.r
	MOVEM.L	(A7)+,D0-D2/A0-A3
	RTS

; z=1: first row of half d6, plane 0, still as drawn
pt_WBarSame41:
	MOVEM.L	D0/A0-A1,-(A7)
	LEA	SECSTRT_2+WB_Y0*80+WB_B0,A0
	LEA	wbar_DrA,A1
	TST.W	D6
	BEQ.S	.h
	LEA	2*80(A0),A0
	LEA	wbar_DrB,A1
.h:	MOVEQ	#WB_NB-1,D0
.l:	CMPM.B	(A0)+,(A1)+
	DBNE	D0,.l
	MOVEM.L	(A7)+,D0/A0-A1		; flags stay
	RTS

; halves painted over: their flags go
pt_WBarVal41:
	MOVEM.L	D6,-(A7)
	MOVEQ	#0,D6
	TST.B	wbar_OkA
	BEQ.S	.b
	BSR.S	pt_WBarSame41
	BEQ.S	.b
	SF	wbar_OkA
.b:	MOVEQ	#1,D6
	TST.B	wbar_OkB
	BEQ.S	.r
	BSR.S	pt_WBarSame41
	BEQ.S	.r
	SF	wbar_OkB
.r:	MOVEM.L	(A7)+,D6
	RTS

; pens from wbar_Save: light row 137, face row 136 (even px of the
; stipple), dark row 138, all at x 300
pt_WBarPens41:
	MOVEM.L	D0-D5/A0,-(A7)
	MOVEQ	#WB_NB+31,D0
	BSR.S	.pen
	MOVE.B	D1,D3
	MOVEQ	#31,D0
	BSR.S	.pen
	MOVE.B	D1,D4
	MOVE.W	#2*WB_NB+31,D0
	BSR.S	.pen
	MOVE.B	D1,D5
	LEA	wbar_Sel,A0
	MOVEQ	#0,D0
.sl:	BTST	D0,D3
	SNE	(A0)+
	BTST	D0,D4
	SNE	(A0)+
	BTST	D0,D5
	SNE	(A0)+
	ADDQ.W	#1,D0
	CMP.W	#2,D0
	BCS.S	.sl
	MOVEM.L	(A7)+,D0-D5/A0
	RTS
; d0 = index in wbar_Save -> d1 = pen of bit 3 (bit p = plane p)
.pen:	LEA	wbar_Save,A0
	ADDA.W	D0,A0
	MOVEQ	#0,D1
	BTST	#3,(A0)
	BEQ.S	.p1
	ADDQ.B	#1,D1
.p1:	BTST	#3,WB_PL(A0)
	BEQ.S	.p2
	ADDQ.B	#2,D1
.p2:	RTS

; rows back as they were (halves that still show the slider)
pt_WBarOff41:
	TST.B	wbar_OkA
	BNE.S	.go
	TST.B	wbar_OkB
	BEQ.S	.r
.go:	MOVEM.L	D0-D1/D5-D6,-(A7)
	MOVEQ	#0,D6
	TST.B	wbar_OkA
	BEQ.S	.b
	SF	wbar_OkA
	BSR.W	pt_WBarSame41
	BNE.S	.b
	MOVEQ	#1,D5
	BSR.W	pt_WBarCopy41
.b:	MOVEQ	#1,D6
	TST.B	wbar_OkB
	BEQ.S	.x
	SF	wbar_OkB
	BSR.W	pt_WBarSame41
	BNE.S	.x
	MOVEQ	#1,D5
	BSR.W	pt_WBarCopy41
.x:	MOVEM.L	(A7)+,D0-D1/D5-D6
.r:	RTS

; a dat_148D image (pattern background, sampler) was painted: it starts
; at row 138, the slider's lower half is gone
pt_WBarGfx41:
	SF	wbar_OkB
	RTS

; sampler: its screen has no slider; the upper half goes back, once
pt_WBarSamp41:
	TST.B	wbar_OkA
	BNE.S	.go
	TST.B	wbar_OkB
	BEQ.S	.r
.go:	SF	wbar_OkB
	BRA.S	pt_WBarOff41
.r:	RTS

; slider still on screen? rows painted over: save them again, draw
pt_WBarChk41:
	TST.W	dat_SamplerActive
	BNE.S	.r
	JSR	pt_WideNat41
	BNE.S	.nat
	BRA.W	pt_WBarOff41		; no native slider here
.nat:	BSR.W	pt_WBarVal41
	TST.B	wbar_OkA
	BEQ.S	pt_WBar41
	TST.B	wbar_OkB
	BEQ.S	pt_WBar41
	MOVEM.L	D4-D5,-(A7)		; knob moved (group, drag, count)
	BSR.W	pt_WBarKnob41
	CMP.W	wbar_K0,D4
	BNE.S	.m
	CMP.W	wbar_K1,D5
.m:	MOVEM.L	(A7)+,D4-D5		; flags stay
	BNE.S	pt_WBar41
.r:	RTS

; slider in the frame lines over the heads: groove sunk (dark, light
; bottom), knob raised (light top, face, dark bottom, grip in the middle)
pt_WBar41:
	TST.W	dat_SamplerActive
	BNE.W	.r
	JSR	pt_WideNat41
	BEQ.W	.r
	MOVEM.L	D0-D7/A0-A4,-(A7)
	BSR.W	pt_WBarVal41
	MOVEQ	#0,D6
	TST.B	wbar_OkA
	BNE.S	.sb
	MOVEQ	#0,D5
	BSR.W	pt_WBarCopy41
.sb:	MOVEQ	#1,D6
	TST.B	wbar_OkB
	BNE.S	.sp
	MOVEQ	#0,D5
	BSR.W	pt_WBarCopy41
.sp:	BSR.W	pt_WBarPens41
	BSR.W	pt_WBarKnob41
	MOVE.W	D4,wbar_K0
	MOVE.W	D5,wbar_K1
	ADD.W	D4,D5
	LSR.W	#1,D5
	MOVE.W	D5,wbar_KN
	BSR.W	pt_WBarPl41
	MOVEQ	#0,D7			; row
.row:	MOVEQ	#0,D3			; byte
.b:	MOVEQ	#0,D1			; d1 light, d2 dark mask
	MOVEQ	#0,D2
	CMP.W	wbar_K0,D3
	BCS.S	.g
	CMP.W	wbar_K1,D3
	BCC.S	.g
	TST.W	D7
	BEQ.S	.ll
	CMP.W	#WB_ROWS-1,D7
	BEQ.S	.dd
	CMP.W	wbar_K0,D3
	BNE.S	.k1
	MOVE.B	#$80,D1
.k1:	CMP.W	wbar_KN,D3
	BNE.S	.k2
	MOVE.B	#$44,D1
	MOVE.B	#$88,D2
.k2:	MOVE.W	wbar_K1,D0
	SUBQ.W	#1,D0
	CMP.W	D0,D3
	BNE.S	.put
	MOVEQ	#1,D2
	BRA.S	.put
.g:	CMP.W	#WB_ROWS-1,D7
	BEQ.S	.ll
.dd:	MOVEQ	#-1,D2
	BRA.S	.put
.ll:	MOVEQ	#-1,D1
.put:	BSR.S	.px
	ADDQ.W	#1,D3
	CMP.W	#WB_NB,D3
	BCS.S	.b
	LEA	80(A0),A0
	LEA	80(A1),A1
	ADDQ.W	#1,D7
	CMP.W	#WB_ROWS,D7
	BCS.S	.row
	BSR.W	pt_WBarPl41		; first rows, plane 0, as drawn
	LEA	wbar_DrA,A2
	BSR.S	.cd
	LEA	2*80(A0),A0
	LEA	wbar_DrB,A2
	BSR.S	.cd
	ST	wbar_OkA
	ST	wbar_OkB
	MOVEM.L	(A7)+,D0-D7/A0-A4
.r:	RTS
.cd:	MOVEQ	#WB_NB-1,D0
.cc:	MOVE.B	(A0,D0.W),(A2,D0.W)
	DBF	D0,.cc
	RTS
; d1 light, d2 dark mask -> byte d3 of planes a0/a1 in the pens
.px:	MOVE.B	D1,D4
	OR.B	D2,D4
	NOT.B	D4			; face
	LEA	wbar_Sel,A3
	MOVEA.L	A0,A4
	BSR.S	.pl
	MOVEA.L	A1,A4
.pl:	MOVE.B	(A3)+,D5
	AND.B	D1,D5
	MOVE.B	(A3)+,D6
	AND.B	D4,D6
	OR.B	D6,D5
	MOVE.B	(A3)+,D6
	AND.B	D2,D6
	OR.B	D6,D5
	MOVE.B	D5,(A4,D3.W)
	RTS

; start of pt_TrkHit41 (d0 = x, d1 = y): lmb on the slider -> page or
; drag, z=0; else z=1, d0/d1 kept
pt_WBarHit41:
	JSR	pt_WideNat41
	BEQ.S	.no
	CMP.W	#WB_Y0-1,D1
	BLT.S	.no
	CMP.W	#WB_Y0+WB_ROWS-1,D1	; row 140 on: the heads
	BGT.S	.no
	CMP.W	#WB_B0*8,D0
	BLO.S	.no
	CMP.W	#(WB_B0+WB_NB)*8,D0
	BLO.S	.y
.no:	ORI	#4,CCR			; z=1
	RTS
.y:	MOVEM.L	D0-D7/A0-A6,-(A7)
	LSR.W	#3,D0
	SUB.W	#WB_B0,D0		; byte in the bar
	BSR.W	pt_WBarKnob41
	CMP.W	D4,D0
	BCS.W	.pl
	CMP.W	D5,D0
	BCC.W	.pr
	SUB.W	D4,D0
	MOVE.W	D0,D7			; grab
	MOVEQ	#WB_NB,D6
	ADD.W	D4,D6
	SUB.W	D5,D6			; travel
.dr:	JSR	pt_ScreenDragUpdate	; test driver steps, screen drag
	JSR	pt_UpdateMousePos
	LMB
	BNE.S	.dn
	MOVE.W	dat_EditDigitValue,D0
	LSR.W	#3,D0
	SUB.W	#WB_B0,D0
	SUB.W	D7,D0			; knob start wanted
	BPL.S	.d0
	MOVEQ	#0,D0
.d0:	CMP.W	D6,D0
	BLS.S	.d1
	MOVE.W	D6,D0
.d1:	MOVE.W	D0,D3
	MOVE.W	D0,wbar_DrK		; knob under the pointer
	ST	wbar_DrOn
	JSR	pt_WideGMax41
	MULU	D0,D3
	MOVEQ	#0,D0
	MOVE.W	D6,D0
	LSR.W	#1,D0
	ADD.L	D0,D3			; rounded
	TST.W	D6
	BEQ.S	.dw
	DIVU	D6,D3
	MOVE.W	D3,D0
	CMP.W	trk_Grp,D0
	BEQ.S	.dw
	BSR.W	pt_WNatGrp41
.dw:	BSR.W	pt_WBarChk41
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-270,A6)		; WaitTOF
	BRA.S	.dr
.pl:	JSR	pt_WideW41		; beside the knob: a page
	LSR.W	#2,D0
	NEG.W	D0
	BRA.S	.pg
.pr:	JSR	pt_WideW41
	LSR.W	#2,D0
.pg:	ADD.W	trk_Grp,D0
	BSR.W	pt_WNatGrp41
	JSR	pt_WaitMouseRelease
.dn:	SF	wbar_DrOn		; knob snaps to the group
	BSR.W	pt_WBarChk41
	MOVEM.L	(A7)+,D0-D7/A0-A6
	ANDI	#$fb,CCR		; z=0
	RTS

;--- 4/8 cells next to clear/setup: a wide module shows its count there
; (tens above, ones below), a click opens setup; else pt's cells
CC_Y		EQU	47		; first glyph row of the upper cell

pt_ChnCells41:
	CMPI.W	#1,dat_UIMode
	BNE.S	.r
	MOVEM.L	D0-D6/A0-A2,-(A7)
	TST.B	chc_On
	BEQ.S	.no
	LEA	chc_Drw,A2
	BSR.W	pt_CcSame41
	BEQ.S	.on
	SF	chc_On			; painted over: pt's cells again
	BRA.S	.no
.on:	TST.B	wide_On
	BEQ.S	.bk
	MOVE.W	wide_Ch,D0
	CMP.W	chc_N,D0
	BEQ.S	.x
	BSR.S	.draw
	BRA.S	.x
.bk:	LEA	chc_Org,A2
	BSR.W	pt_CcPut41
	SF	chc_On
	BRA.S	.x
.no:	TST.B	wide_On
	BEQ.S	.x
	LEA	chc_Org,A2
	BSR.W	pt_CcGet41
	BSR.S	.draw
	ST	chc_On
.x:	MOVEM.L	(A7)+,D0-D6/A0-A2
.r:	RTS
.draw:	MOVEQ	#0,D0
	MOVE.W	wide_Ch,D0
	MOVE.W	D0,chc_N
	DIVU	#10,D0
	MOVEQ	#0,D1
	BSR.S	.dig
	SWAP	D0
	MOVEQ	#6,D1
	BSR.S	.dig
	LEA	chc_Drw,A2
	BRA.W	pt_CcGet41
; d0.w = digit, d1 = first row: glyph of the large font, text pen 1,
; shadow 3 down right, ground 2
.dig:	MOVEM.L	D0/D6/A2,-(A7)
	LEA	chip_FontLarge+16*8,A2
	AND.W	#15,D0
	LSL.W	#3,D0
	ADDA.W	D0,A2
	MOVEQ	#0,D3
	MOVEQ	#6-1,D6
.gl:	MOVEQ	#0,D4
	TST.W	D6
	BEQ.S	.sh
	MOVE.B	(A2)+,D4
.sh:	MOVE.W	D3,D5
	LSR.W	#1,D5
	MOVE.W	D4,D3
	MOVE.W	D4,D2
	NOT.W	D2
	AND.W	D2,D5			; shadow
	OR.W	D4,D5			; plane 0: ink and shadow
	BSR.S	pt_CcAdr41
	LSL.W	#4,D5			; x 308
	LSL.W	#4,D4
	MOVE.W	(A0),D2
	AND.W	#$e001,D2		; cell inside: x 307-318
	OR.W	D5,D2
	MOVE.W	D2,(A0)
	NOT.W	D4
	AND.W	#$1ffe,D4		; plane 1: all but the ink
	MOVE.W	(A1),D2
	AND.W	#$e001,D2
	OR.W	D4,D2
	MOVE.W	D2,(A1)
	ADDQ.W	#1,D1
	DBF	D6,.gl
	MOVEM.L	(A7)+,D0/D6/A2
	RTS

; d1 = glyph row 0-11 (6 a cell) -> a0/a1 = planes 0/1 at x 304
pt_CcAdr41:
	MOVE.L	D2,-(A7)
	MOVE.W	D1,D2
	CMP.W	#6,D2
	BLO.S	.u
	ADDQ.W	#11-6,D2		; lower cell
.u:	ADD.W	#CC_Y,D2
	MULU	#80,D2
	LEA	SECSTRT_2+38,A0
	ADDA.L	D2,A0
	LEA	chip_ScreenBitplanes+38,A1
	ADDA.L	D2,A1
	MOVE.L	(A7)+,D2
	RTS

; glyph rows of both cells -> a2 / a2 -> screen / z=1 screen as a2
pt_CcGet41:
	MOVEQ	#0,D1
.l:	BSR.S	pt_CcAdr41
	MOVE.W	(A0),(A2)+
	MOVE.W	(A1),(A2)+
	ADDQ.W	#1,D1
	CMP.W	#12,D1
	BLO.S	.l
	RTS

pt_CcPut41:
	MOVEQ	#0,D1
.l:	BSR.S	pt_CcAdr41
	MOVE.W	(A2)+,(A0)
	MOVE.W	(A2)+,(A1)
	ADDQ.W	#1,D1
	CMP.W	#12,D1
	BLO.S	.l
	RTS

pt_CcSame41:
	MOVEQ	#0,D1
.l:	BSR.S	pt_CcAdr41
	MOVE.W	(A0),D2
	CMP.W	(A2)+,D2
	BNE.S	.r
	MOVE.W	(A1),D2
	CMP.W	(A2)+,D2
	BNE.S	.r
	ADDQ.W	#1,D1
	CMP.W	#12,D1
	BLO.S	.l
.r:	RTS

; click on the 4/8 cells: wide module -> setup (chan), else nothing
pt_ChnCellBtn41:
	TST.B	wide_On
	BEQ.S	.r
	JMP	pt_BtnMainSetup
.r:	RTS
