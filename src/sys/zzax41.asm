; ZZ9000AX voice engine output for ProTracker 4.1.
; (C) 2026 Dimitris Panokostas <midwan@gmail.com>.
; Offered under the ProTracker 4.1 terms in LICENSE.
; Client contract: sdk/docs/zz9k-voice.md in BlitterStudio/zz9000-firmware.
;
; zz9000ax voice engine: output ZZ9000AX through zz9k.library (version 2,
; revision 42 or later). Like the amigus output there is no software mixing:
; each replayer tick the voice state of the mixer (trigger, period, volume,
; loop, 81y direction) goes to the card voices, only the play positions are
; followed on the 68k (dyn envelope, loop, end); 68000 ok.
; The tables of amigus41.asm are used as they are (agus_Mem: sample entries,
; voice state, the channel structs of a wide module), and so are the voice
; update, the levels, the positions and the volume of the amigus tick.
;
; card side, from sdk/include/zz9k/voice.h and sdk/docs/zz9k-voice.md:
; - 32 voices, one sample per pt sample: ids 0-62 = samples 1-63, slot
;   n at n * 512 kb in a 63 * 512 kb bank (31.5 mb, the limit is 32 mb), signed
;   8 bit. No reversed copies and no copy of an early loop end: START with a
;   first pass, LOOP, and DIRECTION for 81y are native.
; - commands are 16 byte records with a stamp (48 khz engine frame), written
;   to a ring in shared memory. A sample goes up only when it changed (task).
; - ZZ9KVoiceWrite and ZZ9KVoiceGetStatus touch only shared memory: the
;   replayer irq calls them. Open, Close, Reset and Upload are mailbox calls:
;   task only (pt_ZzaxOn/Off/Sync/VoicesFrom41).
;
; tick source and pacing: the replayer stays on its CIA timer (or the vblank),
; as with every output of pt, so keys, the pattern and the scopes need no
; change. The card keeps its own 48 khz clock, so each tick is stamped on a
; timeline of its own: the frames of a tick are 120000 / tempo (16.16, what
; pt4__calc_spt does with rate 48000; the 5 * timer of pt_AgusSpt and the CIA
; clock of the machine make it exact on pal and ntsc), added up from the first
; stamp. The two clocks are held together on the card clock in three steps:
; 1. pt_ZzaxGate (irq, before the replayer tick) reads the status (this is
;    also the heartbeat). A tick whose stamp would be more than ZX_HOLD frames
;    past the horizon of the engine does not run: the song waits for the card
;    (as the ring of the ahi path never gets further than a half buffer ahead).
; 2. the margin (stamp - horizon) is brought to ZX_TARGET frames: each tick
;    is 1/128 of the error longer or shorter (3 percent at most), so a CIA
;    that runs a few ppm fast or slow moves the timeline, not the card.
; 3. a margin below ZX_MINM (a late record, a stall) starts the timeline
;    again from the horizon.
; The stamps of a tick are never earlier than the lead of the card: the first
; one is lead + ZX_TARGET, later ones horizon + margin. A session that the
; card ended (heartbeat, reset) is opened again by the task (pt_ZzaxPoll).
;
; sample slots: id = slot = pt sample 1-63 minus 1, as amigus41.asm.
;
; structs (C layout of voice.h for 68k gcc; every field is 32 bit except the
; two 16 bit ones of the status, all offsets are multiples of 2 and nothing
; is padded; checked against the definitions):
;  ZZ9KVoiceOpenDesc, 24 bytes: voices 0, bank_bytes 4, lead_frames 8,
;   flags 12, ring_bytes 16, staging_bytes 20
;  ZZ9KVoiceUploadDesc, 20 bytes: sample_id 0, bank_offset 4, data 8,
;   length 12, format 16
;  ZZ9KVoiceSession, 80 bytes: grant 0 (session 0, voices 4, bank_bytes 8,
;   lead_frames 12, lead_floor 16, lead_max 20, ring_records 24,
;   output_rate 28, max_samples 32), ring_handle 36, status_handle 40,
;   staging_handle 44, ring_bytes 48, staging_bytes 52, ring 56, status 60,
;   staging 64, write_cursor 68, heartbeat 72, mapped 76
;  ZZ9KVoiceStatus, 32 bytes: playing_frame 0, horizon 4, read_cursor (word) 8,
;   state (word) 10, late 12, rejected 16, underruns 20, dropped 24, session 28
;  ZZ9KVoiceRecord, 16 bytes: stamp 0, voice (byte) 4, op (byte) 5,
;   flags (word) 6, arg0 8, arg1 12
ZZ_LIBREV	EQU	42		; revision with the voice calls
ZZ_LVO_OPEN	EQU	-354		; a0 = open desc, a1 = session -> d0 status
ZZ_LVO_CLOSE	EQU	-360		; a0 = session
ZZ_LVO_RESET	EQU	-366		; a0 = session
ZZ_LVO_UPLOAD	EQU	-372		; a0 = session, a1 = upload desc -> d0 status
ZZ_LVO_WRITE	EQU	-378		; a0 = session, a1 = records, d0 = count -> d0 taken
ZZ_LVO_STATUS	EQU	-384		; a0 = session, a1 = status -> d0 status
ZZ_OP_START	EQU	1
ZZ_OP_LOOP	EQU	2
ZZ_OP_SET	EQU	3
ZZ_OP_STOP	EQU	4
ZZ_OP_MASTER	EQU	5
ZZ_OP_DIR	EQU	6
ZZ_SET_RATE	EQU	1		; arg0 = paula period
ZZ_SET_VOL	EQU	2		; arg1 = left << 16 | right
ZZ_DIR_BACK	EQU	1
ZZ_STATE_OPEN	EQU	1		; no record taken yet
	RSRESET
zo_voices	RS.L	1
zo_bank		RS.L	1
zo_lead		RS.L	1		; 0 = the floor (7680 frames)
zo_flags	RS.L	1		; bit 0 ntsc clock, bit 1 linear
zo_ring		RS.L	1		; bytes, 0 = default
zo_staging	RS.L	1		; bytes, 0 = default
zo_SIZEOF	RS.B	0
	RSRESET
zu_id		RS.L	1
zu_bank		RS.L	1
zu_data		RS.L	1
zu_len		RS.L	1
zu_fmt		RS.L	1		; 0 = signed 8 bit
zu_SIZEOF	RS.B	0
ZS_LEAD		EQU	12		; session: granted lead_frames
ZS_SIZE		EQU	80
	RSRESET
zt_play		RS.L	1		; status: frame now leaving the dac
zt_horizon	RS.L	1		; next frame the engine renders
zt_cursor	RS.W	1
zt_state	RS.W	1		; 0 closed, 1 open, 2 live
zt_rest		RS.L	5
zt_SIZEOF	RS.B	0
	RSRESET
zr_stamp	RS.L	1
zr_voice	RS.B	1
zr_op		RS.B	1
zr_flags	RS.W	1
zr_arg0		RS.L	1
zr_arg1		RS.L	1
zr_SIZEOF	RS.B	0

ZX_SLOTSH	EQU	19		; bank slot per sample: 512 kb
ZX_BANK		EQU	AGUS_NS<<ZX_SLOTSH	; 63 slots = 33030144 bytes (< 32 mb)
ZX_RING		EQU	16+256*16	; ring bytes: 256 records (default is 64)
ZX_PEND		EQU	320		; records the tick keeps for the ring
ZX_TICKMAX	EQU	168		; one tick: 32 voices * 5 + master, rounded
ZX_UNSENT	EQU	ZX_PEND-ZX_TICKMAX-32	; more waiting: the tick waits
ZX_TARGET	EQU	1920		; frames from the horizon to a stamp: 2 periods
ZX_MINM		EQU	480		; margin below this: timeline again
ZX_HOLD		EQU	4800		; margin above this: the tick waits
ZX_KSHIFT	EQU	7		; each tick corrects 1/128 of the margin error
	RSRESET
ZXM_SESS	RS.B	ZS_SIZE		; zzax_Mem: session (first: the library gets it as it is)
ZXM_STAT	RS.B	zt_SIZEOF	; status read by the tick
ZXM_STATT	RS.B	zt_SIZEOF	; status read by the task
ZXM_OPEN	RS.B	zo_SIZEOF
ZXM_UP		RS.B	zu_SIZEOF
ZXM_PEND	RS.B	ZX_PEND*zr_SIZEOF
ZXM_SIZE	RS.B	0

; library on first need (output zz9000ax); zzax_Card = 0 if none. The card
; itself answers at the first Open (voice engine, session free)
pt_ZzaxDetect:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	TST.B	zzax_Tried
	BNE.S	.r
	ST	zzax_Tried
	MOVEA.L	ABSEXECBASE.W,A6
	LEA	zzax_LibName(PC),A1
	MOVEQ	#2,D0
	JSR	(-552,A6)		; OpenLibrary
	MOVE.L	D0,zzax_Base
	BEQ.S	.r
	MOVEA.L	D0,A0
	CMPI.W	#ZZ_LIBREV,22(A0)	; lib_Revision
	BCS.S	.old
	MOVE.L	D0,zzax_Card
	BRA.S	.r
.old:	BSR.S	pt_ZzaxClose		; library without the voice calls
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

; exit (after pt_AgusClose, which has turned the output off): library closed
pt_ZzaxClose:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	CLR.L	zzax_Card
	MOVE.L	zzax_Base,D0
	BEQ.S	.r
	CLR.L	zzax_Base
	MOVEA.L	D0,A1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-414,A6)		; CloseLibrary
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

; any card for more than 8 channels: z=0 amigus or zz9000ax there (detect first)
pt_CardAny41:
	TST.L	agus_Card
	BNE.S	.r
	TST.L	zzax_Card
.r:	RTS

; texts that name the card: d0 = 0 amigus, 1 zz9000ax, 2 both cards there,
; 3 none. The output in use names itself, else the cards found (detect
; first). Only d0 changes.
pt_CardCase41:
	TST.B	zzax_On
	BNE.S	.zz
	TST.B	agus_On
	BNE.S	.ag
	TST.L	zzax_Card
	BNE.S	.zc
	TST.L	agus_Card
	BNE.S	.ag
	MOVEQ	#3,D0
	RTS
.zc:	TST.L	agus_Card
	BNE.S	.both
.zz:	MOVEQ	#1,D0
	RTS
.ag:	MOVEQ	#0,D0
	RTS
.both:	MOVEQ	#2,D0
	RTS

; a0 = table of 4 string pointers (amigus, zz9000ax, both, none) -> a0 = the
; one for the cards (pt_CardCase41); other registers kept
pt_CardStr41:
	MOVE.L	D0,-(A7)
	BSR.S	pt_CardCase41
	LSL.W	#2,D0
	MOVEA.L	(0,A0,D0.W),A0
	MOVE.L	(A7)+,D0
	RTS

; both cards: they take turns on a click of OUTPUT. d0 = 3 amigus / 4
; zz9000ax, z=1 no card
pt_SndCardNext41:
	MOVEQ	#3,D0
	TST.L	agus_Card
	BEQ.S	.z
	TST.L	zzax_Card
	BEQ.S	.y
	TST.B	snd_Alt
	BEQ.S	.y
	MOVEQ	#4,D0
.y:	ANDI	#$fb,CCR
	RTS
.z:	MOVEQ	#4,D0
	TST.L	zzax_Card
	RTS

;--- output
; task: session, tables, samples over
; d0 = 0 ok, -1 no library / voice engine in use
pt_ZzaxOn:
	MOVEM.L	D1-D7/A0-A6,-(A7)
	TST.B	agus_On
	BNE.W	.ok
	TST.L	zzax_Card
	BEQ.W	.no
	TST.L	agus_Mem		; tables of amigus41.asm (not in the bss: a500 memory)
	BNE.S	.hm
	MOVE.L	#AGM_SIZE,D0
	MOVE.L	#$10001,D1		; MEMF_PUBLIC|MEMF_CLEAR
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-198,A6)
	MOVE.L	D0,agus_Mem
	BEQ.W	.no
.hm:	TST.L	zzax_Mem		; session, status, records
	BNE.S	.zm
	MOVE.L	#ZXM_SIZE,D0
	MOVE.L	#$10001,D1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-198,A6)
	MOVE.L	D0,zzax_Mem
	BEQ.W	.no
.zm:	BSR.W	pt_ZzaxOpen
	TST.L	D0
	BNE.W	.no
	JSR	pt_SndAhiDrop		; ahi running: off, paula back first
	BSR.W	pt_ZzaxState
	SF	zx_Lost
	CLR.B	zx_Fails
	ST	zzax_On			; the sync below sends over the library
	ST	zx_Ready
	BSR.W	pt_AgusSync
	ST	agus_On
.ok:	MOVEQ	#0,D0
	BRA.S	.r
.no:	MOVE.L	zzax_Mem,D0		; tables back
	BEQ.S	.nz
	CLR.L	zzax_Mem
	MOVEA.L	D0,A1
	MOVE.L	#ZXM_SIZE,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-210,A6)
.nz:	MOVE.L	agus_Mem,D0
	BEQ.S	.nf
	CLR.L	agus_Mem
	MOVEA.L	D0,A1
	MOVE.L	#AGM_SIZE,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-210,A6)
.nf:	MOVEQ	#-1,D0
.r:	MOVEM.L	(A7)+,D1-D7/A0-A6
	RTS

; voices off, session closed, tables back (task or exit); pt_AgusOff calls it
pt_ZzaxOff:
	TST.B	zzax_On
	BEQ.W	.r
	TST.B	mix_Active		; mixer first: else a tick would start a note
	BEQ.S	.nm0
	JSR	pt_MixStop		; (voices off: Reset)
.nm0:	ST	zx_Busy			; no tick touches the session from here
	SF	zx_Ready
	SF	agus_On
	SF	zzax_On
	SF	zx_Hold			; (pt_AgusRun must not skip the amigus ticks)
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	JSR	pt_WideOff		; wide modules need the card
	BSR.W	pt_ZzaxShut		; silent, bank and buffers free
	MOVE.L	zzax_Mem,D0
	BEQ.S	.nz
	CLR.L	zzax_Mem
	MOVEA.L	D0,A1
	MOVE.L	#ZXM_SIZE,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-210,A6)
.nz:	MOVE.L	agus_Mem,D0
	BEQ.S	.nm
	CLR.L	agus_Mem
	MOVEA.L	D0,A1
	MOVE.L	#AGM_SIZE,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-210,A6)
.nm:	SF	zx_Busy
	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
.r:	RTS

; task: voice session with the 256 record ring, else with the defaults
; d0 = 0 ok (zx_Open, zx_Lead), else the status of the library
pt_ZzaxOpen:
	MOVEM.L	D1-D2/A0-A2/A6,-(A7)
	MOVEA.L	zzax_Mem,A2
	MOVEQ	#1,D2			; second try: ring and staging by default
.try:	LEA	ZXM_OPEN(A2),A0
	MOVEQ	#32,D0
	MOVE.L	D0,(zo_voices,A0)	; all voices: a wide module can need them
	MOVE.L	#ZX_BANK,(zo_bank,A0)
	CLR.L	(zo_lead,A0)		; the floor, 7680 frames (160 ms)
	CLR.L	(zo_flags,A0)		; pal clock like amigus, nearest sample like paula
	MOVE.L	#ZX_RING,(zo_ring,A0)
	TST.W	D2
	BNE.S	.go
	CLR.L	(zo_ring,A0)
.go:	CLR.L	(zo_staging,A0)
	LEA	ZXM_SESS(A2),A1
	MOVEA.L	zzax_Base,A6
	JSR	(ZZ_LVO_OPEN,A6)
	TST.L	D0
	BEQ.S	.ok
	CMP.L	#2,D0			; busy / unsupported: no use trying again
	BEQ.S	.r
	CMP.L	#3,D0
	BEQ.S	.r
	DBF	D2,.try
	BRA.S	.r
.ok:	MOVE.L	(ZXM_SESS+ZS_LEAD,A2),zx_Lead
	ST	zx_Open
	MOVEQ	#0,D0
.r:	MOVEM.L	(A7)+,D1-D2/A0-A2/A6
	RTS

; task: session closed (the card frees the bank, the buffers go back)
pt_ZzaxShut:
	TST.B	zx_Open
	BEQ.S	.r
	SF	zx_Open
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVEA.L	zzax_Mem,A0		; ZXM_SESS = 0
	MOVEA.L	zzax_Base,A6
	JSR	(ZZ_LVO_CLOSE,A6)
	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
.r:	RTS

; nothing on the card (new session): sample entries, voice state, records,
; timeline and tempo cache
pt_ZzaxState:
	MOVEM.L	D0/A0,-(A7)
	AGM	AGM_SMP,A0
	MOVE.W	#AGUS_NS*as_SIZEOF/4-1,D0
.s:	CLR.L	(A0)+
	DBF	D0,.s
	AGM	AGM_VOICE,A0
	MOVE.W	#32*av_SIZEOF/4-1,D0
.v:	CLR.L	(A0)+
	DBF	D0,.v
	CLR.W	zx_PCnt
	CLR.W	zx_PDone
	CLR.W	zx_Frac
	CLR.L	zx_SptKey
	SF	zx_Anch
	SF	zx_Hold
	SF	zx_Fresh
	MOVE.W	#-1,zx_Master
	MOVEM.L	(A7)+,D0/A0
	RTS

; task, with every pt_AgusSync pass: heartbeat (the tick does it while the
; replayer runs), a session the card ended: a new one, samples again
pt_ZzaxPoll:
	MOVEM.L	D0-D2/A0-A1/A6,-(A7)
	TST.B	zx_Lost
	BNE.S	.lost
	TST.B	zx_Ready
	BEQ.W	.x
	MOVE.W	#ZXM_STATT,D1
	BSR.W	pt_ZzaxRead
	BRA.S	.x
.lost:	ST	zx_Busy
	SF	zx_Ready
	BSR.W	pt_ZzaxShut		; (frees the buffers whatever the card says)
	BSR.W	pt_ZzaxOpen
	TST.L	D0
	BNE.S	.fail
	BSR.W	pt_ZzaxState		; samples are gone with the session
	SF	zx_Lost
	CLR.B	zx_Fails
	ST	zx_Ready
	SF	zx_Busy
	BRA.S	.x
.fail:	ADDQ.B	#1,zx_Fails		; 3 tries, then back to paula
	CMP.B	#3,zx_Fails
	BCS.S	.x
	SF	zx_Lost
	JSR	pt_SndPause
	ST	snd_Started
	JSR	pt_MixStop
	MOVE.B	#1,snd_Target		; the switch resumes the song
	MOVE.B	#2,snd_Defer
	LEA	zzax_MsgLost(PC),A0
	JSR	pt_StatusLater41
.x:	MOVEM.L	(A7)+,D0-D2/A0-A1/A6
	RTS

; session status (also the heartbeat): d1.w = ZXM_STAT (tick) or ZXM_STATT
; (task) -> z=1 ok. z=0: the card closed the session (zx_Lost: the task opens
; a new one), nothing is sent until then
pt_ZzaxRead:
	MOVEM.L	D0-D2/A0-A1/A6,-(A7)
	MOVEQ	#0,D2
	MOVE.W	D1,D2
	MOVEA.L	zzax_Mem,A0		; ZXM_SESS = 0
	LEA	0(A0,D2.L),A1
	MOVEA.L	zzax_Base,A6
	JSR	(ZZ_LVO_STATUS,A6)
	TST.L	D0
	BNE.S	.gone
	MOVEA.L	zzax_Mem,A0
	TST.W	(zt_state,A0,D2.L)
	BEQ.S	.gone
	MOVEM.L	(A7)+,D0-D2/A0-A1/A6
	ORI	#4,CCR
	RTS
.gone:	ST	zx_Lost
	SF	zx_Ready
	MOVEM.L	(A7)+,D0-D2/A0-A1/A6
	ANDI	#$fb,CCR
	RTS

; task: all voices (d0.w = 0) or the voices from d0.w on go silent, the
; state is cleared. All: Reset (drops the records the card still holds, the
; timeline goes on from a fresh status). From a voice: STOP records.
pt_ZzaxVoicesFrom41:
	TST.B	zx_Ready
	BEQ.W	.r
	MOVEM.L	D0-D3/D7/A0-A1/A6,-(A7)
	MOVE.W	D0,D7			; d7 = first voice
	BNE.S	.part
	MOVE.B	zx_Busy,D2		; the tick keeps its hands off the session
	ST	zx_Busy
	MOVEA.L	zzax_Mem,A0		; ZXM_SESS = 0
	MOVEA.L	zzax_Base,A6
	JSR	(ZZ_LVO_RESET,A6)
	CLR.W	zx_PCnt
	CLR.W	zx_PDone
	SF	zx_Anch
	AGM	AGM_VOICE,A0
	MOVE.W	#32*av_SIZEOF/4-1,D0
.c:	CLR.L	(A0)+
	DBF	D0,.c
	MOVE.B	D2,zx_Busy
	BRA.S	.x
.part:	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-120,A6)		; Disable: the tick appends records too
	AGM	AGM_VOICE,A0
	MOVE.W	D7,D0
	MULU	#av_SIZEOF,D0
	ADDA.L	D0,A0
.pl:	TST.B	av_on(A0)
	BEQ.S	.pn
	MOVEQ	#ZZ_OP_STOP,D0
	MOVEQ	#0,D1
	MOVEQ	#0,D2
	MOVEQ	#0,D3
	BSR.W	pt_ZzaxPut
.pn:	MOVEQ	#av_SIZEOF/4-1,D0
.pz:	CLR.L	(A0)+
	DBF	D0,.pz
	ADDQ.W	#1,D7
	CMP.W	#32,D7
	BCS.S	.pl
	JSR	(-126,A6)		; Enable
.x:	MOVEM.L	(A7)+,D0-D3/D7/A0-A1/A6
.r:	RTS

; sample of pt_AgusSync (task): a4 = entry, d7 = sample 0-62, d4 = address,
; d5 = length, d3 = sum. The bytes go to the bank slot of the sample over the
; library and define the sample id; the entry says the card has them (else it
; counts the failure: three times the same data, then a status message)
; all registers kept
pt_ZzaxUpload:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVEA.L	zzax_Mem,A5
	LEA	ZXM_UP(A5),A1
	MOVEQ	#0,D0
	MOVE.W	D7,D0
	MOVE.L	D0,(zu_id,A1)
	MOVEQ	#ZX_SLOTSH,D1
	LSL.L	D1,D0
	MOVE.L	D0,(zu_bank,A1)
	MOVE.L	D4,(zu_data,A1)
	MOVE.L	D5,(zu_len,A1)
	CLR.L	(zu_fmt,A1)		; signed 8 bit
	MOVEA.L	A5,A0			; ZXM_SESS = 0
	MOVEA.L	zzax_Base,A6
	JSR	(ZZ_LVO_UPLOAD,A6)
	MOVE.L	D4,as_addr(A4)
	MOVE.L	D5,as_len(A4)
	MOVE.L	D3,as_sum(A4)
	TST.L	D0
	BNE.S	.bad
	CLR.B	as_try(A4)
	ST	as_ok(A4)
	BRA.S	.r
.bad:	ADDQ.B	#1,as_try(A4)
	CMP.B	#3,as_try(A4)
	BNE.S	.r
	LEA	zzax_MsgUp(PC),A0
	JSR	pt_StatusLater41
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

;--- tick
; replayer irq, first thing (pt_AgusStamp): read the status and decide if
; this tick runs. It waits when the records of the last ticks did not fit the
; ring, or when its stamp is more than ZX_HOLD frames past the horizon of the
; engine (the CIA runs ahead of the card, or the card has stopped). zx_Hold
; makes pt_MixMusicEntry return at once and pt_AgusRun do nothing. All
; registers kept.
pt_ZzaxGate:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	SF	zx_Hold
	SF	zx_Fresh
	TST.B	zx_Ready
	BEQ.S	.x
	TST.B	zx_Busy
	BNE.S	.x
	MOVE.W	#ZXM_STAT,D1
	BSR.W	pt_ZzaxRead
	BNE.S	.x			; no session
	ST	zx_Fresh
	BSR.W	pt_ZzaxFlush		; what the ring could not take last time
	TST.B	zx_Anch
	BEQ.S	.x
	MOVE.W	zx_PCnt,D0
	SUB.W	zx_PDone,D0
	CMP.W	#ZX_UNSENT,D0
	BHI.S	.hold
	MOVEA.L	zzax_Mem,A0
	MOVE.L	zx_Stamp,D0
	SUB.L	(ZXM_STAT+zt_horizon,A0),D0
	CMP.L	#ZX_HOLD,D0
	BLE.S	.x
.hold:	ST	zx_Hold
.x:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; records the ring takes: pending records from zx_PDone on
pt_ZzaxFlush:
	MOVEM.L	D0-D2/A0-A2/A6,-(A7)
	MOVEQ	#0,D2
	MOVE.W	zx_PCnt,D2
	MOVEQ	#0,D1
	MOVE.W	zx_PDone,D1
	SUB.L	D1,D2			; d2 = waiting
	BLE.S	.x
	MOVEA.L	zzax_Mem,A2
	LEA	ZXM_PEND(A2),A1
	LSL.L	#4,D1			; zr_SIZEOF
	ADDA.L	D1,A1
	MOVEA.L	A2,A0			; ZXM_SESS = 0
	MOVE.L	D2,D0
	MOVEA.L	zzax_Base,A6
	JSR	(ZZ_LVO_WRITE,A6)	; d0 = taken
	ADD.W	D0,zx_PDone
	MOVE.W	zx_PDone,D0
	CMP.W	zx_PCnt,D0
	BNE.S	.x
	CLR.W	zx_PCnt			; all in the ring
	CLR.W	zx_PDone
.x:	MOVEM.L	(A7)+,D0-D2/A0-A2/A6
	RTS

; one record to the waiting ones, stamp of the tick: d0.b = op, d1.w = flags,
; d2 = arg0, d3 = arg1, d7.w = voice. Full (never, the tick checks): lost.
pt_ZzaxPut:
	MOVEM.L	D4/A0,-(A7)
	MOVEQ	#0,D4
	MOVE.W	zx_PCnt,D4
	CMP.W	#ZX_PEND,D4
	BCC.S	.x
	LSL.L	#4,D4			; zr_SIZEOF
	MOVEA.L	zzax_Mem,A0
	LEA	ZXM_PEND(A0),A0
	ADDA.L	D4,A0
	MOVE.L	zx_Stamp,(A0)+
	MOVE.B	D7,(A0)+
	MOVE.B	D0,(A0)+
	MOVE.W	D1,(A0)+
	MOVE.L	D2,(A0)+
	MOVE.L	D3,(A0)
	ADDQ.W	#1,zx_PCnt
.x:	MOVEM.L	(A7)+,D4/A0
	RTS

; stamp of this tick (zx_Stamp): the timeline goes on from the last tick. The
; first tick, the first after Reset and a tick that would be late start it
; again from the horizon (stamps never go down: the margin is below ZX_MINM)
pt_ZzaxTime:
	MOVEA.L	zzax_Mem,A0
	MOVE.L	(ZXM_STAT+zt_horizon,A0),D0
	TST.B	zx_Anch
	BEQ.S	.new
	MOVE.L	zx_Stamp,D1
	SUB.L	D0,D1			; margin: frames from the horizon to the stamp
	CMP.L	#ZX_MINM,D1
	BGE.S	.r
.new:	CMPI.W	#ZZ_STATE_OPEN,(ZXM_STAT+zt_state,A0)
	BNE.S	.live
	MOVE.L	zx_Lead,D0		; no record taken yet: frame 0 is the arrival
.live:	ADD.L	#ZX_TARGET,D0		; of the first one, the lead is on time
	MOVE.L	D0,zx_Stamp
	ST	zx_Anch
	MOVE.W	#-1,zx_Master		; gain with the first records
.r:	RTS

; frames per tick, 16.16: agus_Spt5 = 5 * timer, timer = cia clock / tempo,
; so 5 * timer * 12000 / (cia clock / 2) = 120000 / tempo = frames of a tick
; at 48 khz. As pt4__calc_spt: whole frames, then 2 * 8 bits of fraction.
; Only when the tempo changed (agus_Spt5 < 2^19, so the product is < 2^32)
pt_ZzaxSpt:
	MOVEM.L	D0-D5,-(A7)
	MOVE.L	agus_Spt5,D0
	CMP.L	zx_SptKey,D0
	BEQ.S	.x
	MOVE.L	D0,zx_SptKey
	MOVE.L	D0,D1
	MULU	#12000,D0		; low word
	SWAP	D1
	MULU	#12000,D1		; high word (3 at most)
	SWAP	D1
	ADD.L	D1,D0			; d0 < 2^32
	MOVE.L	dat_CIATimingBase,D3
	LSR.L	#1,D3			; d3 = divisor (pt_MixDiv32 keeps it)
	MOVE.L	D3,D1
	JSR	pt_MixDiv32
	MOVE.L	D0,D4			; whole frames
	LSL.L	#8,D1
	MOVE.L	D1,D0
	MOVE.L	D3,D1
	JSR	pt_MixDiv32
	MOVE.L	D0,D5			; next 8 bits
	LSL.L	#8,D1
	MOVE.L	D1,D0
	MOVE.L	D3,D1
	JSR	pt_MixDiv32		; d0 = last 8 bits
	SWAP	D4
	LSL.L	#8,D5
	OR.L	D5,D4
	OR.L	D0,D4
	MOVE.L	D4,zx_Spt16
.x:	MOVEM.L	(A7)+,D0-D5
	RTS

; timeline one tick on: the frames of this tick, longer or shorter by 1/128
; of how far the margin (stamp - horizon) is from ZX_TARGET, 3 percent at
; most: the CIA and the card clock stay together without a step
pt_ZzaxNext:
	MOVE.L	zx_Spt16,D0
	MOVEQ	#0,D1
	MOVE.W	zx_Frac,D1
	ADD.L	D1,D0
	MOVE.W	D0,zx_Frac
	SWAP	D0
	AND.L	#$ffff,D0		; d0 = frames
	MOVEA.L	zzax_Mem,A0
	MOVE.L	zx_Stamp,D1
	SUB.L	(ZXM_STAT+zt_horizon,A0),D1
	SUB.L	#ZX_TARGET,D1		; too far ahead (+) or too close (-)
	ASR.L	#ZX_KSHIFT,D1
	MOVE.L	D0,D2
	LSR.L	#5,D2			; limit: 1/32 of the tick
	CMP.L	D2,D1
	BLE.S	.hi
	MOVE.L	D2,D1
.hi:	NEG.L	D2
	CMP.L	D2,D1
	BGE.S	.lo
	MOVE.L	D2,D1
.lo:	SUB.L	D1,D0
	BGT.S	.ok
	MOVEQ	#1,D0
.ok:	ADD.L	D0,zx_Stamp
	RTS

; replayer irq (pt_AgusTick for the zz9000ax): voice state -> records of this
; tick -> ring. The voice update, levels and positions are the ones of the
; amigus tick (pt_AgusRun); a0-a6/d0-d7 are free
pt_ZzaxTick:
	TST.B	zx_Ready
	BEQ.W	.r
	TST.B	zx_Busy			; task resets or opens a session
	BNE.W	.r
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.B	zx_Fresh		; the gate has read the status of this tick
	BNE.S	.fr
	MOVE.W	#ZXM_STAT,D1
	BSR.W	pt_ZzaxRead
	BNE.W	.x
.fr:	SF	zx_Fresh
	MOVE.W	zx_PCnt,D0		; ring did not take the last ticks: no room
	SUB.W	zx_PDone,D0
	CMP.W	#ZX_UNSENT+32,D0
	BHI.W	.x
	BSR.W	pt_ZzaxTime
	BSR.W	pt_ZzaxSpt
	MOVE.W	agus_NV,D0		; gain: a wide module keeps 32 voices from
	CMP.W	#32,D0			; clipping the sum (8 voices: unity, like the
	BLS.S	.nv			; amigus; more: 256 * sqrt(8 / voices))
	MOVEQ	#32,D0
.nv:	ADD.W	D0,D0
	LEA	zzax_MasterTab(PC),A0
	MOVE.W	(A0,D0.W),D2
	CMP.W	zx_Master,D2
	BEQ.S	.nm
	MOVE.W	D2,zx_Master
	AND.L	#$ffff,D2
	MOVEQ	#ZZ_OP_MASTER,D0
	MOVEQ	#0,D1
	MOVEQ	#0,D3
	MOVEQ	#0,D7
	BSR.W	pt_ZzaxPut
.nm:	MOVEA.L	agus_VoBase,A5
	AGM	AGM_VOICE,A4
	MOVEA.L	agus_ChBase,A6
	MOVEQ	#0,D7			; voice
.v:	MOVE.B	(mv_active,A5),D0
	BNE.S	.act
	TST.B	av_on(A4)
	BEQ.W	.nx
	MOVEQ	#ZZ_OP_STOP,D0		; ended or stopped
	MOVEQ	#0,D1
	MOVEQ	#0,D2
	MOVEQ	#0,D3
	BSR.W	pt_ZzaxPut
	CLR.L	av_vol(A4)
	SF	av_on(A4)
	BRA.W	.nx
.act:	CMP.B	#$ff,D0			; new note (mixer: ST)
	BEQ.S	.new
	TST.B	av_on(A4)
	BEQ.W	.nx
	MOVE.B	(mv_back,A5),D0		; 81y: the engine turns the voice itself
	CMP.B	av_back(A4),D0
	BEQ.S	.same
	MOVE.B	D0,av_back(A4)
	BSR.W	pt_ZzaxDir
	BRA.S	.rv
.same:	BSR.W	pt_ZzaxLoopChk
	BRA.S	.rv
.new:	MOVE.B	#1,(mv_active,A5)
	LEA	agus_Hit,A0		; level: started on the card
	ST	(A0,D7.W)
	BSR.W	pt_ZzaxStart
.rv:	TST.B	av_on(A4)
	BEQ.S	.nx
	BSR.W	pt_ZzaxRate
	BSR.W	pt_AgusVol		; volume and split as amigus: SET (pt_ZzaxVolOut)
.nx:	LEA	mv_SIZEOF(A5),A5
	LEA	av_SIZEOF(A4),A4
	LEA	n_SIZEOF(A6),A6
	ADDQ.W	#1,D7
	CMP.W	agus_NV,D7
	BNE.W	.v
	BSR.W	pt_ZzaxNext
	BSR.W	pt_ZzaxFlush
.x:	MOVEM.L	(A7)+,D0-D7/A0-A6
.r:	RTS

; (re)start card voice d7 at the play position: START (offset in the sample,
; first pass), its loop (START clears it), direction. a4 = voice state,
; a5 = voice, a6 = channel. Rate and volume follow in the tick.
pt_ZzaxStart:
	SF	av_on(A4)
	BSR.W	pt_AgusLoop		; d4 = loop start, d5 = loop len (dyn: list)
	MOVE.L	D4,av_loop(A4)
	MOVE.L	D5,av_llen(A4)
	MOVE.L	(mv_pos,A5),D0
	BSR.W	pt_AgusFind		; a0 = sample entry, d1 = offset in it
	BEQ.W	.r			; sample not on the card (yet)
	MOVE.L	D1,D6			; d6 = start offset
	MOVEQ	#0,D2			; first pass: to the sample end ...
	TST.L	D5
	BEQ.S	.fp
	MOVE.L	D4,D2			; ... or to the loop end
	ADD.L	D5,D2
	SUB.L	(mv_pos,A5),D2
	BGT.S	.fp
	MOVEQ	#0,D2
.fp:	BSR.W	pt_AgusSlot		; d1 = slot = sample * 2^19
	SWAP	D1
	LSR.W	#3,D1			; d1.w = sample id
	MOVE.L	D2,D3			; arg1 first pass
	MOVE.L	D6,D2			; arg0 offset
	MOVEQ	#ZZ_OP_START,D0
	BSR.W	pt_ZzaxPut
	TST.L	D5
	BEQ.S	.nl
	MOVE.L	D4,D2
	SUB.L	as_addr(A0),D2		; loop start in the sample
	BCS.S	.nl
	MOVE.L	D5,D3
	MOVEQ	#ZZ_OP_LOOP,D0
	MOVEQ	#0,D1
	BSR.W	pt_ZzaxPut
.nl:	MOVE.B	(mv_back,A5),D0
	MOVE.B	D0,av_back(A4)
	BEQ.S	.nb
	BSR.W	pt_ZzaxDir
.nb:	CLR.W	av_per(A4)		; rate and volume again
	MOVE.L	#-1,av_vol(A4)
	CLR.L	av_vkey(A4)
	ST	av_on(A4)
.r:	RTS

; d0.b = mv_back: DIRECTION record of voice d7
pt_ZzaxDir:
	MOVEQ	#0,D1
	TST.B	D0
	BEQ.S	.f
	MOVEQ	#ZZ_DIR_BACK,D1
.f:	MOVEQ	#ZZ_OP_DIR,D0
	MOVEQ	#0,D2
	MOVEQ	#0,D3
	BRA.W	pt_ZzaxPut

; running forward voice: new loop (sample w/o note) -> LOOP; no loop: the
; voice ends with its pass
pt_ZzaxLoopChk:
	TST.B	av_back(A4)
	BNE.S	.r
	BSR.W	pt_AgusLoop
	CMP.L	av_loop(A4),D4
	BNE.S	.ch
	CMP.L	av_llen(A4),D5
	BEQ.S	.r
.ch:	MOVE.L	D4,av_loop(A4)
	MOVE.L	D5,av_llen(A4)
	MOVEQ	#0,D2
	MOVEQ	#0,D3
	TST.L	D5
	BEQ.S	.put
	MOVE.L	D4,D0
	BSR.W	pt_AgusFind
	BEQ.S	.r
	MOVE.L	D1,D2			; loop start in the sample
	MOVE.L	D5,D3
.put:	MOVEQ	#ZZ_OP_LOOP,D0
	MOVEQ	#0,D1
	BRA.W	pt_ZzaxPut
.r:	RTS

; rate: the period as it is, only when it changed (the card divides the
; paula clock itself). Below 5 the engine would ignore it
pt_ZzaxRate:
	MOVEQ	#0,D2
	MOVE.W	(mv_period,A5),D2
	CMP.W	#5,D2
	BCS.S	.r
	CMP.W	av_per(A4),D2
	BEQ.S	.r
	MOVE.W	D2,av_per(A4)
	MOVEQ	#ZZ_OP_SET,D0
	MOVEQ	#ZZ_SET_RATE,D1
	MOVEQ	#0,D3
	BRA.W	pt_ZzaxPut
.r:	RTS

; pt_AgusVol hook: d3 = left << 16 | right (16 bit each, vol 64 = $4000,
; setup VOLUME and STEREO as amigus; left tracks n & 3 = 0 or 3) -> SET
pt_ZzaxVolOut:
	MOVEQ	#ZZ_OP_SET,D0
	MOVEQ	#ZZ_SET_VOL,D1
	MOVEQ	#0,D2
	BRA.W	pt_ZzaxPut

; master gain Q8.8 (256 = unity) by voice count 0-32: a voice is $4000 at
; vol 64, so a mixed song of up to 8 voices needs none (as the amigus); more
; voices share the headroom: 256 * sqrt(8 / n), the sum of random voices
; grows with the root of their number. Loud coherent voices on one side can
; still clip at the end of the sum, the engine clamps to 16 bits.
zzax_MasterTab:
	DC.W	256,256,256,256,256,256,256,256,256
	DC.W	241,229,218,209,201,194,187,181
	DC.W	176,171,166,162,158,154,151,148
	DC.W	145,142,139,137,134,132,130,128

zzax_LibName:	DC.B	"zz9k.library",0
zzax_MsgUp:	DC.B	"ZZ9000AX: SAMPLE UPLOAD FAILED",0
zzax_MsgNone:	DC.B	"NO ZZ9000AX LIBRARY",0
zzax_MsgBusy:	DC.B	"ZZ9000AX VOICES NOT AVAILABLE",0
zzax_MsgLost:	DC.B	"ZZ9000AX LOST: BACK TO PAULA",0
	EVEN
