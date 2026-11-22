; rtg track view: modules with more than 8 channels on the wide window.
; the pattern rows come from wide_Pat (all channels), not from pt's own
; drawing: pt's 8 char cells in the narrow track font; the tracks share
; the width right of the pos column (72 px at least), text on the byte
; grid, the extra in the fields; heads show the number
TRK_X0		EQU	RWD_X0		; first track (wide x)
TRK_SLOT	EQU	72		; narrowest track, as the native narrow one
TRK_FIX		EQU	TRK_X0+16	; picture width without tracks
TRK_TXT		EQU	(TRK_X0+6)/8	; text byte of the first track
TRK_NAT		EQU	50		; native 4ch track 1: bevel 50-53 (template)
TRK_BG		EQU	60		; its background
TRK_SEP		EQU	104		; its white divider
TRK_SEP1	EQU	6+3*8-1		; dividers in the last (blank) glyph column:
TRK_SEP2	EQU	6+5*8-1		; after the note, after the sample
TRK_CNOTE	EQU	25		; last x of pt's note, sample, fx columns,
TRK_CSMP	EQU	41		; its click thresholds on all four tracks
TRK_CFX		EQU	65
TRK_NUM		EQU	640		; head numbers: line buffer behind the panel
TRK_NUMW	EQU	16		; two digits
TRK_HDPLAIN	EQU	TRK_NAT+6	; plain head pixel (no text) of track 1
TRK_BAR		EQU	642		; slider pens in the line buffer (bar rows)
TRK_KMIN	EQU	16		; smallest knob
	IFNE	TRK_TXT*8-TRK_X0-6
	FAIL	"track text not byte aligned"
	ENDC

; track mode: wide module on the wide layout. pt_RwdLay each frame;
; a change builds the maps again and redraws everything
pt_TrkLay:
	MOVEM.L	D0-D1/A0,-(A7)
	MOVEQ	#0,D0
	TST.B	rtg_Wide
	BEQ.S	.s
	TST.B	wide_On
	BEQ.S	.s
	BTST	#5,dat_ModeFlags	; 8 track view: main loop turns it to 4 first
	BEQ.S	.s
	MOVEQ	#-1,D0
.s:	CMP.B	trk_On,D0
	BNE.S	.c
	TST.B	D0			; same mode: channels changed?
	BEQ.S	.r
	MOVE.W	wide_Ch,D1
	CMP.W	trk_ChKey,D1
	BNE.S	.c
	MOVE.W	trk_First,D1		; seams follow the groups of four
	AND.B	#3,D1
	CMP.B	trk_SmKey,D1
	BNE.S	.m
	TST.L	rwd_Mem			; cursor map still right?
	BEQ.S	.r
	MOVE.W	trk_First,D0
	SWAP	D0
	MOVE.W	trk_Grp,D0
	CMP.L	trk_FxKey,D0
	BEQ.S	.r
	BSR.W	pt_TrkFx
.r:	MOVEM.L	(A7)+,D0-D1/A0
	RTS
.c:	MOVE.B	D0,trk_On
	MOVE.W	wide_Ch,trk_ChKey
	CLR.W	trk_First
	SF	trk_Drag
	LEA	trk_Pen,A0		; slider pens until the bar rows are read
	MOVE.W	#$fff,D1
	BSR.W	pt_RtgSprCol
	MOVE.B	D1,(A0)+
	MOVE.W	#$999,D1
	BSR.W	pt_RtgSprCol
	MOVE.B	D1,(A0)+
	MOVEQ	#0,D1
	BSR.W	pt_RtgSprCol
	MOVE.B	D1,(A0)
	BSR.W	pt_TrkVis
	TST.L	rwd_Mem
	BEQ.S	.r
	BSR.S	.rb
	BSR.W	pt_TrkStgInit		; stage: all channels or the scopes
	BRA.S	.r
.m:	TST.L	rwd_Mem
	BEQ.S	.r
	BSR.S	.rb
	BRA.S	.r
.rb:	MOVE.W	trk_First,D1
	AND.B	#3,D1
	MOVE.B	D1,trk_SmKey
	BSR.W	pt_RwdTabs		; track or wide maps
	BSR.W	pt_RwdMaps
	ST	rpr_TplNew
	BSR.W	pt_RtgInvalidate
	MOVE.B	#10,trk_HeadHot
	RTS

; tracks on screen from the window width and the channels; they share
; the width: pitch on the byte grid, the rest a byte more for the first
; ones, the extra of a track into its note, sample and effect field
pt_TrkVis:
	MOVEM.L	D0-D2,-(A7)
	MOVEQ	#0,D1
	MOVE.W	rwd_W,D1
	SUB.W	#TRK_FIX,D1		; room for the tracks
	CMP.W	#TRK_SLOT,D1
	BGE.S	.p
	MOVEQ	#TRK_SLOT,D1
.p:	MOVE.L	D1,D2
	DIVU	#TRK_SLOT,D1		; tracks of the narrowest width
	AND.L	#$ffff,D1
	TST.B	wide_On			; never an empty place
	BEQ.S	.s
	MOVE.W	wide_Ch,D0
	BEQ.S	.s
	CMP.W	D0,D1
	BLS.S	.s
	MOVE.W	D0,D1
.s:	MOVE.W	D1,trk_Vis
	MOVE.L	D2,D0
	DIVU	D1,D0			; room per track
	AND.L	#$fff8,D0		; byte grid
	MOVE.W	D0,trk_Slot
	MULU	D1,D0
	SUB.W	D0,D2			; rest
	LSR.W	#3,D2
	MOVE.W	D2,trk_WideN		; that many a byte wider
	LSL.W	#3,D2
	ADD.W	D0,D2
	ADD.W	#TRK_X0,D2
	MOVE.W	D2,trk_XE
	MOVEQ	#0,D0			; field pads, as the 8 track view
	MOVE.W	trk_Slot,D0
	SUB.W	#TRK_SLOT,D0		; extra of a track
	MOVE.L	D0,D1
	DIVU	#3,D1
	AND.W	#$fff8,D1
	MOVE.W	D1,trk_PadA
	MOVE.W	D1,trk_PadB
	SUB.W	D1,D0
	SUB.W	D1,D0			; effect field: the rest
	LSR.W	#1,D1
	AND.W	#$fff8,D1
	MOVE.W	D1,trk_TxA
	MOVE.W	D1,trk_TxB
	LSR.W	#1,D0
	AND.W	#$fff8,D0
	MOVE.W	D0,trk_TxC
	MOVE.B	#10,trk_HeadHot		; head count may change
	MOVE.W	trk_First,D0		;41 wider: no empty places
	BSR.S	pt_TrkGrpIn		; edited group stays on screen
	BSR.W	pt_TrkSetFirst
	MOVEM.L	(A7)+,D0-D2
	RTS

; d0.w = first track wanted -> moved so pt's edited group is on screen
; (its start when fewer tracks fit than the group has)
pt_TrkGrpIn:
	MOVEM.L	D1-D2,-(A7)
	MOVE.W	trk_Grp,D1
	LSL.W	#2,D1			; group start
	CMP.W	D1,D0
	BLS.S	.e
	MOVE.W	D1,D0			; view right of it
	BRA.S	.x
.e:	MOVE.W	D1,D2
	ADDQ.W	#4,D2
	CMP.W	wide_Ch,D2		; last group may be short
	BLS.S	.c
	MOVE.W	wide_Ch,D2
.c:	SUB.W	trk_Vis,D2		; first that shows its end
	ADDQ.W	#3,D2			; on a group of four
	AND.W	#$fffc,D2
	CMP.W	D2,D0
	BGE.S	.x
	MOVE.W	D2,D0
	CMP.W	D1,D0
	BLE.S	.x
	MOVE.W	D1,D0
.x:	MOVEM.L	(A7)+,D1-D2
	RTS

; track on screen d0.w -> d0.w = its x, d1.w = its width
pt_TrkSX:
	MOVE.L	D2,-(A7)
	MOVE.W	D0,D2
	MOVE.W	trk_Slot,D1
	MULU	D1,D0
	CMP.W	trk_WideN,D2
	BLO.S	.w
	MOVE.W	trk_WideN,D2
	BRA.S	.s
.w:	ADDQ.W	#8,D1			; one of the wider ones
.s:	LSL.W	#3,D2
	ADD.W	D2,D0
	ADD.W	#TRK_X0,D0
	MOVE.L	(A7)+,D2
	RTS

; wide x d0.w (TRK_X0 .. trk_XE-1) -> d0.l = track on screen, d1.w = x
; in it, d2.w = its width
pt_TrkHitX:
	MOVE.L	D3,-(A7)
	SUB.W	#TRK_X0,D0
	AND.L	#$ffff,D0
	MOVE.W	trk_Slot,D1
	BNE.S	.g
	MOVEQ	#TRK_SLOT,D1		; not built yet
.g:	MOVE.W	D1,D2
	ADDQ.W	#8,D2
	MOVE.W	trk_WideN,D3
	MULU	D2,D3			; the wider ones
	CMP.L	D3,D0
	BLO.S	.w
	SUB.L	D3,D0
	DIVU	D1,D0
	MOVE.W	D1,D2
	ADD.W	trk_WideN,D0
	BRA.S	.x
.w:	DIVU	D2,D0
.x:	MOVE.L	D0,D1
	SWAP	D1
	AND.L	#$ffff,D0
	MOVE.L	(A7)+,D3
	RTS

; x d1.w in the 72 px base track -> x in the track on screen: each
; field moved by the pads before it, text centred (the divider column
; goes with the cell after it)
pt_TrkUShift:
	CMP.W	#TRK_SEP1,D1
	BLT.S	.a
	CMP.W	#TRK_SEP2,D1
	BLT.S	.b
	ADD.W	trk_PadB,D1
	SUB.W	trk_TxB,D1
	ADD.W	trk_TxC,D1
.b:	ADD.W	trk_PadA,D1
	SUB.W	trk_TxA,D1
	ADD.W	trk_TxB,D1
.a:	ADD.W	trk_TxA,D1
	RTS

; x d1.w in the track on screen (pattern line) -> x in the base track
; inside pt's columns of that field (pads stay in their field)
pt_TrkTShift:
	CMP.W	#4,D1
	BLO.S	.r			; bevel
	MOVE.L	D2,-(A7)
	MOVE.W	D1,D2
	SUB.W	trk_PadA,D2
	CMP.W	#TRK_SEP1,D2
	BGE.S	.s
	SUB.W	trk_TxA,D1		; note
	MOVEQ	#6,D2
	CMP.W	D2,D1
	BGE.S	.n0
	MOVE.W	D2,D1
.n0:	MOVEQ	#TRK_CNOTE,D2
	BRA.S	.hi
.s:	SUB.W	trk_PadB,D2
	CMP.W	#TRK_SEP2,D2
	BGE.S	.e
	SUB.W	trk_PadA,D1		; sample
	SUB.W	trk_TxB,D1
	MOVEQ	#TRK_CNOTE+2,D2
	CMP.W	D2,D1
	BGE.S	.s0
	MOVE.W	D2,D1
.s0:	MOVEQ	#TRK_CSMP,D2
	BRA.S	.hi
.e:	SUB.W	trk_PadA,D1		; effect
	SUB.W	trk_PadB,D1
	SUB.W	trk_TxC,D1
	MOVEQ	#TRK_CSMP+2,D2
	CMP.W	D2,D1
	BGE.S	.e0
	MOVE.W	D2,D1
.e0:	MOVEQ	#TRK_CFX,D2
.hi:	CMP.W	D2,D1
	BLE.S	.x
	MOVE.W	D2,D1
.x:	MOVE.L	(A7)+,D2
.r:	RTS

; from pt_RwdSnap (window aspect snap) in the track view: width on the
; byte grid, 1280 up to the screen (tracks share it), factor 1; d6 inner
; w, d4 border w, a1 screen -> d0 = 1, d2 = width, rtg_WideWant;
; narrower than 1280 less half a track: classic
pt_TrkSnap:
	CMP.W	#RWD_W-TRK_SLOT/2,D6
	BLO.S	.r
	MOVEM.L	D0-D1/D5/A0,-(A7)
	MOVEA.L	rtg_CgxBase,A0
	CMPI.W	#41,20(A0)		; renderer: lut writes
	BLO.S	.cg
	MOVEQ	#0,D5
	MOVE.W	D6,D5
	ADDQ.W	#4,D5			; nearest byte
	AND.W	#$fff8,D5
	CMP.W	#RWD_W,D5
	BHS.S	.m
	MOVE.W	#RWD_W,D5
.m:	CMP.W	#RWD_WMAX,D5
	BLS.S	.f
	MOVE.W	#RWD_WMAX,D5
.f:	MOVE.L	D5,D0
	ADD.L	D4,D0
	CMP.W	12(A1),D0		; Screen->Width
	BLS.S	.ok
	SUBQ.W	#8,D5
	CMP.W	#RWD_W,D5
	BHS.S	.f
	BRA.S	.nw			; screen too narrow even for 1280
.ok:	MOVE.L	D5,D2
	MOVEM.L	(A7)+,D0-D1/D5/A0
	MOVEQ	#1,D0
	ST	rtg_WideWant
	RTS
.cg:	LEA	rwd_MsgCgx(PC),A0	; the window stays as it is: say why, once
	BRA.S	.ms			; per wide module
.nw:	LEA	rwd_MsgNarrow(PC),A0
.ms:	TST.B	trk_NarrowMsg
	BNE.S	.x
	ST	trk_NarrowMsg
	JSR	pt_StatusLater41
.x:	MOVEM.L	(A7)+,D0-D1/D5/A0
.r:	RTS

; from pt_RtgWinSnap, a1 = screen, d4 = border w, d6 = inner w: once
; per wide module (its channel count) the screen width is the wish; the
; tracks then share what fits; later the user's size
pt_TrkGrow:
	TST.B	wide_On
	BNE.S	.w
	CLR.W	trk_GrownCh
	RTS
.w:	MOVE.L	D0,-(A7)
	MOVE.W	wide_Ch,D0
	CMP.W	trk_GrownCh,D0
	BEQ.S	.k
	MOVE.W	D0,trk_GrownCh
	SF	trk_NarrowMsg		; a new wide module may say why it stays narrow
	MOVE.W	12(A1),D6		; Screen->Width
	SUB.W	D4,D6
.k:	MOVE.L	(A7)+,D0
	RTS

; end of pt_RwdTabs: track mode -> pattern and head maps for the tracks,
; dark up to the scroll bar (no pos column there)
pt_TrkTabs:
	TST.B	trk_On
	BEQ.W	.r
	MOVEM.L	D0-D7/A0-A1,-(A7)
	WMLEA	WM_TMAP,A0
	WMLEA	WM_HMAP,A1
	LEA	2*TRK_X0(A0),A0
	LEA	2*TRK_X0(A1),A1
	MOVEQ	#0,D3			; track on screen
.k:	CMP.W	trk_Vis,D3
	BHS.W	.g
	MOVE.W	D3,D0
	BSR.W	pt_TrkSX
	MOVE.W	D1,D5			; width
	MOVE.W	D3,D6			; seam after each group of four
	ADD.W	trk_First,D6
	NOT.W	D6
	AND.W	#3,D6
	BEQ.S	.se
	MOVE.W	#$7fff,D6
	BRA.S	.sd
.se:	MOVE.W	D5,D6
	SUBQ.W	#2,D6
.sd:	MOVE.W	D3,D0			; number pixels of this track
	LSL.W	#4,D0
	ADD.W	#TRK_NUM,D0
	MOVE.W	D5,D7			; number centred
	SUB.W	#TRK_NUMW,D7
	LSR.W	#1,D7
	MOVEQ	#0,D4			; x in the track
.t:	CMP.W	#4,D4
	BHS.S	.f
	MOVE.W	D4,D1			; bevel, pattern and head
	ADD.W	#TRK_NAT,D1
	MOVE.W	D1,D2
	BRA.S	.sm
.f:	MOVE.W	D4,D1			; dividers after note and sample field
	SUB.W	trk_PadA,D1
	CMP.W	#TRK_SEP1,D1
	BEQ.S	.sp
	SUB.W	trk_PadB,D1
	CMP.W	#TRK_SEP2,D1
	BEQ.S	.sp
	MOVE.W	#TRK_BG,D1
	BRA.S	.hd
.sp:	MOVE.W	#TRK_SEP,D1
.hd:	MOVE.W	D4,D2			; head: number, else plain
	SUB.W	D7,D2
	BMI.S	.hp
	CMP.W	#TRK_NUMW,D2
	BHS.S	.hp
	ADD.W	D0,D2
	BRA.S	.sm
.hp:	MOVE.W	#TRK_HDPLAIN,D2
.sm:	CMP.W	D6,D4
	BLO.S	.put
	MOVE.W	#TRK_NAT+3,D1		; the bevel's dark pixel
	MOVE.W	D1,D2
.put:	MOVE.W	D1,(A0)+
	MOVE.W	D2,(A1)+
	ADDQ.W	#1,D4
	CMP.W	D5,D4
	BLO.S	.t
	ADDQ.W	#1,D3
	BRA.W	.k
.g:	MOVE.W	rwd_W,D0		; up to the scroll bar: dark
	SUB.W	#16,D0
	SUB.W	trk_XE,D0
	BLE.S	.gx
	SUBQ.W	#1,D0
.gl:	MOVE.W	#TRK_NAT+3,(A0)+
	MOVE.W	#TRK_NAT+3,(A1)+
	DBF	D0,.gl
.gx:	MOVEM.L	(A7)+,D0-D7/A0-A1
	BRA.W	pt_TrkFx
.r:	RTS

; cursor map: pt's 4ch view is the edited group; its sprites (cursor)
; land on that group's tracks on screen, fields moved as the text, off
; screen they are dropped
pt_TrkFx:
	MOVEM.L	D0-D3/A0,-(A7)
	MOVE.W	trk_First,D0
	SWAP	D0
	MOVE.W	trk_Grp,D0
	MOVE.L	D0,trk_FxKey
	WMLEA	WM_FX,A0
	LEA	2*TRK_NAT(A0),A0
	MOVE.W	#TRK_NAT,D0
.l:	MOVEQ	#0,D1
	MOVE.W	D0,D1
	SUB.W	#TRK_NAT,D1
	DIVU	#2*TRK_SLOT,D1		; native 4ch track, hi = x in it
	MOVE.W	trk_Grp,D2
	LSL.W	#2,D2
	ADD.W	D1,D2
	CMP.W	wide_Ch,D2		; tracks past the module: none
	BHS.S	.off
	SUB.W	trk_First,D2		; on screen
	BMI.S	.off
	CMP.W	trk_Vis,D2
	BHS.S	.off
	SWAP	D1
	LSR.W	#1,D1			; half width: 4ch cell -> narrow cell
	SUBQ.W	#1,D1
	BSR.W	pt_TrkUShift		; fields moved by their pads
	MOVE.W	D1,D3
	MOVE.W	D0,-(A7)
	MOVE.W	D2,D0
	BSR.W	pt_TrkSX		; x of that track
	ADD.W	D3,D0
	MOVE.W	D0,D2
	MOVE.W	(A7)+,D0
	BRA.S	.put
.off:	MOVEQ	#-1,D2
.put:	MOVE.W	D2,(A0)+
	ADDQ.W	#1,D0
	CMP.W	#TRK_NAT+8*TRK_SLOT,D0
	BLO.S	.l
	SF	rwd_BarOk		; bar again
	MOVEM.L	(A7)+,D0-D3/A0
	RTS

; pt's view (4 or 8 tracks) holds the channels from group d0 on: the old
; ones go back to wide_Pat, then the new ones in; screen follows
pt_TrkGrpSet:
	CMP.W	trk_Grp,D0
	BEQ.W	.r
	TST.L	wide_Pat
	BEQ.W	.r
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.W	D0,D6
	JSR	pt_WideChgPre41
	JSR	pt_WideGrowView		; patterns added since the load
	BEQ.W	.nm			; no memory: the group stays
	ST	trk_Swap		; replayer: view not written back now
	JSR	pt_WideFlush		; all back first: 8 views overlap
	JSR	pt_WideRows		; d5 = rows - 1, d4 = row bytes
	BMI.S	.sw
	MOVEA.L	dat_ModulePtr,A1
	LEA	mod_patterns(A1),A1
	MOVEA.L	wide_Pat,A3
	MOVE.W	D6,D0
	LSL.W	#4,D0
	ADDA.W	D0,A3			; new group
	MOVE.W	D4,D3
	LSR.W	#2,D3
	SUBQ.W	#1,D3
.row:	MOVEA.L	A3,A2
	MOVE.W	D3,D1
.c:	MOVE.L	(A2)+,(A1)+
	DBF	D1,.c
	LEA	WIDE_ROW(A3),A3
	SUBQ.L	#1,D5
	BPL.S	.row
.sw:	MOVE.W	D6,trk_Grp
	JSR	pt_WideShow41		; 8 view: tracks shown
	SF	trk_Swap
	JSR	pt_WideBtns41		; track buttons: mutes of this view
	MOVE.W	D6,D0			; group on screen
	LSL.W	#2,D0
	CMP.W	trk_First,D0
	BLO.S	.f
	ADDQ.W	#4,D0
	CMP.W	wide_Ch,D0		; last group may be short
	BLS.S	.e
	MOVE.W	wide_Ch,D0
.e:	MOVE.W	trk_First,D1
	ADD.W	trk_Vis,D1
	CMP.W	D1,D0
	BLS.S	.v
	SUB.W	trk_Vis,D0
	ADDQ.W	#3,D0
	AND.W	#$fffc,D0
	MOVE.W	wide_Ch,D1		; no empty place behind the last track
	SUB.W	trk_Vis,D1
	CMP.W	D1,D0
	BLS.S	.f
	MOVE.W	D1,D0
.f:	MOVE.W	D0,trk_First
	MOVE.B	#10,trk_HeadHot
.v:	ADDQ.L	#1,rtg_PatGen
	JSR	pt_TrkClamp41		; cursor on a shown track
	JSR	pt_PatViewDrawAll0
	JSR	pt_WBarChk41		; native slider follows the group
	JSR	pt_WideChgPost41
	BRA.S	.x
.nm:	LEA	wide_MsgGrpMem,A0
	JSR	pt_StatusLater41
.x:	MOVEM.L	(A7)+,D0-D7/A0-A6
.r:	RTS

; tab (pt_03EF) in the track view: past track 4 / before track 1 the
; next / previous group comes into pt's view (wraps)
pt_TrkTab:
	JSR	pt_WideNat41
	BEQ.S	.t
	JMP	pt_WNatTab41		; native screen: own groups
.t:	TST.B	trk_On
	BEQ.S	.r
	MOVE.W	dat_CursorColumn,D0
	TST.W	dat_KeyQual1		; shift
	BNE.S	.bk
	MOVE.W	D0,-(A7)
	BSR.S	pt_TrkLastCol
	CMP.W	(A7)+,D0
	BHI.S	.r
	MOVE.W	trk_Grp,D0
	ADDQ.W	#1,D0
	MOVE.W	D0,D1
	LSL.W	#2,D1
	CMP.W	wide_Ch,D1
	BLO.S	.go
	MOVEQ	#0,D0
.go:	BSR.W	pt_TrkGrpSet
	CLR.W	dat_CursorColumn
	BRA.S	.dn
.bk:	CMP.W	#6,D0
	BHS.S	.r
	MOVE.W	trk_Grp,D0
	SUBQ.W	#1,D0
	BPL.S	.gb
	MOVE.W	wide_Ch,D0
	SUBQ.W	#1,D0
	LSR.W	#2,D0
.gb:	BSR.W	pt_TrkGrpSet
	BSR.S	pt_TrkLastCol
	MOVE.W	D0,dat_CursorColumn
.dn:	ADDQ.L	#4,A7			; tab done
	JMP	pt_ReturnFromPlay
.r:	RTS

; d0 = cursor column of the last track of the edited group
pt_TrkLastCol:
	MOVE.W	trk_Grp,D0
	LSL.W	#2,D0
	NEG.W	D0
	ADD.W	wide_Ch,D0		; tracks of the group
	CMP.W	#4,D0
	BLS.S	.k
	MOVEQ	#4,D0
.k:	SUBQ.W	#1,D0
	MULU	#6,D0
	RTS

; head line (native rows of the heads): numbers of the tracks on screen
; into the line buffer behind the panel, white on the plain head pixel
pt_TrkHead:
	TST.B	trk_On
	BEQ.W	.r
	MOVE.W	rtg_NatRow,D0
	SUB.W	#RWD_HDTOP,D0
	BMI.W	pt_TrkBarRow
	CMP.W	#7,D0
	BHI.W	.r
	MOVEM.L	D0-D7/A0-A4,-(A7)
	MOVE.L	rwd_Font,D1		;41 font not set yet
	ADDQ.L	#1,D1
	BEQ.W	.x
	MOVE.W	D0,D7			; glyph line: pt's head text starts one
	SUBQ.W	#1,D7			; row below the head top
	MOVE.W	#$fff,D1
	BSR.W	pt_RtgSprCol
	MOVE.B	D1,D6			; text
	MOVE.B	D1,trk_PenOn
	MOVE.W	#$777,D1		; channel off: dim number
	BSR.W	pt_RtgSprCol
	MOVE.B	D1,trk_PenOff
	MOVEA.L	rtg_LineBuf,A0
	MOVE.B	TRK_HDPLAIN(A0),D5	; background
	LEA	TRK_NUM(A0),A1
	MOVE.W	trk_Vis,D0		; tracks past the module: plain
	LSL.W	#4,D0
	SUBQ.W	#1,D0
.cl:	MOVE.B	D5,(A1)+
	DBF	D0,.cl
	IFD	TRKDBG			; measuring: bar of NatRow-140 x 4 px
	LEA	TRK_NUM(A0),A1
	MOVE.W	D7,D0
	ADDQ.W	#1,D0
	LSL.W	#2,D0
	BRA.S	.db1
.db:	MOVE.B	D6,(A1)+
.db1:	DBF	D0,.db
	BRA.S	.x
	ENDC
	TST.W	D7			; head top row: background only
	BMI.S	.x
	LEA	TRK_NUM(A0),A1
	MOVEA.L	rwd_Font,A2
	LEA	1024(A2),A2		; narrow glyphs
	MOVE.W	D7,D0
	LSL.W	#7,D0
	ADDA.W	D0,A2			; line d7
	MOVEQ	#0,D4			; track on screen
	MOVE.W	trk_First,D3
.t:	ADDQ.W	#1,D3			; number shown
	MOVE.B	trk_PenOn,D6
	MOVE.W	D3,D0
	SUBQ.W	#1,D0
	MOVE.L	wide_Mute,D1
	BTST	D0,D1
	BEQ.S	.nm
	MOVE.B	trk_PenOff,D6
.nm:	MOVEQ	#0,D0
	MOVE.W	D3,D0
	DIVU	#10,D0			; d0 = tens, hi = ones
	MOVEQ	#0,D1
	TST.W	D0
	BEQ.S	.d1
	MOVE.B	D0,D1
	ADD.B	#'0'-$20,D1
.d1:	BSR.S	.glyph			; tens (blank when 0)
	SWAP	D0
	MOVEQ	#0,D1			; (.glyph left d1 = -1)
	MOVE.B	D0,D1
	ADD.B	#'0'-$20,D1
	BSR.S	.glyph
	CMP.W	wide_Ch,D3
	BHS.S	.x
	ADDQ.W	#1,D4
	CMP.W	trk_Vis,D4
	BLO.S	.t
.x:	MOVEM.L	(A7)+,D0-D7/A0-A4
.r:	RTS
; d1 = char - $20 (0 = blank) -> 8 pixels at a1
.glyph:	MOVE.W	D1,D2			; glyph: char * 2
	ADD.W	D2,D2
	MOVE.B	(A2,D2.W),D2
	MOVEQ	#7,D1
.p:	MOVE.B	D5,(A1)
	BTST	D1,D2
	BEQ.S	.p0
	MOVE.B	D6,(A1)
.p0:	ADDQ.L	#1,A1
	DBF	D1,.p
	RTS

;--- slider in the frame lines above the heads (rows 136-139), under the
; stage that shows all channels. the row's pens at TRK_BAR (groove, light
; edge, face, dark edge, notch dark, notch light), WM_XS points there
pt_TrkBarRow:
	MOVEM.L	D0-D2/A0-A2,-(A7)
	MOVEA.L	rtg_LineBuf,A0
	LEA	trk_Pen,A1		; light, face, dark from the native lines
	ADDQ.W	#4,D0			; 0..3
	MOVE.W	D0,D1
	BNE.S	.p1
	MOVE.B	(A0),1(A1)		; stipple: face, dark
	MOVE.B	1(A0),2(A1)
	BRA.S	.p
.p1:	BTST	#0,D1
	BEQ.S	.p2
	MOVE.B	300(A0),(A1)		; white line
	BRA.S	.p
.p2:	MOVE.B	300(A0),2(A1)		; black line
.p:	MOVE.W	#$f55,D1		; knob: red as the pattern thumb
	BSR.W	pt_RtgSprCol
	MOVE.B	D1,3(A1)
	MULU	#6,D0
	LEA	trk_BarPens(PC,D0.W),A2
	LEA	TRK_BAR(A0),A0
	MOVEQ	#5,D2
.c:	MOVEQ	#0,D1
	MOVE.B	(A2)+,D1
	MOVE.B	(A1,D1.W),(A0)+
	DBF	D2,.c
	MOVEM.L	(A7)+,D0-D2/A0-A2
	RTS
; 0 light 1 grey 2 dark 3 red: groove sunk, knob raised, notches
trk_BarPens:
	DC.B	2,0,0,0,0,0
	DC.B	2,0,3,2,2,0
	DC.B	2,0,3,2,2,0
	DC.B	0,2,2,2,2,2

; z=1 left button down (test driver: its button)
pt_TrkLmb:
	IFD	DEBUGAUTO
	JMP	dbg_LMB
	ELSE
	BTST	#6,CIAA_PRA
	RTS
	ENDC

; d0.w = first track wanted -> 0..wide_Ch-trk_Vis, rows and heads again
pt_TrkSetFirst:
	MOVE.L	D1,-(A7)
	TST.W	D0
	BPL.S	.p
	MOVEQ	#0,D0
.p:	MOVE.W	wide_Ch,D1
	SUB.W	trk_Vis,D1
	BPL.S	.m
	MOVEQ	#0,D1
.m:	CMP.W	D1,D0
	BLE.S	.s
	MOVE.W	D1,D0
.s:	CMP.W	trk_First,D0
	BEQ.S	.x
	MOVE.W	D0,trk_First
	ADDQ.L	#1,rtg_PatGen		; rows again
	MOVE.B	#10,trk_HeadHot		; heads again (the native lines stay)
.x:	MOVE.L	(A7)+,D1
	RTS

; knob from first and vis, slider pens over the tracks in WM_XS (all
; tracks on screen: the frame lines as they are)
pt_TrkBarMap:
	TST.B	trk_On
	BEQ.W	.r
	TST.L	rwd_Mem
	BEQ.W	.r
	MOVEM.L	D0-D7/A0,-(A7)
	MOVE.W	trk_First,D0
	SWAP	D0
	MOVE.W	trk_Vis,D0
	MOVE.L	D0,trk_BarKey
	MOVE.W	wide_Ch,D7
	MOVE.W	trk_Vis,D6
	CMP.W	D6,D7
	BLS.W	.x
	MOVE.W	trk_XE,D5
	SUB.W	#TRK_X0,D5		; slider width
	MOVE.W	D6,D4
	MULU	D5,D4
	DIVU	D7,D4			; knob
	CMP.W	#TRK_KMIN,D4
	BHS.S	.k
	MOVEQ	#TRK_KMIN,D4
.k:	MOVE.W	D5,D3
	SUB.W	D4,D3			; travel
	SUB.W	D6,D7			; last first track
	MOVE.W	trk_First,D1
	CMP.W	D7,D1			;41 safe quotient
	BLS.S	.fk
	MOVE.W	D7,D1
.fk:	MULU	D3,D1
	DIVU	D7,D1
	ADD.W	#TRK_X0,D1
	MOVE.W	D1,trk_K0
	ADD.W	D4,D1
	MOVE.W	D1,trk_K1
	MOVE.W	trk_K0,D6		; notches round the middle
	ADD.W	trk_K1,D6
	LSR.W	#1,D6
	MOVEQ	#0,D2
	MOVE.W	rtg_WinW,D2
	DIVU	rwd_W,D2		; x factor
	WMLEA	WM_XS,A0
	MOVEQ	#0,D0			; window x
.l:	MOVEQ	#0,D1
	MOVE.W	D0,D1
	DIVU	D2,D1			; wide x
	CMP.W	#TRK_X0,D1
	BLO.S	.n
	CMP.W	trk_XE,D1
	BHS.S	.n
	MOVEQ	#0,D3			; groove
	CMP.W	trk_K0,D1
	BLO.S	.p
	CMP.W	trk_K1,D1
	BHS.S	.p
	MOVEQ	#1,D3			; light edge
	CMP.W	trk_K0,D1
	BEQ.S	.p
	MOVEQ	#3,D3			; dark edge
	MOVE.W	trk_K1,D7
	SUBQ.W	#1,D7
	CMP.W	D7,D1
	BEQ.S	.p
	MOVEQ	#2,D3			; face
	CMP.W	#24,D4
	BLO.S	.p
	MOVE.W	D1,D7
	SUB.W	D6,D7
	ADDQ.W	#5,D7
	BMI.S	.p
	CMP.W	#10,D7
	BHI.S	.p
	MOVE.B	.notch(PC,D7.W),D3
.p:	ADD.W	#TRK_BAR,D3
	MOVE.W	D3,(A0)
.n:	ADDQ.L	#2,A0
	ADDQ.W	#1,D0
	CMP.W	rtg_WinW,D0
	BLO.S	.l
.x:	MOVEM.L	(A7)+,D0-D7/A0
.r:	RTS
.notch:	DC.B	2,4,5,2,2,4,5,2,2,4,5
	EVEN

; every frame: slider follows the first track (wheel, tab, drag); button
; up ends a drag
pt_TrkBarChk:
	TST.B	trk_On
	BEQ.S	.r
	TST.L	rwd_Mem
	BEQ.S	.r
	MOVE.L	D0,-(A7)
	BSR.W	pt_TrkLmb
	BEQ.S	.d
	SF	trk_Drag
.d:	MOVE.W	trk_First,D0
	SWAP	D0
	MOVE.W	trk_Vis,D0
	CMP.L	trk_BarKey,D0
	BEQ.S	.x
	BSR.W	pt_TrkBarMap
	MOVE.B	#10,trk_HeadHot
.x:	MOVE.L	(A7)+,D0
.r:	RTS

; input handler, track view: lmb on the knob drags it, beside it a page
; left/right; d2 = wide x, d3 = pt line -> z=0 the pointer is ours
pt_TrkBarMouse:
	MOVEM.L	D0-D1,-(A7)
	BSR.W	pt_TrkLmb
	SEQ	D0			; button down
	MOVE.B	trk_LmbOld,D1
	MOVE.B	D0,trk_LmbOld
	TST.B	D0
	BEQ.W	.up
	TST.B	trk_Drag
	BNE.W	.held
	TST.B	D1			; held from elsewhere: only no buttons
	BNE.W	.on
	BSR.W	.bar
	BNE.W	.no
	MOVE.W	wide_Ch,D0
	CMP.W	trk_Vis,D0
	BLS.W	.yes
	CMP.W	trk_K0,D2
	BLO.S	.pl
	CMP.W	trk_K1,D2
	BHS.S	.pr
	MOVE.W	D2,D0
	SUB.W	trk_K0,D0
	MOVE.W	D0,trk_Grab
	MOVE.B	#1,trk_Drag
	BRA.W	.yes
.pl:	MOVE.W	trk_First,D0
	SUB.W	trk_Vis,D0
	BRA.S	.pg
.pr:	MOVE.W	trk_First,D0
	ADD.W	trk_Vis,D0
.pg:	BSR.W	pt_TrkSetFirst
	MOVE.B	#2,trk_Drag		; page: wait for the release
	BRA.W	.yes
.held:	CMP.B	#1,trk_Drag
	BNE.W	.yes
	MOVEM.L	D2-D4,-(A7)
	MOVE.W	trk_K1,D3
	SUB.W	trk_K0,D3
	MOVE.W	trk_XE,D4
	SUB.W	#TRK_X0,D4
	SUB.W	D3,D4			; travel
	BEQ.S	.dz
	SUB.W	trk_Grab,D2
	SUB.W	#TRK_X0,D2		; knob start in the travel
	BPL.S	.d0
	MOVEQ	#0,D2
.d0:	CMP.W	D4,D2
	BLS.S	.d1
	MOVE.W	D4,D2
.d1:	MOVE.W	wide_Ch,D0
	SUB.W	trk_Vis,D0
	MULU	D0,D2
	MOVE.W	D4,D0
	LSR.W	#1,D0
	ADD.L	D0,D2			; rounded
	DIVU	D4,D2
	MOVE.W	D2,D0
	BRA.S	.ds
.dz:	MOVEQ	#0,D0
.ds:	MOVEM.L	(A7)+,D2-D4
	BSR.W	pt_TrkSetFirst
	BRA.W	.yes
.up:	SF	trk_Drag
.on:	BSR.W	.bar
	BNE.W	.no
.yes:	MOVEQ	#-1,D0
	MOVEM.L	(A7)+,D0-D1		; flags stay
	RTS
.no:	MOVEQ	#0,D0
	MOVEM.L	(A7)+,D0-D1
	RTS
; z=1 pointer on the bar rows over the tracks
.bar:	CMP.W	#RWD_STTOP,D3
	BLT.S	.bn
	CMP.W	#RWD_HDTOP,D3
	BGE.S	.bn
	CMP.W	#TRK_X0,D2
	BLO.S	.bn
	CMP.W	trk_XE,D2
	BHS.S	.bn
	ORI	#4,CCR
	RTS
.bn:	ANDI	#$fb,CCR
	RTS

; pattern row d5 into WM_TXT row a1 (pos column there already): the
; tracks on screen from wide_Pat, pt's cell text, narrow track font
pt_TrkRow:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVEA.L	A1,A5			; a5 = text row (RWD_TS bytes a line)
	TST.L	wide_Pat		; freed (quit, other module): nothing
	BEQ.W	.x
	MOVE.L	dat_PatTableIdx,D0
	MULU	#WIDE_PAT/64,D0
	LSL.L	#6,D0			; pattern * 8 kb
	MOVE.W	D5,D1
	MULU	#WIDE_ROW,D1
	ADD.L	D1,D0
	MOVEA.L	wide_Pat,A6
	CMP.L	wide_PatSize,D0
	BLO.S	.in
	LEA	trk_NoRow,A6		;41 added in pt: others empty, group from the view
	MOVEQ	#0,D0
.in:	ADDA.L	D0,A6
	MOVE.W	trk_First,D3		;41 sampled once
	MOVE.W	D3,D0
	LSL.W	#2,D0
	ADDA.W	D0,A6			; a6 = first cell on screen
	MOVE.L	rwd_Font,D1		;41 font not set yet
	ADDQ.L	#1,D1
	BEQ.W	.x
	MOVEA.L	rwd_Font,A4
	LEA	1024(A4),A4		; narrow glyphs
	LEA	TRK_TXT(A5),A5
	MOVEQ	#0,D4			; d4 = view row (edited group), 0 = none
	MOVE.L	dat_PatTableIdx,D0
	CMP.L	#WIDE_MAXVIEW,D0
	BHS.S	.nv
	TST.B	trk_Swap
	BNE.S	.nv
	MOVEQ	#10,D1
	LSL.L	D1,D0			; pattern * 1024
	MOVE.W	D5,D1
	AND.L	#63,D1
	LSL.W	#4,D1
	ADD.L	D1,D0
	ADD.L	#mod_patterns,D0
	ADD.L	dat_ModulePtr,D0
	MOVE.L	D0,D4
.nv:	MOVE.W	trk_Grp,D2		;41 d3 = channel
	MOVE.W	wide_Ch,D7
	SUB.W	D3,D7
	CMP.W	trk_Vis,D7
	BLS.S	.n
	MOVE.W	trk_Vis,D7
.n:	SUBQ.W	#1,D7
	BMI.W	.x
	SWAP	D7
	MOVE.W	trk_WideN,D7		; the first ones a byte wider
	SWAP	D7
.tr:	MOVE.L	A6,-(A7)
	TST.L	D4
	BEQ.S	.w
	MOVE.W	D3,D0
	LSR.W	#2,D0
	CMP.W	D2,D0
	BNE.S	.w
	MOVE.W	D3,D0			; edited group: cell from the view
	AND.W	#3,D0
	LSL.W	#2,D0
	MOVEA.L	D4,A6
	ADDA.W	D0,A6
.w:	LEA	trk_Cell,A3
	BSR.W	pt_TrkCell		; 8 chars
	MOVEA.L	(A7)+,A6
	MOVEQ	#7,D6
	MOVEA.L	A5,A1
	MOVE.W	trk_TxA,D0		; text centred in its field
	LSR.W	#3,D0
	ADDA.W	D0,A1
.ch:	CMP.W	#4,D6			; sample field
	BNE.S	.c1
	MOVE.W	trk_PadA,D0
	SUB.W	trk_TxA,D0
	ADD.W	trk_TxB,D0
	BRA.S	.c2
.c1:	CMP.W	#2,D6			; effect field
	BNE.S	.c3
	MOVE.W	trk_PadB,D0
	SUB.W	trk_TxB,D0
	ADD.W	trk_TxC,D0
.c2:	LSR.W	#3,D0
	ADDA.W	D0,A1
.c3:	MOVEQ	#0,D0
	MOVE.B	(A3)+,D0
	SUB.B	#$20,D0
	CMP.B	#63,D0
	BLS.S	.c
	MOVEQ	#0,D0
.c:	ADD.W	D0,D0			; glyph: char * 2, a line 128
	LEA	(A4,D0.W),A0
	MOVEA.L	A1,A2
	MOVEQ	#7,D1
.gl:	MOVE.B	(A0),(A2)
	LEA	128(A0),A0
	LEA	RWD_TS(A2),A2
	DBF	D1,.gl
	ADDQ.L	#1,A1
	DBF	D6,.ch
	ADDQ.L	#4,A6
	ADDQ.W	#1,D3
	MOVE.W	trk_Slot,D0		; next track: this one's bytes
	LSR.W	#3,D0
	SWAP	D7
	TST.W	D7
	BEQ.S	.nw
	SUBQ.W	#1,D7
	ADDQ.W	#1,D0
.nw:	SWAP	D7
	ADDA.W	D0,A5
	DBF	D7,.tr
.x:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; cell a6 -> 8 chars at a3, as pt_FormatNoteCell (note, sample, fx;
; zeros blanked like pt's setting)
pt_TrkCell:
	MOVEM.L	D0-D5/A0-A4,-(A7)
	MOVEQ	#0,D1
	MOVE.W	(A6),D1
	AND.W	#$0fff,D1
	BNE.S	.srch
	MOVE.L	#$202d2020,(A3)		; " -  "
	BRA.S	.sfx
.srch:	LEA	dat_PeriodTable,A2
	MOVEQ	#0,D0
	MOVEQ	#36,D2
.f:	CMP.W	(A2,D0.W),D1
	BEQ.S	.name
	ADDQ.L	#2,D0
	DBF	D2,.f
	JSR	pt_NoteNear41		; nearest note instead of ???
	BRA.S	.sfx
.name:	LSL.L	#1,D0
	ADD.L	dat_NoteNamesPtr,D0
	MOVEA.L	D0,A0
	MOVE.L	(A0),(A3)
.sfx:	LEA	dat_HexPairTable,A4
	MOVEQ	#0,D0
	MOVE.B	(A6),D0
	ADD.W	D0,D0
	MOVE.B	(A4,D0.W),3(A3)		; sample high
	MOVEQ	#0,D0
	MOVE.B	2(A6),D0
	ADD.W	D0,D0
	MOVE.B	(A4,D0.W),4(A3)		; sample low
	MOVE.B	1(A4,D0.W),5(A3)	; fx
	MOVEQ	#0,D0
	MOVE.B	3(A6),D0
	ADD.W	D0,D0
	MOVE.B	(A4,D0.W),6(A3)
	MOVE.B	1(A4,D0.W),7(A3)
	BTST	#3,dat_InputReadyFlag	; zeros blanked
	BEQ.S	.r
	MOVEQ	#'0',D4
	CMP.B	3(A3),D4
	BNE.S	.bf
	MOVE.B	#' ',3(A3)
	CMP.B	4(A3),D4
	BNE.S	.bf
	MOVE.B	#'-',4(A3)
.bf:	MOVE.B	5(A3),D1
	OR.B	6(A3),D1
	OR.B	7(A3),D1
	CMP.B	D4,D1
	BNE.S	.r
	MOVE.B	#' ',5(A3)
	MOVE.B	#'.',6(A3)
	MOVE.B	#' ',7(A3)
.r:	MOVEM.L	(A7)+,D0-D5/A0-A4
	RTS

; raw key d1 (pt_EditWheelKey): shift + wheel in the track view moves
; the tracks on screen by a group of four; the key is used up (d1 = a
; release of key 0)
pt_TrkScrollKey:
	JSR	pt_WideNat41
	BNE.S	.nat
	TST.B	trk_On
	BEQ.S	.r
	TST.W	dat_KeyQual1		; shift
	BEQ.S	.r
	MOVE.B	D1,D0
	AND.B	#$7f,D0
	CMP.B	#$7a,D0			; wheel up
	BEQ.S	.k
	CMP.B	#$7b,D0			; wheel down
	BNE.S	.r
.k:	TST.B	D1			; release: only used up
	BMI.S	.x
	MOVEM.L	D2,-(A7)
	MOVE.W	wide_Ch,D2		; last first track: ends at the last
	SUB.W	trk_Vis,D2
	BPL.S	.m
	MOVEQ	#0,D2
.m:	MOVE.W	trk_First,D0
	CMP.B	#$7a,D1
	BEQ.S	.lt
	AND.W	#$fffc,D0
	ADDQ.W	#4,D0
	CMP.W	D2,D0
	BLS.S	.set
	MOVE.W	D2,D0
	BRA.S	.set
.lt:	SUBQ.W	#1,D0
	BMI.S	.z
	AND.W	#$fffc,D0
	BRA.S	.set
.z:	MOVEQ	#0,D0
.set:	MOVEM.L	(A7)+,D2
	BSR.W	pt_TrkSetFirst
.x:	MOVE.B	#$80,D1
.r:	RTS
; native: wish kept, main loop pages (dialogs read keys too)
.nat:	TST.W	dat_KeyQual1		; shift
	BEQ.S	.r
	MOVE.B	D1,D0
	AND.B	#$7f,D0
	CMP.B	#$7a,D0			; wheel up: back
	BEQ.S	.nk
	CMP.B	#$7b,D0			; wheel down: on
	BNE.S	.r
.nk:	TST.B	D1			; release: only used up
	BMI.S	.x
	MOVE.B	#1,wnat_Req
	CMP.B	#$7a,D1
	BNE.S	.x
	MOVE.B	#-1,wnat_Req
	BRA.S	.x

;--- stage in the track view: one well per channel, a chain of led
; segments in pt's level colours, a peak that holds and falls, a bar
; under the tracks on screen; muted channels grey (trk_Lev: card
; start -> card vol, then decay per tick)
TRK_SX0		EQU	4		; first box (stage x)
TRK_SW		EQU	640-2*TRK_SX0	; boxes in here
TRK_SEG		EQU	27		; segments a chain
TRK_SBOT	EQU	RWD_BY+RWD_BH-3	; bottom row of the lowest segment
TRK_GBAR	EQU	TRK_SBOT+1	; two rows: tracks on screen
TRK_HOLD	EQU	25		; frames the peak holds
; stage codes (rwd_StRgb)
TC_WELL		EQU	6
TC_WELLV	EQU	7
TC_OFF		EQU	8
TC_MUTE		EQU	9
TC_PEAK		EQU	10
TC_GBAR		EQU	11
TC_LIT		EQU	12		; 8 codes, dark to light

; wells for wide_Ch channels (track view on), else the 8 scopes again
pt_TrkStgInit:
	MOVEM.L	D0-D7/A0-A3,-(A7)
	WMLEA	WM_STG,A0		; stage clear
	MOVE.W	#640*RWD_SCN/4-1,D0
.cl:	CLR.L	(A0)+
	DBF	D0,.cl
	WMLEA	WM_SPRV,A0		; levels drawn: none
	MOVE.W	#640/4-1,D0
.cs:	CLR.L	(A0)+
	DBF	D0,.cs
	TST.B	trk_On
	BEQ.S	.c
	TST.W	wide_Ch
	BNE.S	.t
.c:	MOVEM.L	(A7)+,D0-D7/A0-A3
	BRA.W	pt_RwdStgInit
.t:	MOVE.W	#TRK_SW,D0
	DIVU	wide_Ch,D0
	MOVE.W	D0,trk_SPitch
	LEA	trk_Pk,A0		; no peaks
	MOVEQ	#32-1,D0
.pk:	CLR.W	(A0)+
	DBF	D0,.pk
	BSR.S	pt_TrkWells
	MOVEM.L	(A7)+,D0-D7/A0-A3
	RTS

; wells and group bar of every channel, segments drawn again next frame
pt_TrkWells:
	MOVEM.L	D0-D7/A0-A1,-(A7)
	MOVE.L	rwd_Mem,trk_StgMem
	MOVE.W	rwd_W,trk_StgW
	MOVE.W	trk_First,trk_StgFirst
	MOVE.W	trk_Vis,trk_StgVis
	MOVE.L	wide_Mute,trk_StgMute
	LEA	trk_SegC,A0		; segments: unknown
	MOVE.W	#32*TRK_SEG-1,D0
.u:	ST	(A0)+
	DBF	D0,.u
	MOVEQ	#0,D7			; channel
.b:	BSR.W	pt_TrkBox		; d0 = x, d1 = width
	MOVEQ	#TC_WELL,D4
	MOVEQ	#TC_WELL,D5
	MOVE.W	D7,D2
	SUB.W	trk_First,D2
	BMI.S	.w
	CMP.W	trk_Vis,D2
	BHS.S	.w
	MOVEQ	#TC_WELLV,D4		; on screen: lighter, bar below
	MOVEQ	#TC_GBAR,D5
.w:	WMLEA	WM_STG,A0
	ADDA.W	D0,A0
	LEA	RWD_BY*640(A0),A0
	MOVEQ	#RWD_BY,D2		; stage row
.y:	MOVE.B	D4,D6
	CMP.W	#TRK_GBAR,D2
	BLO.S	.c
	MOVE.B	D5,D6
.c:	MOVE.W	D1,D3
	SUBQ.W	#1,D3
.x:	MOVE.B	D6,(A0,D3.W)
	DBF	D3,.x
	LEA	640(A0),A0
	ADDQ.W	#1,D2
	CMP.W	#RWD_BY+RWD_BH,D2
	BLO.S	.y
	ADDQ.W	#1,D7
	CMP.W	wide_Ch,D7
	BLO.S	.b
	WMLEA	WM_SGEN,A0		; all rows changed
	MOVEQ	#RWD_SCN-1,D0
.g:	ADDQ.B	#1,(A0)+
	DBF	D0,.g
	MOVEM.L	(A7)+,D0-D7/A0-A1
	RTS

; channel d7 -> d0 = box x, d1 = box width
pt_TrkBox:
	MOVE.W	trk_SPitch,D1
	MOVE.W	D7,D0
	MULU	D1,D0
	ADD.W	#TRK_SX0,D0
	SUBQ.W	#2,D1
	RTS

; every frame instead of the 8 scopes: levels of all channels, changed
; segments drawn, their rows counted in WM_SGEN (pt_RwdScope marks them
; hot)
pt_TrkStage:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.B	trk_HeadHot		; head numbers changed: those native
	BEQ.S	.hh			; lines read again for some frames
	SUBQ.B	#1,trk_HeadHot
	X20LEA	X20_RTGHEAT,A0
	LEA	RWD_STTOP(A0),A0	; scroll bar and heads
	MOVEQ	#RWD_HDEND-RWD_STTOP,D0
.hl:	MOVE.B	#1,(A0)+
	DBF	D0,.hl
.hh:	MOVE.W	trk_First,D0		; group or mutes changed: wells
	CMP.W	trk_StgFirst,D0
	BNE.S	.wl
	MOVE.W	trk_Vis,D0
	CMP.W	trk_StgVis,D0
	BNE.S	.wl
	MOVE.L	wide_Mute,D0
	CMP.L	trk_StgMute,D0
	BEQ.S	.go
.wl:	BSR.W	pt_TrkWells
.go:	LEA	trk_Lev,A4		; levels of the replayer tick, read only
	LEA	trk_Pk,A5		; peak segment, hold frames
	LEA	trk_SegC,A3		; segment codes drawn
	WMLEA	WM_SGEN,A6
	MOVEQ	#0,D7
.ch:	MOVEQ	#0,D2
	TST.B	agus_On			; card gone (quit, output switch): down
	BEQ.S	.v
	MOVE.B	(A4,D7.W),D2
	MULU	#TRK_SEG,D2		; segments lit
	LSR.W	#6,D2
.v:	MOVE.L	wide_Mute,D0
	BTST	D7,D0
	BEQ.S	.nm
	MOVEQ	#0,D2
	CLR.W	(A5)
	MOVEQ	#-1,D3			; muted: no peak
	BRA.S	.dr
.nm:	MOVEQ	#0,D3
	MOVE.B	(A5),D3			; peak (segments)
	CMP.W	D3,D2
	BLO.S	.f
	MOVE.B	D2,(A5)			; new peak, held
	MOVE.B	#TRK_HOLD,1(A5)
	MOVE.W	D2,D3
	BRA.S	.pp
.f:	TST.B	1(A5)
	BEQ.S	.fd
	SUBQ.B	#1,1(A5)
	BRA.S	.pp
.fd:	MOVE.W	trk_Frame,D0		; falls a segment every other frame
	BTST	#0,D0
	BEQ.S	.pp
	SUBQ.B	#1,(A5)
	SUBQ.W	#1,D3
.pp:	SUBQ.W	#1,D3			; peak segment, -1 none
	CMP.W	D2,D3
	BHS.S	.dr
	MOVEQ	#-1,D3			; inside the lit part
.dr:	BSR.S	pt_TrkChain
	LEA	TRK_SEG(A3),A3
	ADDQ.L	#2,A5
	ADDQ.W	#1,D7
	CMP.W	trk_ChKey,D7		; channels the stage was built for
	BLO.S	.ch
	ADDQ.W	#1,trk_Frame
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; chain of channel d7: d2 segments lit, peak segment d3 (-1 none),
; codes drawn at a3; changed segments drawn
pt_TrkChain:
	MOVEM.L	D0-D7/A0-A4,-(A7)
	BSR.W	pt_TrkBox
	WMLEA	WM_STG,A0
	ADDA.W	D0,A0
	ADDQ.L	#1,A0			; 1 px well each side
	SUBQ.W	#3,D1			; columns - 1
	BMI.S	.r
	MOVEQ	#TC_OFF,D6
	MOVE.L	wide_Mute,D0
	BTST	D7,D0
	BEQ.S	.m
	MOVEQ	#TC_MUTE,D6
.m:	LEA	trk_LitIx(PC),A2
	MOVEQ	#0,D5			; segment, bottom up
.s:	MOVE.B	D6,D4
	CMP.W	D5,D3
	BNE.S	.l
	MOVEQ	#TC_PEAK,D4
.l:	CMP.W	D2,D5
	BHS.S	.k
	MOVEQ	#TC_LIT,D4
	ADD.B	(A2,D5.W),D4
.k:	CMP.B	(A3,D5.W),D4
	BEQ.S	.n
	MOVE.B	D4,(A3,D5.W)
	MOVE.W	D5,D0
	LSL.W	#2,D0
	NEG.W	D0
	ADD.W	#TRK_SBOT-2,D0		; top row of the segment
	LEA	(A6,D0.W),A4		; row changes
	MULU	#640,D0
	LEA	(A0,D0.L),A1
	MOVEQ	#3-1,D7
.y:	MOVE.W	D1,D0
.x:	MOVE.B	D4,(A1,D0.W)
	DBF	D0,.x
	ADDQ.B	#1,(A4)+
	LEA	640(A1),A1
	DBF	D7,.y
.n:	ADDQ.W	#1,D5
	CMP.W	#TRK_SEG,D5
	BLO.S	.s
.r:	MOVEM.L	(A7)+,D0-D7/A0-A4
	RTS
; colour step of each segment (8 steps over the chain)
trk_LitIx:
	DC.B	0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,4,4,4,4,5,5,5,5,6,6,6,7
	EVEN

;--- track view: a vu bar over every track on screen, from the card
; levels (pt's own four sprites would only reach its group); look of
; the 8 track view: 12 px at the effect field, the colours of spr 4
TRK_VUX		EQU	46		; bar x in the base track
TRK_VUW		EQU	16		; column: bar and the rest of its byte
	IFNE	(TRK_X0+TRK_VUX)&7
	FAIL	"track vu column not byte aligned"
	ENDC

; from pt_RprVu: changed bars, all after a ring blit or a new layout
pt_TrkVu:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.W	trk_First,D0
	SWAP	D0
	MOVE.W	trk_Slot,D0
	LSL.W	#5,D0
	ADD.W	trk_Vis,D0
	CMP.L	trk_VuKey,D0
	BEQ.S	.k
	MOVE.L	D0,trk_VuKey
	ST	rpr_BlitDone
.k:	TST.B	rpr_BlitDone
	BEQ.S	.go
	LEA	trk_VuH,A0		; drawn heights unknown: all lines
	MOVEQ	#32-1,D0
.u:	ST	(A0)+
	DBF	D0,.u
.go:	LEA	trk_Lev,A0
	LEA	trk_VuH,A2
	MOVEQ	#0,D7			; track on screen
	BRA.W	.e
.l:	MOVE.W	trk_First,D0
	ADD.W	D7,D0			; channel
	MOVEQ	#0,D1			; height
	TST.B	dat_CursorPhase		; vu off
	BEQ.S	.h
	TST.B	agus_On
	BEQ.S	.h
	CMP.W	wide_Ch,D0
	BHS.S	.h
	MOVE.L	wide_Mute,D2
	BTST	D0,D2
	BNE.S	.h
	JSR	pt_LevH41
.h:	MOVEQ	#0,D3
	MOVE.B	(A2,D7.W),D3		; drawn
	CMP.B	#$ff,D3
	BNE.S	.d
	MOVE.W	#RPR_VUTOP,D5		; unknown: whole column
	MOVE.W	#RPR_BARTOP,D6
	BRA.S	.dr
.d:	CMP.W	D1,D3
	BEQ.S	.n
	MOVE.W	#RPR_BARTOP+1,D5	; lines between the two tops
	MOVE.W	D5,D6
	SUB.W	D1,D5
	SUB.W	D3,D6
	CMP.W	D5,D6
	BGE.S	.o
	EXG	D5,D6
.o:	CMP.W	#RPR_VUTOP,D5
	BGE.S	.o1
	MOVE.W	#RPR_VUTOP,D5
.o1:	CMP.W	#RPR_BARTOP,D6
	BLE.S	.o2
	MOVE.W	#RPR_BARTOP,D6
.o2:	CMP.W	D6,D5
	BGE.S	.s
.dr:	MOVE.B	D1,(A2,D7.W)
	MOVE.W	D1,trk_VuCur
	MOVE.W	D7,D0
	JSR	pt_TrkSX
	MOVEQ	#TRK_VUX,D1
	JSR	pt_TrkUShift
	ADD.W	D1,D0
	MOVE.W	D0,D4
	MOVE.W	D5,D1
	MOVE.W	D6,D2
	BSR.S	pt_TrkVuCol
	BRA.S	.n
.s:	MOVE.B	D1,(A2,D7.W)
.n:	ADDQ.W	#1,D7
.e:	CMP.W	trk_Vis,D7
	BLO.W	.l
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; column at wide x d4, native lines d1..d2-1: template, text, the bar of
; height trk_VuCur; written as pt_RwdVuCol does
pt_TrkVuCol:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.W	rwd_W,D3
	SUB.W	#TRK_VUW,D3
	CMP.W	D3,D4
	BHI.W	.out
	MOVE.W	D2,D6
	MOVE.W	D1,rpr_VuTop
	SUB.W	D1,D2
	MOVE.W	D2,rpr_VuLines
	WMLEA	WM_VU,A1
	MOVE.W	D1,D5			; native line
.ln:	MOVE.W	D5,D0
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
	MOVE.L	(A3)+,(A1)
	MOVE.L	(A3)+,4(A1)
	MOVE.L	(A3)+,8(A1)
	MOVE.L	(A3)+,12(A1)
	TST.W	D0
	BMI.S	.bar
	CMP.W	#63,D0
	BHI.S	.bar
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
	MOVEQ	#TRK_VUW/8-1,D3
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
.bar:	MOVE.W	#RPR_BARTOP+1,D0	; line inside the bar?
	SUB.W	trk_VuCur,D0
	CMP.W	D0,D5
	BLT.S	.nb
	BSR.S	pt_TrkVuPx
.nb:	LEA	TRK_VUW(A1),A1
	ADDQ.W	#1,D5
	CMP.W	D6,D5
	BLO.W	.ln
	MOVE.W	#TRK_VUW,rpr_VuW
	MOVE.W	D4,D0
	MOVE.W	rpr_VuTop,D1
	ADD.W	rtg_Shift,D1
	MOVE.W	rpr_VuLines,D2
	JSR	pt_RprRectW
.out:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; bar pixels of native line d5 into (a1): 2 px colour 1, 8 colour 2,
; 2 colour 3 of spr 4 on that line
pt_TrkVuPx:
	MOVEM.L	D0-D2/A0/A5-A6,-(A7)
	MOVEA.L	rtg_RowSt,A5
	MOVE.W	D5,D0
	MULU	#RTG_STSIZE,D0
	ADDA.L	D0,A5
	LEA	28+32+2*8(A5),A5	; colour 16 + spr pair 2
	X20LEA	X20_RTGCOLMAP,A6
	MOVEA.L	A1,A0
	MOVE.W	2(A5),D1
	BSR.S	.col
	MOVE.B	D1,(A0)+
	MOVE.B	D1,(A0)+
	MOVE.W	4(A5),D1
	BSR.S	.col
	MOVEQ	#8-1,D2
.m:	MOVE.B	D1,(A0)+
	DBF	D2,.m
	MOVE.W	6(A5),D1
	BSR.S	.col
	MOVE.B	D1,(A0)+
	MOVE.B	D1,(A0)+
	MOVEM.L	(A7)+,D0-D2/A0/A5-A6
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
