; setup: pages SETUP / SYSTEM, sound, graphics, prefs
; tabs top right; gad rects set_GadPage1/2, text pos SV_* (generated)
; text pos with bit 15 = page 2; guards draw only on the visible page

	INCLUDE	"src/ui/setup41_layout.i"

SET_MQMAX	EQU	40		; AHI mode name kept for the marquee

;--- pages
; replaces pt_0621: unpack block 11 / swap back, then paint page
pt_SetLoadPage:
	MOVE.L	dat_OldSamplePtr,-(A7)	; <>0: swap back (leave setup, page change)
	LEA	dat_1460,A0
	JSR	pt_StoreModulePtr
	TST.L	(A7)+
	BNE.S	.r
	TST.L	dat_OldSamplePtr	; block 11 shown?
	BEQ.S	.r
	BSR.S	pt_SetApplyPage
.r:	RTS

; paint page onto gfx (planes from SECSTRT_2, step $5000, 121x80)
; hdr word 0 = xor delta to block 11, 1 = full; per plane byterun1
pt_SetApplyPage:
	MOVEM.L	D0-D3/A0-A2,-(A7)
	LEA	dat_SetupPage1,A1
	TST.B	set_Page
	BEQ.S	.p
	LEA	dat_SetupPage2,A1
.p:	MOVE.W	(A1)+,D3
	LEA	SECSTRT_2,A0
	BSR.S	.plane
	LEA	SECSTRT_2+$5000,A0
	BSR.S	.plane
	MOVEM.L	(A7)+,D0-D3/A0-A2
	RTS
.plane:	LEA	9680(A0),A2
.tok:	CMPA.L	A2,A0
	BCC.S	.done
	MOVEQ	#0,D0
	MOVE.B	(A1)+,D0
	BMI.S	.run
.lit:	MOVE.B	(A1)+,D1		; d0+1 literals
	BSR.S	.put
	DBF	D0,.lit
	BRA.S	.tok
.run:	NEG.B	D0			; run: (257-n) x same byte -> dbf cnt 256-n
	MOVE.B	(A1)+,D1
.rl:	BSR.S	.put
	DBF	D0,.rl
	BRA.S	.tok
.done:	RTS
.put:	TST.W	D3
	BEQ.S	.x
	MOVE.B	D1,(A0)+
	RTS
.x:	EOR.B	D1,(A0)+
	RTS

; a0 = gad table of page (replaces LEA dat_1431,A0)
pt_SetGadTab:
	LEA	set_GadPage1,A0
	TST.B	set_Page
	BEQ.S	.r
	LEA	set_GadPage2,A0
.r:	RTS

; replaces TST.W D2 / BNE.S pt_0624 / RTS; new gad ids from $a0
pt_SetDispatch:
	TST.W	D2
	BEQ.S	.r
	CMP.W	#SG_TAB_SETUP,D2
	BCC.S	.new
	JMP	pt_0624
.new:	CMP.W	#SG_TAB_SYSTEM,D2
	BLS.S	pt_SetTab
	JMP	pt_SetNewGadget		; sound / graphics gads
.r:	RTS

; page tabs: d2=gad id
pt_SetTab:
	SUB.W	#SG_TAB_SETUP,D2
	CMP.B	set_Page,D2
	BEQ.S	.r
	MOVE.W	D2,-(A7)
	JSR	pt_WaitMouseRelease
	JSR	pt_0621			; swap old page gfx back
	MOVE.W	(A7)+,D2
	MOVE.B	D2,set_Page
	JSR	pt_InitAudioDisplay	; clear value plane (bitplane 2)
	JSR	pt_0621
	JMP	pt_UIUpdatePaletteMode	; redraw by page
.r:	RTS

;--- guards
; Z=1 if page SETUP visible (replaces CMPI.W #5,dat_UIMode + NOP)
pt_SetIsP1:
	CMPI.W	#5,dat_UIMode
	BNE.S	.r
	TST.B	set_Page
.r:	RTS

; replaces CMPI.W #5,dat_UIMode in pt_UIUpdatePaletteMode: Z=0
pt_SetRedrawSel:
	CMPI.W	#5,dat_UIMode
	BNE.S	.r
	TST.B	set_Page
	BEQ.S	.p1
	BSR.W	pt_SysRedraw
	MOVE.W	#0,CCR
.r:	RTS
.p1:	BSR.W	pt_SetDrawP1		; sound block values, then beta 2 (pt_0620)
	MOVE.W	#4,CCR
	RTS

; page SETUP values: sound block + status line
pt_SetDrawP1:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	BSR.W	pt_SndDraw
	BSR.W	pt_NoteDraw
	BSR.W	pt_MidiDraw
	BSR.W	pt_SetStatus
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; Z=1 if value with page mark in d6 (bit 15 = page 2) may draw now
pt_SetOkD6:
	CMPI.W	#5,dat_UIMode
	BNE.S	.yes			; outside setup as original (option pages share it)
	TST.W	D6
	BMI.S	.p2
	TST.B	set_Page
	RTS
.p2:	CMPI.B	#1,set_Page
	RTS
.yes:	CMP.W	D0,D0
	RTS

; Z=1 if page d7 (0/1) may draw now
pt_SetOkPage:
	CMPI.W	#5,dat_UIMode
	BNE.S	.yes
	CMP.B	set_Page,D7
	RTS
.yes:	CMP.W	D0,D0
	RTS

; replaces MOVE.W D6,dat_TextBytePos at start of pt_ShowDisplayText
pt_SetGuardText:
	BSR.S	pt_SetOkD6
	BNE.S	.skip
	MOVE.W	D6,dat_TextBytePos
	ANDI.W	#$7fff,dat_TextBytePos
	RTS
.skip:	ADDQ.L	#4,A7			; skip pt_ShowDisplayText
	RTS

; replaces JMP/JSR pt_BlitPatternFull in switch draws (P1/P2 = page)
pt_SetBlitP1:
	MOVE.L	D7,-(A7)
	MOVEQ	#0,D7
	BRA.S	pt_SetBlit
pt_SetBlitP2:
	MOVE.L	D7,-(A7)
	MOVEQ	#1,D7
pt_SetBlit:
	BSR.S	pt_SetOkPage
	MOVEM.L	(A7)+,D7		; movem keeps flags
	BNE.S	.r
	JMP	pt_BlitPatternFull
.r:	RTS

; replaces JMP pt_DrawTextRender (FONT, page 2)
pt_SetTextP2:
	MOVE.L	D7,-(A7)
	MOVEQ	#1,D7
	BSR.S	pt_SetOkPage
	MOVEM.L	(A7)+,D7
	BNE.S	.r
	JMP	pt_DrawTextRender
.r:	RTS

; replaces JMP pt_DrawTextAt in PRINT field (pt_0785): d1=pos with mark
pt_SetTextAtP2:
	MOVE.L	D7,-(A7)
	MOVEQ	#1,D7
	BSR.S	pt_SetOkPage
	MOVEM.L	(A7)+,D7
	BNE.S	.r
	ANDI.W	#$7fff,D1
	JMP	pt_DrawTextAt
.r:	RTS

; replaces JSR pt_DrawTempoStr (XEFF) / JMP pt_FormatDecimal (SPEED)
pt_SetTempoP1:
	BSR.W	pt_SetSkipP1
	BNE.S	.r
	JMP	pt_DrawTempoStr
.r:	RTS
pt_SetDecP1:
	BSR.W	pt_SetSkipP1
	BNE.S	.r
	JMP	pt_FormatDecimal
.r:	RTS

; Z=0 if page-1 content must not draw (setup shown, page SYSTEM)
pt_SetSkipP1:
	CMPI.W	#5,dat_UIMode
	BNE.S	.ok
	TST.B	set_Page
	RTS
.ok:	CMP.W	D0,D0
	RTS

;--- page SYSTEM
; redraw (gfx already shown)
pt_SysRedraw:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	JSR	pt_PalEdCopperClear	; palette display off
	JSR	pt_DrawStatusArea	; hide palette sprite
	JSR	pt_0629			; beta 2 switches (guards pass only page SYSTEM ones)
	JSR	pt_0785
	BSR.W	pt_SysHardware
	BSR.W	pt_GfxDraw
	BSR.W	pt_SchDraw
	BSR.W	pt_SetStatus
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; a0=text d1=pos (bit15=pg 2) d0=width (blank pad); visible pg only
pt_SetPut:
	MOVEM.L	D0-D2/D7/A0-A1,-(A7)
	MOVEQ	#0,D7
	TST.W	D1
	BPL.S	.p
	MOVEQ	#1,D7
.p:	BSR.W	pt_SetOkPage
	BNE.S	.r
	CMPI.W	#5,dat_UIMode
	BNE.S	.r			; setup only
	LEA	set_Line,A1
	MOVE.W	D0,D2
	SUBQ.W	#1,D2
.c:	TST.B	(A0)
	BEQ.S	.sp
	MOVE.B	(A0)+,(A1)+
	BRA.S	.n
.sp:	MOVE.B	#' ',(A1)+
.n:	DBF	D2,.c
.o:	ANDI.W	#$7fff,D1
	LEA	set_Line,A0
	JSR	pt_DrawTextAt
.r:	MOVEM.L	(A7)+,D0-D2/D7/A0-A1
	RTS

; hardware: cpu fpu kick os chip fast ahi rtg mixer
pt_SysHardware:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVEA.L	ABSEXECBASE.W,A6
	MOVE.W	296(A6),D3
	LEA	set_TxtCpu(PC),A0	; "68060" also without 68060.library (pt_CpuIs060)
	JSR	pt_CpuIs060
	BNE.S	.cpuok
	ADDQ.L	#6,A0
	MOVEQ	#3,D2
.cpu:	BTST	D2,D3
	BNE.S	.cpuok
	ADDQ.L	#6,A0
	DBF	D2,.cpu
.cpuok:
	MOVE.W	#SV_CPU_POS,D1
	MOVEQ	#SV_CPU_N,D0
	BSR.W	pt_SetPut
	LEA	set_TxtFpuNone(PC),A0
	BTST	#4,D3
	BEQ.S	.f1
	LEA	set_TxtFpu881(PC),A0
.f1:	BTST	#5,D3
	BEQ.S	.f2
	LEA	set_TxtFpu882(PC),A0
.f2:	BTST	#6,D3
	BEQ.S	.f3
	LEA	set_TxtFpuInt(PC),A0
.f3:	MOVE.W	#SV_FPU_POS,D1
	MOVEQ	#SV_FPU_N,D0
	BSR.W	pt_SetPut
; kick = exec lib_Version.SoftVer
	MOVEQ	#0,D0
	MOVE.W	20(A6),D0
	MOVEQ	#0,D1
	MOVE.W	34(A6),D1
	LEA	set_Num,A0
	BSR.W	pt_SetFmtVer
	LEA	set_Num,A0
	MOVE.W	#SV_KICK_POS,D1
	MOVEQ	#SV_KICK_N,D0
	BSR.W	pt_SetPut
; os = version.library
	LEA	set_VerName(PC),A1
	MOVEQ	#0,D0
	JSR	(-552,A6)
	LEA	set_TxtNA(PC),A0
	TST.L	D0
	BEQ.S	.os
	MOVEA.L	D0,A1
	MOVEQ	#0,D0
	MOVE.W	20(A1),D0
	MOVEQ	#0,D1
	MOVE.W	22(A1),D1
	LEA	set_Num,A0
	BSR.W	pt_SetFmtVer
	JSR	(-414,A6)
	LEA	set_Num,A0
.os:	MOVE.W	#SV_OS_POS,D1
	MOVEQ	#SV_OS_N,D0
	BSR.W	pt_SetPut
; chip/fast: total (exec 39+, MEMF_TOTAL) else free
	MOVE.L	#$00000002,D4
	MOVE.W	#SV_CHIP_POS,D5
	BSR.W	pt_SysMem
	MOVE.L	#$00000004,D4
	MOVE.W	#SV_FAST_POS,D5
	BSR.W	pt_SysMem
; ahi: version of ahi.device if loaded
	LEA	set_AhiName(PC),A1
	LEA	350(A6),A0
	BSR.W	pt_SysFindVer
	LEA	set_TxtNone(PC),A1	; not loaded but present -> "FOUND" not "NONE"
	CMPA.L	A1,A0
	BNE.S	.ahiv
	MOVEM.L	D0-D2/A6,-(A7)
	MOVEA.L	dat_DosLibBase,A6
	MOVE.L	#set_AhiDevPath,D1
	MOVEQ	#-2,D2
	JSR	(-84,A6)
	LEA	set_TxtNone(PC),A0	; Lock trashes a0
	MOVE.L	D0,D1
	BEQ.S	.ahin
	JSR	(-90,A6)
	LEA	set_TxtInst(PC),A0
.ahin:	MOVEM.L	(A7)+,D0-D2/A6
.ahiv:	MOVE.W	#SV_AHI_POS,D1
	MOVEQ	#SV_AHI_N,D0
	BSR.W	pt_SetPut
; rtg: picasso96 or cybergraphx
	LEA	set_TxtNone(PC),A0
	LEA	set_P96Name(PC),A1
	BSR.W	pt_SysHasLib
	BEQ.S	.nop96
	LEA	set_TxtP96(PC),A0
	BRA.S	.rtg
.nop96:	LEA	set_CgxName(PC),A1
	BSR.W	pt_SysHasLib
	BEQ.S	.rtg
	LEA	set_TxtCgx(PC),A0
.rtg:	LEA	set_TxtNone(PC),A1	;41 library but no card mode: NONE
	CMPA.L	A1,A0
	BEQ.S	.rtgp
	MOVE.L	A0,-(A7)
	MOVEA.L	dat_GfxLibBase,A6
	MOVE.L	#512,D0
	JSR	pt_RtgFindMode
	CMP.L	#-1,D0
	BNE.S	.rtgm
	MOVE.L	#480,D0
	JSR	pt_RtgFindMode
	CMP.L	#-1,D0
	BNE.S	.rtgm
	ADDQ.L	#4,A7
	LEA	set_TxtNone(PC),A0
	BRA.S	.rtgp
.rtgm:	MOVEA.L	(A7)+,A0
.rtgp:	MOVE.W	#SV_RTGCARD_POS,D1
	MOVEQ	#SV_RTGCARD_N,D0
	BSR.W	pt_SetPut
; mixer
	LEA	set_TxtNA(PC),A0
	TST.B	mix_Enabled
	BEQ.S	.mx
	LEA	set_TxtReady(PC),A0
	TST.B	mix_Active
	BEQ.S	.mx
	LEA	set_TxtActive(PC),A0
.mx:	MOVE.W	#SV_MIXER_POS,D1
	MOVEQ	#SV_MIXER_N,D0
	BSR.W	pt_SetPut
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; show mem: d4=type d5=pos a6=execbase
pt_SysMem:
	MOVE.L	D4,D1
	CMPI.W	#39,20(A6)
	BCS.S	.free
	ORI.L	#$00080000,D1
.free:	JSR	(-216,A6)
	MOVEQ	#10,D1
	LSR.L	D1,D0
	MOVEQ	#'K',D2
	CMP.L	#10000,D0
	BCS.S	.k
	MOVEQ	#10,D1
	LSR.L	D1,D0
	MOVEQ	#'M',D2
.k:	LEA	set_Num,A0
	BSR.W	pt_SetFmtNum
	MOVE.B	D2,(A0)+
	CLR.B	(A0)
	LEA	set_Num,A0
	MOVE.W	D5,D1
	MOVEQ	#7,D0
	BRA.W	pt_SetPut

; a0=list a1=name -> a0=text ("NONE" or "V.R")
pt_SysFindVer:
	JSR	(-132,A6)
	JSR	(-276,A6)		; FindName
	MOVE.L	D0,D2
	BEQ.S	.none
	MOVEA.L	D2,A1
	MOVEQ	#0,D0
	MOVE.W	20(A1),D0
	MOVEQ	#0,D1
	MOVE.W	22(A1),D1
	JSR	(-138,A6)
	LEA	set_Num2,A0
	BSR.W	pt_SetFmtVer
	LEA	set_Num2,A0
	RTS
.none:	JSR	(-138,A6)
	LEA	set_TxtNone(PC),A0
	RTS

; Z=0 if lib a1 loaded or openable
pt_SysHasLib:
	MOVEM.L	D0-D1/A0-A1,-(A7)
	MOVEQ	#0,D0
	JSR	(-552,A6)
	TST.L	D0
	BEQ.S	.r
	MOVEA.L	D0,A1
	JSR	(-414,A6)
	MOVEQ	#1,D0
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1
	RTS

;--- status lines
; SETUP: last line of sound block; SYSTEM: sound, mixer, screen, hint
pt_SetStatus:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	CMPI.W	#5,dat_UIMode
	BNE.W	.r
	LEA	set_Line2,A1
	BSR.W	pt_SetSndText		; output path in set_Line2
	TST.B	set_Page
	BNE.S	.sys
	LEA	set_Line2,A0
	MOVE.W	#SV_NOW_POS,D1
	MOVEQ	#SV_NOW_N,D0
	BSR.W	pt_SetPut
	BRA.W	.r
.sys:	LEA	set_Line3,A1
	LEA	set_TxtSound(PC),A0
	BSR.W	pt_SetCat
	LEA	set_Line2,A0
	BSR.W	pt_SetCat
	LEA	set_Line3,A0
	MOVE.W	#SV_STAT_SND_POS,D1
	MOVEQ	#SV_STAT_SND_N,D0
	BSR.W	pt_SetPut
	LEA	set_Line3,A1
	LEA	set_TxtMixer(PC),A0
	BSR.W	pt_SetCat
	JSR	pt_SndRateStr41
	TST.B	mix_Enabled
	BEQ.S	.m3
	TST.B	agus_On
	BNE.S	.m3
	TST.B	mix_Active
	BEQ.S	.m3
	LEA	set_TxtMixAct(PC),A0
	BSR.W	pt_SetCat
.m3:
	LEA	set_Line3,A0
	MOVE.W	#SV_STAT_MIX_POS,D1
	MOVEQ	#SV_STAT_MIX_N,D0
	BSR.W	pt_SetPut
	LEA	set_Line3,A1
	LEA	set_TxtScreen(PC),A0
	BSR.W	pt_SetCat
	CMPI.B	#1,rtg_ProcState
	BNE.S	.nat
	TST.B	rtg_WinMode		; window on wb
	BEQ.S	.nwin
	TST.L	rtg_Window
	BEQ.S	.nat
	LEA	set_TxtRtgWin(PC),A0
	BRA.S	.scr
.nwin:	TST.L	rtg_Screen
	BEQ.S	.nat
	LEA	set_TxtRtg(PC),A0
	BSR.W	pt_SetCat
	MOVEQ	#0,D0
	MOVE.W	rtg_ScrH,D0
	LEA	set_Num,A0
	BSR.W	pt_SetFmtNum
	LEA	set_Num,A0
	BRA.S	.scr
.nat:	LEA	set_TxtNative(PC),A0
	BTST	#0,dat_UICheckFlag	; ntsc switch (pt_BtnSetupNtsc)
	BEQ.S	.scr
	LEA	set_TxtNativeN(PC),A0
.scr:	BSR.W	pt_SetCat
	LEA	set_Line3,A0
	MOVE.W	#SV_STAT_GFX_POS,D1
	MOVEQ	#SV_STAT_GFX_N,D0
	BSR.W	pt_SetPut
	BSR.W	pt_SetHint
	MOVE.W	#SV_HINT_POS,D1
	MOVEQ	#SV_HINT_N,D0
	BSR.W	pt_SetPut
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; saved output amigus, card was busy at start: a new try every 2 s,
; at most 10; then a message, output stays paula
pt_AgusRetry:
	TST.B	agus_Retry
	BEQ.W	.r
	TST.B	agus_On			; switched by hand meanwhile
	BNE.W	.off
	CMPI.B	#1,snd_Choice		; output changed by hand (ahi)
	BNE.W	.off
	TST.L	dat_RpPlayMode		; never under running play
	BNE.S	.r
	MOVEM.L	D0-D1/A0-A1,-(A7)
	JSR	pt_StatusTicks
	MOVE.L	agus_RetryAt,D1		; due (or the clock passed midnight)
	SUB.L	D0,D1
	BLE.S	.due
	CMP.L	#200,D1
	BLS.S	.x			; not yet
.due:	ADD.L	#100,D0
	MOVE.L	D0,agus_RetryAt
	JSR	pt_AgusOn
	TST.L	D0
	BNE.S	.fail
	JSR	pt_MixStop		; restart for the card
	SF	agus_Retry
	SF	prf_AgusKeep
	MOVE.B	#3,snd_Choice
	BSR.W	pt_SndRefresh
	BRA.S	.x
.fail:	SUBQ.B	#1,agus_Retry
	BNE.S	.x
	SF	prf_AgusKeep
	LEA	agus_MsgBusy,A0		; given up: say so
	JSR	pt_StatusLater41
.x:	MOVEM.L	(A7)+,D0-D1/A0-A1
.r:	RTS
.off:	SF	agus_Retry
	SF	prf_AgusKeep
	RTS

; output path text -> a1 (0-term), a1 -> the 0
pt_SetSndText:
	CLR.B	(A1)
	TST.B	agus_On
	BEQ.S	.nag
	LEA	set_TxtAgus(PC),A0
	TST.B	zzax_On
	BEQ.S	.ag
	LEA	set_TxtZzax(PC),A0
	BSR.W	pt_SetCat
	LEA	set_TxtCard48(PC),A0
	BRA.W	pt_SetCat
.ag:	BSR.W	pt_SetCat
	LEA	set_TxtCard192(PC),A0
	BRA.W	pt_SetCat
.nag:	TST.B	ahi_Active
	BEQ.S	.paula
	LEA	set_TxtAhi(PC),A0
	BSR.W	pt_SetCat
	MOVE.L	ahi_Real,D0		; rate ahi runs at
	BNE.S	.ar
	MOVEQ	#0,D0
	MOVE.W	ahi_Freq,D0
.ar:	LEA	set_Num,A0
	BSR.W	pt_SetFmtNum
	LEA	set_Num,A0
	BSR.W	pt_SetCat
	LEA	set_TxtHz(PC),A0
	BRA.W	pt_SetCat
.paula:	LEA	set_TxtPaula4(PC),A0
	BTST	#5,dat_ModeFlags	; 4ch mode
	BNE.S	.cat
	LEA	set_TxtPaula8N(PC),A0
	TST.B	mix_Enabled
	BEQ.S	.cat
	LEA	set_TxtPaula8(PC),A0
	BSR.W	pt_SetCat
	MOVEQ	#0,D0
	MOVE.W	mix_Rate,D0
	LEA	set_Num,A0
	BSR.W	pt_SetFmtNum
	LEA	set_Num,A0
	BSR.W	pt_SetCat
	LEA	set_TxtHz(PC),A0
	TST.B	ahi_Failed		; now line has 26 chars: no room for HZ
	BEQ.S	.cat
	ADDQ.L	#3,A0
.cat:	TST.B	ahi_Failed
	BEQ.W	pt_SetCat
	BSR.W	pt_SetCat
	LEA	set_TxtAhiFail(PC),A0
	BRA.W	pt_SetCat

; hint line: a0=text
pt_SetHint:
	MOVEA.L	ABSEXECBASE.W,A0
	BTST	#1,(297,A0)		; 68020 or better
	BNE.S	.020
	JSR	pt_AgusDetect
	LEA	set_HintAgus(PC),A0	; 68000: card needs no mixer
	TST.L	agus_Card
	BNE.S	.r
	JSR	pt_ZzaxDetect
	LEA	set_HintZzax(PC),A0
	TST.L	zzax_Card
	BNE.S	.r
	LEA	set_HintCpu(PC),A0
	RTS
.020:	LEA	set_HintAhiF(PC),A0
	TST.B	ahi_Failed
	BNE.S	.r
	LEA	set_HintRtgF(PC),A0
	CMPI.B	#2,rtg_ProcState
	BEQ.S	.r
	LEA	aut_HintAuto(PC),A0
	MOVE.B	prf_AutoAhi,D0
	OR.B	prf_AutoRtg,D0
	OR.B	prf_AutoAgus,D0
	BNE.S	.r
	LEA	set_HintBuild(PC),A0	; no warning: build stamp
.r:	RTS

; append a0 to a1 (a1 -> end 0)
pt_SetCat:
.l:	MOVE.B	(A0)+,(A1)+
	BNE.S	.l
	SUBQ.L	#1,A1
	RTS

;--- numbers
; d0.l decimal -> (a0)+, 0-term, a0 -> the 0
pt_SetFmtNum:
	MOVEM.L	D0-D3,-(A7)
	MOVEQ	#0,D3
.d:	BSR.S	pt_SetDiv10
	ADD.B	#'0',D1
	MOVE.W	D1,-(A7)
	ADDQ.W	#1,D3
	TST.L	D0
	BNE.S	.d
	SUBQ.W	#1,D3
.o:	MOVE.W	(A7)+,D1
	MOVE.B	D1,(A0)+
	DBF	D3,.o
	CLR.B	(A0)
	MOVEM.L	(A7)+,D0-D3
	RTS

; "d0.d1" -> (a0)
pt_SetFmtVer:
	MOVE.L	D1,-(A7)
	BSR.S	pt_SetFmtNum
	MOVE.B	#'.',(A0)+
	MOVE.L	(A7)+,D0
	BRA.S	pt_SetFmtNum

; d0.l/10 -> d0.l quot, d1.w rem (68000, 32 bit)
pt_SetDiv10:
	MOVE.L	D2,-(A7)
	MOVE.L	D0,D2
	CLR.W	D0
	SWAP	D0
	DIVU	#10,D0
	MOVE.W	D0,D1
	SWAP	D1
	MOVE.W	D2,D0
	DIVU	#10,D0
	MOVE.W	D0,D1
	SWAP	D0
	EXG	D0,D1
	MOVE.L	(A7)+,D2
	RTS

;--- task poll
; from pt_MixTaskPoll: redraw status every 25 passes
pt_SetPoll:
	JSR	pt_MidiTask		; midi notes in the main task
	BSR.W	pt_SetMqPoll
	TST.B	snd_RateHeld		; rate arrow latched: free on button up
	BEQ.S	.held
	LMB
	BEQ.S	.held
	SF	snd_RateHeld
.held:
	TST.B	set_Ready		; first pass -> apply saved color scheme
	BNE.W	.go
	BSR.W	pt_SchStart
	CMPI.B	#4,snd_Choice		; saved output zz9000ax: no retry, the library answers at once
	BNE.S	.nzx
	JSR	pt_ZzaxDetect
	MOVE.B	#1,snd_Choice
	MOVE.B	#4,prf_AgusKeep		; stays in SAVE CONFIG until taken or changed
	LEA	zzax_MsgNone,A0
	TST.L	zzax_Card
	BEQ.S	.zmsg
	JSR	pt_ZzaxOn
	TST.L	D0
	BNE.S	.zbusy
	JSR	pt_MixStop		; mixer may run for paula: restart for the card
	SF	prf_AgusKeep
	MOVE.B	#4,snd_Choice
	BRA.W	.go
.zbusy:	LEA	zzax_MsgBusy,A0
.zmsg:	JSR	pt_StatusLater41
	BRA.W	.go
.nzx:
	CMPI.B	#3,snd_Choice		; saved output amigus
	BNE.S	.go
	JSR	pt_AgusDetect		; card only now (paula: library stays shut)
	MOVE.B	#1,snd_Choice
	ST	prf_AgusKeep		; stays in SAVE CONFIG until taken or changed
	TST.L	agus_Card
	BNE.S	.card
	LEA	agus_MsgNone,A0		; no card: say so once, no retry
	JSR	pt_StatusLater41
	BRA.S	.go
.card:	JSR	pt_AgusOn
	TST.L	D0
	BNE.S	.busy
	JSR	pt_MixStop		; mixer may run for paula: restart for the card
	SF	prf_AgusKeep
	MOVE.B	#3,snd_Choice
	BRA.S	.go
.busy:	MOVE.B	#10,agus_Retry		; card not ready yet (boot, other
	JSR	pt_StatusTicks		; program releasing it): try again
	ADD.L	#100,D0			; every 2 s
	MOVE.L	D0,agus_RetryAt
.go:	ST	set_Ready
	BSR.W	pt_AgusRetry
	BSR.W	pt_AutoMsg
	TST.B	snd_Defer		; pending output switch
	BEQ.S	.nodef
	SUBQ.B	#1,snd_Defer
	BNE.S	.nodef
	BRA.W	pt_SndOutputDo
.nodef:	TST.B	snd_ResDefer		; resume after switch
	BEQ.S	.nores
	SUBQ.B	#1,snd_ResDefer
	BNE.S	.nores
	BSR.W	pt_SndResume
.nores:	CMPI.W	#5,dat_UIMode
	BNE.S	.r
	TST.W	dat_DiskOpFlag		; yes/no dialog open -> no drawing
	BNE.S	.r
	ADDQ.B	#1,set_PollCnt
	CMPI.B	#25,set_PollCnt
	BCS.S	.r
	CLR.B	set_PollCnt
	TST.B	set_Page		; system page: rtg state follows the mirror
	BEQ.S	.st
	BSR.W	pt_GfxPoll
.st:	BRA.W	pt_SetStatus
.r:	RTS

;--- texts
set_TxtCpu:	DC.B	"68060",0,"68040",0,"68030",0,"68020",0,"68010",0,"68000",0
set_TxtFpuNone:	DC.B	"NONE",0
set_TxtFpu881:	DC.B	"68881",0
set_TxtFpu882:	DC.B	"68882",0
set_TxtFpuInt:	DC.B	"INTERN",0
set_TxtNA:	DC.B	"N/A",0
set_TxtNone:	DC.B	"NONE",0
set_TxtInst:	DC.B	"FOUND",0		; full 7 chars: the T hits the frame
set_AhiDevPath:	DC.B	"DEVS:ahi.device",0
set_TxtP96:	DC.B	"P96",0
set_TxtCgx:	DC.B	"CGX",0
set_TxtReady:	DC.B	"READY",0
set_TxtActive:	DC.B	"ACTIVE",0
set_TxtSound:	DC.B	"SOUND:  ",0
set_TxtMixer:	DC.B	"MIXER:  ",0
set_TxtScreen:	DC.B	"SCREEN: ",0
set_TxtAuto:	DC.B	"AUTO ",0
set_TxtHz:	DC.B	" HZ",0
set_TxtMixAct:	DC.B	"  RUNNING",0
set_TxtRtg:	DC.B	"RTG 640X",0
set_TxtNative:	DC.B	"NATIVE PAL",0
set_TxtRtgWin:	DC.B	"RTG WINDOW ON WORKBENCH",0
set_TxtNativeN:	DC.B	"NATIVE NTSC",0
set_TxtAhi:	DC.B	"AHI ",0
set_TxtAgus:	DC.B	"AMIGUS WAVETABLE",0
set_TxtCard192:	DC.B	" 192 KHZ",0
set_TxtZzax:	DC.B	"ZZ9000AX VOICES",0
set_TxtCard48:	DC.B	" 48 KHZ",0
set_TxtPaula4:	DC.B	"PAULA 4CH DIRECT",0
set_TxtPaula8:	DC.B	"PAULA MIX 8CH ",0
set_TxtPaula8N:	DC.B	"PAULA 8CH, NO MIXER",0
set_TxtAhiFail:	DC.B	" NO AHI",0
set_HintCpu:	DC.B	"AHI AND RTG NEED A 68020",0
set_HintAhiF:	DC.B	"AHI COULD NOT OPEN, PAULA IS USED",0
set_HintRtgF:	DC.B	"NO SUITABLE RTG SCREEN MODE",0
set_HintAgus:	DC.B	"AMIGUS SOUND CARD FOUND",0
set_HintZzax:	DC.B	"ZZ9000AX SOUND CARD FOUND",0
set_HintBuild:	DC.B	"BUILD "
	STAMP
	DC.B	0
set_VerName:	DC.B	"version.library",0
set_AhiName:	DC.B	"ahi.device",0
set_P96Name:	DC.B	"Picasso96API.library",0
set_CgxName:	DC.B	"cybergraphics.library",0
	EVEN

;--- new gads
; gad ids from SG_OUTPUT: sound (page SETUP), graphics (page SYSTEM)
pt_SetNewGadget:
	CMP.W	#SG_OUTPUT,D2
	BEQ.W	pt_SndOutput
	CMP.W	#SG_MIXRATE_UP,D2
	BEQ.W	pt_SndRateUp
	CMP.W	#SG_MIXRATE_DOWN,D2
	BEQ.W	pt_SndRateDown
	CMP.W	#SG_AHIMODE,D2
	BEQ.W	pt_SndAhiMode
	CMP.W	#SG_VOLUME_UP,D2
	BEQ.W	pt_SndVolUp
	CMP.W	#SG_VOLUME_DOWN,D2
	BEQ.W	pt_SndVolDown
	CMP.W	#SG_STEREO_UP,D2
	BEQ.W	pt_SndStUp
	CMP.W	#SG_STEREO_DOWN,D2
	BEQ.W	pt_SndStDown
	CMP.W	#SG_DESIGN,D2		; color scheme (also on 68000)
	BEQ.W	pt_SchGadget
	CMP.W	#SG_NOTES,D2		; note range (also on 68000)
	BEQ.W	pt_NoteGadget
	CMP.W	#SG_MIDI_UP,D2		; midi in (also on 68000)
	BEQ.W	pt_MidiUp
	CMP.W	#SG_MIDI_DOWN,D2
	BEQ.W	pt_MidiDn
	CMP.W	#SG_CHANNELS_UP,D2	; track count (also on 68000)
	BEQ.W	pt_ChnUp41
	CMP.W	#SG_CHANNELS_DOWN,D2
	BEQ.W	pt_ChnDn41
	CMP.W	#SG_ONLOAD,D2		; 4ch mods in 8ch mode (also on 68000)
	BEQ.W	pt_LoadModeGadget
	CMP.W	#SG_AHIFLT,D2
	BEQ.W	pt_FltGadget
	JMP	pt_GfxGadget

; ON LOAD: AUTO (4ch module -> 4ch mode) / KEEP (into 8 tracks)
pt_LoadModeGadget:
	JSR	pt_WaitMouseRelease
	NOT.B	prf_LoadKeep
	BSR.W	pt_LoadModeDraw
	LEA	set_MsgAuto(PC),A0
	TST.B	prf_LoadKeep
	BEQ.S	.m
	LEA	set_MsgKeep(PC),A0
.m:	JMP	pt_ShowStatusMsg
pt_LoadModeDraw:
	MOVEM.L	D0-D1/A0,-(A7)
	LEA	set_TxtLAuto(PC),A0
	TST.B	prf_LoadKeep
	BEQ.S	.d
	LEA	set_TxtLKeep(PC),A0
.d:	MOVE.W	#SV_ONLOAD_POS,D1
	MOVEQ	#SV_ONLOAD_N,D0
	BSR.W	pt_SetPut
	MOVEM.L	(A7)+,D0-D1/A0
	RTS
; AHI FLT: off -> a1200 -> a500
pt_FltGadget:
	JSR	pt_WaitMouseRelease
	TST.B	ahi_Active		; only ahi: value stays
	BNE.S	.on
	LEA	flt_MsgNoAhi(PC),A0
	JMP	pt_ShowStatusMsg
.on:	MOVE.B	ahi_FltMode,D0
	ADDQ.B	#1,D0
	CMP.B	#3,D0
	BCS.S	.s
	MOVEQ	#0,D0
.s:	MOVE.B	D0,ahi_FltMode
	JSR	pt_CardFltReset41
	BSR.S	pt_FltDraw
	LEA	flt_Msg(PC),A0
	MOVEQ	#0,D0
	MOVE.B	ahi_FltMode,D0
	MULU	#26,D0
	ADDA.W	D0,A0
	JMP	pt_ShowStatusMsg
pt_FltDraw:
	MOVEM.L	D0-D1/A0,-(A7)
	LEA	flt_Txt(PC),A0
	MOVEQ	#0,D0
	MOVE.B	ahi_FltMode,D0
	MULU	#6,D0
	ADDA.W	D0,A0
	TST.B	ahi_Active
	BNE.S	.fd
	LEA	set_TxtNA(PC),A0	; value kept, no effect now
.fd:	MOVE.W	#SV_AHIFLT_POS,D1
	MOVEQ	#SV_AHIFLT_N,D0
	BSR.W	pt_SetPut
	MOVEM.L	(A7)+,D0-D1/A0
	RTS
flt_Txt:	DC.B	"OFF",0,0,0
	DC.B	"A1200",0
	DC.B	"A500",0,0
flt_Msg:	DC.B	"AHI FILTER: OFF",0
	DS.B	10
	DC.B	"AHI FILTER: LED 3.1 KHZ",0,0,0
	DC.B	"AHI FILTER: RC + LED",0
	DS.B	5
flt_MsgNoAhi:	DC.B	"AHI FILTER: ONLY WITH AHI",0
	EVEN
set_TxtLAuto:	DC.B	"AUTO",0
set_TxtLKeep:	DC.B	"KEEP",0
set_MsgAuto:	DC.B	"4CH MODS: SWITCH TO 4CHN",0
set_MsgKeep:	DC.B	"4CH MODS: LOAD INTO 8CHN",0
	EVEN

;--- sound
; output: paula/ahi at runtime (play stopped, audio.device + ints swapped)
; ahi mode steps through modes (PREFS = default); freq = mix rate;
; volume hits ahi + mixer ring, stereo only ahi

; output gad: stop play, pend switch; pt_SetPoll does it after 0.5 s
; (switch straight from running playback hangs)
pt_SndOutput:
	JSR	pt_AgusDetect		; card offered from here on
	JSR	pt_ZzaxDetect
	MOVEA.L	ABSEXECBASE.W,A6
	BTST	#1,(297,A6)		; ahi needs the mixer
	BNE.S	.cpu
	BSR.W	pt_CardAny41		; 68000: paula <-> card (no mixing)
	BEQ.S	.no20
	JSR	pt_WaitMouseRelease
	MOVEQ	#1,D0
	TST.B	agus_On
	BNE.S	.go
	BSR.W	pt_SndCardNext41	; amigus or zz9000ax, they take turns
	BRA.S	.go
.no20:	LEA	snd_Msg020(PC),A0
	JMP	pt_ShowStatusMsg
.cpu:	JSR	pt_WaitMouseRelease
	MOVEQ	#1,D0			; paula -> ahi -> card (amigus, zz9000ax) -> paula
	TST.B	agus_On
	BNE.S	.go
	TST.B	ahi_NoPaula
	BEQ.S	.frp
	BSR.W	pt_SndCardNext41
	BNE.S	.go
	MOVEQ	#1,D0
	BRA.S	.go
.frp:	TST.B	ahi_Failed		; failed once: no retry
	BEQ.S	.try0
	BSR.W	pt_CardAny41		; no card to go to: a click asks ahi again
	BNE.S	.noahi
	SF	ahi_Failed
.try0:	MOVEQ	#2,D0
	BSR.W	pt_SndAhiThere		; no ahi.device: a card or stay on paula
	BNE.S	.go
.noahi:	BSR.W	pt_SndCardNext41
	BNE.S	.go
	LEA	snd_MsgAhiFail(PC),A0
	TST.B	ahi_Failed
	BNE.S	.msg
	LEA	snd_MsgNoAhi(PC),A0
.msg:	JMP	pt_ShowStatusMsg
.go:	TST.B	agus_On			; leaving the card: wide module?
	BEQ.S	.go2
	BSR.W	pt_SndWideAsk
	BNE.S	.r
.go2:	CMP.B	#1,D0			; to paula: direct dma needs chip ram
	BNE.S	.go3
	CMPI.W	#8,dat_RpNumChannels
	BNE.S	.go4
	TST.B	mix_Is68k
	BEQ.S	.go3
.go4:	MOVEM.L	D0,-(A7)
	JSR	pt_SmpChipFits41
	MOVEM.L	(A7)+,D0		; flags stay
	BEQ.S	.go3
	LEA	smp_MsgChip(PC),A0	; stay on this output
	JMP	pt_ShowStatusMsg
.go3:	MOVE.B	D0,snd_Target
	SF	agus_Retry		; hand choice: start retry must not cut in
; if playing: stop, switch in main loop, resume at same pos (pt_SndResume)
	BSR.W	pt_SndPause
.idle:	ST	snd_Started		; from now only this choice counts (pt_AhiDetect)
	JSR	pt_MixStop
	MOVE.B	#2,snd_Defer
	LEA	snd_MsgSwitch(PC),A0
	JMP	pt_ShowStatusMsg
.r:	RTS

; wide module and the output leaves the card: tracks that go with notes ->
; ask first; z=1 go on
pt_SndWideAsk:
	MOVEM.L	D0-D2/A0-A1,-(A7)
	JSR	pt_WideKeep
	TST.W	D0
	BEQ.S	.r
	MOVEQ	#8,D0			; first track past the 8 view (4 view: 4)
	BTST	#5,dat_ModeFlags
	BEQ.S	.k
	MOVEQ	#4,D0
.k:	MOVE.W	wide_Ch,D1
	JSR	pt_ChnWideUsed41	; z=1: nothing lost, no question
	BEQ.S	.r
	IFD	DEBUGAUTO
	ADDQ.W	#1,dbg_ChnAsk
	ENDC
	LEA	snd_AskWide8(PC),A0
	JSR	pt_ShowYesNoDialog
.r:	MOVEM.L	(A7)+,D0-D2/A0-A1	; flags stay
	RTS

; z=1: no ahi.device (not loaded, not in DEVS:)
pt_SndAhiThere:
	MOVEM.L	D0-D2/A0-A1/A6,-(A7)
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-132,A6)		; Forbid
	LEA	350(A6),A0		; DeviceList
	LEA	set_AhiName(PC),A1
	JSR	(-276,A6)		; FindName
	JSR	(-138,A6)		; Permit
	TST.L	D0
	BNE.S	.y
	MOVEA.L	dat_DosLibBase,A6
	MOVE.L	#set_AhiDevPath,D1
	MOVEQ	#-2,D2
	JSR	(-84,A6)		; Lock
	MOVE.L	D0,D1
	BEQ.S	.n
	JSR	(-90,A6)		; UnLock
.y:	MOVEM.L	(A7)+,D0-D2/A0-A1/A6
	ANDI	#$fb,CCR		; z=0
	RTS
.n:	MOVEM.L	(A7)+,D0-D2/A0-A1/A6
	CMP.B	D0,D0			; z=1
	RTS

; do pending switch (from pt_SetPoll)
pt_SndOutputDo:
	ST	snd_Switch		; mixer keeps off paula meanwhile
	BSR.S	.do
	SF	snd_Switch
	RTS
.do:	SF	prf_AgusKeep
	TST.B	agus_On			; amigus -> paula
	BEQ.S	.na
	SF	snd_Alt			; both cards: the other one is next
	TST.B	zzax_On
	BNE.S	.alt
	ST	snd_Alt
.alt:
	JSR	pt_WideTo8		; wide module: keep what paula plays
	MOVE.W	D0,-(A7)
	JSR	pt_AgusOff
	MOVE.B	#1,snd_Choice
	JSR	pt_MixStop		; mixer restarts for the new owner
	ST	smp_ChipDue		; card output let samples into fast ram
	TST.B	mix_Is68k		; 68000: v1/2 dma at the next tick
	BEQ.S	.ag2
	JSR	pt_SmpChipNow41		; samples to chip before that
.ag2:	BSR.W	pt_SndRefresh
	MOVE.B	#3,snd_ResDefer
	MOVE.W	(A7)+,D0
	BNE.S	.wm
	JMP	pt_ClearStatusMsg
.wm:	BSR.W	pt_SndChanDraw
	LEA	snd_MsgWide8(PC),A0
	CMP.W	#8,D0
	BEQ.S	.m
	LEA	snd_MsgWide4(PC),A0
.m:	JMP	pt_ShowStatusMsg
.na:	CMPI.B	#4,snd_Target		; zz9000ax
	BEQ.S	.zx
	CMPI.B	#3,snd_Target
	BNE.W	.nt
	IFD	DEBUGAUTO
	JSR	pt_AgusDetect
	ENDC
	BSR.W	pt_SndAhiDrop		; ahi -> amigus: paula back first
	MOVE.B	#1,snd_Choice
	JSR	pt_AgusOn
	TST.L	D0
	BNE.S	.agf
	MOVE.B	#3,snd_Choice
	BRA.W	.done
.agf:	JSR	pt_MixStop
	BSR.W	pt_SndRefresh
	MOVE.B	#3,snd_ResDefer
	LEA	agus_MsgBusy,A0
	JMP	pt_ShowStatusMsg
.zx:	BSR.W	pt_SndAhiDrop		; ahi -> zz9000ax: paula back first
	MOVE.B	#1,snd_Choice
	JSR	pt_ZzaxOn
	TST.L	D0
	BNE.S	.zf
	MOVE.B	#4,snd_Choice
	BRA.W	.done
.zf:	JSR	pt_MixStop
	BSR.W	pt_SndRefresh
	MOVE.B	#3,snd_ResDefer
	LEA	zzax_MsgBusy,A0
	JMP	pt_ShowStatusMsg
.nt:	TST.B	ahi_NoPaula
	BNE.W	.paula
; paula -> ahi: audio ints + dma off, give back vectors + audio.device
	MOVE.W	#$0780,INTENA
	MOVE.W	#$0780,INTREQ
	MOVE.W	#$000f,DMACON
	JSR	pt_RemoveAudioInts
	JSR	pt_CloseAudioDev
	ST	ahi_NoPaula		; paula not ours anymore; set before pt_AhiOpen, else mixer int
	SF	ahi_Failed		; would still program paula once ahi_Active is set
	JSR	pt_AhiOpen
	TST.L	D0
	BNE.S	.fail
	ST	ahi_Want
	MOVE.B	#2,snd_Choice
	BRA.S	.done
.fail:	MOVE.B	#1,snd_Choice		; release paula (pt_AhiDetect sees choice)
	SF	ahi_Want
	SF	ahi_NoPaula
	BSR.W	pt_SndPaulaOpen
	JSR	pt_MixStop		; mixer ran for ahi while it opened: restart on paula
	BSR.W	pt_SndRefresh
	MOVE.B	#3,snd_ResDefer
	LEA	snd_MsgAhiFail(PC),A0
	JMP	pt_ShowStatusMsg
; ahi -> paula
.paula:	BSR.W	pt_SndAhiDrop
.done:	JSR	pt_MixStop		; mixer restarts for the new owner
	BSR.W	pt_SndRefresh
	MOVE.B	#3,snd_ResDefer		; resume stopped playback after 3 main passes
	JMP	pt_ClearStatusMsg

; stop play for switch, save mode/pos/row; pt_SndResume = like CONTINUE
pt_SndPause:
	TST.L	dat_RpPlayMode		; stopped or 2nd click: keep what was saved
	BEQ.S	.r
	MOVE.L	dat_RpPlayMode,snd_ResMode
	MOVE.L	dat_SongDataPtr,snd_ResEdit
	MOVE.L	dat_RpSongPos,snd_ResSong
	MOVE.L	dat_RpPatternPos,snd_ResPat
	CLR.B	snd_ResDefer
	JSR	pt_BtnMainStop
.r:	RTS

; from pt_SetPoll when snd_ResDefer expired
pt_SndResume:
	MOVE.L	snd_ResMode,D0
	BEQ.S	.r
	CLR.L	snd_ResMode
	TST.L	dat_RpPlayMode		; started by hand meanwhile
	BNE.S	.r
	MOVE.L	snd_ResSong,dat_RpSongPos
	MOVE.L	snd_ResPat,dat_RpPatternPos
	CLR.L	dat_RpCounter
	MOVE.L	D0,-(A7)
	TST.L	snd_ResEdit		; was recording: record again
	BEQ.S	.pl
	MOVE.L	snd_ResEdit,dat_SongDataPtr
	JSR	pt_SetPaletteRec
	BRA.S	.pp
.pl:	JSR	pt_SetPalettePlay
.pp:	MOVE.L	(A7)+,D0
	MOVE.L	D0,dat_RpPlayMode
.r:	RTS

; retake audio.device + audio ints, voices -> paula direct
pt_SndPaulaOpen:
	LEA	dat_AudioIOReq,A0	; like first open: no old alloc key / error
	CLR.B	31(A0)
	CLR.W	32(A0)
	JSR	pt_OpenAudioDev
	TST.L	D0
	BEQ.S	.ok
	ST	ahi_NoPaula		; no audio.device: paula not ours (no ints, no close)
	RTS
.ok:	JSR	pt_AddAudioInts
	JMP	pt_MixRestoreDirect

; ahi has or holds the output: mixer off, ahi closed, paula ours again
; (task; flags fall only after the mixer stop, else a tick programs
; paula with the ahi rate)
pt_SndAhiDrop:
	TST.B	ahi_Active
	BNE.S	.go
	TST.B	ahi_NoPaula
	BEQ.S	.r
.go:	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.B	snd_Switch,-(A7)
	ST	snd_Switch
	JSR	pt_MixStop
	JSR	pt_AhiClose
	SF	ahi_Want
	SF	ahi_NoPaula
	SF	ahi_Failed
	ST	snd_Started		; else PT.ahi takes the output again
	MOVE.B	#1,snd_Choice
	BSR.S	pt_SndPaulaOpen
	MOVE.B	(A7)+,snd_Switch
	MOVEM.L	(A7)+,D0-D7/A0-A6
.r:	RTS

; mix rate AUTO/14/22/28 kHz (shared with rmb on CHANNELS, pt_MixRatePoll)
pt_SndRateUp:
	MOVEQ	#1,D1
	BRA.S	pt_SndRate
pt_SndRateDown:
	MOVEQ	#-1,D1
pt_SndRate:
	TST.B	agus_On			; card resamples, no mixer
	BEQ.S	.nag
	LEA	snd_MsgCard(PC),A0
	TST.B	zzax_On
	BEQ.S	.cm
	LEA	snd_MsgZzax(PC),A0
.cm:	JMP	pt_ShowStatusMsg
.nag:	TST.B	mix_Enabled
	BNE.S	.ok
	LEA	snd_Msg020(PC),A0
	JMP	pt_ShowStatusMsg
.ok:	TST.B	ahi_Active		; ahi: rates of the mode, reopens
	BNE.W	pt_SndRateAhi41
	BTST	#5,dat_ModeFlags	; 4ch: nothing is mixed
	BEQ.S	.m8
	LEA	snd_Msg8ch(PC),A0
	JMP	pt_ShowStatusMsg
.m8:	MOVE.B	mix_RateSel,D0
	ADD.B	D1,D0
	AND.B	#3,D0
	MOVE.B	D0,mix_RateSel
	JSR	pt_MixApplyRate
	TST.B	mix_Active		; running: restart with new rate (next tick)
	BEQ.S	.d
	JSR	pt_MixStop
.d:	JSR	pt_0641			; CHANNELS shows rate in 8ch mode
	BSR.W	pt_SndWait
	BRA.W	pt_SndRefresh

; volume 0..100 % in tenths (stored as reduction, 0 = 100 %)
pt_SndVolUp:
	TST.B	snd_VolDown
	BEQ.S	pt_SndVolSet
	SUBQ.B	#1,snd_VolDown
	BRA.S	pt_SndVolSet
pt_SndVolDown:
	CMPI.B	#10,snd_VolDown
	BCC.S	pt_SndVolSet
	ADDQ.B	#1,snd_VolDown
pt_SndVolSet:
	BSR.W	pt_SndApplyVol
	BSR.W	pt_SndWait
	BRA.W	pt_SndRefresh

; stereo 100/75/50/25/0 % (stored as reduction 0..4)
pt_SndStUp:
	JSR	pt_SndStereoOk41
	BEQ.S	pt_SndStNA
	TST.B	snd_StereoDown
	BEQ.S	.d
	SUBQ.B	#1,snd_StereoDown
.d:	BSR.W	pt_SndWait
	BRA.W	pt_SndRefresh
pt_SndStDown:
	JSR	pt_SndStereoOk41
	BEQ.S	pt_SndStNA
	CMPI.B	#4,snd_StereoDown
	BCC.S	.d
	ADDQ.B	#1,snd_StereoDown
.d:	BSR.W	pt_SndWait
	BRA.W	pt_SndRefresh

pt_SndStNA:
	LEA	snd_MsgStereo(PC),A0
	JMP	pt_ShowStatusMsg

; volume -> ahi, or paula (ring and direct channels) at once
pt_SndApplyVol:
	MOVEM.L	D0-D3/A0-A2/A6,-(A7)
	TST.B	ahi_Active
	BEQ.S	.pa
	MOVE.L	ahi_Ctrl,D0
	BEQ.S	.r
	MOVEA.L	D0,A2
	MOVEA.L	ahi_Base,A6
	JSR	pt_AhiVolBoth
	BRA.S	.r
.pa:	JSR	pt_SndPaulaLive41
.r:	MOVEM.L	(A7)+,D0-D3/A0-A2/A6
	RTS

; d1.l = ahi volume (16.16) from snd_VolDown
pt_SndAhiVol:
	MOVEQ	#0,D1
	MOVE.B	snd_VolDown,D1
	CMP.B	#10,D1
	BLS.S	.ok
	MOVEQ	#10,D1
.ok:	LSL.W	#2,D1
	MOVE.L	snd_AhiVolTab(PC,D1.W),D1
	RTS
snd_AhiVolTab:	DC.L	$10000,$e666,$cccc,$b333,$9999,$8000,$6666,$4ccc,$3333,$1999,0

; paula ring ch volume (0..64) from snd_VolDown, for pt_MixStart
pt_SndPaulaVol:
	MOVEQ	#0,D0
	MOVE.B	snd_VolDown,D0
	CMP.B	#10,D0
	BLS.S	.ok
	MOVEQ	#10,D0
.ok:	ADD.W	D0,D0
	MOVE.W	snd_PaulaVolTab(PC,D0.W),D0
	RTS
snd_PaulaVolTab:	DC.W	64,58,51,45,38,32,26,19,13,6,0

; ahi mode: next (after last -> PREFS); running ahi reopens with new mode
pt_SndAhiMode:
	MOVEA.L	ABSEXECBASE.W,A6
	BTST	#1,(297,A6)
	BNE.S	.cpu
	LEA	snd_Msg020(PC),A0
	JMP	pt_ShowStatusMsg
.cpu:	JSR	pt_WaitMouseRelease
	TST.B	ahi_Active		; ahi + playing: stop, reopen, resume
	BEQ.S	.go
	BSR.W	pt_SndPause
.go:	BSR.W	pt_SndAhiBase
	BEQ.W	.noahi
	MOVE.L	snd_AhiMode,D0
	BNE.S	.next
	MOVEQ	#-1,D0			; AHI_INVALID_ID -> first mode
.next:	JSR	(_LVOAHI_NextAudioID,A6)
	CMP.L	#-1,D0
	BNE.S	.set
	MOVEQ	#0,D0			; end of list -> PREFS (AHI_DEFAULT_ID)
.set:	MOVE.L	D0,snd_AhiMode
	SF	snd_NameOk
	BSR.W	pt_SndAhiFree
	TST.B	ahi_Active		; ahi running: reopen with new mode
	BEQ.S	.d
	BSR.S	pt_SndAhiReopen
.d:	MOVE.B	#3,snd_ResDefer		; resume stopped playback
	BRA.W	pt_SndRefresh
.noahi:	MOVE.B	#3,snd_ResDefer		; resume also without ahi
	LEA	snd_MsgNoAhi(PC),A0
	JMP	pt_ShowStatusMsg

; ahi running: close, open again (new mode or rate)
pt_SndAhiReopen:
	ST	snd_Switch
	JSR	pt_MixStop
	JSR	pt_AhiClose
	SF	ahi_Failed
	JSR	pt_AhiOpen
	TST.L	D0
	BEQ.S	.r
	LEA	snd_MsgAhiFail(PC),A0	; mode fails: ahi stays off, paula free -> back to paula
	JSR	pt_ShowStatusMsg
	SF	ahi_NoPaula
	SF	ahi_Want
	ST	snd_Started
	MOVE.B	#1,snd_Choice
	BSR.W	pt_SndPaulaOpen
	JSR	pt_MixStop		; restart on paula
.r:	SF	snd_Switch
	RTS

; AHIBase for task queries (no unit) -> Z=0 a6=AHIBase if open
pt_SndAhiBase:
	MOVEM.L	D0-D1/A0-A1,-(A7)
	LEA	snd_Req,A1
	MOVEQ	#19,D0
.c:	CLR.L	(A1)+
	DBF	D0,.c
	LEA	snd_Req,A1
	MOVE.W	#80,18(A1)
	MOVE.W	#4,48(A1)
	LEA	ahi_DevName,A0
	MOVE.L	#255,D0
	MOVEQ	#0,D1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-444,A6)
	TST.L	D0
	BNE.S	.no
	MOVEA.L	snd_Req+20,A6
	MOVEM.L	(A7)+,D0-D1/A0-A1
	ANDI	#$fb,CCR
	RTS
.no:	MOVEM.L	(A7)+,D0-D1/A0-A1
	ORI	#4,CCR
	RTS

pt_SndAhiFree:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	LEA	snd_Req,A1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-450,A6)
	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

; name of chosen ahi mode -> snd_AhiName (upper case); PREFS = default
pt_SndAhiName:
	MOVEM.L	D0-D2/A0-A2/A6,-(A7)
	TST.B	snd_NameOk
	BNE.W	.r
	LEA	snd_AhiName,A1
	LEA	snd_TxtPrefs(PC),A0
	MOVE.L	snd_AhiMode,D0
	BEQ.S	.copy
	BSR.W	pt_SndAhiBase
	BEQ.S	.copy
	LEA	snd_Tags,A1
	MOVE.L	#AHIDB_Name,(A1)
	MOVE.L	#snd_AhiName,4(A1)
	MOVE.L	#AHIDB_BufferLen,8(A1)
	MOVE.L	#40,12(A1)
	CLR.L	16(A1)
	CLR.B	snd_AhiName
	MOVE.L	snd_AhiMode,D0
	SUBA.L	A2,A2
	JSR	(_LVOAHI_GetAudioAttrsA,A6)
	BSR.W	pt_SndAhiFree
	LEA	snd_AhiName,A0
	MOVE.B	#0,39(A0)
	TST.B	(A0)
	BNE.S	.up
	CLR.L	snd_AhiMode		; id not known (any more): default mode
	LEA	snd_TxtPrefs(PC),A0
	LEA	snd_AhiName,A1
	BRA.S	.copy
.up:	MOVE.B	(A0),D0			; upper case (program font)
	BEQ.S	.ok
	CMP.B	#'a',D0
	BCS.S	.n
	CMP.B	#'z',D0
	BHI.S	.n
	SUB.B	#32,(A0)
.n:	ADDQ.L	#1,A0
	BRA.S	.up
.copy:	MOVE.B	(A0)+,(A1)+
	BNE.S	.copy
.ok:	ST	snd_NameOk
.r:	MOVEM.L	(A7)+,D0-D2/A0-A2/A6
	RTS

; text a0 into the AHI mode field; longer: marquee as the status line
pt_SetAhiMode:
	MOVEM.L	D0-D1/A0-A1,-(A7)
	CLR.W	set_MqLen
	MOVEA.L	A0,A1
	MOVEQ	#-1,D0
.l:	ADDQ.W	#1,D0
	TST.B	(A1)+
	BNE.S	.l
	CMP.W	#SV_AHIMODE_N,D0
	BLS.S	.put
	CMP.W	#SET_MQMAX,D0
	BLS.S	.c0
	MOVEQ	#SET_MQMAX,D0
.c0:	MOVE.W	D0,set_MqLen
	LEA	set_MqBuf,A1
	SUBQ.W	#1,D0
.c:	MOVE.B	(A0)+,(A1)+
	DBF	D0,.c
	CLR.W	set_MqPos
	JSR	pt_StatusTicks
	ADD.L	#STAT_HOLD,D0
	MOVE.L	D0,set_MqNext
	LEA	set_MqBuf,A0
.put:	MOVE.W	#SV_AHIMODE_POS,D1
	MOVEQ	#SV_AHIMODE_N,D0
	BSR.W	pt_SetPut
	MOVEM.L	(A7)+,D0-D1/A0-A1
	RTS

; main loop: next marquee step of the AHI mode field (page SETUP)
pt_SetMqPoll:
	TST.W	set_MqLen
	BEQ.S	.r
	CMPI.W	#5,dat_UIMode
	BNE.S	.off
	TST.B	set_Page
	BNE.S	.off
	MOVEM.L	D0-D3/A0,-(A7)
	JSR	pt_StatusTicks
	MOVE.L	set_MqNext,D1		; due (or the clock passed midnight)
	SUB.L	D0,D1
	BLE.S	.due
	CMP.L	#2*STAT_HOLD,D1
	BLS.S	.x
.due:	MOVE.W	set_MqLen,D2
	SUB.W	#SV_AHIMODE_N,D2	; last start
	MOVE.W	set_MqPos,D1
	MOVEQ	#STAT_STEP,D3
	ADDQ.W	#1,D1
	CMP.W	D2,D1
	BLE.S	.in
	MOVEQ	#0,D1			; past the end: start again
.in:	TST.W	D1
	BEQ.S	.h
	CMP.W	D2,D1
	BNE.S	.s
.h:	MOVE.W	#STAT_HOLD,D3		; hold at both ends
.s:	MOVE.W	D1,set_MqPos
	ADD.L	D3,D0
	MOVE.L	D0,set_MqNext
	LEA	set_MqBuf,A0
	ADDA.W	D1,A0
	MOVE.W	#SV_AHIMODE_POS,D1
	MOVEQ	#SV_AHIMODE_N,D0
	BSR.W	pt_SetPut
.x:	MOVEM.L	(A7)+,D0-D3/A0
.r:	RTS
.off:	CLR.W	set_MqLen		; page left: its draw starts again
	RTS

; short wait so arrows dont race
pt_SndWait:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVEA.L	dat_DosLibBase,A6
	MOVEQ	#6,D1
	JSR	(-198,A6)
	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

; channels value after a mode change (setup page on screen only)
pt_SndChanDraw:
	CMPI.W	#5,dat_UIMode
	BNE.S	.r
	TST.B	set_Page
	BNE.S	.r
	MOVEM.L	D0-D7/A0-A6,-(A7)
	JSR	pt_0641
	MOVEM.L	(A7)+,D0-D7/A0-A6
.r:	RTS

; redraw sound block values + status
pt_SndRefresh:
	BSR.S	pt_SndDraw
	BRA.W	pt_SetStatus

; sound values (pg SETUP); CHANNELS, FILTER, SOFTINT drawn by beta 2
pt_SndDraw:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	BSR.W	pt_LoadModeDraw
	BSR.W	pt_FltDraw
	LEA	set_Line2,A1
	CLR.B	(A1)
	LEA	snd_TxtPaula(PC),A0
	TST.B	ahi_Active
	BEQ.S	.o0
	LEA	snd_TxtAhi(PC),A0
.o0:	TST.B	agus_On
	BEQ.S	.o1
	LEA	snd_TxtAgus(PC),A0
	TST.B	zzax_On
	BEQ.S	.o1
	LEA	snd_TxtZzaxO(PC),A0
.o1:	BSR.W	pt_SetCat
	TST.B	ahi_Failed
	BEQ.S	.o2
	LEA	snd_TxtFailed(PC),A0
	BSR.W	pt_SetCat
.o2:	LEA	set_Line2,A0
	MOVE.W	#SV_OUTPUT_POS,D1
	MOVEQ	#SV_OUTPUT_N,D0
	BSR.W	pt_SetPut
	LEA	set_Line2,A1
	CLR.B	(A1)
	JSR	pt_SndRateStr41
	LEA	set_Line2,A0
	MOVE.W	#SV_MIXRATE_POS,D1
	MOVEQ	#SV_MIXRATE_N,D0
	BSR.W	pt_SetPut
	LEA	set_TxtNA(PC),A0
	MOVEA.L	ABSEXECBASE.W,A6
	BTST	#1,(297,A6)
	BEQ.S	.a
	BSR.W	pt_SndAhiName
	LEA	snd_AhiName,A0
.a:	BSR.W	pt_SetAhiMode
	MOVEQ	#10,D0
	SUB.B	snd_VolDown,D0
	MULU	#10,D0
	MOVE.W	#SV_VOLUME_POS,D1
	BSR.S	pt_SndPercent
	JSR	pt_SndStereoOk41
	BNE.S	.st
	LEA	set_TxtNA(PC),A0	; paula: no effect
	MOVE.W	#SV_STEREO_POS,D1
	MOVEQ	#SV_STEREO_N,D0
	BSR.W	pt_SetPut
	BRA.S	.sx
.st:	MOVEQ	#4,D0
	SUB.B	snd_StereoDown,D0
	MULU	#25,D0
	MOVE.W	#SV_STEREO_POS,D1
	BSR.S	pt_SndPercent
.sx:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; percent d0.w at pos d1
pt_SndPercent:
	AND.L	#$ffff,D0
	LEA	set_Num,A0
	BSR.W	pt_SetFmtNum
	MOVE.B	#' ',(A0)+
	MOVE.B	#'%',(A0)+
	CLR.B	(A0)
	LEA	set_Num,A0
	MOVEQ	#SV_VOLUME_N,D0
	BRA.W	pt_SetPut

AHIDB_Name	EQU	$8000806d
AHIDB_BufferLen	EQU	$8000007a
_LVOAHI_NextAudioID	EQU	-102

snd_TxtPaula:	DC.B	"PAULA",0
snd_TxtAhi:	DC.B	"AHI",0
snd_TxtAgus:	DC.B	"AMIGUS",0
snd_TxtZzaxO:	DC.B	"ZZ9000AX",0
snd_TxtFailed:	DC.B	" (NO AHI)",0
snd_TxtPrefs:	DC.B	"PREFS",0
snd_Msg020:	DC.B	"NEEDS A 68020",0
snd_Msg8ch:	DC.B	"MIX RATE: ONLY IN 8CHN",0
snd_MsgAhiFail:	DC.B	"AHI FAILED",0
snd_MsgNoAhi:	DC.B	"NO AHI.DEVICE",0
snd_MsgSwitch:	DC.B	"SWITCHING OUTPUT...",0
snd_MsgWide8:	DC.B	"WIDE MOD: TRACKS 1-8 KEPT",0
snd_MsgWide4:	DC.B	"WIDE MOD: TRACKS 1-4 KEPT",0
snd_AskWide8:	DC.B	10,10
	DC.B	"  Without the card only",10
	DC.B	" tracks 1-8 stay. Switch?",0
snd_AskWide4:	DC.B	10,10
	DC.B	"  Without the card only",10
	DC.B	" tracks 1-4 stay. Switch?",0
	EVEN

;--- graphics
; rtg runs the mirror process; screenmode steps card modes (8 bit,
; 640x480/512; AUTO = search); scale 2X/1X at 640x512; fps 50/25/17/12;
; changes restart a running mirror
pt_GfxGadget:
	MOVEA.L	ABSEXECBASE.W,A6
	BTST	#1,(297,A6)		; mirror needs 68020
	BNE.S	.cpu
	LEA	snd_Msg020(PC),A0
	JMP	pt_ShowStatusMsg
.cpu:	CMP.W	#SG_RTG,D2
	BEQ.S	pt_GfxRtg
	CMP.W	#SG_SCREENMODE,D2
	BCS.S	.on
	CMP.W	#SG_FPS_DOWN,D2
	BHI.S	.on
	TST.L	rtg_Proc		; mode, aspect, fps: only with rtg on
	BNE.S	.on
	LEA	gfx_MsgOff(PC),A0
	JMP	pt_ShowStatusMsg
.on:	CMP.W	#SG_SCREENMODE,D2
	BEQ.W	pt_GfxMode
	CMP.W	#SG_SCALE_UP,D2
	BEQ.W	pt_GfxScale
	CMP.W	#SG_SCALE_DOWN,D2
	BEQ.W	pt_GfxScaleDn
	CMP.W	#SG_FPS_UP,D2
	BEQ.W	pt_GfxFpsUp
	CMP.W	#SG_FPS_DOWN,D2
	BEQ.W	pt_GfxFpsDown
	CMP.W	#SG_ROWS_UP,D2
	BEQ.W	pt_GfxRowsUp
	CMP.W	#SG_ROWS_DOWN,D2
	BEQ.W	pt_GfxRowsDn
	RTS

; OFF -> SCREEN (own card screen) -> WINDOW (on wb) -> OFF
pt_GfxRtg:
	JSR	pt_WaitMouseRelease
	ST	rtg_Tried		; no auto start from pt_RtgPoll
	TST.L	rtg_Proc
	BEQ.W	.on
	MOVEQ	#0,D0
	TST.B	rtg_WinMode		; window -> off
	BNE.S	.ask
	MOVEQ	#3,D0
	TST.B	rtg_WinBad		; screen -> window, not possible: off
	BNE.S	.ask
	JSR	pt_RtgWinOk41
	TST.L	D0
	BEQ.S	.cl
.ask:	MOVE.L	D0,-(A7)		; next is off: wide module asks first
	BSR.W	pt_GfxWideAsk
	SNE	D1
	MOVE.L	(A7)+,D0
	TST.B	D1
	BNE.S	.no
.cl:	JSR	pt_RtgClose
	TST.B	rtg_WinMode
	BNE.S	.off
	TST.L	D0
	BNE.S	.nowin
	MOVE.B	#1,rtg_WinMode
	BSR.W	pt_GfxStart
	BSR.W	pt_GfxWideLost
	BRA.W	pt_GfxRefresh
.nowin:	LEA	gfx_MsgNoWin(PC),A0
	SUBQ.W	#2,D0
	BMI.S	.nw
.nl:	TST.B	(A0)+
	BNE.S	.nl
	DBF	D0,.nl
.nw:	JSR	pt_StatusLater41
.off:	SF	rtg_Want
	SF	rtg_WinMode
	SF	rtg_WinBad
	BRA.W	pt_GfxRefresh
.on:	ST	rtg_Want
	SF	rtg_WinMode
	BSR.W	pt_GfxStart
	BRA.W	pt_GfxRefresh
.no:	RTS

; rtg off with a wide module: the card plays it and the main loop gives it
; the 8 track view; without the card ask: yes -> play stops, tracks 1-8
; stay as 8ch module. z=1 go on
pt_GfxWideAsk:
	TST.B	wide_On
	BEQ.S	.go
	TST.B	agus_On
	BNE.S	.go
	LEA	gfx_AskWide(PC),A0
	JSR	pt_ShowYesNoDialog
	BNE.S	.r
	BSR.S	pt_GfxWide8
.go:	CMP.W	D0,D0			; z=1
.r:	RTS

; mirror did not come up: without the card keep tracks 1-8
pt_GfxWideLost:
	TST.L	rtg_Proc
	BNE.S	.r
	TST.B	wide_On
	BEQ.S	.r
	TST.B	agus_On
	BNE.S	.r
	BSR.S	pt_GfxWide8
.r:	RTS

pt_GfxWide8:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	JSR	pt_BtnMainStop
	JSR	pt_MixStop
	JSR	pt_WideTo8
	BSR.W	pt_SndChanDraw
	LEA	snd_MsgWide8(PC),A0
	JSR	pt_StatusLater41
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; start mirror process, wait up to 3 s for result
pt_GfxStart:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	CLR.B	rtg_ProcState
	MOVEA.L	dat_DosLibBase,A6
	MOVE.L	#rtg_ProcTags,D1
	JSR	(-498,A6)
	MOVE.L	D0,rtg_Proc
	BEQ.S	.r
	MOVE.W	#150,D7
.w:	TST.B	rtg_ProcState
	BNE.S	.got
	MOVEQ	#1,D1
	JSR	(-198,A6)
	DBF	D7,.w
.got:	CMPI.B	#2,rtg_ProcState	; 2 fail, 3 already ended
	BCS.S	.r
	MOVEQ	#50,D1
.w2:	CMPI.B	#3,rtg_ProcState
	BEQ.S	.gone
	MOVEM.L	D1,-(A7)
	MOVEQ	#1,D1
	JSR	(-198,A6)
	MOVEM.L	(A7)+,D1
	DBF	D1,.w2
.gone:	CLR.L	rtg_Proc
	MOVE.B	#2,rtg_ProcState
	LEA	set_HintRtgF(PC),A0
	JSR	pt_ShowStatusMsg
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; restart running mirror with new settings
pt_GfxRestart:
	TST.L	rtg_Proc
	BEQ.S	.r
	JSR	pt_RtgClose
	BSR.W	pt_GfxStart
	BSR.W	pt_GfxWideLost
.r:	RTS

; screenmode: next card mode (8 bit, 640 x 480/512), after last -> AUTO
pt_GfxMode:
	TST.B	rtg_WinMode		;41 window: card mode has no say
	BEQ.S	.ok
	LEA	gfx_MsgMode(PC),A0
	JMP	pt_ShowStatusMsg
.ok:	JSR	pt_WaitMouseRelease
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVEA.L	dat_GfxLibBase,A6
	MOVE.L	rtg_UserMode,D7
	BNE.S	.next
	MOVEQ	#-1,D7
.next:	MOVE.L	D7,D0
	JSR	(-732,A6)
	MOVE.L	D0,D7
	CMP.L	#-1,D0
	BEQ.S	.auto
	CMP.L	#$00100000,D7		; card modes only (monitor id >= $00100000)
	BLO.S	.next
	MOVE.L	D7,D0
	JSR	pt_RtgModeH
	CMP.W	#512,D1
	BEQ.S	.set
	CMP.W	#480,D1
	BNE.S	.next
	BRA.S	.set
.auto:	MOVEQ	#0,D7
.set:	MOVE.L	D7,rtg_UserMode
	MOVEM.L	(A7)+,D0-D7/A0-A6
	BSR.W	pt_GfxRestart
	BRA.W	pt_GfxRefresh

; aspect: 0 amiga 1:2, $ff pixel 1:1, 2 free (window only)
pt_GfxScale:
	BSR.S	pt_GfxScaleCur
	BEQ.S	.px
	CMP.B	#2,D0
	BEQ.S	.am
	MOVEQ	#2,D0
	TST.B	rtg_WinMode		;41 free only in the window
	BNE.S	pt_GfxScaleSet
.am:	MOVEQ	#0,D0
	BRA.S	pt_GfxScaleSet
.px:	MOVEQ	#-1,D0
	BRA.S	pt_GfxScaleSet
pt_GfxScaleDn:
	BSR.S	pt_GfxScaleCur
	BEQ.S	.fr
	CMP.B	#2,D0
	BEQ.S	.px
	MOVEQ	#0,D0
	BRA.S	pt_GfxScaleSet
.fr:	MOVEQ	#2,D0
	TST.B	rtg_WinMode
	BNE.S	pt_GfxScaleSet
.px:	MOVEQ	#-1,D0
	BRA.S	pt_GfxScaleSet

; aspect as it works: free means amiga on the card screen
pt_GfxScaleCur:
	MOVE.B	rtg_Scale1x,D0
	CMP.B	#2,D0
	BNE.S	.r
	TST.B	rtg_WinMode
	BNE.S	.r
	MOVEQ	#0,D0
.r:	TST.B	D0
	RTS
pt_GfxScaleSet:
	MOVE.B	D0,rtg_Scale1x
	BSR.W	pt_SndWait
	BSR.W	pt_GfxRestart
	BRA.W	pt_GfxRefresh

; fps: 50/25/17/12 = 1..4 vbl per frame (rtg_WaitAdj 0..3, 0 = 50)
pt_GfxFpsUp:
	TST.B	rtg_WaitAdj
	BEQ.S	pt_GfxFpsSet
	SUBQ.B	#1,rtg_WaitAdj
	BRA.S	pt_GfxFpsSet
pt_GfxFpsDown:
	CMPI.B	#3,rtg_WaitAdj
	BEQ.S	pt_GfxFpsSet
	ADDQ.B	#1,rtg_WaitAdj
pt_GfxFpsSet:
	BSR.W	pt_SndWait
	BRA.W	pt_GfxRefresh		; takes effect next frame

; rows: rtg window one pattern row taller/shorter, mirror resizes it
pt_GfxRowsUp:
	MOVEQ	#1,D0
	BRA.S	pt_GfxRows
pt_GfxRowsDn:
	MOVEQ	#-1,D0
pt_GfxRows:
	TST.L	rtg_Proc
	BEQ.S	.na
	TST.B	rtg_WinMode
	BEQ.S	.na
	CMPI.B	#2,rtg_Scale1x		; free: window keeps its size
	BEQ.S	.nf
	MOVE.B	D0,-(A7)
	JSR	pt_WaitMouseRelease
	MOVE.B	(A7)+,D0
	ADD.B	D0,rtg_RowsReq		; taken by pt_RtgWinSnap
	BSR.S	pt_GfxRowsVal
	MOVE.W	D0,gfx_RowsAskV		; pt_GfxPoll: no change = limit
	MOVE.B	#3,gfx_RowsAsk
	RTS				; value follows from pt_SetPoll
.na:	LEA	gfx_MsgRows(PC),A0
	JMP	pt_ShowStatusMsg
.nf:	LEA	gfx_MsgRowsFree(PC),A0
	JMP	pt_ShowStatusMsg

; d0.l = visible pattern rows of the mirror, 0 = off
pt_GfxRowsVal:
	MOVEQ	#0,D0
	TST.L	rtg_Proc
	BEQ.S	.r
	TST.B	rtg_WinMode		;41 screen: rows are not yours to set
	BEQ.S	.r
	MOVE.W	rtg_OutH,D0
	SUB.W	#RTG_ROWS,D0
	BPL.S	.p
	MOVEQ	#0,D0
.p:	LSR.W	#3,D0
	ADD.W	#GFX_ROWS0,D0
.r:	RTS

GFX_ROWS0	EQU	13		; pattern rows at classic height

; system page tick: redraw when the mirror state or the rows changed
pt_GfxPoll:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.B	gfx_RowsAsk
	BEQ.S	.sg
	TST.B	rtg_RowsReq		; not taken yet
	BNE.S	.sg
	SUBQ.B	#1,gfx_RowsAsk
	BNE.S	.sg
	BSR.S	pt_GfxRowsVal
	CMP.W	gfx_RowsAskV,D0
	BNE.S	.sg
	LEA	gfx_MsgLimit(PC),A0
	JSR	pt_ShowStatusMsg
.sg:	BSR.S	pt_GfxSig
	CMP.B	gfx_Sig,D0
	BNE.S	.dr
	BSR.S	pt_GfxRowsVal
	CMP.W	gfx_RowsShown,D0
	BEQ.S	.r
.dr:	BSR.S	pt_GfxDraw
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; d0 = rtg state: proc, window, start state
pt_GfxSig:
	MOVEQ	#0,D0
	TST.L	rtg_Proc
	BEQ.S	.a
	MOVEQ	#1,D0
.a:	TST.B	rtg_WinMode
	BEQ.S	.b
	ADDQ.B	#2,D0
.b:	MOVE.B	rtg_ProcState,D1
	LSL.B	#2,D1
	OR.B	D1,D0
	RTS

pt_GfxRefresh:
	BSR.S	pt_GfxDraw
	BRA.W	pt_SetStatus

; graphics block values (page SYSTEM)
pt_GfxDraw:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	BSR.S	pt_GfxSig
	MOVE.B	D0,gfx_Sig
	MOVEA.L	ABSEXECBASE.W,A6
	BTST	#1,(297,A6)
	BNE.S	.cpu
	LEA	set_TxtNA(PC),A0	; 68000: all N/A
	MOVE.W	#SV_RTG_POS,D1
	MOVEQ	#SV_RTG_N,D0
	BSR.W	pt_SetPut
	MOVE.W	#SV_SCREENMODE_POS,D1
	MOVEQ	#SV_SCREENMODE_N,D0
	BSR.W	pt_SetPut
	MOVE.W	#SV_SCALE_POS,D1
	MOVEQ	#SV_SCALE_N,D0		; own widths, else arrows and ROWS go
	BSR.W	pt_SetPut
	MOVE.W	#SV_FPS_POS,D1
	MOVEQ	#SV_FPS_N,D0
	BSR.W	pt_SetPut
	MOVE.W	#SV_ROWS_POS,D1
	MOVEQ	#SV_ROWS_N,D0
	BSR.W	pt_SetPut
	BRA.W	.r
.cpu:	MOVE.L	rtg_UserMode,D0		;41 mode gone or unfit: AUTO
	BEQ.S	.uok
	MOVEA.L	dat_GfxLibBase,A6
	JSR	pt_RtgModeH
	CMP.W	#512,D1
	BEQ.S	.uok
	CMP.W	#480,D1
	BEQ.S	.uok
	CLR.L	rtg_UserMode
.uok:	LEA	set_Line2,A1
	CLR.B	(A1)
	LEA	gfx_TxtOff(PC),A0
	TST.L	rtg_Proc
	BNE.S	.run
	CMPI.B	#2,rtg_ProcState	; last start failed
	BNE.S	.r1
	LEA	gfx_TxtNoMode(PC),A0
	BRA.S	.r1
.run:
	LEA	gfx_TxtOn(PC),A0
	TST.B	rtg_WinMode
	BEQ.S	.run2
	LEA	gfx_TxtWin(PC),A0
.run2:	CMPI.B	#1,rtg_ProcState
	BEQ.S	.r1
	LEA	gfx_TxtStart(PC),A0
.r1:	BSR.W	pt_SetCat
	LEA	set_Line2,A0
	MOVE.W	#SV_RTG_POS,D1
	MOVEQ	#SV_RTG_N,D0
	BSR.W	pt_SetPut
	TST.L	rtg_Proc		; rtg off: its settings have no effect
	BNE.S	.son
	LEA	set_TxtNA(PC),A0
	MOVE.W	#SV_SCREENMODE_POS,D1
	MOVEQ	#SV_SCREENMODE_N,D0
	BSR.W	pt_SetPut
	MOVE.W	#SV_SCALE_POS,D1
	MOVEQ	#SV_SCALE_N,D0
	BSR.W	pt_SetPut
	MOVE.W	#SV_FPS_POS,D1
	MOVEQ	#SV_FPS_N,D0
	BSR.W	pt_SetPut
	BRA.W	.rows
.son:	TST.B	rtg_WinMode		;41 window: no card mode choice
	BEQ.S	.son1
	LEA	set_TxtNA(PC),A0
	BRA.W	.sm
.son1:
; screenmode: name of chosen / running mode
	LEA	gfx_TxtAuto(PC),A0
	MOVE.L	rtg_UserMode,D2
	BNE.S	.nm
	TST.L	rtg_Proc
	BEQ.W	.sm
	MOVE.L	rtg_Mode,D2		; AUTO running: name found mode
	BEQ.W	.sm
.nm:	MOVEA.L	dat_GfxLibBase,A6
	SUBA.L	A0,A0
	LEA	rtg_DimBuf,A1
	MOVEQ	#48,D0
	MOVE.L	#$80003000,D1
	JSR	(-756,A6)
	LEA	gfx_TxtCard(PC),A0
	TST.L	D0
	BEQ.S	.sm
	LEA	rtg_DimBuf+16,A0
	MOVE.B	#0,31(A0)
	MOVE.L	A0,A1
.up:	MOVE.B	(A1),D0
	BEQ.S	.sm0
	CMP.B	#'a',D0
	BCS.S	.un
	CMP.B	#'z',D0
	BHI.S	.un
	SUB.B	#32,(A1)
.un:	ADDQ.L	#1,A1
	BRA.S	.up
.sm0:	TST.L	rtg_UserMode
	BNE.S	.sm
	LEA	set_Line2,A1		; AUTO: prefix "AUTO "
	CLR.B	(A1)
	MOVE.L	A0,-(A7)
	LEA	gfx_TxtAuto2(PC),A0
	BSR.W	pt_SetCat
	MOVE.L	(A7)+,A0
	BSR.W	pt_SetCat
	LEA	set_Line2,A0
.sm:	MOVE.W	#SV_SCREENMODE_POS,D1
	MOVEQ	#SV_SCREENMODE_N,D0
	BSR.W	pt_SetPut
	LEA	gfx_Txt2x(PC),A0
	BSR.W	pt_GfxScaleCur
	BEQ.S	.sc
	LEA	gfx_Txt1x(PC),A0
	CMP.B	#2,D0
	BNE.S	.sc
	LEA	gfx_TxtFree(PC),A0
.sc:	MOVE.W	#SV_SCALE_POS,D1
	MOVEQ	#SV_SCALE_N,D0
	BSR.W	pt_SetPut
	MOVE.B	rtg_WaitAdj,D0
	EXT.W	D0
	MULU	#8,D0
	LEA	gfx_TxtFps(PC),A0
	ADDA.W	D0,A0
	MOVE.W	#SV_FPS_POS,D1
	MOVEQ	#SV_FPS_N,D0
	BSR.W	pt_SetPut
.rows:	BSR.W	pt_GfxRowsVal
	MOVE.W	D0,gfx_RowsShown
	LEA	set_TxtNA(PC),A0
	TST.L	D0
	BEQ.S	.rw
	LEA	set_Line2,A0
	BSR.W	pt_SetFmtNum
	LEA	set_Line2,A0
.rw:	MOVE.W	#SV_ROWS_POS,D1
	MOVEQ	#SV_ROWS_N,D0
	BSR.W	pt_SetPut
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

gfx_TxtOn:	DC.B	"SCREEN",0		; was "ON"
gfx_TxtWin:	DC.B	"WINDOW",0
gfx_TxtOff:	DC.B	"OFF",0
gfx_TxtStart:	DC.B	"STARTING",0
gfx_TxtNoMode:	DC.B	"OFF - NO CARD MODE",0
gfx_TxtAuto:	DC.B	"AUTO",0
gfx_TxtAuto2:	DC.B	"AUTO: ",0
gfx_TxtCard:	DC.B	"CARD MODE",0
gfx_Txt2x:	DC.B	"AMIGA 1:2",0
gfx_Txt1x:	DC.B	"PIXEL 1:1",0
gfx_TxtFree:	DC.B	"FREE (WINDOW)",0
gfx_TxtFps:	DC.B	"50 FPS",0,0,"25 FPS",0,0,"17 FPS",0,0,"12 FPS",0,0
gfx_MsgRows:	DC.B	"ROWS: ONLY IN THE RTG WINDOW",0
gfx_MsgRowsFree:	DC.B	"ROWS: ASPECT FREE, SIZE THE WINDOW",0
gfx_MsgLimit:	DC.B	"ROWS: AT THE LIMIT",0
gfx_MsgMode:	DC.B	"SCREENMODE: ONLY ON THE RTG SCREEN",0
gfx_MsgNoWin:	DC.B	"NO WINDOW: WB NOT ON A CARD",0
	DC.B	"NO WINDOW: WB TOO SMALL",0
	DC.B	"NO WINDOW: COULD NOT OPEN",0
	DC.B	"NO WINDOW: WB NEEDS 16 BIT",0
gfx_MsgOff:	DC.B	"SWITCH RTG ON FIRST",0
gfx_AskWide:	DC.B	10,10
	DC.B	"   Without RTG only",10
	DC.B	" tracks 1-8 stay. Switch?",0
prf_MsgNoSave:	DC.B	"CAN'T SAVE PT41.PREFS (WRITE PROTECTED?)",0
	EVEN

;--- prefs
; PROGDIR:PT41.prefs = IFF "FORM PT41", chunk "SET1" (28 bytes):
;   +0 output (0 auto, 1 paula, 2 ahi, 3 amigus)  +1 vol  +2 stereo
;   +3 rtg (0 off, $ff scr, 2 win)  +4 ahi mode (L)
;   +8 card mode (L, 0 = AUTO)  +12 aspect (0 amiga, $ff pixel, 2 free)
;   +13 fps ofs  +14 scheme (0 = 4.1, 1 = 2.3)  +15 chs (4/8)
;   +16 window left, top, inner w, h (words, 0 = default)
;   +24 note range (0 pt, $ff ext)  +25 midi (0 off, 1 all, 2..17 ch)
;   +26 on load (0 auto, $ff keep)  +27 ahi flt (0 off, 1 a1200, 2 a500)
; older files (16 or 24 byte chunk) still load
; read at start (before sound opens), SAVE CONFIG writes
; vol, stereo: reduction steps; mix rate lives in PT.config
PREFS_LEN	EQU	12+8+28
PREFS_BOX	EQU	12+8+24
PREFS_OLD	EQU	12+8+16
PREFS_MAX	EQU	64		; read: known part of longer files

pt_PrefsLoad41:
	TST.B	prf_Loaded
	BNE.W	.r
	ST	prf_Loaded
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVEA.L	dat_DosLibBase,A6
	MOVE.L	#prf_Name,D1
	MOVE.L	#1005,D2
	JSR	(-30,A6)
	MOVE.L	D0,D7
	BEQ.W	.x
	MOVE.L	D7,D1
	MOVE.L	#prf_Buf,D2
	MOVEQ	#PREFS_MAX,D3
	JSR	(-42,A6)
	MOVE.L	D0,D6
	MOVE.L	D7,D1
	JSR	(-36,A6)
	CMP.L	#PREFS_OLD,D6		; shorter: nothing usable
	BLT.W	.x
.len:	LEA	prf_Buf,A0
	CMPI.L	#'FORM',(A0)
	BNE.W	.x
	CMPI.L	#'PT41',8(A0)
	BNE.W	.x
	CMPI.L	#'SET1',12(A0)
	BNE.W	.x
	LEA	20(A0),A0
	MOVE.B	(A0)+,D0
	CMP.B	#4,D0			; 3 = amigus, 4 = zz9000ax (taken in pt_SetPoll)
	BHI.W	.x
	MOVE.B	D0,snd_Choice
	MOVE.B	(A0)+,D0
	CMP.B	#10,D0
	BHI.S	.v
	MOVE.B	D0,snd_VolDown
.v:	MOVE.B	(A0)+,D0
	CMP.B	#4,D0
	BHI.S	.s
	MOVE.B	D0,snd_StereoDown
.s:	MOVE.B	(A0)+,D0
	BEQ.S	.rt
	ST	rtg_Want
	CMP.B	#2,D0			; 2 = wb window
	BNE.S	.rt
	MOVE.B	#1,rtg_WinMode
.rt:	MOVE.L	(A0)+,snd_AhiMode
	MOVE.L	(A0)+,rtg_UserMode
	MOVE.B	(A0)+,D0		;41 aspect: 0, -1 or 2
	BEQ.S	.sc1
	CMP.B	#-1,D0
	BEQ.S	.sc1
	CMP.B	#2,D0
	BEQ.S	.sc1
	MOVEQ	#0,D0
.sc1:	MOVE.B	D0,rtg_Scale1x
	MOVE.B	(A0)+,D0
	CMP.B	#-1,D0
	BLT.S	.sch			; bad fps: keep, read on
	CMP.B	#3,D0
	BGT.S	.sch
	TST.B	D0			; old prefs: -1 was the fastest
	BPL.S	.fps
	MOVEQ	#0,D0
.fps:	MOVE.B	D0,rtg_WaitAdj
.sch:	MOVE.B	(A0)+,D0		; scheme
	CMP.B	#1,D0
	BHI.S	.f
	MOVE.B	D0,sch_Scheme
.f:	MOVE.B	(A0)+,prf_Chan		; ch cnt (4/8, 0 = unset)
	CMP.L	#PREFS_BOX,D6		; fields as far as the file goes
	BLT.S	.nobox
	MOVE.L	(A0)+,prf_WinBox
	MOVE.L	(A0)+,prf_WinBox+4
	CMP.L	#PREFS_LEN,D6
	BLT.S	.nobox
	MOVE.B	(A0)+,note_Ext41
	MOVE.B	(A0)+,D0
	CMP.B	#17,D0
	BHI.S	.nobox
	MOVE.B	D0,mid_Sel
	BSR.W	pt_MidiApply
	MOVE.B	(A0)+,prf_LoadKeep	; older files: 0 = auto
	MOVE.B	(A0)+,D0
	CMP.B	#2,D0
	BHI.S	.nobox
	MOVE.B	D0,ahi_FltMode
.nobox:	ST	prf_Found		; saved prefs present -> no auto setup
.x:	MOVEM.L	(A7)+,D0-D7/A0-A6
.r:	RTS

; replaces JSR pt_ClearStatusMsg after PT.config write (SAVE CONFIG)
pt_PrefsSave41:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	LEA	prf_Buf,A0
	MOVE.L	#'FORM',(A0)+
	MOVE.L	#PREFS_LEN-8,(A0)+
	MOVE.L	#'PT41',(A0)+
	MOVE.L	#'SET1',(A0)+
	MOVE.L	#PREFS_LEN-20,(A0)+
	MOVEQ	#0,D0
	TST.B	snd_Choice
	BEQ.S	.c
	MOVEQ	#1,D0
	TST.B	ahi_Active
	BEQ.S	.c
	MOVEQ	#2,D0
.c:	TST.B	agus_On
	BEQ.S	.c2
	MOVEQ	#3,D0
	TST.B	zzax_On
	BEQ.S	.c2
	MOVEQ	#4,D0
.c2:	TST.B	prf_AgusKeep		; amigus or zz9000ax saved, card missing or busy
	BEQ.S	.c3
	MOVEQ	#3,D0
	CMPI.B	#4,prf_AgusKeep
	BNE.S	.c3
	MOVEQ	#4,D0
.c3:	MOVE.B	D0,(A0)+
	MOVE.B	snd_VolDown,(A0)+
	MOVE.B	snd_StereoDown,(A0)+
	TST.L	rtg_Proc		; rtg running = $ff, 2 = window
	SNE	D0
	BEQ.S	.rw
	TST.B	rtg_WinMode
	BEQ.S	.rw
	MOVEQ	#2,D0
.rw:	MOVE.B	D0,(A0)+
	MOVE.L	snd_AhiMode,(A0)+
	MOVE.L	rtg_UserMode,(A0)+
	MOVE.B	rtg_Scale1x,(A0)+
	MOVE.B	rtg_WaitAdj,(A0)+
	MOVE.B	sch_Scheme,(A0)+
	MOVEQ	#8,D0			; ch cnt (dat_ModeFlags bit 5 = 4ch)
	TST.B	wide_On			; wide module in the rtg 4 track view: 8
	BNE.S	.c8
	BTST	#5,dat_ModeFlags
	BEQ.S	.c8
	MOVEQ	#4,D0
.c8:	MOVE.B	D0,(A0)+
	JSR	pt_RtgWinBox		; window running: its place and size
	MOVE.L	prf_WinBox,(A0)+
	MOVE.L	prf_WinBox+4,(A0)+
	MOVE.B	note_Ext41,(A0)+
	MOVE.B	mid_Sel,(A0)+
	MOVE.B	prf_LoadKeep,(A0)+	; 0 auto, $ff keep
	MOVE.B	ahi_FltMode,(A0)+
	MOVEA.L	dat_DosLibBase,A6
	MOVE.L	#prf_Name,D1
	MOVE.L	#1006,D2
	JSR	(-30,A6)
	MOVE.L	D0,D7
	BEQ.S	.no
	MOVE.L	D7,D1
	MOVE.L	#prf_Buf,D2
	MOVEQ	#PREFS_LEN,D3
	JSR	pt_Write41
	MOVE.L	D7,D1
	JSR	pt_CloseQuiet41
.x:	MOVEM.L	(A7)+,D0-D7/A0-A6
	JMP	pt_ClearStatusMsg
.no:	LEA	prf_MsgNoSave(PC),A0	; read-only drawer, cd, protected disk
	JSR	pt_StatusLater41
	BRA.S	.x

; replaces MOVEA.L dat_GfxLibBase,A0 in pt_0716 (start, RESET ALL)
pt_PrefsReset41:
	TST.B	set_Ready		; at start loaded prefs stay
	BEQ.W	.start
	MOVEM.L	D0-D1,-(A7)
	MOVE.L	rtg_UserMode,D0		; gfx values changed -> restart mirror
	OR.B	rtg_Scale1x,D0
	OR.B	rtg_WaitAdj,D0
	MOVE.L	D0,D1
	CLR.B	snd_VolDown
	CLR.B	snd_StereoDown
	SF	prf_LoadKeep		; ON LOAD: AUTO
	CLR.B	ahi_FltMode
	JSR	pt_CardFltReset41
	CLR.B	note_Ext41
	CLR.B	mid_Sel
	BSR.W	pt_MidiApply
	BCLR	#5,dat_ModeFlags	; default config set the 4ch bit without the
	CMPI.W	#4,dat_RpNumChannels	; switch: keep the mode that runs (channels
	BNE.S	.ch			; live in PT41.prefs; LOAD CONFIG switches)
	BSET	#5,dat_ModeFlags
.ch:	CLR.B	sch_Scheme		; RESET ALL loads default palette -> scheme 4.1
	CLR.B	rtg_Scale1x
	CLR.B	rtg_WaitAdj
	CLR.L	rtg_UserMode
	MOVE.L	snd_AhiMode,D0
	CLR.L	snd_AhiMode
	SF	snd_NameOk
	BSR.W	pt_SndApplyVol
	TST.L	D0			; ahi mode chosen + ahi running -> reopen with default
	BEQ.S	.g
	TST.B	ahi_Active
	BEQ.S	.g
	JSR	pt_AhiClose
	SF	ahi_Failed
	JSR	pt_AhiOpen
.g:	TST.L	D1
	BEQ.S	.r
	BSR.W	pt_GfxRestart
.r:	MOVEM.L	(A7)+,D0-D1
.start:	MOVEA.L	dat_GfxLibBase,A0
	RTS

prf_Name:	DC.B	"PROGDIR:PT41.prefs",0
	EVEN

;--- first run auto setup
; no prefs/tooltype/switch file: amigus card first (native, even if ahi
; points to it), else ahi if the default mode works and is not paula's,
; else paula; rtg mirror if a card mode exists; status "AUTO SETUP: ..."

; from pt_AhiAudioDevOpen (before pt_AhiDetect)
pt_AutoAhi:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.B	prf_Found
	BNE.W	.r
	TST.B	ahi_Want		; tooltype AHI
	BNE.W	.r
	TST.B	snd_Choice
	BNE.W	.r
	IFD	FAKEAGUSBOOT
	ST	dbg_FakeAgus		;41 test: card present before the auto setup
	ENDC
	JSR	pt_AgusDetect		;41 card needs no 68020, taken like saved output amigus
	TST.L	agus_Card
	BEQ.S	.noag
	MOVE.B	#3,snd_Choice
	ST	prf_AutoAgus
	BRA.W	.r
.noag:	JSR	pt_ZzaxDetect		;41 then the zz9000ax (voice engine library), the same way
	TST.L	zzax_Card
	BEQ.S	.nozx
	MOVE.B	#4,snd_Choice
	MOVE.B	#2,prf_AutoAgus
	BRA.W	.r
.nozx:	MOVEA.L	ABSEXECBASE.W,A6
	BTST	#1,(297,A6)		;41 ahi needs a 68020
	BEQ.W	.r
; read ENV:Sys/ahi.prefs without dos requester (pr_WindowPtr not -1 yet)
	SUBA.L	A1,A1
	JSR	(-294,A6)
	MOVEA.L	D0,A5
	MOVE.L	184(A5),-(A7)		; save pr_WindowPtr
	MOVE.L	#-1,184(A5)
	MOVEA.L	dat_DosLibBase,A6
	MOVE.L	#aut_AhiPrefs,D1
	MOVE.L	#1005,D2
	JSR	(-30,A6)
	MOVE.L	(A7)+,184(A5)
	MOVE.L	D0,D7
	BEQ.W	.r
	MOVE.L	D7,D1
	MOVE.L	#aut_Buf,D2
	MOVE.L	#256,D3
	JSR	(-42,A6)
	MOVE.L	D0,D6
	MOVE.L	D7,D1
	JSR	(-36,A6)
	CMP.L	#12,D6
	BLT.W	.r
	LEA	aut_Buf,A0
	CMPI.L	#'FORM',(A0)
	BNE.W	.r
	LEA	12(A0),A1		; first chunk
	LEA	(A0,D6.L),A2		; end
	MOVEQ	#0,D5			; mode unit 0
	MOVEQ	#0,D4			; mode music unit (255)
.ch:	LEA	8(A1),A3
	CMPA.L	A2,A3
	BHI.S	.got
	MOVE.L	4(A1),D0		; len
	CMPI.L	#'AHIU',(A1)
	BNE.S	.nx
	MOVE.L	12(A1),D1
	TST.B	8(A1)
	BNE.S	.u255
	MOVE.L	D1,D5
	BRA.S	.nx
.u255:	CMPI.B	#255,8(A1)
	BNE.S	.nx
	MOVE.L	D1,D4
.nx:	ADDQ.L	#1,D0
	BCLR	#0,D0			; even len
	LEA	8(A1,D0.L),A1
	BRA.S	.ch
.got:	TST.L	D4
	BNE.S	.mode
	MOVE.L	D5,D4
.mode:	TST.L	D4
	BEQ.W	.r
; mode name
	BSR.W	pt_SndAhiBase
	BEQ.W	.r
	LEA	snd_Tags,A1
	MOVE.L	#AHIDB_Name,(A1)
	MOVE.L	#aut_Name,4(A1)
	MOVE.L	#AHIDB_BufferLen,8(A1)
	MOVE.L	#32,12(A1)
	CLR.L	16(A1)
	CLR.B	aut_Name
	MOVE.L	D4,D0
	SUBA.L	A2,A2
	JSR	(_LVOAHI_GetAudioAttrsA,A6)
	BSR.W	pt_SndAhiFree
; paula driver: paula direct stays (exact, less cpu); else ahi
	LEA	aut_Name,A0
	BSR.S	pt_AutoUpper3
	CMP.L	#'PAU'<<8,D0
	BEQ.S	.r
	TST.L	D0
	BEQ.S	.r
	MOVE.B	#2,snd_Choice
	MOVE.B	#2,snd_StereoDown	; ahi default stereo 50 %
	ST	prf_AutoAhi
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; d0 = first 3 chars of (a0) upper case, <<8 (0 if empty)
pt_AutoUpper3:
	MOVEQ	#0,D0
	MOVEQ	#2,D2
.l:	MOVE.B	(A0)+,D1
	BEQ.S	.e
	CMP.B	#'a',D1
	BCS.S	.u
	CMP.B	#'z',D1
	BHI.S	.u
	SUB.B	#32,D1
.u:	LSL.L	#8,D0
	MOVE.B	D1,D0
	DBF	D2,.l
	LSL.L	#8,D0
	RTS
.e:	MOVEQ	#0,D0
	RTS

; from pt_RtgPoll (68020, no tooltype/switch file): Z=0 + rtg_Want = start
pt_AutoRtg:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	TST.B	prf_Found
	BNE.S	.no
	TST.L	x20_Base
	BEQ.S	.no
	MOVEA.L	dat_GfxLibBase,A6
	MOVE.L	#512,D0
	JSR	pt_RtgFindMode
	CMP.L	#-1,D0
	BNE.S	.yes
	MOVE.L	#480,D0
	JSR	pt_RtgFindMode
	CMP.L	#-1,D0
	BEQ.S	.no
.yes:	ST	rtg_Want
	ST	prf_AutoRtg
	BSR.W	pt_AutoRtgWin		; wb on card and big enough -> window
	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	ANDI	#$fb,CCR
	RTS

.no:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	ORI	#4,CCR
	RTS

; pubscreen on card (id >= $00100000) and >= 800x600 -> rtg_WinMode = 1
pt_AutoRtgWin:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVEA.L	ABSEXECBASE.W,A6
	LEA	aut_CgxName(PC),A1
	MOVEQ	#41,D0
	JSR	(-552,A6)
	MOVE.L	D0,D6
	BEQ.S	.r
	MOVEA.L	dat_IntuiLibBase,A6
	SUBA.L	A0,A0
	JSR	(-510,A6)
	MOVE.L	D0,D7
	BEQ.S	.cl
	MOVEA.L	D0,A0
	CMPI.W	#800,12(A0)
	BCS.S	.un
	CMPI.W	#600,14(A0)
	BCS.S	.un
	LEA	44(A0),A0
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-792,A6)		; GetVPModeID: card mode >= $00100000
	CMP.L	#$00100000,D0
	BCS.S	.un0
	MOVE.B	#1,rtg_WinMode
.un0:	MOVEA.L	dat_IntuiLibBase,A6
.un:	SUBA.L	A0,A0
	MOVEA.L	D7,A1
	JSR	(-516,A6)
.cl:	MOVEA.L	ABSEXECBASE.W,A6
	MOVEA.L	D6,A1
	JSR	(-414,A6)
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; from pt_SetPoll: report "AUTO SETUP: ..." once after ~2 s
pt_AutoMsg:
	TST.B	prf_MsgDone
	BNE.W	.r
	ADDQ.W	#1,prf_MsgCnt
	CMPI.W	#100,prf_MsgCnt
	BCS.W	.r
	ST	prf_MsgDone
	MOVE.B	prf_AutoAhi,D0
	OR.B	prf_AutoRtg,D0
	OR.B	prf_AutoAgus,D0
	BEQ.S	.r
	MOVEM.L	D0-D1/A0-A1,-(A7)
	TST.B	prf_AutoAgus
	BEQ.S	.ahi
	LEA	aut_MsgAgusR(PC),A0
	CMPI.B	#2,prf_AutoAgus		; zz9000ax
	BNE.S	.ag
	LEA	aut_MsgZzaxR(PC),A0
.ag:	TST.B	prf_AutoRtg
	BNE.S	.show
	LEA	aut_MsgAgus(PC),A0
	CMPI.B	#2,prf_AutoAgus
	BNE.S	.show
	LEA	aut_MsgZzax(PC),A0
	BRA.S	.show
.ahi:	LEA	aut_MsgBoth(PC),A0
	TST.B	prf_AutoAhi
	BEQ.S	.rtg
	TST.B	prf_AutoRtg
	BNE.S	.show
	LEA	aut_MsgAhi(PC),A0
	BRA.S	.show
.rtg:	LEA	aut_MsgRtg(PC),A0
	TST.B	rtg_WinMode
	BEQ.S	.show
	LEA	aut_MsgRtgW(PC),A0
.show:	JSR	pt_ShowStatusMsg
	MOVEM.L	(A7)+,D0-D1/A0-A1
.r:	RTS

aut_AhiPrefs:	DC.B	"ENV:Sys/ahi.prefs",0
aut_MsgBoth:	DC.B	"AUTO SETUP: AHI + RTG",0
aut_MsgAhi:	DC.B	"AUTO SETUP: AHI SOUND CARD",0
aut_MsgRtg:	DC.B	"AUTO SETUP: RTG SCREEN",0
aut_MsgRtgW:	DC.B	"AUTO SETUP: RTG WINDOW",0
aut_MsgAgus:	DC.B	"AUTO SETUP: AMIGUS SOUND CARD",0
aut_MsgAgusR:	DC.B	"AUTO SETUP: AMIGUS + RTG",0
aut_MsgZzax:	DC.B	"AUTO SETUP: ZZ9000AX VOICES",0
aut_MsgZzaxR:	DC.B	"AUTO SETUP: ZZ9000AX + RTG",0
aut_CgxName:	DC.B	"cybergraphics.library",0
aut_HintAuto:	DC.B	"AUTO SETUP - SAVE CONFIG TO KEEP IT",0
	EVEN

;--- color scheme
; design 4.1 / 2.3 (pg SYSTEM): 2.3 = PT 2.3D colors: 8 base, 48 line vu
; gradient, idle ptr; mode ptr colors (play, edit, rec, diskop) as 2.3;
; only idle ptr differs. Sets laid out as SCRN chunk +16 (8 col, 48 grad);
; 4.1 set = builtin default in str_VersionTag2. Switch loads set, own pal
; only after confirm. Start: PT.config pal; 2.3 only if it has 4.1 default
; and scheme 2.3 is saved
sch_Set41	EQU	str_VersionTag2+$98	; builtin config SCRN chunk +16

; gad DESIGN
pt_SchGadget:
	JSR	pt_WaitMouseRelease
	MOVEM.L	D0-D7/A0-A6,-(A7)
	BSR.W	pt_SchSet		; a1 = set of old scheme
	BSR.W	pt_SchSame		; palette = its default?
	SEQ	D7
	EORI.B	#1,sch_Scheme
	TST.B	D7
	BNE.S	.load
	JSR	pt_InitAudioDisplay	; clear value plane (shows through dialog)
	LEA	sch_Ask(PC),A0		; own palette: replace?
	JSR	pt_ShowYesNoDialog
	SEQ	D6
	BSR.W	pt_SchPointer
	TST.B	D6
	BEQ.S	.redraw
	BSR.W	pt_SchSet
	BSR.W	pt_SchApply
.redraw:
	MOVEM.L	(A7)+,D0-D7/A0-A6
	JMP	pt_UIUpdatePaletteMode	; redraw (pt_SetRedrawSel)
.load:	BSR.W	pt_SchSet
	BSR.W	pt_SchApply
	BSR.W	pt_SchPointer
	BSR.W	pt_SchDraw
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; first main pass (pt_SetPoll): 2.3 saved + pal = 4.1 default -> 2.3 set
pt_SchStart:
	TST.B	sch_Scheme
	BEQ.S	.r
	MOVEM.L	D0-D7/A0-A6,-(A7)
	LEA	sch_Set41,A1
	BSR.S	pt_SchSame
	BNE.S	.p
	BSR.S	pt_SchSet
	BSR.S	pt_SchApply
.p:	BSR.W	pt_SchPointer
	MOVEM.L	(A7)+,D0-D7/A0-A6
.r:	RTS

; a1 = color set of current scheme
pt_SchSet:
	LEA	sch_Set41,A1
	TST.B	sch_Scheme
	BEQ.S	.r
	LEA	sch_Set23(PC),A1
.r:	RTS

; Z=1 if base colors + vu gradient equal set a1
pt_SchSame:
	MOVEM.L	D0/A0-A1,-(A7)
	LEA	dat_ScopeWorkBuf,A0
	MOVEQ	#7,D0
.c:	CMPM.W	(A0)+,(A1)+
	DBNE	D0,.c
	BNE.S	.r
	LEA	dat_PaletteEditBuf,A0
	MOVEQ	#47,D0
.v:	CMPM.W	(A0)+,(A1)+
	DBNE	D0,.v
.r:	MOVEM.L	(A7)+,D0/A0-A1
	RTS

; load set a1: base colors, vu gradient, copper (pt_CheckDiskOpCont)
pt_SchApply:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	LEA	dat_ScopeWorkBuf,A0
	MOVEQ	#7,D0
.c:	MOVE.W	(A1)+,(A0)+
	DBF	D0,.c
	LEA	dat_PaletteEditBuf,A0
	MOVEQ	#47,D0
.v:	MOVE.W	(A1)+,(A0)+
	DBF	D0,.v
	JSR	pt_CheckDiskOpCont
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; pointer shows idle pointer of other scheme -> set again
pt_SchPointer:
	MOVEM.L	D0/A0-A1,-(A7)
	MOVEA.L	dat_PalettePtr,A0
	LEA	sch_Ptr41(PC),A1	; idle pointer of other scheme
	TST.B	sch_Scheme
	BNE.S	.t
	LEA	sch_Ptr23(PC),A1
.t:	MOVE.W	(A1),D0
	CMP.W	2(A0),D0
	BNE.S	.r
	MOVE.W	4(A1),D0
	CMP.W	10(A0),D0
	BNE.S	.r
	JSR	pt_SetPaletteBright
.r:	MOVEM.L	(A7)+,D0/A0-A1
	RTS

; replaces body of pt_SetPaletteBright (idle ptr, COLOR17-19)
pt_SchPtrNormal:
	MOVEM.L	A0-A1,-(A7)
	MOVEA.L	dat_PalettePtr,A0
	LEA	sch_Ptr41(PC),A1
	TST.B	sch_Scheme
	BEQ.S	.s
	LEA	sch_Ptr23(PC),A1
.s:	MOVE.W	(A1)+,2(A0)
	MOVE.W	(A1)+,6(A0)
	MOVE.W	(A1)+,10(A0)
	MOVEM.L	(A7)+,A0-A1
	RTS

; replaces MOVEA.L (dat_FileIOVar1,PC),A0 / LEA dat_ScopeWorkBuf,A1:
; pt_BtnSetupPalDef: DEF loads scheme default, DEF1-6 presets stay
pt_SchDefCol:
	MOVEA.L	dat_FileIOVar1,A0
	BSR.S	pt_SchDefSrc
	LEA	dat_ScopeWorkBuf,A1
	RTS

; replaces MOVEA.L (dat_PalEdDataPtr,PC),A0 / (dat_FileIOVar2,PC),A1
pt_SchDefVu:
	MOVEA.L	dat_FileIOVar2,A0
	BSR.S	pt_SchDefSrc
	BEQ.S	.k
	LEA	16(A0),A0		; set+16 = gradient
.k:	MOVEA.L	A0,A1
	MOVEA.L	dat_PalEdDataPtr,A0
	RTS

; a0=src; scheme 2.3, no preset -> a0 = 2.3 set, Z=0; else keep, Z=1
pt_SchDefSrc:
	TST.B	sch_Scheme
	BEQ.S	.r
	CMPA.L	#dat_1475,A0
	BCS.S	.s
	CMPA.L	#dat_147B,A0
	BCS.S	.k
.s:	LEA	sch_Set23(PC),A0
	MOVE.W	#0,CCR
	RTS
.k:	CMP.W	D0,D0
.r:	RTS

; design value (page SYSTEM)
; notes: PT = c-1..b-3 as ever, EXT = octave 4 on the keys above b-3
; (f2), 1xx/2xx/3xx up to b-4/c-0
pt_NoteGadget:
	JSR	pt_WaitMouseRelease
	NOT.B	note_Ext41
	LEA	note_MsgPt(PC),A0
	TST.B	note_Ext41
	BEQ.S	.m
	LEA	note_MsgExt(PC),A0
.m:	JSR	pt_ShowStatusMsg
pt_NoteDraw:
	MOVEM.L	D0-D1/A0,-(A7)
	LEA	note_TxtPt(PC),A0
	TST.B	note_Ext41
	BEQ.S	.d
	LEA	note_TxtExt(PC),A0
.d:	MOVE.W	#SV_NOTES_POS,D1
	MOVEQ	#SV_NOTES_N,D0
	BSR.W	pt_SetPut
	MOVEM.L	(A7)+,D0-D1/A0
	RTS
;--- midi in: off / all channels / channel 1-16
pt_MidiUp:
	MOVEQ	#1,D0
	BRA.S	pt_MidiStep
pt_MidiDn:
	MOVEQ	#-1,D0
pt_MidiStep:
	ADD.B	mid_Sel,D0
	BPL.S	.lo
	MOVEQ	#0,D0
.lo:	CMP.B	#17,D0
	BLS.S	.hi
	MOVEQ	#17,D0
.hi:	MOVE.B	D0,mid_Sel
	BSR.S	pt_MidiApply
	BSR.W	pt_SndWait
	BRA.S	pt_MidiDraw

; mid_Sel -> port on/off; in use: message, off
pt_MidiApply:
	MOVEM.L	D0/A0,-(A7)
	MOVE.B	mid_Sel,D0
	BNE.S	.on
	JSR	pt_MidiOff
	BRA.S	.r
.on:	SUBQ.B	#1,D0
	MOVE.B	D0,mid_Chan
	JSR	pt_MidiOn
	TST.L	D0
	BEQ.S	.r
	CLR.B	mid_Sel
	LEA	mid_MsgBusy(PC),A0
	JSR	pt_ShowStatusMsg
.r:	MOVEM.L	(A7)+,D0/A0
	RTS

pt_MidiDraw:
	MOVEM.L	D0-D1/A0-A1,-(A7)
	LEA	mid_TxtOff(PC),A0
	MOVEQ	#0,D0
	MOVE.B	mid_Sel,D0
	BEQ.S	.d
	LEA	mid_TxtAll(PC),A0
	SUBQ.B	#1,D0
	BEQ.S	.d
	LEA	set_Line2,A1
	CLR.B	(A1)
	LEA	mid_TxtCh(PC),A0
	BSR.W	pt_SetCat
	MOVEA.L	A1,A0
	BSR.W	pt_SetFmtNum
	LEA	set_Line2,A0
.d:	MOVE.W	#SV_MIDI_POS,D1
	MOVEQ	#SV_MIDI_N,D0
	BSR.W	pt_SetPut
	MOVEM.L	(A7)+,D0-D1/A0-A1
	RTS
mid_TxtOff:	DC.B	"OFF",0
mid_TxtAll:	DC.B	"ALL",0
mid_TxtCh:	DC.B	"CH",0
mid_MsgBusy:	DC.B	"MIDI: SERIAL PORT IN USE",0
	EVEN

note_TxtPt:	DC.B	"PT",0
note_TxtExt:	DC.B	"EXT",0
note_MsgPt:	DC.B	"NOTES C-1..B-3 (STANDARD)",0
note_MsgExt:	DC.B	"NOTES C-0..B-4 (EXTENDED)",0
	EVEN

pt_SchDraw:
	MOVEM.L	D0-D1/A0,-(A7)
	LEA	sch_Txt41(PC),A0
	TST.B	sch_Scheme
	BEQ.S	.d
	LEA	sch_Txt23(PC),A0
.d:	MOVE.W	#SV_DESIGN_POS,D1
	MOVEQ	#SV_DESIGN_N,D0
	BSR.W	pt_SetPut
	MOVEM.L	(A7)+,D0-D1/A0
	RTS

; color set 2.3: defaults of ProTracker 2.3D (base colors, gradient)
sch_Set23:
	DC.W	$0000,$0bbb,$0888,$0555,$0fd0,$0d04,$0000,$034f
	DC.W	$0f00,$0f00,$0f10,$0f10,$0f20,$0f20,$0f30,$0f30,$0f40,$0f50,$0f60,$0f70
	DC.W	$0f80,$0f90,$0fa0,$0fb0,$0fc0,$0fd0,$0fe0,$0ff0,$0ff0,$0ef0,$0ef0,$0df0
	DC.W	$0df0,$0cf0,$0cf0,$0bf0,$0bf0,$0af0,$09f0,$09f0,$08f0,$08f0,$07f0,$07f0
	DC.W	$06f0,$06f0,$05f0,$05f0,$04f0,$04f0,$03f0,$03f0,$02f0,$01f0,$00f0,$00e0
	DC.W	$0254			; 49th word: pt_PalEdCopyFromMod copies 49 words (word after 4.1 default)
; idle ptr in COLOR17,18,19 order: 4.1 own, 2.3 grey ($aaa/$777/$444)
sch_Ptr41:	DC.W	$0e44,$0000,$0eec
sch_Ptr23:	DC.W	$0777,$0444,$0aaa
sch_Txt41:	DC.B	"4.1",0
sch_Txt23:	DC.B	"2.3",0
sch_Ask:	DC.B	10,10
	DC.B	"  Replace the palette",10
	DC.B	"  with the colours of",10
	DC.B	"   the chosen design?",0
	EVEN
