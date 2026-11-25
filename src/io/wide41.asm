; wide modules (more than 8 channels, up to 32): amigus output.
; pt's buffer is the view: 4 tracks (4ch, rtg track view) or 8 tracks
; (8ch, native) from group trk_Grp on; all channels sit in wide_Pat,
; 32 a row (128 bytes), the replayer plays them from there (AGM_CHAN)
WIDE_ROW	EQU	128
WIDE_PAT	EQU	64*WIDE_ROW
WIDE_MAXVIEW	EQU	100		; patterns in pt's 4ch buffer

; a0 -> id: "xCHN" (9), "xxCH" or "xxCN" (10..32)
; -> d0 = channels, z=0; else z=1
pt_WideId:
	MOVEQ	#0,D0
	MOVE.B	(A0),D0
	SUB.B	#'0',D0
	CMP.B	#9,D0
	BHI.S	.no
	CMPI.B	#'C',1(A0)		; xCHN
	BNE.S	.two
	CMPI.W	#'HN',2(A0)
	BNE.S	.no
	CMP.B	#9,D0			; up to 8 pt plays itself
	BEQ.S	.y
	BRA.S	.no
.two:	CMPI.W	#'CH',2(A0)		; xxCH
	BEQ.S	.dd
	CMPI.W	#'CN',2(A0)		; xxCN (taketracker)
	BNE.S	.no
.dd:	MULU	#10,D0
	MOVEQ	#0,D1
	MOVE.B	1(A0),D1
	SUB.B	#'0',D1
	CMP.B	#9,D1
	BHI.S	.no
	ADD.W	D1,D0
	CMP.W	#9,D0
	BCS.S	.no
	CMP.W	#32,D0
	BHI.S	.no
.y:	ANDI	#$fb,CCR
	RTS
.no:	ORI	#4,CCR
	RTS

; hook start of pt_FmtCheckMore (a0 -> id): wide id -> load as 4ch, the
; patterns follow in pt_WidePats. needs amigus output; else a dialog,
; nothing loaded
pt_WideCheck:
	BSR.W	pt_WideTmpFree		; left by a load that ended early
	MOVEM.L	D0-D1,-(A7)
	BSR.S	pt_WideId
	BEQ.W	.r
	IFD	DEBUGAUTO
	TST.B	dbg_WideOk
	BNE.S	.go
	ENDC
	TST.B	agus_On
	BEQ.W	.noag
.go:	MOVEM.L	D0-D1/A0-A1/A6,-(A7)	; read buffer now: the old song stays
	MOVE.L	#WIDE_TMP,D0		; if there is none
	MOVEQ	#1,D1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-198,A6)
	MOVE.L	D0,wide_Tmp
	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	BEQ.S	.nm
	MOVE.W	D0,wide_Ch
	ST	wide_Pend
	MOVEM.L	(A7)+,D0-D1
	ADDQ.L	#8,A7			; pop both returns (hook, caller)
	BTST	#5,dat_ModeFlags	; 8ch: to 4ch like the 8chn switch
	BNE.S	.is4
	JSR	pt_BtnMainStop		; no replayer tick on the old buffer
	MOVE.W	#1,dat_DiskOpState
	BSET	#5,dat_ModeFlags
	JSR	pt_ClearScreenBuf2
	MOVE.W	#4,dat_RpNumChannels
	JMP	pt_0E50
.is4:	JMP	pt_CheckModifiedAndInit
.nm:	MOVEM.L	(A7)+,D0-D1
	ADDQ.L	#8,A7
	JSR	pt_CloseFileHandle
	LEA	wide_MsgTmpMem(PC),A0
	JSR	pt_StatusLater41
	JMP	pt_FinishPaletteEdit
.noag:	MOVEM.L	(A7)+,D0-D1
	ADDQ.L	#8,A7
	JSR	pt_CloseFileHandle
	JSR	pt_AgusDetect
	JSR	pt_ZzaxDetect
	LEA	wide_AskNoCard(PC),A0	; explain, then a short status
	BSR.W	pt_CardAny41		; amigus or zz9000ax
	BEQ.S	.d
	LEA	wide_AskSetup(PC),A0	; card there: output or rtg missing
	BSR.W	pt_CardStr41
.d:	JSR	pt_SetupEditScreen	; notice, one button
	LEA	wide_MsgNotLoaded(PC),A0
	BSR.W	pt_CardStr41
	JSR	pt_StatusLater41	; disk op writes its status after
	JMP	pt_FinishPaletteEdit
.r:	MOVEM.L	(A7)+,D0-D1
	RTS

; setup CHANNELS of a wide module: a0 -> "28CH" / "9CHN", else a0 kept
pt_WideChText41:
	TST.B	wide_On
	BEQ.S	.r
	MOVE.L	D0,-(A7)
	LEA	wide_ChTxt,A0
	MOVEQ	#0,D0
	MOVE.W	wide_Ch,D0
	CMP.W	#10,D0
	BCC.S	.two
	ADD.B	#'0',D0
	MOVE.B	D0,(A0)
	MOVE.B	#'C',1(A0)
	MOVE.B	#'H',2(A0)
	MOVE.B	#'N',3(A0)
	BRA.S	.x
.two:	DIVU	#10,D0
	ADD.B	#'0',D0
	MOVE.B	D0,(A0)
	SWAP	D0
	ADD.B	#'0',D0
	MOVE.B	D0,1(A0)
	MOVE.B	#'C',2(A0)
	MOVE.B	#'H',3(A0)
.x:	MOVE.L	(A7)+,D0
.r:	RTS

; pt_FmtAfterHeader (a0 = module): a pending wide module gets id M.K.;
; any other module load ends wide mode
pt_WideHeader:
	TST.B	wide_Pend
	BNE.S	.p
	BRA.W	pt_WideOff
.p:	MOVE.L	#'M.K.',mod_id(A0)
	BRA.W	pt_WideOff		; earlier wide module: voices, patterns

; pt_FmtAfterPatterns: wide patterns, 4ch view, file to the samples.
; reads one pattern at a time; without memory for all channels the
; module stays a 4ch module (tracks 1-4), samples still in place
WIDE_TMP	EQU	32*256		; one raw pattern, 32 channels
pt_WidePats:
	TST.B	wide_Pend
	BEQ.W	.r
	SF	wide_Pend
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVEA.L	dat_ModulePtr,A0
	MOVEQ	#0,D7
	MOVE.W	fmt_FilePats,D7		; patterns in the file, positions not capped
	MOVE.W	wide_Ch,D6		; d6 = raw pattern = ch * 256
	MULU	#256,D6
	MOVE.L	D7,D5
	MULU	D6,D5			; d5 = raw size up to the samples
	JSR	pt_WideCap		; read and keep only what the buffer holds
	CMP.L	D0,D7
	BLS.S	.pn
	MOVE.L	D0,D7
.pn:
	MOVE.L	D7,D0			; wide_Pat: npat * 8 KB (0 = none)
	MULU	#WIDE_PAT/64,D0
	LSL.L	#6,D0
	MOVE.L	D0,wide_PatSize
	MOVE.L	#$10001,D1		; MEMF_PUBLIC|MEMF_CLEAR
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-198,A6)
	MOVE.L	D0,wide_Pat
	MOVE.L	wide_Tmp,D4		; d4 = one raw pattern
	BNE.S	.tp
	MOVE.L	#WIDE_TMP,D0
	MOVEQ	#1,D1
	JSR	(-198,A6)
	MOVE.L	D0,wide_Tmp
	MOVE.L	D0,D4
	BEQ.W	.nomem
.tp:	MOVEA.L	dat_DosLibBase,A6
	MOVE.L	dat_FileHandle,D1
	MOVE.L	#mod_patterns,D2
	MOVEQ	#-1,D3			; OFFSET_BEGINNING
	JSR	pt_FileSeekPos
	MOVEA.L	dat_ModulePtr,A3	; a3 = 4ch view
	LEA	mod_patterns(A3),A3
	MOVEA.L	wide_Pat,A4		; a4 = wide pattern (0 = none)
	MOVEQ	#0,D3			; d3 = pattern
.pat:	MOVEA.L	D4,A0			; short file: rest stays 0
	MOVE.W	#WIDE_TMP/4-1,D0
.z:	CLR.L	(A0)+
	DBF	D0,.z
	MOVEM.L	D3/A3-A4,-(A7)
	MOVE.L	dat_FileHandle,D1
	MOVE.L	D4,D2
	MOVE.L	D6,D3
	JSR	pt_CheckModHeader	; read
	MOVEM.L	(A7)+,D3/A3-A4
	MOVEA.L	D4,A0			; a0 = raw rows, ch * 4 bytes
	MOVEQ	#63,D2
.row:	MOVE.L	(A0),(A3)+		; view: tracks 1-4
	MOVE.L	4(A0),(A3)+
	MOVE.L	8(A0),(A3)+
	MOVE.L	12(A0),(A3)+
	MOVE.L	A4,D0
	BEQ.S	.nw
	MOVEA.L	A0,A1
	MOVEA.L	A4,A2
	MOVE.W	wide_Ch,D1
	SUBQ.W	#1,D1
.cel:	MOVE.L	(A1)+,(A2)+
	DBF	D1,.cel
	LEA	WIDE_ROW(A4),A4
.nw:	ADDA.W	wide_Ch,A0
	ADDA.W	wide_Ch,A0
	ADDA.W	wide_Ch,A0
	ADDA.W	wide_Ch,A0
	DBF	D2,.row
	ADDQ.W	#1,D3
	CMP.W	D7,D3
	BCS.W	.pat
	BSR.W	pt_WideTmpFree
	TST.L	wide_Pat
	BEQ.S	.nomem
	BSR.S	.seek
	TST.L	agus_Mem
	BEQ.S	.nt
	AGM	AGM_CHAN,A0		; fresh channel structs
	MOVE.W	#32*n_SIZEOF/4-1,D0
.cc:	CLR.L	(A0)+
	DBF	D0,.cc
	BSR.W	pt_WideMixStart		; shadow table now: the mixer may run already
.nt:
	CLR.W	trk_Grp			; view = tracks 1-4
	CLR.W	trk_UndoGrp
	CLR.L	wide_Mute
	CLR.W	trk_GrownCh		; next window snap widens for it
	ST	wide_On
	SF	wide_NoView
	MOVE.W	dat_RpDmaChanMask,D0	; buttons -> mutes of tracks 1-4
	BSR.W	pt_WideMaskSet
	ST	wide_MsgPend
	BRA.S	.x
.nomem:	BSR.W	pt_WideTmpFree
	BSR.W	pt_WideFree		; 4ch module: tracks 1-4
	BSR.S	.seek
	LEA	wide_MsgNoMem(PC),A0
	JSR	pt_StatusLater41
.x:	MOVEM.L	(A7)+,D0-D7/A0-A6
.r:	RTS
.seek:	MOVEA.L	dat_DosLibBase,A6	; file to the samples
	MOVE.L	dat_FileHandle,D1
	MOVE.L	D5,D2
	ADD.L	#mod_patterns,D2
	MOVEQ	#-1,D3
	JMP	pt_FileSeekPos

; d0 = patterns pt's buffer holds, at most WIDE_MAXVIEW (d1 used)
pt_WideCap:
	MOVE.L	dat_SampleEditCfg,D0
	SUB.L	#mod_patterns,D0
	MOVEQ	#10,D1
	BTST	#5,dat_ModeFlags
	BNE.S	.s
	MOVEQ	#11,D1
.s:	LSR.L	D1,D0
	CMP.L	#WIDE_MAXVIEW,D0
	BLS.S	.r
	MOVEQ	#WIDE_MAXVIEW,D0
.r:	RTS

; d0 = view patterns up to the last one that holds a cell (0 = empty)
pt_WideNeed:
	MOVEM.L	D1-D2/A0,-(A7)
	BSR.S	pt_WideCap
	MOVEQ	#10,D2
	BTST	#5,dat_ModeFlags
	BNE.S	.s
	MOVEQ	#11,D2
.s:	MOVEA.L	dat_ModulePtr,A0
	LEA	mod_patterns(A0),A0
	MOVE.L	D0,D1
	LSL.L	D2,D1
	ADDA.L	D1,A0			; end of the view
	MOVEQ	#1,D1
	LSL.W	D2,D1
	LSR.W	#2,D1
	SUBQ.W	#1,D1
	MOVE.W	D1,D2			; longs a pattern - 1
.p:	SUBQ.L	#1,D0
	BMI.S	.e
	MOVE.W	D2,D1
.l:	TST.L	-(A0)
	BNE.S	.e
	DBF	D1,.l
	BRA.S	.p
.e:	ADDQ.L	#1,D0
	MOVEM.L	(A7)+,D1-D2/A0
	RTS

; d0 = view width in tracks: 4 (4ch buffer), 8 (8ch buffer)
pt_WideW41:
	MOVEQ	#4,D0
	BTST	#5,dat_ModeFlags
	BNE.S	.r
	MOVEQ	#8,D0
.r:	RTS

; z=0: wide module whose pt screen is the native one (no rtg track view)
pt_WideNat41:
	TST.B	wide_On
	BEQ.S	.n
	TST.B	trk_On			; rtg track view up
	BNE.S	.n
	BTST	#5,dat_ModeFlags
	BEQ.S	.y
	TST.L	rtg_Proc
	BEQ.S	.y
	TST.B	rtg_Wide
	BNE.S	.n
.y:	ANDI	#$fb,CCR		; z=0
	RTS
.n:	ORI	#4,CCR			; z=1
	RTS

; d0 = last group the view starts at: ceil(ch/4) - width/4, at least 0
pt_WideGMax41:
	MOVE.W	wide_Ch,D0
	ADDQ.W	#3,D0
	LSR.W	#2,D0
	BTST	#5,dat_ModeFlags
	BNE.S	.4
	SUBQ.W	#1,D0
.4:	SUBQ.W	#1,D0
	BPL.S	.r
	MOVEQ	#0,D0
.r:	RTS

; view tracks shown: the channels from the group on, the width at most
; (8ch buffer only; the 4ch buffer always has four places)
pt_WideShow41:
	TST.B	wide_On
	BEQ.S	.r
	BTST	#5,dat_ModeFlags
	BNE.S	.r
	MOVE.L	D0,-(A7)
	MOVE.W	trk_Grp,D0
	LSL.W	#2,D0
	NEG.W	D0
	ADD.W	wide_Ch,D0
	CMP.W	#8,D0
	BLS.S	.s
	MOVEQ	#8,D0
.s:	MOVE.B	D0,trk_Show
	MOVE.L	(A7)+,D0
.r:	RTS

; d0 = tracks of the view that go back to wide_Pat (4, or the shown ones)
pt_WideVN:
	MOVEQ	#4,D0
	BTST	#5,dat_ModeFlags
	BNE.S	.r
	MOVEQ	#0,D0
	MOVE.B	trk_Show,D0
.r:	RTS

; d5 = view rows wide_Pat holds - 1 (mi: none), d4 = bytes a view row
pt_WideRows:
	MOVE.L	D0,-(A7)
	MOVE.L	D1,-(A7)
	BSR.W	pt_WideCap
	MOVE.L	wide_PatSize,D5
	MOVEQ	#13,D4
	LSR.L	D4,D5
	CMP.L	D0,D5
	BLS.S	.n
	MOVE.L	D0,D5
.n:	LSL.L	#6,D5
	MOVEQ	#16,D4
	BTST	#5,dat_ModeFlags
	BNE.S	.w
	MOVEQ	#32,D4
.w:	MOVE.L	(A7)+,D1
	MOVE.L	(A7)+,D0
	SUBQ.L	#1,D5
	RTS

; view -> wide_Pat at trk_Grp (the shown tracks, every row wide_Pat holds)
pt_WideFlush:
	MOVEM.L	D0-D5/A0-A2,-(A7)
	BSR.S	pt_WideRows
	BMI.S	.x
	BSR.S	pt_WideVN
	MOVE.W	D0,D3
	SUBQ.W	#1,D3
	BMI.S	.x
	MOVEA.L	dat_ModulePtr,A0
	LEA	mod_patterns(A0),A0
	MOVEA.L	wide_Pat,A1
	MOVE.W	trk_Grp,D0
	LSL.W	#4,D0
	ADDA.W	D0,A1
.row:	MOVEA.L	A1,A2
	MOVE.L	A0,D2
	MOVE.W	D3,D1
.c:	MOVE.L	(A0)+,(A2)+
	DBF	D1,.c
	MOVEA.L	D2,A0
	ADDA.W	D4,A0
	LEA	WIDE_ROW(A1),A1
	SUBQ.L	#1,D5
	BPL.S	.row
.x:	MOVEM.L	(A7)+,D0-D5/A0-A2
	RTS

; a3 = new view buffer: header from wide_Hdr, the view rows from wide_Pat
; at trk_Grp (8 view: the last group at most), the rest 0
pt_WideFill:
	MOVEM.L	D0-D5/A0-A2,-(A7)
	LEA	wide_Hdr,A0
	MOVEA.L	A3,A1
	MOVE.W	#mod_patterns/4-1,D1
.h:	MOVE.L	(A0)+,(A1)+
	DBF	D1,.h
	MOVE.L	dat_SampleEditCfg,D0
	SUB.L	#mod_patterns,D0
	LSR.L	#2,D0
	BRA.S	.z1
.z:	CLR.L	(A1)+
.z1:	SUBQ.L	#1,D0
	BPL.S	.z
	BSR.W	pt_WideGMax41
	CMP.W	trk_Grp,D0
	BCC.S	.g
	MOVE.W	D0,trk_Grp
.g:	BSR.W	pt_WideRows
	BMI.S	.x
	LEA	mod_patterns(A3),A0
	MOVEA.L	wide_Pat,A1
	MOVE.W	trk_Grp,D0
	LSL.W	#4,D0
	ADDA.W	D0,A1
	MOVE.W	D4,D3
	LSR.W	#2,D3
	SUBQ.W	#1,D3
.row:	MOVEA.L	A1,A2
	MOVE.W	D3,D1
.c:	MOVE.L	(A2)+,(A0)+
	DBF	D1,.c
	LEA	WIDE_ROW(A1),A1
	SUBQ.L	#1,D5
	BPL.S	.row
.x:	MOVEM.L	(A7)+,D0-D5/A0-A2
	RTS

; patterns added in pt into wide_Pat's reach (last save, the edited one);
; z=1 no memory
pt_WideGrowView:
	MOVEM.L	D0/D7,-(A7)
	MOVEQ	#0,D7
	MOVE.W	dat_NumSamples,D7
	MOVE.L	dat_PatTableIdx,D0
	CMP.L	D7,D0
	BLS.S	.h
	MOVE.L	D0,D7
.h:	ADDQ.W	#1,D7
	BSR.W	pt_WideGrow
	MOVEM.L	(A7)+,D0/D7		; flags stay
	RTS

; the fingerprint of an unchanged song stays right across a view change
pt_WideChgPre41:
	JSR	pt_ChgSync41
	RTS

pt_WideChgPost41:
	CMPI.L	#'CHG!',dat_SongChangedMagic
	BEQ.S	.r
	ST	chg_Due
.r:	RTS

; wide module: pt's view to d0 tracks (8 native screen, 4 rtg track view),
; same patterns; play pauses and goes on at its row. no memory: view stays
pt_WideView41:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.W	D0,D6			; d6 = new width
	TST.B	wide_On
	BEQ.W	.x
	MOVEQ	#4,D3			; d3 = old width
	BTST	#5,dat_ModeFlags
	BNE.S	.c
	MOVEQ	#8,D3
.c:	CMP.W	D3,D6
	BEQ.W	.x
	SF	wide_NoView		; a mark of an earlier try goes
	MOVEM.L	D3/D6,-(A7)
	BSR.W	pt_WideChgPre41
	MOVEM.L	(A7)+,D3/D6
	TST.L	dat_RpPlayMode
	SNE	D2			; d2 = we pause, we resume
	MOVEM.L	D2-D3/D6,-(A7)		; original code below keeps no registers
	JSR	pt_SndPause
	MOVEM.L	(A7)+,D2-D3/D6
	BSR.W	pt_WideGrowView
	BEQ.W	.nm
	ST	trk_Swap		; replayer: view not written back now
	BSR.W	pt_WideFlush
	JSR	pt_WBarOff41		; native rows back
	MOVEA.L	dat_ModulePtr,A0	; header aside, the rows are in wide_Pat
	LEA	wide_Hdr,A1
	MOVE.W	#mod_patterns/4-1,D1
.sh:	MOVE.L	(A0)+,(A1)+
	DBF	D1,.sh
	MOVE.L	dat_SampleEditCfg,D7	; d7 = old size
	MOVE.L	D7,D5
	SUB.L	#mod_patterns,D5
	CMP.W	#8,D6
	BNE.S	.h
	ADD.L	D5,D5
	BRA.S	.s
.h:	LSR.L	#1,D5
.s:	ADD.L	#mod_patterns,D5	; d5 = new size
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-132,A6)		; Forbid: the freed block stays ours
	MOVEA.L	dat_ModulePtr,A1
	MOVE.L	D7,D0
	JSR	(-210,A6)		; FreeMem
	MOVE.L	D5,D0
	MOVEQ	#1,D1			; MEMF_PUBLIC
	JSR	(-198,A6)		; AllocMem
	TST.L	D0
	BNE.S	.al
	CMP.L	#mod_patterns+64*2048,D5	; 100 pattern 8ch buffer: 64 if they fit
	BLS.S	.old
	MOVE.L	wide_PatSize,D0
	MOVEQ	#13,D1
	LSR.L	D1,D0
	CMP.L	#64,D0
	BHI.S	.old
	CMPI.W	#64,dat_NumSamples
	BCC.S	.old
	CMPI.L	#64,dat_PatTableIdx
	BCC.S	.old
	MOVE.L	#mod_patterns+64*2048,D5
	MOVE.L	D5,D0
	MOVEQ	#1,D1
	JSR	(-198,A6)
	TST.L	D0
	BEQ.S	.old
	MOVE.L	#63,dat_SampleEditState
	CLR.B	dat_PatternBufFlag
	ST	wide_Is64
	BRA.S	.al
.old:	MOVE.L	D7,D5			; no room: old size, old width
	MOVE.W	D3,D6
	ST	wide_NoView
	MOVE.L	D5,D0
	MOVEQ	#1,D1
	JSR	(-198,A6)		; the block just freed
	TST.L	D0
	BEQ.W	.lost
.al:	MOVEA.L	D0,A3			; a3 = new buffer
	MOVE.L	D0,dat_ModulePtr
	MOVE.L	D5,dat_SampleEditCfg
	BCLR	#5,dat_ModeFlags
	MOVE.W	#8,dat_RpNumChannels
	CMP.W	#8,D6
	BEQ.S	.m
	BSET	#5,dat_ModeFlags
	MOVE.W	#4,dat_RpNumChannels
.m:	JSR	(-138,A6)		; Permit
	BSR.W	pt_WideFill
	SF	trk_Swap
	MOVE.W	#-1,trk_UndoPat		; snapshot has the old row size
	MOVEM.L	D2-D3/D6,-(A7)
	MOVE.W	dat_DiskOpState,-(A7)	; screen of the mode, the song stays
	CLR.W	dat_DiskOpState
	JSR	pt_ClearScreenBuf2
	MOVE.W	(A7)+,dat_DiskOpState
	MOVEM.L	(A7)+,D2-D3/D6
	BSR.W	pt_WideShow41
	BSR.W	pt_WideBtns41
	JSR	pt_WBarChk41
	CMP.W	D3,D6
	BEQ.S	.rs
	TST.L	snd_ResMode		; paused play (ours or the output switch's):
	BEQ.S	.rs			; row offset to the new row size
	MOVE.L	snd_ResPat,D0
	CMP.W	#8,D6
	BNE.S	.p4
	ADD.L	D0,D0
	BRA.S	.p8
.p4:	LSR.L	#1,D0
.p8:	MOVE.L	D0,snd_ResPat
.rs:	TST.B	D2
	BEQ.S	.ms
	JSR	pt_SndResume
.ms:	MOVE.B	wide_Is64,D0
	SF	wide_Is64
	TST.B	wide_NoView		; one slot: the failure counts
	BNE.S	.msg
	TST.B	D0
	BEQ.S	.k
	LEA	ld_Msg64,A0
	JSR	pt_StatusLater41
	BRA.S	.k
.lost:	JSR	(-138,A6)		; Permit; no block at all
	CLR.L	dat_ModulePtr
	BRA.S	.k
.nm:	ST	wide_NoView
	TST.B	D2
	BEQ.S	.msg
	JSR	pt_SndResume
.msg:	LEA	wide_MsgViewMem(PC),A0
	JSR	pt_StatusLater41
.k:	BSR.W	pt_WideChgPost41
.x:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; d0 = tracks a wide module keeps without the card (8 as an 8ch module;
; 4 only when pt's 8ch buffer is out of reach); 0 = no wide module
pt_WideKeep:
	MOVEQ	#0,D0
	TST.B	wide_On
	BEQ.S	.r
	MOVEQ	#8,D0
.r:	RTS

; leave wide mode for paula/ahi (play stopped): tracks 1-8 as an 8ch
; module (the 8 track view, group 0), else the 4 track view stays
; d0 = tracks kept (8, 4; 0 = no wide module)
pt_WideTo8:
	TST.B	wide_On
	BEQ.W	.none
	BTST	#5,dat_ModeFlags
	BEQ.S	.v8
	MOVEQ	#8,D0			; 4 track view: pt's 8ch buffer first
	BSR.W	pt_WideView41
	BTST	#5,dat_ModeFlags
	BNE.S	.v4			; no memory: tracks 1-4
.v8:	MOVEQ	#0,D0			; view back to tracks 1-8
	JSR	pt_TrkGrpSet
	TST.W	trk_Grp			; swap failed: group 0 straight from wide
	BEQ.S	.g0
	BSR.W	pt_WideBack0
.g0:	MOVEM.L	D1-D7/A0-A6,-(A7)
	MOVEA.L	dat_ModulePtr,A0
	MOVE.L	#'8CHN',mod_id(A0)
	MOVE.B	#8,trk_Show
	BSR.W	pt_WideOff
	MOVE.W	#1,dat_KeyRepeatDelay	; heads: TRK#n again
	JSR	pt_0641			; setup text
	JSR	pt_PatViewDrawAll
	MOVEM.L	(A7)+,D1-D7/A0-A6
	MOVEQ	#8,D0
	RTS
.v4:	MOVEQ	#0,D0			; view back to tracks 1-4
	JSR	pt_TrkGrpSet
	TST.W	trk_Grp
	BEQ.S	.o4
	BSR.W	pt_WideBack0		; tracks 1-4 back without memory
.o4:	BSR.W	pt_WideOff
	MOVEQ	#4,D0
	RTS
.none:	MOVEQ	#0,D0
	RTS

; the view holds another group and no memory to swap: group 0 is copied
; from wide_Pat, patterns added in the other group get empty tracks
pt_WideBack0:
	MOVEM.L	D0-D5/A0-A2,-(A7)
	MOVE.L	wide_Pat,D1
	BEQ.S	.r
	MOVE.L	D1,D2			; d2 = wide row
	BSR.W	pt_WideRows		; d5 = view rows - 1, d4 = view row bytes
	BMI.S	.r
	MOVEA.L	dat_ModulePtr,A0
	LEA	mod_patterns(A0),A0
	MOVE.L	wide_PatSize,D3
	LSR.L	#7,D3			; wide rows
	MOVEA.L	D2,A2
	LSR.W	#2,D4
	SUBQ.W	#1,D4			; longs a view row - 1
.row:	MOVE.W	D4,D0
	SUBQ.L	#1,D3
	BMI.S	.nw
	MOVEA.L	A2,A1
.c:	MOVE.L	(A1)+,(A0)+
	DBF	D0,.c
	LEA	WIDE_ROW(A2),A2
	BRA.S	.nx
.nw:	CLR.L	(A0)+
	DBF	D0,.nw
.nx:	SUBQ.L	#1,D5
	BPL.S	.row
	CLR.W	trk_Grp
.r:	MOVEM.L	(A7)+,D0-D5/A0-A2
	RTS

; leave wide mode (patterns freed; the 4ch view stays as a 4ch module)
pt_WideOff:
	TST.B	wide_On
	BEQ.S	pt_WideFree
	MOVE.L	D0,-(A7)
	JSR	pt_WBarOff41		; native slider rows back
	JSR	pt_AgusVoicesOff	; voices 8-31 stop with the mode
	MOVE.L	(A7)+,D0
	SF	wide_On
pt_WideFree:
	SF	wide_NoView
	CLR.W	trk_Grp
	CLR.W	trk_UndoGrp
	CLR.L	wide_Mute
	BSR.W	pt_WideSaveFree
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVE.L	wide_Pat,D0
	BEQ.S	.r
	CLR.L	wide_Pat
	MOVEA.L	D0,A1
	MOVE.L	wide_PatSize,D0
	CLR.L	wide_PatSize
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-210,A6)
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

; pt_MixStart: 32 shadow registers, channel masks off (no paula)
pt_WideMixStart:
	TST.L	agus_Mem
	BEQ.W	.nc
	MOVEM.L	D0-D2/A0-A2,-(A7)
	AGM	AGM_CHAN,A0
	AGM	AGM_TAB,A1
	AGM	AGM_SHADOW,A2
	MOVEQ	#0,D2
.c:	CLR.W	(n_pt4_dmacon,A0)
	CLR.W	(n_pt4_dmaset,A0)
	CLR.W	(n_pt4_intmask,A0)
	CLR.W	(n_pt4_intena,A0)
	CLR.B	(n_finetune,A0)
	CLR.B	(n_glissfunk,A0)
	CLR.B	(n_wavecontrol,A0)
	CLR.B	(n_loopcount,A0)
	CLR.B	(n_funkoffset,A0)
	CLR.B	(n_vibratopos,A0)
	CLR.B	(n_tremolopos,A0)
	CLR.W	(n_wantedperiod,A0)
	MOVE.W	D2,D0
	AND.W	#3,D0			; track on/off bits of tracks 1-4
	MOVE.W	D0,(n_pt4_chanbit,A0)
	MOVE.L	A2,(A1)+
	LEA	n_SIZEOF(A0),A0
	LEA	aud_SIZEOF(A2),A2
	ADDQ.W	#1,D2
	CMP.W	#32,D2
	BNE.S	.c
	AGM	AGM_VOICES,A0
	MOVE.W	#32*mv_SIZEOF/4-1,D0
.v:	CLR.L	(A0)+
	DBF	D0,.v
	MOVEM.L	(A7)+,D0-D2/A0-A2
.nc:	RTS

; pt_0134: track buttons -> mask; wide: they mute the edited group
pt_WideMask41:
	MOVE.W	D0,dat_RpDmaChanMask
	TST.B	wide_On
	BNE.S	pt_WideMaskSet
	RTS

; d0 = buttons (bit set = on) -> bits of the view in wide_Mute
pt_WideMaskSet:
	MOVEM.L	D0-D2,-(A7)
	NOT.W	D0
	MOVEQ	#15,D2
	BTST	#5,dat_ModeFlags
	BNE.S	.w
	MOVE.W	#255,D2
.w:	AND.L	D2,D0
	MOVE.W	trk_Grp,D1
	LSL.W	#2,D1
	LSL.L	D1,D0
	LSL.L	D1,D2
	NOT.L	D2
	AND.L	wide_Mute,D2
	OR.L	D0,D2
	MOVE.L	D2,wide_Mute
	MOVEM.L	(A7)+,D0-D2
pt_WideMuteCut41:			; no mutes past the count
	MOVE.L	D0,-(A7)
	BSR.S	pt_WideAll41
	AND.L	D0,wide_Mute
	MOVE.L	(A7)+,D0
	RTS

; -> d0 = a bit for every channel of the song (wide_Ch)
pt_WideAll41:
	MOVEQ	#-1,D0
	CMPI.W	#32,wide_Ch
	BCC.S	.r
	MOVE.L	D1,-(A7)
	MOVE.W	wide_Ch,D1
	LSL.L	D1,D0
	NOT.L	D0
	MOVE.L	(A7)+,D1
.r:	RTS

; view change: buttons of the view from wide_Mute, mask + panel
pt_WideBtns41:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.L	wide_Mute,D0
	MOVE.W	trk_Grp,D1
	LSL.W	#2,D1
	LSR.L	D1,D0
	LEA	dat_ScopeCh1,A0
	MOVEQ	#3,D1
	BSR.W	pt_WideNat41
	BEQ.S	.b
	MOVE.W	#1,dat_KeyRepeatDelay	; heads again: numbers of the view
	BTST	#5,dat_ModeFlags
	BNE.S	.b
	MOVEQ	#7,D1			; 8 view: tracks 5-8 follow
.b:	MOVEQ	#0,D2
	BTST	#0,D0
	BNE.S	.s
	MOVEQ	#1,D2
.s:	MOVE.W	D2,(A0)
	LEA	dat_ScopeCh2-dat_ScopeCh1(A0),A0
	LSR.L	#1,D0
	DBF	D1,.b
	JSR	pt_0134			; mask, scopes, panel
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; ctrl+q: all tracks on; wide: every channel
pt_MuteAllOn41:
	CLR.B	dat_KeyCode
	CLR.L	wide_Mute
	RTS

; solo: buttons cleared; wide: every channel off, cursor one back on
pt_MuteSolo41:
	CLR.W	dat_ScopeCh1
	TST.B	wide_On
	BEQ.S	.r
	MOVE.L	D0,-(A7)
	BSR.W	pt_WideAll41
	MOVE.L	D0,wide_Mute
	MOVE.L	(A7)+,D0
.r:	RTS

; replayer note start: a wide ch (a6 in AGM_CHAN) -> d0 $ffff, 0 muted
pt_RpChMask41:
	MOVE.W	dat_RpDmaChanMask,D0
	TST.B	wide_On
	BEQ.S	.r
	TST.L	agus_Mem
	BEQ.S	.r
	MOVE.L	D1,-(A7)
	MOVE.L	A6,D1
	SUB.L	agus_Mem,D1
	SUB.L	#AGM_CHAN,D1
	CMP.L	#32*n_SIZEOF,D1
	BCC.S	.x			; not a wide ch
	DIVU	#n_SIZEOF,D1
	MOVE.L	wide_Mute,D0
	BTST	D1,D0
	SEQ	D0
	EXT.W	D0
.x:	MOVE.L	(A7)+,D1
.r:	RTS

pt_RpChMaskD1_41:
	MOVE.L	D0,-(A7)
	BSR.S	pt_RpChMask41
	MOVE.W	D0,D1
	MOVE.L	(A7)+,D0
	RTS

; replayer: a6 = voice record -> d2 = voice number from 1, c = not a voice
; record (wide: the records are in the card block)
pt_RpVoiceNo41:
	MOVE.L	D0,-(A7)
	MOVE.L	A6,D2
	SUB.L	#dat_Channel1,D2
	TST.B	wide_On
	BEQ.S	.d
	MOVE.L	agus_Mem,D0
	BEQ.S	.d
	MOVE.L	A6,D2
	SUB.L	D0,D2
	SUB.L	#AGM_CHAN,D2
.d:	CMP.L	#32*n_SIZEOF,D2
	BCC.S	.n			; also below the base: c
	DIVU	#n_SIZEOF,D2
	ADDQ.B	#1,D2
	MOVE.L	(A7)+,D0
	AND.B	#$fe,CCR		; c = 0
	RTS
.n:	MOVE.L	(A7)+,D0
	OR.B	#1,CCR
	RTS

; end of pt_MixLoopInit: 32 channels; new row (d1 = dat_PatBaseAddr,
; pattern*1024/2048 + pos in view): view row -> its tracks, a0/d1 wide
pt_WideLoop:
	TST.L	agus_Mem
	BEQ.W	.nc
	MOVEM.L	D0/D2-D3/A1-A3,-(A7)
	CMP.L	dat_PatBaseAddr,D1	; effects only pass: no row
	BNE.S	.ch
	MOVE.L	D1,D0
	MOVE.L	dat_RpPatternPos,D2
	SUB.L	D2,D0			; pattern * view pattern bytes
	MOVEQ	#3,D3			; 4ch view: row 16 -> 128
	BTST	#5,dat_ModeFlags
	BNE.S	.4
	MOVEQ	#2,D3			; 8ch view: row 32 -> 128
.4:	LSL.L	D3,D2
	LSL.L	D3,D0
	ADD.L	D0,D2
	MOVEA.L	wide_Pat,A2
	ADDA.L	D2,A2
	CMP.L	wide_PatSize,D2
	BCS.S	.vw
	LEA	wide_Row+WIDE_ROW,A2	; pattern added in pt: only the view
	MOVEQ	#WIDE_ROW/4-1,D0
.z:	CLR.L	-(A2)
	DBF	D0,.z
.vw:	MOVE.L	dat_SampleEditCfg,D0	; view edits count
	SUB.L	#mod_patterns,D0
	CMP.L	D0,D1
	BCC.S	.nv
	TST.B	trk_Swap
	BNE.S	.nv
	LEA	(A0,D1.L),A1
	MOVE.W	trk_Grp,D0
	LSL.W	#4,D0
	LEA	(A2,D0.W),A3
	BSR.W	pt_WideVN
	SUBQ.W	#1,D0
	BMI.S	.nv
.wb:	MOVE.L	(A1)+,(A3)+
	DBF	D0,.wb
.nv:	MOVEA.L	A2,A0			; row
	MOVEQ	#0,D1
.ch:	AGM	AGM_CHAN,A6		; volscale: master vol, muted ch 0
	MOVEQ	#0,D7
	MOVE.W	dat_RpMasterVol,D0
	MOVE.L	wide_Mute,D2
.vs:	MOVE.W	D0,(n_pt4_volscale,A6)
	CMP.W	wide_Ch,D7		; channels past the count: silent
	BCC.S	.vm
	BTST	D7,D2
	BEQ.S	.vn
.vm:	CLR.W	(n_pt4_volscale,A6)
.vn:	LEA	n_SIZEOF(A6),A6
	ADDQ.W	#1,D7
	CMP.W	#32,D7
	BNE.S	.vs
	AGM	AGM_CHAN,A6
	MOVEQ	#31,D7
	AGM	AGM_TAB,A5
	MOVE.L	A5,mix_AudPtrCur
	MOVEA.L	(A5),A5
	MOVEM.L	(A7)+,D0/D2-D3/A1-A3
.nc:	RTS

; module save after the id (a0 = module): wide -> pt_WideSave
pt_WideSaveId:
	SF	trk_Pack		; wide writes its own block
	TST.B	wide_On
	BNE.S	pt_WideSave
	JMP	pt_TrkSaveId41

; save (a0 = module): view -> tracks 1-4, then header with
; the wide id and all channels as the write block; samples follow from pt
pt_WideSave:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVEA.L	A0,A4
	BSR.W	pt_WideSaveFree
	MOVEQ	#0,D7
	MOVE.W	dat_NumSamples,D7	; highest pattern
	ADDQ.W	#1,D7
	BSR.W	pt_WideGrowTo		; patterns added since the load
	BEQ.W	.nomem
	BSR.W	pt_WideFlush		; view -> wide (the shown tracks)
	MOVE.W	wide_Ch,D6		; raw = npat * ch * 256
	MULU	#256,D6
	MOVE.L	D7,D5
	MULU	D6,D5
	ADD.L	#mod_patterns,D5	; + header
	MOVE.L	D5,D0
	MOVEQ	#1,D1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-198,A6)
	TST.L	D0
	BEQ.W	.nomem
	MOVE.L	D0,wide_SaveBuf
	MOVE.L	D5,wide_SaveLen
	MOVEA.L	D0,A1
	MOVEA.L	A4,A0
	MOVE.W	#mod_patterns/4-1,D0
.h:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.h
	MOVEA.L	wide_SaveBuf,A0		; id: 9CHN / xxCH
	MOVE.W	wide_Ch,D0
	CMP.W	#10,D0
	BCC.S	.two
	ADD.B	#'0',D0
	MOVE.B	D0,mod_id(A0)
	MOVE.B	#'C',mod_id+1(A0)
	MOVE.B	#'H',mod_id+2(A0)
	MOVE.B	#'N',mod_id+3(A0)
	BRA.S	.pat
.two:	AND.L	#$ffff,D0
	DIVU	#10,D0
	ADD.B	#'0',D0
	MOVE.B	D0,mod_id(A0)
	SWAP	D0
	ADD.B	#'0',D0
	MOVE.B	D0,mod_id+1(A0)
	MOVE.B	#'C',mod_id+2(A0)
	MOVE.B	#'H',mod_id+3(A0)
.pat:	MOVEA.L	wide_Pat,A0		; 128 bytes a row -> ch*4
	MOVE.L	D7,D3
	LSL.L	#6,D3
	SUBQ.L	#1,D3
	MOVE.W	wide_Ch,D2
	SUBQ.W	#1,D2
.row:	MOVEA.L	A0,A2
	MOVE.W	D2,D1
.cel:	MOVE.L	(A2)+,(A1)+
	DBF	D1,.cel
	LEA	WIDE_ROW(A0),A0
	SUBQ.L	#1,D3
	BPL.S	.row
	MOVE.L	wide_SaveBuf,dat_FileWriteAddr
	MOVE.L	wide_SaveLen,dat_FileWriteSize
.x:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; no memory for all channels: plain save aborts before the file is
; opened (old file stays); xpk/pp/exe write the 4ch view
.nomem:	MOVEM.L	(A7)+,D0-D7/A0-A6
	LEA	wide_MsgSaveMem(PC),A0
	JSR	pt_StatusLater41
	TST.W	dat_FileSizeMode
	BNE.S	.keep
	TST.L	dat_XPKWriteActive
	BNE.S	.keep
	TST.B	dat_SampleNameBuf
	BNE.S	.keep
	ADDQ.L	#4,A7			; out of the save, like a failed open
	JMP	pt_ShowMsgSetPal
.keep:	RTS

; d7 = patterns needed: wide_Pat grows, rows kept; z=1 no memory
; also takes every view pattern that holds cells (tab, output switch)
pt_WideGrow:
	MOVE.L	D0,-(A7)
	BSR.W	pt_WideNeed
	CMP.L	D0,D7
	BCC.S	.k
	MOVE.L	D0,D7
.k:	MOVE.L	(A7)+,D0
pt_WideGrowTo:
	MOVEM.L	D0-D2/A0-A1/A6,-(A7)
	IFD	DEBUGAUTO
	TST.W	dbg_WideDeny
	BEQ.S	.nd
	MOVEQ	#0,D0			; grow fails
	BRA.S	.r
.nd:
	ENDC
	MOVE.L	D7,D2
	MULU	#WIDE_PAT/64,D2
	LSL.L	#6,D2
	CMP.L	wide_PatSize,D2
	BLS.S	.ok
	MOVE.L	D2,D0
	MOVE.L	#$10001,D1		; MEMF_PUBLIC|MEMF_CLEAR
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-198,A6)
	TST.L	D0
	BEQ.S	.r
	MOVEA.L	wide_Pat,A0
	MOVEA.L	D0,A1
	MOVE.L	wide_PatSize,D1
	LSR.L	#2,D1
	BRA.S	.c1
.c:	MOVE.L	(A0)+,(A1)+
.c1:	SUBQ.L	#1,D1
	BPL.S	.c
	MOVEA.L	wide_Pat,A1		; replayer takes the new one next row
	MOVE.L	wide_PatSize,-(A7)
	MOVE.L	D0,wide_Pat
	MOVE.L	D2,wide_PatSize
	MOVE.L	(A7)+,D0
	JSR	(-210,A6)		; FreeMem old
.ok:	MOVEQ	#1,D0			; z=0
.r:	MOVEM.L	(A7)+,D0-D2/A0-A1/A6	; flags stay
	RTS

pt_WideSaveFree:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVE.L	wide_SaveBuf,D0
	BEQ.S	.r
	CLR.L	wide_SaveBuf
	MOVEA.L	D0,A1
	MOVE.L	wide_SaveLen,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-210,A6)
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

pt_WideTmpFree:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVE.L	wide_Tmp,D0
	BEQ.S	.r
	CLR.L	wide_Tmp
	MOVEA.L	D0,A1
	MOVE.L	#WIDE_TMP,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-210,A6)
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

wide_NotLoadedA:	DC.B	"NOT LOADED (AMIGUS)",0
wide_NotLoadedZ:	DC.B	"NOT LOADED (ZZ9000AX)",0
wide_NotLoadedB:	DC.B	"NOT LOADED (AMIGUS/ZZ9000AX)",0
wide_AskNoCard:	DC.B	10,10		; no card at all: both names
	DC.B	" More than 8 tracks need",10
	DC.B	" AmiGUS or ZZ9000AX card",10
	DC.B	"     Not loaded.",0
wide_AskSetupA:	DC.B	10,10
	DC.B	" More than 8 tracks need",10
	DC.B	" OUTPUT AMIGUS (SETUP).",10
	DC.B	"     Not loaded.",0
wide_AskSetupZ:	DC.B	10,10
	DC.B	" More than 8 tracks need",10
	DC.B	" OUTPUT ZZ9000AX (SETUP).",10
	DC.B	"     Not loaded.",0
wide_AskSetupB:	DC.B	10,10
	DC.B	" More than 8 tracks need",10
	DC.B	" OUTPUT AMIGUS/ZZ9000AX.",10
	DC.B	"     Not loaded.",0
wide_MsgNoMem:	DC.B	"WIDE MODULE: NO MEMORY, TRACKS 1-4 ONLY",0
wide_MsgTmpMem:	DC.B	"WIDE MODULE: NO MEMORY, NOT LOADED",0
wide_MsgSaveMem:	DC.B	"NOT ENOUGH MEMORY TO SAVE ALL CHANNELS",0
wide_MsgOnA:	DC.B	"WIDE MODULE ON AMIGUS",0
wide_MsgOnZ:	DC.B	"WIDE MODULE ON ZZ9000AX",0
wide_MsgOnB:	DC.B	"WIDE MODULE ON AMIGUS/ZZ9000AX",0
wide_MsgGrpMem:	DC.B	"NO MEMORY FOR THE OTHER TRACKS",0
wide_MsgViewMem:	DC.B	"NO MEMORY FOR THE 8 TRACK VIEW",0
	EVEN
; per card (pt_CardStr41): amigus, zz9000ax, both, none
wide_MsgNotLoaded:	DC.L	wide_NotLoadedA,wide_NotLoadedZ,wide_NotLoadedB,wide_NotLoadedB
wide_AskSetup:	DC.L	wide_AskSetupA,wide_AskSetupZ,wide_AskSetupB,wide_AskSetupB
wide_MsgOn:	DC.L	wide_MsgOnA,wide_MsgOnZ,wide_MsgOnB,wide_MsgOnB
