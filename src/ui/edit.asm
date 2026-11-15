; editor: 8 track mute, wheel, scope base, help slider
; ctrl+a: mute track under cursor, d0=trk*11+4 -> toggle of ch 1-8
pt_EditMuteTrack:
	ADDQ.L	#4,A7			; toggles return on their own
	SUBQ.W	#4,D0
	BPL.S	.ok
	MOVEQ	#0,D0
.ok:	EXT.L	D0
	DIVU	#11,D0			; track 0-7
	AND.W	#7,D0
	ADD.W	D0,D0
	ADD.W	D0,D0
	LEA	.tab(PC),A0
	MOVEA.L	(A0,D0.W),A0
	JMP	(A0)
.tab:	DC.L	pt_ScopeCh1Toggle,pt_ScopeCh2Toggle,pt_ScopeCh3Toggle,pt_ScopeCh4Toggle
	DC.L	pt_012F,pt_0130,pt_0131,pt_0132

; wheel: newmouse $7a/$7b -> cursor up/down ($4c/$4d, release $cc/$cd)
pt_EditWheelKey:
	JSR	pt_TrkScrollKey		; track view: shift + wheel scrolls
	MOVE.B	D1,D0
	AND.B	#$7f,D0
	CMP.B	#$7a,D0
	BNE.S	.n1
	SUB.B	#$7a-$4c,D1
	BRA.S	.st
.n1:	CMP.B	#$7b,D0
	BNE.S	.st
	SUB.B	#$7b-$4d,D1
.st:	MOVE.B	D1,dat_KeyCode
	RTS

; hook: sampler volume box, return or esc closes -> z=1
pt_SmpVolKey41:
	MOVE.B	dat_KeyCode,D2
	CMP.B	#$45,D2
	BNE.S	.n
	CLR.B	dat_KeyCode		; esc stays in the sampler, z=1
	RTS
.n:	CMP.B	#$44,D2
	RTS

; hook: input handler, same raw key again: every wheel notch counts
pt_InKey41:
	CMP.B	#$7a,D0
	BEQ.S	.w
	CMP.B	#$7b,D0
	BEQ.S	.w
	CMP.B	dat_RawKeyCode,D0
	RTS
.w:	ANDI	#$fb,CCR		; z=0: new key
	RTS

; sampler: scopes show the cursor half (col>=24 -> ch5-8)
pt_ScopeBase:
	TST.B	wide_On			; wide module: own panel box
	BEQ.S	.nw
	CMPI.W	#1,dat_UIMode
	BEQ.S	.w
	CMPI.W	#9,dat_UIMode
	BEQ.S	.w
	SF	wsc_State		; box hidden: laid out again on return
	BRA.S	.b
.w:	TST.W	dat_SamplerActive
	BEQ.S	.ws
	JSR	pt_WideSmpBar41
.ws:	JSR	pt_WideScope41
	ADDQ.L	#4,A7			; leave caller too
	RTS
.nw:	TST.B	wsc_State		; left wide mode: box back to pt
	BEQ.S	.b
	JSR	pt_WideScopeEnd41
.b:	LEA	dat_Channel1,A0
	BTST	#5,dat_ModeFlags	; set = 4ch
	BNE.S	.r
	CMPI.W	#24,dat_CursorColumn
	BCS.S	.r
	LEA	dat_Channel5,A0
.r:	JSR	pt_Mix68ScopeOff	; a500 mode -> scopes off
	BEQ.S	.rr
	ADDQ.L	#4,A7			; leave caller too
	RTS
.rr:	BTST	#5,dat_ModeFlags
	BNE.S	.x
	JSR	pt_Scope8		; 8ch: all channels, sampler too
	ADDQ.L	#4,A7
.x:	RTS

; scope: mixed voices count as running (card, ahi: no paula dma)
pt_ScopeDma41:
	MOVE.W	DMACONR,D6
	TST.B	mix_Active
	BEQ.S	.r
	MOVEQ	#0,D0
	MOVE.B	mix_PairMask,D0
	AND.W	dat_RpDmaChanMask,D0	; muted tracks stay flat
	OR.W	D0,D6
.r:	RTS

; d0=len input -> d0=1..128
pt_SongLenClamp41:
	CMP.W	#$0080,D0
	BLS.S	.lo
	MOVE.W	#$0080,D0
.lo:	TST.W	D0
	BNE.S	.r
	MOVEQ	#1,D0
.r:	RTS

; scope step = $8a8d/d1, d1=per/2 (unsigned)
pt_ScopeStep41:
	MOVE.L	#$00008a8d,D2
	DIVU.W	D1,D2
	AND.L	#$0000ffff,D2
	RTS

; help page: 15 lines + slider (head b6='S', b9=top, b12=height)
HLP_ROW0	EQU	17*80+78
pt_HelpPage41:
	MOVEM.L	D0-D2/A0-A2,-(A7)
	LEA	SECSTRT_2+HLP_ROW0,A0
	LEA	chip_ScreenBitplanes+HLP_ROW0,A1
	MOVEA.L	dat_ScreenBuf2Ptr,A2
	LEA	HLP_ROW0(A2),A2
	MOVEQ	#92-1,D0		; clear old slider
.clr:	CLR.B	(A0)
	CLR.B	(A1)
	CLR.B	(A2)
	LEA	80(A0),A0
	LEA	80(A1),A1
	LEA	80(A2),A2
	DBF	D0,.clr
	CMPI.B	#'S',dat_153E+6
	BNE.W	.done
	LEA	SECSTRT_2+HLP_ROW0,A0
	LEA	chip_ScreenBitplanes+HLP_ROW0,A1
	MOVE.B	#$ff,(A1)		; rail frame
	MOVE.B	#$ff,91*80(A1)
	LEA	80(A1),A2
	MOVEQ	#90-1,D0
.rail:	MOVE.B	#$81,(A2)
	LEA	80(A2),A2
	DBF	D0,.rail
	MOVEQ	#0,D1
	MOVE.B	dat_153E+9,D1
	SUB.W	#32,D1
	MOVEQ	#0,D2
	MOVE.B	dat_153E+12,D2
	SUB.W	#32,D2
	CMP.W	#3,D2
	BLT.S	.done
	MOVE.W	D1,D0
	ADD.W	D2,D0
	CMP.W	#90,D0
	BHI.S	.done			; bad head -> no slider
	MULU.W	#80,D1
	LEA	80(A0,D1.L),A0
	LEA	80(A1,D1.L),A1
	MOVE.B	#$7e,(A0)
	MOVE.B	#$83,(A1)
	SUBQ.W	#3,D2
.mid:	LEA	80(A0),A0
	LEA	80(A1),A1
	MOVE.B	#$42,(A0)
	MOVE.B	#$bf,(A1)
	DBF	D2,.mid
	MOVE.B	#$7e,80(A0)
	MOVE.B	#$bf,80(A1)
.done:	BSR.S	pt_HelpTail41
	MOVEM.L	(A7)+,D0-D2/A0-A2
	MOVE.W	#$05a0,D6
	MOVEQ	#15-1,D7
	RTS

; tail after the 15 lines: 'K' first k n step -> hlp_Tail
pt_HelpTail41:
	CLR.B	hlp_Tail
	LEA	dat_153E+16,A0
	MOVE.W	#$520-16-6,D1
	MOVEQ	#15-1,D0
.l:	SUBQ.W	#1,D1
	BMI.S	.r
	CMPI.B	#10,(A0)+
	BNE.S	.l
	DBF	D0,.l
	CMPI.B	#'K',(A0)
	BNE.S	.r
	MOVE.B	(A0)+,hlp_Tail
	MOVE.B	(A0)+,hlp_Tail+1
	MOVE.B	(A0)+,hlp_Tail+2
	MOVE.B	(A0)+,hlp_Tail+3
	MOVE.B	(A0)+,hlp_Tail+4
.r:	RTS

; hook: start of pt_InputHelp, lmb on the slider -> page or drag
pt_HelpIn41:
	MOVEM.W	dat_SavedEditDigit,D0-D1
	CMP.W	#616,D0
	BLT.S	.r
	CMP.W	#17,D1
	BLT.S	.r
	CMP.W	#108,D1
	BGT.S	.r
	CMPI.B	#'S',dat_153E+6
	BNE.S	.r
	CMPI.B	#'K',hlp_Tail
	BEQ.S	.y
.r:	RTS
.y:	ADDQ.L	#4,A7			; leave pt_InputHelp
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVEQ	#0,D4
	MOVE.B	hlp_Tail+2,D4		; k
	MOVEQ	#0,D3
	MOVE.B	dat_153E+9,D3
	SUB.W	#32-18,D3		; knob top row
	CMP.W	D3,D1
	BLT.S	.up
	MOVEQ	#0,D5
	MOVE.B	dat_153E+12,D5
	SUB.W	#32,D5			; knob height
	MOVE.W	D3,D2
	ADD.W	D5,D2
	CMP.W	D2,D1
	BGE.S	.dn
	SUB.W	D3,D1
	MOVE.W	D1,D7			; grab
	MOVEQ	#90,D6
	SUB.W	D5,D6			; travel
	MOVEQ	#0,D5
	MOVE.B	hlp_Tail+3,D5
	SUBQ.W	#1,D5			; last k
.dr:	JSR	pt_ScreenDragUpdate	; test driver steps, screen drag
	JSR	pt_UpdateMousePos
	LMB
	BNE.S	.x
	MOVE.W	dat_PalEdSelectPos,D0
	SUB.W	#18,D0
	SUB.W	D7,D0			; knob top wanted
	BPL.S	.d0
	MOVEQ	#0,D0
.d0:	CMP.W	D6,D0
	BLS.S	.d1
	MOVE.W	D6,D0
.d1:	MOVEQ	#0,D4
	TST.W	D6
	BEQ.S	.dg
	MULU	D5,D0
	MOVE.W	D6,D4
	LSR.W	#1,D4
	ADD.L	D0,D4			; rounded
	DIVU	D6,D4
.dg:	BSR.S	.go
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-270,A6)		; WaitTOF
	BRA.S	.dr
.up:	MOVEQ	#0,D0
	MOVE.B	hlp_Tail+4,D0
	SUB.W	D0,D4
	BPL.S	.pg
	MOVEQ	#0,D4
	BRA.S	.pg
.dn:	MOVEQ	#0,D0
	MOVE.B	hlp_Tail+4,D0
	ADD.W	D0,D4
	MOVEQ	#0,D0
	MOVE.B	hlp_Tail+3,D0
	CMP.W	D0,D4
	BLT.S	.pg
	MOVE.W	D0,D4
	SUBQ.W	#1,D4
.pg:	BSR.S	.go			; held: the main loop repeats
.x:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS
; d4=k -> page first+k unless shown
.go:	MOVEQ	#0,D0
	MOVE.B	hlp_Tail+1,D0
	ADD.W	D4,D0
	CMP.B	dat_0485+1,D0
	BEQ.S	.gr
	MOVEM.L	D1-D7/A0-A6,-(A7)
	MOVE.W	D0,dat_0485
	JSR	pt_EnterHelp
	MOVEM.L	(A7)+,D1-D7/A0-A6
.gr:	RTS

;--- 8 track editing: row stride 16 (4ch) / 32 (8ch)
; d3 = row stride
pt_Stride41:
	MOVEQ	#16,D3
	BTST	#5,dat_ModeFlags	; set = 4ch
	BNE.S	.r
	MOVEQ	#32,D3
.r:	RTS

; d0.w = row -> d0.w = row ofs
pt_RowOfs41:
	AND.W	#$003f,D0
	LSL.W	#4,D0
	BTST	#5,dat_ModeFlags
	BNE.S	.r
	ADD.W	D0,D0
.r:	RTS

pt_PosOfs41:
	MOVE.W	dat_PatternPosition,D0
	BRA.S	pt_RowOfs41

; patops block scope: d0.w = block start row ofs
pt_EdRowOfs41:
	MOVE.W	dat_EditCursorRow,D0
	BRA.S	pt_RowOfs41

; rot down 8ch: wrap cell of the last row
pt_RotWrap41:
	MOVE.W	(32,A0),D1
	MOVE.W	(34,A0),D2
	RTS

; multi: d0.w = trk -> next trk, 8ch keeps the half
pt_MultiNext41:
	MOVEM.L	D1-D5/A0,-(A7)
	MOVE.W	D0,D5
	JSR	pt_TrkN41
	MOVE.W	D0,D4			; tracks in use
	MOVE.W	D5,D2
	AND.W	#4,D2
	MOVE.W	D5,D1
	MOVEQ	#3,D3
	LEA	dat_DiskIOReady,A0
.l:	AND.W	#3,D1
	MOVE.B	(0,A0,D1.W),D1
	SUBQ.W	#1,D1
	AND.W	#3,D1
	MOVE.W	D1,D0
	OR.W	D2,D0
	CMP.W	D4,D0
	BCS.S	.r			; skips hidden tracks
	DBF	D3,.l
	MOVE.W	D5,D0
.r:	MOVEM.L	(A7)+,D1-D5/A0
	RTS

; block transpose: d5 = start row ofs
pt_BlkTrAddr41:
	BTST	#5,dat_ModeFlags
	BNE.S	.r
	ADD.W	D5,D5
.r:	MOVE.W	dat_CursorColumn,D0
	RTS

; delete row above cursor, a0 = trk base -> d2 = -1
pt_DelRow41:
	MOVE.W	dat_PatternPosition,D0
	BNE.S	.go
	MOVEQ	#0,D2			; row 0: cursor stays
	RTS
.go:	MOVEM.L	D3/A1,-(A7)
	BSR.W	pt_Stride41
	SUBQ.W	#1,D0
	MULU	D3,D0
	MOVE.W	D3,D1
	LSL.W	#6,D1
	SUB.W	D3,D1			; last row
.l:	CMP.W	D1,D0
	BCC.S	.e
	LEA	(0,A0,D0.W),A1
	MOVE.L	(A1,D3.W),(A1)
	ADD.W	D3,D0
	BRA.S	.l
.e:	MOVEQ	#-1,D2
	CLR.L	(0,A0,D1.W)
	MOVEM.L	(A7)+,D3/A1
	RTS

; delete row above cursor, fx column only
pt_DelFx41:
	MOVE.W	dat_PatternPosition,D0
	BNE.S	.go
	MOVEQ	#0,D2			; row 0: cursor stays
	RTS
.go:	MOVEM.L	D3/A1,-(A7)
	BSR.W	pt_Stride41
	SUBQ.W	#1,D0
	MULU	D3,D0
	MOVE.W	D3,D1
	LSL.W	#6,D1
	SUB.W	D3,D1
.l:	CMP.W	D1,D0
	BCC.S	.e
	LEA	(0,A0,D0.W),A1
	MOVE.W	(2,A1,D3.W),D2
	AND.W	#$0fff,D2
	ANDI.W	#$f000,(2,A1)
	OR.W	D2,(2,A1)
	ADD.W	D3,D0
	BRA.S	.l
.e:	MOVEQ	#-1,D2
	ANDI.W	#$f000,(2,A0,D1.W)
	MOVEM.L	(A7)+,D3/A1
	RTS

; insert row at cursor, a0 = trk base -> d2 = 1
pt_InsRow41:
	MOVEM.L	D3/A1,-(A7)
	BSR.W	pt_Stride41
	MOVE.W	dat_PatternPosition,D1
	MULU	D3,D1
	MOVE.W	D3,D0
	LSL.W	#6,D0
	SUB.W	D3,D0
	SUB.W	D3,D0			; second last row
.l:	CMP.W	D1,D0
	BLT.S	.e
	LEA	(0,A0,D0.W),A1
	MOVE.L	(A1),(A1,D3.W)
	SUB.W	D3,D0
	BRA.S	.l
.e:	MOVEQ	#1,D2
	CLR.L	(0,A0,D1.W)
	MOVEM.L	(A7)+,D3/A1
	RTS

; insert row at cursor, fx column only
pt_InsFx41:
	MOVEM.L	D3/A1,-(A7)
	BSR.W	pt_Stride41
	MOVE.W	dat_PatternPosition,D1
	MULU	D3,D1
	MOVE.W	D3,D0
	LSL.W	#6,D0
	SUB.W	D3,D0
	SUB.W	D3,D0
.l:	CMP.W	D1,D0
	BLT.S	.e
	LEA	(0,A0,D0.W),A1
	MOVE.W	(2,A1),D2
	AND.W	#$0fff,D2
	ANDI.W	#$f000,(2,A1,D3.W)
	OR.W	D2,(2,A1,D3.W)
	SUB.W	D3,D0
	BRA.S	.l
.e:	MOVEQ	#1,D2
	ANDI.W	#$f000,(2,A0,D1.W)
	MOVEM.L	(A7)+,D3/A1
	RTS

; ctrl+c: block (track under cursor) -> buf, one long per row
pt_BlkCopy41:
	CLR.W	dat_EditCursorPos
	MOVE.W	#$0001,dat_048B
	MOVE.W	dat_CursorColumn,D0
	JSR	pt_GetPatternAddr
	MOVE.L	D3,-(A7)
	BSR.W	pt_Stride41
	LEA	dat_14F0,A1
	MOVEQ	#63,D0
.l:	MOVE.L	(A0),(A1)+
	ADDA.W	D3,A0
	DBF	D0,.l
	MOVE.L	(A7)+,D3
	MOVE.W	dat_0488,D0
	MOVE.W	dat_LastPatPos,D1
	CMP.W	D0,D1
	BCC.S	.o
	EXG	D0,D1
.o:	MOVE.W	D0,dat_048E
	MOVE.W	D1,dat_048F
	JMP	pt_ClearStatusMsg

; ctrl+p/j/w: buf -> track at cursor row
pt_BlkPaste41:
	CLR.B	dat_KeyCode
	TST.W	dat_048B
	BNE.S	*+8
	JMP	pt_r07a16
	JSR	pt_ConvertKeyToNote
	MOVE.W	dat_CursorColumn,D0
	JSR	pt_GetPatternAddr
	MOVEM.L	D5/D7,-(A7)
	MOVEQ	#16,D7
	BTST	#5,dat_ModeFlags
	BNE.S	.s
	MOVEQ	#32,D7
.s:	LEA	dat_14F0,A1
	MOVE.W	dat_048E,D0		; src row
	MOVE.W	dat_048F,D1
	MOVE.W	dat_PatternPosition,D2	; dst row
.l:	MOVE.W	D0,D5
	LSL.W	#2,D5
	MOVE.L	(0,A1,D5.W),D3
	MOVE.W	D2,D5
	MULU	D7,D5
	TST.W	dat_048C
	BEQ.S	.st
	MOVE.L	D3,D4
	AND.L	#$fffff000,D4
	BNE.S	.st
	MOVE.L	(0,A0,D5.W),D4
	AND.L	#$fffff000,D4
	AND.L	#$00000fff,D3
	OR.L	D4,D3
.st:	MOVE.L	D3,(0,A0,D5.W)
	CMP.W	D0,D1
	BEQ.S	.e
	CMP.W	#63,D0
	BEQ.S	.e
	CMP.W	#63,D2
	BEQ.S	.e
	ADDQ.W	#1,D0
	ADDQ.W	#1,D2
	TST.W	dat_048D
	BEQ.S	.l
	MOVEM.L	D0-D2/A1,-(A7)
	JSR	pt_ProcessPlayback
	MOVE.W	dat_CursorColumn,D0
	JSR	pt_GetPatternAddr
	MOVEM.L	(A7)+,D0-D2/A1
	BRA.S	.l
.e:	MOVEM.L	(A7)+,D5/D7
	JMP	pt_r077b0

; ctrl+b.. clear block
pt_BlkClear41:
	CLR.B	dat_KeyCode
	TST.W	dat_EditCursorPos
	BNE.S	*+8
	JMP	pt_r07a08
	JSR	pt_ConvertKeyToNote
	CLR.W	dat_EditCursorPos
	MOVE.W	dat_CursorColumn,D0
	JSR	pt_GetPatternAddr
	BSR.W	pt_Stride41
	MOVE.W	dat_0488,D0
	MOVE.W	dat_LastPatPos,D1
	CMP.W	D0,D1
	BCC.S	.o
	EXG	D0,D1
.o:	MULU	D3,D0
	MULU	D3,D1
	MOVEQ	#0,D2
.l:	MOVE.L	D2,(0,A0,D0.W)
	CMP.W	D0,D1
	BEQ.S	.e
	ADD.W	D3,D0
	BRA.S	.l
.e:	JSR	pt_ClearStatusMsg
	JMP	pt_PatViewDrawAll

; ctrl+y reverse block
pt_BlkRev41:
	CLR.B	dat_KeyCode
	TST.W	dat_EditCursorPos
	BNE.S	*+8
	JMP	pt_r07a08
	JSR	pt_ConvertKeyToNote
	CLR.W	dat_EditCursorPos
	MOVE.W	dat_CursorColumn,D0
	JSR	pt_GetPatternAddr
	BSR.W	pt_Stride41
	MOVE.W	dat_0488,D0
	MOVE.W	dat_LastPatPos,D1
	CMP.W	D0,D1
	BCC.S	.o
	EXG	D0,D1
.o:	MULU	D3,D0
	MULU	D3,D1
.l:	CMP.W	D1,D0
	BCC.S	.e
	MOVE.L	(0,A0,D0.W),D2
	MOVE.L	(0,A0,D1.W),(0,A0,D0.W)
	MOVE.L	D2,(0,A0,D1.W)
	ADD.W	D3,D0
	SUB.W	D3,D1
	BRA.S	.l
.e:	JSR	pt_ClearStatusMsg
	JMP	pt_PatViewDrawAll

; ctrl+k: clear track from cursor to end (shift: to start)
pt_KillTrk41:
	CLR.B	dat_KeyCode
	JSR	pt_ConvertKeyToNote
	MOVE.W	dat_CursorColumn,D0
	JSR	pt_GetPatternAddr
	BSR.W	pt_Stride41
	MOVE.W	dat_PatternPosition,D0
	MOVE.W	D0,D1
	MULU	D3,D1
	LEA	(0,A0,D1.W),A0
	TST.W	dat_KeyQual1
	BNE.S	.up
.dn:	CLR.L	(A0)
	ADDA.W	D3,A0
	ADDQ.W	#1,D0
	CMP.W	#64,D0
	BCS.S	.dn
	JMP	pt_PatViewDrawAll
.up:	CLR.L	(A0)
	SUBA.W	D3,A0
	SUBQ.W	#1,D0
	BPL.S	.up
	JMP	pt_PatViewDrawAll

; undo: snapshot / swap of the whole pattern
pt_UndoSave41:
	MOVEM.L	D0/A0-A1,-(A7)
	MOVE.W	trk_Grp,trk_UndoGrp
	MOVE.W	dat_PatTableIdx+2,trk_UndoPat
	MOVEQ	#0,D0
	JSR	pt_GetPatternAddr
	LEA	dat_14F3,A1
	BSR.W	pt_UndoCnt41
.l:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.l
	MOVEM.L	(A7)+,D0/A0-A1
	RTS

pt_UndoSwap41:
	CLR.B	dat_KeyCode
	MOVE.W	dat_PatTableIdx+2,D0
	CMP.W	trk_UndoPat,D0
	BNE.S	.np
	TST.B	wide_On			; wide: snapshot group into the view
	BEQ.S	.g
	MOVE.W	trk_UndoGrp,D0
	CMP.W	trk_Grp,D0
	BEQ.S	.g
	JSR	pt_WideGMax41		; group past the count: no snapshot
	CMP.W	trk_UndoGrp,D0
	BCS.S	.np
	MOVE.W	trk_UndoGrp,D0
	JSR	pt_TrkGrpSet
	CMP.W	trk_Grp,D0
	BNE.S	.nm
	JSR	pt_WideBtns41
.g:	MOVEQ	#0,D0
	JSR	pt_GetPatternAddr
	LEA	dat_14F3,A1
	BSR.W	pt_UndoCnt41
.l:	MOVE.L	(A1),D1
	MOVE.L	(A0),(A1)+
	MOVE.L	D1,(A0)+
	DBF	D0,.l
	JMP	pt_PatViewDrawAll
.nm:	LEA	wide_MsgGrpMem,A0	; other group: no memory, no undo
	JMP	pt_StatusLater41
.np:	LEA	edit_MsgUndoPat,A0	; snapshot is of another pattern
	JMP	pt_StatusLater41

pt_UndoCnt41:
	MOVE.W	#$00ff,D0
	BTST	#5,dat_ModeFlags
	BNE.S	.r
	MOVE.W	#$01ff,D0
.r:	RTS

edit_MsgUndoPat:	DC.B	"UNDO IS OF ANOTHER PATTERN",0
	EVEN

; chunk list of ch d0 (0-7) -> a3; table has ch 1-4 only
pt_ChunkList41:
	CMP.W	#4,D0
	BCC.S	.ch5
	LEA	dat_AudioChannelPtrs,A3
	ADD.W	D0,D0
	ADD.W	D0,D0
	MOVEA.L	(0,A3,D0.W),A3
	RTS
.ch5:	LEA	mix_ChunkLists,A3
	SUBQ.W	#4,D0
	MULU	#800,D0
	ADDA.L	D0,A3
	RTS

; f3-f5 + shift/ctrl: d0.w = cursor col, 0 with alt (whole pattern)
pt_FkeyCol41:
	MOVE.W	dat_CursorColumn,D0
	TST.W	dat_KeyQual2
	BEQ.S	.r
	MOVEQ	#0,D0
.r:	RTS

;--- notes outside c-1..b-3: nearest name instead of "???"
; hook pt_FormatNoteCell: d1.w = period not in the table, a3 = cell
; octave 0/4 as named, between two notes "C?3", out of 0..9 clamped + "?"
pt_NoteNear41:
	MOVEM.L	D0-D7/A0,-(A7)
	MOVE.W	D1,D5
	MOVEQ	#0,D6			; octaves shifted (+ up, - down)
.up:	CMP.W	#55,D5			; below b-4: double
	BHI.S	.dn
	ADD.W	D5,D5
	ADDQ.W	#1,D6
	BRA.S	.up
.dn:	CMP.W	#1763,D5		; above c-0: halve
	BLS.S	.find
	LSR.W	#1,D5
	SUBQ.W	#1,D6
	BRA.S	.dn
.find:	LEA	note_Per41(PC),A0
	MOVE.W	#$7fff,D3		; best diff
	MOVEQ	#0,D7
	MOVEQ	#0,D4
.l:	MOVE.W	(A0)+,D0
	BEQ.S	.got
	SUB.W	D5,D0
	BPL.S	.a
	NEG.W	D0
.a:	CMP.W	D3,D0
	BCC.S	.n
	MOVE.W	D0,D3
	MOVE.W	D7,D4
.n:	ADDQ.W	#1,D7
	BRA.S	.l
.got:	DIVU	#12,D4			; octave, note
	ADD.W	D4,D6
	SWAP	D4
	LSL.W	#2,D4
	MOVEA.L	dat_NoteNamesPtr,A0	; sharps or flats
	MOVE.B	(A0,D4.W),(A3)
	MOVE.B	1(A0,D4.W),1(A3)
	TST.W	D3
	BEQ.S	.ex
	MOVE.B	#'?',1(A3)		; between two notes
.ex:	TST.W	D6
	BPL.S	.o1
	MOVEQ	#0,D6
	MOVE.B	#'?',1(A3)
.o1:	CMP.W	#9,D6
	BLS.S	.o2
	MOVEQ	#9,D6
	MOVE.B	#'?',1(A3)
.o2:	ADD.B	#'0',D6
	MOVE.B	D6,2(A3)
	MOVE.B	#' ',3(A3)
	MOVEM.L	(A7)+,D0-D7/A0
	RTS

; c-0..b-4, finetune 0 (octave 0 and 4 as other trackers write them)
note_Per41:
	DC.W	1712,1616,1525,1440,1357,1281,1209,1141,1077,1017,961,907
	DC.W	856,808,762,720,678,640,604,570,538,508,480,453
	DC.W	428,404,381,360,340,320,302,285,269,254,240,226
	DC.W	214,202,190,180,170,160,151,143,135,127,120,113
	DC.W	107,101,95,90,85,80,76,71,67,64,60,57
	DC.W	0

;--- note entry, notes EXT: keys I..] of the upper row (f2) = c-4..g-4
; hook pt_KeyToPlayCmd: d0 = key pos, a1 = key->note table; flags as
; CMP.W #$24,D0 after the lookup
NOTE_KEYC4	EQU	29		; key pos of c-4 (one octave above c-3)
NOTE_KEYG4	EQU	36
pt_NoteKey41:
	SF	note_Up41
	TST.B	note_Ext41
	BEQ.S	.n
	CMPA.L	#dat_PlayPatAddr,A1	; f2 table
	BNE.S	.n
	CMP.W	#NOTE_KEYC4,D0
	BCS.S	.n
	CMP.W	#NOTE_KEYG4,D0
	BHI.S	.n
	SUB.W	#12,D0			; same key one octave lower
	ST	note_Up41
.n:	MOVE.B	(0,A1,D0.W),D0
	CMP.W	#$0024,D0
	RTS

; hook: d3.l = period of note d0/2 (a1 = finetune 0 table)
pt_NotePer41:
	MOVEQ	#0,D3
	MOVE.W	(0,A1,D0.W),D3
	TST.B	note_Up41
	BEQ.S	.r
	MOVE.L	A0,-(A7)
	LEA	note_Per41+48(PC),A0	; c-2, i.e. one octave up from c-1
	MOVE.W	(0,A0,D0.W),D3
	MOVEA.L	(A7)+,A0
.r:	RTS

; hook: preview period of note d0/2 with finetune (a1 = its table)
pt_NotePlay41:
	MOVE.L	D1,-(A7)
	MOVE.W	(0,A1,D0.W),D1
	TST.B	note_Up41
	BEQ.S	.s
	SF	note_Up41
	CMP.W	#24*2,D0
	BCC.S	.h
	MOVE.W	24(A1,D0.W),D1		; up an octave within the table
	BRA.S	.s
.h:	ADDQ.W	#1,D1			; octave 3 -> 4: half the period
	LSR.W	#1,D1
.s:	MOVE.W	D1,dat_PlaybackEnable
	MOVE.L	(A7)+,D1
	RTS
