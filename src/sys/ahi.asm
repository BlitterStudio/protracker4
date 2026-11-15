; ahi out: mixer ring -> 2 channels (hard left, hard right), 2 dyn mono
; sounds each via soundfunc hook; a stereo sound plays its left side only
; in amigus fast 16 bit stereo
AHI_HALF	EQU	1024		; samples per half (2 bytes, m16s)
AHI_STALL	EQU	150		; ticks without a half: ahi is silent
AHIST_M16S	EQU	1
AHIST_DYNSAMPLE	EQU	1
AHI_TAGBASE	EQU	$80000000
AHIA_AudioID	EQU	AHI_TAGBASE+1
AHIA_MixFreq	EQU	AHI_TAGBASE+2
AHIA_Channels	EQU	AHI_TAGBASE+3
AHIA_Sounds	EQU	AHI_TAGBASE+4
AHIA_SoundFunc	EQU	AHI_TAGBASE+5
AHIC_Play	EQU	AHI_TAGBASE+80
AHIC_MixFreq_Query	EQU	AHI_TAGBASE+84
AHIDB_MinMixFreq	EQU	AHI_TAGBASE+112
AHIDB_MaxMixFreq	EQU	AHI_TAGBASE+113
_LVOAHI_AllocAudioA	EQU	-42
_LVOAHI_GetAudioAttrsA	EQU	-108
_LVOAHI_FreeAudio	EQU	-48
_LVOAHI_ControlAudioA	EQU	-60
_LVOAHI_SetVol	EQU	-66
_LVOAHI_SetFreq	EQU	-72
_LVOAHI_SetSound	EQU	-78
_LVOAHI_LoadSound	EQU	-90

; PROGDIR:PT.ahi present? -> ahi_Want, actual open in pt_AhiPoll
pt_AhiDetect:
	MOVEM.L	D0-D2/A0-A1/A6,-(A7)
	TST.B	ahi_Want		; tooltype ahi / already decided
	BNE.S	.r
	TST.B	snd_Started		; after start only the setup choice counts
	BNE.S	.choice
	MOVEA.L	dat_DosLibBase,A6
	MOVE.L	#ahi_FileName,D1
	MOVEQ	#-2,D2			; ACCESS_READ
	JSR	(-84,A6)		; Lock
	TST.L	D0
	BEQ.S	.choice
	MOVE.L	D0,D1
	JSR	(-90,A6)		; UnLock
	ST	ahi_Want
	BRA.S	.r
.choice:
	CMPI.B	#2,snd_Choice		; setup page / prefs: ahi
	BNE.S	.r
	MOVEA.L	ABSEXECBASE.W,A6	; ahi needs the 020 mixer (prefs
	BTST	#1,(297,A6)		; copied from a bigger amiga)
	BEQ.S	.r
	ST	ahi_Want
.r:	MOVEM.L	(A7)+,D0-D2/A0-A1/A6
	RTS

; runs in ahi process (AllocAudio fails in the main process) -> d0=0 ok
pt_AhiSetup:
	MOVEM.L	D1-D7/A0-A6,-(A7)
	IFD	DEBUGAUTO
	BSR.W	flt_DbgAlloc
	ENDC
	MOVEA.L	ABSEXECBASE.W,A6
	MOVE.B	#1,ahi_Step
	JSR	(-666,A6)		; CreateMsgPort
	MOVE.L	D0,ahi_Port
	BEQ.W	.fail
	MOVE.L	#80,D0
	MOVE.L	#$10001,D1		; MEMF_PUBLIC|MEMF_CLEAR
	JSR	(-198,A6)		; AllocMem
	MOVE.L	D0,ahi_Req1
	BEQ.W	.fail
	MOVEA.L	D0,A1
	MOVE.L	ahi_Port,14(A1)		; mn_ReplyPort
	MOVE.W	#80,18(A1)		; mn_Length
	MOVE.W	#4,48(A1)		; ahir_Version
	MOVE.B	#2,ahi_Step
	LEA	ahi_DevName(PC),A0
	MOVE.L	#255,D0			; AHI_NO_UNIT: library base only
	MOVEQ	#0,D1
	JSR	(-444,A6)		; OpenDevice
	MOVE.B	D0,ahi_IoErr
	TST.L	D0
	BNE.W	.fail
	ST	ahi_DevOpen
	MOVEA.L	ahi_Req1,A0
	MOVE.L	20(A0),ahi_Base		; io_Device = AHIBase
	MOVE.B	#3,ahi_Step
	MOVE.L	#AHI_HALF*8,D0		; 2 ch * 2 halves, m16s
	MOVE.L	#$10001,D1
	JSR	(-198,A6)
	MOVE.L	D0,ahi_Buf1
	BEQ.W	.fail
	MOVEA.L	ahi_Base,A6
	MOVE.L	snd_AhiMode,D0
	JSR	pt_SndAhiLimits41	; mode range -> mix rate
	JSR	pt_SndAhiAdapt41
	;--- hook + tags
	LEA	ahi_Hook,A0
	CLR.L	(A0)
	CLR.L	4(A0)
	MOVE.L	#pt_AhiSoundFunc,8(A0)	; h_Entry
	CLR.L	12(A0)
	CLR.L	16(A0)
	LEA	ahi_Tags,A0
	MOVE.L	#AHIA_AudioID,(A0)+
	MOVE.L	snd_AhiMode,(A0)+	; 0 = AHI_DEFAULT_ID
	MOVE.L	#AHIA_MixFreq,(A0)+
	MOVEQ	#0,D0
	MOVE.W	mix_Rate,D0
	BNE.S	.rate
	MOVE.W	#28604,D0
.rate:	MOVE.L	D0,(A0)+
	MOVE.L	#AHIA_Channels,(A0)+
	MOVE.L	#2,(A0)+
	MOVE.L	#AHIA_Sounds,(A0)+
	MOVE.L	#4,(A0)+
	MOVE.L	#AHIA_SoundFunc,(A0)+
	MOVE.L	#ahi_Hook,(A0)+
	CLR.L	(A0)+			; TAG_DONE
	MOVEA.L	ahi_Base,A6
	LEA	ahi_Tags,A1
	JSR	(_LVOAHI_AllocAudioA,A6)
	MOVE.L	D0,ahi_Ctrl
	BNE.S	.got
	TST.L	snd_AhiMode		; saved mode gone: default mode, once
	BEQ.W	.fail
	CLR.L	snd_AhiMode
	SF	snd_NameOk
	ST	ahi_ModeGone
	MOVEQ	#0,D0
	JSR	pt_SndAhiLimits41
	JSR	pt_SndAhiAdapt41
	LEA	ahi_Tags,A1
	CLR.L	4(A1)
	MOVEQ	#0,D0
	MOVE.W	mix_Rate,D0
	MOVE.L	D0,12(A1)
	JSR	(_LVOAHI_AllocAudioA,A6)
	MOVE.L	D0,ahi_Ctrl
	BEQ.W	.fail
.got:	LEA	ahi_Tags,A1		; rate ahi really runs at
	MOVE.L	#AHIC_MixFreq_Query,(A1)
	MOVE.L	#ahi_Real,4(A1)
	CLR.L	8(A1)
	MOVEA.L	ahi_Ctrl,A2
	JSR	(_LVOAHI_ControlAudioA,A6)
	IFD	DEBUGAUTO
	MOVE.L	dbg_AhiRealSet,D0	; test: a driver that rounds the rate
	BEQ.S	.nrs
	MOVE.L	D0,ahi_Real
.nrs:
	ENDC
	JSR	pt_MixApplyRate		; mixer to that rate: sounds 1:1
	MOVE.B	#4,ahi_Step
	; sound 0/1 = left halves, 2/3 = right halves (buf quarters)
	LEA	ahi_Info,A0
	MOVE.L	ahi_Buf1,D0
	MOVEQ	#3,D1
.si:	MOVE.L	#AHIST_M16S,(A0)+
	MOVE.L	D0,(A0)+
	MOVE.L	#AHI_HALF,(A0)+
	ADD.L	#AHI_HALF*2,D0
	DBF	D1,.si
	MOVEA.L	ahi_Ctrl,A2
	MOVEQ	#0,D2
	LEA	ahi_Info,A3
.ls:	MOVE.L	D2,D0
	MOVEQ	#AHIST_DYNSAMPLE,D1
	MOVEA.L	A3,A0
	JSR	(_LVOAHI_LoadSound,A6)
	TST.L	D0
	BNE.W	.fail
	LEA	12(A3),A3
	ADDQ.L	#1,D2
	CMP.W	#4,D2
	BNE.S	.ls
	MOVE.B	#5,ahi_Step
	; play
	LEA	ahi_Tags,A1
	MOVE.L	#AHIC_Play,(A1)
	MOVE.L	#1,4(A1)
	CLR.L	8(A1)
	MOVEA.L	ahi_Ctrl,A2
	JSR	(_LVOAHI_ControlAudioA,A6)
	TST.L	D0
	BNE.W	.fail
	CLR.B	ahi_Half
	BSR.W	pt_CardFltReset41
	MOVE.L	mix_WriteInt,ahi_ReadPos
	MOVEA.L	ahi_Ctrl,A2
	BSR.W	pt_AhiVolBoth
	MOVEQ	#0,D1
	MOVE.W	mix_Rate,D1
	BNE.S	.fr
	MOVE.W	#28604,D1
.fr:	MOVE.W	D1,ahi_FreqNow
	BSR.W	pt_AhiFreqBoth
	MOVEQ	#0,D0			; ch 0: sound 0 (left half 0, silent)
	MOVEQ	#0,D1
	MOVEQ	#0,D2
	MOVEQ	#0,D3			; full len
	MOVEQ	#1,D4			; immediate
	JSR	(_LVOAHI_SetSound,A6)
	MOVEQ	#1,D0			; ch 1: sound 2 (right half 0)
	MOVEQ	#2,D1
	MOVEQ	#0,D2
	MOVEQ	#0,D3
	MOVEQ	#1,D4
	JSR	(_LVOAHI_SetSound,A6)
	MOVE.B	#6,ahi_Step
	MOVEQ	#0,D0
	MOVEM.L	(A7)+,D1-D7/A0-A6
	RTS
.fail:	ST	ahi_Failed
	MOVEQ	#-1,D0
	MOVEM.L	(A7)+,D1-D7/A0-A6
	RTS

; soundfunc: ahi plays by the card clock, the mixer writes by the cia
; ticks; both drift apart. keep the ring distance near 2 halves by a
; small change of the ahi rate (max rate/256, below hearing) instead of
; a jump; the resync stays for big gaps (start, stalls)
pt_AhiServo41:
	MOVEM.L	D0-D2/A0-A2/A6,-(A7)
	MOVEQ	#0,D1
	MOVE.W	ahi_Freq,D1
	BEQ.S	.r
	MOVE.L	mix_WriteInt,D0
	SUB.L	ahi_ReadPos,D0
	AND.L	#MIX_RING-1,D0
	SUB.L	#2*AHI_HALF,D0		; error, samples
	CMP.L	#AHI_HALF,D0
	BLE.S	.lo
	MOVE.L	#AHI_HALF,D0
.lo:	CMP.L	#-AHI_HALF,D0
	BGE.S	.cl
	MOVE.L	#-AHI_HALF,D0
.cl:	MULS	D1,D0			; rate * error >> 18
	ASR.L	#8,D0
	ASR.L	#8,D0
	ASR.L	#2,D0
	ADD.L	D0,D1
	CMP.W	ahi_FreqNow,D1
	BEQ.S	.r
	MOVE.W	D1,ahi_FreqNow
	IFD	DEBUGFX
	ADDQ.L	#1,dbg_AhiServo
	ENDC
	MOVEA.L	ahi_Base,A6
	MOVEA.L	ahi_Ctrl,A2
	MOVE.L	D1,-(A7)
	MOVEQ	#0,D0			; ch 0, at the next sound
	MOVEQ	#0,D2
	JSR	(_LVOAHI_SetFreq,A6)
	MOVE.L	(A7)+,D1
	MOVEQ	#1,D0
	MOVEQ	#0,D2
	JSR	(_LVOAHI_SetFreq,A6)
.r:	MOVEM.L	(A7)+,D0-D2/A0-A2/A6
	RTS

; soundfunc (int): a0=hook a2=ctrl a1=msg
; half started -> fill other from ring, queue it; d2-d7/a2-a6 kept
pt_AhiSoundFunc:
	IFD	DEBUGAUTO
	TST.B	dbg_AhiMute		; test: a driver that never plays
	BEQ.S	.live
	MOVEQ	#0,D0
	RTS
.live:
	ENDC
	TST.W	(A1)			; ahism_Channel: left drives both
	BEQ.S	.ch0
	MOVEQ	#0,D0
	RTS
.ch0:	MOVEM.L	D2-D7/A2-A6,-(A7)
	ADDQ.L	#1,ahi_Sent
	MOVE.B	ahi_Half,D7
	EOR.B	#1,D7			; other half
	MOVE.B	D7,ahi_Half
	MOVEA.L	ahi_Buf1,A3		; a3 = left half, right half at +AHI_HALF*4
	TST.B	D7
	BEQ.S	.h0
	LEA	AHI_HALF*2(A3),A3
.h0:	MOVE.W	#AHI_HALF-1,D6
	TST.B	mix_Active
	BEQ.W	.silence
	TST.L	mix_Ring
	BEQ.W	.silence
	; keep 2 halves behind write ptr, too close or overrun -> resync
	MOVE.L	mix_WriteInt,D0
	SUB.L	ahi_ReadPos,D0
	AND.L	#MIX_RING-1,D0
	IFD	DEBUGFX
	JSR	dbg_AhiLog		; time, distance
	ENDC
	CMP.L	#AHI_HALF,D0
	BLO.S	.resync
	CMP.L	#MIX_RING-AHI_HALF,D0
	BLS.S	.go
.resync:
	IFD	DEBUGFX
	JSR	dbg_AhiRes
	ENDC
	MOVE.L	mix_WriteInt,D0
	SUB.L	#2*AHI_HALF,D0
	AND.L	#MIX_RING-1,D0
	MOVE.L	D0,ahi_ReadPos
	ADDQ.L	#1,ahi_Resync
	BSR.W	pt_CardFltReset41
.go:	BSR.W	pt_AhiServo41		; card clock vs cia ticks
	MOVEA.L	mix_Ring,A0		; ch0
	LEA	MIX_RING(A0),A4		; ch1
	LEA	MIX_RING(A4),A5		; ch2
	LEA	MIX_RING(A5),A6		; ch3
	MOVE.L	ahi_ReadPos,D1
	MOVEQ	#0,D5
	MOVE.B	snd_StereoDown,D5	; stereo width 0 = paula hard, 4 = mono
.cv:	MOVE.B	(A0,D1.L),D2
	EXT.W	D2
	MOVE.B	(A6,D1.L),D3
	EXT.W	D3
	ADD.W	D3,D2			; left = 0+3
	MOVE.B	(A4,D1.L),D3
	EXT.W	D3
	MOVE.B	(A5,D1.L),D4
	EXT.W	D4
	ADD.W	D4,D3			; right = 1+2
	TST.W	D5
	BEQ.S	.wide
	MOVE.W	D2,D4			; cross-feed d5/8 of diff
	SUB.W	D3,D4
	MULS	D5,D4
	ASR.W	#3,D4
	SUB.W	D4,D2
	ADD.W	D4,D3
.wide:	LSL.W	#7,D3
	LSL.W	#7,D2
	MOVE.W	D3,AHI_HALF*4(A3)
	MOVE.W	D2,(A3)+
	IFD	DEBUGFX
	TST.W	D2
	BPL.S	.pos
	NEG.W	D2
.pos:	CMP.W	ahi_Peak,D2
	BLS.S	.npk
	MOVE.W	D2,ahi_Peak		; peak
.npk:
	ENDC
	ADDQ.L	#1,D1
	AND.L	#MIX_RING-1,D1
	DBF	D6,.cv
	MOVE.L	D1,ahi_ReadPos
	ADDQ.L	#1,ahi_Done
	BRA.S	.queue
.silence:
	CLR.W	AHI_HALF*4(A3)
	CLR.W	(A3)+
	DBF	D6,.silence
.queue:	BSR.W	pt_CardFlt41
	MOVEA.L	ahi_Base,A6
	MOVEA.L	ahi_Ctrl,A2
	MOVEQ	#0,D0			; ch 0
	MOVEQ	#0,D1
	MOVE.B	D7,D1			; sound = filled half
	MOVEQ	#0,D2
	MOVEQ	#0,D3
	MOVEQ	#0,D4			; after current sound
	JSR	(_LVOAHI_SetSound,A6)
	MOVEQ	#1,D0			; ch 1: right half
	MOVEQ	#2,D1
	ADD.B	D7,D1
	MOVEQ	#0,D2
	MOVEQ	#0,D3
	MOVEQ	#0,D4
	JSR	(_LVOAHI_SetSound,A6)
	MOVEM.L	(A7)+,D2-D7/A2-A6
	MOVEQ	#0,D0
	RTS

; a2 = ctrl, a6 = ahi base: setup VOLUME, ch 0 hard left, ch 1 hard right
pt_AhiVolBoth:
	MOVEM.L	D0-D3/A0-A1,-(A7)
	JSR	pt_SndAhiVol		; -> d1 = vol 16.16
	MOVE.L	D1,-(A7)
	MOVEQ	#0,D0
	MOVEQ	#0,D2			; left
	MOVEQ	#1,D3			; AHISF_IMM
	JSR	(_LVOAHI_SetVol,A6)
	MOVE.L	(A7)+,D1
	MOVEQ	#1,D0
	MOVE.L	#$10000,D2		; right
	MOVEQ	#1,D3
	JSR	(_LVOAHI_SetVol,A6)
	MOVEM.L	(A7)+,D0-D3/A0-A1
	RTS

; d1 = rate, a2 = ctrl, a6 = ahi base: both channels, immediate
pt_AhiFreqBoth:
	MOVEM.L	D0-D2/A0-A1,-(A7)
	MOVE.L	D1,-(A7)
	MOVEQ	#0,D0
	MOVEQ	#1,D2
	JSR	(_LVOAHI_SetFreq,A6)
	MOVE.L	(A7)+,D1
	MOVEQ	#1,D0
	MOVEQ	#1,D2
	JSR	(_LVOAHI_SetFreq,A6)
	MOVEM.L	(A7)+,D0-D2/A0-A1
	RTS

; mixed pairs: paula vol 0
pt_AhiPaulaMute:
	TST.B	ahi_NoPaula		; paula owned by ahi, hands off
	BEQ.S	.own
	RTS
.own:	MOVEM.L	D0-D1/A0,-(A7)
	MOVEQ	#0,D1
	MOVE.B	mix_PairMask,D1
	LEA	AUD0VOL,A0
	MOVEQ	#0,D0
.v:	BTST	D0,D1
	BEQ.S	.n
	CLR.W	(A0)
.n:	LEA	aud_SIZEOF(A0),A0
	ADDQ.W	#1,D0
	CMP.W	#4,D0
	BNE.S	.v
	MOVEM.L	(A7)+,D0-D1/A0
	RTS

; teardown (ahi process)
pt_AhiTeardown:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	CLR.L	ahi_Real
	CLR.L	snd_AhiMin
	CLR.L	snd_AhiMax
	MOVE.L	ahi_Ctrl,D0
	BEQ.S	.noctrl
	MOVEA.L	D0,A2
	MOVEA.L	ahi_Base,A6
	LEA	ahi_Tags,A1
	MOVE.L	#AHIC_Play,(A1)
	CLR.L	4(A1)
	CLR.L	8(A1)
	JSR	(_LVOAHI_ControlAudioA,A6)
	MOVEA.L	ahi_Ctrl,A2
	JSR	(_LVOAHI_FreeAudio,A6)	; unloads sounds too
	CLR.L	ahi_Ctrl
.noctrl:
	MOVEA.L	ABSEXECBASE.W,A6
	TST.B	ahi_DevOpen
	BEQ.S	.nodev
	MOVEA.L	ahi_Req1,A1
	JSR	(-450,A6)		; CloseDevice
	SF	ahi_DevOpen
.nodev:	MOVE.L	ahi_Req1,D0
	BEQ.S	.noreq
	MOVEA.L	D0,A1
	MOVE.L	#80,D0
	JSR	(-210,A6)		; FreeMem
	CLR.L	ahi_Req1
.noreq:	MOVE.L	ahi_Buf1,D0
	BEQ.S	.nobuf
	MOVEA.L	D0,A1
	MOVE.L	#AHI_HALF*8,D0
	JSR	(-210,A6)
	CLR.L	ahi_Buf1
.nobuf:	MOVE.L	ahi_Port,D0
	BEQ.S	.r
	MOVEA.L	D0,A0
	JSR	(-672,A6)		; DeleteMsgPort
	CLR.L	ahi_Port
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; task poll: follow mix_Rate changes
pt_AhiPoll:
	TST.B	ahi_Active
	BNE.S	.act
	RTS
.act:	ADDQ.L	#1,ahi_Polls
	MOVE.L	ahi_Sent,D0		; ahi asked for a half since?
	CMP.L	ahi_SentSeen,D0
	BEQ.S	.st
	MOVE.L	D0,ahi_SentSeen
	CLR.W	ahi_Ticks
	BRA.S	.rt
.st:	CMPI.W	#AHI_STALL,ahi_Ticks	; silent for seconds: other rate,
	BCS.S	.rt			; then paula
	JMP	pt_AhiStall41
.rt:	MOVE.W	mix_Rate,D0		; rate changed?
	BEQ.S	.r
	CMP.W	ahi_Freq,D0
	BEQ.S	.r
	MOVEM.L	D0-D2/A0-A2/A6,-(A7)
	MOVE.W	D0,ahi_Freq
	MOVE.W	D0,ahi_FreqNow
	BSR.W	pt_CardFltReset41
	MOVEQ	#0,D1
	MOVE.W	D0,D1
	MOVEA.L	ahi_Ctrl,A2
	MOVEA.L	ahi_Base,A6
	BSR.W	pt_AhiFreqBoth
	MOVEM.L	(A7)+,D0-D2/A0-A2/A6
.r:	RTS

;--- ahi process
; start proc, wait 3 s max -> d0=0 ok, else ahi_Failed
pt_AhiOpen:
	MOVEM.L	D1-D7/A0-A6,-(A7)
	TST.B	ahi_Active
	BNE.W	.ok
	CLR.B	ahi_ProcState		; 0 starting, 1 ready, 2 error, 3 gone
	MOVEA.L	dat_DosLibBase,A6
	MOVE.L	#ahi_ProcTags,D1
	JSR	(-498,A6)		; CreateNewProc
	MOVE.L	D0,ahi_Proc
	BEQ.S	.fail
	MOVE.W	#150,D7			; 3 s max
.wait:	MOVE.B	ahi_ProcState,D0
	BNE.S	.got
	MOVEQ	#1,D1
	JSR	(-198,A6)		; Delay(1)
	DBF	D7,.wait
	BRA.S	.fail
.got:	CMP.B	#1,D0
	BNE.S	.fail
	ST	ahi_Active
	TST.B	ahi_ModeGone
	BEQ.S	.mg
	SF	ahi_ModeGone
	LEA	ahi_MsgGone,A0
	JSR	pt_StatusLater41
.mg:	TST.B	mix_Active		; ring already on paula? -> pair dma off
	BEQ.S	.ok
	MOVEQ	#0,D0
	MOVE.B	mix_PairMask,D0
	MOVE.W	D0,DMACON
	BSR.W	pt_AhiPaulaMute
.ok:	MOVEQ	#0,D0
	MOVEM.L	(A7)+,D1-D7/A0-A6
	RTS
.fail:	TST.L	ahi_Proc		; slow or failed: no process left behind
	BEQ.S	.f2
	BSR.S	pt_AhiClose
.f2:	ST	ahi_Failed
	MOVEQ	#-1,D0
	MOVEM.L	(A7)+,D1-D7/A0-A6
	RTS

; stop process via ctrl-c, wait max 3 s
pt_AhiClose:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	SF	ahi_Active
	MOVE.L	ahi_Proc,D0
	BEQ.S	.r
	MOVEA.L	D0,A1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-132,A6)		; Forbid: it must not end before the signal
	CMP.B	#3,ahi_ProcState
	BEQ.S	.dead
	MOVE.L	#$1000,D0		; SIGBREAKF_CTRL_C
	JSR	(-324,A6)		; Signal
.dead:	JSR	(-138,A6)		; Permit
	MOVEA.L	dat_DosLibBase,A6
	MOVE.W	#150,D7
.w:	CMP.B	#3,ahi_ProcState
	BEQ.S	.gone
	MOVEQ	#1,D1
	JSR	(-198,A6)		; Delay(1)
	DBF	D7,.w
.gone:	CLR.L	ahi_Proc
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; proc entry: setup, wait ctrl-c, teardown
; Forbid before exit, code must not be freed under us
pt_AhiProc:
	BSR.W	pt_AhiSetup
	TST.L	D0
	BNE.S	.err
	MOVE.B	#1,ahi_ProcState
	MOVEA.L	ABSEXECBASE.W,A6
	MOVE.L	#$1000,D0
	JSR	(-318,A6)		; Wait(SIGBREAKF_CTRL_C)
	BRA.S	.down
.err:	MOVE.B	#2,ahi_ProcState
.down:	BSR.W	pt_AhiTeardown
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-132,A6)		; Forbid
	MOVE.B	#3,ahi_ProcState
	MOVEQ	#0,D0
	RTS

ahi_ProcTags:	DC.L	$800003eb,pt_AhiProc	; NP_Entry
		DC.L	$800003f4,ahi_ProcName	; NP_Name
		DC.L	$800003f5,10		; NP_Priority
		DC.L	$800003f3,16384		; NP_StackSize
		DC.L	0,0
ahi_ProcName:	DC.B	"PT4.1 AHI",0
	CNOP	0,2

;--- hooks
; ahi: paula untouched (no audio.device/ints/dmacon), 68020+

; patch: LEA dat_AudioMsgPort,A1 at pt_OpenAudioDev
pt_AhiAudioDevOpen:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.B	disk_ToolDone		; read tooltypes early
	BNE.S	.tt
	ST	disk_ToolDone
	JSR	pt_CfgToolTypes
.tt:	JSR	pt_PrefsLoad41
	JSR	pt_AutoAhi		; first run: pick ahi
	JSR	pt_AhiDetect
	TST.B	ahi_Want
	BEQ.S	.paula
	MOVEA.L	ABSEXECBASE.W,A6
	BTST	#1,(297,A6)		; AttnFlags AFB_68020
	BEQ.S	.paula
	JSR	pt_AhiOpen
	TST.L	D0
	BNE.S	.paula
	ST	ahi_NoPaula
	MOVEM.L	(A7)+,D0-D7/A0-A6
	ADDQ.L	#4,A7			; skip pt_OpenAudioDev
	MOVEQ	#0,D0			; ok, Z set
	RTS
.paula:	MOVEM.L	(A7)+,D0-D7/A0-A6
	SF	ahi_Want		; not taken: paula has the output
	MOVE.W	#$00ff,$DFF09E		; adkcon: no modulation (start, back from ahi)
	LEA	dat_AudioMsgPort,A1
	RTS

; patch: LEA dat_AudioIOReq,A1 at pt_CloseAudioDev
pt_AhiAudioDevClose:
	TST.B	ahi_NoPaula
	BNE.S	.skip
	LEA	dat_AudioIOReq,A1
	RTS
.skip:	ADDQ.L	#4,A7
	MOVEQ	#-1,D0			; like original ok path
	RTS

; patch: MOVE.W #$0780,INTENA at pt_AddAudioInts
pt_AhiAudIntsAdd:
	TST.B	ahi_NoPaula
	BNE.S	.skip
	MOVE.W	#$0780,INTENA
	RTS
.skip:	ADDQ.L	#4,A7
	RTS

; patch: MOVEQ #7,D0 / MOVEA.L dat_RpOldAudInt0,A1 at pt_RemoveAudioInts
pt_AhiAudIntsRemove:
	TST.B	ahi_NoPaula
	BNE.S	.skip
	MOVEQ	#7,D0
	MOVEA.L	dat_RpOldAudInt0,A1
	RTS
.skip:	ADDQ.L	#4,A7
	RTS

; patch: paula shutdown in pt_StopAllAudio
pt_AhiStopHw:
	TST.B	ahi_NoPaula
	BNE.S	.r
	MOVE.W	#$0780,INTENA
	MOVE.W	#$000f,DMACON
	CLR.W	AUD0VOL
	CLR.W	AUD1VOL
	CLR.W	AUD2VOL
	CLR.W	AUD3VOL
.r:	RTS

ahi_DevName:	DC.B	"ahi.device",0
ahi_FileName:	DC.B	"PROGDIR:PT.ahi",0
	CNOP	0,2
