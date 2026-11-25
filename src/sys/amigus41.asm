; amigus sound card: detection via amigus.library; output OUTPUT AMIGUS:
; no software mixing: each replayer tick the voice state of the mixer
; (trigger, period, volume, loop) goes to wavetable voices 0-7 and only
; the play positions are followed (81y switch, dyn envelope); 68000 ok.
; sdram slot n (512 kb): sample + copy of its loop (loop ends early), at
; +256 kb the sample backwards; slots 0-62 = samples 1-63; only changed
; samples are sent again (task)
; the zz9000ax output (zzax41.asm) shares the tables, the voice update, the
; levels, the positions and the volume of this file; its hooks are marked
; zz9000ax below, the card is driven from zzax41.asm
AGUS_TYPENAME	EQU	28		; struct AmiGUS: STRPTR type name
AGUS_TYPEID	EQU	32		; UWORD: zorro / mini
AGUS_WAVE	EQU	4		; APTR wavetable registers
AGUS_FLAG_WT	EQU	2
AGUS_OWNER	EQU	'PT41'
AW_INT		EQU	$00		; bit 8: sdram write fifo was full (latched)
AW_FFULL	EQU	$0100
AW_FIFORST	EQU	$18		; sdram write fifo reset (strobe)
AW_WADDR	EQU	$14		; sdram write address (long)
AW_WDATA	EQU	$10		; sdram data port (long, address counts up)
AW_BANK		EQU	$1E		; voice select
AW_CTRL		EQU	$20		; bit 15 start, bit 1 loop
AW_START	EQU	$22		; byte addresses (long: high, low)
AW_LOOP		EQU	$26
AW_END		EQU	$2A		; last word
AW_RATE		EQU	$2E		; $40000000 = one sample per 192 khz clock
AW_VOL		EQU	$32		; long: left, right (16 bit each)
AW_MASTER	EQU	$40		; long: left, right; 0 after power on
AGUS_SLOTSH	EQU	19		; sdram slot per sample: 512 kb
AGUS_REV	EQU	$40000		; backwards copy in the slot
AGUS_NS		EQU	63		; samples 1-63
AGUS_RATEA	EQU	$49E4C		; 3546895 * 2^30 / 192000 = $49E4C:$5F92
AGUS_RATEB	EQU	$5F92
AGUS_LEFT	EQU	$99		; voices on the left: 1 4 5 8 (as paula pairs)
	RSRESET
as_addr		RS.L	1		; sample table: amiga address
as_len		RS.L	1
as_sum		RS.L	1
as_ls		RS.L	1		; loop start (bytes) as uploaded
as_ll		RS.L	1		; loop length, 0 = none
as_ok		RS.B	1		; in sdram
as_early	RS.B	1		; loop ends before the sample end: copy behind
as_try		RS.B	1		; failed uploads of this data
as_pad		RS.B	1
as_SIZEOF	RS.B	0
	RSRESET
av_rate		RS.L	1		; voice state as written to the card
av_vol		RS.L	1
av_loop		RS.L	1
av_llen		RS.L	1
av_vkey		RS.L	1		; vol and setup av_vol was computed from (0 = none)
av_per		RS.W	1
av_on		RS.B	1
av_back		RS.B	1		; card voice plays the backwards copy
av_SIZEOF	RS.B	0
	RSRESET
ac_step		RS.L	1		; position step per tick, samples * 256
ac_per		RS.W	1		; period it is for (0 = none)
ac_pad		RS.W	1
ac_SIZEOF	RS.B	0
AGM_SMP		EQU	0			; agus_Mem: samples on the card
AGM_VOICE	EQU	AGM_SMP+AGUS_NS*as_SIZEOF	; card voice state
AGM_CHAN	EQU	AGM_VOICE+32*av_SIZEOF	; wide: channel structs
AGM_SHADOW	EQU	AGM_CHAN+32*n_SIZEOF	; wide: shadow registers
AGM_VOICES	EQU	AGM_SHADOW+32*aud_SIZEOF	; wide: voice state
AGM_TAB		EQU	AGM_VOICES+32*mv_SIZEOF	; wide: shadow pointer table
AGM_STEPS	EQU	AGM_TAB+32*4		; position step per voice
AGM_SIZE	EQU	AGM_STEPS+32*ac_SIZEOF

; library + first card on first need (output amigus); agus_Card = 0 if
; none (nothing reserved)
pt_AgusDetect:
	IFD	DEBUGAUTO
	TST.B	dbg_FakeAgus
	BEQ.S	.real
	MOVE.L	#dbg_FakeCard,agus_Card
	RTS
.real:
	ENDC
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	TST.B	agus_Tried
	BNE.S	.r
	ST	agus_Tried
	MOVEA.L	ABSEXECBASE.W,A6
	LEA	agus_LibName(PC),A1
	MOVEQ	#0,D0
	JSR	(-552,A6)		; OpenLibrary
	MOVE.L	D0,agus_Base
	BEQ.S	.r
	MOVEA.L	D0,A6
	SUBA.L	A0,A0
	JSR	(-30,A6)		; AmiGUS_FindCard(first)
	MOVE.L	D0,agus_Card
	BNE.S	.r
	BSR.S	pt_AgusClose		; library without a card
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

; exit: library closed
pt_AgusClose:
	BSR.W	pt_AgusOff
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	CLR.L	agus_Card
	MOVE.L	agus_Base,D0
	BEQ.S	.r
	CLR.L	agus_Base
	MOVEA.L	D0,A1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-414,A6)		; CloseLibrary
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

; a0 = card name for the hardware page ("AMIGUS MINI", "NONE")
pt_AgusName:
	LEA	agus_TxtNone(PC),A0
	MOVE.L	agus_Card,D0
	BEQ.S	.r
	LEA	agus_TxtZorro(PC),A0
	MOVEA.L	D0,A1
	CMPI.W	#$7001,AGUS_TYPEID(A1)
	BNE.S	.r
	LEA	agus_TxtMini(PC),A0
.r:	RTS

agus_LibName:	DC.B	"amigus.library",0
agus_TxtNone:	DC.B	"NONE",0
agus_TxtZorro:	DC.B	"AMIGUS",0
agus_TxtMini:	DC.B	"AMIGUS MINI",0
	EVEN

;--- output
; task: reserve the wavetable, master up, voices off, samples over
; d0 = 0 ok, -1 no card / in use
pt_AgusOn:
	MOVEM.L	D1-D7/A0-A6,-(A7)
	TST.B	agus_On
	BNE.W	.ok
	MOVE.L	agus_Card,D0
	BEQ.W	.no
	MOVEA.L	D0,A0
	MOVE.L	AGUS_WAVE(A0),agus_Wave
	BEQ.W	.no
	TST.L	agus_Mem		; tables (not in the bss: a500 memory)
	BNE.S	.hm
	MOVE.L	#AGM_SIZE,D0
	MOVE.L	#$10001,D1		; MEMF_PUBLIC|MEMF_CLEAR
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-198,A6)
	MOVE.L	D0,agus_Mem
	BEQ.W	.no
.hm:
	IFD	DEBUGAUTO
	TST.B	dbg_FakeAgus
	BNE.S	.fk
	ENDC
	MOVEA.L	agus_Base,A6
	MOVEA.L	agus_Card,A0		; allocmem trashed a0
	MOVEQ	#AGUS_FLAG_WT,D0
	MOVE.L	#AGUS_OWNER,D1
	JSR	(-36,A6)		; AmiGUS_ReserveCard
	TST.L	D0
	BNE.W	.no
.fk:	JSR	pt_SndAhiDrop		; ahi running: off, paula back first
	AGM	AGM_SMP,A0		; nothing on the card yet
	MOVE.W	#AGUS_NS*as_SIZEOF/4-1,D0
.cs:	CLR.L	(A0)+
	DBF	D0,.cs
	BSR.W	pt_AgusVoicesOff
	MOVEA.L	agus_Wave,A3
	CLR.W	AW_FIFORST(A3)		; write fifo from a clean state
	MOVE.W	#AW_FFULL,AW_INT(A3)	; bit 15 = 0: clear the flag
	IFD	DEBUGAUTO
	CLR.W	AW_INT(A3)
	ENDC
	SF	agus_UpFail
	MOVE.L	#$ffffffff,AW_MASTER(A3)
	BSR.W	pt_AgusSync
	ST	agus_On
.ok:	MOVEQ	#0,D0
	BRA.S	.r
.no:	MOVE.L	agus_Mem,D0		; tables back
	BEQ.S	.nf
	CLR.L	agus_Mem
	MOVEA.L	D0,A1
	MOVE.L	#AGM_SIZE,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-210,A6)
.nf:	MOVEQ	#-1,D0
.r:	MOVEM.L	(A7)+,D1-D7/A0-A6
	RTS

; voices off, master 0, reservation free (task or exit)
pt_AgusOff:
	TST.B	zzax_On			; zz9000ax: its own off
	BNE.W	pt_ZzaxOff
	TST.B	agus_On
	BEQ.S	.r
	TST.B	mix_Active		; mixer first: else a tick takes the paula way
	BEQ.S	.nm0
	JSR	pt_MixStop
.nm0:	SF	agus_On
	MOVEM.L	D0-D1/A0-A1/A3/A6,-(A7)
	JSR	pt_WideOff		; wide modules need the card
	BSR.W	pt_AgusVoicesOff
	MOVEA.L	agus_Wave,A3
	CLR.L	AW_MASTER(A3)
	IFD	DEBUGAUTO
	TST.B	dbg_FakeAgus
	BNE.S	.fk
	ENDC
	MOVEA.L	agus_Base,A6
	MOVEA.L	agus_Card,A0
	MOVEQ	#AGUS_FLAG_WT,D0
	MOVE.L	#AGUS_OWNER,D1
	JSR	(-42,A6)		; AmiGUS_FreeCard
.fk:	MOVE.L	agus_Mem,D0
	BEQ.S	.nm
	CLR.L	agus_Mem
	MOVEA.L	D0,A1
	MOVE.L	#AGM_SIZE,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-210,A6)
.nm:	MOVEM.L	(A7)+,D0-D1/A0-A1/A3/A6
.r:	RTS

; card voices 0-31 off and silent, state cleared (also pt_MixStop)
pt_AgusVoicesOff:
	MOVE.L	D0,-(A7)
	MOVEQ	#0,D0
	BSR.S	pt_AgusVoicesFrom41
	MOVE.L	(A7)+,D0
	RTS

; d0.w = first card voice: it and the ones after it off, state cleared
pt_AgusVoicesFrom41:
	TST.B	zzax_On			; zz9000ax: Reset / STOP records
	BNE.W	pt_ZzaxVoicesFrom41
	TST.L	agus_Mem
	BEQ.S	.r
	TST.L	agus_Wave
	BEQ.S	.r
	MOVEM.L	D0-D2/A0/A3,-(A7)
	MOVE.B	agus_Busy,D2		; tick keeps its hands off the bank
	ST	agus_Busy
	MOVEA.L	agus_Wave,A3
	MOVE.W	D0,D1			; d1 = first
	BRA.S	.n
.v:	MOVE.W	D0,AW_BANK(A3)
	CLR.W	AW_CTRL(A3)
	AGW	AW_CTRL
	CLR.L	AW_VOL(A3)
	AGW	AW_VOL
	ADDQ.W	#1,D0
.n:	CMP.W	#32,D0
	BCS.S	.v
	AGM	AGM_VOICE,A0
	MOVEQ	#32,D0
	SUB.W	D1,D0
	MULU	#av_SIZEOF,D0		; bytes of the voices that go
	MULU	#av_SIZEOF,D1
	ADDA.L	D1,A0
	BRA.S	.c1
.c:	CLR.B	(A0)+
.c1:	SUBQ.L	#1,D0
	BPL.S	.c
	MOVE.B	D2,agus_Busy
	MOVEM.L	(A7)+,D0-D2/A0/A3
.r:	RTS

; wide stop: all 32 voices inactive, the tick keys them off
pt_AgusWideSilence:
	MOVE.L	D1,-(A7)
	MOVEQ	#0,D1
	BSR.S	pt_AgusSilFrom41
	MOVE.L	(A7)+,D1
	RTS

; d1.w = first voice: it and the ones after it inactive, the rest plays
pt_AgusSilFrom41:
	TST.B	wide_On
	BEQ.W	.r
	TST.L	agus_Mem
	BEQ.W	.r
	MOVEM.L	D0-D1/A0-A2/A6,-(A7)
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-120,A6)		; Disable: the tick runs on its own
	AGM	AGM_VOICES,A0
	AGM	AGM_SHADOW,A1
	AGM	AGM_CHAN,A2
	MOVE.W	D1,D0
	MULU	#mv_SIZEOF,D0
	ADDA.L	D0,A0
	MOVE.W	D1,D0
	MULU	#aud_SIZEOF,D0
	ADDA.L	D0,A1
	MOVE.W	D1,D0
	MULU	#n_SIZEOF,D0
	ADDA.L	D0,A2
	MOVEQ	#31,D0
	SUB.W	D1,D0
	BMI.S	.x
.l:	SF	(mv_active,A0)
	CLR.W	(mv_vol,A0)
	CLR.W	(aud_VOL,A1)
	CLR.W	(aud_PER,A1)		; no pending trigger
	CLR.B	(n_volume,A2)
	SF	(n_pt4_dmawait,A2)
	CLR.B	(n_pt4_chunked,A2)
	CLR.L	(n_pt4_chunkptr,A2)
	LEA	mv_SIZEOF(A0),A0
	LEA	aud_SIZEOF(A1),A1
	LEA	n_SIZEOF(A2),A2
	DBF	D0,.l
.x:	JSR	(-126,A6)		; Enable
	MOVEM.L	(A7)+,D0-D1/A0-A2/A6
.r:	RTS

; task: samples to the card that are new or changed (address, length,
; loop, sparse sum); a voice plays a sample only once it is there
pt_AgusSync:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.B	zzax_On			; zz9000ax: heartbeat, lost session, then the same pass
	BEQ.S	.ag
	BSR.W	pt_ZzaxPoll
	TST.B	zx_Ready
	BEQ.W	.r
.ag:
	MOVE.L	dat_ModulePtr,D0
	BEQ.W	.r
	MOVEA.L	D0,A2
	LEA	42(A2),A2		; length word of sample 1
	LEA	dat_RpSampleStarts,A1
	AGM	AGM_SMP,A4
	MOVEA.L	agus_Wave,A3
	MOVEQ	#0,D7			; sample
.s:	MOVE.L	(A1)+,D4		; address
	MOVEQ	#0,D5
	MOVE.W	(A2),D5
	ADD.L	D5,D5			; length
	CMP.L	#AGUS_REV-4,D5
	BLS.S	.l
	MOVE.L	#AGUS_REV-4,D5
.l:	TST.L	D4
	BEQ.S	.none
	CMP.L	#2,D5
	BHI.S	.got
.none:	SF	as_ok(A4)
	BRA.W	.nx
.got:	MOVEQ	#0,D0			; loop from the header: a5 = start, a6 = len
	MOVE.W	4(A2),D0
	ADD.L	D0,D0
	MOVEQ	#0,D1
	MOVE.W	6(A2),D1
	ADD.L	D1,D1
	CMP.L	#2,D1
	BHI.S	.lp
	MOVEQ	#0,D0
	MOVEQ	#0,D1
.lp:	MOVEA.L	D0,A5
	MOVEA.L	D1,A6
	MOVEA.L	D4,A0			; sum: every 16th long, the last one, loop
	MOVE.L	D5,D2
	LSR.L	#6,D2
	MOVE.L	D0,D3
	SWAP	D3
	ADD.L	D1,D3
	BRA.S	.se
.sl:	ADD.L	(A0),D3
	LEA	64(A0),A0
.se:	DBF	D2,.sl
	MOVEA.L	D4,A0
	ADDA.L	D5,A0
	ADD.L	-4(A0),D3
	TST.B	as_ok(A4)
	BNE.S	.ck
	TST.B	as_try(A4)		; failed before: same data again, 3 times
	BEQ.S	.up
	CMP.L	as_addr(A4),D4
	BNE.S	.nt
	CMP.L	as_len(A4),D5
	BNE.S	.nt
	CMP.L	as_sum(A4),D3
	BNE.S	.nt
	CMP.B	#3,as_try(A4)
	BCC.W	.nx
	BRA.S	.up
.nt:	CLR.B	as_try(A4)
	BRA.S	.up
.ck:	CMP.L	as_addr(A4),D4
	BNE.S	.up
	CMP.L	as_len(A4),D5
	BNE.S	.up
	CMP.L	as_sum(A4),D3
	BEQ.W	.nx
.up:	SF	as_ok(A4)
	TST.B	zzax_On			; zz9000ax: the sample goes over the library
	BEQ.S	.agup
	BSR.W	pt_ZzaxUpload
	BRA.W	.nx
.agup:	ST	agus_Busy		; no voice writes between address and data
	MOVE.W	#AW_FFULL,AW_INT(A3)	; clear the fifo full flag
	IFD	DEBUGAUTO
	CLR.W	AW_INT(A3)
	ENDC
	MOVE.L	D3,D6			; d6 = sum
	MOVE.L	D7,D0			; forward: sample, loop copy if early
	MOVEQ	#AGUS_SLOTSH,D1
	LSL.L	D1,D0
	MOVE.L	D0,AW_WADDR(A3)
	MOVE.L	D0,-(A7)
	MOVEQ	#0,D3			; stream state: d3 bytes in d2
	MOVEA.L	D4,A0
	MOVE.L	D5,D1
	BSR.W	pt_AgusPut
	SF	as_early(A4)
	MOVE.L	A6,D1			; loop end < sample end?
	BEQ.S	.ne
	ADD.L	A5,D1
	CMP.L	D5,D1
	BCC.S	.ne
	ST	as_early(A4)
	MOVEA.L	D4,A0
	ADDA.L	A5,A0
	MOVE.L	A6,D1
	BSR.W	pt_AgusPut
.ne:	BSR.W	pt_AgusFlush
	MOVE.L	(A7)+,D0		; backwards: pad, smp end .. start, pad
	ADD.L	#AGUS_REV,D0
	MOVE.L	D0,AW_WADDR(A3)
	MOVEQ	#0,D3
	MOVEQ	#0,D0
	BSR.W	pt_AgusByte
	MOVEA.L	D4,A0
	ADDA.L	D5,A0
	MOVE.L	D5,D1
	SUBQ.L	#1,D1
.rv:	MOVE.B	-(A0),D0
	BSR.W	pt_AgusByte
	SUBQ.L	#1,D1
	BPL.S	.rv
	MOVEQ	#0,D0
	BSR.W	pt_AgusByte
	BSR.W	pt_AgusFlush
	IFD	DEBUGAUTO
	TST.B	dbg_AgFail
	BEQ.S	.nf
	SUBQ.B	#1,dbg_AgFail
	OR.W	#AW_FFULL,AW_INT(A3)
.nf:
	ENDC
	MOVE.W	AW_INT(A3),D0		; bit 8: data lost on the way
	MOVE.L	D4,as_addr(A4)
	MOVE.L	D5,as_len(A4)
	MOVE.L	D6,as_sum(A4)
	MOVE.L	A5,as_ls(A4)
	MOVE.L	A6,as_ll(A4)
	SF	agus_Busy
	BTST	#8,D0
	BNE.S	.bad
	CLR.B	as_try(A4)
	ST	as_ok(A4)
	BRA.S	.nx
.bad:	CLR.W	AW_FIFORST(A3)		; again with the next pass, then give up
	ADDQ.B	#1,as_try(A4)
	CMP.B	#3,as_try(A4)
	BNE.S	.nx
	ST	agus_UpFail
	MOVEM.L	D0-D1/A0-A1,-(A7)
	LEA	agus_MsgUp(PC),A0
	JSR	pt_StatusLater41
	MOVEM.L	(A7)+,D0-D1/A0-A1
.nx:	LEA	s_SIZEOF(A2),A2
	LEA	as_SIZEOF(A4),A4
	ADDQ.W	#1,D7
	CMP.W	#31,D7
	BEQ.S	.tb
	CMP.W	#AGUS_NS,D7
	BNE.W	.s
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS
.tb:	MOVE.L	smx_Mem,D0		; samples 32-63: headers + pointers of the table
	BNE.S	.th
	MOVEQ	#AGUS_NS-32,D0		; no table: none on the card
.tc:	SF	as_ok(A4)
	LEA	as_SIZEOF(A4),A4
	DBF	D0,.tc
	BRA.S	.r
.th:	MOVEA.L	D0,A2
	LEA	SMX_PTR(A2),A1
	LEA	SMX_HDR+22(A2),A2
	BRA.W	.s

; sdram stream (a3 = wave regs): d2 = pending bytes, d3 = their count
; a0 = src (even), d1 = bytes (even)
pt_AgusPut:
	TST.L	D1
	BEQ.S	.r
	TST.W	D3
	BEQ.S	.l
.w:	MOVE.B	(A0)+,D0		; pending bytes: byte wise to a long
	BSR.S	pt_AgusByte
	SUBQ.L	#1,D1
	BEQ.S	.r
	TST.W	D3
	BNE.S	.w
.l:	CMP.L	#4,D1
	BCS.S	.w
	MOVE.L	(A0)+,AW_WDATA(A3)
	TST.W	AW_INT(A3)		; pace: one bus read per long
	SUBQ.L	#4,D1
	BNE.S	.l
.r:	RTS
; d0.b -> stream
pt_AgusByte:
	LSL.L	#8,D2
	MOVE.B	D0,D2
	ADDQ.W	#1,D3
	CMP.W	#4,D3
	BNE.S	.r
	MOVE.L	D2,AW_WDATA(A3)
	TST.W	AW_INT(A3)
	MOVEQ	#0,D3
.r:	RTS
; last long, zero padded
pt_AgusFlush:
	TST.W	D3
	BEQ.S	.r
	MOVEQ	#0,D0
	BSR.S	pt_AgusByte
	BRA.S	pt_AgusFlush
.r:	RTS

; d0 = amiga addr -> a0 = sample entry, d1 = addr - smp start, z=0 found
pt_AgusFind:
	MOVE.L	D2,-(A7)
	AGM	AGM_SMP,A0
	MOVEQ	#AGUS_NS-1,D2
	TST.L	smx_Mem
	BNE.S	.s
	MOVEQ	#30,D2
.s:	TST.B	as_ok(A0)
	BEQ.S	.nx
	MOVE.L	D0,D1
	SUB.L	as_addr(A0),D1
	BCS.S	.nx
	CMP.L	as_len(A0),D1
	BCS.S	.y
.nx:	LEA	as_SIZEOF(A0),A0
	DBF	D2,.s
	MOVE.L	(A7)+,D2
	ORI	#4,CCR
	RTS
.y:	MOVE.L	(A7)+,D2
	ANDI	#$fb,CCR
	RTS

; a0 = sample entry -> d1 = its sdram slot
pt_AgusSlot:
	MOVE.L	A0,D1
	SUB.L	agus_Mem,D1		; AGM_SMP = 0
	DIVU	#as_SIZEOF,D1
	AND.L	#$ffff,D1
	SWAP	D1
	LSL.L	#AGUS_SLOTSH-16,D1
	RTS

; replayer irq, first thing: how long ago did the tick timer run out? A
; card run that took more than a tick starts the next one at once; then
; the card runs of this and the next tick are skipped (voices lag a tick
; or two, the main loop gets its time) instead of the system never
; leaving the irq
pt_AgusStamp:
	TST.B	zzax_On			; zz9000ax: the card clock decides if the tick runs
	BNE.W	pt_ZzaxGate
	MOVEM.L	D0-D2/A0,-(A7)
	MOVEA.L	dat_CIABaseAddr,A0
	MOVE.L	A0,D0
	BEQ.S	.x
	LEA	$400(A0),A0		; timer a
	TST.L	dat_CIATimerSelect
	BEQ.S	.a
	LEA	$200(A0),A0		; timer b
.a:	MOVEQ	#0,D0
	MOVE.B	$100(A0),D0
	LSL.W	#8,D0
	MOVE.B	(A0),D0			; d0 = e clocks left of the tick
	IFD	DEBUGAUTO
	MOVE.L	$DFF004,D1
	LSR.L	#8,D1
	AND.W	#$1ff,D1
	MOVE.W	D1,dbg_AgTime+10	; irq entry line
	ENDC
	MULU	#40,D0			; 5 * 8 * left
	MOVE.L	agus_Spt5,D1		; 5 * tick (as the run before took it)
	MOVE.L	D1,D2
	LSL.L	#3,D1
	SUB.L	D2,D1			; 5 * 7 * tick
	CMP.L	D1,D0
	BCC.S	.x
	MOVE.B	#2,agus_Late
	IFD	DEBUGAUTO
	ADDQ.W	#1,dbg_AgLate
	ENDC
.x:	MOVEM.L	(A7)+,D0-D2/A0
	RTS

AGSTAMP	MACRO				; test: raster line at stage \1
	IFD	DEBUGAUTO
	MOVE.L	$DFF004,D0
	LSR.L	#8,D0
	AND.W	#$1ff,D0
	MOVE.W	D0,dbg_AgTime+\1*2
	IFEQ	\1-4
	BSR.W	dbg_AgDone
	ENDC
	ENDC
	ENDM

; all position steps are divided again
pt_AgusStepsOff:
	AGM	AGM_STEPS,A0
	MOVEQ	#31,D0
.l:	CLR.W	ac_per(A0)
	LEA	ac_SIZEOF(A0),A0
	DBF	D0,.l
	RTS

;--- tick (replayer irq, all cpus): voice state -> card, positions on
; 8 voices, or 32 for a wide module (own channel structs and voices)
pt_AgusRun:
	TST.B	zx_Hold			; zz9000ax: this tick waited for the card
	BEQ.S	.nh
	RTS
.nh:
	TST.B	agus_Late		; the run before overran the tick: skip
	BEQ.S	.go
	SUBQ.B	#1,agus_Late
	IFD	DEBUGAUTO
	ADDQ.W	#1,dbg_AgSkip
	ENDC
	RTS
.go:	MOVEM.L	D0-D7/A0-A6,-(A7)
	AGSTAMP	0
	BSR.W	pt_AgusSpt		; d0 = 5 * timer, for samples per tick
	CMP.L	agus_Spt5,D0		; tempo changed: steps are new
	BEQ.S	.stp
	MOVE.L	D0,agus_Spt5
	BSR.W	pt_AgusStepsOff
.stp:
	MOVE.L	#dat_Channel1,agus_ChBase
	MOVE.L	#mix_Voices,agus_VoBase
	MOVE.L	#mix_Shadow,D1
	MOVEQ	#8,D0
	TST.B	wide_On
	BEQ.S	.n8
	MOVE.L	agus_Mem,D1
	ADD.L	#AGM_CHAN,D1
	MOVE.L	D1,agus_ChBase
	ADD.L	#AGM_VOICES-AGM_CHAN,D1
	MOVE.L	D1,agus_VoBase
	ADD.L	#AGM_SHADOW-AGM_VOICES,D1
	MOVEQ	#32,D0
	MOVE.W	wide_Ch,D2		; only the voices of the module
	BEQ.S	.n8
	CMP.W	D0,D2
	BHI.S	.n8
	MOVE.W	D2,D0
.n8:	MOVE.W	D0,agus_NV
	MOVEA.L	agus_ChBase,A6
	MOVEA.L	agus_VoBase,A5
	MOVEA.L	D1,A4
	MOVE.W	agus_NV,D7
	SUBQ.W	#1,D7
.u:	TST.B	(mv_active,A5)		; idle voice without a trigger: nothing to take
	BNE.S	.do
	TST.B	(n_pt4_dmawait,A6)
	BNE.S	.do
	CMPI.W	#1,(aud_PER,A4)
	BNE.S	.idle
.do:	MOVEM.L	D7/A4-A6,-(A7)
	JSR	pt_MixUpdateVoice	; trigger, loop, volume, period
	TST.B	(n_pt4_chunked,A6)	; dyn: loop of the chunk list
	BEQ.S	.nd
	BSR.W	pt_AgusLoop
	MOVE.L	D4,(mv_loopstart,A5)
	MOVE.L	D5,(mv_looplen,A5)
.nd:	MOVEM.L	(A7)+,D7/A4-A6
.idle:	LEA	n_SIZEOF(A6),A6
	LEA	mv_SIZEOF(A5),A5
	LEA	aud_SIZEOF(A4),A4
	DBF	D7,.u
	AGSTAMP	1
	BSR.W	pt_AgusTick
	AGSTAMP	2
	BSR.W	pt_AgusLevels
	JSR	pt_WscTick41		; panel bars with the tick
	AGSTAMP	3
	MOVEA.L	agus_VoBase,A1		; positions one tick on
	MOVEA.L	agus_ChBase,A6
	AGM	AGM_STEPS,A4
	MOVE.W	agus_NV,D7
	SUBQ.W	#1,D7
.p:	BSR.W	pt_AgusAdvance
	LEA	ac_SIZEOF(A4),A4
	LEA	mv_SIZEOF(A1),A1
	LEA	n_SIZEOF(A6),A6
	DBF	D7,.p
	TST.B	wide_On			; wide: vu of the tracks pt shows (note cell, volume)
	BEQ.S	.x
	JSR	pt_WideVuSet41		; a0 = first channel, a1 = vu slot 1, d7 = count - 1
.vu:	MOVE.L	(A0),(A1)
	MOVE.B	(n_volume,A0),(n_volume,A1)
	LEA	n_SIZEOF(A0),A0
	LEA	n_SIZEOF(A1),A1
	DBF	D7,.vu
.x:	AGSTAMP	4
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; per tick: levels for the stage and the panel box (trk_Lev 0..64): a
; card start sets the card vol, then it falls, never above the vol, a
; held voice keeps half of it
LEV_FALL	EQU	2
pt_AgusLevels:
	LEA	agus_Hit,A0
	LEA	trk_Lev,A1
	MOVEA.L	agus_VoBase,A5
	MOVEQ	#0,D6			; voice
.l:	MOVEQ	#0,D3			; vol the card plays
	TST.B	(mv_active,A5)
	BEQ.S	.v
	MOVE.W	(mv_vol,A5),D3
	CMP.W	#64,D3
	BLS.S	.v
	MOVEQ	#64,D3
.v:	MOVEQ	#0,D2
	MOVE.B	(A1,D6.W),D2
	TST.B	(A0,D6.W)
	BEQ.S	.d
	SF	(A0,D6.W)
	MOVE.W	D3,D2
	IFD	DEBUGAUTO
	MOVE.W	D6,D0
	ADD.W	D0,D0
	LEA	dbg_LvHits,A2
	ADDQ.W	#1,(A2,D0.W)
	ENDC
	BRA.S	.s
.d:	SUBQ.W	#LEV_FALL,D2
	BPL.S	.c
	MOVEQ	#0,D2
.c:	CMP.W	D3,D2
	BLS.S	.h
	MOVE.W	D3,D2
.h:	MOVE.W	D3,D0
	LSR.W	#1,D0
	CMP.W	D0,D2
	BHS.S	.s
	MOVE.W	D0,D2
.s:	MOVE.B	D2,(A1,D6.W)
	LEA	mv_SIZEOF(A5),A5
	ADDQ.W	#1,D6
	CMP.W	agus_NV,D6
	BLO.S	.l
	RTS

; d0 = 5 * tick in e clocks (paula clock = 5 e clocks, pal and ntsc)
pt_AgusSpt:
	MOVE.L	#14188*5,D0		; vblank: 50 hz
	BTST	#0,dat_ModeFlags
	BEQ.S	.r
	MOVE.L	D1,-(A7)
	MOVE.L	dat_CIATimingBase,D0
	MOVEQ	#0,D1
	MOVE.W	dat_CurrentTempo,D1
	BNE.S	.b
	MOVEQ	#125,D1
.b:	JSR	pt_MixDiv32		; timer value
	MULU	#5,D0
	MOVE.L	(A7)+,D1
.r:	RTS

; a1 = voice, a4 = its step cache, a6 = channel: position one tick on,
; loop/end as the mixer; the step is divided again when the period or the
; tick changed only
pt_AgusAdvance:
	TST.B	(mv_active,A1)
	BEQ.S	.r
	MOVEQ	#0,D1
	MOVE.W	(mv_period,A1),D1
	CMP.W	#2,D1
	BCS.S	.r
	CMP.W	ac_per(A4),D1
	BEQ.S	.have
	MOVE.W	D1,ac_per(A4)
	MOVE.L	agus_Spt5,D0		; samples * 256 = 5 * timer * 256 / period
	LSL.L	#8,D0
	MOVE.L	D0,D2			; 32 / 16 bit division in two divu
	CLR.W	D0
	SWAP	D0
	DIVU	D1,D0			; d0 = rest : high quotient
	SWAP	D2
	MOVE.W	D0,D2			; d2 = low word of the dividend : high quotient
	SWAP	D2
	MOVE.W	D2,D0			; d0 = rest : low word of the dividend
	DIVU	D1,D0
	MOVE.W	D0,D2			; d2 = quotient
	MOVE.L	D2,(ac_step,A4)
.have:	MOVE.L	(ac_step,A4),D0
	MOVE.L	D0,D1
	LSL.W	#8,D1			; frac
	LSR.L	#8,D0			; int
	TST.B	(mv_back,A1)
	BNE.S	.bk
	ADD.W	D1,(mv_frac,A1)
	MOVE.L	(mv_pos,A1),D2
	ADDX.L	D0,D2
	MOVE.L	D2,(mv_pos,A1)
	BRA.S	.w
.bk:	SUB.W	D1,(mv_frac,A1)
	MOVE.L	(mv_pos,A1),D2
	SUBX.L	D0,D2
	MOVE.L	D2,(mv_pos,A1)
.w:	MOVEM.L	D7/A1/A4/A6,-(A7)
	JSR	pt_MixVoiceWrap		; loop start/end, stop
	MOVEM.L	(A7)+,D7/A1/A4/A6
.r:	RTS

; voice state -> card voices 0-7
pt_AgusTick:
	TST.B	agus_On
	BEQ.W	.x
	TST.B	zzax_On			; zz9000ax: records instead of registers
	BNE.W	pt_ZzaxTick
	TST.B	agus_Busy		; task writes sdram: voices next tick
	BNE.W	.x
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVEA.L	agus_Wave,A3
	MOVEA.L	agus_VoBase,A5
	AGM	AGM_VOICE,A4
	MOVEA.L	agus_ChBase,A6
	MOVEQ	#0,D7			; voice
.v:	MOVE.W	D7,AW_BANK(A3)
	MOVE.B	(mv_active,A5),D0
	BNE.S	.act
	TST.B	av_on(A4)
	BEQ.W	.nx
	CLR.W	AW_CTRL(A3)		; ended or stopped
	AGW	AW_CTRL
	CLR.L	AW_VOL(A3)		; and silent, should the card go on
	AGW	AW_VOL
	CLR.L	av_vol(A4)
	SF	av_on(A4)
	BRA.W	.nx
.act:	CMP.B	#$ff,D0			; new note (mixer: ST)
	BEQ.S	.new
	TST.B	av_on(A4)
	BEQ.W	.nx
	MOVE.B	(mv_back,A5),D0		; 81y direction changed: on from here
	CMP.B	av_back(A4),D0
	BNE.S	.start
	BSR.W	pt_AgusLoopChk
	BRA.S	.rv
.new:	MOVE.B	#1,(mv_active,A5)
	LEA	agus_Hit,A0		; level: started on the card
	ST	(A0,D7.W)
.start:	BSR.W	pt_AgusStart
.rv:	TST.B	av_on(A4)
	BEQ.S	.nx
	BSR.W	pt_AgusRate
	BSR.W	pt_AgusVol
.nx:	LEA	mv_SIZEOF(A5),A5
	LEA	av_SIZEOF(A4),A4
	LEA	n_SIZEOF(A6),A6
	ADDQ.W	#1,D7
	CMP.W	agus_NV,D7
	BNE.W	.v
	MOVEM.L	(A7)+,D0-D7/A0-A6
.x:	RTS

; (re)start card voice d7 at the play position: forward or backwards copy
pt_AgusStart:
	CLR.W	AW_CTRL(A3)
	AGW	AW_CTRL
	SF	av_on(A4)
	BSR.W	pt_AgusLoop		; d4 = loop start, d5 = loop len (dyn: list)
	MOVE.L	D4,av_loop(A4)
	MOVE.L	D5,av_llen(A4)
	MOVE.L	(mv_pos,A5),D0
	BSR.W	pt_AgusFind
	BEQ.W	.r			; sample not on the card (yet)
	MOVE.L	D1,D6			; d6 = offset in the sample
	BSR.W	pt_AgusSlot		; d1 = slot
	MOVE.B	(mv_back,A5),av_back(A4)
	BNE.S	.back
	; forward: start, end/loop (copy behind the sample: early loop end)
	MOVEA.L	A0,A2			; a2 = entry of the voice's sample
	TST.L	D5
	BEQ.S	.os
	BSR.W	pt_AgusLoopRegs		; d4/d5 -> d0 loop reg, d2 end reg, a0 entry
	BEQ.S	.os
	MOVE.L	D0,AW_LOOP(A3)
	AGW	AW_LOOP
	MOVE.W	#$8002,D3
	MOVE.L	D1,D0			; start in the sample
	ADD.L	D6,D0
	CMPA.L	A0,A2			; own early loop and past the first pass:
	BNE.S	.st			; go on in the copy
	TST.B	as_early(A2)
	BEQ.S	.st
	TST.L	as_ls(A2)
	BNE.S	.st
	MOVE.L	(mv_end,A5),D4
	SUB.L	as_addr(A2),D4
	CMP.L	as_len(A2),D4
	BCC.S	.st
	SUB.L	as_ls(A2),D6
	BCS.S	.st
	MOVE.L	D1,D0
	ADD.L	as_len(A2),D0
	ADD.L	D6,D0
	BRA.S	.st
.os:	MOVE.L	D1,D0			; one shot: to the sample end
	ADD.L	D6,D0
	MOVE.L	D1,D2
	ADD.L	as_len(A2),D2
	SUBQ.L	#2,D2
	MOVE.W	#$8000,D3
.st:	MOVE.L	D0,AW_START(A3)
	AGW	AW_START
	MOVE.L	D2,AW_END(A3)
	AGW	AW_END
	BRA.W	.go
.back:	; backwards copy: rev(o) = slot + REV + len - o
	ADD.L	#AGUS_REV,D1
	MOVE.L	as_len(A0),D2
	MOVE.L	D2,D0
	SUB.L	D6,D0
	ADD.L	D1,D0
	MOVE.L	D0,AW_START(A3)
	AGW	AW_START
	MOVE.W	#$8000,D3
	TST.L	D5
	BEQ.S	.bos
	MOVE.L	D4,D0			; loop: rev(loop end) .. rev(loop start)-2
	SUB.L	as_addr(A0),D0
	BCS.S	.bos
	ADD.L	D5,D0
	CMP.L	D2,D0
	BHI.S	.bos
	NEG.L	D0
	ADD.L	D2,D0
	ADD.L	D1,D0
	MOVE.L	D0,AW_LOOP(A3)
	AGW	AW_LOOP
	ADD.L	D5,D0
	SUBQ.L	#2,D0
	MOVE.L	D0,AW_END(A3)
	AGW	AW_END
	MOVE.W	#$8002,D3
	BRA.S	.go
.bos:	MOVE.L	D4,D0			; no loop: down to the phase start
	SUB.L	as_addr(A0),D0
	BCC.S	.bp
	MOVEQ	#0,D0
.bp:	NEG.L	D0
	ADD.L	D2,D0
	ADD.L	D1,D0
	MOVE.L	D0,AW_END(A3)
	AGW	AW_END
.go:	CLR.W	av_per(A4)
	MOVE.L	#-1,av_vol(A4)
	CLR.L	av_vkey(A4)
	CLR.L	av_rate(A4)
	MOVE.W	D3,-(A7)		; control word (rate/vol use d0-d3)
	BSR.W	pt_AgusRate
	BSR.W	pt_AgusVol
	TST.W	av_per(A4)		; no rate (period < 5): stays off
	BNE.S	.on
	ADDQ.L	#2,A7
	RTS
.on:	MOVE.W	(A7)+,AW_CTRL(A3)
	AGW	AW_CTRL
	ST	av_on(A4)
.r:	RTS

; d4 = loop start, d5 = loop len (bytes, 0 none) of voice a5 / channel a6;
; dyn samples: loop from the chunk list
pt_AgusLoop:
	MOVE.L	(mv_loopstart,A5),D4
	MOVE.L	(mv_looplen,A5),D5
	TST.B	(n_pt4_chunked,A6)
	BEQ.S	.r
	MOVEM.L	D0-D2/A0,-(A7)
	MOVE.L	(n_pt4_chunklist,A6),D0
	BEQ.S	.x
	MOVEA.L	D0,A0
	MOVEQ	#0,D5			; end of list: end, negative: loop back
.n:	MOVE.L	(A0)+,D0
	BGT.S	.c
	BEQ.S	.x
	ADDA.L	D0,A0
	MOVE.L	(A0),D4			; loop chunk .. end of the last chunk
	MOVE.L	D2,D5
	SUB.L	D4,D5
	BRA.S	.x
.c:	MOVEQ	#0,D1
	MOVE.W	(A0),D1
	ADD.L	D1,D1
	ADD.L	D0,D1
	MOVE.L	D1,D2			; end of this chunk
	ADDQ.L	#4,A0
	BRA.S	.n
.x:	MOVEM.L	(A7)+,D0-D2/A0
.r:	RTS

; d4/d5 loop -> d0 loop reg, d2 end reg, a0 entry of the loop's sample;
; own early loop: copy behind the sample; z=1 loop not on the card
pt_AgusLoopRegs:
	MOVE.L	D1,-(A7)
	MOVE.L	D4,D0
	BSR.W	pt_AgusFind
	BEQ.S	.no
	MOVE.L	D1,D0			; offset of the loop start
	BSR.W	pt_AgusSlot
	TST.B	as_early(A0)
	BEQ.S	.d
	CMP.L	as_ls(A0),D0
	BNE.S	.d
	CMP.L	as_ll(A0),D5
	BNE.S	.d
	TST.L	as_ls(A0)		; loop from 0 only: else the first pass ends at the loop end
	BNE.S	.d
	MOVE.L	as_len(A0),D0		; copy: slot + len
	ADD.L	D1,D0
	BRA.S	.e
.d:	ADD.L	D1,D0
.e:	MOVE.L	D0,D2
	ADD.L	D5,D2
	SUBQ.L	#2,D2
	MOVE.L	(A7)+,D1
	ANDI	#$fb,CCR
	RTS
.no:	MOVE.L	(A7)+,D1
	ORI	#4,CCR
	RTS

; running forward voice: new loop (sample w/o note) -> loop/end regs
pt_AgusLoopChk:
	TST.B	av_back(A4)
	BNE.S	.r
	BSR.W	pt_AgusLoop
	CMP.L	av_loop(A4),D4
	BNE.S	.ch
	CMP.L	av_llen(A4),D5
	BEQ.S	.r
.ch:	MOVE.L	D4,av_loop(A4)
	MOVE.L	D5,av_llen(A4)
	TST.L	D5
	BEQ.S	.r
	BSR.W	pt_AgusLoopRegs
	BEQ.S	.r
	MOVE.L	D0,AW_LOOP(A3)
	AGW	AW_LOOP
	MOVE.L	D2,AW_END(A3)
	AGW	AW_END
.r:	RTS

; rate from the period, only when it changed (2 x divu, all cpus)
pt_AgusRate:
	MOVEQ	#0,D2
	MOVE.W	(mv_period,A5),D2
	CMP.W	#5,D2
	BCS.S	.r
	CMP.W	av_per(A4),D2
	BEQ.S	.r
	MOVE.W	D2,av_per(A4)
	MOVE.L	#AGUS_RATEA,D0
	DIVU	D2,D0			; rest : high word of the rate
	MOVE.W	D0,D1
	MOVE.W	#AGUS_RATEB,D0		; rest : low part of the constant
	DIVU	D2,D0
	SWAP	D1
	MOVE.W	D0,D1
	MOVE.L	D1,D0			; high << 16 | low
	CMP.L	#$3fffffff,D0
	BLS.S	.s
	MOVE.L	#$3fffffff,D0
.s:	CMP.L	av_rate(A4),D0
	BEQ.S	.r
	MOVE.L	D0,av_rate(A4)
	MOVE.L	D0,AW_RATE(A3)
	AGW	AW_RATE
.r:	RTS

; volume 0..64 -> 16 bit (64 = $4000 as one paula channel), setup VOLUME,
; paula sides, STEREO width; dyn: chunk volume at the play position
pt_AgusVol:
	TST.B	(n_pt4_chunked,A6)
	BEQ.S	.key
	CLR.L	(av_vkey,A4)
	MOVEQ	#0,D0
	MOVE.W	(mv_vol,A5),D0
	BSR.W	pt_AgusDynVol
	BRA.S	.calc
.key:	MOVEQ	#0,D0			; same vol and setup as the last time: nothing to do
	MOVE.W	(mv_vol,A5),D0
	SWAP	D0
	MOVEQ	#0,D1
	MOVE.B	snd_VolDown,D1
	LSL.W	#8,D1
	MOVE.B	snd_StereoDown,D1
	OR.W	D1,D0
	BSET	#31,D0
	CMP.L	(av_vkey,A4),D0
	BEQ.S	.vr
	MOVE.L	D0,(av_vkey,A4)
	MOVEQ	#0,D0
	MOVE.W	(mv_vol,A5),D0
.calc:	LSL.L	#8,D0
	MOVEQ	#10,D1
	SUB.B	snd_VolDown,D1
	MULU	D1,D0
	DIVU	#10,D0
	AND.L	#$ffff,D0
	MOVEQ	#0,D1
	MOVE.B	snd_StereoDown,D1	; 0 hard .. 4 mono: other side d1/8
	MOVE.L	D0,D2
	MULU	D1,D2
	LSR.L	#3,D2			; other side
	MOVE.L	D0,D3
	SUB.L	D2,D3			; own side
	MOVE.W	D7,D1			; left: tracks 1 4 5 8 9 ... (n & 3 = 0 or 3)
	AND.W	#3,D1
	BEQ.S	.vl
	CMP.W	#3,D1
	BEQ.S	.vl
	EXG	D2,D3
.vl:	SWAP	D3			; d3 = left << 16 | right
	MOVE.W	D2,D3
	CMP.L	av_vol(A4),D3
	BEQ.S	.vr
	MOVE.L	D3,av_vol(A4)
	TST.B	zzax_On			; zz9000ax: SET record, same value
	BNE.W	pt_ZzaxVolOut
	MOVE.L	D3,AW_VOL(A3)
	AGW	AW_VOL
.vr:	RTS

; dyn: d0 = chunk vol * n_pt4_irqvol / 64 at mv_pos (as the audio irq)
pt_AgusDynVol:
	MOVEM.L	D1-D2/A0,-(A7)
	MOVE.L	(n_pt4_chunklist,A6),D1
	BEQ.S	.x
	MOVEA.L	D1,A0
.n:	MOVE.L	(A0)+,D1
	BLE.S	.x			; end or loop entry: keep d0
	MOVE.L	(mv_pos,A5),D2
	SUB.L	D1,D2
	BCS.S	.s
	MOVEQ	#0,D1
	MOVE.W	(A0),D1
	ADD.L	D1,D1
	CMP.L	D1,D2
	BCS.S	.hit
.s:	ADDQ.L	#4,A0
	BRA.S	.n
.hit:	MOVE.W	2(A0),D1		; chunk vol
	MOVE.W	(n_pt4_irqvol,A6),D0
	BEQ.S	.z
	MULU	D1,D0
	BEQ.S	.x
	ADD.W	#32,D0
	LSR.W	#6,D0
	BNE.S	.x
	MOVEQ	#1,D0
	BRA.S	.x
.z:	MOVEQ	#0,D0
.x:	MOVEM.L	(A7)+,D1-D2/A0
	RTS

agus_MsgBusy:	DC.B	"AMIGUS WAVETABLE IN USE",0
agus_MsgUp:	DC.B	"AMIGUS: SAMPLE UPLOAD FAILED",0
agus_MsgNone:	DC.B	"NO AMIGUS CARD",0
	EVEN
