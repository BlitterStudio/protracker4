; ON LOAD: 4ch module in 8ch mode -> pt to 4ch first (AUTO), like the
; original 4ch -> 8ch switch for 8chn; KEEP loads it into 8 tracks

; z=0: pt is in 4ch mode now (was, or switched); z=1: 8ch, KEEP
pt_LoadModeAuto:
	BTST	#5,dat_ModeFlags
	BNE.S	.y
	TST.B	prf_LoadKeep
	BNE.S	.keep
	MOVEM.L	D0-D7/A0-A6,-(A7)
	JSR	pt_BtnMainStop		; no replayer tick on the old buffer
	MOVE.W	#1,dat_DiskOpState
	BSET	#5,dat_ModeFlags
	JSR	pt_ClearScreenBuf2
	MOVE.W	#4,dat_RpNumChannels
	MOVEM.L	(A7)+,D0-D7/A0-A6
.y:	ANDI	#$fb,CCR
	RTS
.keep:	ORI	#4,CCR
	RTS

; module load, before the file opens: every voice of every output
; stops now (a held loop would ring through the load); then the
; changed flag as before
pt_LoadStop41:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.L	dat_RpPlayMode
	BEQ.S	.idle
	JSR	pt_BtnMainStop
	BRA.S	.x
.idle:	JSR	pt_StopAllAudio		; keyboard notes, sampler
.x:	MOVEM.L	(A7)+,D0-D7/A0-A6
	JMP	pt_ChgClear41

; 8chn from the id chain: stop play before the 4ch -> 8ch switch
pt_Load8Stop41:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	JSR	pt_BtnMainStop
	MOVEM.L	(A7)+,D0-D7/A0-A6
	JMP	pt_0E4C

; module buffer for 100 patterns (m!k!, 8ch) failed: low or split memory.
; the 64 pattern buffer was freed just before, so ask for that size again;
; the loader keeps the patterns that fit (pt_FmtPatCount). d0 = buffer
pt_ModBuf41:
	TST.L	D0
	BNE.S	.r
	MOVEM.L	D1/A0-A1/A6,-(A7)
	MOVE.L	#1084+64*1024,D0
	BTST	#5,dat_ModeFlags	; set = 4ch
	BNE.S	.s
	MOVE.L	#1084+64*2048,D0
.s:	MOVE.L	D0,dat_SampleEditCfg
	MOVE.L	#63,dat_SampleEditState
	CLR.B	dat_PatternBufFlag
	MOVE.L	#$10001,D1		; MEMF_PUBLIC|MEMF_CLEAR
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-198,A6)		; AllocMem
	TST.L	D0
	BEQ.S	.x
	LEA	ld_Msg64,A0
	JSR	pt_StatusLater41
	TST.L	D0
.x:	MOVEM.L	(A7)+,D1/A0-A1/A6
.r:	RTS
ld_Msg64:	DC.B	"LOW MEMORY: 64 PATTERNS MAX",0
	EVEN

; pt_InitModulePart freed the old block and got no new one. 8ch wanted:
; an empty 4ch song in a 64 pattern block (the freed one was at least
; that big) and the 4ch screen instead of the 8ch one; never block 0
pt_ModNoMem41:
	BTST	#5,dat_ModeFlags
	BNE.S	.r			; 4ch block failed: nothing smaller
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)	; block before the box: its main pass
					; would give the 8ch mixer the memory
	MOVE.L	#1084+64*1024,D0
	MOVE.L	D0,dat_SampleEditCfg
	MOVE.L	#$10001,D1		; MEMF_PUBLIC|MEMF_CLEAR
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-198,A6)		; AllocMem
	MOVE.L	D0,dat_ModulePtr
	MOVEM.L	(A7)+,D0-D1/A0-A1/A6	; ccr stays
	BEQ.S	.r
	BSET	#5,dat_ModeFlags
	JSR	pt_Trk4Mode41
	JSR	pt_NewBlk41
	JSR	pt_SetupPaletteMode	; "NOT ENOUGH MEMORY!"
	ADDQ.L	#8,A7			; leave pt_InitModulePart and the 8ch screen
	JMP	pt_063B			; 4ch screen
.r:	JMP	pt_SetupPaletteMode

; 6chn/8chn load after the 4ch -> 8ch switch: no 8ch block -> stop
pt_Ld8Buf41:
	JSR	pt_ClearScreenBuf2
	BTST	#5,dat_ModeFlags
	BNE.S	.x
	TST.L	dat_ModulePtr
	BEQ.S	.x
	RTS
.x:	ADDQ.L	#4,A7
pt_LdNoMem41:
	JSR	pt_CloseFileHandle
	LEA	ld_MsgNoMem(PC),A0
	JMP	pt_FinishPaletteEdit

; song load, mode taken from the song (inside the caller's MOVEM)
pt_LdSongBuf41:
	JSR	pt_ClearScreenBuf2
	BSR.S	pt_LdModeOk41
	BNE.S	.x
	RTS
.x:	LEA	4+15*4(A7),A7		; return and the caller's registers
	BRA.S	pt_LdNoMem41

pt_LdSong2Buf41:
	MOVEM.L	(A7)+,D0-D7/A0-A6
	BSR.S	pt_LdModeOk41
	BNE.S	pt_LdNoMem41
	JMP	pt_09F2

; z=1: a block in the mode the song asked for
pt_LdModeOk41:
	MOVEM.L	D0-D1,-(A7)
	TST.L	dat_ModulePtr
	SEQ	D0
	BTST	#5,dat_ModeFlags
	SNE	D1
	BTST	#5,dat_SongModified
	BEQ.S	.c
	NOT.B	D1
.c:	OR.B	D1,D0
	MOVEM.L	(A7)+,D0-D1		; ccr stays
	RTS

ld_MsgNoMem:	DC.B	"NOT ENOUGH MEMORY, NOT LOADED",0
	EVEN
