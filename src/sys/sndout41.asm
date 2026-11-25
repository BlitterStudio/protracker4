; sound output glue: setup VOLUME on all paula channels, ahi mode limits,
; mix rate text of the running output

;--- volume
; d0.w 0..64 -> scaled by setup VOLUME (paula registers only)
	IFD	DEBUGAUTO
pt_SndHwVol41:
	TST.W	D0
	BEQ.S	pt_SndHwVolX
	MOVE.W	D0,dbg_HwVolIn
	BSR.S	pt_SndHwVolX
	MOVE.W	D0,dbg_HwVolOut
	RTS
	ELSE
pt_SndHwVol41:
	ENDC
pt_SndHwVolX:
	TST.B	snd_VolDown
	BEQ.S	.r
	MOVE.L	D1,-(A7)
	MOVE.W	D0,D1
	JSR	pt_SndPaulaVol
	MULU	D1,D0
	ADD.W	#32,D0
	LSR.W	#6,D0
	MOVE.L	(A7)+,D1
.r:	RTS

; same, only if a5 points to the paula registers (not a shadow);
; shadows may sit above $dff000 (fast ram on 32 bit boards)
pt_SndHwVolA5:
	CMPA.L	#AUD0LCH,A5
	BCS.S	.r
	CMPA.L	#AUD0LCH+4*aud_SIZEOF,A5
	BCS.S	pt_SndHwVol41
.r:	RTS

; volume gad: rewrite what paula plays now (ring or direct channels)
pt_SndPaulaLive41:
	TST.B	ahi_NoPaula
	BNE.S	.x
	TST.B	agus_On
	BNE.S	.x
	MOVEM.L	D0-D2/A0/A5,-(A7)
	LEA	AUD0LCH,A5
	LEA	dat_Channel1,A0
	MOVEQ	#0,D2
.c:	TST.B	mix_Active
	BEQ.S	.dir
	BTST	D2,mix_PairMask
	BEQ.S	.dm
	JSR	pt_SndPaulaVol		; ring channel
	MOVE.W	D0,(aud_VOL,A5)
	IFD	DEBUGAUTO
	MOVE.W	D0,dbg_RingVol
	ENDC
	BRA.S	.n
.dm:	TST.B	mix_Is68k		; direct pair: next tick writes it
	BNE.S	.n
.dir:	JSR	pt_0179
.n:	LEA	n_SIZEOF(A0),A0
	LEA	aud_SIZEOF(A5),A5
	ADDQ.W	#1,D2
	CMP.W	#4,D2
	BNE.S	.c
	MOVEM.L	(A7)+,D0-D2/A0/A5
.x:	RTS

;--- samples for paula dma
; the mixer lets samples go to fast ram (cpu reads them); when paula
; plays them itself (4ch direct after ahi, card or 8ch) they must sit
; in chip ram: move them over, pointers of the channels follow
pt_SmpChip41:
	TST.B	snd_Switch
	BNE.S	.r
	TST.B	smp_ChipRetry
	BEQ.S	pt_SmpChipNow41
	ADDQ.B	#1,smp_ChipPoll		; no chip ram last time: ask now and then
	MOVE.B	smp_ChipPoll,D0
	AND.B	#63,D0
	BNE.S	pt_SmpChipNow41
	MOVEM.L	D1/A0-A1/A6,-(A7)
	MOVEA.L	ABSEXECBASE.W,A6
	MOVE.L	#$20002,D1		; MEMF_CHIP|MEMF_LARGEST
	JSR	(-216,A6)		; AvailMem
	MOVEM.L	(A7)+,D1/A0-A1/A6
	CMP.L	smp_ChipNeed,D0
	BCS.S	pt_SmpChipNow41
	ST	smp_ChipDue
	BRA.S	pt_SmpChipNow41
.r:	RTS
; output switch: mixer off, snd_Switch keeps the tick from it
pt_SmpChipNow41:
	TST.B	smp_ChipDue
	BEQ.W	.x
	TST.B	mix_Active		; mixer reads them by cpu
	BNE.W	.x
	TST.B	ahi_NoPaula
	BNE.W	.x
	TST.B	agus_On
	BNE.W	.x
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.L	dat_RpPlayMode		; playing: no dyn voice in the middle
	BEQ.S	.go
	LEA	dat_Channel1,A0
	MOVEQ	#7,D0
.dy:	TST.B	(n_pt4_chunked,A0)
	BNE.W	.later
	LEA	n_SIZEOF(A0),A0
	DBF	D0,.dy
.go:	SF	smp_ChipDue
	SF	smp_ChipFail
	SF	smp_ChipRetry
	CLR.L	smp_ChipNeed
	LEA	dat_ModulePtr+4,A2	; slots 1-31, sizes at +124
	MOVEQ	#124,D6
	MOVEQ	#30,D7
.s:	BSR.S	pt_SmpChipOne
	ADDQ.L	#4,A2
	DBF	D7,.s
	MOVE.L	smx_Mem,D0		; entries 32-63
	BEQ.S	.nx
	MOVEA.L	D0,A2
	LEA	SMX_PTR(A2),A2
	MOVE.L	#SMX_LEN-SMX_PTR,D6
	MOVEQ	#SMX_N-1,D7
.e:	BSR.S	pt_SmpChipOne
	ADDQ.L	#4,A2
	DBF	D7,.e
.nx:	TST.B	smp_ChipFail
	BEQ.S	.r
	CLR.L	snd_ResMode		; paula would play noise from fast ram
	TST.L	dat_RpPlayMode
	BEQ.S	.ms
	JSR	pt_BtnMainStop
.ms:	LEA	smp_MsgChip(PC),A0
	JSR	pt_StatusLater41
	BRA.S	.r
.later:	ST	smp_ChipDue		; again next pass
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
.x:	RTS

; a2 -> sample pointer, d6 = offset of its size: fast -> chip
pt_SmpChipOne:
	MOVE.L	(A2),D4			; d4 = old
	BEQ.W	.r
	MOVE.L	(A2,D6.L),D5		; d5 = size
	BEQ.W	.r
	MOVEA.L	ABSEXECBASE.W,A6
	MOVEA.L	D4,A1
	JSR	(-534,A6)		; TypeOfMem
	BTST	#1,D0			; MEMF_CHIP
	BNE.W	.r
	IFD	DEBUGAUTO
	TST.B	dbg_ChipDeny
	BNE.W	.fail
	ENDC
	MOVE.L	D5,D0
	MOVEQ	#3,D1			; MEMF_PUBLIC|MEMF_CHIP
	JSR	(-198,A6)		; AllocMem
	TST.L	D0
	BEQ.W	.fail
	MOVE.L	D0,D3			; d3 = new
	MOVEA.L	D4,A0
	MOVEA.L	D3,A1
	MOVE.L	D5,D0
	JSR	(-624,A6)		; CopyMem
	JSR	(-120,A6)		; Disable: replayer irq
	MOVE.L	D3,(A2)
	LEA	dat_Channel1,A0
	MOVEQ	#7,D2
.c:	LEA	(n_start,A0),A1
	BSR.W	pt_SmpChipPtr
	LEA	(n_loopstart,A0),A1
	BSR.W	pt_SmpChipPtr
	LEA	(n_wavestart,A0),A1
	BSR.W	pt_SmpChipPtr
	LEA	(n_pt4_samplestart,A0),A1
	BSR.W	pt_SmpChipPtr
	CMP.W	#4,D2			; paula ch 1-4: loop regs again
	BCS.S	.n
	MOVE.L	(n_loopstart,A0),D0
	BEQ.S	.n
	MOVE.W	#7,D1
	SUB.W	D2,D1
	LSL.W	#4,D1
	LEA	AUD0LCH,A1
	ADDA.W	D1,A1
	MOVE.L	D0,(A1)
	MOVE.W	(n_replen,A0),4(A1)
.n:	LEA	n_SIZEOF(A0),A0
	DBF	D2,.c
	LEA	vu8_Pos,A0		; scopes read the samples: follow the move
	MOVEQ	#7,D2
	BSR.W	pt_SmpChipScope
	LEA	dat_ScopeChanPos,A0
	MOVEQ	#3,D2
	BSR.W	pt_SmpChipScope
	LEA	vu8_Src,A0
	MOVEQ	#7,D2
.q:	MOVEA.L	A0,A1
	BSR.W	pt_SmpChipPtr
	ADDQ.L	#8,A0
	DBF	D2,.q
	JSR	(-126,A6)		; Enable
	MOVEA.L	D4,A1
	MOVE.L	D5,D0
	JSR	(-210,A6)		; FreeMem old
.r:	RTS
.fail:	ST	smp_ChipFail
	ST	smp_ChipRetry
	MOVE.L	smp_ChipNeed,D0
	BEQ.S	.nd
	CMP.L	D5,D0
	BLS.S	.r2
.nd:	MOVE.L	D5,smp_ChipNeed
.r2:	RTS

; (a1) in old block d4..d4+d5 -> into the new one at d3
pt_SmpChipPtr:
	MOVE.L	(A1),D0
	SUB.L	D4,D0
	BCS.S	.r
	CMP.L	D5,D0
	BCC.S	.r
	ADD.L	D3,D0
	MOVE.L	D0,(A1)
.r:	RTS

; scope pos tables: a0 -> d2+1 entries of 20 bytes (pos, end, loop start,
; loop end); an end pointer may sit right behind the old block
pt_SmpChipScope:
.l:	MOVEA.L	A0,A1
	BSR.S	pt_SmpChipPtr
	LEA	(4,A0),A1
	BSR.S	pt_SmpChipPtrE
	LEA	(8,A0),A1
	BSR.S	pt_SmpChipPtr
	LEA	(12,A0),A1
	BSR.S	pt_SmpChipPtrE
	LEA	(20,A0),A0
	DBF	D2,.l
	RTS

; same for an end pointer: old block d4+1..d4+d5
pt_SmpChipPtrE:
	MOVE.L	(A1),D0
	SUB.L	D4,D0
	BLS.S	.r
	CMP.L	D5,D0
	BHI.S	.r
	ADD.L	D3,D0
	MOVE.L	D0,(A1)
.r:	RTS

; z=1: the samples in fast ram fit into chip ram (biggest block, sum)
pt_SmpChipFits41:
	MOVEM.L	D1-D7/A0-A6,-(A7)
	MOVEQ	#0,D2
	MOVEQ	#0,D3
	LEA	dat_ModulePtr+4,A2
	MOVEQ	#124,D6
	MOVEQ	#30,D7
.s:	BSR.S	.one
	ADDQ.L	#4,A2
	DBF	D7,.s
	MOVE.L	smx_Mem,D0
	BEQ.S	.t
	MOVEA.L	D0,A2
	LEA	SMX_PTR(A2),A2
	MOVE.L	#SMX_LEN-SMX_PTR,D6
	MOVEQ	#SMX_N-1,D7
.e:	BSR.S	.one
	ADDQ.L	#4,A2
	DBF	D7,.e
.t:	MOVEA.L	ABSEXECBASE.W,A6
	MOVE.L	#$20002,D1		; MEMF_CHIP|MEMF_LARGEST
	JSR	(-216,A6)		; AvailMem
	CMP.L	D2,D0
	BCS.S	.no
	MOVEQ	#2,D1			; MEMF_CHIP
	JSR	(-216,A6)
	CMP.L	D3,D0
	BCS.S	.no
	MOVEQ	#0,D0
	BRA.S	.x
.no:	MOVEQ	#1,D0
.x:	MOVEM.L	(A7)+,D1-D7/A0-A6	; flags stay
	RTS
.one:	MOVE.L	(A2),D4
	BEQ.S	.or
	MOVE.L	(A2,D6.L),D5
	BEQ.S	.or
	MOVEA.L	ABSEXECBASE.W,A6
	MOVEA.L	D4,A1
	JSR	(-534,A6)		; TypeOfMem
	BTST	#1,D0			; MEMF_CHIP
	BNE.S	.or
	CMP.L	D2,D5
	BLS.S	.a
	MOVE.L	D5,D2
.a:	ADD.L	D5,D3
.or:	RTS

smp_MsgChip:	DC.B	"NOT ENOUGH CHIP RAM FOR PAULA",0
	EVEN

;--- ahi mode limits
; d0 = mode id, a6 = AHIBase -> snd_AhiMin/Max (0 = unknown)
pt_SndAhiLimits41:
	MOVEM.L	D0-D1/A0-A2,-(A7)
	CLR.L	snd_AhiMin
	CLR.L	snd_AhiMax
	LEA	snd_Tags,A1
	MOVE.L	#AHIDB_MinMixFreq,(A1)
	MOVE.L	#snd_AhiMin,4(A1)
	MOVE.L	#AHIDB_MaxMixFreq,8(A1)
	MOVE.L	#snd_AhiMax,12(A1)
	CLR.L	16(A1)
	SUBA.L	A2,A2
	JSR	(_LVOAHI_GetAudioAttrsA,A6)
	MOVEM.L	(A7)+,D0-D1/A0-A2
	RTS

; d1.w mix rate -> into the mode range, never above 32 khz; once ahi
; is open the rate it really plays; snd_RateFit = the mode can't do it
pt_SndAhiFit41:
	SF	snd_RateFit
	BSR.S	pt_SndAhiOut41		; paula: limits of an old ahi mode don't count
	BEQ.S	.r
	MOVE.L	D2,-(A7)
	MOVEQ	#0,D2
	MOVE.W	D1,D2
	MOVE.L	snd_AhiMax,D0
	BEQ.S	.ok
	CMP.L	D0,D2
	BLS.S	.lo
	MOVE.L	D0,D2
	ST	snd_RateFit
.lo:	MOVE.L	snd_AhiMin,D0
	CMP.L	D0,D2
	BCC.S	.ok
	ST	snd_RateFit
	CMP.L	#32000,D0
	BHI.S	.ok
	MOVE.L	D0,D2
.ok:	MOVE.L	ahi_Real,D0		; ahi open: mix at the rate it plays,
	CMP.L	#8000,D0		; no resampling in the driver
	BCS.S	.w
	CMP.L	#32000,D0
	BHI.S	.w
	MOVE.L	D0,D2
.w:	MOVE.W	D2,D1
	MOVE.L	(A7)+,D2
.r:	RTS

; z=0: ahi has or takes the output
pt_SndAhiOut41:
	TST.B	ahi_Active
	BNE.S	.r
	TST.B	ahi_NoPaula
	BNE.S	.r
	TST.B	ahi_Want
.r:	RTS

; d0.l = mix per -> paula: never below 124 (dma)
pt_SndPerMin41:
	BSR.S	pt_SndAhiOut41
	BNE.S	.r
	CMP.L	#124,D0
	BCC.S	.r
	MOVEQ	#124,D0
.r:	RTS

; new ahi mode: rate it can't do -> AUTO
pt_SndAhiAdapt41:
	MOVEM.L	D0-D2/A0-A1,-(A7)
	JSR	pt_MixApplyRate
	TST.B	snd_RateFit
	BEQ.S	.r
	TST.B	mix_RateSel
	BEQ.S	.r
	CLR.B	mix_RateSel
	JSR	pt_MixApplyRate
.r:	MOVEM.L	(A7)+,D0-D2/A0-A1
	RTS

;--- rate text
; MIX RATE value of the running output, appended at a1
pt_SndRateStr41:
	MOVEM.L	D0/A0,-(A7)
	LEA	set_TxtNA,A0
	TST.B	agus_On
	BEQ.S	.nag
	LEA	snd_TxtCard(PC),A0
	TST.B	zzax_On
	BEQ.S	.cat
	LEA	snd_TxtZzax(PC),A0
	BRA.S	.cat
.nag:	TST.B	ahi_Active
	BEQ.S	.pa
	MOVE.L	ahi_Real,D0
	BNE.S	.num
	BRA.S	.pm
.pa:	BTST	#5,dat_ModeFlags	; 4ch on paula: nothing mixed
	BNE.S	.cat
.pm:	TST.B	mix_Enabled
	BEQ.S	.cat
	MOVEQ	#0,D0
	MOVE.W	mix_Rate,D0
.num:	TST.B	mix_RateSel
	BNE.S	.n1
	LEA	set_TxtAuto,A0
	JSR	pt_SetCat
.n1:	LEA	set_Num,A0
	JSR	pt_SetFmtNum
	LEA	set_Num,A0
	JSR	pt_SetCat
	LEA	set_TxtHz,A0
.cat:	JSR	pt_SetCat
	MOVEM.L	(A7)+,D0/A0
	RTS

; z=1: stereo has no effect on this output
pt_SndStereoOk41:
	TST.B	agus_On
	BNE.S	.r
	TST.B	ahi_Active
.r:	RTS

;--- arrows on MIX RATE with ahi: next rate the mode can do, ahi reopens
; d1 = +1/-1
pt_SndRateAhi41:
	TST.B	snd_RateHeld		; held arrow: ahi reopens once
	BNE.S	.hold
	ST	snd_RateHeld
	IFD	DEBUGAUTO
	ADDQ.W	#1,dbg_RateSteps
	ENDC
	MOVE.W	D1,-(A7)
	JSR	pt_SndPause
	MOVE.W	(A7)+,D1
	MOVEQ	#3,D2
.n:	MOVE.B	mix_RateSel,D0
	ADD.B	D1,D0
	AND.B	#3,D0
	MOVE.B	D0,mix_RateSel
	JSR	pt_MixApplyRate
	TST.B	mix_RateSel
	BEQ.S	.go
	TST.B	snd_RateFit
	BEQ.S	.go
	DBF	D2,.n
.go:	JSR	pt_SndAhiReopen
	MOVE.B	#3,snd_ResDefer
	JSR	pt_0641
	JSR	pt_SndWait
	JMP	pt_SndRefresh
.hold:	RTS

; from pt_AhiPoll: ahi asked for no half for seconds, the mode plays
; nothing at this rate: once again at 22 khz, then back to paula
pt_AhiStall41:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	CLR.W	ahi_Ticks
	JSR	pt_SndPause
	TST.W	ahi_Stalls
	BNE.S	.pa
	CMPI.B	#2,mix_RateSel
	BEQ.S	.pa
	ADDQ.W	#1,ahi_Stalls
	MOVE.B	#2,mix_RateSel
	JSR	pt_SndAhiReopen		; adapts the rate to the mode
	MOVE.B	#3,snd_ResDefer
	LEA	ahi_MsgSil22(PC),A0
	BRA.S	.m
.pa:	CLR.W	ahi_Stalls
	ST	snd_Started
	JSR	pt_MixStop
	MOVE.B	#1,snd_Target		; the switch resumes the song
	MOVE.B	#2,snd_Defer
	LEA	ahi_MsgSilP(PC),A0
.m:	JSR	pt_StatusLater41
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

ahi_MsgSil22:	DC.B	"AHI SILENT: TRYING 22 KHZ",0
ahi_MsgSilP:	DC.B	"AHI SILENT: BACK TO PAULA",0
snd_TxtCard:	DC.B	"CARD 192 KHZ",0
snd_MsgCard:	DC.B	"AMIGUS: NO MIXER, 192 KHZ",0
snd_TxtZzax:	DC.B	"CARD 48 KHZ",0
snd_MsgZzax:	DC.B	"ZZ9000AX: NO MIXER, 48 KHZ",0
snd_MsgStereoA:	DC.B	"STEREO: AHI/AMIGUS ONLY",0
snd_MsgStereoZ:	DC.B	"STEREO: AHI/ZZ9000AX ONLY",0
snd_MsgStereoB:	DC.B	"STEREO: AHI/AMIGUS/ZZ9000AX ONLY",0
ahi_MsgGone:	DC.B	"AHI MODE GONE: PREFS",0
	EVEN
snd_MsgStereo:	DC.L	snd_MsgStereoA,snd_MsgStereoZ,snd_MsgStereoB,snd_MsgStereoA	; pt_CardStr41
