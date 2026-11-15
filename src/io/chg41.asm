; module changed: fingerprint after load, clear and save

; replaces the flag clears: new fingerprint on the next main loop pass
pt_ChgClear41:
	CLR.L	dat_SongChangedMagic
	ST	chg_Due
	RTS

; plain save written in full (packed: not known here, stays changed)
pt_ChgSaved41:
	TST.W	dat_FileSizeMode
	BNE.S	.r
	TST.L	dat_XPKWriteActive
	BEQ.S	pt_ChgClear41
.r:	RTS

; main loop: take the fingerprint once a load, clear or save is over
pt_ChgPoll41:
	TST.B	chg_Due
	BEQ.S	.r
	SF	chg_Due
	MOVEM.L	D0-D1,-(A7)
	BSR.S	pt_ChgSum41
	MOVEM.L	D0-D1,chg_Base
	ST	chg_Valid
	MOVEM.L	(A7)+,D0-D1
.r:	RTS

; before the "changed?" questions: other fingerprint counts as changed
pt_ChgSync41:
	TST.B	chg_Valid
	BEQ.S	.r
	TST.B	chg_Due
	BNE.S	.r
	CMPI.L	#'CHG!',dat_SongChangedMagic
	BEQ.S	.r
	MOVEM.L	D0-D1,-(A7)
	BSR.S	pt_ChgSum41
	CMP.L	chg_Base,D0
	BNE.S	.c
	CMP.L	chg_Base+4,D1
	BEQ.S	.x
.c:	MOVE.L	#'CHG!',dat_SongChangedMagic
.x:	MOVEM.L	(A7)+,D0-D1
.r:	RTS

; -> d0/d1 = sum, running sum (order counts)
pt_ChgSum41:
	MOVEM.L	D2-D7/A0-A2,-(A7)
	MOVE.W	smx_Swp,D7		; slot 31 back in place while summing
	BSR.W	pt_SmxUnswap
	MOVEQ	#0,D0
	MOVEQ	#0,D1
	MOVEA.L	dat_ModulePtr,A0	; header and all patterns
	MOVE.L	A0,D3
	BEQ.S	.nomod
	MOVE.L	dat_SampleEditCfg,D3
	BSR.W	.sum
	MOVEA.L	dat_ModulePtr,A1	; smp 1-31: as many bytes as saved
	LEA	12+30(A1),A1
	LEA	dat_ModulePtr+4,A2
	MOVEQ	#30,D6
.smp:	MOVEQ	#0,D3
	MOVE.W	(A1),D3
	ADD.L	D3,D3
	MOVE.L	124(A2),D2		; allocated
	CMP.L	D2,D3
	BLS.S	.sl
	MOVE.L	D2,D3
.sl:	MOVEA.L	(A2)+,A0
	MOVE.L	A0,D2
	BEQ.S	.sn
	BSR.W	.sum
.sn:	LEA	30(A1),A1
	DBF	D6,.smp
.nomod:	MOVE.L	wide_Pat,D2		; wide module: the real patterns
	BEQ.S	.nw
	MOVEA.L	D2,A0
	MOVE.L	wide_PatSize,D3
	BSR.W	.sum
.nw:	LEA	str_UnnamedSong,A0
	MOVEQ	#32,D3
	BSR.W	.sum
	LEA	str_UnnamedAuthor,A0
	MOVEQ	#32,D3
	BSR.W	.sum
	LEA	SECSTRT_4,A0		; dyn envelopes
	MOVE.L	#800,D3
	BSR.W	.sum
	ADD.L	dat_RpChunkedSamples,D0
	ADD.L	D0,D1
	MOVEQ	#0,D2			; shown tracks: saved as the id
	MOVE.B	trk_Show,D2
	ADD.L	D2,D0
	ADD.L	D0,D1
	MOVE.L	smx_Mem,D2		; table of samples 32-63
	BEQ.S	.done
	MOVEA.L	D2,A2
	MOVEA.L	A2,A0
	MOVE.L	#SMX_PTR,D3		; headers
	BSR.W	.sum
	LEA	SMX_FLG(A2),A0		; dyn flags, iff ofs
	MOVE.L	#SMX_SIZE-SMX_FLG,D3
	BSR.W	.sum
	MOVEA.L	A2,A1
	MOVEQ	#SMX_N-1,D6
.ent:	MOVEQ	#0,D3
	MOVE.W	22(A1),D3
	ADD.L	D3,D3
	MOVE.L	SMX_LEN(A2),D2
	CMP.L	D2,D3
	BLS.S	.el
	MOVE.L	D2,D3
.el:	MOVEA.L	SMX_PTR(A2),A0
	MOVE.L	A0,D2
	BEQ.S	.en
	BSR.W	.sum
.en:	LEA	30(A1),A1
	ADDQ.L	#4,A2
	DBF	D6,.ent
.done:	TST.W	D7
	BEQ.S	.x
	MOVE.L	D0,-(A7)
	MOVE.W	D7,D0
	BSR.W	pt_SmxSwap
	MOVE.L	(A7)+,D0
.x:	MOVEM.L	(A7)+,D2-D7/A0-A2
	RTS

; a0 = data (even) d3 = len (even) -> d0/d1 updated
.sum:	ADD.L	D3,D0
	ADD.L	D0,D1
	MOVE.L	D3,D4
	LSR.L	#2,D4
	BEQ.S	.t
	SUBQ.L	#1,D4
	MOVE.L	D4,D5
	SWAP	D5
.l:	ADD.L	(A0)+,D0
	ADD.L	D0,D1
	DBF	D4,.l
	DBF	D5,.l
.t:	BTST	#1,D3
	BEQ.S	.r
	MOVEQ	#0,D4
	MOVE.W	(A0)+,D4
	ADD.L	D4,D0
	ADD.L	D0,D1
.r:	RTS
