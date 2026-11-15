; save exe, 8ch: player stub + 8chn module
; 4ch keeps the original stub (dat_HunkHeaderData), 8ch writes exe8_Stub,
; kept packed and unpacked into exe8_Buf only while saving

	INCLUDE	"src/data/bin/exe8_stub.i"
	INCLUDE	"src/data/bin/exe8_stub_lz.i"

; hook pt_0EBE: patch hunk sizes, d0 = mod size in longs
pt_Exe8Patch:
	BTST	#5,dat_ModeFlags	; bit 5 = 4ch
	BNE.S	.ch4
	MOVEM.L	D0-D2/D6/A1-A3/A6,-(A7)
	BSR.W	pt_Exe8Free
	MOVE.L	#EXE8_LEN,D0
	MOVEQ	#0,D1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-198,A6)		; AllocMem
	MOVE.L	D0,exe8_Buf
	BEQ.S	.nomem
	LEA	exe8_Stub,A0
	MOVEA.L	D0,A1
	LEA	EXE8_LEN(A1),A2
	BSR.W	pt_Exe8Unpack
	MOVEM.L	(A7)+,D0-D2/D6/A1-A3/A6
	MOVEA.L	exe8_Buf,A0
	MOVE.L	D0,EXE8_DATASIZE(A0)
	ADD.L	#$40000000,D0		; chip hunk
	MOVE.L	D0,EXE8_HDRSIZE(A0)
	RTS
.nomem:	MOVEM.L	(A7)+,D0-D2/D6/A1-A3/A6
	LEA	12(A7),A7		; return, both sizes of the caller
	JMP	pt_SetupPaletteMode	; "NOT ENOUGH MEMORY!", back to its caller
.ch4:	LEA	dat_HunkHeaderData,A0
	ADDA.W	#$1590,A0
	MOVE.L	D0,(A0)
	LEA	dat_HunkHeaderData,A0
	ADDA.W	#$0018,A0
	ADD.L	#$40000000,D0
	MOVE.L	D0,(A0)
	RTS

; hook: file write size/addr
pt_Exe8WriteParams:
	BTST	#5,dat_ModeFlags
	BNE.S	.ch4
	MOVE.L	#EXE8_LEN,dat_FileWriteSize
	MOVE.L	exe8_Buf,dat_FileWriteAddr
	RTS
.ch4:	MOVE.L	#$00001594,dat_FileWriteSize
	MOVE.L	#dat_HunkHeaderData,dat_FileWriteAddr
	RTS

; hook pt_PrepareModSave: d0 = pattern bytes (1024/pat, 2048 in 8ch)
pt_Exe8PatBytes:
	BSR.W	pt_Exe8Free		; stub is written
	MOVEQ	#0,D0
	MOVE.W	dat_NumSamples,D0
	ADDQ.L	#1,D0
	LSL.L	#8,D0
	LSL.L	#2,D0
	BTST	#5,dat_ModeFlags
	BNE.S	.r
	ADD.L	D0,D0
.r:	RTS

; hook: a0 = mod, 8chn id in 8ch
pt_Exe8ModId:
	BTST	#5,dat_ModeFlags
	BNE.S	.ch4
	MOVE.L	#$3843484e,(mod_id,A0)	; "8CHN"
	RTS
.ch4:	CMPI.W	#$0040,dat_NumSamples
	BCS.S	.r
	MOVE.L	#$4d214b21,(mod_id,A0)	; "M!K!" from 64 pats
.r:	RTS

; hook: exe load; file ofs 40 = 8ch stub id -> mod after exe8_Stub
pt_Exe8LoadMark:
	MOVE.W	#$0001,dat_SampleTableOfs
	MOVE.L	#$00001594,exe8_Skip
	MOVEM.L	D0/A1,-(A7)
	MOVE.L	dat_SampleChannelMask,D0
	CMP.L	#EXE8_MARK0,D0
	BNE.S	.r
	MOVE.L	dat_SampleChannelMask+4,D0
	CMP.L	#EXE8_MARK1,D0
	BNE.S	.r
	MOVE.L	#EXE8_LEN,exe8_Skip
.r:	MOVEM.L	(A7)+,D0/A1
	RTS

; hook pt_FileSeekPos
pt_Exe8SeekAdd:
	CMP.L	#-1,D3			; from start only
	BNE.S	.r
	ADD.L	exe8_Skip,D2
.r:	RTS

; save exe: the player knows 8 ch -> z=0 refused
pt_ExeWide41:
	TST.B	wide_On
	BEQ.S	.r
	LEA	exe_MsgWide(PC),A0
	JSR	pt_ChnMsg41
	TST.B	wide_On
.r:	RTS

; unpack buffer back (also at exit)
pt_Exe8Free:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVE.L	exe8_Buf,D0
	BEQ.S	.r
	CLR.L	exe8_Buf
	MOVEA.L	D0,A1
	MOVE.L	#EXE8_LEN,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-210,A6)		; FreeMem
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

; a0 = packed, a1 = out, a2 = out end; bits msb first, 0 = literal,
; 1 = match: gamma(len-1), gamma(ofs>>8 +1), ofs low byte (ofs+1 back)
pt_Exe8Unpack:
	MOVEQ	#-128,D6		; empty bit byte
.l:	CMPA.L	A2,A1
	BCC.S	.x
	BSR.S	.bit
	BCS.S	.m
	MOVE.B	(A0)+,(A1)+
	BRA.S	.l
.m:	BSR.S	.gam
	MOVE.W	D0,D2			; length - 1
	BSR.S	.gam
	SUBQ.W	#1,D0
	LSL.W	#8,D0
	MOVE.B	(A0)+,D0
	MOVEA.L	A1,A3
	SUBA.W	D0,A3
	SUBQ.L	#1,A3
.c:	MOVE.B	(A3)+,(A1)+
	DBF	D2,.c
	BRA.S	.l
.x:	RTS
.gam:	MOVEQ	#0,D1			; elias gamma -> d0
.z:	BSR.S	.bit
	BCS.S	.o
	ADDQ.W	#1,D1
	BRA.S	.z
.o:	MOVEQ	#1,D0
	BRA.S	.n
.b:	BSR.S	.bit
	ADDX.W	D0,D0
.n:	DBF	D1,.b
	RTS
.bit:	ADD.B	D6,D6			; c = next bit
	BNE.S	.br
	MOVE.B	(A0)+,D6
	ADDX.B	D6,D6
.br:	RTS

exe8_Skip:	DC.L	$00001594
exe8_Buf:	DC.L	0
exe_MsgWide:	DC.B	"EXE: MAX 8 CHANNELS",0
	EVEN

	CNOP	0,4
exe8_Stub:
	INCBIN	"src/data/bin/exe8_stub.lz"
	CNOP	0,4
