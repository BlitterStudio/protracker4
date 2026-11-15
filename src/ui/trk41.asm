; track count: 8ch song shows tracks 1..n, the slots after them stay empty

TRK_Y0		EQU	140		; first panel row of the slots
TRK_ROWS	EQU	114
TRK_LASTB	EQU	77		; last byte of the slots

; -> d0.w = tracks in use (4 in 4ch)
pt_TrkN41:
	MOVEQ	#4,D0
	BTST	#5,dat_ModeFlags
	BNE.S	.r
	MOVE.B	trk_Show,D0
	BEQ.S	.8
	CMP.B	#8,D0
	BLS.S	.r
.8:	MOVEQ	#8,D0
.r:	RTS

;--- mode and load hooks
pt_Trk4Mode41:
	MOVE.W	#4,dat_RpNumChannels
	MOVE.B	#4,trk_Show
	RTS

pt_Trk8Mode41:
	MOVE.W	#8,dat_RpNumChannels
	MOVE.B	#8,trk_Show
	JMP	pt_WideShow41		; wide module: tracks of the view

; start of pt_InitNewModule
pt_TrkNew41:
	CLR.B	dat_KeyCode
	TST.B	wide_Pend		; wide load: keep
	BNE.S	.k
	JSR	pt_WideOff		; clear, pattern max: wide mode ends
.k:
	MOVE.B	#8,trk_Show
	BTST	#5,dat_ModeFlags
	BEQ.S	.r
	MOVE.B	#4,trk_Show
.r:	RTS

;--- backdrop
; d0 = n: slots n..8 plain panel, box edge of slot n-1 stays
pt_TrkHide41:
	CMP.W	#8,D0
	BHS.S	.r
	MOVEM.L	D0-D3/A0-A3,-(A7)
	MULU	#9,D0
	ADDQ.W	#5,D0			; byte of the first hidden pixel col - 3
	LEA	SECSTRT_2+TRK_Y0*80,A0
	LEA	chip_ScreenBitplanes+TRK_Y0*80,A1
	ADDA.W	D0,A0
	ADDA.W	D0,A1
	MOVEQ	#TRK_LASTB-1,D2
	SUB.W	D0,D2			; bytes after the first
	MOVE.W	#TRK_ROWS-1,D3
.row:	AND.B	#$e0,(A0)
	OR.B	#$1f,(A1)
	LEA	1(A0),A2
	LEA	1(A1),A3
	MOVE.W	D2,D1
.l:	CLR.B	(A2)+
	ST	(A3)+
	DBF	D1,.l
	LEA	80(A0),A0
	LEA	80(A1),A1
	DBF	D3,.row
	MOVEM.L	(A7)+,D0-D3/A0-A3
.r:	RTS

; d0 = n: pattern text of the hidden slots away
pt_TrkClrText41:
	CMP.W	#8,D0
	BHS.S	.r
	MOVEM.L	D0-D3/A0-A1,-(A7)
	MULU	#9,D0
	ADDQ.W	#5,D0
	MOVEA.L	dat_ScreenBuf2Ptr,A0
	LEA	139*80(A0),A0
	ADDA.W	D0,A0
	MOVEQ	#TRK_LASTB,D2
	SUB.W	D0,D2			; bytes - 1
	MOVE.W	#722-139-1,D3
.row:	MOVEA.L	A0,A1
	MOVE.W	D2,D1
.l:	CLR.B	(A1)+
	DBF	D1,.l
	LEA	80(A0),A0
	DBF	D3,.row
	MOVEM.L	(A7)+,D0-D3/A0-A1
.r:	RTS

; hook: end of pt_CheckModuleTypeWrap, replaces freeing the undo buf
pt_TrkWrapEnd41:
	MOVEQ	#0,D0
	JSR	pt_FreeUndoBuf
	JSR	pt_WBarGfx41		; the image painted over the slider's lower half
	TST.W	dat_SamplerActive
	BNE.S	.r
	BTST	#5,dat_ModeFlags
	BNE.S	.b
	MOVEM.L	D0-D1,-(A7)
	BSR.W	pt_TrkN41
	MOVE.B	D0,trk_Drawn
	BSR.W	pt_TrkHide41
	MOVEM.L	(A7)+,D0-D1
.b:	JSR	pt_WBarChk41		; wide view: slider over the heads
.r:	RTS

; hook: pt_PatViewDrawAll before the redraw: backdrop follows the count
pt_TrkSync41:
	TST.W	dat_SamplerActive
	BNE.S	.r
	BTST	#5,dat_ModeFlags
	BNE.S	.r
	MOVEM.L	D0-D7/A0-A6,-(A7)
	BSR.W	pt_TrkN41
	MOVEQ	#0,D1
	MOVE.B	trk_Drawn,D1
	BNE.S	.d
	MOVEQ	#8,D1
.d:	CMP.W	D1,D0
	BEQ.S	.o
	BHI.S	.grow
	MOVE.B	D0,trk_Drawn
	BSR.W	pt_TrkHide41
	BSR.W	pt_TrkClrText41
	BRA.S	.o
.grow:	LEA	dat_IMPFormatData2,A0
	JSR	pt_CheckModuleTypeWrap	; backdrop again, hides via the hook
	MOVE.W	#1,dat_KeyRepeatDelay
	JSR	pt_AudioChannelUpdate
.o:	MOVEM.L	(A7)+,D0-D7/A0-A6
.r:	JMP	pt_ClearDataRegs

;--- pattern view
; hook: cells per row -> d7 (dbf count)
pt_TrkCells41:
	MOVE.L	D0,-(A7)
	BSR.W	pt_TrkN41
	MOVE.W	D0,D7
	SUBQ.W	#1,D7
	MOVE.L	(A7)+,D0
	RTS

; hook: end of a row, skip the cells of the hidden tracks
pt_TrkRowEnd41:
	ADDI.W	#$0233,dat_TextBytePos
	BSR.W	pt_TrkN41
	NEG.W	D0
	ADD.W	dat_RpNumChannels,D0
	BLE.S	.r
	MOVE.W	D0,D1
	LSL.W	#2,D1
	ADDA.W	D1,A6
	MULU	#9,D0
	ADD.W	D0,dat_TextBytePos
.r:	RTS

; hook: channel loop of the track headers, d0 is the channel
pt_TrkCnt41:
	MOVE.L	D0,-(A7)
	BSR.W	pt_TrkN41
	MOVE.W	D0,D7
	SUBQ.W	#1,D7
	MOVE.L	(A7)+,D0
	RTS

;--- cursor
; flags like cmpi #6*n,dat_CursorColumn
pt_TrkCurR41:
	MOVEM.L	D0-D1,-(A7)
	BSR.W	pt_TrkN41
	MULU	#6,D0
	MOVE.W	dat_CursorColumn,D1
	CMP.W	D0,D1
	MOVEM.L	(A7)+,D0-D1
	RTS

pt_TrkCurL41:
	MOVE.L	D0,-(A7)
	BSR.W	pt_TrkN41
	MULU	#6,D0
	SUBQ.W	#1,D0
	MOVE.W	D0,dat_CursorColumn
	MOVE.L	(A7)+,D0
	RTS

; tab: flags like cmp.w dat_RpNumChannels,d0
pt_TrkCmpN41:
	MOVEM.L	D0-D1,-(A7)
	MOVE.W	D0,D1
	BSR.W	pt_TrkN41
	CMP.W	D0,D1
	MOVEM.L	(A7)+,D0-D1
	RTS

; shift tab: d0 = last track
pt_TrkLast41:
	BSR.W	pt_TrkN41
	SUBQ.W	#1,D0
	RTS

;--- mouse: pattern column and header ids of a hidden track -> d2 = 0
; instead of JSR pt_HandleUIButton in pt_InputPatternArea
pt_TrkHit41:
	JSR	pt_WBarHit41		; wide view slider: done, no button
	BEQ.S	.h
	MOVEQ	#0,D2
	RTS
.h:	BSR.S	pt_TrkHeadHit41
	BEQ.S	.ui
	JSR	pt_HandleUIButton
.ui:	MOVEM.L	D0-D1,-(A7)
	MOVE.W	D2,D0
	SUB.W	#$29,D0
	BCS.S	.r
	CMP.W	#8,D0
	BCS.S	.t
	SUB.W	#$31-$29,D0
	BCS.S	.r
	CMP.W	#8,D0
	BCC.S	.r
.t:	MOVE.W	D0,D1
	BSR.W	pt_TrkN41
	CMP.W	D0,D1
	BCS.S	.r
	MOVEQ	#0,D2
.r:	MOVEM.L	(A7)+,D0-D1
	TST.W	D2
	RTS

; 4ch screen: the slider of a wide module, else the button under the mouse
pt_TrkHit4_41:
	JSR	pt_WBarHit41
	BEQ.S	.h
	MOVEQ	#0,D2
	RTS
.h:	BSR.S	pt_TrkHeadHit41
	BEQ.S	.r
	JMP	pt_HandleUIButton
.r:	RTS

; wide module, native view: the whole head band (rows 140-148, track
; width) mutes -> z=1, d2 = head id; else z=0, d0/d1 kept
pt_TrkHeadHit41:
	JSR	pt_WideNat41
	BEQ.S	.no
	CMP.W	#140,D1
	BLT.S	.no
	CMP.W	#148,D1
	BGT.S	.no
	MOVEM.L	D0-D1,-(A7)
	BSR.W	pt_TrkN41
	MOVE.W	D0,D1			; slots
	MOVE.L	(A7),D0
	AND.L	#$ffff,D0
	SUB.W	#46,D0
	BMI.S	.n
	CMP.W	#4,D1
	BNE.S	.8
	DIVU	#144,D0
	BRA.S	.s
.8:	DIVU	#72,D0
.s:	CMP.W	D1,D0
	BHS.S	.n
	MOVE.W	D0,D2
	ADD.W	#$31,D2
	MOVEM.L	(A7)+,D0-D1
	ORI	#4,CCR			; z=1
	RTS
.n:	MOVEM.L	(A7)+,D0-D1
.no:	ANDI	#$fb,CCR		; z=0
	RTS

;--- setup: the name of CHANNELS switches 4/8 ch mode as before, the
; arrows count; hook: start of pt_BtnSetupChannels, replaces
; WaitMouseRelease / LEA a0
pt_TrkChanBtn41:
	JSR	pt_WaitMouseRelease
	LEA	dat_12E1,A0
	RTS

; setup arrows of CHANNELS
pt_ChnUp41:
	MOVEQ	#1,D2
	BRA.W	pt_ChnStep41
pt_ChnDn41:
	MOVEQ	#-1,D2
	BRA.W	pt_ChnStep41

; d0 = first, d1 = last + 1 (tracks, 0 based) -> z: empty in every
; pattern of the buffer, else d2 = the track
pt_TrkEmpty41:
	MOVEM.L	D3-D7/A0,-(A7)
	MOVE.L	dat_SampleEditCfg,D7
	SUB.L	#mod_patterns,D7
	MOVEQ	#11,D3
	LSR.L	D3,D7
	MOVEQ	#0,D3
	SUBQ.W	#1,D7
	BMI.S	.x
	MOVEA.L	dat_ModulePtr,A0
	LEA	mod_patterns(A0),A0
.p:	MOVEQ	#63,D6
.r:	MOVE.W	D0,D5
.t:	MOVE.W	D5,D4
	LSL.W	#2,D4
	TST.L	(A0,D4.W)
	BNE.S	.f
	ADDQ.W	#1,D5
	CMP.W	D1,D5
	BCS.S	.t
	LEA	32(A0),A0
	DBF	D6,.r
	DBF	D7,.p
	BRA.S	.x
.f:	MOVE.W	D5,D2
	MOVEQ	#1,D3
.x:	TST.W	D3
	MOVEM.L	(A7)+,D3-D7/A0
	RTS

; setup text of CHANNELS in 8ch: n<8 -> a0 + d0 = "nCHN", ne
pt_TrkChanText41:
	MOVEQ	#0,D1
	MOVE.B	trk_Show,D1
	BEQ.S	.n
	CMP.B	#8,D1
	BCC.S	.n
	LEA	trk_ChanTab-4,A0
	SUBQ.W	#1,D1
	LSL.W	#2,D1
	ADDA.W	D1,A0
	MOVEQ	#4,D0
	MOVEQ	#1,D1
	RTS
.n:	MOVEQ	#0,D1
	RTS
trk_ChanTab:	DC.B	"1CHN2CHN3CHN4CHN5CHN6CHN7CHN"
	EVEN

; data in hidden tracks (paste from a wider song): show them, they are
; saved; never drop notes silently
pt_TrkKeep41:
	MOVEM.L	D0-D2/A0,-(A7)
	BSR.W	pt_TrkN41
	MOVE.W	D0,D2			; n
	MOVEQ	#7,D0
.l:	CMP.W	D2,D0
	BCS.S	.r
	MOVE.W	D0,D1
	ADDQ.W	#1,D1
	MOVEM.L	D0/D2,-(A7)
	BSR.W	pt_TrkEmpty41
	MOVEM.L	(A7)+,D0/D2
	BNE.S	.f
	SUBQ.W	#1,D0
	BRA.S	.l
.f:	ADDQ.W	#1,D0
	MOVE.B	D0,trk_Show
	LEA	trk_MsgK(PC),A0
	JSR	pt_StatusLater41
	JSR	pt_PatViewDrawAll
.r:	MOVEM.L	(A7)+,D0-D2/A0
	RTS
trk_MsgK:	DC.B	"HIDDEN TRACKS HAD DATA!",0
	EVEN

; after a load: cursor on a shown track
pt_TrkClamp41:
	MOVEM.L	D0-D1,-(A7)
	BSR.W	pt_TrkN41
	MULU	#6,D0
.l:	CMP.W	dat_CursorColumn,D0
	BHI.S	.r
	SUBQ.W	#6,dat_CursorColumn
	BRA.S	.l
.r:	MOVEM.L	(A7)+,D0-D1
	RTS

;--- save: n tracks of the 8 -> id and packed rows
; hook: pt_WideSaveId (a0 = module)
pt_TrkSaveId41:
	SF	trk_Pack
	BTST	#5,dat_ModeFlags
	BNE.S	.r
	BSR.W	pt_TrkKeep41
	BSR.W	pt_TrkN41
	CMP.W	#8,D0
	BCC.S	.r
	ST	trk_Pack
	MOVE.L	#'M.K.',mod_id(A0)
	CMP.W	#4,D0
	BNE.S	.n
	CMPI.W	#$40,dat_NumSamples	; patterns, as the 4ch save
	BCS.S	.r
	MOVE.L	#'M!K!',mod_id(A0)
	BRA.S	.r
.n:	MOVE.L	#'0CHN',mod_id(A0)
	ADD.B	D0,mod_id(A0)
.r:	RTS

; hook: header and pattern write of the module save (replaces JSR
; pt_WriteFileData / BNE.S); error: on to the close
pt_TrkWrite41:
	TST.B	trk_Pack
	BNE.S	.pk
	JSR	pt_WriteFileData
	JSR	pt_WideSaveFree		; wide block out, memory back
	TST.L	D0
	BNE.S	.e
	RTS
.e:	ADDQ.L	#4,A7
	JMP	pt_CheckCloseAndBranch
.pk:	MOVEM.L	D1-D6/A0-A5,-(A7)
	MOVEA.L	dat_ModulePtr,A5
	MOVE.L	A5,dat_FileWriteAddr
	MOVE.L	#mod_patterns,dat_FileWriteSize
	JSR	pt_WriteFileData
	BNE.S	.pe
	BSR.W	pt_TrkN41
	MOVE.W	D0,D5			; n
	MOVEQ	#8,D6
	SUB.W	D5,D6
	LSL.W	#2,D6			; src bytes skipped per row
	MOVEQ	#0,D4
	MOVE.W	dat_NumSamples,D4
	LEA	mod_patterns(A5),A5
	JSR	pt_FmtBufGet
	BEQ.S	.pe
.p:	MOVEA.L	fmt_Buf,A1
	MOVE.L	A1,dat_FileWriteAddr
	MOVEQ	#63,D3
.row:	MOVE.W	D5,D2
	SUBQ.W	#1,D2
.c:	MOVE.L	(A5)+,(A1)+
	DBF	D2,.c
	ADDA.W	D6,A5
	DBF	D3,.row
	MOVE.W	D5,D0
	LSL.W	#8,D0
	MOVE.L	D0,dat_FileWriteSize
	JSR	pt_WriteFileData
	BNE.S	.pf
	DBF	D4,.p
	JSR	pt_FmtBufFree
	MOVEM.L	(A7)+,D1-D6/A0-A5
	MOVEQ	#0,D0
	RTS
.pf:	JSR	pt_FmtBufFree
.pe:	MOVEM.L	(A7)+,D1-D6/A0-A5
	ADDQ.L	#4,A7
	JMP	pt_CheckCloseAndBranch
