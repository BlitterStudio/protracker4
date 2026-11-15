; 8ch display: vu meters and scopes for all channels at once

;--- vu: 4 sprites x 2 bars of 6 px, copper moves them to tracks 5-8
; hook: vbl tick instead of TST.B dat_CursorPhase
pt_Vu8Tick41:
	BTST	#5,dat_ModeFlags	; set = 4ch
	BEQ.S	.m8
.c4:	TST.B	vu8_On
	BEQ.S	.w4
	BSR.W	pt_Vu8Restore
.w4:	TST.B	wide_On			; wide module: levels of the card
	BEQ.S	.r
	TST.B	dat_CursorPhase
	BEQ.S	.r
	BSR.W	pt_WideVu41
	ORI	#4,CCR			; z=1: pt's 4 bars skipped
	RTS
.r:	TST.B	dat_CursorPhase
	RTS
.m8:	TST.B	mix68_Slow		; a500 mode: no spare irq time, old vu
	BEQ.S	.go
	TST.B	mix_Active
	BNE.S	.c4
.go:	TST.B	dat_CursorPhase
	BEQ.S	.r
	LEA	dat_Channel1,A1
	LEA	dat_ScopeCh1,A3
	LEA	vu8_Dummy,A2
	MOVEQ	#7,D7
.v:	TST.B	wide_On
	BEQ.S	.o
	MOVEQ	#7,D0
	SUB.W	D7,D0
	BSR.W	pt_WideVuH41
	BRA.S	.n
.o:	JSR	pt_r0284e		; height only, header goes to the dummy
.n:	LEA	n_SIZEOF(A1),A1
	LEA	10(A3),A3
	DBF	D7,.v
	BSR.W	pt_Vu8Draw
	ADDQ.L	#4,A7			; leave pt_r027fc too
	RTS

; wide module, 4 track view: pt's 4 bars from the card levels
pt_WideVu41:
	LEA	chip_PanelBitplane1,A2
	LEA	dat_ScopeCh1,A3
	MOVEQ	#0,D3
.l:	MOVE.W	D3,D0
	BSR.S	pt_WideVuH41
	JSR	pt_DrawScopeSprite
	LEA	$d0(A2),A2
	LEA	10(A3),A3
	ADDQ.W	#1,D3
	CMP.W	#4,D3
	BLO.S	.l
	RTS

; view slot d0 -> bar height (4,a3) 1..48 from trk_Lev, as pt scales
; the volume; muted or silent: rest
pt_WideVuH41:
	MOVEM.L	D0-D2/A0,-(A7)
	MOVE.W	trk_Grp,D1
	LSL.W	#2,D1
	ADD.W	D1,D0			; channel
	MOVEQ	#1,D1
	TST.B	agus_On
	BEQ.S	.s
	CMP.W	wide_Ch,D0
	BHS.S	.s
	MOVE.L	wide_Mute,D2
	BTST	D0,D2
	BNE.S	.s
	LEA	trk_Lev,A0
	BSR.S	pt_LevH41
.s:	MOVE.W	D1,(4,A3)
	MOVEM.L	(A7)+,D0-D2/A0
	RTS

; level of channel d0 at (a0) -> d1 = height 1..48 (pt's vu scale)
pt_LevH41:
	MOVEQ	#0,D1
	MOVE.B	(A0,D0.W),D1
	CMP.W	#63,D1
	BLS.S	.c
	MOVEQ	#63,D1
.c:	MULU	#48,D1
	MULU	dat_RpMasterVol,D1
	ADD.L	#32,D1
	LSR.L	#6,D1
	LSR.W	#6,D1
	BNE.S	.r
	MOVEQ	#1,D1
.r:	RTS

; hook: pt_InitPalettes, instead of LEA chip_PanelBitplane1,A2
pt_Vu8Init41:
	BTST	#5,dat_ModeFlags
	BEQ.S	.m8
	TST.B	vu8_On
	BEQ.S	.r
	BSR.W	pt_Vu8Restore
.r:	LEA	chip_PanelBitplane1,A2
	RTS
.m8:	MOVEM.L	D0-D7/A0-A5,-(A7)
	BSR.W	pt_Vu8Draw
	MOVEM.L	(A7)+,D0-D7/A0-A5
	ADDQ.L	#4,A7
	RTS

; sprite data back to 1 bar of 10 px
pt_Vu8Restore:
	MOVEM.L	D0-D1/A0-A1,-(A7)
	SF	vu8_On
	ST	dat_0658		; analyzer backdrop again
	BSR.S	pt_Vu8Unhook
	LEA	chip_PanelBitplane1+4,A0
	MOVEQ	#4-1,D1
.k:	MOVEQ	#48-1,D0
	MOVEA.L	A0,A1
.l:	MOVE.L	#$c0c03fc0,(A1)+
	DBF	D0,.l
	LEA	$d0(A0),A0
	DBF	D1,.k
	MOVEM.L	(A7)+,D0-D1/A0-A1
	RTS

; copper back to the plain list
pt_Vu8Unhook:
	TST.B	vu8_Cop
	BEQ.S	.r
	MOVEM.L	A0-A1,-(A7)
	SF	vu8_Cop
	LEA	vu8_CopOrg,A0
	LEA	dat_14AB,A1
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	MOVEM.L	(A7)+,A0-A1
.r:	RTS

; z=1: spr 4-7 show the vu (sampler: range and play bar sprites)
pt_Vu8Own:
	TST.W	dat_SamplerActive
	BNE.S	.r
	CMPI.L	#chip_PanelBitplane1,dat_BplPtr1
.r:	RTS

; hook: end of pt_CheckDiskOpCont, instead of JSR pt_UpdatePaletteCopper
pt_Vu8CopHook41:
	JSR	pt_UpdatePaletteCopper
	TST.B	vu8_On
	BEQ.S	.r
	BSR.S	pt_Vu8Own
	BNE.S	.r
	BSR.W	pt_Vu8CopBuild
.r:	RTS

;--- copper multiplex: spr 4-7 repeated on tracks 5-8
; chip_VuMux row = 96 bytes: 28 vu colors, 4x pos restore, wait, per
; spr (datb, data, pos); jump in at dat_14AB, back to dat_14AC
VU8_X1		EQU	40		; spr 4 d0, tracks 1-4 36 apart
VU8_DX		EQU	72		; 2nd bar: pos byte offset
VU8_ROW		EQU	96

pt_Vu8CopBuild:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	LEA	dat_14AB,A0
	LEA	chip_VuMux,A1
	MOVE.W	dat_0FDB,D6
	SUB.W	#125,D6
	ASR.W	#1,D6			; scroll x in cck
	MOVE.W	(A0),D5
	SUB.W	#$100,D5		; line of row 0
	MOVEQ	#0,D7
.row:	TST.W	D7
	BNE.S	.g
	MOVEQ	#7-1,D0
.f:	MOVE.L	#$01fe0000,(A1)+
	DBF	D0,.f
	BRA.S	.o
.g:	MOVEQ	#7-1,D0
.c:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.c
.o:	LEA	.t(PC),A2
	MOVEQ	#34-1,D0
.t1:	MOVE.W	(A2)+,(A1)+
	DBF	D0,.t1
	LEA	-52(A1),A2		; patch the wait
	MOVE.W	.hp(PC),D1
	ADD.W	D6,D1
	MOVE.W	D5,D2
	AND.W	#$ff00,D2
	OR.W	D2,D1
	OR.W	#1,D1
	MOVE.W	D1,(A2)
	ADD.W	#$100,D5
	ADDQ.W	#1,D7
	CMP.W	#48,D7
	BNE.W	.row
	MOVEQ	#7-1,D0
.l:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.l
	MOVE.L	#$00840000,(A1)+
	MOVE.L	#$00860000,(A1)+
	MOVE.L	#$008a0000,(A1)+
	MOVE.L	#dat_14AC,D0
	MOVE.W	D0,-6(A1)		; cop2lcl
	SWAP	D0
	MOVE.W	D0,-10(A1)		; cop2lch
	LEA	dat_14AB,A0
	LEA	vu8_CopOrg,A1
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	LEA	dat_14AB,A0
	MOVE.L	#$00840000,(A0)+
	MOVE.L	#$00860000,(A0)+
	MOVE.L	#$008a0000,(A0)+
	MOVE.L	#chip_VuMux,D0
	MOVE.W	D0,-6(A0)
	SWAP	D0
	MOVE.W	D0,-10(A0)
	LEA	vu8_Prev,A0
	MOVEQ	#12-1,D0
.iv:	MOVE.W	#$ffff,(A0)+
	DBF	D0,.iv
	ST	vu8_Cop
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS
; row ops template, waits patched by line and hp
.t:	DC.W	$0160,0,$0168,0,$0170,0,$0178,0
	DC.W	$0001,$fffe
	DC.W	$0166,0,$0164,0,$0160,0
	DC.W	$016e,0,$016c,0,$0168,0
	DC.W	$0176,0,$0174,0,$0170,0
	DC.W	$017e,0,$017c,0,$0178,0
; cck of the wait: after the first bar of spr 4
.hp:	DC.W	((VU8_X1+125+8)/2)|1

; state heights (4,A3) -> sprites 4-7, 2nd bar of each via copper
pt_Vu8Draw:
	BSR.W	pt_Vu8Own
	BNE.W	pt_Vu8Unhook		; mux would move the sampler sprites
	TST.B	vu8_Cop
	BNE.S	.cp
	BSR.W	pt_Vu8CopBuild
.cp:	ST	vu8_On
	MOVE.L	A6,-(A7)
	LEA	.x(PC),A4
	LEA	chip_PanelBitplane1,A5
	LEA	dat_ScopeCh1,A3
	LEA	vu8_Bar2,A2
	LEA	chip_VuMux+50,A1
	LEA	chip_VuMux+30,A6
	MOVEQ	#4-1,D7
.k:	MOVE.W	(A4)+,D0
	TST.B	dat_CursorPhase
	BNE.S	.v
	MOVEQ	#-64,D0
.v:	BSR.S	pt_Vu8Spr
	LEA	$d0(A5),A5
	LEA	10(A3),A3
	LEA	192(A2),A2
	LEA	12(A1),A1
	ADDQ.L	#4,A6
	DBF	D7,.k
	MOVEA.L	(A7)+,A6
	RTS
.x:	DC.W	VU8_X1,VU8_X1+36,VU8_X1+72,VU8_X1+108

; d0=x a5=spr list a3=state ch k (ch k+4 at 40) a2=2nd bar table d7=3-k
; a1=copper datb of row 0, a6=copper pos restore of row 0
; writes only rows that changed (vu8_Prev: 2 thresholds, pos)
pt_Vu8Spr:
	MOVEM.L	A1-A2/A4/A6,-(A7)
	MOVE.W	#$c6-48,D1
	MOVEQ	#48,D2
	MOVEA.L	A5,A0
	JSR	pt_DrawSprite
	MOVEQ	#0,D3
	MOVEQ	#0,D4
	TST.B	dat_CursorPhase
	BEQ.S	.h
	MOVE.W	(4,A3),D3
	MOVE.W	(44,A3),D4
	CMP.W	#48,D3
	BLS.S	.a
	MOVEQ	#48,D3
.a:	CMP.W	#48,D4
	BLS.S	.h
	MOVEQ	#48,D4
.h:	BSR.W	pt_Vu8Hide
	NEG.W	D3
	ADD.W	#48,D3			; first row with bar
	NEG.W	D4
	ADD.W	#48,D4
	LEA	vu8_Prev,A4
	MOVE.W	D7,D1
	NEG.W	D1
	ADDQ.W	#3,D1
	MULU	#6,D1
	ADDA.W	D1,A4
	MOVE.W	(A5),D5
	MOVE.W	D5,D6
	ADD.B	#VU8_DX,D6
	CMP.W	4(A4),D5
	BEQ.S	.np
	MOVE.W	D5,4(A4)
	MOVEA.L	A1,A0
	MOVEQ	#48-1,D0
.pl:	MOVE.W	D6,8(A0)
	MOVE.W	D5,(A6)
	LEA	VU8_ROW(A0),A0
	LEA	VU8_ROW(A6),A6
	DBF	D0,.pl
.np:	MOVE.W	(A4),D0
	MOVE.W	D3,(A4)
	MOVE.W	D3,D1
	BSR.S	.rng
	LEA	4(A5),A0
	MOVE.W	D0,D2
	LSL.W	#2,D2
	ADDA.W	D2,A0
	BRA.S	.e1
.l1:	MOVEQ	#0,D2
	CMP.W	D3,D0
	BLO.S	.z1
	MOVE.L	#$84007c00,D2
.z1:	MOVE.L	D2,(A0)+
	ADDQ.W	#1,D0
.e1:	CMP.W	D1,D0
	BNE.S	.l1
	MOVE.W	2(A4),D0
	MOVE.W	D4,2(A4)
	MOVE.W	D4,D1
	BSR.S	.rng
	MOVE.W	D0,D2
	LSL.W	#2,D2
	ADDA.W	D2,A2
	MOVE.W	D0,D5
	MULU	#VU8_ROW,D5
	ADDA.L	D5,A1
	BRA.S	.e2
.l2:	MOVEQ	#0,D2
	CMP.W	D4,D0
	BLO.S	.z2
	MOVE.L	#$84007c00,D2
.z2:	MOVE.L	D2,(A2)+
	MOVE.W	D2,(A1)
	SWAP	D2
	MOVE.W	D2,4(A1)
	LEA	VU8_ROW(A1),A1
	ADDQ.W	#1,D0
.e2:	CMP.W	D1,D0
	BNE.S	.l2
	MOVEM.L	(A7)+,A1-A2/A4/A6
	RTS
; d0=old d1=new threshold -> d0=lo d1=hi (old invalid: all rows)
.rng:	CMP.W	#$ffff,D0
	BNE.S	.v
	MOVEQ	#0,D0
	MOVEQ	#48,D1
	RTS
.v:	CMP.W	D1,D0
	BLS.S	.o
	EXG	D0,D1
.o:	RTS

; hidden tracks: no bar (d3 ch k, d4 ch k+4, d7 = 3-k)
pt_Vu8Hide:
	MOVEM.L	D0-D1,-(A7)
	JSR	pt_TrkN41
	MOVEQ	#3,D1
	SUB.W	D7,D1
	CMP.W	D0,D1
	BLO.S	.a
	MOVEQ	#0,D3
.a:	ADDQ.W	#4,D1
	CMP.W	D0,D1
	BLO.S	.r
	MOVEQ	#0,D4
.r:	MOVEM.L	(A7)+,D0-D1
	RTS

;--- scopes: box = 2 ch of 20 px, wide box = 4 ch of 22 px
; from pt_ScopeBase, replaces pt_ScopeTrackPos
pt_Scope8:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	LEA	dat_Channel1,A0
	LEA	vu8_Pos,A2
	MOVEQ	#8-1,D6
	BSR.W	pt_Vu8Track
	LEA	dat_ScopeDisplayBuf,A3
	BRA.W	pt_Scope8Src

; a0=1st ch a2=pos table (20 bytes per ch) d6=ch-1: scope pos per ch
pt_Vu8Track:
	LEA	dat_ScopeSampleTab,A1
	LEA	dat_ScopeDisplayBuf,A3
.ch:	MOVE.W	(A0),D0
	AND.W	#$0fff,D0
	OR.W	(16,A0),D0
	BEQ.S	.idle
	MOVE.W	(16,A0),(16,A2)
	MOVE.B	(19,A0),(18,A2)
	TST.B	(n_pt4_trigger,A0)
	BEQ.S	.run
	SF	(n_pt4_trigger,A0)
	JSR	pt_ScopeSetSample
	MOVEQ	#0,D0
	MOVE.B	(n_pt4_samplenum,A0),D0
	SUBQ.W	#1,D0
	LSL.W	#4,D0
	MOVE.L	(0,A1,D0.W),(A2)
	MOVE.L	(4,A1,D0.W),(4,A2)
	MOVE.L	(8,A1,D0.W),(8,A2)
	MOVE.L	(12,A1,D0.W),(12,A2)
	MOVE.L	(A2),D0
	CMP.L	A3,D0
	BEQ.S	.nx
	BRA.S	.chk
.run:	MOVE.L	(A2),D0
	CMP.L	A3,D0
	BEQ.S	.nx
	MOVEQ	#0,D1
	MOVE.W	(16,A2),D1
	LSR.W	#1,D1
	BEQ.S	.nx
	JSR	pt_ScopeStep41
	ADD.L	D2,D0
.chk:	CMP.L	(4,A2),D0
	BCS.S	.st
	TST.L	(8,A2)
	BNE.S	.wrap
.idle:	MOVE.L	A3,D0
	BRA.S	.st
.wrap:	MOVEQ	#64,D1			; bounded: stale pos must not spin
.w:	SUB.L	(4,A2),D0
	ADD.L	(8,A2),D0
	MOVE.L	(12,A2),(4,A2)
	CMP.L	(4,A2),D0
	BCS.S	.st
	SUBQ.W	#1,D1
	BNE.S	.w
	BRA.S	.idle
.st:	MOVE.L	D0,(A2)
.nx:	LEA	20(A2),A2
	LEA	n_SIZEOF(A0),A0
	DBF	D6,.ch
	RTS

;--- src ptr and scale per ch
pt_Scope8Src:
	LEA	vu8_Pos,A2
	LEA	vu8_Src,A4
	LEA	dat_ScopeCh1,A5
	MOVEQ	#8-1,D6
.s:	MOVE.L	A3,D1
	MOVEQ	#0,D5
	TST.W	(A5)
	BEQ.S	.f
	MOVE.L	(A2),D0
	CMP.L	A3,D0
	BEQ.S	.f
	MOVE.L	D0,D1
	MOVE.B	(18,A2),D5
	MULS.W	dat_RpMasterVol,D5
	ADD.L	#$20,D5
	LSR.L	#6,D5
	LSR.W	#1,D5
	CMP.W	#$20,D5
	BLS.S	.f
	MOVEQ	#32,D5
.f:	MOVE.L	D1,(A4)+
	MOVE.W	D5,(A4)+
	ADDQ.L	#2,A4
	LEA	20(A2),A2
	LEA	10(A5),A5
	DBF	D6,.s
	TST.W	dat_SamplerActive
	BEQ.S	.dr
	LEA	vu8_Pos,A2
	MOVEQ	#8,D5
	BSR.W	pt_Vu8SmpBar
;--- draw
.dr:	TST.B	dat_ScopeBufferRef
	BEQ.W	.out
	ADDQ.B	#1,vu8_Frame		; irq load: plot at half rate
	BTST	#0,vu8_Frame
	BNE.W	.out
	MOVE.W	dat_UIMode,D0
	CMP.W	#1,D0
	BEQ.S	.main
	CMP.W	#9,D0
	BEQ.S	.main
	CMPI.B	#2,dat_CursorPhase
	BNE.W	.out
	BRA.W	.pk
.main:	BSR.W	pt_StageLogo41		; rtg stage on screen: logo here
	BNE.W	.pk
	JSR	pt_0114			; backdrop on mode change
	MOVE.B	dat_ScopeMode,D0
	BNE.S	.m1
	BSR.W	pt_Vu8ClrAll
	BRA.W	.pk
.m1:	BSR.W	pt_Vu8Steg
	LEA	pt_Vu8Dot,A6
	CMP.B	#2,D0
	BEQ.S	.stk
	CMP.B	#5,D0
	BEQ.S	.stk
	CMP.B	#3,D0
	BNE.S	.sty
	LEA	pt_Vu8Conn,A6
	BRA.S	.sty
.stk:	LEA	pt_Vu8Stick,A6
.sty:	MOVEA.L	dat_ScreenBuf2Ptr,A4
	CMP.B	#4,D0
	BCC.S	.wide
	MOVEQ	#0,D7
.nb:	MOVE.W	D7,D0
	BSR.W	pt_Vu8ClrBox
	MOVE.W	D7,D0
	MULU	#6,D0
	LEA	$709(A4),A1
	ADDA.W	D0,A1
	MOVEQ	#3,D5
	MOVEA.W	D5,A2			; stride
	MOVE.W	D7,D0
	ADD.W	D0,D0
	MOVEQ	#0,D1
	MOVEQ	#16,D2
	BSR.W	pt_Vu8Seg
	ADDQ.W	#1,D0
	MOVEQ	#24,D1
	BSR.W	pt_Vu8Seg
	ADDQ.W	#1,D7
	CMP.W	#4,D7
	BNE.S	.nb
	BRA.W	.out
.wide:	MOVEQ	#0,D7
.wb:	MOVE.W	D7,D0
	MULU	#12,D0
	MOVEA.L	A4,A0
	ADDA.W	D0,A0
	ADDA.W	#$209,A0
	MOVEQ	#11-1,D0
	BSR.W	pt_Vu8Clr
	MOVE.W	D7,D0
	MULU	#12,D0
	LEA	$709(A4),A1
	ADDA.W	D0,A1
	MOVEQ	#5,D5
	MOVEA.W	D5,A2
	MOVE.W	D7,D0
	LSL.W	#2,D0
	MOVEQ	#0,D1
	MOVEQ	#4-1,D6
.wg:	MOVEQ	#16,D2
	BSR.W	pt_Vu8Seg
	ADDQ.W	#1,D0
	ADD.W	#24,D1
	DBF	D6,.wg
	ADDQ.W	#1,D7
	CMP.W	#2,D7
	BNE.S	.wb
	BRA.W	.out
.pk:	CMPI.B	#2,dat_CursorPhase
	BNE.W	.out
	LEA	vu8_Src,A4
	LEA	dat_ScopeCh1+6,A5
	MOVEQ	#8-1,D6
.pc:	MOVEA.L	(A4),A0
	MOVEQ	#0,D7
	MOVEQ	#40-1,D2
.pl:	MOVE.B	(A0)+,D0
	EXT.W	D0
	BPL.S	.pp
	NEG.W	D0
.pp:	CMP.W	D0,D7
	BGE.S	.pn
	MOVE.W	D0,D7
.pn:	DBF	D2,.pl
	MOVE.W	D7,(A5)
	ADDQ.L	#8,A4
	LEA	10(A5),A5
	DBF	D6,.pc
.out:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; sampler, wide module on the card: play bar over all its channels
pt_WideSmpBar41:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.L	agus_Mem,D0
	BEQ.S	.r
	ADD.L	#AGM_CHAN,D0
	MOVEA.L	D0,A0
	LEA	wsb_Pos,A2
	MOVE.W	wide_Ch,D6
	SUBQ.W	#1,D6
	BMI.S	.r
	BSR.W	pt_Vu8Track
	LEA	wsb_Pos,A2
	MOVE.W	wide_Ch,D5
	BSR.S	pt_Vu8SmpBar
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; sampler: play bar of one ch inside the shown part, last one first
; a2=pos table d5=ch count (8 ch: mute flags of the scopes)
pt_Vu8SmpBar:
	MOVEM.L	D0-D4/A0,-(A7)
	MOVE.L	dat_DiskBufLen,D3
	BEQ.S	.off
	MOVEQ	#0,D4
	MOVE.B	vu8_BarCh,D4
	BSR.S	.in
	BCS.S	.on
	MOVEQ	#0,D4
.l:	BSR.S	.in
	BCS.S	.on
	ADDQ.W	#1,D4
	CMP.W	D5,D4
	BCS.S	.l
.off:	MOVEQ	#0,D0
	MOVE.W	#$010e,D1
	BRA.S	.spr
.on:	MOVE.B	D4,vu8_BarCh
.sh:	CMP.L	#$ffff,D3		; mulu/divu: 16 bit len
	BLS.S	.x
	LSR.L	#1,D3
	LSR.L	#1,D1
	BRA.S	.sh
.x:	MULU.W	#$013a,D1
	DIVU.W	D3,D1
	MOVEQ	#0,D0
	MOVE.W	D1,D0
	ADDQ.W	#6,D0
	MOVE.W	#$008b,D1
.spr:	MOVEQ	#64,D2
	LEA	chip_BorderRight,A0
	JSR	pt_DrawSprite
	MOVEM.L	(A7)+,D0-D4/A0
	RTS
; d4=ch -> c=1 and d1=ofs if it plays inside the shown part
.in:	CMP.W	D5,D4
	BCC.S	.no
	MOVE.W	D4,D0
	MULU	#10,D0
	CMP.W	#8,D5
	BNE.S	.nm
	LEA	dat_ScopeCh1,A0
	TST.W	(A0,D0.W)		; muted
	BEQ.S	.no
.nm:	ADD.W	D0,D0
	MOVE.L	(A2,D0.W),D1
	MOVE.L	dat_ScopeDisplay1,D0
	CMP.L	D0,D1
	BLS.S	.no
	CMP.L	dat_ScopeDisplay2,D1
	BCC.S	.no
	SUB.L	D0,D1
	ORI.B	#1,CCR
	RTS
.no:	ANDI.B	#$fe,CCR
	RTS

; d0=ch d1=x d2=n a1=box centre a2=stride a6=style
pt_Vu8Seg:
	MOVEM.L	D0-D1,-(A7)
	MOVE.W	D0,D1
	JSR	pt_TrkN41
	CMP.W	D0,D1
	BCS.S	.sh1
	MOVEM.L	(A7)+,D0-D1
	RTS
.sh1:	MOVEM.L	(A7)+,D0-D1
	MOVEM.L	D0-D7/A0-A5,-(A7)
	MOVE.W	D0,D3
	LSL.W	#3,D3
	LEA	vu8_Src,A4
	ADDA.W	D3,A4
	MOVEA.L	(A4),A0
	MOVE.W	4(A4),D5
	MOVE.W	D1,D4
	MOVE.W	D2,D6
	SUBQ.W	#1,D6
	MOVEQ	#0,D7
	MOVEA.W	#$7fff,A5		; no prev row yet
.px:	MOVE.B	(A0),D0
	ADDA.W	A2,A0
	EXT.W	D0
	MOVE.W	D0,D1
	BPL.S	.p
	NEG.W	D1
.p:	CMP.W	D1,D7
	BGE.S	.m
	MOVE.W	D1,D7
.m:	NEG.W	D0
	MULS.W	D5,D0
	ASR.W	#8,D0
	MOVE.W	D0,D1
	ASL.W	#6,D0
	ASL.W	#4,D1
	ADD.W	D1,D0			; rows * 80
	MOVE.W	D4,D2
	MOVE.W	D4,D3
	LSR.W	#3,D2
	NOT.W	D3			; bset takes bit mod 8
	LEA	(A1,D2.W),A3
	JSR	(A6)
	ADDQ.W	#1,D4
	DBF	D6,.px
	MOVE.W	2(A7),D0		; saved d0 = ch
	MULU	#10,D0
	LEA	dat_ScopeCh1+6,A4
	MOVE.W	D7,(A4,D0.W)
	MOVEM.L	(A7)+,D0-D7/A0-A5
	RTS

pt_Vu8Dot:
	BSET	D3,(0,A3,D0.W)
	RTS

pt_Vu8Stick:
	MOVEQ	#40,D2
.l:	BSET	D3,(0,A3,D0.W)
	TST.W	D0
	BEQ.S	.r
	BMI.S	.a
	SUB.W	#80,D0
	DBF	D2,.l
	RTS
.a:	ADD.W	#80,D0
	DBF	D2,.l
.r:	RTS

; d2 bounds the walk: runs in the vbl irq, 8ch x 16 px must stay cheap
pt_Vu8Conn:
	MOVE.W	D0,D1
	CMPA.W	#$7fff,A5
	BNE.S	.s
	MOVEA.W	D0,A5
.s:	MOVEQ	#12,D2
.l:	BSET	D3,(0,A3,D0.W)
	CMP.W	A5,D0
	BEQ.S	.r
	BMI.S	.a
	SUB.W	#80,D0
	DBF	D2,.l
	BRA.S	.r
.a:	ADD.W	#80,D0
	DBF	D2,.l
.r:	MOVEA.W	D1,A5
	RTS

; bar bytes between the plot halves = copy of the gap between two boxes
pt_Vu8Steg:
	MOVEM.L	D0-D3/A0-A3,-(A7)
	MOVEQ	#46,D0
	LEA	.n(PC),A3
	CMPI.B	#4,dat_ScopeMode
	BCS.S	.s
	MOVEQ	#52,D0
	LEA	.w(PC),A3
.s:	LEA	SECSTRT_2+5*80,A0
	MOVEQ	#2-1,D2
.p:	MOVEQ	#35-1,D1
.r:	MOVEA.L	A3,A1
	LEA	(A0,D0.W),A2
.b:	MOVEQ	#0,D3
	MOVE.B	(A1)+,D3
	BMI.S	.nx
	MOVE.B	(A2),(A0,D3.W)
	BRA.S	.b
.nx:	LEA	80(A0),A0
	DBF	D1,.r
	LEA	chip_ScreenBitplanes+5*80,A0
	DBF	D2,.p
	MOVEM.L	(A7)+,D0-D3/A0-A3
	RTS
.n:	DC.B	43,49,55,61,-1
.w:	DC.B	43,46,49,55,58,61,-1
	EVEN

pt_Vu8ClrAll:
	MOVEM.L	D0-D3/A0-A1,-(A7)
	MOVEQ	#3,D3
.b:	MOVE.W	D3,D0
	BSR.S	pt_Vu8ClrBox
	DBF	D3,.b
	MOVEM.L	(A7)+,D0-D3/A0-A1
	RTS

; d0=box 0-3
pt_Vu8ClrBox:
	MULU	#6,D0
	MOVEA.L	dat_ScreenBuf2Ptr,A0
	ADDA.W	D0,A0
	ADDA.W	#$209,A0
	MOVEQ	#6-1,D0

; a0=top left byte, d0=width-1, 33 rows
pt_Vu8Clr:
	MOVEQ	#33-1,D1
.r:	MOVE.W	D0,D2
	MOVEA.L	A0,A1
.b:	CLR.B	(A1)+
	DBF	D2,.b
	LEA	80(A0),A0
	DBF	D1,.r
	RTS

;--- panel box with the rtg stage on screen (wide window): logo, z=0
pt_StageLogo41:
	TST.B	rtg_Wide
	BEQ.S	.n
	TST.L	rwd_Mem
	BEQ.S	.n
	TST.B	rwd_On
	BEQ.S	.n
	CMPI.B	#$fe,dat_0658
	BEQ.S	.y
	MOVE.B	#$fe,dat_0658		; no mode: pt_0114 draws the user's again
	MOVEM.L	D0-D1/A0-A1,-(A7)
	BSR.W	pt_Vu8ClrAll		; traces off plane 2
	BSR.S	pt_WideLogo41
	MOVEM.L	(A7)+,D0-D1/A0-A1
.y:	ANDI	#$fb,CCR
	RTS
.n:	ORI	#4,CCR
	RTS

pt_WideLogo41:
	MOVEM.L	D0/A0,-(A7)
	MOVEA.L	#dat_CreditsLogo41,A0
	JMP	pt_ScopeBackdrop41	; pops d0/a0

;--- wide module, panel box: logo with the stage, else a level bar per
; channel in the scope boxes (plane 2, scope colour)
pt_WideScope41:
	TST.B	dat_ScopeBufferRef
	BEQ.W	.r
	MOVEM.L	D0-D7/A0-A3,-(A7)
	ST	wsc_Busy
	BSR.W	pt_StageLogo41
	BEQ.S	.nat
	MOVE.B	#1,wsc_State
	BRA.S	.x
.nat:	MOVEQ	#3,D0			; mode 0: scopes off, pt's logo
	TST.B	dat_ScopeMode
	BEQ.S	.k
	MOVEQ	#2,D0			; levels: one block
.k:	MOVE.B	wide_Ch+1,D1
	CMP.B	wsc_State,D0
	BNE.S	.nk
	CMP.B	wsc_Ch,D1
	BEQ.S	.go
.nk:	MOVE.B	D0,wsc_State
	MOVE.B	D1,wsc_Ch
	ST	dat_0658		; backdrop and bars again
.go:	MOVE.B	dat_ScopeMode,D1
	CMP.B	dat_0658,D1
	BEQ.S	.b
	TST.L	dat_AllocBufPtr		; task unpacks a backdrop: next frame
	BNE.W	.x
	BSR.W	pt_Vu8ClrAll
	BSR.W	pt_WscGeom41
	JSR	pt_0114
.b:	CMP.B	#3,D0
	BEQ.S	.x
	TST.L	dat_AllocBufPtr
	BNE.S	.x
	BSR.S	pt_WscBlk41
	BSR.W	pt_WscBars41
.x:	SF	wsc_Busy
	MOVEM.L	(A7)+,D0-D7/A0-A3
.r:	RTS

; replayer tick (card): changed bars right away, the scope irq only
; lays the box out; not while it draws
pt_WscTick41:
	CMPI.B	#2,wsc_State
	BNE.S	.r
	TST.B	wsc_Busy
	BNE.S	.r
	TST.B	dat_ScopeBufferRef
	BEQ.S	.r
	CMPI.W	#1,dat_UIMode
	BEQ.S	.m
	CMPI.W	#9,dat_UIMode
	BNE.S	.r
.m:	TST.L	dat_AllocBufPtr
	BNE.S	.r
	MOVEM.L	D0-D7/A0-A3,-(A7)
	MOVE.B	dat_ScopeMode,D0
	CMP.B	dat_0658,D0		; box laid out
	BNE.S	.x
	BSR.W	pt_WscBars41
.x:	MOVEM.L	(A7)+,D0-D7/A0-A3
.r:	RTS

; box backdrop -> one block: the gaps between the boxes go (planes 0,
; 1; the backdrop may come from the task, so checked every frame)
pt_WscBlk41:
	LEA	SECSTRT_2+20*80+46,A0
	LEA	chip_ScreenBitplanes+20*80+46,A1
	MOVE.B	(A0),D1
	OR.B	(A1),D1
	OR.B	6(A0),D1		; two boxes: the gap in the middle
	OR.B	6(A1),D1
	BEQ.S	.r
	LEA	-15*80(A0),A0		; top edge
	LEA	-15*80(A1),A1
	MOVEQ	#3-1,D1
.g:	MOVEM.L	A0-A1,-(A7)
	ST	(A0)
	ST	(A1)
	MOVEQ	#33-1,D2
.l:	LEA	80(A0),A0
	LEA	80(A1),A1
	CLR.B	(A0)
	CLR.B	(A1)
	DBF	D2,.l
	ST	80(A0)			; bottom edge: light
	CLR.B	80(A1)
	MOVEM.L	(A7)+,A0-A1
	ADDQ.L	#6,A0
	ADDQ.L	#6,A1
	DBF	D1,.g
.r:	RTS

; help title rows 0-11 have no plane 2: scope traces there go
pt_HelpTop41:
	MOVEM.L	D0/A0,-(A7)
	MOVEA.L	dat_ScreenBuf2Ptr,A0
	MOVE.W	#12*80/4-1,D0
.c:	CLR.L	(A0)+
	DBF	D0,.c
	MOVEM.L	(A7)+,D0/A0
	RTS

; another page takes the screen (help, about): the bars go now, the
; page clears only below them; laid out again on return
pt_WscOff41:
	CMPI.B	#2,wsc_State
	BNE.S	.r
	MOVEM.L	D0-D7/A0-A3,-(A7)
	MOVEA.L	dat_ScreenBuf2Ptr,A2
	LEA	6*80+40(A2),A2
	LEA	wsc_Prv,A1
	MOVEQ	#0,D7
	BRA.S	.e
.c:	MOVEQ	#0,D3
	MOVE.B	(A1,D7.W),D3
	BEQ.S	.n
	CLR.B	(A1,D7.W)
	MOVEQ	#0,D2
	BSR.W	pt_WscBar41
.n:	ADDQ.W	#1,D7
.e:	MOVEQ	#0,D0
	MOVE.B	wsc_Ch,D0
	CMP.W	D0,D7
	BLO.S	.c
	SF	wsc_State
	MOVEM.L	(A7)+,D0-D7/A0-A3
.r:	RTS

pt_WideScopeEnd41:
	SF	wsc_State
	BSR.W	pt_Vu8ClrAll
	ST	dat_0658
	RTS

; bar geometry: one block x 328-511, none drawn
pt_WscGeom41:
	MOVEM.L	D0-D2/A0,-(A7)
	LEA	wsc_Prv,A0
	MOVEQ	#32-1,D1
.c:	CLR.B	(A0)+
	DBF	D1,.c
	MOVEQ	#1,D1			; boxes
	MOVE.W	#184,D2			; px a box
	CLR.W	wsc_BP
	MOVEQ	#0,D0
	MOVE.W	wide_Ch,D0
	ADD.W	D1,D0
	SUBQ.W	#1,D0
	DIVU	D1,D0			; channels a box
	TST.W	D0
	BNE.S	.p
	MOVEQ	#1,D0
.p:	MOVE.W	D0,wsc_N
	MOVEQ	#0,D1
	MOVE.W	D2,D1
	DIVU	D0,D1			; pitch
	MOVE.W	D1,wsc_P
	MULU	D1,D0
	SUB.W	D0,D2
	LSR.W	#1,D2
	MOVE.W	D2,wsc_Pad
	MOVEM.L	(A7)+,D0-D2/A0
	RTS

; changed bars only (heights 0..33 from trk_Lev)
pt_WscBars41:
	MOVEA.L	dat_ScreenBuf2Ptr,A2
	LEA	6*80+40(A2),A2		; x 320, first bar row
	LEA	trk_Lev,A3
	LEA	wsc_Prv,A1
	MOVEQ	#0,D7
	BRA.S	.e
.c:	MOVEQ	#0,D2
	TST.B	agus_On
	BEQ.S	.z
	MOVE.B	(A3,D7.W),D2
	MULU	#33,D2
	LSR.W	#6,D2
.z:	MOVEQ	#0,D3
	MOVE.B	(A1,D7.W),D3
	CMP.W	D3,D2
	BEQ.S	.n
	MOVE.B	D2,(A1,D7.W)
	BSR.S	pt_WscBar41
.n:	ADDQ.W	#1,D7
.e:	MOVEQ	#0,D0
	MOVE.B	wsc_Ch,D0		; channels the bars are laid out for
	CMP.W	D0,D7
	BLO.S	.c
	RTS

; bar of ch d7 from height d3 to d2, a2 = box top left
pt_WscBar41:
	MOVEM.L	D0-D7/A0-A1,-(A7)
	MOVEQ	#0,D0
	MOVE.W	D7,D0
	DIVU	wsc_N,D0		; box, slot in the high word
	MOVE.W	D0,D1
	MULU	wsc_BP,D1
	SWAP	D0
	MULU	wsc_P,D0
	ADD.W	D0,D1
	ADD.W	wsc_Pad,D1
	ADDQ.W	#8,D1			; first px from x 320
	MOVE.W	D1,D4
	ADD.W	wsc_P,D4
	SUBQ.W	#2,D4			; last px, 1 px gap
	MOVE.W	D1,D0
	AND.W	#7,D0
	MOVEQ	#-1,D5
	LSR.B	D0,D5			; first byte mask
	MOVE.W	D4,D0
	AND.W	#7,D0
	EOR.W	#7,D0
	MOVEQ	#-1,D6
	LSL.B	D0,D6			; last byte mask
	LSR.W	#3,D1
	LSR.W	#3,D4
	MOVEQ	#33,D0
	MOVE.W	D2,D7
	SUB.W	D3,D7
	BPL.S	.up
	NEG.W	D7
	SUB.W	D3,D0			; fall: rows 33-old .. 32-new off
	MOVEQ	#0,D3
	BRA.S	.ro
.up:	SUB.W	D2,D0			; rise: rows 33-new .. 32-old on
	MOVEQ	#-1,D3
.ro:	MULU	#80,D0
	LEA	(A2,D0.W),A0
	ADDA.W	D1,A0
	SUB.W	D1,D4			; bytes after the first
	SUBQ.W	#1,D7
.y:	MOVEA.L	A0,A1
	MOVE.B	D5,D0
	TST.W	D4
	BNE.S	.f
	AND.B	D6,D0			; bar inside one byte
.f:	BSR.S	.px
	MOVE.W	D4,D1
	SUBQ.W	#2,D1
	BMI.S	.l
.m:	MOVE.B	D3,(A1)+		; full bytes
	DBF	D1,.m
.l:	TST.W	D4
	BEQ.S	.nr
	MOVE.B	D6,D0
	BSR.S	.px
.nr:	LEA	80(A0),A0
	DBF	D7,.y
	MOVEM.L	(A7)+,D0-D7/A0-A1
	RTS
.px:	TST.B	D3
	BEQ.S	.pc
	OR.B	D0,(A1)+
	RTS
.pc:	NOT.B	D0
	AND.B	D0,(A1)+
	RTS
