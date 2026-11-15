; module footer: 'PT41', version, flags as the last 8 bytes of a save
; written only if the module uses 4.1 extras, plain mods stay as before

FTR_VER		EQU	$0412
FTR_FX8		EQU	1		; 8xy sub-effects in the patterns
FTR_SMX		EQU	2		; block PT4X written
FTR_DYN		EQU	4		; dyn envelope written
FTR_SUB		EQU	%11011110	; x of 8xy with an action: 1-4, 6, 7

; hook: pattern write of the module save; dyn marker reset first
pt_FtrHead41:
	CLR.L	dat_0EE3		; set by the save when an envelope goes out
	JMP	pt_TrkWrite41

; hook: after sample 31 (d7 = file) -> block PT4X, then the footer
pt_FtrTail41:
	JSR	pt_SmxWrite
	BNE.S	.r
	TST.W	dat_FileSizeMode	; packed: no footer
	BNE.S	.ok
	TST.L	dat_XPKWriteActive
	BNE.S	.ok
	MOVEM.L	D1-D6/A0-A6,-(A7)
	BSR.S	pt_FtrFlags41
	BEQ.S	.no
	LEA	ftr_Buf,A0
	MOVE.L	#'PT41',(A0)
	MOVE.W	#FTR_VER,4(A0)
	MOVE.W	D0,6(A0)
	MOVE.L	A0,dat_FileWriteAddr
	MOVEQ	#8,D0
	MOVE.L	D0,dat_FileWriteSize
	JSR	pt_WriteFileData	; z=1 ok
.no:	MOVEM.L	(A7)+,D1-D6/A0-A6
	RTS
.ok:	MOVEQ	#0,D0
.r:	RTS

; -> d0.w footer flags, z=1 none (the saved cells, not the hidden ones)
pt_FtrFlags41:
	MOVEQ	#0,D5
	JSR	pt_SmxCount
	BEQ.S	.nx
	MOVEQ	#FTR_SMX,D5
.nx:	TST.L	dat_0EE3
	BEQ.S	.sc
	OR.W	#FTR_DYN,D5
.sc:	MOVEA.L	dat_ModulePtr,A0
	LEA	mod_positions(A0),A1
	MOVEQ	#0,D3
	MOVEQ	#127,D0
.pm:	MOVE.B	(A1)+,D4
	CMP.B	D3,D4
	BLS.S	.pm2
	MOVE.B	D4,D3
.pm2:	DBF	D0,.pm
	ADDQ.L	#1,D3
	LSL.L	#6,D3			; rows
	SUBQ.L	#1,D3
	LEA	mod_patterns(A0),A0
	MOVEQ	#4,D1			; cells per row
	MOVEQ	#16,D2			; row bytes
	TST.B	wide_On
	BEQ.S	.nw
	MOVEA.L	wide_Pat,A0
	MOVE.W	wide_Ch,D1
	MOVE.L	#WIDE_ROW,D2
	BRA.S	.go
.nw:	BTST	#5,dat_ModeFlags
	BNE.S	.go
	MOVEQ	#32,D2
	JSR	pt_TrkN41		; 8ch: tracks saved
	MOVE.W	D0,D1
.go:	SUBQ.W	#1,D1
	MOVE.L	#FTR_SUB,D6
.row:	MOVEA.L	A0,A1
	MOVE.W	D1,D0
.cel:	MOVEQ	#$0f,D4
	AND.B	2(A1),D4
	CMP.B	#8,D4
	BNE.S	.nc
	MOVEQ	#$0f,D4
	AND.B	3(A1),D4		; y=0: colour
	BEQ.S	.nc
	MOVE.B	3(A1),D4
	LSR.B	#4,D4
	BTST	D4,D6
	BEQ.S	.nc
	OR.W	#FTR_FX8,D5
	BRA.S	.e
.nc:	ADDQ.L	#4,A1
	DBF	D0,.cel
	ADDA.L	D2,A0
	SUBQ.L	#1,D3
	BPL.S	.row
.e:	MOVE.W	D5,D0
	RTS
