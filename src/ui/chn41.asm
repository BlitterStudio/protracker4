; channel count (setup CHANNELS arrows): 1-8 in pt's 8ch buffer, 9-32 as a
; wide module (amigus output); fewer tracks ask before notes go

CHN_MAX		EQU	32
CHN_ASKN	EQU	16		; place of the number in chn_AskT

; -> d0.w = channels of the song
pt_ChnNow41:
	TST.B	wide_On
	BEQ.S	.t
	MOVE.W	wide_Ch,D0
	RTS
.t:	JMP	pt_TrkN41

; setup arrows: d2.w = +1 / -1 (card 1-32; else 4ch mode: none, 8ch mode
; 1-8, down from 1 wraps to 8; up never cuts tracks)
pt_ChnStep41:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.B	snd_Defer		; output switch pending: not now
	BNE.W	.x
	BSR.W	pt_ChnNow41
	MOVE.W	D0,D3			; d3 = old
	MOVE.W	D0,D4
	ADD.W	D2,D4			; d4 = new
	TST.B	agus_On
	BNE.S	.card
	BTST	#5,dat_ModeFlags
	BEQ.S	.p8
	LEA	chn_Msg4(PC),A0		; 4ch mode: the name switches it
	BRA.S	.m
.p8:	TST.W	D4
	BGT.S	.p1
	MOVEQ	#8,D4
.p1:	CMP.W	#8,D4
	BLS.S	.go
	LEA	chn_MsgNoCard(PC),A0
	BSR.W	pt_CardAny41		; card there: how to get more
	BEQ.S	.m
	LEA	chn_MsgCard(PC),A0
	BSR.W	pt_CardStr41
	BRA.S	.m
.card:	LEA	chn_MsgMin(PC),A0
	TST.W	D4
	BLE.S	.m
	LEA	chn_MsgMax(PC),A0
	CMP.W	#CHN_MAX,D4
	BLS.S	.go
.m:	BSR.W	pt_ChnMsg41
	BRA.W	.w
.go:	SF	D7			; d7 = cut the tracks that go (asked)
	CMP.W	D3,D4
	BEQ.W	.w
	BCC.S	.do
	MOVE.W	D4,D0			; fewer: notes in the tracks that go?
	MOVE.W	D3,D1
	BSR.W	pt_ChnUsed41
	BEQ.S	.do
	BSR.W	pt_ChnAsk41
	BNE.W	.w
	ST	D7
.do:	TST.B	wide_On
	BEQ.S	.nw
	CMP.W	#9,D4
	BCS.S	.w8
	BSR.W	pt_ChnWideSet41
	BRA.S	.ok
.w8:	BSR.W	pt_ChnWideTo8_41
	BNE.S	.w
	BRA.S	.ok
.nw:	BTST	#5,dat_ModeFlags
	BEQ.S	.n8
	BSR.W	pt_ChnTo8_41		; 4ch mode, card: pt's 8ch buffer
	BNE.S	.w
	BRA.S	.ok
.n8:	CMP.W	#9,D4
	BCC.S	.wd
	TST.B	D7
	BEQ.S	.s8
	MOVE.W	D4,D0
	MOVE.W	D3,D1
	BSR.W	pt_ChnCutView41
.s8:	MOVE.B	D4,trk_Show
	JSR	pt_TrkClamp41
	JSR	pt_PatViewDrawAll
	BRA.S	.ok
.wd:	BSR.W	pt_ChnToWide41
	BNE.S	.w
.ok:	MOVE.L	#'CHG!',dat_SongChangedMagic	; the count is part of the song
	JSR	pt_0641
	JSR	pt_ReturnFromPlay
.w:	JSR	pt_SndWait
.x:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; a0 = status text
pt_ChnMsg41:
	IFD	DEBUGAUTO
	MOVE.L	A0,dbg_ChnMsg
	ENDC
	JMP	pt_ShowStatusMsg

; d4 = new count: "tracks after nn hold notes" -> z=1 yes
pt_ChnAsk41:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	IFD	DEBUGAUTO
	ADDQ.W	#1,dbg_ChnAsk
	ENDC
	LEA	chn_AskT(PC),A0
	LEA	chn_Ask,A1
.c:	MOVE.B	(A0)+,(A1)+
	BNE.S	.c
	MOVEQ	#0,D0
	MOVE.W	D4,D0
	DIVU	#10,D0
	ADD.B	#'0',D0
	CMP.B	#'0',D0
	BNE.S	.t
	MOVE.B	#' ',D0
.t:	MOVE.B	D0,chn_Ask+CHN_ASKN
	SWAP	D0
	ADD.B	#'0',D0
	MOVE.B	D0,chn_Ask+CHN_ASKN+1
	LEA	chn_Ask,A0
	JSR	pt_ShowYesNoDialog
	MOVEM.L	(A7)+,D0-D7/A0-A6	; flags stay
	RTS

; d0 = first, d1 = end track -> z=1 no cell in a pattern, else d2 = track
pt_ChnUsed41:
	TST.B	wide_On
	BNE.S	pt_ChnWideUsed41
; pt's buffer (4 or 8 tracks a row): slots d0..d1-1
pt_ChnViewUsed41:
	MOVEM.L	D3-D7/A0,-(A7)
	BSR.W	pt_ChnRows41		; d7 = rows, d6 = row bytes
	MOVEQ	#0,D3
	MOVEA.L	dat_ModulePtr,A0
	LEA	mod_patterns(A0),A0
	BRA.S	.n
.r:	MOVE.W	D0,D5
.t:	MOVE.W	D5,D4
	LSL.W	#2,D4
	TST.L	(A0,D4.W)
	BNE.S	.f
	ADDQ.W	#1,D5
	CMP.W	D1,D5
	BCS.S	.t
	ADDA.W	D6,A0
.n:	SUBQ.L	#1,D7
	BPL.S	.r
	BRA.S	.x
.f:	MOVE.W	D5,D2
	MOVEQ	#1,D3
.x:	TST.W	D3
	MOVEM.L	(A7)+,D3-D7/A0
	RTS

; wide: channels d0..d1-1 over wide_Pat, the view written back first;
; no memory to take every pattern in: counts as used
pt_ChnWideUsed41:
	MOVEM.L	D3-D7/A0,-(A7)
	JSR	pt_WideGrowView		; view patterns into wide_Pat's reach
	BEQ.S	.y
	JSR	pt_WideFlush
	MOVE.L	wide_PatSize,D7
	LSR.L	#7,D7			; rows
	MOVEQ	#0,D3
	MOVEA.L	wide_Pat,A0
	BRA.S	.n
.r:	MOVE.W	D0,D5
.t:	MOVE.W	D5,D4
	LSL.W	#2,D4
	TST.L	(A0,D4.W)
	BNE.S	.f
	ADDQ.W	#1,D5
	CMP.W	D1,D5
	BCS.S	.t
	LEA	WIDE_ROW(A0),A0
.n:	SUBQ.L	#1,D7
	BPL.S	.r
	BRA.S	.x
.y:	MOVE.W	D0,D5
.f:	MOVE.W	D5,D2
	MOVEQ	#1,D3
.x:	TST.W	D3
	MOVEM.L	(A7)+,D3-D7/A0
	RTS

; -> d7 = rows of pt's buffer, d6 = bytes a row (16 4ch, 32 8ch)
pt_ChnRows41:
	MOVE.L	D3,-(A7)
	MOVEQ	#16,D6
	MOVEQ	#10,D3
	BTST	#5,dat_ModeFlags
	BNE.S	.w
	MOVEQ	#32,D6
	MOVEQ	#11,D3
.w:	MOVE.L	dat_SampleEditCfg,D7
	SUB.L	#mod_patterns,D7
	LSR.L	D3,D7
	LSL.L	#6,D7
	MOVE.L	(A7)+,D3
	RTS

; d0 = first, d1 = end slot: those cells of pt's buffer cleared
pt_ChnCutView41:
	MOVEM.L	D2-D7/A0-A1,-(A7)
	MOVE.W	#-1,trk_UndoPat		; no undo into tracks that are gone
	CLR.W	trk_UndoGrp
	BSR.S	pt_ChnRows41
	MOVEA.L	dat_ModulePtr,A0
	LEA	mod_patterns(A0),A0
	MOVE.W	D0,D4
	LSL.W	#2,D4			; first byte
	MOVE.W	D1,D5
	SUB.W	D0,D5
	SUBQ.W	#1,D5			; cells - 1
	BMI.S	.x
	BRA.S	.n
.r:	LEA	(A0,D4.W),A1
	MOVE.W	D5,D2
.c:	CLR.L	(A1)+
	DBF	D2,.c
	ADDA.W	D6,A0
.n:	SUBQ.L	#1,D7
	BPL.S	.r
.x:	MOVEM.L	(A7)+,D2-D7/A0-A1
	RTS

; wide: channels d0..d1-1 cleared in wide_Pat and in the view
pt_ChnWideCut41:
	MOVEM.L	D0-D7/A0-A1,-(A7)
	ST	trk_Swap		; replayer: view not written back now
	MOVE.W	#-1,trk_UndoPat
	CLR.W	trk_UndoGrp
	MOVE.L	wide_PatSize,D7
	LSR.L	#7,D7
	MOVEA.L	wide_Pat,A0
	MOVE.W	D0,D4
	LSL.W	#2,D4
	MOVE.W	D1,D5
	SUB.W	D0,D5
	SUBQ.W	#1,D5
	BMI.S	.v
	BRA.S	.n
.r:	LEA	(A0,D4.W),A1
	MOVE.W	D5,D2
.c:	CLR.L	(A1)+
	DBF	D2,.c
	LEA	WIDE_ROW(A0),A0
.n:	SUBQ.L	#1,D7
	BPL.S	.r
.v:	MOVE.W	trk_Grp,D2		; view: slot = channel - 4 * group
	LSL.W	#2,D2
	SUB.W	D2,D0
	BPL.S	.a
	MOVEQ	#0,D0
.a:	SUB.W	D2,D1
	MOVEQ	#4,D3
	BTST	#5,dat_ModeFlags
	BNE.S	.b
	MOVEQ	#8,D3
.b:	CMP.W	D3,D1
	BLE.S	.e
	MOVE.W	D3,D1
.e:	CMP.W	D1,D0
	BGE.S	.x
	BSR.W	pt_ChnCutView41
.x:	SF	trk_Swap
	MOVEM.L	(A7)+,D0-D7/A0-A1
	RTS

pt_ChnPause41:
	SF	chn_Paused
	TST.L	dat_RpPlayMode
	BEQ.S	.r
	ST	chn_Paused
	MOVEM.L	D0-D7/A0-A6,-(A7)
	JSR	pt_SndPause
	MOVEM.L	(A7)+,D0-D7/A0-A6
.r:	RTS

; song block after realloc (cleared): len 1, restart 127, m.k., replen 1
pt_NewBlk41:
	MOVE.L	dat_ModulePtr,D0
	BEQ.S	.d
	MOVEA.L	D0,A0
	MOVE.W	#$017f,mod_songlen(A0)
	MOVE.L	#"M.K.",mod_id(A0)
	LEA	mod_samples+s_replen(A0),A0
	MOVEQ	#30,D0
.l:	MOVE.W	#1,(A0)
	LEA	s_SIZEOF(A0),A0
	DBF	D0,.l
.d:	JMP	pt_DrawSampleHex

pt_ChnResume41:
	TST.B	chn_Paused
	BEQ.S	.r
	SF	chn_Paused
	MOVE.B	#3,snd_ResDefer		; pt_SetPoll goes on at the row
.r:	RTS

; 4ch mode (card) -> 8ch buffer, the song stays; d4 = tracks (1..8),
; d7.b = cut slots d4..3. z=1 done
pt_ChnTo8_41:
	MOVEM.L	D1-D7/A0-A6,-(A7)
	MOVE.L	dat_SampleEditCfg,D6	; d6 = old size
	MOVE.L	D6,D5
	SUB.L	#mod_patterns,D5
	ADD.L	D5,D5
	ADD.L	#mod_patterns,D5	; d5 = same patterns, 32 bytes a row
	MOVEQ	#0,D0
	MOVEQ	#4,D1
	BSR.W	pt_ChnViewUsed41
	SEQ	D3			; d3 = no cell at all
	BSR.W	pt_ChnPause41
	MOVEA.L	ABSEXECBASE.W,A6
	TST.B	D3
	BEQ.W	.keep
	MOVEA.L	dat_ModulePtr,A0	; empty: old block first (1 mb machines)
	LEA	wide_Hdr,A1
	MOVE.W	#mod_patterns/4-1,D1
.sh:	MOVE.L	(A0)+,(A1)+
	DBF	D1,.sh
	JSR	(-132,A6)		; Forbid: the freed block stays ours
	MOVEA.L	dat_ModulePtr,A1
	MOVE.L	D6,D0
	JSR	(-210,A6)		; FreeMem
	BSR.W	.alloc
	BNE.S	.e1
	MOVE.L	D6,D5			; no room: the old block again
	MOVE.L	D6,D0
	MOVE.L	#$10001,D1
	JSR	(-198,A6)
	MOVEA.L	D0,A3
	MOVE.L	A3,dat_ModulePtr
	JSR	(-138,A6)		; Permit
	BSR.W	.hdr
	BRA.W	.nm
.e1:	MOVEA.L	D0,A3
	JSR	(-138,A6)		; Permit
	BSR.W	.hdr
	BRA.S	.set
.keep:	BSR.W	.alloc
	BEQ.W	.nm
	MOVEA.L	D0,A3
	MOVEA.L	dat_ModulePtr,A0	; header, rows: tracks 1-4, 5-8 stay 0
	MOVEA.L	A3,A1
	MOVE.W	#mod_patterns/4-1,D1
.h:	MOVE.L	(A0)+,(A1)+
	DBF	D1,.h
	MOVE.L	D5,D1
	SUB.L	#mod_patterns,D1
	LSR.L	#5,D1			; rows of the new block
	BRA.S	.r1
.r:	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	LEA	16(A1),A1
.r1:	SUBQ.L	#1,D1
	BPL.S	.r
	MOVEA.L	dat_ModulePtr,A1
	MOVE.L	D6,D0
	JSR	(-210,A6)		; FreeMem old
.set:	MOVE.L	A3,dat_ModulePtr
	MOVE.L	D5,dat_SampleEditCfg
	MOVEM.L	D4/D7,-(A7)		; original code below keeps no registers
	MOVE.W	dat_DiskOpState,-(A7)	; screen of 8ch, the song stays
	CLR.W	dat_DiskOpState
	BCLR	#5,dat_ModeFlags
	JSR	pt_ClearScreenBuf2
	MOVE.W	(A7)+,dat_DiskOpState
	MOVEM.L	(A7)+,D4/D7
	JSR	pt_MixStop		; the tick starts the card 8ch
	MOVE.B	D4,trk_Show
	MOVE.W	#-1,trk_UndoPat
	TST.B	D7
	BEQ.S	.nc
	MOVE.W	D4,D0
	MOVEQ	#4,D1
	BSR.W	pt_ChnCutView41
.nc:	JSR	pt_PatViewDrawAll
	TST.B	chn_Paused		; row offset: 16 -> 32 bytes a row
	BEQ.S	.ok
	MOVE.L	snd_ResPat,D0
	ADD.L	D0,D0
	MOVE.L	D0,snd_ResPat
.ok:	BSR.W	pt_ChnResume41
	MOVEM.L	(A7)+,D1-D7/A0-A6
	CMP.W	D0,D0			; z=1
	RTS
.nm:	BSR.W	pt_ChnResume41
	LEA	chn_MsgMem8(PC),A0
	BSR.W	pt_ChnMsg41
	MOVEM.L	(A7)+,D1-D7/A0-A6
	ANDI	#$fb,CCR		; z=0
	RTS
; d5 = size -> d0 = block (MEMF_PUBLIC|CLEAR), z=1 none; 100 pattern
; buffer: 64 if the song fits (d3 set: empty, always)
.alloc:	MOVE.L	D5,D0
	MOVE.L	#$10001,D1
	JSR	(-198,A6)
	TST.L	D0
	BNE.S	.ar
	CMP.L	#mod_patterns+64*2048,D5
	BLS.S	.an
	TST.B	D3
	BNE.S	.a64
	JSR	pt_WideNeed		; last pattern with cells (4ch view)
	CMP.L	#64,D0
	BHI.S	.an
	CMPI.W	#64,dat_NumSamples
	BCC.S	.an
	CMPI.L	#64,dat_PatTableIdx
	BCC.S	.an
.a64:	MOVE.L	#mod_patterns+64*2048,D5
	MOVE.L	D5,D0
	MOVE.L	#$10001,D1
	JSR	(-198,A6)
	TST.L	D0
	BEQ.S	.ar
	MOVE.L	#63,dat_SampleEditState
	CLR.B	dat_PatternBufFlag
	LEA	ld_Msg64,A0
	JSR	pt_StatusLater41
	TST.L	D0
.ar:	RTS
.an:	MOVEQ	#0,D0
	RTS
.hdr:	LEA	wide_Hdr,A0		; header back (a3 = block)
	MOVEA.L	A3,A1
	MOVE.W	#mod_patterns/4-1,D1
.hh:	MOVE.L	(A0)+,(A1)+
	DBF	D1,.hh
	RTS

; 8ch song (8 tracks) -> wide module with d4 channels (9..32); z=1 done
pt_ChnToWide41:
	MOVEM.L	D1-D7/A0-A6,-(A7)
	TST.L	agus_Mem
	BEQ.W	.nm
	MOVEQ	#0,D7
	MOVE.W	dat_NumSamples,D7	; highest pattern
	MOVE.L	dat_PatTableIdx,D0	; or the edited one
	CMP.L	D7,D0
	BLS.S	.h
	MOVE.L	D0,D7
.h:	ADDQ.L	#1,D7
	JSR	pt_WideNeed		; or the last one with cells
	CMP.L	D7,D0
	BLS.S	.n
	MOVE.L	D0,D7
.n:	JSR	pt_WideCap		; not past pt's buffer
	CMP.L	D0,D7
	BLS.S	.c
	MOVE.L	D0,D7
.c:	MOVE.L	D7,D6
	MOVEQ	#13,D0
	LSL.L	D0,D6			; d6 = 8 kb a pattern
	MOVE.L	D6,D0
	MOVE.L	#$10001,D1		; MEMF_PUBLIC|MEMF_CLEAR
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-198,A6)
	TST.L	D0
	BEQ.W	.nm
	MOVEA.L	D0,A2			; a2 = wide patterns
	BSR.W	pt_ChnPause41
	JSR	pt_MixStop		; card voices off, the tick starts them wide
	MOVEA.L	dat_ModulePtr,A0	; rows: 8 cells -> 32 a row
	LEA	mod_patterns(A0),A0
	MOVEA.L	A2,A1
	MOVE.L	D7,D1
	LSL.L	#6,D1
	BRA.S	.r1
.r:	MOVEQ	#7,D0
.cl:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.cl
	LEA	WIDE_ROW-32(A1),A1
.r1:	SUBQ.L	#1,D1
	BPL.S	.r
	MOVE.L	A2,wide_Pat
	MOVE.L	D6,wide_PatSize
	MOVE.W	D4,wide_Ch
	CLR.W	trk_Grp
	CLR.W	trk_UndoGrp
	MOVE.W	#-1,trk_UndoPat
	CLR.L	wide_Mute
	CLR.W	trk_GrownCh		; next window snap widens for it
	SF	wide_NoView
	AGM	AGM_CHAN,A0		; fresh channel structs
	MOVE.W	#32*n_SIZEOF/4-1,D0
.cc:	CLR.L	(A0)+
	DBF	D0,.cc
	MOVE.B	#8,trk_Show
	ST	wide_On
	JSR	pt_MixStop		; a tick may have started it narrow meanwhile
	MOVE.W	dat_RpDmaChanMask,D0	; buttons -> mutes of the shown tracks
	JSR	pt_WideMaskSet
	JSR	pt_WideShow41
	MOVE.W	#1,dat_KeyRepeatDelay	; heads: channel numbers
	JSR	pt_PatViewDrawAll
	JSR	pt_WBarChk41		; slider over the heads
	BSR.W	pt_ChnResume41
	MOVEM.L	(A7)+,D1-D7/A0-A6
	CMP.W	D0,D0			; z=1
	RTS
.nm:	LEA	chn_MsgMem(PC),A0
	TST.L	agus_Mem
	BNE.S	.m
	LEA	chn_MsgCard(PC),A0
	BSR.W	pt_CardStr41
.m:	BSR.W	pt_ChnMsg41
	MOVEM.L	(A7)+,D1-D7/A0-A6
	ANDI	#$fb,CCR		; z=0
	RTS

; wide module: d3 = old, d4 = new channels (9..32), d7.b = cut d4..d3-1
pt_ChnWideSet41:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.B	D7
	BEQ.S	.nc
	MOVE.W	D4,D0
	MOVE.W	D3,D1
	BSR.W	pt_ChnWideCut41
.nc:	MOVE.W	#-1,trk_UndoPat		; snapshot of the old count goes
	CLR.W	trk_UndoGrp
	MOVE.W	D4,wide_Ch
	JSR	pt_WideMuteCut41	; no mutes past the count
	JSR	pt_WideGMax41		; last group the view may start at
	CMP.W	trk_Grp,D0
	BCC.S	.in
	JSR	pt_TrkGrpSet		; view back inside the count
.in:	JSR	pt_WideShow41
	JSR	pt_WideBtns41		; buttons of hidden tracks on again
	CMP.W	D3,D4
	BCC.S	.v
	MOVE.W	D4,D1			; channels past the count: voices off,
	JSR	pt_AgusSilFrom41
	MOVE.W	D4,D0			; on the card too: the tick skips them
	JSR	pt_AgusVoicesFrom41
.v:	MOVE.W	#1,dat_KeyRepeatDelay
	JSR	pt_TrkClamp41
	JSR	pt_PatViewDrawAll
	JSR	pt_WBarOff41		; knob size follows the count
	JSR	pt_WBarChk41
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; wide module -> 8ch song, d4 tracks (1..8), d7.b = cut d4..7; z=1 done
pt_ChnWideTo8_41:
	MOVEM.L	D1-D7/A0-A6,-(A7)
	BSR.W	pt_ChnPause41
	BTST	#5,dat_ModeFlags	; rtg 4 track view: pt's 8ch buffer first
	BEQ.S	.v8
	MOVEQ	#8,D0
	JSR	pt_WideView41
	BTST	#5,dat_ModeFlags
	BNE.S	.nm
.v8:	MOVEQ	#0,D0			; tracks 1-8 into the view
	JSR	pt_TrkGrpSet
	TST.W	trk_Grp
	BNE.S	.nm
	TST.B	D7
	BEQ.S	.nc
	MOVE.W	D4,D0
	MOVEQ	#8,D1
	CMP.W	D1,D0
	BCC.S	.nc
	BSR.W	pt_ChnCutView41
.nc:	MOVE.W	#-1,trk_UndoPat		; snapshot may be of another group
	JSR	pt_WideOff		; channels 9-32 away
	JSR	pt_MixStop		; the tick starts the card narrow
	MOVE.B	D4,trk_Show
	MOVE.W	#1,dat_KeyRepeatDelay
	JSR	pt_TrkClamp41
	JSR	pt_PatViewDrawAll
	BSR.W	pt_ChnResume41
	MOVEM.L	(A7)+,D1-D7/A0-A6
	CMP.W	D0,D0			; z=1
	RTS
.nm:	BSR.W	pt_ChnResume41
	TST.B	wide_NoView		; the view change said it already
	BNE.S	.q
	LEA	chn_MsgMem8(PC),A0
	BSR.W	pt_ChnMsg41
.q:	MOVEM.L	(A7)+,D1-D7/A0-A6
	ANDI	#$fb,CCR		; z=0
	RTS

chn_AskT:	DC.B	10,10
	DC.B	" Tracks after ## hold",10
	DC.B	" notes. Remove them?",0
chn_MsgMax:	DC.B	"CHANNELS: 32 IS THE MAXIMUM",0
chn_MsgMin:	DC.B	"CHANNELS: 1 IS THE MINIMUM",0
chn_MsgCardA:	DC.B	"9-32 CHANNELS: OUTPUT AMIGUS",0
chn_MsgCardZ:	DC.B	"9-32 CHANNELS: OUTPUT ZZ9000AX",0
chn_MsgCardB:	DC.B	"9-32 CHANNELS: OUTPUT AMIGUS/ZZ9000AX",0
chn_MsgNoCard:	DC.B	"CHANNELS: 8 WITHOUT AMIGUS/ZZ9000AX",0	; no card at all
chn_Msg4:	DC.B	"CHANNELS: CLICK THE NAME FOR 8CHN",0
chn_MsgMem:	DC.B	"NO MEMORY FOR MORE CHANNELS",0
chn_MsgMem8:	DC.B	"NO MEMORY FOR 8 CHANNELS",0
	EVEN
chn_MsgCard:	DC.L	chn_MsgCardA,chn_MsgCardZ,chn_MsgCardB,chn_MsgCardB	; pt_CardStr41
