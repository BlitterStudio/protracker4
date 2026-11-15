; extra 8ch ids: OCTA, CD81, FLT8
; octa/cd81 = 8chn layout (2048 bytes/pat)
; flt8: positions doubled (0,2,4..), 8ch pat = two 1024-byte 4ch pats
; (ch1-4, then ch5-8); positions halved after header, pats
; interleaved row by row after the pattern read
; hooks: end of id chain in pt_DosLibDiskOp, pt_0E52, pt_0E5E

; start of a load: no format state left from an aborted one
pt_LoadFlags41:
	SF	wide_Pend
	SF	fmt_Flt8Pending
	CLR.W	fmt_NarrowCh
	MOVE.L	dat_FileHandle,D1
	RTS

; a0 -> id at file ofs 1080
pt_FmtCheckMore:
	JSR	pt_WideCheck		; more than 8 channels: amigus only
	MOVE.L	D0,-(A7)
	BSR.W	pt_FmtNarrowId		; 1..7 channels (6chn, tdz3, ...)
	BEQ.S	.nn
	CMP.W	#4,D0
	BEQ.S	.is4
	MOVE.W	D0,fmt_NarrowCh		; -> 8ch, patterns in pt_FmtNarrow
	MOVE.L	(A7)+,D0
	ADDQ.L	#4,A7
	JMP	pt_Load8Stop41
.is4:	MOVE.L	(A7)+,D0		; 4chn, tdz4 = m.k.
	ADDQ.L	#4,A7
	JMP	pt_CheckModifiedAndInit
.nn:	MOVE.L	(A7)+,D0
	CMPI.L	#"OCTA",(A0)
	BEQ.S	.eight
	CMPI.L	#"CD81",(A0)
	BEQ.S	.eight
	CMPI.L	#"FLT8",(A0)
	BNE.S	.unknown
	ST	fmt_Flt8Pending
.eight:	ADDQ.L	#4,A7			; pop ret, jump like the original BEQ.W
	JMP	pt_Load8Stop41
.unknown:				; orig: try 15-smp module, else unknown format
	SF	fmt_Flt8Pending
	JSR	pt_0E37
	CMP.L	#2,D0
	BEQ.S	.ret
	ADDQ.L	#4,A7
	JMP	pt_0E43
.ret:	RTS

; a0=dat_ModulePtr after 1084-byte header; sanitize smp headers
; vol <= 64, replen 0 -> 1, loop end <= len, finetune nibble
; (bit 7 = dyn envelope follows, kept)
pt_FmtAfterHeader:
	JSR	pt_WideHeader
	MOVE.B	#$7f,(951,A0)
	MOVEM.L	D0-D3/A1,-(A7)
	LEA	mod_samples(A0),A1
	MOVEQ	#30,D3
.smp:	BSR.S	pt_FmtClampSmp
	LEA	s_SIZEOF(A1),A1
	DBF	D3,.smp
	MOVEM.L	(A7)+,D0-D3/A1
	TST.B	fmt_Flt8Pending
	BEQ.S	.r
	MOVEM.L	D0-D1/A1,-(A7)
	LEA	mod_positions(A0),A1
	MOVEQ	#127,D0
.half:	MOVE.B	(A1),D1
	LSR.B	#1,D1
	MOVE.B	D1,(A1)+
	DBF	D0,.half
	MOVEM.L	(A7)+,D0-D1/A1
.r:	RTS

; 15 smp module: same header checks, then on with the patterns
pt_Fmt15Clamp41:
	MOVEM.L	D0-D3/A1,-(A7)
	MOVEA.L	dat_ModulePtr,A1
	LEA	mod_samples(A1),A1
	MOVEQ	#14,D3
.smp:	BSR.S	pt_FmtClampSmp
	LEA	s_SIZEOF(A1),A1
	DBF	D3,.smp
	MOVEM.L	(A7)+,D0-D3/A1
	JMP	pt_0E53

; a1 = smp header: vol <= 64, replen >= 1, loop end <= len, finetune
; nibble (bit 7 kept). trashes d0-d2
pt_FmtClampSmp:
	MOVEQ	#0,D0
	MOVE.W	s_length(A1),D0		; words
	CMPI.B	#64,s_volume(A1)
	BLS.S	.volok
	MOVE.B	#64,s_volume(A1)
.volok:	ANDI.B	#$8f,s_finetune(A1)	; bit 7 kept
	MOVEQ	#0,D1			; loop end is summed as long
	MOVE.W	s_replen(A1),D1
	BNE.S	.replenok
	MOVEQ	#1,D1
	MOVE.W	D1,s_replen(A1)
.replenok:
	MOVEQ	#0,D2
	MOVE.W	s_repeat(A1),D2
	CMP.L	D0,D2			; loop start past end?
	BCS.S	.repok
	CLR.W	s_repeat(A1)
	MOVE.W	#1,s_replen(A1)
	RTS
.repok:	ADD.L	D1,D2			; loop end
	CMP.L	D0,D2
	BLS.S	.r
	SUB.L	D0,D2			; overhang
	SUB.W	D2,s_replen(A1)
	BNE.S	.r
	MOVE.W	#1,s_replen(A1)
.r:	RTS

; patterns to read (replaces the scan over song length + 1 entries,
; which took the id byte for length 128): max of all 128 positions + 1
; as pt 2.3d, capped to the buffer; positions past it -> 0, the rest
; of the file is skipped in pt_FmtAfterPatterns. d3 = patterns
pt_FmtPatCount:
	MOVEM.L	D0-D2/D4/A0-A1,-(A7)
	MOVEA.L	dat_ModulePtr,A0
	MOVE.B	mod_songlen(A0),D0	; length 1..128
	BEQ.S	.l1
	BPL.S	.lok
	MOVE.B	#128,mod_songlen(A0)
	BRA.S	.lok
.l1:	MOVE.B	#1,mod_songlen(A0)
.lok:	LEA	mod_positions(A0),A1
	MOVEQ	#0,D3
	MOVEQ	#127,D1
.pm:	MOVE.B	(A1)+,D2
	CMP.B	D3,D2
	BLS.S	.pm2
	MOVE.B	D2,D3
.pm2:	DBF	D1,.pm
	ADDQ.W	#1,D3			; d3 = patterns in the file
	MOVE.W	D3,fmt_FilePats
	MOVE.L	dat_SampleEditCfg,D4	; d4 = patterns the buffer holds
	SUB.L	#mod_patterns,D4
	MOVEQ	#10,D0
	BTST	#5,dat_ModeFlags
	BNE.S	.m4
	MOVEQ	#11,D0
.m4:	LSR.L	D0,D4
	CLR.L	fmt_SeekTo
	CMP.W	D4,D3
	BLS.S	.r
	MOVEQ	#1,D2			; file pattern: buffer one, or 4ch
	LSL.L	D0,D2			; when converted
	TST.W	dat_FileOpFlag
	BEQ.S	.fp
	MOVE.W	#1024,D2
.fp:	MOVE.L	D3,D0			; samples start here
	MULU	D2,D0
	ADD.L	#mod_patterns,D0
	MOVE.L	D0,fmt_SeekTo
	LEA	mod_positions(A0),A1	; positions past the buffer -> 0
	MOVEQ	#127,D1
.cl:	CMP.B	(A1)+,D4
	BHI.S	.cl2
	CLR.B	-1(A1)
.cl2:	DBF	D1,.cl
	MOVE.W	D4,D3
	LEA	fmt_MsgPats(PC),A0
	JSR	pt_StatusLater41
.r:	MOVEM.L	(A7)+,D0-D2/D4/A0-A1
	RTS

; song load, header read: bigger buffer for M!K! before the patterns
; are read, else all 128 positions as in a module load, capped to the
; buffer; no samples follow. d3 = pattern bytes
pt_SongPats41:
	MOVEA.L	dat_ModulePtr,A0
	CMPI.L	#"M!K!",mod_id(A0)
	BNE.S	.cnt
	TST.W	dat_SongSaveChecksum
	BNE.S	.cnt
	TST.B	dat_PatternBufFlag
	BNE.S	.cnt
	ADDQ.L	#4,A7
	JMP	pt_09FA
.cnt:	JSR	pt_FmtPatCount
	CLR.L	fmt_SeekTo
	LSL.L	#8,D3
	LSL.L	#2,D3
	RTS

; a0 -> id: xCHN (x 1..7), TDZx (1..4), CD61 -> d0 = channels, z=0;
; else z=1 (8chn, wide ids and the rest elsewhere)
pt_FmtNarrowId:
	MOVEQ	#0,D0
	CMPI.L	#'CD61',(A0)
	BNE.S	.tdz
	MOVEQ	#6,D0
	BRA.S	.y
.tdz:	CMPI.W	#'TD',(A0)
	BNE.S	.chn
	CMPI.B	#'Z',2(A0)
	BNE.S	.no
	MOVE.B	3(A0),D0
	SUB.B	#'0',D0
	BEQ.S	.no
	CMP.B	#4,D0
	BHI.S	.no
	BRA.S	.y
.chn:	MOVE.L	(A0),D0			; xCHN: 1..7 (8chn is pt's own)
	AND.L	#$00ffffff,D0
	CMP.L	#'CHN',D0
	BNE.S	.no
	MOVEQ	#0,D0
	MOVE.B	(A0),D0
	SUB.B	#'1',D0
	CMP.B	#6,D0
	BHI.S	.no
	ADDQ.B	#1,D0
.y:	TST.W	D0
	RTS
.no:	MOVEQ	#0,D0
	RTS

; pt_FmtAfterPatterns: 1..7 channel module -> 8ch rows (rest empty).
; pt read the patterns as 8ch; read them again one at a time with the
; real row size, file to the samples after
pt_FmtNarrow:
	TST.W	fmt_NarrowCh
	BEQ.W	.r
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVEA.L	dat_ModulePtr,A0
	MOVE.L	#'8CHN',mod_id(A0)
	CLR.L	fmt_SeekTo		; own seek below
	SF	fmt_TruncPending	; pt's 8ch read went past the patterns
	MOVEQ	#0,D7
	MOVE.W	fmt_FilePats,D7		; d7 = patterns in the file
	MOVE.W	fmt_NarrowCh,D6		; d6 = file row bytes
	LSL.W	#2,D6
	MOVE.L	dat_SampleEditCfg,D5	; d5 = patterns the buffer holds
	SUB.L	#mod_patterns,D5
	MOVEQ	#11,D0
	LSR.L	D0,D5
	CMP.W	D5,D7
	BCC.S	.cap
	MOVE.W	D7,D5
.cap:	MOVEA.L	dat_DosLibBase,A6
	MOVE.L	dat_FileHandle,D1
	MOVE.L	#mod_patterns,D2
	MOVEQ	#-1,D3
	JSR	pt_FileSeekPos
	MOVEA.L	dat_ModulePtr,A3
	LEA	mod_patterns(A3),A3	; a3 = 8ch rows
	SUBQ.W	#1,D5
	BMI.S	.done
	BSR.W	pt_FmtBufGet
	BEQ.S	.done
.pat:	MOVE.L	dat_FileHandle,D1	; one pattern
	MOVE.L	fmt_Buf,D2
	MOVE.W	D6,D3
	EXT.L	D3
	LSL.L	#6,D3
	JSR	pt_CheckModHeader
	MOVEA.L	fmt_Buf,A0
	MOVEQ	#63,D4
.row:	MOVEQ	#7,D1			; 8 cells: file ones, then 0
	MOVE.W	fmt_NarrowCh,D2
.cel:	CLR.L	D0
	TST.W	D2
	BEQ.S	.put
	MOVE.L	(A0)+,D0
	SUBQ.W	#1,D2
.put:	MOVE.L	D0,(A3)+
	DBF	D1,.cel
	DBF	D4,.row
	DBF	D5,.pat
	BSR.W	pt_FmtBufFree
.done:	MOVE.L	D7,D2			; samples
	MULU	D6,D2
	LSL.L	#6,D2
	ADD.L	#mod_patterns,D2
	MOVE.L	dat_FileHandle,D1
	MOVEQ	#-1,D3
	JSR	pt_FileSeekPos
	MOVE.B	fmt_NarrowCh+1,trk_Show
	CLR.W	fmt_NarrowCh
	MOVEM.L	(A7)+,D0-D7/A0-A6
.r:	RTS

pt_FmtAfterPatterns:
	BSR.W	pt_FmtNarrow
	TST.W	dat_FileOpFlag		; 4ch file in 8 tracks
	BEQ.S	.t8
	MOVE.B	#4,trk_Show
.t8:	JSR	pt_TrkClamp41
	TST.L	fmt_SeekTo		; patterns cut: file to the samples
	BEQ.S	.ns
	MOVEM.L	D0-D3/A0-A1/A6,-(A7)
	MOVEA.L	dat_DosLibBase,A6
	MOVE.L	dat_FileHandle,D1
	MOVE.L	fmt_SeekTo,D2
	MOVEQ	#-1,D3			; OFFSET_BEGINNING
	JSR	pt_FileSeekPos
	CLR.L	fmt_SeekTo
	MOVEM.L	(A7)+,D0-D3/A0-A1/A6
.ns:	JSR	pt_WidePats
	CLR.W	dat_FileOpFlag
	BSR.W	pt_FmtScanPeriods	; ext octaves check
	TST.B	fmt_Flt8Pending
	BEQ.S	.r
	SF	fmt_Flt8Pending
	MOVEM.L	D0-D3/A0-A3,-(A7)
	MOVEA.L	dat_ModulePtr,A0
	MOVE.L	#"8CHN",mod_id(A0)
; npat = max(positions)+1
	LEA	mod_positions(A0),A1
	MOVEQ	#0,D0
	MOVEQ	#127,D1
.pm:	MOVE.B	(A1)+,D2
	CMP.B	D0,D2
	BLS.S	.pm2
	MOVE.B	D2,D0
.pm2:	DBF	D1,.pm
	LEA	mod_patterns(A0),A1		; a1 = pat block (2048 bytes/pat)
	BSR.W	pt_FmtBufGet
	BEQ.S	.nb
.pat:	; copy to own buffer: the mixer irq writes mix_TickBuf
	MOVEA.L	fmt_Buf,A2
	MOVEA.L	A1,A3
	MOVE.W	#2048/4-1,D1
.cp:	MOVE.L	(A3)+,(A2)+
	DBF	D1,.cp
	MOVEA.L	fmt_Buf,A2			; a2 = ch1-4 (row r at 16r)
	LEA	1024(A2),A3			; a3 = ch5-8
	MOVEQ	#63,D1
.row:	MOVE.L	(A2)+,(A1)+
	MOVE.L	(A2)+,(A1)+
	MOVE.L	(A2)+,(A1)+
	MOVE.L	(A2)+,(A1)+
	MOVE.L	(A3)+,(A1)+
	MOVE.L	(A3)+,(A1)+
	MOVE.L	(A3)+,(A1)+
	MOVE.L	(A3)+,(A1)+
	DBF	D1,.row
	DBF	D0,.pat
	BSR.W	pt_FmtBufFree
.nb:	MOVEM.L	(A7)+,D0-D3/A0-A3
.r:	RTS

; 2 kb work buffer only while a pattern is converted -> z=1 no memory
pt_FmtBufGet:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVE.L	#2048,D0
	MOVEQ	#0,D1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-198,A6)		; AllocMem
	MOVE.L	D0,fmt_Buf
	BNE.S	.r
	LEA	smx_MsgFmtMem(PC),A0
	JSR	pt_StatusLater41
	MOVEQ	#0,D0
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS
pt_FmtBufFree:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVE.L	fmt_Buf,D0
	BEQ.S	.r
	MOVEA.L	D0,A1
	CLR.L	fmt_Buf
	MOVE.L	#2048,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-210,A6)		; FreeMem
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS
smx_MsgFmtMem:	DC.B	"NOT ENOUGH MEMORY TO CONVERT PATTERNS",0
	EVEN

; periods outside 113..856 are counted, reported once (pt_MixTaskPoll)
pt_FmtScanPeriods:
	MOVEM.L	D0-D3/A0-A1,-(A7)
	CLR.W	fmt_ExtPeriods
	MOVEA.L	dat_ModulePtr,A0
	LEA	mod_positions(A0),A1
	MOVEQ	#0,D0
	MOVEQ	#127,D1
.pm:	MOVE.B	(A1)+,D2
	CMP.B	D0,D2
	BLS.S	.pm2
	MOVE.B	D2,D0
.pm2:	DBF	D1,.pm
	ADDQ.W	#1,D0			; pats
	MULU	#64,D0
	MULU	dat_RpNumChannels,D0	; cells
	LEA	mod_patterns(A0),A1
	MOVEQ	#0,D3
.cell:	MOVE.B	(A1),D1			; smp nr > 63 (nibbles of byte 0/2) -> 0, else replayer reads past table
	AND.B	#$f0,D1
	MOVE.B	2(A1),D2
	LSR.B	#4,D2
	OR.B	D2,D1
	CMP.B	#SMX_MAX,D1
	BLS.S	.smpok
	AND.B	#$0f,(A1)
	AND.B	#$0f,2(A1)
.smpok:	MOVE.W	(A1),D1
	ADDQ.L	#4,A1
	AND.W	#$0fff,D1
	BEQ.S	.next
	CMP.W	#113,D1
	BCS.S	.ext
	CMP.W	#856,D1
	BLS.S	.next
.ext:	ADDQ.W	#1,D3
.next:	SUBQ.L	#1,D0
	BNE.S	.cell
	MOVE.W	D3,fmt_ExtPeriods
	BEQ.S	.r
	ST	fmt_ExtPending		; report from task context
.r:	MOVEM.L	(A7)+,D0-D3/A0-A1
	RTS

; hook pt_CheckModHeader: d1=fh d2=buf d3=len -> d0=bytes read
; xpk: plain copy. dos: short read -> zero-fill rest, flag truncated
pt_FmtRead:
	TST.W	dat_XpkLibFlag
	BEQ.S	.dos
	JMP	pt_CopyModData
.dos:
	MOVEM.L	D2-D3/A0,-(A7)
	JSR	(-42,A6)		; Read()
	MOVEM.L	(A7)+,D2-D3/A0
	TST.L	D0
	BMI.S	.r			; error: caller handles
	CMP.L	D3,D0
	BCC.S	.r
	MOVEM.L	D0/D3/A0,-(A7)
	MOVEA.L	D2,A0
	ADDA.L	D0,A0
	SUB.L	D0,D3
.clr:	CLR.B	(A0)+
	SUBQ.L	#1,D3
	BNE.S	.clr
	ST	fmt_TruncPending
	IFD	DEBUGFX
	ADDQ.L	#1,dbg_TruncCnt		; dbg: count padded reads
	ENDC
	MOVEM.L	(A7)+,D0/D3/A0
.r:	RTS
;--- song name that starts like a foreign magic: a mod id at 1080 wins
; a0 = dat_FileIOBuf -> mod id: jmp pt_DosLibDiskOp, else ccr of cmp mmd1
pt_MagicMod41:
	CMPI.L	#$000003f3,(A0)
	BEQ.S	.no
	MOVEM.L	D1-D3/A1,-(A7)
	MOVE.L	dat_FileHandle,D1
	MOVE.L	#mod_id,D2
	MOVEQ	#-1,D3
	JSR	pt_FileSeekPos
	MOVE.L	dat_FileHandle,D1
	MOVE.L	#dat_FileIOBuf+4,D2
	MOVEQ	#4,D3
	JSR	pt_CheckModHeader
	MOVEQ	#4,D1
	CMP.L	D1,D0
	BNE.S	.nr
	MOVE.L	dat_FileIOBuf+4,D0
	BSR.S	pt_ModIdOk41
	BNE.S	.nr
	MOVEM.L	(A7)+,D1-D3/A1
	ADDQ.L	#4,A7
	JMP	pt_DosLibDiskOp
.nr:	MOVEM.L	(A7)+,D1-D3/A1
.no:	LEA	dat_FileIOBuf,A0
	CMPI.L	#"MMD1",(A0)
	RTS

; d0 = id -> z=1 known mod id (4/8ch, xCHN, xxCH, xxCN, TDZx)
pt_ModIdOk41:
	LEA	.tab(PC),A1
.t:	TST.L	(A1)
	BEQ.S	.pat
	CMP.L	(A1)+,D0
	BNE.S	.t
	RTS
.pat:	MOVE.L	D0,D1
	CLR.B	D1
	CMP.L	#"TDZ"<<8,D1
	BEQ.S	.r
	MOVE.L	D0,D1
	AND.L	#$00ffffff,D1
	CMP.L	#$0043484e,D1		; xCHN
	BNE.S	.wide
	ROL.L	#8,D0
	SUB.B	#"1",D0
	CMP.B	#8,D0
	BRA.S	.dg
.wide:	CMP.W	#"CH",D0
	BEQ.S	.w2
	CMP.W	#"CN",D0
	BNE.S	.r
.w2:	SWAP	D0
	SUB.W	#"00",D0
	CMP.B	#9,D0
	BHI.S	.n
	LSR.W	#8,D0
	CMP.B	#9,D0
.dg:	BHI.S	.n
	CMP.B	D0,D0			; z=1
.r:	RTS
.n:	MOVEQ	#1,D0			; z=0
	RTS
.tab:	DC.L	"M.K.","M!K!","FLT4","FLT8","EXO4","!PM!","CD81","OCTA","CD61",0

fmt_TruncText:	DC.B	"MODULE TRUNCATED",0
fmt_MsgPats:	DC.B	"TOO MANY PATTERNS: REST NOT LOADED",0
	CNOP	0,2
