; rtg wide window: 8 tracks in the 4 track geometry, 1280 px a line
; panel stays 640 px at the left, the stage next to it; pattern text in
; the wide font, chars found from the narrow glyphs pt drew
RWD_W		EQU	1280
RWD_STTOP	EQU	136		; full width lines above the track heads
RWD_HDTOP	EQU	140		; track heads
RWD_HDEND	EQU	147
RWD_SLOT	EQU	144		; wide track, 8 shown (fewer: wider)
RWD_X0		EQU	50		; first track
RWD_XE		EQU	RWD_X0+8*RWD_SLOT
RWD_SCR		EQU	RWD_W-16	; scroll bar column
RWD_TOPEND	EQU	10		; panel top row: help, exit, screen button
RWD_EXIT	EQU	572		; exit cell, grows over the screen button
RWD_BTN		EQU	624		; screen button (window has its own)
RWD_LB		EQU	641		; line buffer: title strip left, mid, right, text
RWD_TXTN	EQU	8*8+1		; title text pixels with shadow
RWD_SCT		EQU	RWD_TOPEND+1	; analyzer stage rows below the strip
RWD_SCN		EQU	RWD_STTOP-RWD_SCT
RWD_BW		EQU	75		; scope box, 8 shown (stage coordinates)
RWD_BD		EQU	RWD_BW+3	; box to box
RWD_BX		EQU	(640-8*RWD_BD+3)/2
RWD_BY		EQU	6
RWD_BH		EQU	RWD_SCN-2*RWD_BY
RWD_MID		EQU	RWD_BY+RWD_BH/2	; zero line
RWD_AMP		EQU	39		; full scale: 3/4 of the half box

; inner w d0 -> d1.b = -1 wide layout, 0 classic
pt_RwdWant:
	MOVEM.L	D0/D2/A0,-(A7)
	MOVE.B	wide_On,D2		;41 sampled once
	MOVEQ	#0,D1
	TST.B	rtg_WideWant
	BEQ.S	.r
	TST.B	rtg_WideFail
	BNE.S	.r
	TST.B	D2			; more than 8 tracks: track view
	BNE.S	.w8
	BTST	#5,dat_ModeFlags	; 4 ch: never
	BNE.S	.r
.w8:
	CMPI.B	#2,rtg_Scale1x
	BEQ.S	.r
	TST.B	D2			; track view: any width 1280..max
	BEQ.S	.w4
	CMP.W	#RWD_W,D0
	BLO.S	.r
	CMP.W	#RWD_WMAX,D0
	BHI.S	.r
	MOVEQ	#-1,D1
	BRA.S	.r
.w4:	AND.L	#$ffff,D0
	DIVU	#RWD_W,D0
	BEQ.S	.r
	SWAP	D0
	TST.W	D0
	BNE.S	.r
	MOVEQ	#-1,D1
.r:	MOVEM.L	(A7)+,D0/D2/A0
	RTS

; snap: d0 = n (round w / 640) even, 8 ch, inner h d7 nearer the wide
; height (n / 2) than the classic one (n) -> d0 = n / 2, d2 = 1280,
; rtg_WideWant; else unchanged
; d3 = base h, d4 = border w, a1 = screen
pt_RwdSnap:
	SF	rtg_WideWant
	DK	'#'
	TST.B	rtg_WideFail
	BNE.S	.f
	TST.B	wide_On			; more than 8 tracks: track view
	BNE.S	.w8
	BTST	#5,dat_ModeFlags
	BNE.S	.r
	BRA.S	.w9
.w8:	BRA.W	pt_TrkSnap		; track view: whole tracks
.w9:
	BTST	#0,D0
	BNE.S	.o
	MOVEM.L	D1/A0,-(A7)
	MOVEA.L	rtg_CgxBase,A0
	CMPI.W	#41,20(A0)		; renderer: lut writes
	BLO.S	.c
	MOVE.W	D3,D1			; 3/4 of the classic height
	MULU	D0,D1
	MOVE.L	D1,-(A7)
	LSR.L	#2,D1
	SUB.L	(A7)+,D1
	NEG.L	D1
	CMP.W	D1,D7
	BHS.S	.h
	MOVE.W	D0,D1
	LSR.W	#1,D1
	MULU	#RWD_W,D1
	ADD.L	D4,D1
	CMP.W	12(A1),D1		; Screen->Width
	BHI.S	.w
	LSR.W	#1,D0
	MOVE.L	#RWD_W,D2
	ST	rtg_WideWant
	DK	'+'
.no:	MOVEM.L	(A7)+,D1/A0
.r:	RTS
.f:	DK	'!'
	TST.B	rtg_WideMsg		;41 once per failure
	BNE.S	.r
	ST	rtg_WideMsg
	MOVE.L	A0,-(A7)
	LEA	rwd_MsgMem(PC),A0
	JSR	pt_StatusLater41
	MOVEA.L	(A7)+,A0
	RTS
.o:	DK	'%'
	RTS
.c:	DK	'&'
	LEA	rwd_MsgCgx(PC),A0
	JSR	pt_StatusLater41
	BRA.S	.no
.h:	DK	'<'
	BRA.S	.no
.w:	DK	'>'
	LEA	rwd_MsgNarrow(PC),A0
	JSR	pt_StatusLater41
	BRA.S	.no

rwd_MsgMem:	DC.B	"WIDE VIEW: OUT OF MEMORY",0
rwd_MsgCgx:	DC.B	"WIDE VIEW: NEEDS CYBERGRAPHICS 41",0
rwd_MsgNarrow:	DC.B	"WIDE VIEW: WB TOO NARROW",0
	EVEN

; rtg_Wide -> wide buffers (none: classic), else free them
pt_RwdAlloc:
	TST.B	rtg_Wide
	BEQ.W	pt_RwdFree
	TST.L	rwd_Mem
	BNE.S	.r
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.L	#WM_SIZE,D0
	MOVE.L	#$10001,D1		; MEMF_PUBLIC|MEMF_CLEAR
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-198,A6)		; AllocMem
	MOVE.L	D0,rwd_Mem
	BNE.S	.ok
	DK	'='
	SF	rtg_Wide
	ST	rtg_WideFail
	BRA.S	.x
.ok:	BSR.W	pt_RwdTabs
	BSR.W	pt_RwdStgInit
	MOVE.L	#-1,rwd_Font
	SF	rwd_BarOk
	ST	rpr_TplNew
.x:	MOVEM.L	(A7)+,D0-D7/A0-A6
.r:	RTS

pt_RwdFree:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVE.L	rwd_Mem,D0
	BEQ.S	.r
	CLR.L	rwd_Mem
	MOVEA.L	D0,A1
	MOVE.L	#WM_SIZE,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-210,A6)		; FreeMem
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

; new window size (before pt_RwdAlloc): picture width - 8 ch 1280, track
; view the window (factor 1, max RWD_WMAX); track geometry; a change
; builds the maps again when the buffers are there
pt_RwdSetW:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	BSR.W	pt_RwdGeom		; slot never 0 for the mouse
	MOVE.W	#RWD_W,D0
	TST.B	rtg_Wide
	BEQ.S	.s
	TST.B	wide_On
	BEQ.S	.s
	MOVE.W	rtg_WinW,D0
	AND.W	#$fff8,D0
	CMP.W	#RWD_WMAX,D0
	BLS.S	.s
	MOVE.W	#RWD_WMAX,D0
.s:	CMP.W	rwd_W,D0
	BEQ.S	.r
	MOVE.W	D0,rwd_W
	BSR.W	pt_TrkVis
	TST.L	rwd_Mem
	BEQ.S	.r
	BSR.W	pt_RwdTabs
	ST	rpr_TplNew
	SF	rwd_BarOk
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; d0.b = tracks shown in the 8 track view (1-8)
pt_RwdShow:
	MOVEQ	#0,D0
	MOVE.B	trk_Show,D0
	BEQ.S	.a
	CMP.B	#8,D0
	BLS.S	.r
.a:	MOVEQ	#8,D0
.r:	RTS

; 8 track view: the shown tracks share the width, the extra goes to
; the note, sample and effect field (text centred in each, byte grid);
; analyzer boxes: one per shown track over the stage
pt_RwdGeom:
	MOVEM.L	D0-D2,-(A7)
	BSR.S	pt_RwdShow
	MOVE.W	D0,D2			; n
	MOVE.L	#RWD_XE-RWD_X0,D1
	DIVU	D2,D1
	AND.W	#$fff8,D1
	MOVE.W	D1,rwd_Slot
	SUB.W	#72,D1
	LSR.W	#1,D1
	MOVE.W	D1,rwd_HdC
	MOVE.W	rwd_Slot,D1
	SUB.W	#RWD_SLOT,D1		; extra
	MOVE.W	D1,D0
	MULU	#3,D0
	DIVU	#9,D0
	AND.W	#$fff8,D0
	MOVE.W	D0,rwd_PadA
	LSR.W	#1,D0
	AND.W	#$fff8,D0
	MOVE.W	D0,rwd_TxA
	MOVE.W	D1,D0
	MULU	#2,D0
	DIVU	#9,D0
	AND.W	#$fff8,D0
	MOVE.W	D0,rwd_PadB
	LSR.W	#1,D0
	AND.W	#$fff8,D0
	MOVE.W	D0,rwd_TxB
	SUB.W	rwd_PadA,D1
	SUB.W	rwd_PadB,D1
	LSR.W	#1,D1
	AND.W	#$fff8,D1
	MOVE.W	D1,rwd_TxC
	MOVE.L	#RWD_BD*8,D1		; boxes
	DIVU	D2,D1
	MOVE.W	D1,rwd_BoxP
	MULU	D1,D2
	SUBQ.W	#3,D1
	MOVE.W	D1,rwd_BoxW
	NEG.W	D2
	ADD.W	#640+3,D2
	LSR.W	#1,D2
	MOVE.W	D2,rwd_BoxX
	MOVE.L	#RWD_BW*256,D0		; scope: same wave, wider
	DIVU	D1,D0
	MOVE.W	D0,rwd_Step
	MOVEM.L	(A7)+,D0-D2
	RTS

; track x d1.w (pattern line, 8 track view) -> x as in a 144 px track
; (pads of a field stay in that field)
pt_RwdTShift:
	MOVE.L	D2,-(A7)
	MOVE.W	D1,D2
	SUB.W	rwd_PadA,D2
	CMP.W	#54,D2
	BGE.S	.1
	SUB.W	rwd_TxA,D1		; note field: 4..53
	CMP.W	#4,D1
	BGE.S	.n0
	MOVEQ	#4,D1
.n0:	CMP.W	#53,D1
	BLE.S	.x
	MOVEQ	#53,D1
	BRA.S	.x
.1:	CMP.W	#56,D2
	BLT.S	.m
	SUB.W	rwd_PadB,D2
	CMP.W	#86,D2
	BGE.S	.3
	ADD.W	rwd_PadB,D2		; sample field: 56..85
	SUB.W	rwd_TxB,D2
	CMP.W	#56,D2
	BGE.S	.s0
	MOVEQ	#56,D2
.s0:	CMP.W	#85,D2
	BLE.S	.m
	MOVEQ	#85,D2
	BRA.S	.m
.3:	CMP.W	#88,D2
	BLT.S	.m
	SUB.W	rwd_TxC,D2		; effect field: 88..
	CMP.W	#88,D2
	BGE.S	.m
	MOVEQ	#88,D2
.m:	MOVE.W	D2,D1
.x:	MOVE.L	(A7)+,D2
	RTS

; x d1.w as in a 144 px track -> track x (inverse of pt_RwdTShift)
; (the divider columns go with the cell after them, as the text does)
pt_RwdUShift:
	CMP.W	#54,D1
	BLO.S	.a
	CMP.W	#86,D1
	BLO.S	.c
	ADD.W	rwd_TxC,D1
	ADD.W	rwd_PadB,D1
	SUB.W	rwd_TxB,D1
.c:	ADD.W	rwd_TxB,D1
	ADD.W	rwd_PadA,D1
	SUB.W	rwd_TxA,D1
.a:	ADD.W	rwd_TxA,D1
	RTS

; d0.w = wide x after the last shown track
pt_RwdXE:
	TST.B	trk_On
	BNE.S	.a
	BSR.W	pt_RwdShow
	MULU	rwd_Slot,D0
	ADD.W	#RWD_X0,D0
	RTS
.a:	MOVE.W	#RWD_XE,D0
	RTS

; fixed maps: wide x -> narrow x (pattern lines, heads), narrow -> wide
pt_RwdTabs:
	MOVEM.L	D5-D6,-(A7)
	BSR.W	pt_RwdGeom
	BSR.W	pt_RwdShow
	MOVE.W	D0,D5			; shown tracks
	BSR.W	pt_RwdXE
	MOVE.W	D0,rwd_XEn
	WMLEA	WM_TMAP,A0
	WMLEA	WM_HMAP,A1
	MOVEQ	#0,D0			; wide x
.w:	MOVE.W	D0,D1			; d1 pattern, d2 heads
	MOVE.W	D0,D2
	CMP.W	#RWD_X0,D0
	BHS.S	.w1
	CMP.W	#8,D0			; pos column: dark from x 8
	BLO.S	.w0
	MOVEQ	#8,D1
.w0:	CMP.W	#42,D0
	BLO.W	.put
	MOVEQ	#41,D2
	BRA.W	.put
.w1:	CMP.W	rwd_XEn,D0
	BLO.S	.w2
	BRA.S	.w5			; rest of the width: right margin
.w2:	MOVEQ	#0,D3
	MOVE.W	D0,D3
	SUB.W	#RWD_X0,D3
	DIVU	rwd_Slot,D3
	MOVE.L	D3,D4
	SWAP	D4			; x in the track
	MULU	#72,D3
	ADD.W	#42,D3			; narrow track
	MOVE.W	D4,D2			; heads: narrow track centred
	SUB.W	rwd_HdC,D2
	BMI.S	.h0
	CMP.W	#71,D2
	BLS.S	.h1
.h0:	MOVEQ	#0,D2
.h1:	ADD.W	D3,D2
	MOVE.W	D3,D1			; bevel, thin dividers, dark
	CMP.W	#4,D4
	BHS.S	.p1
	ADD.W	D4,D1
	BRA.S	.put
.p1:	MOVE.W	D4,D6			; dividers after the note and sample
	SUB.W	rwd_PadA,D6		; field, moved by the extra
	CMP.W	#54,D6
	BLT.S	.p4
	BEQ.S	.put
	CMP.W	#55,D6
	BEQ.S	.p3
	SUB.W	rwd_PadB,D6
	CMP.W	#86,D6
	BEQ.S	.put
	CMP.W	#87,D6
	BEQ.S	.p3
.p4:	ADDQ.W	#1,D1
.p3:	ADDQ.W	#3,D1
	BRA.S	.put
.w5:	MOVE.W	#618,D1			; right of the tracks: dark
	MOVE.W	D1,D2
	MOVE.W	rwd_W,D3
	SUB.W	#16,D3
	CMP.W	D3,D0
	BLO.S	.put
	MOVE.W	D0,D1			; scroll bar column
	SUB.W	rwd_W,D1
	ADD.W	#640,D1
	MOVE.W	D1,D2
.put:	MOVE.W	D1,(A0)+
	MOVE.W	D2,(A1)+
	ADDQ.W	#1,D0
	CMP.W	rwd_W,D0
	BLO.W	.w
	WMLEA	WM_FX,A0
	MOVEQ	#0,D0			; narrow x
.f:	MOVE.W	D0,D1
	CMP.W	#42,D0
	BLO.S	.fp
	CMP.W	#618,D0
	BHS.S	.f5
	MOVEQ	#0,D3
	MOVE.W	D0,D3
	SUB.W	#42,D3
	DIVU	#72,D3
	CMP.W	D5,D3			; hidden track: off screen
	BLO.S	.fv
	MOVEQ	#-1,D1
	BRA.S	.fp
.fv:	MOVE.L	D3,D4
	SWAP	D4
	MULU	rwd_Slot,D3
	ADD.W	#RWD_X0,D3
	MOVE.W	D3,D1
	ADD.W	D4,D1
	CMP.W	#4,D4			; bevel 1:1, the rest doubled
	BLO.S	.fp
	MOVE.W	D4,D1
	ADD.W	D1,D1
	SUBQ.W	#6,D1
	BSR.W	pt_RwdUShift
	ADD.W	D3,D1
	BSET	#15,D1
	BRA.S	.fp
.f5:	CMP.W	#624,D0
	BHS.S	.f6
	SUB.W	#618,D1
	ADD.W	D1,D1
	ADD.W	#RWD_XE,D1
	BSET	#15,D1
	BRA.S	.fp
.f6:	ADD.W	rwd_W,D1
	SUB.W	#640,D1
.fp:	MOVE.W	D1,(A0)+
	ADDQ.W	#1,D0
	CMP.W	#640,D0
	BLO.S	.f
	BSR.W	pt_TrkTabs		; track view: own pattern/head maps
	WMLEA	WM_DBL,A0
	MOVEQ	#0,D0
.d:	MOVEQ	#0,D1
	MOVEQ	#7,D2
.d1:	LSL.W	#2,D1
	BTST	D2,D0
	BEQ.S	.d2
	ADDQ.W	#3,D1
.d2:	DBF	D2,.d1
	MOVE.W	D1,(A0)+
	ADDQ.W	#1,D0
	CMP.W	#256,D0
	BLO.S	.d
	MOVEM.L	(A7)+,D5-D6
	RTS

; wide without the renderer bitmap: classic for this session
pt_RwdCheck:
	TST.B	rtg_Wide
	BEQ.S	.r
	TST.L	rpr_BM
	BNE.S	.r
	DK	'~'
	ST	rtg_WideFail
	SF	rtg_Wide
	BSR.W	pt_RwdFree
	BSR.W	pt_RtgWinOut
	BSR.W	pt_RprAlloc
.r:	RTS

; window x -> line x for the window width: top (panel, stage), heads,
; pattern lines, full width lines
pt_RwdMaps:
	MOVEM.L	D0-D6/A0-A5,-(A7)
	SF	rwd_StDxOk		; stage map changes
	BSR.W	pt_RwdStgFit
	MOVE.W	rwd_W,D4
	SUB.W	#16,D4			; scroll bar column
	MOVE.W	D4,D6
	SUB.W	#640,D6
	MOVE.W	rwd_W,D5
	SUB.W	#640,D5
	MOVEQ	#0,D2
	MOVE.W	rtg_WinW,D2
	DIVU	rwd_W,D2		; x factor
	MOVEA.L	rtg_XMap,A0
	WMLEA	WM_XH,A1
	WMLEA	WM_XT,A2
	WMLEA	WM_XS,A3
	WMLEA	WM_HMAP,A4
	WMLEA	WM_TMAP,A5
	MOVEQ	#0,D0
.l:	MOVEQ	#0,D1
	MOVE.W	D0,D1
	DIVU	D2,D1			; wide x
	MOVE.W	D1,D3
	CMP.W	#640,D3
	BLO.S	.h
	MOVE.W	#640,D3			; stage pixel
.h:	MOVE.W	D3,(A0)+
	MOVE.W	D1,D3			; full width: right part repeated
	CMP.W	D6,D3
	BLO.S	.s
	CMP.W	D4,D3
	BHS.S	.s1
	AND.W	#31,D3
	ADD.W	#592,D3
	BRA.S	.s
.s1:	SUB.W	D5,D3
.s:	MOVE.W	D3,(A3)+
	ADD.W	D1,D1
	MOVE.W	(A4,D1.W),(A1)+
	MOVE.W	(A5,D1.W),(A2)+
	ADDQ.W	#1,D0
	CMP.W	rtg_WinW,D0
	BLO.S	.l
	WMLEA	WM_XA,A0		; stage rows: stretched, centred
	MOVEQ	#0,D0
.la:	MOVEQ	#0,D1
	MOVE.W	D0,D1
	DIVU	D2,D1
	BSR.W	pt_RwdStgX
	MOVE.W	D1,(A0)+
	ADDQ.W	#1,D0
	CMP.W	rtg_WinW,D0
	BLO.S	.la
	BSR.S	pt_RwdTopMap
	MOVEM.L	(A7)+,D0-D6/A0-A5
	BRA.W	pt_TrkBarMap		; track view: slider over the tracks

; panel top row map (rwd_Main: exit widened, else 1:1)
pt_RwdTopMap:
	MOVEM.L	D0-D2/A0,-(A7)
	MOVEQ	#0,D2
	MOVE.W	rtg_WinW,D2
	DIVU	rwd_W,D2		; x factor
	WMLEA	WM_X0,A0
	MOVEQ	#0,D0
.l0:	MOVEQ	#0,D1
	MOVE.W	D0,D1
	DIVU	D2,D1
	BSR.S	pt_RwdTopX
	MOVE.W	D1,(A0)+
	ADDQ.W	#1,D0
	CMP.W	rtg_WinW,D0
	BLO.S	.l0
	MOVEM.L	(A7)+,D0-D2/A0
	RTS

; stage over the window right of the panel: rwd_StX, rwd_StE px wide
; (1280: as is, wider: stretched to the window edge)
pt_RwdStgFit:
	MOVE.W	rwd_W,D0
	SUB.W	#640,D0
	CMP.W	#640,D0
	BHS.S	.f
	MOVE.W	#640,D0
.f:	MOVE.W	D0,rwd_StE
	MOVE.W	#640,rwd_StX
	RTS

; stage rows: wide x d1.w -> line x (640: black)
pt_RwdStgX:
	CMP.W	#640,D1
	BLO.S	.r
	SUB.W	rwd_StX,D1
	BMI.S	.k
	CMP.W	rwd_StE,D1
	BHS.S	.k
	MULU	#640,D1
	DIVU	rwd_StE,D1
	ADD.W	#640,D1
.r:	RTS
.k:	MOVE.W	#640,D1
	RTS

; top row: wide x d1.w -> line x; exit takes the screen button cell
; (the window has its own), right of the panel the title strip
pt_RwdTopX:
	CMP.W	#RWD_EXIT,D1
	BLO.S	.r
	CMP.W	#640,D1
	BHS.S	.st
	TST.B	rwd_Main		; other pages: 1:1
	BEQ.S	.r
	CMP.W	#639,D1
	BNE.S	.e1
	MOVE.W	#RWD_BTN-1,D1		; exit right edge
	RTS
.e1:	CMP.W	#RWD_EXIT,D1
	BEQ.S	.r
	SUBQ.W	#8,D1			; label half the button further right
	CMP.W	#RWD_EXIT+2,D1
	BHS.S	.e2
	MOVE.W	#RWD_EXIT+2,D1
.e2:	CMP.W	#RWD_BTN-3,D1
	BLS.S	.r
	MOVE.W	#RWD_BTN-3,D1
.r:	RTS
.st:	MOVE.L	D0,-(A7)		; strip over the stage only
	MOVE.W	rwd_StX,D0
	CMP.W	D0,D1
	BLO.S	.bk
	BNE.S	.s1
	MOVE.L	(A7)+,D0
	MOVE.W	#RWD_LB,D1		; strip left edge
	RTS
.s1:	ADD.W	rwd_StE,D0
	CMP.W	D0,D1
	BHS.S	.bk
	SUBQ.W	#1,D0
	CMP.W	D0,D1
	BNE.S	.s2
	MOVE.L	(A7)+,D0
	MOVE.W	#RWD_LB+2,D1		; right edge
	RTS
.s2:	MOVE.W	rwd_StE,D0		; text centred over the stage
	SUB.W	#RWD_TXTN,D0
	LSR.W	#1,D0
	ADD.W	rwd_StX,D0
	SUB.W	D0,D1
	MOVEM.L	(A7)+,D0		; (flags kept)
	BMI.S	.s3
	CMP.W	#RWD_TXTN,D1
	BHS.S	.s3
	ADD.W	#RWD_LB+3,D1		; title text
	RTS
.s3:	MOVE.W	#RWD_LB+1,D1		; strip inside
	RTS
.bk:	MOVE.L	(A7)+,D0
	MOVE.W	#640,D1			; beside the stage: black
	RTS

; window row: stage pixel behind the line (black)
pt_RwdStage:
	MOVEM.L	D1/A0,-(A7)
	MOVEQ	#0,D1
	BSR.W	pt_RtgSprCol
	MOVEA.L	rtg_LineBuf,A0
	MOVE.B	D1,640(A0)
	CMPI.W	#RWD_TOPEND,rtg_NatRow	; panel top row: title strip
	BHI.S	.s
	BSR.S	pt_RwdTitle
	BRA.S	.r
.s:	TST.B	rwd_On			; below: analyzer
	BEQ.S	.r
	CMPI.W	#RWD_STTOP,rtg_NatRow
	BHS.S	.hd
	BSR.W	pt_RwdStRow
	BRA.S	.r
.hd:	MOVEM.L	D0,-(A7)		; track view: head numbers
	BSR.W	pt_TrkHead
	MOVEM.L	(A7)+,D0
.r:	MOVEM.L	(A7)+,D1/A0
	RTS

; title strip pixels of this line into the line buffer: edges and inside
; from the screen button cell (its bevel colours, the same on every
; page), text white with black shadow
pt_RwdTitle:
	MOVEM.L	D0-D7/A0-A2,-(A7)
	MOVEA.L	rtg_LineBuf,A0
	CMPI.W	#2,dat_UIMode		; help: own palette, panel colours
	BEQ.S	.own
	TST.B	rwd_Main
	BEQ.S	.lb
	CMPI.W	#5,rtg_NatRow		; panel colours 1-3 kept for help
	BNE.S	.lb
	MOVE.L	rtg_Colors+2,rwd_TCol
	MOVE.W	rtg_Colors+6,rwd_TCol+4
.lb:	MOVE.B	RWD_BTN(A0),RWD_LB(A0)
	MOVE.B	RWD_BTN+1(A0),RWD_LB+1(A0)
	MOVE.B	639(A0),RWD_LB+2(A0)
	MOVE.B	RWD_BTN+1(A0),D4	; inside
	MOVE.B	RWD_BTN(A0),D5		; text (white edge of rows 1-9)
	MOVE.B	639(A0),D6		; shadow (black edge)
	BRA.S	.go
.own:	MOVE.W	rwd_TCol,D1		; light, grey, dark as pens
	BSR.W	pt_RtgSprCol
	MOVE.B	D1,D5
	MOVE.W	rwd_TCol+2,D1
	BSR.W	pt_RtgSprCol
	MOVE.B	D1,D4
	MOVE.W	rwd_TCol+4,D1
	BSR.W	pt_RtgSprCol
	MOVE.B	D1,D6
	MOVE.B	D5,D0			; bevel: rows 1-9 light grey dark
	MOVE.B	D4,D1
	MOVE.B	D6,D2
	TST.W	rtg_NatRow
	BNE.S	.o1
	MOVE.B	D5,D1			; top: light light grey
	MOVE.B	D4,D2
.o1:	CMPI.W	#RWD_TOPEND,rtg_NatRow
	BNE.S	.o2
	MOVE.B	D4,D0			; bottom: grey dark dark
	MOVE.B	D6,D1
.o2:	MOVE.B	D0,RWD_LB(A0)
	MOVE.B	D1,RWD_LB+1(A0)
	MOVE.B	D2,RWD_LB+2(A0)
	MOVE.B	D1,D4			; inside
.go:	LEA	RWD_LB+3(A0),A1
	MOVE.W	rtg_NatRow,D7
	SUBQ.W	#2,D7			; glyph line
	LEA	dat_146F,A2		; narrow track font
	ADDA.L	dat_TrackFontOffset,A2
	LEA	1024(A2),A2
	MOVEQ	#0,D0			; pixel
.p:	MOVE.B	D4,D3
	MOVE.W	D7,D1
	SUBQ.W	#1,D1
	MOVE.W	D0,D2
	SUBQ.W	#1,D2
	BSR.S	.bit			; shadow: one up, one left
	BEQ.S	.f
	MOVE.B	D6,D3
.f:	MOVE.W	D7,D1
	MOVE.W	D0,D2
	BSR.S	.bit
	BEQ.S	.w
	MOVE.B	D5,D3
.w:	MOVE.B	D3,(A1)+
	ADDQ.W	#1,D0
	CMP.W	#RWD_TXTN,D0
	BLO.S	.p
	MOVEM.L	(A7)+,D0-D7/A0-A2
	RTS
; d1 = glyph line, d2 = pixel of the text -> z=0 set
.bit:	TST.W	D1
	BMI.S	.no
	CMP.W	#7,D1
	BHI.S	.no
	TST.W	D2
	BMI.S	.no
	CMP.W	#8*8,D2
	BHS.S	.no
	MOVEM.L	D3-D4,-(A7)
	MOVE.W	D2,D3
	LSR.W	#3,D3			; char
	LEA	rwd_Title(PC),A0
	MOVEQ	#0,D4
	MOVE.B	(A0,D3.W),D4
	SUB.W	#$20,D4
	ADD.W	D4,D4
	MOVE.W	D1,D3
	LSL.W	#7,D3			; 128 bytes per line
	ADD.W	D3,D4
	MOVE.B	(A2,D4.W),D4
	MOVE.W	D2,D3
	AND.W	#7,D3
	EOR.W	#7,D3
	BTST	D3,D4
	MOVEM.L	(A7)+,D3-D4		; flags stay
	RTS
.no:	CMP.W	D0,D0			; z=1
	RTS
rwd_Title:	DC.B	"ANALYZER"
	EVEN

; after the copper walk: pattern view by the renderer -> rwd_On; the
; lines above the section are walked before it shows up in a frame
pt_RwdLay:
	MOVE.L	D0,-(A7)
	MOVEQ	#0,D0
	TST.B	rtg_Wide
	BEQ.S	.s
	TST.B	rtg_PatOn
	BEQ.S	.s
	TST.B	rtg_RprOn
	BEQ.S	.s
	MOVEQ	#-1,D0
.s:	CMP.B	rwd_On,D0
	BEQ.S	.r
	MOVE.B	D0,rwd_On
	BSR.W	pt_RtgInvalidate	; layout moved: every line again
.r:	MOVEQ	#-1,D0			; main panel in the top row
	CMPI.W	#1,dat_UIMode
	BEQ.S	.m
	CMPI.W	#9,dat_UIMode		; pos editor: below it
	BEQ.S	.m
	MOVEQ	#0,D0
.m:	CMP.B	rwd_Main,D0
	BEQ.S	.m1
	MOVE.B	D0,rwd_Main
	TST.L	rwd_Mem
	BEQ.S	.m1
	BSR.W	pt_RwdTopMap
	BSR.W	pt_RtgInvalidate
.m1:	BSR.W	pt_TrkLay
	BSR.W	pt_TrkBarChk
	BSR.W	pt_RwdShowChk
	MOVE.L	(A7)+,D0
	RTS

; frame start, before the copper walk: stage drawn, its rows hot now
; (also without the renderer: levels fall, no half drawn bar stays)
pt_RwdStgPre:
	TST.B	rtg_Wide
	BEQ.S	.r
	TST.L	rwd_Mem
	BEQ.S	.r
	BSR.W	pt_RwdScope
.r:	RTS

; shown track count changed: maps and stage again
pt_RwdShowChk:
	MOVEM.L	D0,-(A7)
	BSR.W	pt_RwdShow
	CMP.B	rwd_ShowKey,D0
	BEQ.S	.r
	MOVE.B	D0,rwd_ShowKey
	TST.B	trk_On
	BNE.S	.r
	TST.L	rwd_Mem
	BEQ.S	.r
	BSR.W	pt_RwdTabs
	BSR.W	pt_RwdMaps
	BSR.W	pt_TrkStgInit		; clears the stage, boxes of the shown
	ST	rpr_TplNew
	SF	rwd_BarOk
	BSR.W	pt_RtgInvalidate
.r:	MOVEM.L	(A7)+,D0
	RTS

; x table of the line being written -> a2
pt_RwdXMap:
	MOVEA.L	rtg_XMap,A2
	TST.B	rtg_Wide
	BEQ.S	.r
	TST.B	rwd_On
	BEQ.S	.r
	MOVE.L	D0,-(A7)
	MOVE.W	rtg_NatRow,D0
	BMI.S	.x
	CMP.W	#RWD_TOPEND,D0		; panel top row
	BHI.S	.nt
	WMLEA	WM_X0,A2
	BRA.S	.x
.nt:	CMP.W	#RWD_STTOP,D0
	BGE.S	.ns
	WMLEA	WM_XA,A2		; analyzer stage
	BRA.S	.x
.ns:
	CMP.W	#RWD_HDTOP,D0
	BGE.S	.h
	WMLEA	WM_XS,A2
	BRA.S	.x
.h:	CMP.W	#RWD_HDEND,D0
	BGT.S	.t
	WMLEA	WM_XH,A2
	BRA.S	.x
.t:	WMLEA	WM_XT,A2		; pattern frame lines
.x:	MOVE.L	(A7)+,D0
.r:	RTS

; mouse: window x d2 -> picture x (wide: 0-1279)
pt_RtgMX:
	SF	rtg_InStage
	TST.B	rtg_Wide
	BEQ.S	.n
	MULU	rwd_W,D2
	BRA.S	.d
.n:	MULU	#640,D2
.d:	DIVU	rtg_WinW,D2
	RTS

; mouse: wide picture x d2, pt line d3 -> pt x d2
pt_RwdMouse:
	TST.B	rtg_Wide
	BEQ.W	.r
	JSR	pt_LmbRaw41		; button up: next press counts again
	BEQ.S	.dn
	SF	trk_HeadLatch
.dn:	MOVEM.L	D0-D1,-(A7)
	TST.B	rwd_On
	BEQ.W	.top
	TST.B	trk_On			; track view slider: no buttons for pt
	BEQ.S	.nt
	BSR.W	pt_TrkBarMouse
	BEQ.S	.nt
	MOVE.W	#639,D2
	ST	rtg_InStage
	BRA.W	.x
.nt:	CMP.W	#RWD_HDTOP,D3
	BLT.W	.top
	MOVE.W	rwd_W,D0
	SUB.W	#16,D0
	CMP.W	D0,D2
	BLO.S	.n1
	SUB.W	rwd_W,D2		; scroll bar
	ADD.W	#640,D2
	BRA.W	.x
.n1:	CMP.W	#RWD_X0,D2
	BHS.S	.n2
	CMP.W	#RWD_HDEND,D3		; pos column
	BGT.S	.np
	CMP.W	#42,D2
	BLO.W	.x
	MOVEQ	#41,D2
	BRA.W	.x
.np:	MULU	#42,D2
	DIVU	#RWD_X0,D2
	BRA.W	.x
.n2:	TST.B	trk_On			;41 track view: its own end
	BEQ.S	.n3
	CMP.W	trk_XE,D2
	BLO.W	.tk
	BRA.W	.tx			; dark edge before the scroll bar
.n3:	BSR.W	pt_RwdXE
	CMP.W	D0,D2
	BLO.S	.tr
	SUB.W	D0,D2			; right of the tracks
	AND.L	#$ffff,D2
	DIVU	#11,D2
	ADD.W	#618,D2
	CMP.W	#626,D2			;41 stay left of pt's scroll bar
	BLS.W	.x
	MOVE.W	#626,D2
	BRA.W	.x
.tr:	MOVEQ	#0,D0
	MOVE.W	D2,D0
	SUB.W	#RWD_X0,D0
	DIVU	rwd_Slot,D0
	MOVE.L	D0,D1
	SWAP	D1			; x in the track
	MULU	#72,D0
	CMP.W	#RWD_HDEND,D3
	BGT.S	.tp
	SUB.W	rwd_HdC,D1		; heads: centred
	BRA.S	.tc
.tp:	BSR.W	pt_RwdTShift		; extra of the fields out
	SUBQ.W	#6,D1			; pattern: text doubled
	ASR.W	#1,D1
	ADDQ.W	#6,D1
.tc:	TST.W	D1
	BPL.S	.t0
	MOVEQ	#0,D1
.t0:	CMP.W	#71,D1
	BLS.S	.t1
	MOVEQ	#71,D1
.t1:	ADD.W	#42,D1
	ADD.W	D1,D0
	MOVE.W	D0,D2
	BRA.W	.x
.tk:	MOVE.L	D4,-(A7)		;41 track, x in it, its width
	MOVE.W	D2,D0
	BSR.W	pt_TrkHitX
	CMP.W	trk_Vis,D0		; maps may lag a resize
	BLO.S	.tv
	MOVE.W	trk_Vis,D0
	SUBQ.W	#1,D0
.tv:	ADD.W	trk_First,D0		; channel
	MOVE.W	D0,D4
	LSR.W	#2,D4
	CMP.W	trk_Grp,D4		; only pt's edited group takes clicks
	BNE.S	.tm
	CMP.W	#RWD_HDEND,D3
	BGT.S	.tf
	SUB.W	#TRK_SLOT,D2		; heads: base track centred
	ASR.W	#1,D2
	SUB.W	D2,D1
	BPL.S	.th
	MOVEQ	#0,D1
.th:	CMP.W	#TRK_SLOT-1,D1
	BLS.S	.tb
	MOVEQ	#TRK_SLOT-1,D1
	BRA.S	.tb
.tf:	BSR.W	pt_TrkTShift		; pattern: pads out, the field kept
.tb:	MOVE.L	(A7)+,D4
	AND.W	#3,D0
	MULU	#2*TRK_SLOT,D0		; pt's 4 channel track
	ADD.W	D1,D1
	ADD.W	D1,D0
	ADD.W	#TRK_NAT,D0
	MOVE.W	D0,D2
	BRA.W	.x
.tm:	MOVE.L	(A7)+,D4
.tn:	CMP.W	#RWD_HDTOP,D3		; other group: a head switches the channel
	BLT.S	.tx
	CMP.W	#RWD_HDEND,D3
	BGT.S	.tx
	CMP.W	wide_Ch,D0		; only channels of the module
	BHS.S	.tx
	JSR	pt_TrkHeadReq41
.tx:	MOVE.W	#639,D2			; nothing for pt
	ST	rtg_InStage
	BRA.W	.x
.top:	CMP.W	#RWD_TOPEND,D3		; exit grew over the screen button
	BHI.S	.t2
	TST.B	rwd_Main		; main panel only
	BEQ.S	.t2
	CMP.W	#RWD_BTN,D2
	BLO.S	.t2
	CMP.W	#640,D2
	BHS.S	.t2
	MOVE.W	#(RWD_EXIT+RWD_BTN)/2,D2
	BRA.W	.x
.t2:	CMP.W	#640,D2
	BLO.W	.x
	MOVE.W	#639,D2
	ST	rtg_InStage
.x:	MOVEM.L	(A7)+,D0-D1
.r:	RTS

; font of the pattern text: glyph table, rows again on a change
pt_RwdFont:
	MOVEM.L	D0/A0,-(A7)
	LEA	dat_146F,A0
	ADDA.L	dat_TrackFontOffset,A0
	CMPA.L	rwd_Font,A0
	BEQ.S	.r
	MOVE.L	A0,rwd_Font
	WMLEA	WM_GLY,A0
	MOVEQ	#256/4-1,D0
.c:	CLR.L	(A0)+
	DBF	D0,.c
	BSR.W	pt_RprInval
.r:	MOVEM.L	(A7)+,D0/A0
	RTS

; template lines through the pattern map
pt_RwdTpl:
	MOVEM.L	D0-D2/A0-A2,-(A7)
	RMLEA	RM_TPL,A0
	WMLEA	WM_TPL,A1
	MOVEQ	#1,D2
.p:	WMLEA	WM_TMAP,A2
	MOVE.W	rwd_W,D1
	SUBQ.W	#1,D1
.l:	MOVE.W	(A2)+,D0
	MOVE.B	(A0,D0.W),(A1)+
	DBF	D1,.l
	LEA	640(A0),A0
	DBF	D2,.p
	MOVEM.L	(A7)+,D0-D2/A0-A2
	RTS

; bar line d0 (0-8) before sprites
pt_RwdPre:
	TST.L	rwd_Mem
	BEQ.S	.r
	MOVEM.L	D0-D1/A0-A1,-(A7)
	MULU	#640,D0
	WMLEA	WM_BPRE,A1
	ADDA.L	D0,A1
	MOVEA.L	rtg_LineBuf,A0
	MOVE.W	#640/4-1,D1
.c:	MOVE.L	(A0)+,(A1)+
	DBF	D1,.c
	MOVEM.L	(A7)+,D0-D1/A0-A1
.r:	RTS

; pattern row d5 (0-63): pt's narrow text -> wide text
pt_RwdRow:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	WMLEA	WM_TXT,A1
	MOVE.W	D5,D0
	MULU	#8*RWD_TS,D0
	ADDA.L	D0,A1
	MOVEA.L	A1,A2
	MOVE.W	#8*RWD_TS/4-1,D0
.cl:	CLR.L	(A2)+
	DBF	D0,.cl
	MOVE.W	D5,D0
	LSL.W	#3,D0
	ADD.W	#RTG_PATCUR-4,D0
	MULU	#80,D0
	MOVEA.L	dat_ScreenBuf2Ptr,A0
	ADDA.L	D0,A0
	MOVEA.L	A0,A2			; pos column as it is
	MOVEA.L	A1,A3
	MOVEQ	#7,D1
.pc:	MOVE.L	(A2),(A3)
	MOVE.W	4(A2),4(A3)
	LEA	80(A2),A2
	LEA	RWD_TS(A3),A3
	DBF	D1,.pc
	TST.B	trk_On			; track view: cells from wide_Pat
	BEQ.S	.nt
	BSR.W	pt_TrkRow
	BRA.S	.x
.nt:	MOVEA.L	rwd_Font,A4
	LEA	6(A0),A2		; narrow: 9 bytes a track
	LEA	7(A1),A3		; wide: 18 bytes a track
	BSR.W	pt_RwdShow
	MOVE.W	D0,D7
	SUBQ.W	#1,D7
	MOVE.W	rwd_Slot,D4
	LSR.W	#3,D4			; track bytes
.tr:	MOVE.L	A3,-(A7)
	MOVE.W	rwd_TxA,D0		; text centred in its field
	LSR.W	#3,D0
	ADDA.W	D0,A3
	MOVEQ	#7,D6
.ch:	CMP.W	#4,D6			; sample field
	BNE.S	.c1
	MOVE.W	rwd_PadA,D0
	SUB.W	rwd_TxA,D0
	ADD.W	rwd_TxB,D0
	BRA.S	.c2
.c1:	CMP.W	#2,D6			; effect field
	BNE.S	.c3
	MOVE.W	rwd_PadB,D0
	SUB.W	rwd_TxB,D0
	ADD.W	rwd_TxC,D0
.c2:	LSR.W	#3,D0
	ADDA.W	D0,A3
.c3:	BSR.W	pt_RwdGlyph
	ADDQ.L	#1,A2
	ADDQ.L	#2,A3
	DBF	D6,.ch
	ADDQ.L	#1,A2
	MOVEA.L	(A7)+,A3
	ADDA.W	D4,A3
	DBF	D7,.tr
.x:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; narrow glyph at a2 (80 a line) -> wide char at a3 (160), a4 font
pt_RwdGlyph:
	LEA	rwd_G,A5
	MOVEA.L	A2,A6
	MOVEQ	#0,D0			; hash
	MOVEQ	#0,D3
	MOVEQ	#7,D2
.g:	MOVE.B	(A6),D1
	MOVE.B	D1,(A5)+
	OR.B	D1,D3
	ROL.B	#1,D0
	ADD.B	D1,D0
	LEA	80(A6),A6
	DBF	D2,.g
	TST.B	D3
	BEQ.S	.r			; blank
	WMLEA	WM_GLY,A5
	MOVEQ	#0,D1
	MOVE.B	(A5,D0.W),D1
	BEQ.S	.s
	SUBQ.W	#1,D1
	BSR.S	.cmp
	BEQ.S	.w
.s:	MOVEQ	#63,D1
.sl:	BSR.S	.cmp
	BEQ.S	.got
	DBF	D1,.sl
	LEA	rwd_G,A5		; not in the font: pixels doubled
	WMLEA	WM_DBL,A6
	MOVEQ	#0,D2
.d:	MOVEQ	#0,D1
	MOVE.B	(A5)+,D1
	ADD.W	D1,D1
	MOVE.W	(A6,D1.W),D1
	MOVE.B	D1,1(A3,D2.W)
	LSR.W	#8,D1
	MOVE.B	D1,(A3,D2.W)
	ADD.W	#RWD_TS,D2
	CMP.W	#8*RWD_TS,D2
	BLO.S	.d
.r:	RTS
.got:	WMLEA	WM_GLY,A5
	MOVE.B	D1,(A5,D0.W)
	ADDQ.B	#1,(A5,D0.W)
.w:	LEA	(A4,D1.W),A6		; wide glyph: 2 bytes a line
	ADDA.W	D1,A6
	MOVEQ	#0,D2
.wl:	MOVE.B	(A6),(A3,D2.W)
	MOVE.B	1(A6),1(A3,D2.W)
	LEA	128(A6),A6
	ADD.W	#RWD_TS,D2
	CMP.W	#8*RWD_TS,D2
	BLO.S	.wl
	RTS
.cmp:	MOVEM.L	D1-D2/A5-A6,-(A7)	; narrow char d1 = rwd_G? z=1 yes
	LEA	rwd_G,A5
	LEA	1024(A4),A6
	ADDA.W	D1,A6
	ADDA.W	D1,A6
	MOVEQ	#7,D2
.c:	MOVE.B	(A6),D1
	CMP.B	(A5)+,D1
	BNE.S	.cx
	LEA	128(A6),A6
	DBF	D2,.c
.cx:	MOVEM.L	(A7)+,D1-D2/A5-A6
	RTS

; wide slot: d0 = row -> WM_LINE (8 x 1280); the ring has normal rows only
pt_RwdBuild:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	WMLEA	WM_LINE,A1
	MOVEQ	#0,D6			; line 0..7
	MOVE.W	D0,D5
	BMI.W	.e
	CMP.W	#63,D5
	BHI.W	.e
	BSR.W	pt_RwdRow
	WMLEA	WM_TXT,A0
	MULU	#8*RWD_TS,D5
	ADDA.L	D5,A0
	X20LEA	X20_RTGP2C,A3
.ln:	WMLEA	WM_TPL,A2
	BTST	#0,D6
	BEQ.S	.ev
	ADDA.W	rwd_W,A2
.ev:	MOVE.W	rwd_W,D4
	LSR.W	#3,D4
	SUBQ.W	#1,D4
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
.nl:	MOVE.W	#RWD_TS,D3		; next text line
	MOVE.W	rwd_W,D0
	LSR.W	#3,D0
	SUB.W	D0,D3
	ADDA.W	D3,A0
	ADDQ.W	#1,D6
	CMP.W	#8,D6
	BLO.S	.ln
	BRA.S	.r
.e:	WMLEA	WM_TPL,A2		; outside rows 0-63: empty
	BTST	#0,D6
	BEQ.S	.e1
	ADDA.W	rwd_W,A2
.e1:	MOVE.W	rwd_W,D0
	LSR.W	#2,D0
	SUBQ.W	#1,D0
.ec:	MOVE.L	(A2)+,(A1)+
	DBF	D0,.ec
	ADDQ.W	#1,D6
	CMP.W	#8,D6
	BLO.S	.e
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; wide cursor bar (9 x 1280): background of pt's bar through the
; pattern map, the cursor row in the wide font, sprites where pt's bar
; differs from its planes
pt_RwdBar:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.W	rpr_BarGen,D0
	SWAP	D0
	MOVE.W	rtg_PatRow,D0
	TST.B	rwd_BarOk
	BEQ.S	.go
	CMP.L	rwd_BarKey,D0
	BEQ.W	.r
.go:	MOVE.L	D0,rwd_BarKey
	ST	rwd_BarOk
	MOVE.W	rtg_PatRow,D5
	BSR.W	pt_RwdRow
	WMLEA	WM_TXT,A4
	MULU	#8*RWD_TS,D5
	ADDA.L	D5,A4
	WMLEA	WM_BPRE,A0
	RMLEA	RM_BAR,A5
	WMLEA	WM_BAR,A1
	X20LEA	X20_RTGP2C,A3
	MOVEQ	#0,D7			; bar line, 1-8 = row lines 0-7
.ln:	WMLEA	WM_TMAP,A2
	MOVE.W	rwd_W,D6
	SUBQ.W	#1,D6
	MOVEA.L	A1,A6
.bg:	MOVE.W	(A2)+,D0
	MOVE.B	(A0,D0.W),D1
	AND.B	#$fb,D1			; no text plane
	MOVE.B	D1,(A6)+
	DBF	D6,.bg
	TST.W	D7
	BEQ.S	.sp
	MOVEA.L	A1,A6
	MOVE.W	rwd_W,D6
	LSR.W	#3,D6
	SUBQ.W	#1,D6
.tx:	MOVEQ	#0,D0
	MOVE.B	(A4)+,D0
	BEQ.S	.t0
	LSL.W	#3,D0
	MOVE.L	(A3,D0.W),D1
	MOVE.L	4(A3,D0.W),D2
	LSL.L	#2,D1
	LSL.L	#2,D2
	OR.L	D1,(A6)+
	OR.L	D2,(A6)+
	DBF	D6,.tx
	BRA.S	.sp
.t0:	ADDQ.L	#8,A6
	DBF	D6,.tx
.sp:	TST.W	D7			; text line done: next one
	BEQ.S	.sp0
	MOVE.W	#RWD_TS,D0
	MOVE.W	rwd_W,D1
	LSR.W	#3,D1
	SUB.W	D1,D0
	ADDA.W	D0,A4
.sp0:	WMLEA	WM_FX,A2
	MOVEA.L	A0,A6
	MOVE.W	#639,D6
.sx:	MOVE.B	(A5)+,D1
	CMP.B	(A6)+,D1
	BNE.S	.sd
.sn:	ADDQ.L	#2,A2
	DBF	D6,.sx
	BRA.S	.nx
.sd:	MOVE.W	(A2),D0
	CMP.W	#-1,D0			; off screen (track view)
	BEQ.S	.sn
	BPL.S	.s1
	AND.W	#$7fff,D0
	MOVE.B	D1,1(A1,D0.W)
.s1:	MOVE.B	D1,(A1,D0.W)
	BRA.S	.sn
.nx:	LEA	640(A0),A0
	ADDA.W	rwd_W,A1
	ADDQ.W	#1,D7
	CMP.W	#9,D7
	BLO.W	.ln
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; sprite column at narrow x d0, native lines d1..d2-1 -> wide, twice
; as wide
pt_RwdVuCol:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.W	D0
	BPL.S	.x0
	MOVEQ	#0,D0
.x0:	CMP.W	#640-RPR_VUW,D0
	BLS.S	.x1
	MOVE.W	#640-RPR_VUW,D0
.x1:	WMLEA	WM_FX,A0
	ADD.W	D0,D0
	MOVE.W	(A0,D0.W),D4
	AND.W	#$7ff8,D4		; wide x, byte aligned
	MOVE.W	rwd_W,D3
	SUB.W	#2*RPR_VUW,D3
	CMP.W	D3,D4
	BLS.S	.x2
	MOVE.W	D3,D4
.x2:	MOVE.W	D2,D6
	CMP.W	D6,D1
	BGE.W	.out
	MOVE.W	D1,rpr_VuTop
	SUB.W	D1,D2
	MOVE.W	D2,rpr_VuLines
	WMLEA	WM_VU,A1
	MOVE.W	D1,D5			; native line
.ln:	MOVE.W	D5,D7
	MOVE.W	D5,D0
	ADD.W	rtg_Shift,D0
	SUB.W	#RTG_PATTOP,D0
	MOVE.W	D0,D1
	AND.W	#7,D1			; line in the row
	LSR.W	#3,D0
	ADD.W	rtg_PatRow,D0
	SUB.W	rpr_C,D0		; pattern row
	WMLEA	WM_TPL,A3
	BTST	#0,D1
	BEQ.S	.ev
	ADDA.W	rwd_W,A3
.ev:	ADDA.W	D4,A3
	MOVEQ	#2*RPR_VUW/4-1,D2
.tc:	MOVE.L	(A3)+,(A1)+
	DBF	D2,.tc
	LEA	-2*RPR_VUW(A1),A1
	TST.W	D0
	BMI.S	.spr
	CMP.W	#63,D0
	BHI.S	.spr
	MULU	#8*RWD_TS,D0
	MULU	#RWD_TS,D1
	ADD.L	D1,D0
	WMLEA	WM_TXT,A0
	ADDA.L	D0,A0
	MOVE.W	D4,D0
	LSR.W	#3,D0
	ADDA.W	D0,A0
	X20LEA	X20_RTGP2C,A3
	MOVEA.L	A1,A4
	MOVEQ	#2*RPR_VUW/8-1,D3
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
.spr:	BSR.W	pt_RwdVuSpr
	LEA	2*RPR_VUW(A1),A1
	ADDQ.W	#1,D5
	CMP.W	D6,D5
	BLO.W	.ln
	MOVE.W	D4,D0
	MOVE.W	rpr_VuTop,D1
	ADD.W	rtg_Shift,D1
	MOVE.W	rpr_VuLines,D2
	BSR.W	pt_RprRect
.out:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; sprites on native line d7 into the wide column at x d4, buffer a1
pt_RwdVuSpr:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.W	D7,D2
	ADD.W	rtg_VStart,D2		; raster line
	MOVEA.L	rtg_RowSt,A5		; colours of that line
	MOVE.W	D7,D0
	MULU	#RTG_STSIZE,D0
	ADDA.L	D0,A5
	LEA	28+32(A5),A5		; colour 16
	X20LEA	X20_RTGCOLMAP,A6
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
	MOVE.W	6(A0),D5		; narrow hires x of pixel 15
	SUB.W	rtg_DiwH,D5
	ADD.W	D5,D5
	WMLEA	WM_FX,A3
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
	BSR.S	.put			; 2 narrow px
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
.put:	CMP.W	#639,D5			; d0 colour at narrow x d5 (off: skip)
	BHI.S	.pn
	MOVE.W	D5,D1
	ADD.W	D1,D1
	MOVE.W	(A3,D1.W),D1
	BPL.S	.p1
	AND.W	#$7fff,D1
	SUB.W	D4,D1
	ADDQ.W	#1,D1
	CMP.W	#2*RPR_VUW-1,D1
	BHI.S	.p0
	MOVE.B	D0,(A1,D1.W)
.p0:	SUBQ.W	#1,D1
	BRA.S	.p2
.p1:	SUB.W	D4,D1
.p2:	CMP.W	#2*RPR_VUW-1,D1
	BHI.S	.pn
	MOVE.B	D0,(A1,D1.W)
.pn:	ADDQ.W	#1,D5
	RTS

;--- analyzer stage: a flat screen per track right of the panel
; codes in WM_STG: 0 stage, 1 screen, 2 zero line, 3 wave, 4 number,
; 5 number of a muted track
pt_RwdStgInit:
	MOVEM.L	D0-D3/A0,-(A7)
	BSR.W	pt_RwdGeom
	SF	rwd_ScMute
	MOVEQ	#0,D2			; box
.b:	WMLEA	WM_STG,A0
	MOVE.W	D2,D0
	MULU	rwd_BoxP,D0
	ADD.W	rwd_BoxX,D0
	ADD.L	#RWD_BY*640,D0
	ADDA.L	D0,A0
	MOVEQ	#0,D1			; box row
.y:	MOVEQ	#1,D3
	CMP.W	#RWD_MID-RWD_BY,D1
	BNE.S	.g
	MOVEQ	#2,D3
.g:	MOVE.W	rwd_BoxW,D0
	SUBQ.W	#1,D0
.x:	MOVE.B	D3,(A0,D0.W)
	DBF	D0,.x
	LEA	640(A0),A0
	ADDQ.W	#1,D1
	CMP.W	#RWD_BH,D1
	BLO.S	.y
	MOVE.W	D2,D0
	MOVEQ	#4,D1
	BSR.S	pt_RwdLabel
	ADDQ.W	#1,D2
	BSR.W	pt_RwdShow
	CMP.W	D0,D2
	BLO.S	.b
	MOVEM.L	(A7)+,D0-D3/A0
	RTS

; track number d0 (box) in code d1, narrow track font, top left
pt_RwdLabel:
	MOVEM.L	D0-D4/A0-A3,-(A7)
	WMLEA	WM_STG,A0
	MOVE.W	D0,D2
	MULU	rwd_BoxP,D2
	ADD.W	rwd_BoxX,D2
	ADD.L	#3+(RWD_BY+3)*640,D2
	ADDA.L	D2,A0
	LEA	dat_146F,A2
	ADDA.L	dat_TrackFontOffset,A2
	LEA	1024(A2),A2
	ADD.W	#'1'-$20,D0		; 2 bytes a char
	ADD.W	D0,D0
	ADDA.W	D0,A2
	WMLEA	WM_SGEN,A1
	LEA	RWD_BY+3(A1),A1
	MOVEQ	#8-1,D3
.l:	MOVE.B	(A2),D4
	MOVEA.L	A0,A3
	MOVEQ	#7,D2
.p:	BTST	D2,D4
	BEQ.S	.n
	MOVE.B	D1,(A3)
.n:	ADDQ.L	#1,A3
	DBF	D2,.p
	ADDQ.B	#1,(A1)+
	LEA	640(A0),A0
	LEA	128(A2),A2
	DBF	D3,.l
	MOVEM.L	(A7)+,D0-D4/A0-A3
	RTS

; every frame: scopes from the replayer's scope state (vu8_Src), only
; changed columns drawn; their rows hot for the mirror
pt_RwdScope:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.B	trk_On			; track view: levels of all channels
	BEQ.S	.sc
	BSR.W	pt_TrkStage
	WMLEA	WM_SGEN,A6
	BRA.W	.heat
.sc:	BSR.W	pt_RwdGeom
	LEA	vu8_Src,A4
	LEA	dat_ScopeCh1,A5
	WMLEA	WM_SPRV,A1
	WMLEA	WM_SGEN,A6
	MOVEQ	#0,D7			; track
.ch:	TST.W	(A5)			; muted: number dimmed
	SEQ	D2
	BTST	D7,rwd_ScMute
	SNE	D3
	CMP.B	D2,D3
	BEQ.S	.lb
	BCHG	D7,rwd_ScMute
	MOVEQ	#4,D1
	SUB.B	D2,D1
	MOVE.W	D7,D0
	BSR.W	pt_RwdLabel
.lb:	MOVEA.L	(A4),A2			; samples
	MOVE.W	4(A4),D6		; scale 0..32
	WMLEA	WM_STG,A3
	MOVE.W	D7,D0
	MULU	rwd_BoxP,D0
	ADD.W	rwd_BoxX,D0
	ADDA.W	D0,A3
	MOVEQ	#0,D5			; column
	MOVEQ	#0,D2			; sample, 8.8
.c:	MOVEQ	#0,D4
	TST.W	D6
	BEQ.S	.a
	MOVE.W	D2,D0
	LSR.W	#8,D0
	MOVE.B	(A2,D0.W),D4
	EXT.W	D4
	MULS	D6,D4
	MULS	#RWD_AMP,D4
	ASR.L	#8,D4
	ASR.L	#4,D4
.a:	MOVE.B	(A1),D3
	EXT.W	D3
	CMP.W	D3,D4
	BEQ.S	.nc
	MOVE.B	D4,(A1)
	BSR.S	pt_RwdCol
.nc:	ADDQ.L	#1,A1
	ADDQ.W	#1,D5
	ADD.W	rwd_Step,D2
	CMP.W	rwd_BoxW,D5
	BLO.S	.c
	ADDQ.L	#8,A4
	LEA	10(A5),A5
	ADDQ.W	#1,D7
	BSR.W	pt_RwdShow
	CMP.W	D0,D7
	BLO.W	.ch
.heat:	X20LEA	X20_RTGHEAT,A0		; changed rows: read this frame
	LEA	RWD_SCT(A0),A0
	WMLEA	WM_SLAST,A1
	MOVEQ	#RWD_SCN-1,D0
.h:	MOVE.B	(A6)+,D1
	CMP.B	(A1),D1
	BEQ.S	.hn
	MOVE.B	D1,(A1)
	TST.B	(A0)
	BNE.S	.hn
	MOVE.B	#1,(A0)
.hn:	ADDQ.L	#1,A1
	ADDQ.L	#1,A0
	DBF	D0,.h
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; column d5 of box a3: height d3 -> d4 (up positive), a6 row changes
pt_RwdCol:
	MOVEM.L	D0-D6/A0,-(A7)
	MOVE.W	D4,D6
	NEG.W	D3
	ADD.W	#RWD_MID,D3		; old end
	NEG.W	D4
	ADD.W	#RWD_MID,D4		; new end
	MOVE.W	#RWD_MID,D0		; rows d0..d1
	MOVE.W	D0,D1
	CMP.W	D3,D0
	BLE.S	.m1
	MOVE.W	D3,D0
.m1:	CMP.W	D4,D0
	BLE.S	.m2
	MOVE.W	D4,D0
.m2:	CMP.W	D3,D1
	BGE.S	.m3
	MOVE.W	D3,D1
.m3:	CMP.W	D4,D1
	BGE.S	.m4
	MOVE.W	D4,D1
.m4:	MOVE.W	#RWD_MID,D2		; wave d2..d4
	CMP.W	D4,D2
	BLE.S	.m5
	EXG	D2,D4
.m5:	TST.W	D6
	BNE.S	.m6
	MOVEQ	#-1,D4			; silent: zero line only
.m6:	MOVE.W	D0,D3
	MULU	#640,D3
	LEA	(A3,D3.L),A0
	ADDA.W	D5,A0
.y:	MOVEQ	#1,D3
	CMP.W	#RWD_MID,D0
	BNE.S	.z
	MOVEQ	#2,D3
.z:	CMP.W	D2,D0
	BLT.S	.w
	CMP.W	D4,D0
	BGT.S	.w
	MOVEQ	#3,D3
.w:	CMP.B	(A0),D3
	BEQ.S	.k
	MOVE.B	D3,(A0)
	ADDQ.B	#1,(A6,D0.W)
.k:	LEA	640(A0),A0
	ADDQ.W	#1,D0
	CMP.W	D1,D0
	BLE.S	.y
	MOVEM.L	(A7)+,D0-D6/A0
	RTS

; stage row of this line into the line buffer (x 640 on); the row as the
; lut buffer is made from it is kept in WM_SOLD
pt_RwdStRow:
	MOVEM.L	D0-D2/A0-A2,-(A7)
	BSR.W	pt_RwdStCols
	LEA	rwd_StCol,A1
	MOVE.W	rtg_NatRow,D0
	SUB.W	#RWD_SCT,D0
	MULU	#640,D0
	MOVE.L	D0,D1
	WMLEA	WM_STG,A2
	ADDA.L	D0,A2
	MOVEA.L	rtg_LineBuf,A0
	LEA	640(A0),A0
	MOVE.W	#640-1,D2
	MOVEQ	#0,D0
.p:	MOVE.B	(A2)+,D0
	MOVE.B	(A1,D0.W),(A0)+
	DBF	D2,.p
	WMLEA	WM_SOLD,A1
	ADDA.L	D1,A1
	LEA	-640(A2),A2
	MOVE.W	#640/4-1,D2
.o:	MOVE.L	(A2)+,(A1)+
	DBF	D2,.o
	MOVEM.L	(A7)+,D0-D2/A0-A2
	RTS

; stage colour codes -> line colours (rwd_StCol); the colours stay while
; the colour pool is not reset
pt_RwdStCols:
	MOVEM.L	D0-D2/A0-A1,-(A7)
	MOVE.W	rtg_PoolGen,D0
	TST.B	rwd_StColOk
	BEQ.S	.go
	CMP.W	rwd_StColGen,D0
	BEQ.S	.r
.go:	MOVE.W	D0,rwd_StColGen		; (a reset in the loop: again next time)
	ST	rwd_StColOk
	LEA	rwd_StCol,A1
	LEA	rwd_StRgb(PC),A0
	MOVEQ	#20-1,D2
.c:	MOVE.W	(A0)+,D1
	BSR.W	pt_RtgSprCol
	MOVE.B	D1,(A1)+
	DBF	D2,.c
.r:	MOVEM.L	(A7)+,D0-D2/A0-A1
	RTS
rwd_StRgb:	DC.W	$000,$005,$00b,$fe0,$8de,$359
	DC.W	$002,$004,$113,$333,$eff,$8de	; track view: wells, leds
	DC.W	$150,$370,$480,$6a0,$8b0,$9c0,$be0,$cf0	; pt's level colours

; stage row of the window when only its stage changed since the row was
; made (planes, bank, sprites as before): the changed 32 px chunks of the
; stage go straight into the lut buffer, as the pixels pt_RwdStRow and the
; scaler would make from them. z=1 done, z=0 the row has to be converted
pt_RwdStFast:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.B	rtg_RunWin
	BEQ.W	.no
	TST.B	rtg_Wide
	BEQ.W	.no
	TST.B	rwd_On
	BEQ.W	.no
	TST.L	rwd_Mem
	BEQ.W	.no
	TST.L	rtg_LutBuf
	BEQ.W	.no
	TST.B	rtg_NoEmit
	BNE.W	.no
	MOVEQ	#0,D7
	MOVE.W	rtg_NatRow,D7
	SUB.W	#RWD_SCT,D7		; stage row
	BMI.W	.no
	CMP.W	#RWD_SCN,D7
	BHS.W	.no
	MOVE.W	D7,D0
	MULU	#640,D0
	WMLEA	WM_STG,A2
	ADDA.L	D0,A2			; stage row now
	WMLEA	WM_SOLD,A3
	ADDA.L	D0,A3			; ... as the buffer was made from it
	MOVEQ	#0,D3			; changed stage chunks
	MOVE.B	(A2),D0
	CMP.B	(A3),D0
	BEQ.S	.p0
	BSET	#31,D3			; pixel 0 is also what shows right of the stage
.p0:	MOVEQ	#0,D1
.cc:	MOVE.W	D1,D0
	LSL.W	#5,D0
	LEA	(A2,D0.W),A0
	LEA	(A3,D0.W),A1
	MOVEQ	#8-1,D2
.cl:	CMPM.L	(A0)+,(A1)+
	DBNE	D2,.cl
	BEQ.S	.cn
	BSET	D1,D3
	LEA	(A2,D0.W),A0
	LEA	(A3,D0.W),A1
	MOVEQ	#8-1,D2
.cp:	MOVE.L	(A0)+,(A1)+
	DBF	D2,.cp
.cn:	ADDQ.W	#1,D1
	CMP.W	#20,D1
	BLO.S	.cc
	TST.L	D3
	BEQ.W	.ok			; the stage is as it was made from
	BSR.W	pt_RwdStCols
	TST.B	rtg_PalDirty		; as pt_RtgWinRow: new colours first
	BEQ.S	.np
	BSR.W	pt_RtgCTab
	ST	rtg_BlitAll
.np:	TST.B	rwd_StDxOk
	BNE.S	.rk
	BSR.W	pt_RwdStDx
.rk:	MOVEQ	#0,D0			; dst rows of the output line
	MOVE.W	rtg_OutRow,D0
	MULU	rtg_WinH,D0
	DIVU	rtg_OutH,D0
	AND.L	#$ffff,D0
	MOVEQ	#0,D6
	MOVE.W	rtg_OutRow,D6
	ADDQ.W	#1,D6
	MULU	rtg_WinH,D6
	DIVU	rtg_OutH,D6
	AND.L	#$ffff,D6
	SUB.L	D0,D6
	BEQ.W	.ok			; shrunk: no dst row
	MOVE.L	D0,-(A7)		; first dst row
	SUBQ.W	#1,D6			; more dst rows
	MOVEQ	#0,D5
	MOVE.W	rtg_WinW,D5
	MULU	D5,D0
	MOVEA.L	rtg_LutBuf,A6
	ADDA.L	D0,A6			; first dst row in the buffer
	WMLEA	WM_XA,A4		; window x -> line x
	LEA	rwd_StCol,A5
	LEA	-640(A2),A2		; stage by line x
	LEA	rwd_StDx,A3
	MOVEQ	#0,D7			; lut chunks to write
	MOVEQ	#0,D2			; stage chunk
.sk:	BTST	D2,D3
	BEQ.S	.skn
	MOVE.W	D2,D0
	LSL.W	#6,D0
	MOVE.W	64(A3,D0.W),D1		; its window x range
	MOVE.W	(A3,D0.W),D0
	BSR.W	.put
.skn:	ADDQ.W	#1,D2
	CMP.W	#20,D2
	BLO.S	.sk
	BTST	#31,D3
	BEQ.S	.nt
	MOVE.W	1280(A3),D0		; right of the stage: pixel 0
	MOVE.W	rtg_WinW,D1
	BSR.W	.put
.nt:	MOVE.L	(A7)+,D4
	TST.L	D7
	BEQ.S	.ok
	MOVEA.L	rtg_DirtyTab,A0		; as pt_RtgWinRow: dirty chunks, span
	MOVE.L	D4,D0
	LSL.L	#2,D0
	ADDA.L	D0,A0
	MOVE.W	D6,D2
.mk:	OR.L	D7,(A0)+
	DBF	D2,.mk
	CMP.W	rtg_DirtyY0,D4
	BGE.S	.y0
	MOVE.W	D4,rtg_DirtyY0
.y0:	MOVE.W	D4,D0
	ADD.W	D6,D0
	CMP.W	rtg_DirtyY1,D0
	BLE.S	.ok
	MOVE.W	D0,rtg_DirtyY1
.ok:
	IFD	DIAGWIN
	ADDQ.L	#1,dw_NFast
	ENDC
	MOVEM.L	(A7)+,D0-D7/A0-A6
	CMP.B	D0,D0			; z=1
	RTS
.no:	MOVEM.L	(A7)+,D0-D7/A0-A6
	ANDI.B	#$fb,CCR		; z=0
	RTS
; window x d0..d1-1 from the stage: its lut chunks into d7, pixels into
; the dst rows where they differ (a2 stage by line x, a4 map, a5 colours,
; a6 first dst row, d5 row bytes, d6 more dst rows)
.put:	CMP.W	D0,D1
	BLS.S	.pe
	MOVE.W	D2,-(A7)
	MOVEQ	#0,D2
	MOVE.W	D0,D2
	DIVU	rtg_ChunkW,D2		; first lut chunk
	MOVEQ	#0,D4
	MOVE.W	D1,D4
	SUBQ.W	#1,D4
	DIVU	rtg_ChunkW,D4		; last one
.pm:	BSET	D2,D7
	ADDQ.W	#1,D2
	CMP.W	D4,D2
	BLS.S	.pm
	MOVEA.L	A4,A0
	MOVE.W	D0,D2
	ADD.W	D2,D2
	ADDA.W	D2,A0			; map at x
	MOVEA.L	A6,A1
	ADDA.W	D0,A1			; first dst row at x
	SUB.W	D0,D1
	SUBQ.W	#1,D1
	MOVEQ	#0,D4
.px:	MOVE.W	(A0)+,D0
	MOVE.B	(A2,D0.W),D4
	MOVE.B	(A5,D4.W),D4
	CMP.B	(A1),D4
	BEQ.S	.pn
	MOVE.B	D4,(A1)
	MOVE.W	D6,D2
	BEQ.S	.pn
	SUBQ.W	#1,D2
	MOVE.L	D5,D0
.xl:	MOVE.B	D4,(A1,D0.L)
	ADD.L	D5,D0
	DBF	D2,.xl
.pn:	ADDQ.L	#1,A1
	DBF	D1,.px
	MOVE.W	(A7)+,D2
.pe:	RTS

; the first window x of every stage pixel in the stage map (rwd_StDx 0-639);
; 640: where the stage ends, right of it the map shows pixel 0 again
pt_RwdStDx:
	MOVEM.L	D0-D4/A0-A1,-(A7)
	WMLEA	WM_XA,A0
	LEA	rwd_StDx,A1
	MOVEQ	#0,D1			; window x
	MOVEQ	#0,D3			; stage pixel to get its x next
.f:	CMP.W	rtg_WinW,D1
	BHS.S	.end			; no stage in this window
	MOVE.W	(A0)+,D0
	CMP.W	#640,D0
	BHS.S	.st
	ADDQ.W	#1,D1
	BRA.S	.f
.st:	MOVE.W	D0,D4			; last map value
.g:	SUB.W	#640,D0			; stage pixel at this x
.h:	CMP.W	D0,D3
	BHI.S	.n
	MOVE.W	D3,D2
	ADD.W	D2,D2
	MOVE.W	D1,(A1,D2.W)
	ADDQ.W	#1,D3
	BRA.S	.h
.n:	ADDQ.W	#1,D1
	CMP.W	rtg_WinW,D1
	BHS.S	.end
	MOVE.W	(A0)+,D0
	CMP.W	D4,D0
	BLO.S	.end			; falls back: right of the stage
	MOVE.W	D0,D4
	BRA.S	.g
.end:	CMP.W	#640,D3			; the rest: where the stage ends
	BHI.S	.done
	MOVE.W	D3,D2
	ADD.W	D2,D2
	MOVE.W	D1,(A1,D2.W)
	ADDQ.W	#1,D3
	BRA.S	.end
.done:	ST	rwd_StDxOk
	MOVEM.L	(A7)+,D0-D4/A0-A1
	RTS

; row signature: analyzer changes of a stage row (d6)
pt_RwdSig:
	TST.B	rwd_On
	BEQ.S	.r
	TST.B	rtg_Wide		;41 buffers may be gone already
	BEQ.S	.r
	TST.L	rwd_Mem
	BEQ.S	.r
	MOVEM.L	D0/A0,-(A7)
	MOVE.W	rtg_NatRow,D0
	SUB.W	#RWD_SCT,D0
	BMI.S	.x
	CMP.W	#RWD_SCN,D0
	BHS.S	.x
	WMLEA	WM_SGEN,A0
	ROL.L	#2,D6
	MOVE.B	(A0,D0.W),D0
	EXT.W	D0
	ADD.W	D0,D6
.x:	MOVEM.L	(A7)+,D0/A0
.r:	RTS
