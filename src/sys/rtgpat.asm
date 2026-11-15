; rtg pattern renderer: the pattern section drawn on the card
; ring of row slots in a card bitmap (friend of the window), shown with
; two blits; a slot is drawn again only when its row, style or data
; changed; rows from pt's 1 bit pattern buffer over a chunky template,
; the cursor bar from the mirror (native lines with sprites)
RPR_MAXW	EQU	4096
RPR_BARTOP	EQU	197		; native lines of the cursor bar (white top)
RPR_BAREND	EQU	205
RPR_TPLROW	EQU	150		; native line of an empty pattern line
RPR_MAXN	EQU	(RTG_MAXOUT-RTG_PATTOP)/8	; slots at most
	IFGT	RPR_MAXN-80
	FAIL	"X20_RPRSLOT too small"
	ENDC

; pt draws the whole pattern (pt_PatViewDrawAll entry)
pt_PatAll41:
	ADDQ.L	#1,rtg_PatGen
	TST.W	dat_RecordMode		; replaced instruction, flags for the caller
	RTS

; pt draws one cell (pt_PatViewDrawCell): its row changed
pt_PatCell41:
	MOVEA.L	A0,A6			; replaced instructions
	LEA	dat_PeriodTable,A2
	MOVEQ	#0,D0
	MOVE.W	dat_TextBytePos,D0
	SUB.W	#$3ca2,D0		; row 0 of the buffer
	BMI.S	.r
	DIVU	#640,D0
	CMP.W	#63,D0
	BHI.S	.r
	LEA	rtg_RowDirty,A3
	ST	(A3,D0.W)		; a3 is set again by the caller
.r:	RTS

; window: renderer possible (locked aspect, lut writes, card window)
; -> z=0 yes
pt_RprOk:
	TST.B	rpr_Fail
	BNE.S	.no
	TST.B	rtg_RunWin
	BEQ.S	.yes			; card screen: always integer
	CMPI.B	#2,rtg_Scale1x
	BEQ.S	.no
	TST.L	rtg_LutBuf
	BEQ.S	.no
.yes:
	MOVEQ	#1,D0
	RTS
.no:	MOVEQ	#0,D0
	RTS

; geometry of the window changed: bitmap and buffer for it
pt_RprAlloc:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	DK	'A'
	BSR.W	pt_RprFree
	SF	rpr_Fail
	BSR.S	pt_RprOk
	BEQ.W	.r
	TST.B	rtg_RunWin
	BNE.S	.win
	MOVE.W	#640,rpr_W		; card screen: 1x, lines doubled or not
	MOVE.W	#1,rpr_XF
	MOVEQ	#1,D1
	TST.B	rtg_Double
	BEQ.S	.yf
	MOVEQ	#2,D1
	BRA.S	.yf
.win:	MOVE.W	rtg_WinW,rpr_W
	MOVEQ	#0,D0
	MOVE.W	rtg_WinW,D0
	TST.B	rtg_Wide
	BEQ.S	.xn
	DIVU	rwd_W,D0		; wide: x factor of the picture width
	BRA.S	.xf
.xn:	DIVU	#640,D0			; x factor
.xf:
	BEQ.W	.fail
	MOVE.W	D0,rpr_XF
	MOVEQ	#0,D1
	MOVE.W	rtg_WinH,D1
	DIVU	rtg_OutH,D1		; y factor
	BEQ.W	.fail
.yf:	MOVE.W	D1,rpr_YF
	LSL.W	#3,D1
	MOVE.W	D1,rpr_RowH		; output lines per row
	MOVE.W	rtg_OutH,D0
	SUB.W	#RTG_PATTOP+2,D0
	LSR.W	#3,D0
	MOVE.W	D0,rpr_N		; slots
	MOVE.W	rtg_YtOut,D0
	SUB.W	#RTG_PATTOP,D0
	LSR.W	#3,D0
	MOVE.W	D0,rpr_C		; slot of the cursor row
	MOVEA.L	ABSEXECBASE.W,A6
	MOVEQ	#9,D0			; slot or cursor bar (9 lines)
	MULU	rpr_YF,D0
	MULU	rpr_W,D0
	MOVE.L	D0,rpr_SBSize
	MOVEQ	#1,D1			; MEMF_PUBLIC
	JSR	(-198,A6)		; AllocMem
	MOVE.L	D0,rpr_SBuf
	BEQ.W	.fail
	MOVEA.L	rtg_Screen,A0		; friend: screen or window bitmap
	LEA	84(A0),A0		; Screen->RastPort
	TST.B	rtg_RunWin
	BEQ.S	.fb
	MOVEA.L	rtg_Window,A0
	MOVEA.L	50(A0),A0		; RPort
.fb:	MOVEA.L	4(A0),A0		; BitMap (friend)
	MOVEA.L	A0,A4
	MOVEA.L	dat_GfxLibBase,A6
	MOVE.L	A0,-(A7)
	MOVEQ	#4,D1			; BMA_DEPTH
	JSR	(-960,A6)		; GetBitMapAttr
	MOVE.L	D0,D2
	MOVEA.L	(A7)+,A0
	MOVEQ	#0,D0
	MOVE.W	rpr_W,D0
	MOVEQ	#0,D1
	MOVE.W	rpr_N,D1
	MULU	rpr_RowH,D1
	MOVEQ	#$10,D3			; BMF_MINPLANES: friend format
	JSR	(-918,A6)		; AllocBitMap
	MOVE.L	D0,rpr_BM
	BEQ.W	.fail
	X20LEA	X20_RPRRP,A1
	JSR	(-198,A6)		; InitRastPort
	X20LEA	X20_RPRRP,A1
	MOVE.L	rpr_BM,4(A1)		; rp_BitMap
	MOVEQ	#0,D0			; pattern area put together off screen
	MOVE.W	rpr_W,D0		; (none: straight to the picture)
	MOVEQ	#0,D1
	MOVE.W	rpr_N,D1
	MULU	rpr_RowH,D1
	MOVE.W	D1,rpr_H2
	MOVEA.L	A4,A0
	JSR	(-918,A6)		; AllocBitMap
	MOVE.L	D0,rpr_BM2
	BEQ.S	.n2
	X20LEA	X20_RPRRP2,A1
	JSR	(-198,A6)		; InitRastPort
	X20LEA	X20_RPRRP2,A1
	MOVE.L	rpr_BM2,4(A1)
.n2:
	BSR.W	pt_RprInval
	ST	rpr_Force
	BRA.S	.r
.fail:	ST	rpr_Fail
	BSR.W	pt_RprFree
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

pt_RprFree:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVE.L	rpr_BM,D0
	BEQ.S	.nb
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-228,A6)		; WaitBlit
	MOVEA.L	rpr_BM,A0
	JSR	(-924,A6)		; FreeBitMap
	CLR.L	rpr_BM
	MOVE.L	rpr_BM2,D0
	BEQ.S	.nb
	MOVEA.L	D0,A0
	JSR	(-924,A6)
	CLR.L	rpr_BM2
.nb:	MOVE.L	rpr_SBuf,D0
	BEQ.S	.r
	MOVEA.L	D0,A1
	MOVE.L	rpr_SBSize,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-210,A6)		; FreeMem
	CLR.L	rpr_SBuf
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

; every slot drawn again
pt_RprInval:
	MOVEM.L	D0/A0,-(A7)
	X20LEA	X20_RPRSLOT,A0
	MOVEQ	#RPR_MAXN-1,D0
.l:	MOVE.L	#-1,(A0)+
	DBF	D0,.l
	MOVE.W	#-999,rpr_LastPR
	CLR.W	rpr_Head		; ring of a new size: old start may lie outside
	SF	rwd_BarOk
	MOVEM.L	(A7)+,D0/A0
	RTS

; mirror, native line in rtg_LineBuf (rtg_NatRow), before sprites:
; empty pattern line -> template (text plane masked out)
pt_RprCapPre:
	MOVEM.L	D0/A0-A1,-(A7)
	MOVE.W	rtg_NatRow,D0		; bar line: scroll column without pt's thumb
	SUB.W	#RPR_BARTOP,D0
	CMP.W	#RPR_BAREND-RPR_BARTOP,D0
	BHI.S	.nb
	BSR.W	pt_RwdPre
	LSL.W	#4,D0
	X20LEA	X20_RPRBARCOL,A1
	ADDA.W	D0,A1
	MOVEA.L	rtg_LineBuf,A0
	LEA	624(A0),A0
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
.nb:	MOVE.W	rtg_NatRow,D0		; lines 150 (even) and 151 (odd)
	SUB.W	#RPR_TPLROW,D0
	CMP.W	#1,D0
	BHI.W	.x
	MULU	#640,D0
	RMLEA	RM_TPL,A1
	ADDA.L	D0,A1
	MOVE.L	D1,-(A7)
	MOVEA.L	rtg_LineBuf,A0
	MOVE.W	#640/4-1,D0
.l:	MOVE.L	(A0)+,D1
	ANDI.L	#$fbfbfbfb,D1		; plane 3 = pattern text
	CMP.L	(A1),D1
	BEQ.S	.s
	ST	rpr_TplNew		; template changed: every slot again
.s:	MOVE.L	D1,(A1)+
	DBF	D0,.l
	MOVE.L	(A7)+,D1
.x:	MOVEM.L	(A7)+,D0/A0-A1
	RTS

; after sprites: cursor bar lines as shown (text, edit cursor)
pt_RprCapPost:
	MOVEM.L	D0/A0-A1,-(A7)
	MOVE.W	rtg_NatRow,D0
	SUB.W	#RPR_BARTOP,D0
	BMI.S	.r
	CMP.W	#RPR_BAREND-RPR_BARTOP,D0
	BHI.S	.r
	MOVE.W	D0,-(A7)
	LSL.W	#4,D0			; scroll column as before the sprites
	X20LEA	X20_RPRBARCOL,A1
	ADDA.W	D0,A1
	MOVEA.L	rtg_LineBuf,A0
	LEA	624(A0),A0
	MOVE.L	(A1)+,(A0)+
	MOVE.L	(A1)+,(A0)+
	MOVE.L	(A1)+,(A0)+
	MOVE.L	(A1)+,(A0)+
	MOVE.W	(A7)+,D0
	MULU	#640,D0
	RMLEA	RM_BAR,A1
	ADDA.L	D0,A1
	MOVEA.L	rtg_LineBuf,A0
	MOVE.W	#640/4-1,D0
.l:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.l
	ADDQ.W	#1,rpr_BarGen
.r:	MOVEM.L	(A7)+,D0/A0-A1
	RTS

; native line d0 inside the pattern section while the renderer runs:
; z=0 the mirror converts it (no write), z=1 skip
pt_RprNative:
	CMP.W	#RPR_TPLROW,D0
	BEQ.S	.yes
	CMP.W	#RPR_TPLROW+1,D0
	BEQ.S	.yes
	CMP.W	#RPR_BARTOP,D0
	BLO.S	.no
	CMP.W	#RPR_BAREND,D0
	BHI.S	.no
.yes:	MOVE.L	D1,-(A7)
	MOVEQ	#1,D1
	MOVEM.L	(A7)+,D1		; flags stay
	RTS
.no:	CMP.B	D0,D0
	RTS

; build slot content: d0 = pattern row (may be outside 0-63), d1 = style
; (1 normal, 2 cursor bar, 3 above the bar) -> rpr_Line (8 x 640)
pt_RprBuild:
	TST.B	rtg_Wide
	BNE.W	pt_RwdBuild
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.W	D1,D7			; style
	RMLEA	RM_LINE,A1
	CMP.W	#2,D7
	BNE.S	.text
	RMLEA	RM_BAR+640,A0		; bar: native lines 198-205
	MOVE.W	#8*640/4-1,D0
.bc:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.bc
	BRA.W	.r
.text:	MOVEQ	#0,D6			; line 0..7
	MOVE.W	D0,D5			; row
.ln:	RMLEA	RM_TPL,A2		; template of the line parity
	BTST	#0,D6
	BEQ.S	.ev
	LEA	640(A2),A2
.ev:
	CMP.W	#3,D7			; above the bar: line 7 = bar top
	BNE.S	.t1
	CMP.W	#7,D6
	BNE.S	.t1
	RMLEA	RM_BAR,A0
	MOVE.W	#640/4-1,D0
.tc:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.tc
	BRA.S	.nl
.t1:	TST.W	D5			; rows outside 0-63: empty line
	BMI.S	.empty
	CMP.W	#63,D5
	BHI.S	.empty
	MOVE.W	D5,D0
	LSL.W	#3,D0
	ADD.W	D6,D0
	ADD.W	#RTG_PATCUR-4,D0	; buffer line
	MULU	#80,D0
	MOVEA.L	dat_ScreenBuf2Ptr,A0
	ADDA.L	D0,A0
	X20LEA	X20_RTGP2C,A3		; byte -> 8 bytes 0/1
	MOVEQ	#79,D4
.bx:	MOVEQ	#0,D0
	MOVE.B	(A0)+,D0
	BEQ.S	.b0
	LSL.W	#3,D0
	MOVE.L	(A3,D0.W),D1
	MOVE.L	4(A3,D0.W),D2
	LSL.L	#2,D1			; text pixel: index + 4
	LSL.L	#2,D2
	ADD.L	(A2)+,D1
	ADD.L	(A2)+,D2
	MOVE.L	D1,(A1)+
	MOVE.L	D2,(A1)+
	DBF	D4,.bx
	BRA.S	.nl
.b0:	MOVE.L	(A2)+,(A1)+
	MOVE.L	(A2)+,(A1)+
	DBF	D4,.bx
	BRA.S	.nl
.empty:	MOVE.W	#640/4-1,D0
.ec:	MOVE.L	(A2)+,(A1)+
	DBF	D0,.ec
.nl:	ADDQ.W	#1,D6
	CMP.W	#8,D6
	BLO.W	.ln
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; rpr_Line -> scaled -> slot d0 of the card bitmap
pt_RprPut:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.W	D0,D7
	MOVEA.L	rpr_SBuf,A1
	RMLEA	RM_LINE,A0
	MOVE.W	#640,D5
	TST.B	rtg_Wide
	BEQ.S	.sw
	WMLEA	WM_LINE,A0
	MOVE.W	rwd_W,D5
.sw:	MOVEQ	#8,D6
	BSR.W	pt_RprScale
	TST.B	rtg_RunWin
	BNE.S	.lut
	X20LEA	X20_RPRRP,A0		; card screen: clut indices as they are
	MOVEQ	#0,D0			; xstart
	MOVEQ	#0,D1
	MOVE.W	D7,D1
	MULU	rpr_RowH,D1		; ystart
	MOVE.L	#639,D2			; xstop
	MOVEQ	#0,D3
	MOVE.W	rpr_RowH,D3
	ADD.L	D1,D3
	SUBQ.L	#1,D3			; ystop
	MOVEA.L	rpr_SBuf,A2
	MOVE.L	#640,D4			; bytesperrow
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-1056,A6)		; WriteChunkyPixels
	BRA.S	.out
.lut:	BSR.W	pt_RprCTab
	MOVEA.L	rpr_SBuf,A0		; srcRect
	MOVEQ	#0,D0			; SrcX
	MOVEQ	#0,D1			; SrcY
	MOVEQ	#0,D2
	MOVE.W	rpr_W,D2		; SrcMod
	X20LEA	X20_RPRRP,A1
	X20LEA	X20_RTGCTAB,A2
	MOVEQ	#0,D3			; DestX
	MOVEQ	#0,D4
	MOVE.W	D7,D4
	MULU	rpr_RowH,D4		; DestY
	MOVE.L	D2,D5			; SizeX
	MOVEQ	#0,D6
	MOVE.W	rpr_RowH,D6		; SizeY
	MOVEQ	#0,D7			; CTABFMT_XRGB8
	MOVEA.L	rtg_CgxBase,A6
	JSR	(-198,A6)		; WriteLUTPixelArray
.out:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; after the copper walk: bring every slot up to date
pt_RprFrame:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.B	rtg_RprOn
	BEQ.W	.r
	TST.L	rpr_BM
	BEQ.W	.r
	MOVE.L	rtg_PatGen,D0		; whole pattern drawn again by pt
	CMP.L	rpr_Gen,D0
	BEQ.S	.g
	MOVE.L	D0,rpr_Gen
	IFD	DEBUGAUTO
	ADDQ.L	#1,rtg_ProfN+32
	ENDC
	BSR.W	pt_RprInval
.g:	TST.B	rtg_Wide
	BEQ.S	.g1
	BSR.W	pt_RwdFont
.g1:	TST.B	rpr_TplNew		; new template or colours: all
	BEQ.S	.t
	SF	rpr_TplNew
	IFD	DEBUGAUTO
	ADDQ.L	#1,rtg_ProfN+36
	ENDC
	BSR.W	pt_RprInval
	TST.B	rtg_Wide
	BEQ.S	.t
	BSR.W	pt_RwdTpl
.t:	MOVE.W	rtg_PatRow,D0
	MOVE.W	D0,D1
	SUB.W	rpr_LastPR,D1		; rows moved
	MOVE.W	D0,rpr_LastPR
	MOVE.W	D1,D2
	BPL.S	.ab
	NEG.W	D2
.ab:	CMP.W	rpr_N,D2
	BLO.S	.mv
	IFD	DEBUGAUTO
	ADDQ.L	#1,rtg_ProfN+40
	ENDC
	BSR.W	pt_RprInval		; jump: all slots
	MOVE.W	D0,rpr_LastPR
	BRA.S	.sl
.mv:	TST.W	D1
	BEQ.S	.sl
	ST	rpr_Force
	MOVE.W	rpr_Head,D2		; ring start follows the rows
	ADD.W	D1,D2
	BPL.S	.h1
	ADD.W	rpr_N,D2
.h1:	CMP.W	rpr_N,D2
	BLO.S	.h2
	SUB.W	rpr_N,D2
.h2:	MOVE.W	D2,rpr_Head
.sl:	MOVEQ	#0,D5			; position j
	X20LEA	X20_RPRSLOT,A5
	LEA	rtg_RowDirty,A4
.lp:	CMP.W	rpr_N,D5
	BHS.W	.done
	MOVE.W	rtg_PatRow,D0		; row r = pat row - c + j
	SUB.W	rpr_C,D0
	ADD.W	D5,D0
	MOVEQ	#1,D1			; ring: normal rows; the bar is drawn over it
	MOVE.L	#$10000000,D3		; key: style, row
	MOVE.W	D0,D3
	MOVE.W	rpr_Head,D6		; physical slot
	ADD.W	D5,D6
	CMP.W	rpr_N,D6
	BLO.S	.p1
	SUB.W	rpr_N,D6
.p1:	MOVE.W	D6,D2
	LSL.W	#2,D2
	TST.W	D0			; row changed by pt?
	BMI.S	.cmp
	CMP.W	#63,D0
	BHI.S	.cmp
	TST.B	(A4,D0.W)
	BEQ.S	.cmp
	SF	(A4,D0.W)
	IFD	DEBUGAUTO
	ADDQ.L	#1,rtg_ProfN+48
	ENDC
	BRA.S	.draw
.cmp:	CMP.L	(A5,D2.W),D3
	BEQ.S	.nx
.draw:	MOVE.L	D3,(A5,D2.W)
	IFD	DEBUGAUTO
	ADDQ.L	#1,rtg_ProfN+44
	ENDC
	BSR.W	pt_RprBuild
	MOVE.W	D6,D0
	BSR.W	pt_RprPut
	ST	rpr_Force
.nx:	ADDQ.W	#1,D5
	BRA.W	.lp
.done:	TST.B	rtg_Wide		; wide bar outside the layer lock
	BEQ.S	.d0
	BSR.W	pt_RwdBar
.d0:	MOVE.W	rpr_BarGen,D0		; cursor bar changed: show again
	CMP.W	rpr_BarShown,D0
	BEQ.S	.r
	MOVE.W	D0,rpr_BarShown
	ST	rpr_Force
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; cursor bar (native lines 197-205 as captured) scaled into rpr_SBuf
; -> d0 = lines
pt_RprBarBuf:
	MOVEM.L	D1-D7/A0-A6,-(A7)
	RMLEA	RM_BAR,A0
	MOVE.W	#640,D5
	TST.B	rtg_Wide
	BEQ.S	.sw
	WMLEA	WM_BAR,A0
	MOVE.W	rwd_W,D5
.sw:	MOVEA.L	rpr_SBuf,A1
	MOVEQ	#9,D6
	BSR.S	pt_RprScale
	MOVEQ	#9,D0
	MULU	rpr_YF,D0
	MOVEM.L	(A7)+,D1-D7/A0-A6
	RTS

; d6 lines of d5 px at a0 -> scaled by rpr_XF, rpr_YF to a1
pt_RprScale:
	MOVE.W	rpr_XF,D3
	SUBQ.W	#1,D6
.ln:	MOVEA.L	A1,A4			; first copy of this line
	MOVEA.L	A0,A2
	CMP.W	#1,D3			; 1x: long copy
	BNE.S	.xs
	MOVE.W	D5,D0
	LSR.W	#2,D0
	SUBQ.W	#1,D0
.c1:	MOVE.L	(A2)+,(A1)+
	DBF	D0,.c1
	BRA.S	.yr
.xs:	MOVE.W	D5,D0			; x factor n: each pixel n times
	SUBQ.W	#1,D0
.px:	MOVE.B	(A2)+,D1
	MOVE.W	D3,D2
	SUBQ.W	#1,D2
.pr:	MOVE.B	D1,(A1)+
	DBF	D2,.pr
	DBF	D0,.px
.yr:	MOVE.W	rpr_YF,D2		; more output lines: copies
	SUBQ.W	#2,D2
	BMI.S	.nx
	MOVE.W	rpr_W,D4
	LSR.W	#2,D4
	SUBQ.W	#1,D4
.yc:	MOVEA.L	A4,A2
	MOVE.W	D4,D0
.y4:	MOVE.L	(A2)+,(A1)+
	DBF	D0,.y4
	DBF	D2,.yc
.nx:	ADDA.W	D5,A0
	DBF	D6,.ln
	RTS

; card bitmap -> window (two blits around the ring start), thumb
pt_RprBlit:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.B	rtg_RprOn
	BEQ.W	.r
	TST.L	rpr_BM
	BEQ.W	.r
	TST.B	rpr_Force
	BEQ.W	.r
	TST.L	rpr_BM2
	BNE.W	pt_RprComp
	TST.B	rtg_RunWin
	BEQ.W	.scr
	BSR.W	pt_RprCTab		; bar colours current
	MOVEA.L	rtg_Window,A3
	MOVEA.L	124(A3),A5		; WLayer
	BSR.W	pt_RtgPriUp
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-654,A6)		; AttemptLockLayerRom
	TST.L	D0
	BEQ.W	.nl			; busy: next frame
	SF	rpr_Force
	ST	rpr_BlitDone
	MOVEQ	#0,D7
	MOVE.B	55(A3),D7
	MOVE.W	#RTG_PATTOP,D0
	MULU	rpr_YF,D0
	ADD.L	D0,D7			; dest y of the pattern area
	MOVE.W	rpr_N,D5		; slots head .. n-1
	SUB.W	rpr_Head,D5
	MOVE.W	rpr_Head,D1
	BSR.W	.blt
	MOVE.W	rpr_Head,D5		; slots 0 .. head-1
	MOVEQ	#0,D1
	BSR.W	.blt
	JSR	(-228,A6)		; WaitBlit: card blits run on their own
	BSR.W	pt_RprBarBuf		; cursor bar over the ring
	MOVE.L	D0,D6			; SizeY
	MOVEA.L	rpr_SBuf,A0
	MOVEQ	#0,D0
	MOVEQ	#0,D1
	MOVEQ	#0,D2
	MOVE.W	rpr_W,D2
	MOVEA.L	50(A3),A1
	X20LEA	X20_RTGCTAB,A2
	MOVEQ	#0,D3
	MOVE.B	54(A3),D3
	MOVEQ	#0,D4
	MOVE.W	rtg_YtOut,D4
	SUBQ.W	#1,D4
	MULU	rpr_YF,D4
	MOVEQ	#0,D5
	MOVE.B	55(A3),D5
	ADD.L	D5,D4
	MOVE.L	D2,D5
	MOVEQ	#0,D7
	MOVE.L	A6,-(A7)
	MOVEA.L	rtg_CgxBase,A6
	JSR	(-198,A6)		; WriteLUTPixelArray
	MOVEA.L	(A7)+,A6
	BSR.W	pt_RprThumb
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-438,A6)		; UnlockLayerRom
.nl:	BSR.W	pt_RtgPriDown
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS
.scr:	SF	rpr_Force		; card screen: its rastport, no layer
	ST	rpr_BlitDone
	MOVEA.L	rtg_Screen,A2
	LEA	84(A2),A2
	MOVEA.L	dat_GfxLibBase,A6
	MOVEQ	#0,D7
	MOVE.W	rtg_YOff,D7
	MOVE.W	#RTG_PATTOP,D0
	MULU	rpr_YF,D0
	ADD.L	D0,D7
	MOVE.W	rpr_N,D5
	SUB.W	rpr_Head,D5
	MOVE.W	rpr_Head,D1
	BSR.S	.bls
	MOVE.W	rpr_Head,D5
	MOVEQ	#0,D1
	BSR.S	.bls
	JSR	(-228,A6)		; WaitBlit: card blits run on their own
	BSR.W	pt_RprBarBuf		; cursor bar over the ring
	MOVE.L	D0,D3
	MOVEA.L	A2,A0			; screen rastport
	MOVEQ	#0,D0
	MOVEQ	#0,D1
	MOVE.W	rtg_YtOut,D1
	SUBQ.W	#1,D1
	MULU	rpr_YF,D1
	ADD.W	rtg_YOff,D1
	ADD.L	D1,D3
	SUBQ.L	#1,D3
	MOVE.L	#639,D2
	MOVE.L	A2,-(A7)
	MOVEA.L	rpr_SBuf,A2
	MOVE.L	#640,D4
	JSR	(-1056,A6)		; WriteChunkyPixels
	MOVEA.L	(A7)+,A2
	BSR.W	pt_RprThumbS
	BRA.W	.r
.bls:	TST.W	D5
	BEQ.S	.bs0
	MULU	rpr_RowH,D1
	MULU	rpr_RowH,D5
	MOVEA.L	rpr_BM,A0
	MOVEQ	#0,D0
	MOVEA.L	A2,A1
	MOVEQ	#0,D2
	MOVE.L	D7,D3
	MOVE.L	#640,D4
	MOVE.L	D5,-(A7)
	MOVE.L	#$c0,D6
	JSR	(-606,A6)		; BltBitMapRastPort
	MOVE.L	(A7)+,D5
	ADD.L	D5,D7
.bs0:	RTS
.blt:	TST.W	D5			; d1 first slot, d5 count, d7 dest y (advanced)
	BEQ.S	.b0
	MULU	rpr_RowH,D1
	MULU	rpr_RowH,D5
	MOVEA.L	rpr_BM,A0
	MOVEQ	#0,D0			; xSrc
	MOVEA.L	50(A3),A1		; RPort
	MOVEQ	#0,D2
	MOVE.B	54(A3),D2		; xDest
	MOVE.L	D7,D3			; yDest
	MOVEQ	#0,D4
	MOVE.W	rpr_W,D4
	MOVE.L	D5,-(A7)
	MOVE.L	#$c0,D6
	JSR	(-606,A6)		; BltBitMapRastPort
	MOVE.L	(A7)+,D5
	ADD.L	D5,D7
.b0:	RTS

; pattern area put together in rpr_BM2 (ring, cursor bar, thumb, vu),
; then one blit to the picture: no frame shows the ring without them
pt_RprComp:
	DK	'C'
	MOVEA.L	dat_GfxLibBase,A6
	TST.B	rtg_RunWin
	BEQ.S	.c0
	BSR.W	pt_RprCTab
	MOVEA.L	rtg_Window,A3
	MOVEA.L	124(A3),A5		; WLayer
	BSR.W	pt_RtgPriUp
	JSR	(-654,A6)		; AttemptLockLayerRom
	TST.L	D0
	IFD	DEBUGAUTO
	BNE.S	.c0
	ADDQ.L	#1,rtg_ProfN+8
	BRA.W	.nl
	ENDC
	BEQ.W	.nl			; busy: next frame
.c0:	SF	rpr_Force
	ST	rpr_BlitDone
	MOVEQ	#0,D7			; ring -> rpr_BM2
	MOVE.W	rpr_N,D5
	SUB.W	rpr_Head,D5
	MOVE.W	rpr_Head,D1
	BSR.W	.bb
	MOVE.W	rpr_Head,D5
	MOVEQ	#0,D1
	BSR.W	.bb
	JSR	(-228,A6)		; WaitBlit
	BSR.W	pt_RprBarBuf		; cursor bar
	MOVE.L	D0,D6			; SizeY
	MOVEQ	#0,D4
	MOVE.W	rtg_YtOut,D4
	SUB.W	#RTG_PATTOP+1,D4
	MULU	rpr_YF,D4		; DestY
	TST.B	rtg_RunWin
	BEQ.S	.cs
	MOVEA.L	rpr_SBuf,A0
	MOVEQ	#0,D0
	MOVEQ	#0,D1
	MOVEQ	#0,D2
	MOVE.W	rpr_W,D2
	X20LEA	X20_RPRRP2,A1
	X20LEA	X20_RTGCTAB,A2
	MOVEQ	#0,D3
	MOVE.L	D2,D5
	MOVEQ	#0,D7
	MOVE.L	A6,-(A7)
	MOVEA.L	rtg_CgxBase,A6
	JSR	(-198,A6)		; WriteLUTPixelArray
	MOVEA.L	(A7)+,A6
	BRA.S	.ct
.cs:	X20LEA	X20_RPRRP2,A0
	MOVEQ	#0,D0
	MOVE.L	D4,D1
	MOVE.L	D4,D3
	ADD.L	D6,D3
	SUBQ.L	#1,D3
	MOVE.L	#639,D2
	MOVEA.L	rpr_SBuf,A2
	MOVE.L	#640,D4
	JSR	(-1056,A6)		; WriteChunkyPixels
.ct:	BSR.W	pt_RprThumbO
	ST	rpr_Off			; vu columns into rpr_BM2
	BSR.W	pt_RprVu
	SF	rpr_Off
	JSR	(-228,A6)		; WaitBlit
	MOVEA.L	rpr_BM2,A0		; rpr_BM2 -> picture
	MOVEQ	#0,D0
	MOVEQ	#0,D1
	MOVEQ	#0,D4
	MOVE.W	rpr_W,D4
	MOVEQ	#0,D5
	MOVE.W	rpr_H2,D5
	MOVE.L	#$c0,D6
	MOVE.W	#RTG_PATTOP,D3
	MULU	rpr_YF,D3
	TST.B	rtg_RunWin
	BEQ.S	.ds
	MOVEA.L	50(A3),A1
	MOVEQ	#0,D2
	MOVE.B	54(A3),D2
	MOVEQ	#0,D7
	MOVE.B	55(A3),D7
	ADD.L	D7,D3
	JSR	(-606,A6)		; BltBitMapRastPort
	BSR.W	pt_RprThumb		; thumb part below the area
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-438,A6)		; UnlockLayerRom
.nl:	BSR.W	pt_RtgPriDown
	BRA.S	.r
.ds:	MOVEA.L	rtg_Screen,A1
	LEA	84(A1),A1
	MOVEQ	#0,D2
	ADD.W	rtg_YOff,D3
	JSR	(-606,A6)		; BltBitMapRastPort
	MOVEA.L	rtg_Screen,A2
	LEA	84(A2),A2
	BSR.W	pt_RprThumbS
.r:
	DK	'c'
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS
.bb:	TST.W	D5			; d1 first slot, d5 count, d7 dest y
	BEQ.S	.b0
	MULU	rpr_RowH,D1
	MULU	rpr_RowH,D5
	MOVEM.L	D5/D7,-(A7)
	MOVEA.L	rpr_BM,A0
	MOVEQ	#0,D0
	MOVEA.L	rpr_BM2,A1
	MOVEQ	#0,D2
	MOVE.L	D7,D3
	MOVEQ	#0,D4
	MOVE.W	rpr_W,D4
	MOVE.L	#$c0,D6
	MOVEQ	#-1,D7
	SUBA.L	A2,A2
	JSR	(-30,A6)		; BltBitMap
	MOVEM.L	(A7)+,D5/D7
	ADD.L	D5,D7
.b0:	RTS

; thumb into rpr_BM2 (clipped to it)
pt_RprThumbO:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.W	rtg_OutH,D1
	SUB.W	#RTG_PATTOP+26,D1
	MULU	rtg_PatRow,D1
	DIVU	#63,D1
	MULU	rpr_YF,D1		; y in the area
	MOVEQ	#24,D3
	MULU	rpr_YF,D3		; h
	MOVEQ	#0,D0
	MOVE.W	rpr_H2,D0
	SUB.L	D1,D0
	BLE.S	.r
	CMP.L	D0,D3
	BLE.S	.h
	MOVE.L	D0,D3
.h:	X20LEA	X20_RPRRP2,A1
	TST.B	rtg_RunWin
	BEQ.S	.s
	MOVE.W	#627,D0
	TST.B	rtg_Wide
	BEQ.S	.tx
	ADD.W	rwd_W,D0
	SUB.W	#640,D0
.tx:	MULU	rpr_XF,D0
	MOVEQ	#10,D2
	MULU	rpr_XF,D2
	MOVE.L	#$00ff0000,D4
	MOVEA.L	rtg_CgxBase,A6
	JSR	(-150,A6)		; FillPixelArray
	BRA.S	.r
.s:	MOVEQ	#0,D0
	MOVE.B	rtg_ThumbIdx,D0
	MOVEA.L	dat_GfxLibBase,A6
	MOVE.L	A1,-(A7)
	JSR	(-342,A6)		; SetAPen
	MOVEA.L	(A7)+,A1
	ADD.L	D1,D3
	SUBQ.L	#1,D3			; y1
	MOVE.L	#627,D0
	MOVE.L	#636,D2
	JSR	(-306,A6)		; RectFill
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; scroll thumb over the whole pattern area (a3 window, layer locked)
pt_RprThumb:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.W	rtg_OutH,D1		; top = 150 + row * (h - 176) / 63
	SUB.W	#RTG_PATTOP+26,D1
	MULU	rtg_PatRow,D1
	DIVU	#63,D1
	ADD.W	#RTG_PATTOP,D1
	MULU	rpr_YF,D1
	MOVEQ	#0,D0
	MOVE.B	55(A3),D0
	ADD.L	D0,D1			; y
	MOVE.W	#627,D0
	TST.B	rtg_Wide
	BEQ.S	.tx
	ADD.W	rwd_W,D0
	SUB.W	#640,D0
.tx:	MULU	rpr_XF,D0
	MOVEQ	#0,D2
	MOVE.B	54(A3),D2
	ADD.L	D2,D0			; x
	MOVEQ	#10,D2
	MULU	rpr_XF,D2		; w
	MOVEQ	#24,D3
	MULU	rpr_YF,D3		; h
	MOVE.L	#$00ff0000,D4
	MOVEA.L	50(A3),A1
	MOVEA.L	rtg_CgxBase,A6
	JSR	(-150,A6)		; FillPixelArray
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; card screen: thumb with the clut pen of red (a2 screen rastport)
pt_RprThumbS:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVEA.L	A2,A1
	MOVEQ	#0,D0
	MOVE.B	rtg_ThumbIdx,D0
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-342,A6)		; SetAPen
	MOVE.W	rtg_OutH,D1
	SUB.W	#RTG_PATTOP+26,D1
	MULU	rtg_PatRow,D1
	DIVU	#63,D1
	ADD.W	#RTG_PATTOP,D1
	MULU	rpr_YF,D1
	ADD.W	rtg_YOff,D1		; y0
	MOVEQ	#24,D3
	MULU	rpr_YF,D3
	ADD.L	D1,D3
	SUBQ.L	#1,D3			; y1
	MOVE.L	#627,D0			; x0
	MOVE.L	#636,D2			; x1
	MOVEA.L	A2,A1
	JSR	(-306,A6)		; RectFill
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

;--- sprites over the pattern area: vu bars, pointer on the card screen
; a column is drawn again from the template, pt's text and the sprite
; data when it moved or after a ring blit; columns of the last frame
; that are gone get their background back
RPR_VUTOP	EQU	150
RPR_VUH		EQU	RPR_BARTOP-RPR_VUTOP	; 47 lines
RPR_VUW		EQU	40		; column width (pointer not byte aligned)
RPR_VUN		EQU	12		; columns per frame

pt_RprVu:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.B	rtg_RprOn
	BEQ.W	.r
	TST.L	rpr_BM
	BEQ.W	.r
	TST.L	rtg_RowSt
	BEQ.W	.r
	X20LEA	X20_RPRVUNEW,A2		; columns of this frame: x, top, end line
	MOVEQ	#0,D7
	X20LEA	X20_RTGSEGS,A0
	MOVE.W	rtg_NumSegs,D6
	BRA.W	.se
.sl:	MOVE.W	6(A0),D0		; hires x, byte aligned
	SUB.W	rtg_DiwH,D0
	ADD.W	D0,D0
	CMP.W	#620,D0			; scroll bar thumb: renderer's own
	BGE.W	.sn
	CMP.W	#-32,D0
	BLE.W	.sn
	AND.W	#$fff8,D0
	MOVE.W	2(A0),D1		; native y0, y1
	SUB.W	rtg_VStart,D1
	MOVE.W	4(A0),D2
	SUB.W	rtg_VStart,D2
	TST.W	(A0)			; pointer (card screen): above and below the bar
	BNE.S	.vu
	TST.B	rtg_RunWin
	BNE.W	.sn
	MOVE.W	D1,D3			; part above the bar
	MOVE.W	D2,D4
	CMP.W	#RTG_PATTOP,D3
	BGE.S	.a0
	MOVE.W	#RTG_PATTOP,D3
.a0:	CMP.W	#RPR_BARTOP,D4
	BLE.S	.a1
	MOVE.W	#RPR_BARTOP,D4
.a1:	BSR.S	.add
	MOVE.W	D1,D3			; part below the bar
	MOVE.W	D2,D4
	CMP.W	#RPR_BAREND+1,D3
	BGE.S	.b0
	MOVE.W	#RPR_BAREND+1,D3
.b0:	CMP.W	#RTG_PATEND,D4
	BLE.S	.b1
	MOVE.W	#RTG_PATEND,D4
.b1:	BSR.S	.add
	BRA.S	.sn
.vu:	TST.B	trk_On			; track view: bars of its own
	BNE.S	.sn
	CMP.W	#RPR_VUTOP,D1		; vu bar: from its top to the bar
	BLT.S	.sn
	CMP.W	#RPR_BARTOP+1,D2
	BGT.S	.sn
	MOVE.W	D1,D3
	MOVE.W	#RPR_BARTOP,D4
	BSR.S	.add
.sn:	LEA	12(A0),A0
.se:	DBF	D6,.sl
	MOVE.W	D7,rpr_VuNewN
	BRA.S	.draw
.add:	CMP.W	D4,D3			; x d0, lines d3..d4-1 (empty: none)
	BGE.S	.ax
	CMP.W	#RPR_VUN,D7
	BHS.S	.ax
	MOVE.W	D0,(A2)+
	MOVE.W	D3,(A2)+
	MOVE.W	D4,(A2)+
	ADDQ.W	#1,D7
.ax:	RTS
.draw:	X20LEA	X20_RPRVUNEW,A2		; new columns: draw if moved or after a blit
	MOVE.W	D7,D6
	BRA.S	.de
.dl:	MOVE.W	(A2)+,D0		; x
	MOVE.W	(A2)+,D1		; top
	MOVE.W	(A2)+,D2		; end
	X20LEA	X20_RPRVUOLD,A1
	MOVE.W	rpr_VuOldN,D5
	BRA.S	.fe
.fl:	CMP.W	(A1),D0
	BNE.S	.fn
	TST.B	rpr_BlitDone
	BNE.S	.fm
	CMP.W	2(A1),D1
	BNE.S	.fm
	CMP.W	4(A1),D2
	BEQ.S	.de			; unchanged
.fm:	CMP.W	2(A1),D1		; union with the old column
	BLE.S	.f1
	MOVE.W	2(A1),D1
.f1:	CMP.W	4(A1),D2
	BGE.S	.fd
	MOVE.W	4(A1),D2
	BRA.S	.fd
.fn:	ADDQ.L	#6,A1
.fe:	DBF	D5,.fl
.fd:	BSR.W	pt_RprVuCol
.de:	DBF	D6,.dl
	X20LEA	X20_RPRVUOLD,A2		; old ones not drawn now: background
	MOVE.W	rpr_VuOldN,D6
	BRA.S	.oe
.ol:	MOVE.W	(A2)+,D0
	MOVE.W	(A2)+,D1
	MOVE.W	(A2)+,D2
	X20LEA	X20_RPRVUNEW,A1
	MOVE.W	rpr_VuNewN,D5
	BRA.S	.ge
.gl:	CMP.W	(A1),D0
	BEQ.S	.oe
	ADDQ.L	#6,A1
.ge:	DBF	D5,.gl
	BSR.W	pt_RprVuCol
.oe:	DBF	D6,.ol
	X20LEA	X20_RPRVUNEW,A0		; new -> old
	X20LEA	X20_RPRVUOLD,A1
	MOVE.W	#RPR_VUN*3-1,D0
.cp:	MOVE.W	(A0)+,(A1)+
	DBF	D0,.cp
	MOVE.W	rpr_VuNewN,rpr_VuOldN
	TST.B	trk_On
	BEQ.S	.nt
	BSR.W	pt_TrkVu
.nt:	SF	rpr_BlitDone
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; one column at hires x d0, native lines d1..d2-1: build, write
pt_RprVuCol:
	TST.B	rtg_Wide
	BNE.W	pt_RwdVuCol
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.W	D0			; inside the picture
	BPL.S	.x0
	MOVEQ	#0,D0
.x0:	CMP.W	#640-RPR_VUW,D0
	BLS.S	.x1
	MOVE.W	#640-RPR_VUW,D0
.x1:	MOVE.W	D0,D4			; x
	MOVE.W	D2,D6			; end line
	CMP.W	D6,D1
	BGE.W	.out
	MOVE.W	D1,rpr_VuTop
	SUB.W	D1,D2
	MOVE.W	D2,rpr_VuLines
	RMLEA	RM_VU,A1
	MOVE.W	D1,D5			; native line
.ln:	MOVE.W	D5,D7
	MOVE.W	D5,D0			; output line, pattern row and its line
	ADD.W	rtg_Shift,D0
	SUB.W	#RTG_PATTOP,D0
	MOVE.W	D0,D1
	AND.W	#7,D1			; line in the row
	LSR.W	#3,D0			; slot j
	ADD.W	rtg_PatRow,D0
	SUB.W	rpr_C,D0		; pattern row
	RMLEA	RM_TPL,A3		; background: template of the parity
	BTST	#0,D1
	BEQ.S	.ev
	LEA	640(A3),A3
.ev:	ADDA.W	D4,A3
	MOVEQ	#RPR_VUW/4-1,D2
.tc:	MOVE.L	(A3)+,(A1)+
	DBF	D2,.tc
	LEA	-RPR_VUW(A1),A1
	TST.W	D0			; text of the row (rows 0-63)
	BMI.S	.spr
	CMP.W	#63,D0
	BHI.S	.spr
	LSL.W	#3,D0
	ADD.W	D1,D0
	ADD.W	#RTG_PATCUR-4,D0
	MULU	#80,D0
	MOVEA.L	dat_ScreenBuf2Ptr,A0
	ADDA.L	D0,A0
	MOVE.W	D4,D0
	LSR.W	#3,D0
	ADDA.W	D0,A0
	X20LEA	X20_RTGP2C,A3
	MOVEA.L	A1,A4
	MOVEQ	#RPR_VUW/8-1,D3
.tb:	MOVEQ	#0,D0
	MOVE.B	(A0)+,D0
	LSL.W	#3,D0
	MOVE.L	(A3,D0.W),D1
	MOVE.L	4(A3,D0.W),D2
	LSL.L	#2,D1
	LSL.L	#2,D2
	ADD.L	D1,(A4)+
	ADD.L	D2,(A4)+
	DBF	D3,.tb
.spr:	BSR.W	pt_RprVuSpr		; sprites of native line d7 into (a1)
	LEA	RPR_VUW(A1),A1
	ADDQ.W	#1,D5
	CMP.W	D6,D5
	BLO.W	.ln
	MOVE.W	D4,D0			; write at output line top + shift
	MOVE.W	rpr_VuTop,D1
	ADD.W	rtg_Shift,D1
	MOVE.W	rpr_VuLines,D2
	BSR.W	pt_RprRect
.out:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; sprites on native line d7 over the column at x d4, buffer a1
; (in front of the planes, as the mirror draws them)
pt_RprVuSpr:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.W	D7,D2
	ADD.W	rtg_VStart,D2		; raster line
	MOVEA.L	rtg_RowSt,A5		; colours of that line
	MOVE.W	D7,D0
	MULU	#RTG_STSIZE,D0
	ADDA.L	D0,A5
	LEA	28+32(A5),A5		; colour 16
	X20LEA	X20_RTGCOLMAP,A6	; $0rgb -> clut idx
	X20LEA	X20_RTGSEGS,A0
	MOVE.W	rtg_NumSegs,D3
	BRA.W	.e
.l:	CMP.W	2(A0),D2
	BLO.W	.n
	CMP.W	4(A0),D2
	BHS.W	.n
	MOVE.W	D2,D0
	SUB.W	2(A0),D0
	LSL.W	#2,D0
	MOVEA.L	8(A0),A2
	MOVE.L	(A2,D0.W),D6		; a word, b word
	BEQ.W	.n
	MOVE.W	(A0),D0			; sprite pair -> 3 colours
	LSR.W	#1,D0
	LSL.W	#3,D0
	LEA	(A5,D0.W),A3
	LEA	rpr_VuIdx,A4
	MOVE.W	2(A3),D1
	BSR.S	.col
	MOVE.B	D1,1(A4)
	MOVE.W	4(A3),D1
	BSR.S	.col
	MOVE.B	D1,2(A4)
	MOVE.W	6(A3),D1
	BSR.S	.col
	MOVE.B	D1,3(A4)
	MOVE.W	6(A0),D5		; hires x of pixel 15
	SUB.W	rtg_DiwH,D5
	ADD.W	D5,D5
	SUB.W	D4,D5			; relative to the column
	MOVEQ	#15,D7
.px:	MOVEQ	#0,D0
	MOVE.W	D7,D1
	ADD.W	#16,D1
	BTST	D1,D6
	BEQ.S	.na
	MOVEQ	#1,D0
.na:	BTST	D7,D6
	BEQ.S	.nb
	ADDQ.W	#2,D0
.nb:	TST.W	D0
	BEQ.S	.sk
	MOVE.B	(A4,D0.W),D0
	BSR.S	.put			; 2 hires px
	BSR.S	.put
	BRA.S	.nx
.sk:	ADDQ.W	#2,D5
.nx:	DBF	D7,.px
.n:	LEA	12(A0),A0
.e:	DBF	D3,.l
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS
.col:	MOVE.W	D1,-(A7)		; known colour from the table, else allocate
	AND.W	#$0fff,D1
	MOVE.B	(A6,D1.W),D1
	BEQ.S	.c0
	ADDQ.L	#2,A7
	AND.W	#$ff,D1
	RTS
.c0:	MOVE.W	(A7)+,D1
	BRA.W	pt_RtgSprCol
.put:	CMP.W	#RPR_VUW-1,D5		; d0 colour at d5 (outside: skip)
	BHI.S	.pn
	MOVE.B	D0,(A1,D5.W)		; in front, as the mirror draws sprites
.pn:	ADDQ.W	#1,D5
	RTS

; RM_VU (RPR_VUW x d2 chunky) -> picture at native x d0, output line d1
pt_RprRect:
	MOVE.W	#RPR_VUW,rpr_VuW
	TST.B	rtg_Wide
	BEQ.S	pt_RprRectW
	MOVE.W	#2*RPR_VUW,rpr_VuW
; the same, width in rpr_VuW
pt_RprRectW:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.W	D0,D6			; x
	MOVE.W	D1,D7			; y
	MOVE.W	D2,rpr_VuLines
	RMLEA	RM_VU,A0		; scale into rpr_SBuf
	TST.B	rtg_Wide
	BEQ.S	.w0
	WMLEA	WM_VU,A0
.w0:	MOVEA.L	rpr_SBuf,A1
	MOVE.W	rpr_XF,D3
	MOVE.W	D2,D5
	SUBQ.W	#1,D5
.ln:	MOVEA.L	A1,A4
	CMP.W	#1,D3
	BNE.S	.xs
	MOVE.W	rpr_VuW,D0
	LSR.W	#2,D0
	SUBQ.W	#1,D0
.l1:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.l1
	BRA.S	.xd
.xs:	MOVE.W	rpr_VuW,D0
	SUBQ.W	#1,D0
.px:	MOVE.B	(A0)+,D1
	MOVE.W	D3,D2
	SUBQ.W	#1,D2
.pr:	MOVE.B	D1,(A1)+
	DBF	D2,.pr
	DBF	D0,.px
.xd:	MOVE.W	rpr_YF,D2
	SUBQ.W	#2,D2
	BMI.S	.nx
	MOVE.W	rpr_VuW,D4		; (w / 4) * xf longs per line
	LSR.W	#2,D4
	MULU	D3,D4
	SUBQ.W	#1,D4
.yc:	MOVEA.L	A4,A2
	MOVE.W	D4,D0
.y4:	MOVE.L	(A2)+,(A1)+
	DBF	D0,.y4
	DBF	D2,.yc
.nx:	DBF	D5,.ln
	MOVE.W	rpr_VuW,D4		; width (scaled)
	MULU	rpr_XF,D4
	MOVE.W	rpr_VuLines,D5		; height (scaled)
	MULU	rpr_YF,D5
	MULU	rpr_XF,D6		; dest x, y
	MULU	rpr_YF,D7
	TST.B	rpr_Off
	BNE.W	.off
	TST.B	rtg_RunWin
	BNE.S	.win
	MOVEA.L	rtg_Screen,A0		; card screen
	LEA	84(A0),A0
	MOVE.L	D6,D0
	MOVE.L	D7,D1
	ADD.W	rtg_YOff,D1
	MOVE.L	D0,D2
	ADD.L	D4,D2
	SUBQ.L	#1,D2
	MOVE.L	D1,D3
	ADD.L	D5,D3
	SUBQ.L	#1,D3
	MOVEA.L	rpr_SBuf,A2
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-1056,A6)		; WriteChunkyPixels
	BRA.S	.r
.win:	BSR.W	pt_RprCTab		; new colours (vu) into the rgb table
	MOVEA.L	rtg_Window,A3
	MOVEA.L	124(A3),A5
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-654,A6)		; AttemptLockLayerRom
	TST.L	D0
	BEQ.S	.r
	MOVEA.L	rpr_SBuf,A0
	MOVEQ	#0,D0
	MOVEQ	#0,D1
	MOVE.L	D4,D2			; SrcMod
	MOVEA.L	50(A3),A1
	X20LEA	X20_RTGCTAB,A2
	MOVE.L	D6,D3
	MOVEQ	#0,D0
	MOVE.B	54(A3),D0
	ADD.L	D0,D3			; DestX
	MOVEQ	#0,D0
	MOVE.L	D4,-(A7)
	MOVE.L	D7,D4
	MOVEQ	#0,D1
	MOVE.B	55(A3),D1
	ADD.L	D1,D4			; DestY
	MOVEQ	#0,D1
	MOVE.L	(A7)+,D2
	MOVE.L	D2,-(A7)
	MOVE.L	D5,D6			; SizeY
	MOVE.L	(A7)+,D5		; SizeX
	MOVEQ	#0,D7
	MOVEA.L	rtg_CgxBase,A6
	JSR	(-198,A6)		; WriteLUTPixelArray
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-438,A6)		; UnlockLayerRom
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS
.off:	MOVE.W	#RTG_PATTOP,D0		; off screen area: relative, clipped
	MULU	rpr_YF,D0
	SUB.L	D0,D7
	BMI.W	.r
	MOVEQ	#0,D0
	MOVE.W	rpr_H2,D0
	SUB.L	D7,D0
	BLE.W	.r
	CMP.L	D0,D5
	BLE.S	.o1
	MOVE.L	D0,D5
.o1:	TST.B	rtg_RunWin
	BNE.S	.ow
	X20LEA	X20_RPRRP2,A0
	MOVE.L	D6,D0
	MOVE.L	D7,D1
	MOVE.L	D0,D2
	ADD.L	D4,D2
	SUBQ.L	#1,D2
	MOVE.L	D1,D3
	ADD.L	D5,D3
	SUBQ.L	#1,D3
	MOVEA.L	rpr_SBuf,A2
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-1056,A6)		; WriteChunkyPixels
	BRA.W	.r
.ow:	BSR.W	pt_RprCTab
	MOVEA.L	rpr_SBuf,A0
	MOVEQ	#0,D0
	MOVEQ	#0,D1
	MOVE.L	D4,D2			; SrcMod
	X20LEA	X20_RPRRP2,A1
	X20LEA	X20_RTGCTAB,A2
	MOVE.L	D6,D3
	MOVE.L	D7,D4
	MOVE.L	D5,D6
	MOVE.L	D2,D5
	MOVEQ	#0,D7
	MOVEA.L	rtg_CgxBase,A6
	JSR	(-198,A6)		; WriteLUTPixelArray
	BRA.W	.r

; window: colours allocated since the last table build -> rgb table
pt_RprCTab:
	TST.B	rtg_PalDirty
	BEQ.S	.r
	SF	rtg_PalDirty
	BSR.W	pt_RtgCTab
	ST	rtg_BlitAll		; mirror parts in the new colours too
.r:	RTS
