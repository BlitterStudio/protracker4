; rtg mirror: copper list -> chunky -> card (own proc, 68020+)
; not emulated: attached spr, fmode spr
RTG_ROWS	EQU	256
RTG_MAXOUT	EQU	768		; output lines (taller pattern view)
RTG_PATTOP	EQU	150		; first line of the pattern section
RTG_PATCUR	EQU	198		; text line of the cursor row (classic)
RTG_PATEND	EQU	254		; bottom frame of the pattern section (2 lines)
RTG_KMAX	EQU	50		; extra rows at most (whole pattern in view)
RTG_GEOSTILL	EQU	6		; frames a new size must stand before it is taken
RTG_BAND	EQU	32		; lines a layer lock may cover
RTG_TILE	EQU	8		; lines of a dirty tile (a led segment is 4 rows)
RTG_RECTS	EQU	64		; rects a band may need (RTG_BAND/RTG_TILE tiles, 16 runs each)
	IFNE	RTG_TILE-8
	FAIL	"pt_RtgPlan shifts by 3"
	ENDC
	IFNE	RTG_BAND/RTG_TILE-4
	FAIL	"rtg_PlanU holds 4 tiles"
	ENDC
RTG_BANKS	EQU	30
RTG_SEGS	EQU	32
RTG_WINBUF	EQU	4096*2+4096*3	; x table (words) + rgb row, win width up to 4096
RTG_ROWCOPY	EQU	1280		; line buffer offset of the plane copy
RTG_COPCOPY	EQU	RTG_ROWCOPY+4*80	; copper list copy, one chip read per frame
RTG_COPMAX	EQU	4000
RTG_STRIPE	EQU	8		; lines checked per frame without a reason
RTG_HOT	EQU	10		; frames a changed line stays read
RTG_FULLN	EQU	10		; frames all lines read after input
RTG_LINEBUF	EQU	RTG_COPCOPY+4*RTG_COPMAX
SA_Width_	EQU	$80000023
SA_Height_	EQU	$80000024
SA_Depth_	EQU	$80000025
SA_Title_	EQU	$80000028
SA_Type_	EQU	$8000002d
SA_DisplayID_	EQU	$80000032
SA_ShowTitle_	EQU	$80000036
SA_Quiet_	EQU	$80000038
WA_Left_	EQU	$80000064
WA_Top_		EQU	$80000065
WA_Width_	EQU	$80000066
WA_Height_	EQU	$80000067
WA_CustomScreen_	EQU	$80000070
WA_Backdrop_	EQU	$80000085
WA_NoCareRefresh_	EQU	$80000087
WA_Borderless_	EQU	$80000088
WA_Activate_	EQU	$80000089
WA_RMBTrap_	EQU	$8000008a
WA_SimpleRefresh_	EQU	$8000008c
; wb window tags
WA_Title_	EQU	$8000006e
WA_IDCMP_	EQU	$8000006a
WA_CloseGadget_	EQU	$80000084
WA_MinWidth_	EQU	$80000072
WA_MinHeight_	EQU	$80000073
WA_MaxWidth_	EQU	$80000074
WA_MaxHeight_	EQU	$80000075
WA_InnerWidth_	EQU	$80000076
WA_InnerHeight_	EQU	$80000077
WA_PubScreen_	EQU	$80000079
WA_SizeGadget_	EQU	$80000081
WA_DragBar_	EQU	$80000082
WA_DepthGadget_	EQU	$80000083
WA_SmartRefresh_	EQU	$8000008d
WA_SizeBBottom_	EQU	$8000008f
WA_AutoAdjust_	EQU	$80000090

;--- pt task
; first poll: check wish, start proc once
pt_RtgPoll:
	TST.B	rtg_Tried
	BNE.S	.r
	ST	rtg_Tried
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVEA.L	ABSEXECBASE.W,A6
	BTST	#1,(297,A6)		; AttnFlags AFB_68020
	BEQ.S	.no
	TST.B	rtg_Want		; tooltype rtg
	BNE.S	.go
	MOVEA.L	dat_DosLibBase,A6
	MOVE.L	#rtg_FileName,D1
	MOVEQ	#-2,D2
	JSR	(-84,A6)		; Lock
	TST.L	D0
	BEQ.S	.auto
	MOVE.L	D0,D1
	JSR	(-90,A6)		; UnLock
	ST	rtg_Want
	BRA.S	.go
.auto:	JSR	pt_AutoRtg		; first run + matching card mode -> mirror on
	BEQ.S	.no
.go:	CLR.B	rtg_ProcState
	MOVEA.L	dat_DosLibBase,A6
	MOVE.L	#rtg_ProcTags,D1
	JSR	(-498,A6)		; CreateNewProc
	MOVE.L	D0,rtg_Proc
.no:	MOVEM.L	(A7)+,D0-D7/A0-A6
.r:	RTS

; stop proc via ctrl-c, wait 3 s max
pt_RtgClose:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.B	main_Pri		; own task back to pri 0 (cli: the
	BEQ.S	.p0			; shell's process)
	SF	main_Pri
	MOVEA.L	ABSEXECBASE.W,A6
	MOVEA.L	276(A6),A1		; ThisTask
	MOVE.B	main_PriOrg,D0		;41 back to the priority it came with
	EXT.W	D0
	EXT.L	D0
	JSR	(-300,A6)		; SetTaskPri
.p0:
	MOVE.L	rtg_Proc,D0
	BEQ.S	.r
	DK	'['
	CMP.B	#3,rtg_ProcState
	BEQ.S	.gone
	MOVEA.L	D0,A1
	MOVE.L	#$1000,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-324,A6)		; Signal
	MOVEA.L	dat_DosLibBase,A6
	MOVE.W	#150,D7
.w:	CMP.B	#3,rtg_ProcState
	BEQ.S	.gone
	MOVEQ	#1,D1
	JSR	(-198,A6)		; Delay
	DBF	D7,.w
	DK	'?'			; mirror did not end in 3 s
.gone:	DK	']'
	CLR.L	rtg_Proc
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

;--- rtg process
pt_RtgProc:
	MOVEA.L	ABSEXECBASE.W,A6
	SUBA.L	A1,A1
	JSR	(-294,A6)		; FindTask(0)
	MOVEA.L	D0,A0
	MOVE.L	#-1,(184,A0)		; no dos requesters from mirror proc
	IFD	DEBUGTRAP
	MOVE.L	#dbg_TrapHandler,(50,A0)
	ENDC
	BSR.W	pt_RtgSetup
	TST.L	D0
	BNE.W	.err
	BSR.W	pt_RtgVblOn
	MOVE.B	#1,rtg_ProcState	; pri 1 in the window too: pt passes are
.loop:	MOVE.L	rtg_Vbl,D1		; long, pacing leaves pt half the cpu
	SUB.L	rtg_FrameT0,D1		; vbl spent on the last frame
	CMP.L	#50,D1
	BLS.S	.spent
	MOVEQ	#50,D1
.spent:	MOVEQ	#1,D7
	ADD.B	rtg_WaitAdj,D7
	SUB.W	D1,D7			; rest of the period
	CMP.W	D1,D7			; slow cpu: mirror takes half at most
	BGE.S	.rest
	MOVE.W	D1,D7
.rest:	TST.W	D7
	BGT.S	.more
	MOVEQ	#1,D7			; always one vbl for everybody else
.more:	SUBQ.W	#1,D7
	MOVEA.L	ABSEXECBASE.W,A6
.tof:	MOVE.L	rtg_VblMask,D1		; own vbl signal: sure to sleep, waittof
	BEQ.S	.gtof			; may poll the card
	MOVEQ	#0,D0
	JSR	(-306,A6)		; SetSignal: drop an old tick
	MOVE.L	rtg_VblMask,D0
	JSR	(-318,A6)		; Wait
	BRA.S	.tofn
.gtof:	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-270,A6)		; WaitTOF
	MOVEA.L	ABSEXECBASE.W,A6
.tofn:	DBF	D7,.tof
	MOVE.L	rtg_Vbl,rtg_FrameT0
	MOVEA.L	ABSEXECBASE.W,A6
	IFD	DEBUGAUTO
	MOVE.B	rtg_ProfN+29,D0		; test: priority set from outside
	BEQ.S	.npri
	CLR.B	rtg_ProfN+29
	EXT.W	D0
	EXT.L	D0
	MOVEA.L	276(A6),A1
	JSR	(-300,A6)		; SetTaskPri
.npri:
.pz:	TST.B	rtg_ProfN+30		; test photos: wait here, frame complete
	BEQ.S	.npz
	ST	rtg_ProfN+31		; ... acknowledged
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-270,A6)		; WaitTOF
	MOVEA.L	ABSEXECBASE.W,A6
	BRA.S	.pz
.npz:	SF	rtg_ProfN+31
	ENDC
	MOVEQ	#0,D0
	MOVEQ	#0,D1
	JSR	(-306,A6)		; SetSignal(0,0)
	BTST	#12,D0			; SIGBREAKB_CTRL_C
	BNE.W	.down
	TST.B	rtg_RunWin		; win size per frame
	BEQ.S	.fr
	BSR.W	pt_RtgWinGeom
	BSR.W	pt_RtgWinHold		; dragging/sizing: hands off the layers
	BNE.W	.loop
	BSR.W	pt_RtgDamage
	BSR.W	pt_RtgWinTitle
.fr:	MOVEA.L	dat_IntuiLibBase,A0	; our card scr in front: native
	MOVE.L	60(A0),D1		; picture unseen, no bpl dma
	TST.B	rtg_RunWin
	BEQ.S	.fs
	MOVEA.L	rtg_Window,A0
	CMP.L	46(A0),D1		; Window->WScreen
	BRA.S	.fc
.fs:	CMP.L	rtg_Screen,D1
.fc:	BNE.S	.fn
	MOVE.W	#$0100,DMACON		; chip reads 2x
	ST	rtg_BplOff
	BRA.S	.fd
.fn:	TST.B	rtg_BplOff		; native scr in front: dma back once
	BEQ.S	.fd
	SF	rtg_BplOff
	MOVE.W	#$8100,DMACON
.fd:
	IFD	DIAGWIN
	MOVE.L	dw_VblTot,-(A7)
	ENDC
	IFD	DEBUGAUTO
	BSR.W	pt_RtgTick
	MOVE.L	D0,-(A7)
	ENDC
	DK	'F'
	BSR.W	pt_RtgFrame
	DK	'f'
	IFD	DEBUGAUTO
	BSR.W	pt_RtgTick
	SUB.L	(A7)+,D0
	ADD.L	D0,rtg_Prof
	ENDC
	IFD	DIAGWIN
	MOVE.L	dw_VblTot,D0
	SUB.L	(A7)+,D0
	ADD.L	D0,dw_TFr
	MOVE.L	dw_VblTot,-(A7)
	ENDC
	TST.B	rtg_RunWin
	BEQ.S	.nwb
	BSR.W	pt_RtgWinBlit
.nwb:
	IFD	DEBUGAUTO
	BSR.W	pt_RtgTick
	MOVE.L	D0,-(A7)
	ENDC
	BSR.W	pt_RprBlit		; pattern area: card bitmap -> picture
	BSR.W	pt_RprVu		; vu bars over it
	IFD	DEBUGAUTO
	BSR.W	pt_RtgTick
	SUB.L	(A7)+,D0
	ADD.L	D0,rtg_Prof+12
	ENDC
	IFD	DEBUGAUTO
	ADDQ.L	#1,rtg_Prof+20		; profile: frames
	ENDC
.cnt:
	IFD	DIAGWIN
	MOVE.L	dw_VblTot,D0
	SUB.L	(A7)+,D0
	ADD.L	D0,dw_TBl
	ENDC
	ADDQ.L	#1,rtg_Frames
	BRA.W	.loop
.err:	MOVE.B	#2,rtg_ProcState
.down:	DK	'D'
	BSR.W	pt_RtgVblOff
	BSR.W	pt_RtgTeardown
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-132,A6)		; Forbid, exit race-free
	MOVE.B	#3,rtg_ProcState
	MOVEQ	#0,D0
	RTS

; profile tick: vbl * 313 + beam line -> d0 (64 us steps)
pt_RtgTick:
	MOVE.L	D1,-(A7)
.again:	MOVE.L	rtg_Vbl,D0
	MOVE.L	$dff004,D1		; VPOSR/VHPOSR
	CMP.L	rtg_Vbl,D0
	BNE.S	.again
	LSR.L	#8,D1
	AND.L	#$1ff,D1
	MULU	#313,D0
	ADD.L	D1,D0
	MOVE.L	(A7)+,D1
	RTS

; vertb server: frame clock of the mirror
pt_RtgVblSrv:
	ADDQ.L	#1,rtg_Vbl
	MOVE.L	rtg_VblMask,D0
	BEQ.S	.r
	MOVEA.L	rtg_VblTask,A1
	MOVE.L	A6,-(A7)
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-324,A6)		; Signal
	MOVEA.L	(A7)+,A6
.r:	MOVEQ	#0,D0
	RTS

pt_RtgVblOn:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVE.L	rtg_Vbl,rtg_FrameT0
	MOVEA.L	ABSEXECBASE.W,A6
	MOVE.L	276(A6),rtg_VblTask	; ThisTask
	MOVEQ	#-1,D0
	JSR	(-330,A6)		; AllocSignal
	MOVEQ	#0,D1
	TST.B	D0
	BMI.S	.ns
	BSET	D0,D1
.ns:	MOVE.L	D1,rtg_VblMask		; 0: no signal, then no wait either
	LEA	rtg_VblInt,A1
	MOVE.B	#2,8(A1)		; NT_INTERRUPT
	MOVE.B	#10,9(A1)		; pri 10: lower servers may be cut off
	MOVE.L	#rtg_ProcName,10(A1)
	MOVE.L	#pt_RtgVblSrv,18(A1)
	MOVEQ	#5,D0			; INTB_VERTB
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-168,A6)		; AddIntServer
	ST	rtg_VblUp
	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

pt_RtgVblOff:
	TST.B	rtg_VblUp
	BEQ.S	.r
	SF	rtg_VblUp
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	LEA	rtg_VblInt,A1
	MOVEQ	#5,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-174,A6)		; RemIntServer
	MOVE.L	rtg_VblMask,D1
	BEQ.S	.nf
	CLR.L	rtg_VblMask
	MOVEQ	#-1,D0
.b:	ADDQ.L	#1,D0
	LSR.L	#1,D1
	BCC.S	.b			; mask -> signal number
	JSR	(-336,A6)		; FreeSignal
.nf:
	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
.r:	RTS

; z=0: pointer on our window but off the picture (border, bar, gadgets)
pt_RtgOnFrame:
	MOVEM.L	D0-D3/A0-A1,-(A7)
	MOVEA.L	rtg_Window,A1
	MOVEA.L	46(A1),A0		; WScreen
	MOVE.W	18(A0),D0		; Screen->MouseX
	SUB.W	4(A1),D0		; window x
	BMI.S	.no
	CMP.W	8(A1),D0		; Width
	BGE.S	.no
	MOVE.W	16(A0),D1		; Screen->MouseY
	SUB.W	6(A1),D1
	BMI.S	.no
	CMP.W	10(A1),D1		; Height
	BGE.S	.no
	MOVEQ	#0,D2
	MOVE.B	54(A1),D2		; BorderLeft
	CMP.W	D2,D0
	BLT.S	.yes
	MOVE.W	8(A1),D2
	MOVEQ	#0,D3
	MOVE.B	56(A1),D3
	SUB.W	D3,D2			; Width - BorderRight
	CMP.W	D2,D0
	BGE.S	.yes
	MOVEQ	#0,D2
	MOVE.B	55(A1),D2		; BorderTop
	CMP.W	D2,D1
	BLT.S	.yes
	MOVE.W	10(A1),D2
	MOVE.B	57(A1),D3
	SUB.W	D3,D2			; Height - BorderBottom
	CMP.W	D2,D1
	BGE.S	.yes
.no:	MOVEM.L	(A7)+,D0-D3/A0-A1
	CMP.B	D0,D0			; z=1
	RTS
.yes:	MOVEM.L	(A7)+,D0-D3/A0-A1
	ANDI.B	#$fb,CCR		; z=0
	RTS

; z=0: lmb held (cia port or input events)
pt_RtgLmb:
	BTST	#6,CIAA_PRA
	BNE.S	.ev
	ANDI.B	#$fb,CCR		; pressed: z=0
	RTS
.ev:	TST.B	rtg_LmbEv
	RTS

; z=0: skip frame (window moving, lmb held off the picture = drag/size)
; z=1: draw; after a pause the whole window once more
pt_RtgWinHold:
	MOVEM.L	D0/A0,-(A7)
	MOVEA.L	rtg_Window,A0
	MOVE.L	4(A0),D0		; LeftEdge/TopEdge
	CMP.L	rtg_WinLastPos,D0
	BEQ.S	.still
	MOVE.L	D0,rtg_WinLastPos
	BRA.S	.hold
.still:	TST.B	rtg_SysDrag		; intuition drags or sizes us
	BNE.S	.hold
	BSR.W	pt_RtgLmb		; lmb down?
	BEQ.S	.free
	TST.B	rtg_InBlock		; ... off the picture
	BEQ.S	.free
	MOVEA.L	dat_IntuiLibBase,A0	; ... of our own window (border/title), not elsewhere
	MOVEA.L	52(A0),A0		; IntuitionBase->ActiveWindow
	CMPA.L	rtg_Window,A0
	BEQ.S	.hold
.free:	TST.B	rtg_WinHeld
	BEQ.S	.go
	SUBQ.B	#1,rtg_WinHeld
	BNE.S	.busy
	TST.B	rtg_HoldSize		; a move alone: layers kept the picture,
	BEQ.S	.go			; parts shown again come as damage
	SF	rtg_HoldSize
	BSR.W	pt_RtgWinRedraw
.go:	MOVEM.L	(A7)+,D0/A0
	CMP.B	D0,D0			; z=1
	RTS
.hold:	MOVE.B	#3,rtg_WinHeld
.busy:	MOVEM.L	(A7)+,D0/A0
	MOVEQ	#1,D0			; z=0
	RTS

; find card mode 640 x d0, depth 8; a6=gfxbase -> d0=id or -1
; card ids >= $00100000; p96 lacks DIPF_IS_FOREIGN -> no BestModeID
pt_RtgFindMode:
	MOVEM.L	D1-D7/A0-A1,-(A7)
	MOVE.L	D0,D6			; Hoehe
	MOVEQ	#-1,D7
.next:	MOVE.L	D7,D0
	JSR	(-732,A6)		; NextDisplayInfo
	MOVE.L	D0,D7
	CMP.L	#-1,D0
	BEQ.S	.out
	CMP.L	#$00100000,D7
	BLO.S	.next
	SUBA.L	A0,A0
	LEA	rtg_DimBuf,A1
	MOVEQ	#88,D0
	MOVE.L	#$80001000,D1		; DTAG_DIMS
	MOVE.L	D7,D2
	JSR	(-756,A6)		; GetDisplayInfoData
	TST.L	D0
	BEQ.S	.next
	LEA	rtg_DimBuf,A1
	CMP.W	#8,16(A1)		; MaxDepth
	BNE.S	.next
	MOVE.W	30(A1),D0		; Nominal.MaxX
	SUB.W	26(A1),D0
	CMP.W	#639,D0
	BNE.S	.next
	MOVE.W	32(A1),D0		; Nominal.MaxY
	SUB.W	28(A1),D0
	ADDQ.W	#1,D0
	CMP.W	D6,D0
	BNE.S	.next
.out:	MOVE.L	D7,D0
	MOVEM.L	(A7)+,D1-D7/A0-A1
	RTS

; mode d0 8 bit + 640 wide -> d1=height else 0, a6=gfxbase
pt_RtgModeH:
	MOVEM.L	D0/D2/A0-A1,-(A7)
	MOVE.L	D0,D2
	SUBA.L	A0,A0
	LEA	rtg_DimBuf,A1
	MOVEQ	#88,D0
	MOVE.L	#$80001000,D1		; DTAG_DIMS
	JSR	(-756,A6)		; GetDisplayInfoData
	MOVEQ	#0,D1
	TST.L	D0
	BEQ.S	.r
	LEA	rtg_DimBuf,A1
	CMP.W	#8,16(A1)		; MaxDepth
	BNE.S	.r
	MOVE.W	30(A1),D0
	SUB.W	26(A1),D0
	CMP.W	#639,D0
	BNE.S	.r
	MOVE.W	32(A1),D1
	SUB.W	28(A1),D1
	ADDQ.W	#1,D1
.r:	MOVEM.L	(A7)+,D0/D2/A0-A1
	RTS

; open scr/win/bufs -> d0=0 ok
pt_RtgSetup:
	MOVEM.L	D1-D7/A0-A6,-(A7)
	MOVE.B	rtg_WinMode,rtg_RunWin
	MOVE.B	#1,rtg_Step
	TST.L	x20_Base		; tables live in x20 area
	BEQ.W	.fail
	TST.B	rtg_RunWin		; wb window
	BEQ.S	.scr
	BSR.W	pt_RtgWinSetup
	TST.L	D0
	BEQ.W	.common
	SF	rtg_WinMode
	SF	rtg_RunWin		; no card on wb / no cybergraphics -> own screen
	ST	rtg_WinBad
.scr:
	; mode: 640x512 (line doubled) else 640x480 centered, setup choice first
	MOVEA.L	dat_GfxLibBase,A6
	MOVE.L	D0,-(A7)
	MOVE.W	#RTG_ROWS,D0		; classic until a mode says more
	BSR.W	pt_RtgSetOut
	MOVE.L	(A7)+,D0
	MOVE.L	rtg_UserMode,D0
	BEQ.S	.auto
	BSR.W	pt_RtgModeH		; d1 = height or 0
	CMP.W	#512,D1
	BEQ.W	.m512
	CMP.W	#480,D1
	BEQ.S	.m480
.auto:	MOVE.L	#512,D0
	BSR.W	pt_RtgFindMode
	CMP.L	#-1,D0
	BNE.W	.m512
	MOVE.L	#480,D0
	BSR.W	pt_RtgFindMode
	CMP.L	#-1,D0
	BEQ.W	.fail
.m480:	SF	rtg_Double		; 480 lines: classic height, centered
	MOVE.W	#480,rtg_ScrH
	MOVE.W	#(480-RTG_ROWS)/2,rtg_YOff
	BRA.S	.mode
.m512:	MOVE.W	#512,rtg_ScrH
	ST	rtg_Double
	CLR.W	rtg_YOff
	CMPI.B	#-1,rtg_Scale1x		; pixel 1:1: no doubling, 512 lines
	BNE.S	.mode
	SF	rtg_Double
	MOVE.L	D0,-(A7)
	MOVE.W	#512,D0
	BSR.W	pt_RtgSetOut
	MOVE.L	(A7)+,D0
.mode:	MOVE.L	D0,rtg_Mode
	MOVE.B	#2,rtg_Step
	LEA	rtg_ScrTags,A1
	MOVE.L	D0,4(A1)		; SA_DisplayID
	MOVEQ	#0,D0
	MOVE.W	rtg_ScrH,D0
	MOVE.L	D0,20(A1)		; SA_Height
	SUBA.L	A0,A0
	MOVEA.L	dat_IntuiLibBase,A6
	JSR	(-612,A6)		; OpenScreenTagList
	MOVE.L	D0,rtg_Screen
	BEQ.W	.fail
	MOVE.B	#3,rtg_Step
	LEA	rtg_WinTags,A1
	MOVE.L	D0,4(A1)		; WA_CustomScreen
	MOVEQ	#0,D0
	MOVE.W	rtg_ScrH,D0
	MOVE.L	D0,36(A1)		; WA_Height
	SUBA.L	A0,A0
	JSR	(-606,A6)		; OpenWindowTagList
	MOVE.L	D0,rtg_Window
	BEQ.W	.fail
.common:
	MOVEA.L	ABSEXECBASE.W,A6	; steady frames: last copper list, line states
	MOVE.L	#RTG_COPMAX*4,D0
	MOVEQ	#1,D1
	JSR	(-198,A6)		; AllocMem
	MOVE.L	D0,rtg_PrevCop
	MOVE.L	#RTG_ROWS*RTG_STSIZE,D0
	MOVEQ	#1,D1
	JSR	(-198,A6)
	MOVE.L	D0,rtg_RowSt
	MOVE.L	#RM_SIZE,D0		; renderer and steady buffers
	MOVE.L	#$10001,D1		; MEMF_PUBLIC|MEMF_CLEAR
	JSR	(-198,A6)
	MOVE.L	D0,rtg_Mem
	BNE.S	.mem
	ST	rpr_Fail		; no renderer, no steady frames
	MOVEQ	#0,D0
	MOVE.L	rtg_RowSt,D1
	BEQ.S	.mem
	MOVEA.L	D1,A1
	MOVE.L	#RTG_ROWS*RTG_STSIZE,D0
	JSR	(-210,A6)
	CLR.L	rtg_RowSt
.mem:	SF	rtg_StateOk
	TST.B	rtg_RunWin		; card screen: renderer bitmap now
	BNE.S	.cw
	BSR.W	pt_RprAlloc
.cw:	MOVE.B	#4,rtg_Step
	MOVEA.L	ABSEXECBASE.W,A6
	MOVEQ	#16,D0
	MOVE.L	#$10003,D1		; chip|clear: empty ptr
	JSR	(-198,A6)
	MOVE.L	D0,rtg_Blank
	BEQ.S	.nobl
	TST.B	rtg_RunWin		; window: wb ptr stays
	BNE.S	.nobl
	MOVEA.L	rtg_Window,A0
	MOVEA.L	D0,A1
	MOVEQ	#1,D0			; Hoehe
	MOVEQ	#16,D1			; Breite
	MOVEQ	#0,D2
	MOVEQ	#0,D3
	MOVEA.L	dat_IntuiLibBase,A6
	JSR	(-270,A6)		; SetPointer, hide intui ptr (pt draws its own)
.nobl:	MOVEA.L	ABSEXECBASE.W,A6
	MOVE.L	#RTG_LINEBUF,D0
	MOVEQ	#1,D1			; MEMF_PUBLIC
	JSR	(-198,A6)
	MOVE.L	D0,rtg_LineBuf
	BEQ.W	.fail
	MOVE.B	#5,rtg_Step
	; p2c table: byte -> 8 bytes 0/1 (msb first)
	X20LEA	X20_RTGP2C,A0
	MOVEQ	#0,D0
.t1:	MOVEQ	#7,D1
.t2:	MOVEQ	#0,D2
	BTST	D1,D0
	BEQ.S	.t3
	MOVEQ	#1,D2
.t3:	MOVE.B	D2,(A0)+
	DBF	D1,.t2
	ADDQ.B	#1,D0
	BNE.S	.t1
	BSR.W	pt_RtgPoolReset
	MOVE.B	#6,rtg_Step
	MOVEQ	#0,D0
	MOVEM.L	(A7)+,D1-D7/A0-A6
	RTS
.fail:	MOVEQ	#-1,D0
	MOVEM.L	(A7)+,D1-D7/A0-A6
	RTS

pt_RtgTeardown:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	IFD	DIAGWIN
	BSR.W	dw_Stop
	ENDC
	BSR.W	pt_RtgInUnhook		; input direct to pt again
	SF	rtg_InBlock
	BSR.W	pt_RprFree
	SF	rtg_Wide
	SF	trk_On
	SF	rwd_On
	BSR.W	pt_RwdFree
	SF	rtg_StateOk
	MOVEA.L	ABSEXECBASE.W,A6
	MOVE.L	rtg_PrevCop,D0
	BEQ.S	.npc
	MOVEA.L	D0,A1
	MOVE.L	#RTG_COPMAX*4,D0
	JSR	(-210,A6)		; FreeMem
	CLR.L	rtg_PrevCop
.npc:	MOVE.L	rtg_Mem,D0
	BEQ.S	.nmm
	MOVEA.L	D0,A1
	MOVE.L	#RM_SIZE,D0
	JSR	(-210,A6)
	CLR.L	rtg_Mem
.nmm:	MOVE.L	rtg_RowSt,D0
	BEQ.S	.nrs
	MOVEA.L	D0,A1
	MOVE.L	#RTG_ROWS*RTG_STSIZE,D0
	JSR	(-210,A6)
	CLR.L	rtg_RowSt
.nrs:
	MOVE.W	#$8100,DMACON		; native picture back
	SF	rtg_BplOff
	MOVEA.L	dat_IntuiLibBase,A6
	BSR.W	pt_RtgBufFree
	MOVE.L	rtg_Window,D0
	BEQ.S	.nw
	MOVEA.L	D0,A0
	JSR	(-72,A6)		; CloseWindow
	CLR.L	rtg_Window
	TST.B	rtg_RunWin		; win: pt screen back to front
	BEQ.S	.nw
	MOVE.L	dat_ScreenPtr,D0
	BEQ.S	.nw
	MOVEA.L	D0,A0
	JSR	(-252,A6)		; ScreenToFront
.nw:	MOVE.L	rtg_Screen,D0
	BEQ.S	.ns
	MOVEA.L	D0,A0
	JSR	(-66,A6)		; CloseScreen
	CLR.L	rtg_Screen
.ns:	MOVEA.L	ABSEXECBASE.W,A6
	MOVE.L	rtg_LineBuf,D0
	BEQ.S	.nb
	MOVEA.L	D0,A1
	MOVE.L	#RTG_LINEBUF,D0
	JSR	(-210,A6)
	CLR.L	rtg_LineBuf
.nb:	MOVE.L	rtg_Blank,D0
	BEQ.S	.nbl
	MOVEA.L	D0,A1
	MOVEQ	#16,D0
	JSR	(-210,A6)
	CLR.L	rtg_Blank
.nbl:	MOVE.L	rtg_XMap,D0
	BEQ.S	.nx
	MOVEA.L	D0,A1
	MOVE.L	#RTG_WINBUF,D0
	JSR	(-210,A6)
	CLR.L	rtg_XMap
.nx:	MOVE.L	rtg_CgxBase,D0
	BEQ.S	.r
	MOVEA.L	D0,A1
	JSR	(-414,A6)		; CloseLibrary
	CLR.L	rtg_CgxBase
.r:	SF	rtg_RunWin
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; force full redraw
pt_RtgInvalidate:
	MOVEM.L	D0/A0,-(A7)
	SF	rtg_StateOk
	X20LEA	X20_RTGSIG,A0
	MOVE.W	#RTG_MAXOUT-1,D0
.i:	MOVE.L	#-1,(A0)+
	DBF	D0,.i
	MOVEM.L	(A7)+,D0/A0
	RTS

;--- frame
; walk copper list, render rows; a4=cop d4=raster line d5=vhigh ofs
pt_RtgFrame:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	ADD.W	#RTG_STRIPE,rtg_Stripe	; next stripe
	TST.B	dat_KeyCode		; input: pt answers on screen, read all
	BNE.S	.in
	BTST	#6,CIAA_PRA		; lmb
	BEQ.S	.lm
.rm:	BTST	#2,$dff016		; rmb
	BEQ.S	.in
	TST.B	rtg_Full
	BEQ.S	.go
	SUBQ.B	#1,rtg_Full
	BRA.S	.go
.in:	MOVE.B	#RTG_FULLN,rtg_Full
	BRA.S	.go
.lm:	TST.B	rtg_RunWin		; wb window: lmb counts over our picture
	BEQ.S	.in			; only (dragging any window: no full
	TST.B	rtg_SysDrag		; frames from chip ram)
	BNE.S	.rm
	TST.B	rtg_InBlock
	BNE.S	.rm
	BRA.S	.in
.go:	BSR.W	pt_RwdStgPre		; stage first: its rows read this frame
	IFD	DEBUGAUTO
	BSR.W	pt_RtgTick		; profile: copy + sprites
	MOVE.L	D0,rtg_ProfT0
	ENDC
	MOVE.L	dat_ActiveCopperPtr,D0
	BEQ.W	.out
	MOVEA.L	D0,A0
	MOVEA.L	rtg_LineBuf,A4
	LEA	RTG_COPCOPY(A4),A4
	MOVEA.L	A4,A1
	SF	rtg_P3Moved
	MOVEQ	#1,D6			; differs from the last frame
	MOVE.L	rtg_PrevCop,D1
	BEQ.S	.c0
	MOVEQ	#0,D6
	MOVEA.L	D1,A2
.c0:	MOVE.W	#RTG_COPMAX-2,D0
.cc:	MOVE.L	(A0)+,D1		; chip is slow: list read once into fast ram
	MOVE.L	D1,(A1)+
	TST.L	rtg_PrevCop
	BEQ.S	.cn
	CMP.L	(A2),D1			; same list as last frame?
	BEQ.S	.ce
	MOVE.L	D1,D2
	SWAP	D2
	CMP.W	#$00e8,D2		; BPL3PT only (pattern row): renderer job
	BEQ.S	.cp
	CMP.W	#$00ea,D2
	BEQ.S	.cp
	MOVEQ	#1,D6			; anything else: full frame
	BRA.S	.cw
.cp:	ST	rtg_P3Moved
.cw:	MOVE.L	D1,(A2)
.ce:	ADDQ.L	#4,A2
.cn:	MOVE.L	D1,D2			; last BPL3PT of the list = pattern ptr
	SWAP	D2
	CMP.W	#$00e8,D2
	BNE.S	.ch
	MOVE.W	D1,rtg_NewP3
.ch:	CMP.W	#$00ea,D2
	BNE.S	.cl
	MOVE.W	D1,rtg_NewP3+2
.cl:	CMP.L	#$fffffffe,D1
	DBEQ	D0,.cc
	MOVE.L	#$fffffffe,(A1)		; end even if cut
	IFD	DEBUGAUTO
	MOVE.W	#RTG_COPMAX-2,D1	; profile: list length
	SUB.W	D0,D1
	MOVE.W	D1,rtg_ProfLen
	BSR.W	pt_RtgTick
	SUB.L	rtg_ProfT0,D0
	ADD.L	D0,rtg_Prof+16
	BSR.W	pt_RtgTick
	MOVE.L	D0,rtg_ProfT0
	ENDC
	BSR.W	pt_RtgSprBuild		; spr from SPRxPT in cop list
	IFD	DEBUGAUTO
	BSR.W	pt_RtgTick
	SUB.L	rtg_ProfT0,D0
	ADD.L	D0,rtg_ProfX
	ENDC
	BSR.W	pt_RtgSegsChk		; sprites moved?
	OR.B	D0,D6
	TST.B	rtg_Full		; input: full frame
	SNE	D0
	OR.B	D0,D6
	TST.B	rtg_StateOk
	SEQ	D0
	OR.B	D0,D6
	OR.B	rtg_RprMiss,D6		; renderer kept on: walk again for its fate
	TST.B	rtg_P3Moved		; pattern row moved: steady only with renderer
	BEQ.S	.p3
	TST.B	rtg_RprOn
	SEQ	D0
	OR.B	D0,D6
.p3:	TST.B	D6
	BNE.S	.full
	IFD	DEBUGAUTO
	BSR.W	pt_RtgTick
	MOVE.L	D0,rtg_ProfT0
	ENDC
	BSR.W	pt_RtgSteady		; nothing moved: only hot / stripe / sprite lines
	IFD	DEBUGAUTO
	BSR.W	pt_RtgTick
	SUB.L	rtg_ProfT0,D0
	ADD.L	D0,rtg_ProfX+4
	ENDC
	MOVE.L	rtg_NewP3,rtg_OldP3
	BRA.W	.post
.full:
	DK	'X'
	SF	rtg_StateOk
	MOVE.L	rtg_NewP3,rtg_OldP3
	TST.L	rtg_Mem
	BEQ.S	.fn
	RMLEA	RM_SPR,A0		; sprite lines: check again in the next steady frame
	MOVE.W	#RTG_ROWS-1,D0
.fs:	MOVE.L	#-1,(A0)+
	DBF	D0,.fs
.fn:
	LEA	rtg_BplPt,A0
	MOVEQ	#5,D0
.cb:	CLR.L	(A0)+
	DBF	D0,.cb
	CLR.W	rtg_Con0
	CLR.W	rtg_Mod1
	CLR.W	rtg_Mod2
	MOVE.W	#$2c,rtg_VStart
	SF	rtg_PatOn
	SF	rtg_TplOk
	SF	rtg_RprOn
	MOVEQ	#0,D4			; Rasterzeile
	MOVEQ	#0,D5			; vhigh
	MOVE.W	#4000,D7		; insn limit
.cop:	SUBQ.W	#1,D7
	BMI.W	.lim
	MOVE.L	(A4)+,D1
	MOVE.L	D1,D0
	SWAP	D0
	BTST	#0,D0
	BNE.W	.waitskip
	AND.W	#$01fe,D0
	CMP.W	#$0180,D0
	BLO.S	.notcol
	CMP.W	#$01be,D0
	BHI.S	.cop
	SUB.W	#$0180,D0
	LEA	rtg_Colors,A0
	MOVE.W	D1,(A0,D0.W)
	CMP.W	#16,D0			; colors 0-7: bank may change
	BHS.W	.cop
	ST	rtg_ColDirty
	BRA.W	.cop
.notcol:
	CMP.W	#$00e0,D0
	BLO.S	.notbpl
	CMP.W	#$00f6,D0
	BHI.S	.notbpl
	SUB.W	#$00e0,D0
	LEA	rtg_BplPt,A0
	BTST	#1,D0
	BNE.S	.lo
	MOVE.W	D1,(A0,D0.W)		; hohes Wort
	BRA.S	.cop
.lo:	MOVE.W	D1,(A0,D0.W)		; lo word (+2 in long)
	CMP.W	#$000a,D0		; BPL3PTL: pattern buffer?
	BNE.W	.cop
	IFD	DEBUGAUTO
	TST.B	rtg_ProfN+28		; test: this walk misses the pattern ptr
	BNE.W	.cop
	ENDC
	BSR.W	pt_RtgPatChk
	BRA.W	.cop
.notbpl:
	CMP.W	#$0100,D0
	BNE.S	.n100
	MOVE.W	D1,rtg_Con0
	BRA.W	.cop
.n100:	CMP.W	#$0108,D0
	BNE.S	.n108
	MOVE.W	D1,rtg_Mod1
	BRA.W	.cop
.n108:	CMP.W	#$010a,D0
	BNE.S	.n10a
	MOVE.W	D1,rtg_Mod2
	BRA.W	.cop
.n10a:	CMP.W	#$008e,D0
	BNE.S	.n8e
	MOVE.W	D1,D2
	LSR.W	#8,D2
	MOVE.W	D2,rtg_VStart
	AND.W	#$ff,D1
	MOVE.W	D1,rtg_DiwH
	BRA.W	.cop
.n8e:	CMP.W	#$0084,D0
	BNE.S	.n84
	MOVE.W	D1,rtg_Cop2
	BRA.W	.cop
.n84:	CMP.W	#$0086,D0
	BNE.S	.n86
	MOVE.W	D1,rtg_Cop2+2
	BRA.W	.cop
.n86:	CMP.W	#$008a,D0		; COPJMP2
	BNE.W	.cop
	MOVE.L	rtg_Cop2,D2
	BEQ.W	.cop
	MOVEA.L	D2,A4
	BRA.W	.cop
.waitskip:
	BTST	#0,D1
	BNE.W	.cop			; ignore SKIP
	CMP.W	#$ffff,D0
	BNE.S	.wait
	CMP.W	#$fffe,D1
	BEQ.S	.end
.wait:	MOVEQ	#0,D2
	MOVE.W	D0,D2
	LSR.W	#8,D2
	ADD.W	D5,D2			; Zielzeile
	CMP.W	D4,D2
	BHS.S	.wfwd
	MOVE.W	D4,D2			; target passed: hw does not wait (e.g. $E307 after $E507)
.wfwd:	BSR.W	pt_RtgLines		; D4 .. D2-1
	MOVE.W	D2,D4
	CMP.W	#$ffdf,D0
	BNE.W	.cop
	MOVE.W	#256,D5
	BRA.W	.cop
.lim:
	IFD	DEBUGAUTO
	ADDQ.L	#1,rtg_ProfN+16		; copper list longer than the walk
	ENDC
.end:
	IFD	DEBUGAUTO
	SF	rtg_ProfN+28
	ENDC
	BSR.W	pt_RprHold
	MOVE.W	rtg_VStart,D2		; rest of win
	ADD.W	#RTG_ROWS,D2
	BSR.W	pt_RtgLines
	TST.L	rtg_RowSt
	SNE	rtg_StateOk		; line states saved: next frame may be steady
.post:
	IFD	DEBUGAUTO
	TST.B	rtg_RprOn		; renderer dropped out for a frame
	BNE.S	.dg1
	TST.L	rpr_BM
	BEQ.S	.dg1
	TST.B	rtg_ProfN+27
	BEQ.S	.dg1
	ADDQ.L	#1,rtg_ProfN+20
.dg1:	MOVE.B	rtg_RprOn,rtg_ProfN+27
	ENDC
	BSR.W	pt_RtgSynth		; rows beyond the native picture
	BSR.W	pt_RwdLay
	IFD	DEBUGAUTO
	BSR.W	pt_RtgTick
	MOVE.L	D0,-(A7)
	ENDC
	BSR.W	pt_RprFrame		; or the renderer
	IFD	DEBUGAUTO
	BSR.W	pt_RtgTick
	SUB.L	(A7)+,D0
	ADD.L	D0,rtg_Prof+8
	ENDC
	BSR.W	pt_RtgPalette
.out:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; full walk without the pattern pointer (list read while pt writes it,
; walk cut short) although the renderer ran: it keeps its area for this
; frame, else the mirror writes old lut lines over the pattern
pt_RprHold:
	TST.B	rtg_RprOn
	BNE.S	.on
	TST.B	rtg_RprWas
	BEQ.S	.off
	TST.B	rtg_RprMiss
	BNE.S	.off
	TST.L	rpr_BM
	BEQ.S	.off
	TST.W	dat_SamplerActive
	BNE.S	.off
	IFD	DEBUGAUTO
	ADDQ.W	#1,rtg_ProfN+24
	ENDC
	ST	rtg_RprMiss		; one frame only: a real change follows
	ST	rtg_RprOn
	ST	rtg_PatOn
	RTS
.off:	SF	rtg_RprWas
	SF	rtg_RprMiss
	RTS
.on:	ST	rtg_RprWas
	SF	rtg_RprMiss
	RTS

; rows d4..d2-1, only inside win VStart..VStart+255
pt_RtgLines:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	IFD	DEBUGAUTO
	BSR.W	pt_RtgTick
	MOVE.L	D0,-(A7)
	ENDC
	MOVE.W	D4,D6
.l:	CMP.W	D2,D6
	BHS.W	.r
	MOVE.W	D6,D0
	SUB.W	rtg_VStart,D0
	BMI.S	.n
	CMP.W	#RTG_ROWS,D0
	BHS.S	.n
	MOVEM.L	D2/D6,-(A7)
	MOVE.W	D0,rtg_OutRow
	TST.B	rtg_PatOn		; pattern lines move down in a taller picture
	BEQ.S	.go
	CMP.W	#RTG_PATTOP,D0
	BLO.S	.go
	MOVE.W	rtg_Shift,D2
	CMP.W	#RTG_PATEND,D0		; bottom frame: last lines of the picture
	BHS.S	.fr
	TST.B	rtg_RprOn		; renderer: only bar and template lines
	BEQ.S	.sh
	BSR.W	pt_RprNative
	BNE.S	.ne
	MOVE.W	D0,rtg_NatRow		; state kept for the vu bars (colours)
	BSR.W	pt_RtgStSave
	BSR.W	pt_RtgAdv
	BRA.S	.skp
.ne:	ST	rtg_NoEmit
	ADD.W	D2,rtg_OutRow
	BSR.W	pt_RtgRow
	SF	rtg_NoEmit
	BRA.S	.skp
.fr:	MOVE.W	rtg_OutH,D2
	SUB.W	#RTG_ROWS,D2
.sh:	ADD.W	D2,rtg_OutRow
.go:	BSR.W	pt_RtgRow		; D0 = Bildzeile
.skp:	MOVEM.L	(A7)+,D2/D6
.n:	ADDQ.W	#1,D6
	BRA.W	.l
.r:
	IFD	DEBUGAUTO
	BSR.W	pt_RtgTick		; profile: lines
	SUB.L	(A7)+,D0
	ADD.L	D0,rtg_Prof+4
	ENDC
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; one row d0=0..255: bank, sig, convert+write if changed, advance ptrs
; chip is slow: a line is read only if hot, in the stripe, after input
; or when its bank/ptrs/sprites changed; else its last plane sum counts
pt_RtgRow:
	MOVE.W	D0,rtg_NatRow		; native line (sprites), -1 synthetic
	MOVE.W	rtg_OutRow,D7		; output line (caches, write)
	TST.B	rtg_InSteady
	BNE.S	.nsv
	CMP.W	#RTG_ROWS,D0
	BHS.S	.nsv
	BSR.W	pt_RtgStSave
.nsv:
	CMP.W	#RTG_PATTOP,D0		; template for synthetic pattern rows
	BNE.S	.ntp
	BSR.W	pt_RtgTplSave
.ntp:	MOVE.W	rtg_Con0,D3
	LSR.W	#8,D3
	LSR.W	#4,D3
	AND.W	#7,D3			; Bitplanes
	CMP.W	#4,D3
	BLS.S	.np
	MOVEQ	#4,D3
.np:	MOVE.L	rtg_TplBank,D1		; synthetic: template bank
	TST.B	rtg_NoSpr
	BNE.S	.bk
	BSR.W	pt_RtgBank		; bank
.bk:	MOVE.L	D1,D5			; key: bank, planes, ptrs
	SWAP	D5
	OR.W	D3,D5
	LEA	rtg_BplPt,A2
	MOVE.W	D3,D2
	BRA.S	.ke
.kl:	ROL.L	#5,D5
	ADD.L	(A2)+,D5
.ke:	DBF	D2,.kl
	TST.B	rtg_PatOn		; taller view: thumb moves with the row
	BEQ.S	.kp
	CMP.W	#RTG_PATTOP,D7
	BLO.S	.kp
	ROL.L	#5,D5
	ADD.W	rtg_PatRow,D5
.kp:
	MOVE.W	D7,D4
	LSL.W	#2,D4			; long idx
	X20LEA	X20_RTGKEY,A0
	CMP.L	(A0,D4.W),D5
	BNE.S	.rd
	TST.B	rtg_NoSpr		; synthetic: content follows key + stripe
	BNE.S	.stp

	TST.B	rtg_Full
	BNE.S	.rd
	X20LEA	X20_RTGHEAT,A0
	TST.B	(A0,D7.W)
	BNE.S	.rd
.stp:
	MOVE.W	D7,D0
	SUB.W	rtg_Stripe,D0
	AND.W	#RTG_ROWS-1,D0
	CMP.W	#RTG_STRIPE,D0
	BLO.S	.rd
	X20LEA	X20_RTGPSIG,A0		; untouched: last sum, no chip read
	MOVE.L	(A0,D4.W),D6
	ADD.L	D5,D6
	BSR.W	pt_RtgSprSig
	X20LEA	X20_RTGSIG,A0
	CMP.L	(A0,D4.W),D6
	BEQ.W	pt_RtgAdv
.rd:	X20LEA	X20_RTGKEY,A0
	MOVE.L	D5,(A0,D4.W)
	ADDQ.L	#1,rtg_Reads
	MOVEQ	#0,D6			; plane sum, 20 longs each
	LEA	rtg_BplPt,A2
	MOVEA.L	rtg_LineBuf,A4
	LEA	RTG_ROWCOPY(A4),A4	; planes to fast ram, chip read once
	MOVE.W	D3,D2
	SUBQ.W	#1,D2
	BMI.S	.sigd
.sp:	MOVEA.L	(A2)+,A0
	MOVE.L	A0,D0
	BTST	#0,D0
	BNE.S	.odd			; odd -> not fetched
	MOVEQ	#19,D0
.sl:	ROL.L	#1,D6
	MOVE.L	(A0)+,(A4)
	ADD.L	(A4)+,D6
	DBF	D0,.sl
	BRA.S	.spn
.odd:	MOVEQ	#19,D0
.oc:	MOVE.L	(A0)+,(A4)+
	DBF	D0,.oc
.spn:	DBF	D2,.sp
.sigd:	X20LEA	X20_RTGHEAT,A1
	X20LEA	X20_RTGPSIG,A0
	CMP.L	(A0,D4.W),D6
	BEQ.S	.cold
	MOVE.L	D6,(A0,D4.W)
	MOVE.B	#RTG_HOT,(A1,D7.W)	; changed: read it every frame a while
	BRA.S	.sum
.cold:	TST.B	(A1,D7.W)
	BEQ.S	.sum
	SUBQ.B	#1,(A1,D7.W)
.sum:	ADD.L	D5,D6
	BSR.W	pt_RtgSprSig
	X20LEA	X20_RTGSIG,A0
	CMP.L	(A0,D4.W),D6
	BEQ.W	pt_RtgAdv
	MOVE.L	D6,(A0,D4.W)
	; convert to rtg_LineBuf
	MOVEA.L	rtg_LineBuf,A1
	MOVE.L	D1,D5
	LSL.L	#3,D5			; bank * 8
	MOVE.L	D5,D0
	LSL.L	#8,D0
	OR.L	D0,D5
	MOVE.L	D5,D0
	SWAP	D0
	OR.L	D0,D5			; all 4 bytes
	X20LEA	X20_RTGP2C,A3
	MOVEA.L	rtg_LineBuf,A4
	LEA	RTG_ROWCOPY(A4),A4
	MOVEQ	#0,D4			; byte idx 0..79
.bx:	MOVE.L	D5,D0			; px 0-3
	MOVE.L	D5,D1			; px 4-7
	MOVEA.L	A4,A2
	MOVEQ	#0,D6			; plane
.pl:	CMP.W	D3,D6
	BHS.S	.pld
	MOVEQ	#0,D2
	MOVE.B	(A2,D4.W),D2
	LEA	80(A2),A2
	LSL.W	#3,D2
	MOVE.L	(A3,D2.W),A5		; bits 7-4 as bytes
	MOVE.L	4(A3,D2.W),A6		; bits 3-0
	MOVE.L	A5,D2
	LSL.L	D6,D2
	OR.L	D2,D0
	MOVE.L	A6,D2
	LSL.L	D6,D2
	OR.L	D2,D1
	ADDQ.W	#1,D6
	BRA.S	.pl
.pld:	MOVE.L	D0,(A1)+
	MOVE.L	D1,(A1)+
	ADDQ.W	#1,D4
	CMP.W	#80,D4
	BLO.S	.bx
	MOVE.W	rtg_NatRow,D0		; scroll bar column before sprites
	SUB.W	#RTG_PATTOP,D0
	CMP.W	#1,D0
	BHI.S	.nsc
	LSL.W	#4,D0
	MOVEA.L	rtg_LineBuf,A0
	LEA	rtg_ScrCol,A1
	MOVE.L	624(A0),(A1,D0.W)
	MOVE.L	628(A0),4(A1,D0.W)
	MOVE.L	632(A0),8(A1,D0.W)
	MOVE.L	636(A0),12(A1,D0.W)
.nsc:	TST.B	rtg_NoEmit
	BEQ.S	.ns1
	BSR.W	pt_RprCapPre		; renderer template (no sprites)
.ns1:	; sprites
	BSR.W	pt_RtgSprites
	TST.B	rtg_NoEmit
	BEQ.S	.ns2
	BSR.W	pt_RprCapPost		; renderer cursor bar (with sprites)
	BRA.W	pt_RtgAdv
.ns2:	BSR.W	pt_RtgScrPaint		; taller view: own scroll bar
	BSR.W	pt_RtgEmit
	BRA.W	pt_RtgAdv

; rtg_LineBuf -> output line d7 (window scaled, or card screen)
pt_RtgEmit:
	TST.B	rtg_RunWin		; win: write scaled into wb window
	BEQ.S	.scrw
	BRA.W	pt_RtgWinRow
.scrw:
	MOVEA.L	rtg_LineBuf,A0
	MOVEQ	#0,D1			; ystart
	MOVE.W	D7,D1
	MOVE.L	D1,D3
	TST.B	rtg_Double
	BEQ.S	.single
	ADD.L	D1,D1
	MOVE.L	D1,D3
	ADDQ.L	#1,D3			; two rows
	LEA	640(A0),A1		; 2nd row = copy
	MOVE.W	#640/4-1,D0
.cp:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.cp
	MOVEA.L	rtg_LineBuf,A0
	BRA.S	.wr
.single:
	ADD.W	rtg_YOff,D1
	MOVE.L	D1,D3
.wr:	MOVEA.L	A0,A2			; array
	MOVEA.L	rtg_Screen,A0
	LEA	84(A0),A0		; Screen->RastPort
	MOVEQ	#0,D0			; xstart
	MOVE.L	#639,D2			; xstop
	MOVE.L	#640,D4			; bytesperrow
	MOVE.L	A6,-(A7)
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-1056,A6)		; WriteChunkyPixels(rp,xstart,ystart,xstop,ystop,array,bpr)
	MOVEA.L	(A7)+,A6
	ADDQ.L	#1,rtg_Lines
	RTS

pt_RtgAdv:	; bpl ptrs: only active planes advance, 80 + modulo
	TST.B	rtg_NoSpr		; synthetic rows: ptrs set per row
	BNE.S	.advd
	; odd planes BPL1MOD, even BPL2MOD, disabled planes fetch nothing
	LEA	rtg_BplPt,A0
	MOVE.W	rtg_Mod1,D0
	EXT.L	D0
	ADD.L	#80,D0
	MOVE.W	rtg_Mod2,D1
	EXT.L	D1
	ADD.L	#80,D1
	MOVE.W	rtg_Con0,D2
	LSR.W	#8,D2
	LSR.W	#4,D2
	AND.W	#7,D2
	SUBQ.W	#1,D2
	BMI.S	.advd
.advl:	ADD.L	D0,(A0)+
	EXG	D0,D1
	DBF	D2,.advl
.advd:	RTS

; find/alloc color bank for rtg_Colors[0..7] -> d1 = bank
pt_RtgBank:
	TST.B	rtg_ColDirty		; colors 0-7 as on the last line: same bank
	BNE.S	.srch
	MOVE.L	rtg_LastBank,D1
	RTS
.srch:	MOVEM.L	D0/D2-D3/A0-A1,-(A7)
	X20LEA	X20_RTGBANKS,A0
	MOVEQ	#0,D1
.s:	CMP.W	rtg_NumBanks,D1
	BHS.S	.new
	MOVEQ	#7,D2
	LEA	rtg_Colors,A1
	MOVE.L	A0,-(A7)
.c:	CMPM.W	(A0)+,(A1)+
	DBNE	D2,.c
	MOVEA.L	(A7)+,A0
	BEQ.S	.got
	LEA	16(A0),A0
	ADDQ.W	#1,D1
	BRA.S	.s
.new:	CMP.W	#RTG_BANKS,D1
	BHS.S	.full
	MOVE.W	D1,D2			; new bank must stay below spr color pool
	LSL.W	#3,D2
	ADDQ.W	#7,D2
	CMP.W	rtg_SprNext,D2
	BLS.S	.add
.full:	BSR.W	pt_RtgPoolReset		; full: restart, redraw all
	X20LEA	X20_RTGBANKS,A0
	MOVEQ	#0,D1
.add:	LEA	rtg_Colors,A1
	MOVEQ	#7,D2
.a:	MOVE.W	(A1)+,(A0)+
	DBF	D2,.a
	ADDQ.W	#1,rtg_NumBanks
	ST	rtg_PalDirty
.got:	MOVE.L	D1,rtg_LastBank
	SF	rtg_ColDirty
	MOVEM.L	(A7)+,D0/D2-D3/A0-A1
	RTS

; reset color pools (banks from 0, spr colors from 255 down), redraw all
pt_RtgPoolReset:
	MOVEM.L	D0/A0,-(A7)
	IFD	DEBUGAUTO
	ADDQ.L	#1,rtg_ProfN+4
	ENDC
	ST	rtg_ColDirty
	CLR.W	rtg_NumBanks
	MOVE.W	#255,rtg_SprNext
	X20LEA	X20_RTGCOLMAP,A0
	MOVE.W	#4096/4-1,D0
.c:	CLR.L	(A0)+
	DBF	D0,.c
	ST	rtg_PalDirty
	BSR.W	pt_RtgInvalidate
	MOVEM.L	(A7)+,D0/A0
	RTS

; spr segs: SPRxPT from cop (MOVE $120-$13E), chain POS/CTL/data to 0/0
; 16 px wide, fmode 0 -> rtg_Segs (spr, vstart, vstop, hstart, data)
pt_RtgSprBuild:
	MOVEM.L	D0-D7/A0-A2,-(A7)
	LEA	rtg_SprPt,A0
	MOVEQ	#7,D0
.cl:	CLR.L	(A0)+
	DBF	D0,.cl
	MOVEA.L	rtg_LineBuf,A1
	LEA	RTG_COPCOPY(A1),A1	; copy made by pt_RtgFrame
	MOVE.W	#RTG_COPMAX,D7
.sc:	SUBQ.W	#1,D7
	BMI.S	.scd
	MOVE.L	(A1)+,D1
	MOVE.L	D1,D0
	SWAP	D0
	BTST	#0,D0
	BNE.S	.scw
	AND.W	#$01fe,D0
	CMP.W	#$0120,D0
	BLO.S	.sc
	CMP.W	#$013e,D0
	BHI.S	.sc
	SUB.W	#$0120,D0
	LEA	rtg_SprPt,A0
	MOVE.W	D1,(A0,D0.W)
	BRA.S	.sc
.scw:	CMP.W	#$ffff,D0
	BNE.S	.sc
	CMP.W	#$fffe,D1
	BNE.S	.sc
.scd:	X20LEA	X20_RTGSEGS,A2
	MOVEQ	#0,D6			; segs
	MOVEQ	#0,D5			; Sprite
.sp:	LEA	rtg_SprPt,A0
	MOVE.W	D5,D0
	LSL.W	#2,D0
	MOVE.L	(A0,D0.W),D0
	BEQ.W	.spn
	BTST	#0,D0
	BNE.W	.spn
	CMP.L	#$00200000,D0		; chip ram only
	BHS.W	.spn
	MOVEA.L	D0,A1
	MOVEQ	#7,D4			; max 8 segs per spr
	MOVEQ	#$19,D7			; spr dma starts at line 25
.sg:	MOVE.W	(A1)+,D0		; POS
	MOVE.W	(A1)+,D1		; CTL
	MOVE.W	D0,D2
	OR.W	D1,D2
	BEQ.W	.spn
	MOVE.W	D0,D2
	LSR.W	#8,D2			; VSTART
	BTST	#2,D1
	BEQ.S	.v1
	BSET	#8,D2
.v1:	MOVE.W	D1,D3
	LSR.W	#8,D3			; VSTOP
	BTST	#1,D1
	BEQ.S	.v2
	BSET	#8,D3
.v2:	CMP.W	D2,D3
	BLS.W	.spn
	CMP.W	D7,D2			; vstart compares for equality: passed -> spr stays off
	BLO.W	.spn
	CMP.W	#$138,D2
	BHI.W	.spn
	MOVE.W	D3,D7
	ADDQ.W	#1,D7			; next POS/CTL fetched in line after vstop
	CMP.W	#RTG_SEGS,D6
	BHS.W	.done
	MOVE.W	D5,(A2)+
	MOVE.W	D2,(A2)+
	MOVE.W	D3,(A2)+
	AND.W	#$ff,D0
	ADD.W	D0,D0
	BTST	#0,D1
	BEQ.S	.h
	ADDQ.W	#1,D0
.h:	MOVE.W	D0,(A2)+		; hstart (lores clk)
	MOVE.L	A1,(A2)+
	ADDQ.W	#1,D6
	SUB.W	D2,D3
	EXT.L	D3
	LSL.L	#2,D3
	ADDA.L	D3,A1
	DBF	D4,.sg
.spn:	ADDQ.W	#1,D5
	CMP.W	#8,D5
	BLO.W	.sp
.done:	TST.B	vu8_Cop
	BEQ.S	.dn
	BSR.S	pt_RtgVuSegs
.dn:	MOVE.W	D6,rtg_NumSegs
	X20LEA	X20_RTGSPRLN,A0		; lines with sprites (cheap test per row)
	MOVEQ	#320/4-1,D0
.cz:	CLR.L	(A0)+
	DBF	D0,.cz
	X20LEA	X20_RTGSPRLN,A0
	X20LEA	X20_RTGSEGS,A1
	BRA.S	.ce
.cs:	MOVE.W	6(A1),D0		; off the picture (x): never drawn
	SUB.W	rtg_DiwH,D0
	ADD.W	D0,D0
	CMP.W	#-32,D0
	BLE.S	.cn
	CMP.W	#640,D0
	BGE.S	.cn
	MOVE.W	2(A1),D0		; y0
	MOVE.W	4(A1),D1		; y1
.cy:	CMP.W	D1,D0
	BHS.S	.cn
	CMP.W	#320,D0
	BHS.S	.cn
	ADDQ.B	#1,(A0,D0.W)
	ADDQ.W	#1,D0
	BRA.S	.cy
.cn:	LEA	12(A1),A1
.ce:	DBF	D6,.cs
	MOVEM.L	(A7)+,D0-D7/A0-A2
	RTS

; vu spr 4-7: 2nd bar seg 72 clk right of the first, data from vu8_Bar2
pt_RtgVuSegs:
	MOVEM.L	D0-D4/A0-A1,-(A7)
	X20LEA	X20_RTGSEGS,A0
	MOVE.W	D6,D4
	BRA.S	.e
.l:	MOVE.W	(A0),D0
	SUBQ.W	#4,D0
	CMP.W	#3,D0
	BHI.S	.n
	CMP.W	#RTG_SEGS,D6
	BHS.S	.n
	MOVE.W	(A0),(A2)+
	MOVE.W	2(A0),(A2)+
	MOVE.W	4(A0),(A2)+
	MOVE.W	6(A0),D1
	ADD.W	#2*VU8_DX,D1
	MOVE.W	D1,(A2)+
	MULU	#192,D0
	LEA	vu8_Bar2,A1
	ADDA.L	D0,A1
	MOVE.L	A1,(A2)+
	ADDQ.W	#1,D6
.n:	LEA	12(A0),A0
.e:	DBF	D4,.l
	MOVEM.L	(A7)+,D0-D4/A0-A1
	RTS

; spr part of row sig: row d7, sig d6
pt_RtgSprSig:
	MOVEM.L	D0-D3/A0-A1,-(A7)
	TST.B	rtg_NoSpr
	BNE.S	.x
	MOVE.W	rtg_NatRow,D2
	ADD.W	rtg_VStart,D2		; Rasterzeile
	CMP.W	#320,D2
	BHS.S	.all
	X20LEA	X20_RTGSPRLN,A0		; no sprite on this line: nothing to add
	TST.B	(A0,D2.W)
	BEQ.S	.x
.all:
	X20LEA	X20_RTGSEGS,A0
	MOVE.W	rtg_NumSegs,D3
	BRA.S	.e
.l:	CMP.W	2(A0),D2
	BLO.S	.n
	CMP.W	4(A0),D2
	BHS.S	.n
	MOVE.W	D2,D0
	SUB.W	2(A0),D0
	LSL.W	#2,D0
	MOVEA.L	8(A0),A1
	ROL.L	#3,D6
	ADD.L	(A1,D0.W),D6		; data a/b
	ROL.L	#3,D6
	ADD.W	6(A0),D6		; Position
	MOVE.W	(A0),D0
	LSR.W	#1,D0
	LSL.W	#3,D0			; pair * 4 colors * 2 bytes
	LEA	rtg_Colors+32,A1
	ROL.L	#1,D6
	ADD.L	2(A1,D0.W),D6		; colors 1, 2
	ROL.L	#1,D6
	ADD.W	6(A1,D0.W),D6		; color 3
.n:	LEA	12(A0),A0
.e:	DBF	D3,.l
.x:	BSR.W	pt_RwdSig
	MOVEM.L	(A7)+,D0-D3/A0-A1
	RTS

; spr into rtg_LineBuf row d7: spr 7 first, spr 0 on top, behind planes
; (BPLCON2 $0024); px = 2 hires px, x = (HSTART-DIWSTRT-H)*2, COLOR16-31
pt_RtgSprites:
	MOVEM.L	D0-D6/A0-A3,-(A7)
	TST.B	rtg_NoSpr
	BNE.W	.r
	MOVE.W	rtg_NatRow,D2
	ADD.W	rtg_VStart,D2
	CMP.W	#320,D2
	BHS.S	.al
	X20LEA	X20_RTGSPRLN,A0
	TST.B	(A0,D2.W)
	BEQ.W	.r
.al:	MOVE.W	rtg_NumSegs,D3
	BEQ.W	.r
	X20LEA	X20_RTGSEGS,A0
	MOVE.W	D3,D0
	MULU	#12,D0
	ADDA.L	D0,A0
.l:	LEA	-12(A0),A0
	TST.B	rtg_RunWin		; win: wb has own ptr, skip pt mouse spr (0)
	BEQ.S	.spr
	TST.W	(A0)
	BEQ.W	.n
.spr:	CMP.W	2(A0),D2
	BLO.W	.n
	CMP.W	4(A0),D2
	BHS.W	.n
	TST.B	trk_On			; track view: vu bars are the renderer's
	BEQ.S	.vu
	CMPI.W	#4,(A0)
	BLO.S	.vu
	CMPI.W	#RPR_VUTOP,rtg_NatRow
	BLO.S	.vu
	CMPI.W	#RPR_BARTOP,rtg_NatRow
	BLS.W	.n
.vu:	MOVE.W	D2,D0
	SUB.W	2(A0),D0
	LSL.W	#2,D0
	MOVEA.L	8(A0),A1
	MOVE.L	(A1,D0.W),D4		; a word (top), b word (bottom)
	BEQ.W	.n
	LEA	rtg_SprIdx,A2
	MOVE.W	(A0),D0
	LSR.W	#1,D0
	LSL.W	#3,D0
	LEA	rtg_Colors+32,A1
	ADDA.W	D0,A1
	MOVE.W	2(A1),D1
	BSR.W	pt_RtgSprCol
	MOVE.B	D1,1(A2)
	MOVE.W	4(A1),D1
	BSR.W	pt_RtgSprCol
	MOVE.B	D1,2(A2)
	MOVE.W	6(A1),D1
	BSR.W	pt_RtgSprCol
	MOVE.B	D1,3(A2)
	MOVE.W	6(A0),D5
	SUB.W	rtg_DiwH,D5
	ADD.W	D5,D5			; hires x
	MOVEA.L	rtg_LineBuf,A3
	MOVEQ	#15,D6
.px:	MOVEQ	#0,D0
	MOVE.W	D6,D1
	ADD.W	#16,D1
	BTST	D1,D4
	BEQ.S	.na
	MOVEQ	#1,D0
.na:	BTST	D6,D4
	BEQ.S	.nb
	ADDQ.W	#2,D0
.nb:	TST.W	D0
	BEQ.S	.sk
	MOVE.B	(A2,D0.W),D0
	CMP.W	#639,D5
	BHI.S	.sk			; also off left (negative)
	MOVE.B	D0,(A3,D5.W)
	CMP.W	#638,D5
	BHI.S	.sk
	MOVE.B	D0,1(A3,D5.W)
.sk:	ADDQ.W	#2,D5
	DBF	D6,.px
.n:	SUBQ.W	#1,D3
	BNE.W	.l
.r:	MOVEM.L	(A7)+,D0-D6/A0-A3
	RTS

; spr color d1=$0RGB -> clut idx from pool 255 down, d1=idx
pt_RtgSprCol:
	MOVEM.L	D0/D2/A0,-(A7)
	AND.W	#$0fff,D1
	X20LEA	X20_RTGCOLMAP,A0
	MOVEQ	#0,D0
	MOVE.B	(A0,D1.W),D0
	BNE.S	.got
	MOVE.W	rtg_SprNext,D0
	MOVE.W	rtg_NumBanks,D2
	LSL.W	#3,D2			; first free idx above banks
	CMP.W	D2,D0
	BHS.S	.new
	BSR.W	pt_RtgPoolReset		; full: restart (row redrawn next frame)
	X20LEA	X20_RTGCOLMAP,A0
	MOVE.W	rtg_SprNext,D0
.new:	MOVE.B	D0,(A0,D1.W)
	SUBQ.W	#1,rtg_SprNext
	X20LEA	X20_RTGSPRRGB,A0
	ADD.W	D0,D0
	MOVE.W	D1,(A0,D0.W)
	LSR.W	#1,D0
	ST	rtg_PalDirty
.got:	MOVE.W	D0,D1
	MOVEM.L	(A7)+,D0/D2/A0
	RTS

; load clut if colors changed (LoadRGB32: banks from 0, spr colors to 255)
pt_RtgPalette:
	TST.B	rtg_PalDirty
	BEQ.W	.r
	SF	rtg_PalDirty
	TST.B	rtg_RunWin		; win: color table built by pt_RtgWinRow (pt_RtgCTab)
	BNE.W	.r
	MOVEM.L	D0-D3/A0-A2/A6,-(A7)
	X20LEA	X20_RTGPAL,A0
	MOVE.W	rtg_NumBanks,D0
	LSL.W	#3,D0			; color cnt
	BEQ.S	.spr			; cnt 0 would end table
	MOVE.W	D0,(A0)+
	CLR.W	(A0)+			; first idx 0
	X20LEA	X20_RTGBANKS,A1
	SUBQ.W	#1,D0
.c:	MOVE.W	(A1)+,D1
	BSR.S	.rgb
	DBF	D0,.c
.spr:	MOVE.W	#255,D0
	SUB.W	rtg_SprNext,D0		; spr colors SprNext+1 .. 255
	BEQ.S	.end
	MOVE.W	D0,(A0)+
	MOVE.W	rtg_SprNext,D1
	ADDQ.W	#1,D1
	MOVE.W	D1,(A0)+
	X20LEA	X20_RTGSPRRGB,A1
	ADD.W	D1,D1
	ADDA.W	D1,A1
	SUBQ.W	#1,D0
.s:	MOVE.W	(A1)+,D1
	BSR.S	.rgb
	DBF	D0,.s
.end:	CLR.L	(A0)
	MOVEA.L	rtg_Screen,A0
	LEA	44(A0),A0		; ViewPort
	X20LEA	X20_RTGPAL,A1
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-882,A6)		; LoadRGB32
	MOVEM.L	(A7)+,D0-D3/A0-A2/A6
.r:	RTS
.rgb:	; .rgb: ; d1 = $0RGB -> 3 longs, nibble repeated
	MOVE.W	D1,D2
	LSR.W	#8,D2
	BSR.S	.gun
	MOVE.W	D1,D2
	LSR.W	#4,D2
	BSR.S	.gun
	MOVE.W	D1,D2
.gun:	AND.L	#$f,D2
	MOVE.L	D2,D3
	LSL.L	#4,D3
	OR.L	D3,D2
	MOVE.L	D2,D3
	LSL.L	#8,D3
	OR.L	D3,D2
	MOVE.L	D2,D3
	SWAP	D3
	OR.L	D3,D2			; $nnnnnnnn
	MOVE.L	D2,(A0)+
	RTS

;--- window
; wb window possible? -> d0 = 0 ok, 1 not on a card (or no cgx),
; 2 wb too small for the window
pt_RtgWinOk41:
	MOVEM.L	D1-D7/A0-A6,-(A7)
	MOVEQ	#1,D6
	MOVEA.L	ABSEXECBASE.W,A6
	LEA	rtg_CgxName(PC),A1
	MOVEQ	#40,D0
	JSR	(-552,A6)		; OpenLibrary
	MOVE.L	D0,D5
	BEQ.S	.r
	MOVEA.L	dat_IntuiLibBase,A6
	SUBA.L	A0,A0
	JSR	(-510,A6)		; LockPubScreen(NULL)
	MOVE.L	D0,D7
	BEQ.S	.cl
	MOVEA.L	D0,A0
	MOVE.W	12(A0),D3		; width
	MOVE.W	14(A0),D4		; height
	LEA	44(A0),A0
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-792,A6)		; GetVPModeID
	CMP.L	#$00100000,D0
	BCS.S	.un
	MOVEQ	#4,D6			;41 clut wb: lut writes draw nothing
	MOVEA.L	D7,A0
	MOVEA.L	88(A0),A0		;41 Screen->RastPort.BitMap
	MOVEQ	#4,D1			;41 BMA_DEPTH
	JSR	(-960,A6)		;41 GetBitMapAttr
	CMP.L	#15,D0
	BCS.S	.un
	MOVEQ	#2,D6
	BSR.W	pt_RtgBase
	ADD.W	#32,D0			; room for borders
	ADD.W	#32,D1
	CMP.W	D0,D3
	BCS.S	.un
	CMP.W	D1,D4
	BCS.S	.un
	MOVEQ	#0,D6
.un:	MOVEA.L	dat_IntuiLibBase,A6
	SUBA.L	A0,A0
	MOVEA.L	D7,A1
	JSR	(-516,A6)		; UnlockPubScreen
.cl:	MOVEA.L	ABSEXECBASE.W,A6
	MOVEA.L	D5,A1
	JSR	(-414,A6)		; CloseLibrary
.r:	MOVE.L	D6,D0
	MOVEM.L	(A7)+,D1-D7/A0-A6
	RTS

; wb window on pubscreen, nearest-neighbour scaled, cgx WritePixelArray
; input: pt_RtgInWrap before pt handler, keys only if win active,
; mouse pos from win (fake RAWMOUSE); buttons: pt_LMB41/RMB41
; wb ptr stays visible, pt mouse ptr not drawn in win
pt_RtgWinSetup:
	MOVEM.L	D1-D7/A0-A6,-(A7)
	BSR.W	pt_RtgWinOk41
	TST.L	D0
	BNE.W	.fail
	MOVEA.L	ABSEXECBASE.W,A6
	MOVE.B	#10,rtg_Step		; step 10 cgx, 11 buf, 12 wb, 13 card, 14 win
	LEA	rtg_CgxName(PC),A1
	MOVEQ	#40,D0
	JSR	(-552,A6)		; OpenLibrary("cybergraphics.library", 40)
	MOVE.L	D0,rtg_CgxBase
	BEQ.W	.fail
	MOVE.B	#11,rtg_Step
	MOVE.L	#RTG_WINBUF,D0
	MOVEQ	#1,D1			; MEMF_PUBLIC
	JSR	(-198,A6)		; AllocMem
	MOVE.L	D0,rtg_XMap
	BEQ.W	.fail
	ADD.L	#4096*2,D0
	MOVE.L	D0,rtg_ScaleBuf
	MOVE.B	#12,rtg_Step
	MOVEA.L	dat_IntuiLibBase,A6
	SUBA.L	A0,A0
	JSR	(-510,A6)		; LockPubScreen(NULL)
	MOVE.L	D0,D7
	BEQ.W	.fail
	MOVE.B	#13,rtg_Step
	MOVEA.L	D0,A0
	LEA	44(A0),A0		; Screen->ViewPort
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-792,A6)		; GetVPModeID: card modes >= $00100000
	MOVEA.L	dat_IntuiLibBase,A6	; P96 CYBRMATTR_ISCYBERGFX unreliable
	CMP.L	#$00100000,D0
	BCS.S	.unl
	MOVE.B	#14,rtg_Step
	LEA	rtg_PubTags,A1
	MOVE.L	D7,4(A1)		; WA_PubScreen
	BSR.W	pt_RtgBoxTags		; saved place and size
	SUBA.L	A0,A0
	JSR	(-606,A6)		; OpenWindowTagList
	MOVE.L	D0,rtg_Window
.unl:	SUBA.L	A0,A0
	MOVEA.L	D7,A1
	JSR	(-516,A6)		; UnlockPubScreen(NULL, Screen)
	MOVE.L	rtg_Window,D0
	BEQ.S	.fail
	MOVE.L	#rtg_WinTitle,rtg_TitleCur
	SF	rtg_CloseReq
	CLR.L	rtg_WinW		; size computed in first frame (pt_RtgWinGeom)
	MOVE.W	#RTG_ROWS,D0
	BSR.W	pt_RtgSetOut
	BSR.W	pt_RtgWinLimits
	MOVE.L	dat_ScreenPtr,D0	; pt screen to back, wb to front
	BEQ.S	.nb
	MOVEA.L	D0,A0
	JSR	(-246,A6)		; ScreenToBack
.nb:	MOVEA.L	rtg_Window,A0
	MOVEA.L	46(A0),A0		; Window->WScreen
	JSR	(-252,A6)		; ScreenToFront
	MOVEA.L	rtg_Window,A0
	JSR	(-450,A6)		; ActivateWindow, WA_Activate alone fails after scr switch
	MOVE.B	#1,rtg_InBlock
	BSR.W	pt_RtgInHook
	MOVEQ	#0,D0
	MOVEM.L	(A7)+,D1-D7/A0-A6
	RTS
.fail:	MOVE.B	rtg_Step,rtg_WinFail
	MOVEQ	#-1,D0
	MOVEM.L	(A7)+,D1-D7/A0-A6
	RTS

; check inner area, changed -> rebuild x table, redraw all
pt_RtgWinGeom:
	MOVEM.L	D0-D5/A0-A1,-(A7)
	TST.B	rtg_GeoPend		; snap only once a new size stands
	BNE.S	.ns
	BSR.W	pt_RtgWinSnap
	BNE.W	.r			; resized: new size next frame
.ns:
	MOVEA.L	rtg_Window,A0
	MOVEQ	#0,D1
	MOVE.W	8(A0),D0		; Width
	MOVE.B	54(A0),D1		; BorderLeft
	SUB.W	D1,D0
	MOVE.B	56(A0),D1		; BorderRight
	SUB.W	D1,D0
	MOVE.W	10(A0),D2		; Height
	MOVE.B	55(A0),D1		; BorderTop
	SUB.W	D1,D2
	MOVE.B	57(A0),D1		; BorderBottom
	SUB.W	D1,D2
	CMP.W	#1,D0
	BGE.S	.w1
	MOVEQ	#1,D0
.w1:	CMP.W	#4096,D0
	BLE.S	.w2
	MOVE.W	#4096,D0
.w2:	CMP.W	#1,D2
	BGE.S	.h1
	MOVEQ	#1,D2
.h1:	BSR.W	pt_RwdWant		; d1 = wide layout for this width
	CMP.B	rtg_Wide,D1
	BNE.S	.new
	CMP.W	rtg_WinW,D0
	BNE.S	.new
	CMP.W	rtg_WinH,D2
	BEQ.W	.r
.new:	CMP.B	rtg_GeoWide,D1		; new size: taken once it stands still
	BNE.S	.cand			; and the button is up; meanwhile no
	CMP.W	rtg_GeoW,D0		; drawing and no new buffers
	BNE.S	.cand
	CMP.W	rtg_GeoH,D2
	BNE.S	.cand
	BSR.W	pt_RtgLmb
	BNE.S	.wait
	ADDQ.B	#1,rtg_GeoCnt
	CMPI.B	#RTG_GEOSTILL,rtg_GeoCnt
	BCS.S	.wait
	BSR.W	pt_RtgWinSnap		; stands: aspect snap first
	BEQ.S	.take
	CLR.B	rtg_GeoCnt		; snapped: wait for that size
	BRA.S	.wait
.cand:	MOVE.B	D1,rtg_GeoWide
	MOVE.W	D0,rtg_GeoW
	MOVE.W	D2,rtg_GeoH
	CLR.B	rtg_GeoCnt
	ST	rtg_GeoPend
.wait:	MOVE.B	#3,rtg_WinHeld
	ST	rtg_HoldSize		; new size: whole window after it
	BRA.W	.r
.take:	SF	rtg_GeoPend
.chg:
	DK	'G'
	MOVE.W	D0,rtg_WinW
	MOVE.W	D2,rtg_WinH
	MOVE.B	D1,rtg_Wide
	BSR.W	pt_RwdSetW		; picture width for this size
	BSR.W	pt_RwdAlloc
	BSR.W	pt_RtgWinOut		; lines of the picture for this size
	BSR.W	pt_RtgBufAlloc		;41 lut buffer first: renderer needs it
	BSR.W	pt_RprAlloc		; renderer bitmap for this size
	BSR.W	pt_RwdCheck
	TST.B	rtg_Wide
	BEQ.S	.cl
	BSR.W	pt_RwdMaps
	BRA.S	.xd
.cl:	MOVEA.L	rtg_XMap,A1
	MOVEQ	#0,D3
.x:	MOVE.L	D3,D5
	MULU	#640,D5
	DIVU	D0,D5			; src x = dst x * 640 / width
	MOVE.W	D5,(A1)+
	ADDQ.W	#1,D3
	CMP.W	D0,D3
	BLO.S	.x
.xd:	BSR.W	pt_RtgInvalidate
.r:	MOVEM.L	(A7)+,D0-D5/A0-A1
	RTS

;--- steady frames: copper list and sprites as in the last frame
; line states (plane ptrs, colors, con0) of the last full frame
RTG_STSIZE	EQU	24+2+2+64

; native line d0: state -> table
pt_RtgStSave:
	MOVEM.L	D0/A0-A1,-(A7)
	MOVE.L	rtg_RowSt,D0
	BEQ.S	.r
	MOVEA.L	D0,A1
	MOVE.W	rtg_NatRow,D0
	MULU	#RTG_STSIZE,D0
	ADDA.L	D0,A1
	LEA	rtg_BplPt,A0
	MOVEQ	#5,D0
.p:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.p
	MOVE.W	rtg_Con0,(A1)+
	ADDQ.L	#2,A1
	LEA	rtg_Colors,A0
	MOVEQ	#15,D0
.c:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.c
.r:	MOVEM.L	(A7)+,D0/A0-A1
	RTS

; native line d0: table -> state
pt_RtgStLoad:
	MOVEM.L	D0/A0-A1,-(A7)
	MOVEA.L	rtg_RowSt,A0
	MULU	#RTG_STSIZE,D0
	ADDA.L	D0,A0
	LEA	rtg_BplPt,A1
	MOVEQ	#5,D0
.p:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.p
	MOVE.W	(A0)+,rtg_Con0
	ADDQ.L	#2,A0
	LEA	rtg_Colors,A1
	MOVEQ	#15,D0
.c:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.c
	ST	rtg_ColDirty
	MOVEM.L	(A7)+,D0/A0-A1
	RTS

; sprite segments as in the last frame? d0 = 1 moved, 0 same
; with the renderer, segments inside the pattern lines (vu bars) do not
; count, except those touching the cursor bar (edit cursor)
pt_RtgSegsChk:
	MOVEM.L	D1-D5/A0-A1,-(A7)
	MOVEQ	#0,D4			; signature
	X20LEA	X20_RTGSEGS,A0
	MOVE.W	rtg_NumSegs,D1
	BRA.S	.e
.l:	MOVE.W	2(A0),D2		; y0, y1 (raster) -> native
	SUB.W	rtg_VStart,D2
	MOVE.W	4(A0),D3
	SUB.W	rtg_VStart,D3
	MOVE.W	6(A0),D5		; off the picture: never drawn
	SUB.W	rtg_DiwH,D5
	ADD.W	D5,D5
	CMP.W	#-32,D5
	BLE.S	.skip
	CMP.W	#640,D5
	BGE.S	.skip
	TST.B	rtg_RprOn
	BEQ.S	.use
	CMP.W	#620,D5			; pt's scroll thumb: the renderer draws its own
	BHS.S	.skip
	CMP.W	#RTG_PATTOP,D2		; inside the pattern lines?
	BLT.S	.use
	CMP.W	#RTG_PATEND,D3
	BGT.S	.use
	CMP.W	#RPR_BAREND+1,D2	; touching the bar: counts
	BGE.S	.skip
	CMP.W	#RPR_BARTOP+1,D3	; vu bars end on the bar top line
	BGT.S	.use
	BRA.S	.skip
.use:	ROL.L	#5,D4
	ADD.L	(A0),D4
	ROL.L	#5,D4
	ADD.L	4(A0),D4
	ROL.L	#5,D4
	ADD.L	8(A0),D4
.skip:	LEA	12(A0),A0
.e:	DBF	D1,.l
	MOVEQ	#0,D0
	CMP.L	rtg_PrevSegSig,D4
	BEQ.S	.r
	MOVE.L	D4,rtg_PrevSegSig
	MOVEQ	#1,D0
.r:	MOVEM.L	(A7)+,D1-D5/A0-A1
	RTS

; raster line d0 -> d1 = sum of the sprite data words on it
pt_RtgSprData:
	MOVEM.L	D0/D2-D3/A0-A1,-(A7)
	MOVEQ	#0,D1
	X20LEA	X20_RTGSEGS,A0
	MOVE.W	rtg_NumSegs,D3
	BRA.S	.e
.l:	CMP.W	2(A0),D0
	BLO.S	.n
	CMP.W	4(A0),D0
	BHS.S	.n
	MOVE.W	D0,D2
	SUB.W	2(A0),D2
	LSL.W	#2,D2
	MOVEA.L	8(A0),A1
	ROL.L	#3,D1
	ADD.L	(A1,D2.W),D1
.n:	LEA	12(A0),A0
.e:	DBF	D3,.l
	MOVEM.L	(A7)+,D0/D2-D3/A0-A1
	RTS

; steady frame: only lines that are hot, in the stripe or carry sprites
pt_RtgSteady:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	ST	rtg_InSteady
	TST.B	rtg_P3Moved
	BEQ.S	.s0
	MOVE.L	rtg_NewP3,D1		; pattern lines: ptr moved by the delta
	SUB.L	rtg_OldP3,D1
	MOVEA.L	rtg_RowSt,A0
	LEA	RTG_PATTOP*RTG_STSIZE+8(A0),A0
	MOVE.W	#RTG_ROWS-RTG_PATTOP-1,D0
.sd:	ADD.L	D1,(A0)
	LEA	RTG_STSIZE(A0),A0
	DBF	D0,.sd
	MOVE.L	rtg_NewP3,rtg_BplPt+8	; new row under the cursor
	BSR.W	pt_RtgPatChk
.s0:	MOVEQ	#0,D6			; native line
.l:	CMP.W	#RTG_ROWS,D6
	BHS.W	.r
	MOVE.W	D6,D5			; output line
	TST.B	rtg_PatOn
	BEQ.W	.ck
	CMP.W	#RTG_PATTOP,D6
	BLO.S	.ck
	CMP.W	#RTG_PATEND,D6
	BHS.S	.fr
	TST.B	rtg_RprOn		; renderer: pattern lines are its job
	BEQ.S	.sh
	TST.B	rtg_P3Moved		; ... but the bar lines follow the row
	BEQ.W	.nx
	CMP.W	#RPR_BARTOP,D6		; (template lines: only text, masked anyway)
	BLO.W	.nx
	CMP.W	#RPR_BAREND,D6
	BHI.W	.nx
	ADD.W	rtg_Shift,D5
	MOVE.W	D6,D0
	BSR.W	pt_RtgStLoad
	MOVE.W	D5,rtg_OutRow
	MOVEM.L	D5-D6,-(A7)
	ST	rtg_NoEmit
	MOVE.W	D6,D0
	BSR.W	pt_RtgRow
	SF	rtg_NoEmit
	MOVEM.L	(A7)+,D5-D6
	BRA.W	.nx
.sh:	ADD.W	rtg_Shift,D5
	BRA.S	.ck
.fr:	ADD.W	rtg_OutH,D5
	SUB.W	#RTG_ROWS,D5
	TST.B	rtg_RprOn		; renderer: frame lines only for real changes
	BNE.S	.ck
	TST.B	rtg_P3Moved		; frame lines carry plane 3 too
	BNE.S	.do
.ck:	X20LEA	X20_RTGHEAT,A0
	TST.B	(A0,D5.W)
	BNE.S	.do
	MOVE.W	D5,D0
	SUB.W	rtg_Stripe,D0
	AND.W	#RTG_ROWS-1,D0
	CMP.W	#RTG_STRIPE,D0
	BLO.S	.do
	MOVE.W	D6,D0
	ADD.W	rtg_VStart,D0
	CMP.W	#320,D0
	BHS.W	.nx
	X20LEA	X20_RTGSPRLN,A0
	TST.B	(A0,D0.W)
	BEQ.W	.nx
	BSR.W	pt_RtgSprData		; sprite line: only if its data changed
	RMLEA	RM_SPR,A0
	MOVE.W	D6,D2
	LSL.W	#2,D2
	CMP.L	(A0,D2.W),D1
	BEQ.W	.nx
	MOVE.L	D1,(A0,D2.W)
.do:	MOVE.W	D6,D0
	BSR.W	pt_RtgStLoad
	MOVE.W	D5,rtg_OutRow
	MOVEM.L	D5-D6,-(A7)
	MOVE.W	D6,D0
	BSR.W	pt_RtgRow
	MOVEM.L	(A7)+,D5-D6
.nx:	ADDQ.W	#1,D6
	BRA.W	.l
.r:	SF	rtg_InSteady
	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

;--- taller picture: pattern view with more rows (output > 256 lines)
; native lines from the pattern section on move down by rtg_Shift, so
; the cursor row stays in the middle; lines above and below are drawn
; from the prerendered pattern buffer (template row planes 1-2, plane 3
; from the buffer); own scroll bar over the whole pattern area

; d0.w = output lines -> cursor row position and shift
pt_RtgSetOut:
	MOVEM.L	D0-D1,-(A7)
	CMP.W	#RTG_MAXOUT,D0
	BLS.S	.m
	MOVE.W	#RTG_MAXOUT,D0
.m:	MOVE.W	D0,rtg_OutH
	SUB.W	#RTG_PATTOP,D0
	LSR.W	#4,D0			; rows / 2
	LSL.W	#3,D0
	ADD.W	#RTG_PATTOP,D0
	MOVE.W	D0,rtg_YtOut
	SUB.W	#RTG_PATCUR,D0
	MOVE.W	D0,rtg_Shift
	MOVEM.L	(A7)+,D0-D1
	RTS

; window: output lines = inner h / y factor (locked aspect), else 256
pt_RtgWinOut:
	MOVEM.L	D0-D2,-(A7)
	MOVE.W	#RTG_ROWS,D1
	CMPI.B	#2,rtg_Scale1x		; free: classic, scaled
	BEQ.S	.set
	MOVEQ	#0,D0
	MOVE.W	rtg_WinW,D0
	TST.B	rtg_Wide
	BEQ.S	.nw
	DIVU	rwd_W,D0		; wide: factor of the picture width
	BRA.S	.n0
.nw:	DIVU	#640,D0			; n
.n0:
	BEQ.S	.set
	CMPI.B	#-1,rtg_Scale1x
	BEQ.S	.px
	ADD.W	D0,D0			; amiga: 2n
.px:	MOVEQ	#0,D2
	MOVE.W	rtg_WinH,D2
	DIVU	D0,D2
	CMP.W	#RTG_ROWS,D2
	BLS.S	.set
	MOVE.W	D2,D1
.set:	MOVE.W	D1,D0
	BSR.W	pt_RtgSetOut
	MOVEM.L	(A7)+,D0-D2
	RTS

; d3.w = output line -> pt line (pattern lines back by the shift)
pt_RtgOut2Pt:
	TST.B	rtg_PatOn
	BEQ.S	.c
	CMP.W	#RTG_PATTOP,D3
	BLO.S	.c
	SUB.W	rtg_Shift,D3
	CMP.W	#RTG_PATTOP,D3
	BGE.S	.c
	MOVE.W	#RTG_PATTOP,D3
.c:	CMP.W	#RTG_ROWS-1,D3
	BLE.S	.r
	MOVE.W	#RTG_ROWS-1,D3
.r:	RTS

; copper wrote BPL3PT: pointing at a pattern row -> taller layout on
pt_RtgPatChk:
	MOVEM.L	D0-D1,-(A7)
	BSR.W	pt_RprOk		; renderer: also at classic height
	SNE	D1
	TST.L	rpr_BM
	BNE.S	.ok
	SF	D1
.ok:	TST.B	D1
	BNE.S	.go
	CMP.W	#RTG_ROWS,rtg_OutH
	BLS.S	.r
.go:	TST.W	dat_SamplerActive	; sampler: no pattern lines, the
	BNE.S	.r			; mirror draws its rows
	MOVE.B	D1,rtg_RprOn
	MOVE.L	rtg_BplPt+8,D0
	SUB.L	dat_ScreenBuf2Ptr,D0
	SUB.L	#11680,D0		; row 0 under the cursor
	BMI.S	.r
	CMP.L	#63*640,D0
	BHI.S	.r
	DIVU	#640,D0
	MOVE.L	D0,D1
	SWAP	D1
	TST.W	D1
	BNE.S	.r			; not a row start
	MOVE.W	D0,rtg_PatRow
	ST	rtg_PatOn
	MOVE.W	#$0f00,D1		; scroll thumb colors
	BSR.W	pt_RtgSprCol
	MOVE.B	D1,rtg_ThumbIdx
	MOVE.W	#$0b00,D1
	BSR.W	pt_RtgSprCol
	MOVE.B	D1,rtg_ThumbIdx+1
.r:	MOVEM.L	(A7)+,D0-D1
	RTS

; native line 150: planes, colors, con0 = template of synthetic rows
pt_RtgTplSave:
	MOVEM.L	D0/A0-A1,-(A7)
	LEA	rtg_BplPt,A0
	LEA	rtg_TplPt,A1
	MOVEQ	#5,D0
.p:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.p
	LEA	rtg_Colors,A0
	LEA	rtg_TplCol,A1
	MOVEQ	#7,D0
.c:	MOVE.W	(A0)+,(A1)+
	DBF	D0,.c
	MOVE.W	rtg_Con0,rtg_TplCon0
	ST	rtg_TplOk
	MOVEM.L	(A7)+,D0/A0-A1
	RTS

; a0 -> a1: 6 plane ptrs
pt_RtgState:
	MOVEM.L	D0,-(A7)
	MOVEQ	#5,D0
.p:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.p
	MOVEM.L	(A7)+,D0
	RTS

; after the copper walk: synthetic pattern rows, or empty lines
pt_RtgSynth:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.B	rtg_PatOn,D0
	CMP.B	rtg_PatLast,D0
	BEQ.S	.same
	MOVE.B	D0,rtg_PatLast
	BSR.W	pt_RtgInvalidate	; layout moved: every line next frame
	SF	rtg_BlankOk
.same:	TST.B	rtg_RprOn		; renderer draws the pattern section
	BNE.W	.r
	MOVE.W	rtg_OutH,D6
	CMP.W	#RTG_ROWS,D6
	BLS.W	.r
	TST.B	rtg_PatOn
	BEQ.W	.blank
	TST.B	rtg_TplOk
	BEQ.W	.r
	SF	rtg_BlankOk
	LEA	rtg_BplPt,A0		; keep the native state
	LEA	rtg_SavPt,A1
	BSR.W	pt_RtgState
	MOVE.L	rtg_Colors,rtg_SavCol
	MOVE.L	rtg_Colors+4,rtg_SavCol+4
	MOVE.L	rtg_Colors+8,rtg_SavCol+8
	MOVE.L	rtg_Colors+12,rtg_SavCol+12
	MOVE.W	rtg_Con0,rtg_SavCon0
	LEA	rtg_TplPt,A0		; template state once, bank once
	LEA	rtg_BplPt,A1
	BSR.W	pt_RtgState
	MOVE.L	rtg_TplCol,rtg_Colors
	MOVE.L	rtg_TplCol+4,rtg_Colors+4
	MOVE.L	rtg_TplCol+8,rtg_Colors+8
	MOVE.L	rtg_TplCol+12,rtg_Colors+12
	MOVE.W	rtg_TplCon0,rtg_Con0
	ST	rtg_ColDirty
	BSR.W	pt_RtgBank
	MOVE.L	D1,rtg_TplBank
	ST	rtg_NoSpr
	MOVE.W	#RTG_PATTOP,D5		; output line
.l:	CMP.W	D6,D5
	BHS.W	.done
	MOVE.W	D5,D0
	SUB.W	rtg_Shift,D0
	CMP.W	#RTG_PATTOP,D0		; inside the native band: drawn already
	BLO.S	.syn
	CMP.W	#RTG_PATEND,D0
	BLO.W	.nx
	MOVE.W	D6,D0			; bottom frame: native too
	SUBQ.W	#2,D0
	CMP.W	D0,D5
	BHS.W	.nx
.syn:	MOVE.W	D5,D0
	SUB.W	rtg_YtOut,D0
	EXT.L	D0
	MOVE.W	rtg_PatRow,D1
	LSL.W	#3,D1
	EXT.L	D1
	ADD.L	D1,D0
	ADD.L	#RTG_PATCUR-4,D0	; buffer line (row text at 194 + 8 * row)
	CMP.L	#RTG_PATCUR-4,D0	; outside rows 0-63 the buffer is
	BLT.S	.z			; panel plane or empty: blank
	CMP.L	#RTG_PATCUR-4+64*8,D0
	BHS.S	.z
	MULU	#80,D0
	ADD.L	dat_ScreenBuf2Ptr,D0
	BRA.S	.pt
.z:	MOVE.L	#rtg_Zero80,D0
.pt:	MOVE.L	D0,rtg_BplPt+8
	MOVE.W	D5,rtg_OutRow
	MOVEM.L	D5-D6,-(A7)		; pt_RtgRow keeps no registers
	MOVEQ	#-1,D0
	BSR.W	pt_RtgRow
	MOVEM.L	(A7)+,D5-D6
.nx:	ADDQ.W	#1,D5
	BRA.W	.l
.done:	SF	rtg_NoSpr
	LEA	rtg_SavPt,A0
	LEA	rtg_BplPt,A1
	BSR.W	pt_RtgState
	MOVE.L	rtg_SavCol,rtg_Colors
	MOVE.L	rtg_SavCol+4,rtg_Colors+4
	MOVE.L	rtg_SavCol+8,rtg_Colors+8
	MOVE.L	rtg_SavCol+12,rtg_Colors+12
	MOVE.W	rtg_SavCon0,rtg_Con0
	ST	rtg_ColDirty
	BRA.S	.r
.blank:	TST.B	rtg_BlankOk		; no pattern view: empty below once
	BNE.S	.r
	ST	rtg_BlankOk
	MOVE.W	#RTG_ROWS,D7
.bl:	CMP.W	D6,D7
	BHS.S	.r
	MOVEA.L	rtg_LineBuf,A0
	MOVE.W	#640/4-1,D0
.bz:	CLR.L	(A0)+
	DBF	D0,.bz
	MOVEM.L	D6-D7,-(A7)
	BSR.W	pt_RtgEmit
	MOVEM.L	(A7)+,D6-D7
	ADDQ.W	#1,D7
	BRA.S	.bl
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; taller view: scroll bar column (no native sprite) + thumb, line d7
pt_RtgScrPaint:
	TST.B	rtg_RprOn
	BNE.W	.r0
	TST.B	rtg_PatOn
	BEQ.W	.r0
	CMP.W	#RTG_PATTOP,D7
	BLO.W	.r0
	MOVE.L	D0,-(A7)
	MOVE.W	rtg_OutH,D0		; bottom frame stays
	SUBQ.W	#2,D0
	CMP.W	D0,D7
	MOVEM.L	(A7)+,D0
	BHS.S	.r0
	MOVEM.L	D0-D2/A0-A1,-(A7)
	MOVEA.L	rtg_LineBuf,A0
	LEA	624(A0),A0
	LEA	rtg_ScrCol,A1
	MOVE.W	D7,D0
	AND.W	#1,D0
	LSL.W	#4,D0
	ADDA.W	D0,A1
	MOVE.L	(A1)+,(A0)+
	MOVE.L	(A1)+,(A0)+
	MOVE.L	(A1)+,(A0)+
	MOVE.L	(A1)+,(A0)+
	MOVE.W	rtg_OutH,D1		; thumb top = 150 + row * (h - 174) / 63
	SUB.W	#RTG_PATTOP+24,D1
	MULU	rtg_PatRow,D1
	DIVU	#63,D1
	ADD.W	#RTG_PATTOP,D1
	MOVE.W	D7,D0
	SUB.W	D1,D0
	BMI.S	.r
	CMP.W	#24,D0
	BHS.S	.r
	MOVEA.L	rtg_LineBuf,A0
	LEA	627(A0),A0
	MOVE.B	rtg_ThumbIdx,D1
	MOVE.B	rtg_ThumbIdx+1,D2
	CMP.W	#23,D0
	BNE.S	.t
	MOVE.B	D2,D1			; last line dark
.t:	MOVEQ	#8,D0
.tl:	MOVE.B	D1,(A0)+
	DBF	D0,.tl
	MOVE.B	D2,(A0)			; right edge dark
.r:	MOVEM.L	(A7)+,D0-D2/A0-A1
.r0:	RTS

; aspect lock: 1x size of the picture -> d0 w, d1 h (inner)
pt_RtgBase:
	MOVE.L	#640,D0
	MOVE.L	#512,D1			; amiga 1:2
	CMPI.B	#-1,rtg_Scale1x
	BNE.S	.r
	MOVE.L	#256,D1			; pixel 1:1
.r:	RTS

; aspect lock: inner size -> nearest integer factor of the 1x size
; that fits the screen; z=0 when the window was resized
pt_RtgWinSnap:
	MOVEM.L	D0-D7/A0-A1/A6,-(A7)
	CMPI.B	#2,rtg_Scale1x		; free
	BEQ.W	.no
	BSR.W	pt_RtgLmb		; lmb held: still sizing
	BNE.W	.no
	MOVEA.L	rtg_Window,A0
	MOVEQ	#0,D4
	MOVEQ	#0,D5
	MOVE.B	54(A0),D4
	ADD.B	56(A0),D4		; border w
	MOVE.B	55(A0),D5
	ADD.B	57(A0),D5		; border h
	MOVE.W	8(A0),D6
	SUB.W	D4,D6			; inner w
	MOVE.W	10(A0),D7
	SUB.W	D5,D7			; inner h
	BSR.S	pt_RtgBase
	MOVE.L	D0,D2
	MOVE.L	D1,D3
	MOVEQ	#0,D0
	MOVE.W	D6,D0
	ADD.L	#320,D0
	DIVU	#640,D0			; n = round(w / 640)
	BNE.S	.n1
	MOVEQ	#1,D0
.n1:	MOVEA.L	46(A0),A1		; WScreen
	MOVE.W	D6,-(A7)		; real inner w for the compare below
	BSR.W	pt_TrkGrow		; new wide module: as wide as needed
	BSR.W	pt_RwdSnap		; 8 tracks wide: d0, d2 for 1280
	MOVE.W	(A7)+,D6
	TST.B	rtg_WideWant
	BNE.S	.got
.fit:	CMP.W	#1,D0
	BLS.S	.got
	MOVE.W	D2,D1
	MULU	D0,D1
	ADD.L	D4,D1
	CMP.W	12(A1),D1		; Screen->Width
	BHI.S	.less
	MOVE.W	D3,D1
	MULU	D0,D1
	ADD.L	D5,D1
	CMP.W	14(A1),D1		; Screen->Height
	BLS.S	.got
.less:	SUBQ.W	#1,D0
	BRA.S	.fit
.got:	MULU	D0,D2			; target inner w
	MOVE.W	D3,D1
	LSR.W	#8,D1			; 2 amiga, 1 pixel
	MULU	D0,D1			; y factor
	MOVEQ	#0,D3
	MOVE.W	D7,D3
	MOVE.B	rtg_RowsReq,D0		; rows from the setup page
	BEQ.S	.nrq
	SF	rtg_RowsReq
	EXT.W	D0
	LSL.W	#3,D0
	MULS	D1,D0
	ADD.W	D0,D3
	BPL.S	.nrq
	MOVEQ	#0,D3
.nrq:
	DIVU	D1,D3			; lines of the picture
	AND.L	#$ffff,D3
	SUB.W	#RTG_ROWS-4,D3		; extra pattern rows, rounded
	BPL.S	.k0
	MOVEQ	#0,D3
.k0:	LSR.W	#3,D3
	CMP.W	#RTG_KMAX,D3
	BLS.S	.k1
	MOVEQ	#RTG_KMAX,D3
.k1:	LSL.W	#3,D3
	ADD.W	#RTG_ROWS,D3
.kf:	MOVE.W	D3,-(A7)		; fewer rows until it fits the screen
	MULU	D1,D3
	MOVE.L	D3,-(A7)
	ADD.L	D5,D3
	CMP.W	14(A1),D3
	MOVEM.L	(A7)+,D3		; flags stay
	BLS.S	.kok
	MOVE.W	(A7)+,D3
	CMP.W	#RTG_ROWS,D3
	BLS.S	.kmin
	SUBQ.W	#8,D3
	BRA.S	.kf
.kmin:	MULU	D1,D3
	BRA.S	.cmp
.kok:	ADDQ.L	#2,A7
.cmp:	CMP.W	D2,D6
	BNE.S	.set
	CMP.W	D3,D7
	BEQ.S	.no
.set:	ADD.W	D4,D2			; outer w
	ADD.W	D5,D3			; outer h
	MOVE.W	4(A0),D0		; left/top: keep, but on the screen
	BPL.S	.l0			; (never off its left/top edge)
	MOVEQ	#0,D0
.l0:	MOVE.W	12(A1),D1
	SUB.W	D2,D1
	BPL.S	.l1
	MOVEQ	#0,D1
.l1:	CMP.W	D1,D0
	BLE.S	.l2
	MOVE.W	D1,D0
.l2:	MOVE.W	6(A0),D1
	BPL.S	.t0
	MOVEQ	#0,D1
.t0:	MOVE.W	14(A1),D7
	SUB.W	D3,D7
	BPL.S	.t1
	MOVEQ	#0,D7
.t1:	CMP.W	D7,D1
	BLE.S	.t2
	MOVE.W	D7,D1
.t2:	EXT.L	D0
	EXT.L	D1
	EXT.L	D2
	EXT.L	D3
	MOVEA.L	dat_IntuiLibBase,A6
	DK	'S'
	JSR	(-486,A6)		; ChangeWindowBox
	MOVEM.L	(A7)+,D0-D7/A0-A1/A6
	MOVEQ	#1,D0			; z=0: resized
	RTS
.no:	MOVEM.L	(A7)+,D0-D7/A0-A1/A6
	CMP.B	D0,D0			; z=1
	RTS

; aspect lock: no window below 1x
pt_RtgWinLimits:
	MOVEM.L	D0-D3/A0-A1/A6,-(A7)
	CMPI.B	#2,rtg_Scale1x
	BEQ.S	.r
	BSR.W	pt_RtgBase
	MOVEA.L	rtg_Window,A0
	MOVEQ	#0,D2
	MOVE.B	54(A0),D2
	ADD.B	56(A0),D2
	ADD.L	D2,D0
	MOVE.B	55(A0),D2
	ADD.B	57(A0),D2
	ADD.L	D2,D1
	MOVEQ	#0,D2			; max: unchanged
	MOVEQ	#0,D3
	MOVEA.L	dat_IntuiLibBase,A6
	JSR	(-318,A6)		; WindowLimits
.r:	MOVEM.L	(A7)+,D0-D3/A0-A1/A6
	RTS

; saved window box -> open tags (left/top only when a size was saved);
; d7 = screen: size and place are clamped to it (negative = edge)
pt_RtgBoxTags:
	MOVEM.L	D0-D4/A0-A1,-(A7)
	LEA	rtg_PubBox,A0
	MOVE.W	prf_WinBox+4,D0
	BLE.S	.r
	MOVE.W	prf_WinBox+6,D1
	BLE.S	.r
	MOVEA.L	D7,A1
	MOVE.W	12(A1),D2		; Screen->Width
	MOVE.W	14(A1),D3		; Screen->Height
	CMP.W	D2,D0
	BLS.S	.w1
	MOVE.W	D2,D0
.w1:	CMP.W	D3,D1
	BLS.S	.h1
	MOVE.W	D3,D1
.h1:	SUB.W	D0,D2			; furthest left / top
	SUB.W	D1,D3
	MOVE.W	prf_WinBox,D4
	BPL.S	.l1
	MOVEQ	#0,D4
.l1:	CMP.W	D2,D4
	BLE.S	.l2
	MOVE.W	D2,D4
.l2:	MOVE.L	#WA_Left_,(A0)
	MOVE.W	D4,6(A0)
	MOVE.W	prf_WinBox+2,D4
	BPL.S	.t1
	MOVEQ	#0,D4
.t1:	CMP.W	D3,D4
	BLE.S	.t2
	MOVE.W	D3,D4
.t2:	MOVE.L	#WA_Top_,8(A0)
	MOVE.W	D4,14(A0)
	MOVE.W	D0,22(A0)		; WA_InnerWidth
	MOVE.W	D1,30(A0)		; WA_InnerHeight
.r:	MOVEM.L	(A7)+,D0-D4/A0-A1
	RTS

; running window -> prf_WinBox (SAVE CONFIG)
pt_RtgWinBox:
	MOVEM.L	D0/A1,-(A7)
	TST.L	rtg_Proc
	BEQ.S	.r
	TST.B	rtg_RunWin
	BEQ.S	.r
	MOVE.L	rtg_Window,D0
	BEQ.S	.r
	MOVEA.L	D0,A1
	MOVE.L	4(A1),prf_WinBox	; LeftEdge, TopEdge
	MOVE.L	rtg_WinW,prf_WinBox+4	; inner w, h
.r:	MOVEM.L	(A7)+,D0/A1
	RTS

; row d7 (640 px) scaled to win rows d7*H/256..(d7+1)*H/256-1
pt_RtgWinRow:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	TST.B	rtg_Wide
	BEQ.S	.nw
	BSR.W	pt_RwdStage
.nw:	TST.B	rtg_PalDirty		; new colors (bank/spr) before writing table
	BEQ.S	.pal
	BSR.W	pt_RtgCTab
	ST	rtg_BlitAll		; lut buffer: all pixels change color
.pal:	MOVEQ	#0,D0
	MOVE.W	D7,D0
	MULU	rtg_WinH,D0
	DIVU	rtg_OutH,D0		; first dst row
	AND.L	#$ffff,D0
	MOVEQ	#0,D6
	MOVE.W	D7,D6
	ADDQ.W	#1,D6
	MULU	rtg_WinH,D6
	DIVU	rtg_OutH,D6
	AND.L	#$ffff,D6
	SUB.L	D0,D6			; dst row cnt (0 when shrunk)
	BEQ.W	.r
	MOVE.L	D0,D4
	TST.L	rtg_LutBuf
	BNE.W	.lut
	MOVEA.L	rtg_LineBuf,A0		; scale horizontally, color lookup -> rgb (3 bytes/px)
	MOVEA.L	rtg_ScaleBuf,A1
	BSR.W	pt_RwdXMap
	X20LEA	X20_RTGCTAB,A4
	MOVE.W	rtg_WinW,D2
	SUBQ.W	#1,D2
	MOVEQ	#0,D3
	MOVEQ	#0,D1
.s:	MOVE.W	(A2)+,D3
	MOVE.B	(A0,D3.L),D1
	MOVE.W	D1,D0
	LSL.W	#2,D0
	MOVE.L	(A4,D0.W),D5		; $00RRGGBB
	SWAP	D5
	MOVE.B	D5,(A1)+		; R
	ROL.L	#8,D5
	MOVE.B	D5,(A1)+		; G
	ROL.L	#8,D5
	MOVE.B	D5,(A1)+		; B
	DBF	D2,.s
	SUBQ.W	#1,D6
	MOVEA.L	rtg_Window,A3
	MOVEQ	#0,D0
	MOVE.B	55(A3),D0		; BorderTop
	ADD.L	D0,D4
	MOVEA.L	124(A3),A5		; Window->WLayer
	BSR.W	pt_RtgPriUp
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-654,A6)		; AttemptLockLayerRom: never wait on a layer intuition holds (drag/size)
	TST.L	D0
	BNE.S	.y
	BSR.W	pt_RtgPriDown
	BSR.W	pt_RtgInvalidate	; busy -> skip, whole window again next frame
	BRA.W	.r
.y:	MOVEM.L	D4/D6,-(A7)
	MOVEA.L	rtg_ScaleBuf,A0		; srcRect
	MOVEQ	#0,D0			; SrcX
	MOVEQ	#0,D1			; SrcY
	MOVEQ	#0,D2
	MOVE.W	rtg_WinW,D2
	MULU	#3,D2			; SrcMod (bytes/row)
	MOVEA.L	50(A3),A1		; Window->RPort
	MOVEQ	#0,D3
	MOVE.B	54(A3),D3		; DestX = BorderLeft
	MOVEQ	#0,D5
	MOVE.W	rtg_WinW,D5		; SizeX
	MOVEQ	#1,D6			; SizeY
	MOVEQ	#0,D7			; RECTFMT_RGB
	MOVEA.L	rtg_CgxBase,A6
	JSR	(-126,A6)		; WritePixelArray (cybergraphics V40)
	MOVEM.L	(A7)+,D4/D6
	ADDQ.L	#1,D4
	DBF	D6,.y
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-438,A6)		; UnlockLayerRom (a5 = layer)
	BSR.W	pt_RtgPriDown
	ADDQ.L	#1,rtg_Lines
	BRA.W	.r
.lut:	SUBQ.W	#1,D6			; lut buffer: scale into ram, write what changed
	MOVEQ	#0,D5
	MOVE.W	rtg_WinW,D5		; bytes per row
	MOVE.L	D4,D0
	MULU	D5,D0
	MOVEA.L	rtg_LutBuf,A6
	ADDA.L	D0,A6			; first dst row
	MOVEA.L	rtg_LineBuf,A0
	BSR.W	pt_RwdXMap
	MOVEA.L	rtg_ScaleBuf,A1		; new row first, the buffer keeps the old one
	MOVEA.L	A1,A4
	MOVE.W	D5,D2
	SUBQ.W	#1,D2
	MOVEQ	#0,D3
.lx:	MOVE.W	(A2)+,D3
	MOVE.B	(A0,D3.L),(A1)+
	DBF	D2,.lx
	MOVEA.L	A4,A0			; new row against the old one, chunk by chunk
	MOVEA.L	A6,A1
	MOVEQ	#0,D3			; chunks that differ
	MOVEQ	#0,D1			; chunk
.ck:	MOVE.W	rtg_ChunkW,D0		; bytes of this chunk
	MOVE.W	rtg_NChunk,D2
	SUBQ.W	#1,D2
	CMP.W	D2,D1
	BNE.S	.ck1
	MOVE.W	rtg_LastChunkW,D0
.ck1:	MOVEA.L	A0,A5			; chunk starts
	MOVEA.L	A1,A2
	MOVE.W	D0,D2
	LSR.W	#2,D2
	BEQ.S	.ckb
	SUBQ.W	#1,D2
.ckl:	CMPM.L	(A0)+,(A1)+
	DBNE	D2,.ckl
	BNE.S	.ckd
.ckb:	MOVE.W	D0,D2
	AND.W	#3,D2
	BEQ.S	.ckn
	SUBQ.W	#1,D2
.ckc:	CMPM.B	(A0)+,(A1)+
	DBNE	D2,.ckc
	BEQ.S	.ckn
.ckd:	BSET	D1,D3			; differs: into every dst row of this line
	MOVEA.L	A2,A1
	MOVE.W	D6,D2
.cd1:	MOVEA.L	A5,A0
	MOVE.W	D0,D7
	LSR.W	#2,D7
	BRA.S	.cd3
.cd2:	MOVE.L	(A0)+,(A1)+
.cd3:	DBF	D7,.cd2
	MOVE.W	D0,D7
	AND.W	#3,D7
	BRA.S	.cd5
.cd4:	MOVE.B	(A0)+,(A1)+
.cd5:	DBF	D7,.cd4
	SUBA.W	D0,A1			; next dst row, same chunk
	ADDA.L	D5,A1
	DBF	D2,.cd1
	MOVEA.L	A5,A0			; behind the chunk in the new and the first old row
	ADDA.W	D0,A0
	MOVEA.L	A2,A1
	ADDA.W	D0,A1
.ckn:	ADDQ.W	#1,D1
	CMP.W	rtg_NChunk,D1
	BLO.W	.ck
	ADDQ.L	#1,rtg_Lines
	TST.L	D3
	BEQ.S	.r			; same pixels as shown: nothing to write
	MOVEA.L	rtg_DirtyTab,A0		; dirty chunks of these dst rows
	MOVE.L	D4,D0
	LSL.L	#2,D0
	ADDA.L	D0,A0
	MOVE.W	D6,D2
.mk:	OR.L	D3,(A0)+
	DBF	D2,.mk
	CMP.W	rtg_DirtyY0,D4
	BGE.S	.l0
	MOVE.W	D4,rtg_DirtyY0
.l0:	MOVE.W	D4,D0
	ADD.W	D6,D0
	CMP.W	rtg_DirtyY1,D0
	BLE.S	.r
	MOVE.W	D0,rtg_DirtyY1
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; lut buffer -> window, one WriteLUTPixelArray per frame; busy: keep band
pt_RtgWinBlit:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	DK	'W'
	TST.L	rtg_LutBuf
	BEQ.W	.r
	MOVE.W	rtg_DirtyY0,D1
	MOVE.W	rtg_DirtyY1,D6
	TST.B	rtg_BlitAll
	BEQ.W	.b
	IFD	DEBUGAUTO
	ADDQ.L	#1,rtg_ProfN
	TST.B	rtg_RprOn
	BEQ.S	.da
	ADDQ.L	#1,rtg_ProfN+12
.da:
	ENDC
	MOVEQ	#0,D1
	MOVE.W	rtg_WinH,D6
	SUBQ.W	#1,D6
	BSR.W	.mka			; every line, every chunk
	TST.B	rtg_RprOn		; renderer: its area is not in the lut
	BEQ.S	.al			; buffer, all but it as dirty lines
	TST.L	rpr_BM
	BEQ.S	.al
	MOVE.W	D1,rtg_DirtyY0
	MOVE.W	D6,rtg_DirtyY1
	SF	rtg_BlitAll
	ST	rpr_Force
	BRA.S	.b
.al:	BSR.W	.put
	BNE.W	.r
	ST	rpr_Force		; whole window written: pattern area again
	SF	rtg_BlitAll
	BRA.W	.done
.b:	CMP.W	D1,D6
	BLT.W	.r
	TST.B	rtg_RprOn		; renderer: its area stays out, else a
	BEQ.W	.one			; mirror frame would show over it
	TST.L	rpr_BM
	BEQ.W	.one
	MOVE.W	#RTG_PATTOP,D2
	MULU	rpr_YF,D2		; first line of the renderer area
	MOVE.W	rpr_N,D3
	MULU	rpr_RowH,D3
	ADD.W	D2,D3			; first line below it
	CMP.W	D2,D6
	BLT.W	.one			; all above
	CMP.W	D3,D1
	BGE.W	.one			; all below
	DK	'O'
	MOVEM.W	D3/D6,-(A7)
	MOVE.W	D2,D6			; part above
	SUBQ.W	#1,D6
	CMP.W	D1,D6
	BLT.W	.na
	BSR.W	.put
	BEQ.W	.na
	ADDQ.L	#4,A7			; layer busy: all again next frame
	BRA.W	.r
.na:	MOVEM.W	(A7)+,D1/D6		; part below
	CMP.W	D1,D6
	BLT.W	.done
.one:	BSR.W	.put
	BNE.W	.r
.done:	BSR.W	.clr
	MOVE.W	#$7fff,rtg_DirtyY0
	CLR.W	rtg_DirtyY1
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS
; lines d1..d6 of the lut buffer -> window; z=0: layer busy
.put:	MOVEM.L	D0-D7/A0-A6,-(A7)
.band:	MOVE.W	D6,-(A7)		; bands: intuition waits one at most
	MOVE.W	D1,D0
	ADD.W	#RTG_BAND-1,D0
	CMP.W	D6,D0
	BGE.S	.bl
	MOVE.W	D0,D6
.bl:	BSR.S	.put1
	MOVEM.W	(A7)+,D6		; (flags kept)
	BNE.S	.pb2			; busy: all again next frame
	ADD.W	#RTG_BAND,D1
	CMP.W	D6,D1
	BLE.S	.band
	MOVEM.L	(A7)+,D0-D7/A0-A6
	CMP.B	D0,D0			; z=1
	RTS
.pb2:	MOVEM.L	(A7)+,D0-D7/A0-A6
	ANDI.B	#$fb,CCR		; z=0
	RTS
; one band d1..d6: its dirty rects only, under one layer lock
.put1:	MOVEM.L	D0-D7/A0-A6,-(A7)
	LEA	rtg_PlanR,A0
	BSR.W	pt_RtgPlan		; d0 = rects (d1, d6 kept)
	TST.W	D0
	BEQ.W	.p1c			; clean band: no lock
	MOVE.W	D0,-(A7)
	MOVEM.W	D1/D6,-(A7)		; 0 first line, 2 last line, 4 rects left
	MOVEA.L	rtg_Window,A3
	MOVEA.L	124(A3),A5		; Window->WLayer
	BSR.W	pt_RtgPriUp
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-654,A6)		; AttemptLockLayerRom
	TST.L	D0
	BEQ.W	.pb			; intuition busy: next frame
	LEA	rtg_PlanR,A4
.pr:	MOVEQ	#0,D0
	MOVE.W	(A4),D0			; SrcX
	MOVEQ	#0,D1
	MOVE.W	2(A4),D1		; SrcY
	MOVEQ	#0,D5
	MOVE.W	4(A4),D5		; SizeX
	MOVEQ	#0,D6
	MOVE.W	6(A4),D6		; SizeY
	MOVEQ	#0,D2
	MOVE.W	rtg_WinW,D2		; SrcMod
	MOVEQ	#0,D3
	MOVE.B	54(A3),D3
	ADD.L	D0,D3			; DestX = BorderLeft + x
	MOVEQ	#0,D4
	MOVE.B	55(A3),D4
	ADD.L	D1,D4			; DestY = BorderTop + y
	MOVEA.L	rtg_LutBuf,A0
	MOVEA.L	50(A3),A1		; Window->RPort
	X20LEA	X20_RTGCTAB,A2		; $00rrggbb
	MOVEQ	#0,D7			; CTABFMT_XRGB8
	MOVEA.L	rtg_CgxBase,A6
	JSR	(-198,A6)		; WriteLUTPixelArray
	ADDQ.L	#8,A4
	SUBQ.W	#1,4(A7)
	BNE.S	.pr
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-438,A6)		; UnlockLayerRom
	BSR.W	pt_RtgPriDown
	MOVEA.L	rtg_DirtyTab,A0		; band written: its lines are clean
	MOVEQ	#0,D0
	MOVE.W	(A7),D0
	LSL.L	#2,D0
	ADDA.L	D0,A0
	MOVE.W	2(A7),D2
	SUB.W	(A7),D2
.pm:	CLR.L	(A0)+
	DBF	D2,.pm
	ADDQ.L	#6,A7
.p1c:	MOVEM.L	(A7)+,D0-D7/A0-A6
	CMP.B	D0,D0			; z=1
	RTS
.pb:	BSR.W	pt_RtgPriDown
	ADDQ.L	#6,A7
	MOVEM.L	(A7)+,D0-D7/A0-A6
	ANDI.B	#$fb,CCR		; z=0
	RTS
; whole window dirty: every chunk of every line
.mka:	MOVEM.L	D0/D2/A0,-(A7)
	MOVEA.L	rtg_DirtyTab,A0
	MOVE.W	rtg_WinH,D2
	SUBQ.W	#1,D2
	MOVEQ	#-1,D0
.mkl:	MOVE.L	D0,(A0)+
	DBF	D2,.mkl
	CLR.W	rtg_DirtyY0
	MOVE.W	rtg_WinH,rtg_DirtyY1
	SUBQ.W	#1,rtg_DirtyY1
	MOVEM.L	(A7)+,D0/D2/A0
	RTS
; no dirty chunks left in the lines of the span (what the window shows
; of the renderer area is not from the buffer)
.clr:	MOVEM.L	D0/D2/A0,-(A7)
	MOVE.W	rtg_DirtyY1,D2
	SUB.W	rtg_DirtyY0,D2
	BLT.S	.clx
	MOVEQ	#0,D0
	MOVE.W	rtg_DirtyY0,D0
	LSL.L	#2,D0
	MOVEA.L	rtg_DirtyTab,A0
	ADDA.L	D0,A0
.clc:	CLR.L	(A0)+
	DBF	D2,.clc
.clx:	MOVEM.L	(A7)+,D0/D2/A0
	RTS

; band d1..d6 (RTG_BAND lines at most) -> rects (x, y, w, h words) at a0:
; the dirty chunks of RTG_TILE lines each; a run of chunks that is dirty
; in the next tiles as well makes one taller rect. d0 = rects (RTG_RECTS
; at most)
pt_RtgPlan:
	MOVEM.L	D1-D7/A0-A3,-(A7)
	MOVEA.L	A0,A3
	MOVEA.L	rtg_DirtyTab,A1
	MOVEQ	#0,D0
	MOVE.W	D1,D0
	LSL.L	#2,D0
	ADDA.L	D0,A1			; mask of the first line
	LEA	rtg_PlanU,A2
	MOVE.W	D6,D2
	SUB.W	D1,D2
	ADDQ.W	#1,D2			; lines
	MOVEQ	#0,D7			; tiles
.tl:	MOVEQ	#0,D3
	MOVEQ	#RTG_TILE-1,D4
.tu:	OR.L	(A1)+,D3
	SUBQ.W	#1,D2
	BLE.S	.te
	DBF	D4,.tu
.te:	MOVE.L	D3,(A2)+
	ADDQ.W	#1,D7
	TST.W	D2
	BGT.S	.tl
	ADDQ.W	#1,D6			; end line + 1
	MOVEQ	#0,D5			; tile
	LEA	rtg_PlanU,A1
.et:	MOVE.L	(A1),D3
.run:	TST.L	D3
	BEQ.W	.nt
	MOVE.L	D3,D0			; lowest run of set chunks
	NEG.L	D0
	AND.L	D3,D0
	ADD.L	D3,D0
	NOT.L	D0
	AND.L	D3,D0
	MOVEQ	#0,D4
.f0:	BTST	D4,D0
	BNE.S	.f1
	ADDQ.W	#1,D4
	BRA.S	.f0
.f1:	MOVE.W	D4,D2
.f2:	ADDQ.W	#1,D2
	CMP.W	#32,D2
	BHS.S	.f3
	BTST	D2,D0
	BNE.S	.f2
.f3:	MULU	rtg_ChunkW,D4		; x of the first chunk
	MULU	rtg_ChunkW,D2		; end of the last one
	CMP.W	rtg_WinW,D2
	BLS.S	.f4
	MOVE.W	rtg_WinW,D2
.f4:	SUB.W	D4,D2
	MOVE.W	D4,(A3)
	MOVE.W	D2,4(A3)
	MOVE.L	D0,D4			; run done in this tile
	NOT.L	D4
	AND.L	D4,D3
	MOVE.W	D5,D2
	ADDQ.W	#1,D2			; next tiles that have all of it
	LEA	4(A1),A2
.ex:	CMP.W	D7,D2
	BHS.S	.ed
	MOVE.L	(A2),D4
	AND.L	D0,D4
	CMP.L	D0,D4
	BNE.S	.ed
	MOVE.L	D0,D4
	NOT.L	D4
	AND.L	D4,(A2)+
	ADDQ.W	#1,D2
	BRA.S	.ex
.ed:	MOVE.W	D5,D4			; y = first line + tile * RTG_TILE
	LSL.W	#3,D4
	ADD.W	D1,D4
	LSL.W	#3,D2			; end = first line + tile * RTG_TILE, in the band
	ADD.W	D1,D2
	CMP.W	D6,D2
	BLS.S	.e1
	MOVE.W	D6,D2
.e1:	SUB.W	D4,D2
	MOVE.W	D4,2(A3)
	MOVE.W	D2,6(A3)
	ADDQ.L	#8,A3
	BRA.W	.run
.nt:	ADDQ.L	#4,A1
	ADDQ.W	#1,D5
	CMP.W	D7,D5
	BLO.W	.et
	MOVE.L	A3,D0
	SUB.L	A0,D0
	LSR.L	#3,D0
	MOVEM.L	(A7)+,D1-D7/A0-A3
	RTS

; layer lock held: just below input.device, which drags the window
; and may wait for it; at pri 0 every busy task would preempt the
; holder and the gui stands still
pt_RtgPriUp:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVEA.L	ABSEXECBASE.W,A6
	MOVEA.L	276(A6),A1		; ThisTask
	MOVEQ	#19,D0
	JSR	(-300,A6)		; SetTaskPri
	MOVE.B	D0,rtg_PriOld
	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS
pt_RtgPriDown:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVEA.L	ABSEXECBASE.W,A6
	MOVEA.L	276(A6),A1
	CMPI.B	#19,9(A1)		; changed from outside meanwhile: keep it
	BNE.S	.r
	MOVE.B	rtg_PriOld,D0
	EXT.W	D0
	EXT.L	D0
	JSR	(-300,A6)		; SetTaskPri
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

; (re)alloc lut buffer rtg_WinW x rtg_WinH (cgx 41+), else direct rows;
; behind the pixels a long per line: its dirty chunks
pt_RtgBufAlloc:
	MOVEM.L	D0-D3/A0-A1/A6,-(A7)
	BSR.W	pt_RtgBufFree
	MOVEA.L	rtg_CgxBase,A0
	CMPI.W	#41,20(A0)		; lib_Version: WriteLUTPixelArray
	BLO.W	.r
	MOVEQ	#0,D0
	MOVE.W	rtg_WinW,D0
	MULU	rtg_WinH,D0
	ADDQ.L	#3,D0
	AND.L	#$fffffffc,D0
	MOVE.L	D0,D2			; offset of the dirty table
	MOVEQ	#0,D1
	MOVE.W	rtg_WinH,D1
	LSL.L	#2,D1
	ADD.L	D1,D0
	MOVE.L	D0,rtg_LutSize
	MOVE.L	#$10001,D1		; MEMF_PUBLIC|MEMF_CLEAR: rows the copper skips stay black
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-198,A6)		; AllocMem
	MOVE.L	D0,rtg_LutBuf
	BEQ.S	.r
	ADD.L	D2,D0
	MOVE.L	D0,rtg_DirtyTab
	MOVE.W	rtg_WinW,D0		; chunks: 32 at most, a multiple of 4 px wide
	ADD.W	#31,D0
	LSR.W	#5,D0
	ADDQ.W	#3,D0
	AND.W	#$fffc,D0
	MOVE.W	D0,rtg_ChunkW
	MOVEQ	#0,D1
	MOVE.W	rtg_WinW,D1
	ADD.W	D0,D1
	SUBQ.W	#1,D1
	DIVU	D0,D1
	MOVE.W	D1,rtg_NChunk
	SUBQ.W	#1,D1
	MULU	D0,D1
	MOVE.W	rtg_WinW,D3
	SUB.W	D1,D3
	MOVE.W	D3,rtg_LastChunkW
	ST	rtg_BlitAll
.r:	MOVE.W	#$7fff,rtg_DirtyY0
	CLR.W	rtg_DirtyY1
	MOVEM.L	(A7)+,D0-D3/A0-A1/A6
	RTS

pt_RtgBufFree:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVE.L	rtg_LutBuf,D0
	BEQ.S	.r
	MOVEA.L	D0,A1
	MOVE.L	rtg_LutSize,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-210,A6)		; FreeMem
	CLR.L	rtg_LutBuf
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

; simple refresh: parts shown again (window moved off them) are
; damaged; clear the damage and draw the whole window again
pt_RtgDamage:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVEA.L	rtg_Window,A0
	MOVEA.L	124(A0),A1		; Window->WLayer
	BTST	#7,31(A1)		; Layer->Flags LAYERREFRESH
	BEQ.S	.r
	MOVEA.L	dat_IntuiLibBase,A6
	JSR	(-354,A6)		; BeginRefresh
	MOVEA.L	rtg_Window,A0
	MOVEQ	#1,D0
	JSR	(-366,A6)		; EndRefresh(complete)
	BSR.S	pt_RtgWinRedraw
	ST	rpr_Force
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

; whole window again: lut buffer still holds it, else convert anew
pt_RtgWinRedraw:
	TST.L	rtg_LutBuf
	BEQ.W	pt_RtgInvalidate
	ST	rtg_BlitAll
	RTS

; color table: banks + spr colors (SprNext+1..255), $0RGB -> $00RRGGBB
pt_RtgCTab:
	ST	rpr_TplNew		; renderer: colors are in the card bitmap
	MOVEM.L	D0-D2/A0-A1,-(A7)
	X20LEA	X20_RTGCTAB,A0
	X20LEA	X20_RTGBANKS,A1
	MOVE.W	rtg_NumBanks,D0
	LSL.W	#3,D0
	SUBQ.W	#1,D0
	BMI.S	.spr
.b:	MOVE.W	(A1)+,D1
	BSR.S	.x
	MOVE.L	D1,(A0)+
	DBF	D0,.b
.spr:	MOVE.W	rtg_SprNext,D0
	ADDQ.W	#1,D0
.s:	CMP.W	#255,D0
	BHI.S	.r
	X20LEA	X20_RTGSPRRGB,A1
	MOVE.W	D0,D2
	ADD.W	D2,D2
	MOVE.W	(A1,D2.W),D1
	BSR.S	.x
	X20LEA	X20_RTGCTAB,A0
	ADD.W	D2,D2
	MOVE.L	D1,(A0,D2.W)
	ADDQ.W	#1,D0
	BRA.S	.s
.r:	MOVEM.L	(A7)+,D0-D2/A0-A1
	RTS
.x:	MOVEM.L	D0/D2,-(A7)		; d1=$0RGB -> $00RRGGBB (nibble * 17)
	MOVE.W	D1,D2
	LSR.W	#8,D2
	AND.L	#15,D2
	MULU	#17,D2
	SWAP	D2			; R << 16
	MOVE.L	D2,D0
	MOVE.W	D1,D2
	LSR.W	#4,D2
	AND.L	#15,D2
	MULU	#17,D2
	LSL.L	#8,D2			; G << 8
	OR.L	D2,D0
	MOVE.W	D1,D2
	AND.L	#15,D2
	MULU	#17,D2			; B
	OR.L	D2,D0
	MOVE.L	D0,D1
	MOVEM.L	(A7)+,D0/D2
	RTS

; hook/unhook input wrap (is_Code of pt handler)
pt_RtgInHook:
	CMPI.L	#pt_RtgInWrap,dat_InputIntStruct+18
	BEQ.S	.r
	MOVE.L	dat_InputIntStruct+18,rtg_InOrig
	MOVE.L	#pt_RtgInWrap,dat_InputIntStruct+18
.r:	RTS
pt_RtgInUnhook:
	CMPI.L	#pt_RtgInWrap,dat_InputIntStruct+18
	BNE.S	.r
	MOVE.L	rtg_InOrig,dat_InputIntStruct+18
.r:	RTS

; input wrap (input.device): a0=event chain a1=is_Data -> d0
; pt handler takes single events only -> pass one by one
pt_RtgInWrap:
	TST.B	rtg_RunWin
	BEQ.S	.orig
	TST.L	rtg_Window
	BNE.S	.win
.orig:	MOVE.L	rtg_InOrig,-(A7)
	RTS
.win:	MOVEM.L	D1-D7/A1-A6,-(A7)
	MOVEA.L	A0,A2			; lmb from the events: usb, tablet, remote
.lm:	MOVE.L	A2,D0			; (button codes may be taken by a handler
	BEQ.S	.lmd			; above us, the qualifier stays)
	MOVE.B	4(A2),D0
	CMP.B	#2,D0			; IECLASS_RAWMOUSE
	BEQ.S	.lq
	CMP.B	#$13,D0			; IECLASS_NEWPOINTERPOS
	BNE.S	.lmn
.lq:	MOVE.W	6(A2),D0
	CMP.W	#$68,D0			; IECODE_LBUTTON
	BEQ.S	.ldn
	CMP.W	#$e8,D0			; released
	BEQ.S	.lup
	BTST	#6,8(A2)		; IEQUALIFIER_LEFTBUTTON
	BEQ.S	.lup
.ldn:	TST.B	rtg_LmbEv
	BNE.S	.lmn
	ST	rtg_LmbEv		; pressed now: on our frame?
	BSR.W	pt_RtgOnFrame
	SNE	rtg_SysDrag
	BRA.S	.lmn
.lup:	SF	rtg_LmbEv
	SF	rtg_SysDrag
.lmn:	MOVEA.L	(A2),A2
	BRA.S	.lm
.lmd:	MOVEA.L	A1,A5			; is_Data
	MOVE.L	A0,D6			; head of new chain
	MOVEQ	#0,D4			; mouse move for pt
	MOVEQ	#0,D5
	MOVEQ	#1,D7			; blocked
	MOVEQ	#1,D1			; keys blocked
	MOVEA.L	dat_IntuiLibBase,A6
	MOVEA.L	rtg_Window,A3
	CMPA.L	52(A6),A3		; IntuitionBase->ActiveWindow
	BNE.S	.blk
	MOVEQ	#0,D1			; keys: active window, pointer anywhere
	MOVEQ	#0,D0
	MOVEA.L	46(A3),A0		; Window->WScreen: screen mouse pos
	MOVE.W	18(A0),D2		; Window->MouseX/Y stale after size gadget drag
	SUB.W	4(A3),D2		; - LeftEdge
	MOVE.B	54(A3),D0
	SUB.W	D0,D2			; - BorderLeft
	BMI.S	.blk
	CMP.W	rtg_WinW,D2
	BGE.S	.blk
	MOVE.W	16(A0),D3		; Screen->MouseY
	SUB.W	6(A3),D3		; - TopEdge
	MOVE.B	55(A3),D0
	SUB.W	D0,D3
	BMI.S	.blk
	CMP.W	rtg_WinH,D3
	BGE.S	.blk
	MOVEQ	#0,D7			; active and over image
	BSR.W	pt_RtgMX		; dst x 0..639 (wide 0..1279)
	MULU	rtg_OutH,D3
	DIVU	rtg_WinH,D3		; output line
	BSR.W	pt_RtgOut2Pt		; -> pt line
	BSR.W	pt_RwdMouse		; wide -> pt x
	ADD.W	D3,D3			; raw y (rows * 2)
	MOVE.W	D2,D4
	SUB.W	dat_ChannelMaskTmp,D4
	MOVE.W	D3,D5
	SUB.W	dat_ButtonRepeat,D5
.blk:	MOVE.B	D7,rtg_InBlock
	SUBA.L	A2,A2			; prev
	MOVEA.L	D6,A4			; current event
.l:	MOVE.L	A4,D0
	BEQ.S	.done
	MOVE.L	(A4),D3			; next
	TST.B	D1			; keys: window active, pointer anywhere
	BNE.S	.keep
	CMPI.B	#1,4(A4)		; IECLASS_RAWKEY -> single to pt
	BNE.S	.keep
	CLR.L	(A4)
	MOVEA.L	A4,A0
	BSR.S	.call
	MOVE.L	D3,(A4)
	TST.L	D0
	BNE.S	.keep			; passed on (e.g. system requester open)
	MOVE.L	A2,D0			; consumed: unlink
	BEQ.S	.head
	MOVE.L	D3,(A2)
	BRA.S	.nx
.head:	MOVE.L	D3,D6
	BRA.S	.nx
.keep:	MOVEA.L	A4,A2
.nx:	MOVEA.L	D3,A4
	BRA.S	.l
.done:	TST.B	D7			; mouse pos from win to pt
	BNE.S	.ret
	MOVE.W	D4,D0
	OR.W	D5,D0
	BEQ.S	.ret
	LEA	rtg_Synth,A0
	CLR.L	(A0)
	MOVE.W	#$0200,4(A0)		; IECLASS_RAWMOUSE, subclass 0
	MOVE.W	#$00ff,6(A0)		; IECODE_NOBUTTON
	CLR.W	8(A0)
	MOVE.W	D4,10(A0)
	MOVE.W	D5,12(A0)
	BSR.S	.call
.ret:	MOVE.L	D6,D0
	MOVEM.L	(A7)+,D1-D7/A1-A6
	RTS
.call:	MOVEM.L	D1-D7/A1-A6,-(A7)	; a0 = single event
	MOVEA.L	A5,A1
	MOVEA.L	rtg_InOrig,A6
	JSR	(A6)
	MOVEM.L	(A7)+,D1-D7/A1-A6
	RTS

; input handler entry: absolute pointer (tablet, virtual mouse) -> pt pos
; wb window: positions come from pt_RtgInWrap
pt_InAbs41:
	TST.B	rtg_RunWin
	BNE.S	.pt
	IFD	DEBUGAUTO
	TST.B	dbg_AutoPtrSet		; test driver owns the pointer
	BNE.S	.pt
	ENDC
	BSR.S	pt_RtgAbsPtr41
.pt:	JMP	dat_InputHandlerCode

; intuition moves the screen pointer, pt follows with a fake RAWMOUSE
; a0=event chain a1=is_Data, all regs kept
pt_RtgAbsPtr41:
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVEA.L	A1,A5
	MOVEA.L	A0,A2
	SUBA.L	A4,A4
.sc:	MOVE.L	A2,D0
	BEQ.S	.chk
	MOVE.B	4(A2),D0
	CMP.B	#$04,D0			; IECLASS_POINTERPOS
	BEQ.S	.abs
	CMP.B	#$13,D0			; IECLASS_NEWPOINTERPOS
	BEQ.S	.abs
	CMP.B	#$02,D0			; RAWMOUSE with a move: relative mouse again
	BNE.S	.nx
	MOVE.L	10(A2),D0
	BEQ.S	.nx
	SF	rtg_AbsPtr
	BRA.S	.nx
.abs:	ST	rtg_AbsPtr
	MOVE.L	A2,A4			; last absolute event
.nx:	MOVEA.L	(A2),A2
	BRA.S	.sc
.chk:	TST.B	rtg_AbsPtr
	BEQ.W	.r
	MOVE.L	rtg_Screen,D0
	BEQ.W	.nat
	MOVEA.L	D0,A0
	MOVEQ	#0,D2
	MOVE.W	18(A0),D2		; Screen->MouseX
	BPL.S	.x0
	MOVEQ	#0,D2
.x0:	MULU	#640,D2
	MOVE.W	12(A0),D0		; Width
	BEQ.W	.r
	DIVU	D0,D2
	CMP.W	#639,D2
	BLS.S	.x1
	MOVE.W	#639,D2
.x1:	MOVE.W	16(A0),D3		; Screen->MouseY
	SUB.W	rtg_YOff,D3
	BPL.S	.y0
	MOVEQ	#0,D3
.y0:	TST.B	rtg_Double
	BNE.S	.y1
	BSR.W	pt_RtgOut2Pt		; output line -> pt line
	ADD.W	D3,D3			; raw y = rows * 2
.y1:	CMP.W	#511,D3
	BLS.S	.y2
	MOVE.W	#511,D3
.y2:	BRA.W	.mv
.nat:	MOVE.L	A4,D0			; native: event itself (pt screen is a strip for intuition)
	BEQ.W	.r
	MOVEQ	#0,D2
	MOVEQ	#0,D3
	CMPI.B	#$04,4(A4)
	BNE.S	.np
	MOVE.W	10(A4),D2		; POINTERPOS: ie_X/ie_Y, hires/non-lace
	MOVE.W	12(A4),D3
	BRA.S	.nc
.np:	MOVEA.L	10(A4),A0		; NEWPOINTERPOS: ie_EventAddress
	MOVE.L	A0,D0
	BEQ.W	.r
	MOVE.B	5(A4),D0
	CMP.B	#1,D0			; IESUBCLASS_PIXEL: screen, x, y
	BNE.S	.nt
	MOVE.W	4(A0),D2
	MOVE.W	6(A0),D3
	BRA.S	.nc
.nt:	CMP.B	#2,D0			; IESUBCLASS_TABLET: range x/y, value x/y
	BNE.S	.nn
	MOVE.W	4(A0),D2
	MULU	#640,D2
	MOVE.W	0(A0),D0
	BEQ.W	.r
	DIVU	D0,D2
	MOVE.W	6(A0),D3
	MULU	#256,D3
	MOVE.W	2(A0),D0
	BEQ.W	.r
	DIVU	D0,D3
	BRA.S	.nc
.nn:	CMP.B	#3,D0			; IESUBCLASS_NEWTABLET: tablet x/y, range x/y (long)
	BNE.W	.r
	MOVE.L	12(A0),D2
	MOVE.L	20(A0),D0
	MOVE.W	#640,D1
	BSR.S	.scl
	MOVE.W	D2,D4
	MOVE.L	16(A0),D2
	MOVE.L	24(A0),D0
	MOVE.W	#256,D1
	BSR.S	.scl
	MOVE.W	D2,D3
	MOVE.W	D4,D2
.nc:	TST.W	D2
	BPL.S	.n0
	MOVEQ	#0,D2
.n0:	CMP.W	#639,D2
	BLS.S	.n1
	MOVE.W	#639,D2
.n1:	TST.W	D3
	BPL.S	.n2
	MOVEQ	#0,D3
.n2:	ADD.W	D3,D3			; raw y = rows * 2
	CMP.W	#511,D3
	BLS.S	.mv
	MOVE.W	#511,D3
	BRA.S	.mv
.scl:	; d2 = d2 * d1 / d0, d0/d2 long, scaled down to 16 bit first
	TST.L	D0
	BEQ.S	.z
.s0:	CMP.L	#$ffff,D0
	BLS.S	.s1
	LSR.L	#1,D0
	LSR.L	#1,D2
	BRA.S	.s0
.s1:	CMP.L	D0,D2
	BLS.S	.s2
	MOVE.L	D0,D2
.s2:	MULU	D1,D2
	DIVU	D0,D2
	AND.L	#$ffff,D2
	RTS
.z:	MOVEQ	#0,D2
	RTS
.mv:	SUB.W	dat_ChannelMaskTmp,D2
	SUB.W	dat_ButtonRepeat,D3
	MOVE.W	D2,D0
	OR.W	D3,D0
	BEQ.W	.r
	LEA	rtg_Synth,A0
	CLR.L	(A0)
	MOVE.W	#$0200,4(A0)		; IECLASS_RAWMOUSE
	MOVE.W	#$00ff,6(A0)		; IECODE_NOBUTTON
	MOVE.W	#$8000,8(A0)		; IEQUALIFIER_RELATIVEMOUSE
	MOVE.W	D2,10(A0)
	MOVE.W	D3,12(A0)
	MOVEA.L	A5,A1
	JSR	dat_InputHandlerCode
.r:	MOVEM.L	(A7)+,D0-D7/A0-A6
	RTS

; main loop: wb window -> wait for vbl, leave the cpu to the system
pt_MainYield41:
	TST.B	rtg_CloseReq		; window close gadget: page's own exit
	BNE.W	pt_RtgCloseDo
	JSR	pt_WidePoll41		; wide module: view for the screen, slider
	JSR	pt_MidiMain		; midi notes like keys
	BSR.S	pt_MainPri41
	TST.B	rtg_RunWin
	BEQ.S	.go
	TST.L	rtg_Window
	BEQ.S	.go
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	IFD	DIAGWIN
	ADDQ.L	#1,dw_Main
	BSR.W	dw_Start
	ENDC
	DK	'L'
	MOVEA.L	dat_GfxLibBase,A6
	JSR	(-270,A6)		; WaitTOF
	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
.go:	JMP	pt_ScreenDragUpdate

; wb window, a window being dragged (lmb held off our picture): pt's
; own loop below every other program (pri -1) so intuition and the
; window owners get the time; else pri 0 (it feeds ahi)
pt_MainPri41:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVEQ	#0,D0
	TST.B	rtg_RunWin
	BEQ.S	.s
	TST.L	rtg_Window
	BEQ.S	.s
	TST.B	rtg_SysDrag		; our window moved or sized
	BNE.S	.lo
	BSR.W	pt_RtgLmb
	BEQ.S	.s
	TST.B	rtg_InBlock		; lmb off the picture: other window
	BEQ.S	.s
.lo:	MOVEQ	#-1,D0
.s:	CMP.B	main_Pri,D0
	BEQ.S	.r
	MOVE.B	D0,main_Pri
	BNE.S	.lw
	MOVE.B	main_PriOrg,D0		;41 normal = the priority it came with
.lw:	EXT.W	D0
	EXT.L	D0
	MOVEA.L	ABSEXECBASE.W,A6
	MOVEA.L	276(A6),A1		; ThisTask
	JSR	(-300,A6)		; SetTaskPri
	TST.B	main_Pri
	BEQ.S	.r
	MOVE.B	D0,main_PriOrg		;41 old priority of the first change
.r:	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	RTS

; ctrl-c on pt (from pt_ScreenDragUpdate: every input loop, dialogs
; too): quit like EXIT; a changed module asks first (that dialog's own
; loop comes back here: brk_Asking)
pt_BreakQuit41:
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVEA.L	ABSEXECBASE.W,A6
	MOVEQ	#0,D0
	MOVE.L	#$1000,D1
	JSR	(-306,A6)		; SetSignal: take ctrl-c
	BTST	#12,D0
	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	BNE.S	.q
	RTS
.q:
	IFD	DEBUGAUTO
	JSR	dbg_AutoQuit
	JMP	pt_SyncAndStop
	ELSE
	TST.B	brk_Asking
	BNE.W	.r
	JSR	pt_ChgSync41
	CMPI.L	#'CHG!',dat_SongChangedMagic
	BNE.W	.quit
	ST	brk_Asking
	MOVEM.L	D0-D7/A0-A6,-(A7)
	CLR.L	-(A7)			; copies of the open dialog's backup and picture
	TST.W	dat_DiskOpFlag		; a dialog is open: this one would
	BEQ.W	.nb			; overwrite its backup and redraw its area
	MOVEA.L	ABSEXECBASE.W,A6
	MOVE.L	#12294,D0
	MOVEQ	#0,D1
	JSR	(-198,A6)		; AllocMem
	MOVE.L	D0,(A7)
	BEQ.W	.nb
	MOVEA.L	D0,A1
	MOVE.W	dat_PaletteSave0,(A1)+
	MOVE.W	dat_PaletteSave1,(A1)+
	MOVE.W	dat_PaletteSave2,(A1)+
	LEA	dat_GfxBitplaneBuf,A0
	BSR.S	.cp
	JSR	pt_CopyPatternBlock	; its picture as it is now
	LEA	dat_GfxBitplaneBuf,A0
	BSR.S	.cp
.nb:	JSR	pt_SaveConfirmDialog	; d0 = 2: yes, lose it
	MOVE.W	D0,D7
	MOVEA.L	(A7),A2
	MOVE.L	A2,D0
	BEQ.W	.nr
	LEA	6+6144(A2),A0
	LEA	dat_GfxBitplaneBuf,A1
	BSR.S	.cp
	JSR	pt_CopyScreenBufs	; picture back
	LEA	6(A2),A0
	LEA	dat_GfxBitplaneBuf,A1
	BSR.S	.cp
	MOVE.W	(A2),dat_PaletteSave0
	MOVE.W	(2,A2),dat_PaletteSave1
	MOVE.W	(4,A2),dat_PaletteSave2
	MOVEA.L	(A7),A1
	MOVEA.L	ABSEXECBASE.W,A6
	MOVE.L	#12294,D0
	JSR	(-210,A6)		; FreeMem
.nr:	ADDQ.L	#4,A7
	CMP.W	#2,D7
	MOVEM.L	(A7)+,D0-D7/A0-A6
	SF	brk_Asking
	BEQ.S	.quit
.r:	RTS
.quit:	JMP	pt_SyncAndStop
.cp:	MOVE.W	#1535,D0		; 6144 bytes a0 -> a1
.cl:	MOVE.L	(A0)+,(A1)+
	DBF	D0,.cl
	RTS
	ENDC

; scr gadget (dat_03FB): win mode -> window to back only, d0=-1
; (= "no screen", pt_ScreenStateHandler does nothing)
; else original: TST.L dat_ScreenPtr for the BEQ.S after
pt_ScrBack41:
	TST.B	rtg_RunWin
	BEQ.S	.orig
	TST.L	rtg_Window
	BEQ.S	.orig
	MOVEM.L	D1/A0-A1/A6,-(A7)
	MOVEA.L	dat_IntuiLibBase,A6
	MOVEA.L	rtg_Window,A0
	JSR	(-306,A6)		; WindowToBack
	ADDQ.B	#1,rtg_BackCnt
	MOVEM.L	(A7)+,D1/A0-A1/A6
	ADDQ.L	#4,A7			; drop return to dat_03FB
	MOVEQ	#-1,D0			; to pt_ScreenStateHandler: Z=0 -> nothing
	RTS
.orig:	TST.L	dat_ScreenPtr
	BEQ.S	.o2
	CMPI.B	#1,rtg_ProcState	; card screen up: it hides wb and
	BNE.S	.o2			; the return window
	TST.L	rtg_Screen
	BEQ.S	.o2
	MOVEM.L	D1/A0-A1/A6,-(A7)
	MOVEA.L	dat_IntuiLibBase,A6
	MOVEA.L	rtg_Screen,A0
	JSR	(-246,A6)		; ScreenToBack
	MOVEM.L	(A7)+,D1/A0-A1/A6
.o2:	TST.L	dat_ScreenPtr
	RTS

; wb window (rtg proc, per frame): close gadget -> rtg_CloseReq for pt;
; help page: its title into the window bar, else the program name
pt_RtgWinTitle:
	MOVEM.L	D0-D1/A0-A2/A6,-(A7)
	MOVEA.L	rtg_Window,A2
	MOVEA.L	ABSEXECBASE.W,A6
.msg:	MOVE.L	86(A2),D0		; Window->UserPort
	BEQ.S	.t
	MOVEA.L	D0,A0
	JSR	(-372,A6)		; GetMsg
	TST.L	D0
	BEQ.S	.t
	MOVEA.L	D0,A1
	CMPI.L	#$200,20(A1)		; Class = IDCMP_CLOSEWINDOW
	BNE.S	.rp
	ST	rtg_CloseReq
.rp:	JSR	(-378,A6)		; ReplyMsg
	BRA.S	.msg
.t:	LEA	rtg_WinTitle,A1
	CMPI.W	#2,dat_UIMode
	BNE.S	.s
	LEA	rtg_HelpTitle,A1
.s:	CMPA.L	rtg_TitleCur,A1
	BEQ.S	.r
	MOVE.L	A1,rtg_TitleCur
	MOVEA.L	A2,A0
	MOVEA.W	#-1,A2			; screen title kept
	MOVEA.L	dat_IntuiLibBase,A6
	JSR	(-276,A6)		; SetWindowTitles
.r:	MOVEM.L	(A7)+,D0-D1/A0-A2/A6
	RTS

; pt task: window close gadget = the button top left of the page
pt_RtgCloseDo:
	SF	rtg_CloseReq
	LEA	.tab(PC),A0
.l:	MOVE.W	(A0)+,D0
	BEQ.S	.r
	MOVEA.L	(A0)+,A1
	CMP.W	dat_UIMode,D0
	BNE.S	.l
	JMP	(A1)
.r:	RTS
.tab:	DC.W	1
	DC.L	pt_BtnMainQuit		; main: quit request
	DC.W	2
	DC.L	pt_InitEditMode		; help: close
	DC.W	3
	DC.L	pt_BtnDiskMainMenu
	DC.W	5
	DC.L	pt_BtnSetupMainMenu
	DC.W	6
	DC.L	pt_BtnPlstExit
	DC.W	8
	DC.L	pt_BtnInfoExit
	DC.W	9
	DC.L	pt_BtnPosExit
	DC.W	0

; ch cnt at start (replaces JSR pt_ClearScreenBuf2 in pt_Init)
; prefs byte +15 (4/8) first, else 8ch if mixer copes (68020+/fast 68000,
; not a500 mode) unless PROGDIR:PT.4ch exists; then pt_ClearScreenBuf2
pt_ChanDefault41:
	MOVEM.L	D0-D2/A0-A1/A6,-(A7)
	MOVE.B	prf_Chan,D0
	CMP.B	#8,D0
	BNE.S	.n8
	TST.B	mix_Enabled		; prefs from a bigger amiga: 8ch only
	BNE.S	.ch8			; with the mixer or the card output
	CMPI.B	#3,snd_Choice
	BEQ.S	.ch8
	BRA.S	.ch4
.n8:
	CMP.B	#4,D0
	BEQ.S	.ch4
	TST.B	mix_Enabled
	BEQ.S	.r
	TST.B	mix68_Slow
	BNE.S	.r
	MOVEA.L	dat_DosLibBase,A6
	MOVE.L	#.n4ch,D1
	MOVEQ	#-2,D2
	JSR	(-84,A6)		; Lock("PROGDIR:PT.4ch")
	MOVE.L	D0,D1
	BEQ.S	.ch8
	JSR	(-90,A6)		; UnLock
	BRA.S	.r
.ch4:	BSET	#5,dat_ModeFlags
	BRA.S	.r
.ch8:	BCLR	#5,dat_ModeFlags
.r:	MOVEM.L	(A7)+,D0-D2/A0-A1/A6
	JMP	pt_ClearScreenBuf2
.n4ch:	DC.B	"PROGDIR:PT.4ch",0
	EVEN

; req cnt down (return of intui patch pt_SetVectorAud0), never below 0
; orig SUBQ unchecked: FreeSysRequest w/o counted BuildSysRequest went
; negative -> input handler passed everything through
pt_ReqDec41:
	TST.B	dat_VBlankCounter
	BEQ.S	.r
	SUBQ.B	#1,dat_VBlankCounter
	BNE.S	.r
	JMP	pt_SetupCopper		; last req closed: restore display
.r:	RTS

; LMB/RMB macro test: win mode only if win active and ptr over image,
; else "up" (Z=0); otherwise hw btst
pt_LMB41:
	TST.B	rtg_InBlock
	BNE.S	pt_BtnUp41
	TST.B	rtg_InStage
	BNE.S	pt_BtnUp41
	BTST	#6,CIAA_PRA
	RTS
pt_RMB41:
	TST.B	rtg_InBlock
	BNE.S	pt_BtnUp41
	TST.B	rtg_InStage
	BNE.S	pt_BtnUp41
	BTST	#2,POTGOR
	RTS
pt_BtnUp41:
	ANDI	#$fb,CCR
	RTS

rtg_PubTags:	DC.L	WA_PubScreen_,0
		DC.L	WA_Title_,rtg_WinTitle
		DC.L	WA_CloseGadget_,1
		DC.L	WA_IDCMP_,$200		; IDCMP_CLOSEWINDOW
rtg_PubBox:	DC.L	1,0			; TAG_IGNORE or WA_Left
		DC.L	1,0			; TAG_IGNORE or WA_Top
		DC.L	WA_InnerWidth_,640
		DC.L	WA_InnerHeight_,512
		DC.L	WA_MinWidth_,180
		DC.L	WA_MinHeight_,90
		DC.L	WA_MaxWidth_,-1
		DC.L	WA_MaxHeight_,-1
		DC.L	WA_DragBar_,1
		DC.L	WA_DepthGadget_,1
		DC.L	WA_SizeGadget_,1
		DC.L	WA_SizeBBottom_,1
		DC.L	WA_SimpleRefresh_,1	; smart: every move copies the
		DC.L	1,0			; hidden parts (seconds on a card)
		DC.L	WA_AutoAdjust_,1
		DC.L	WA_Activate_,1
		DC.L	WA_RMBTrap_,1
		DC.L	0,0
rtg_CgxName:	DC.B	"cybergraphics.library",0
rtg_WinTitle:	DC.B	"ProTracker 4.1.2",0
rtg_HelpTitle:	DC.B	"Protracker Help",0
	CNOP	0,2

rtg_ScrTags:	DC.L	SA_DisplayID_,0
		DC.L	SA_Width_,640
		DC.L	SA_Height_,512
		DC.L	SA_Depth_,8
		DC.L	SA_Quiet_,1
		DC.L	SA_ShowTitle_,0
		DC.L	SA_Type_,$000f		; CUSTOMSCREEN
		DC.L	SA_Title_,rtg_ProcName
		DC.L	0,0
rtg_WinTags:	DC.L	WA_CustomScreen_,0
		DC.L	WA_Left_,0
		DC.L	WA_Top_,0
		DC.L	WA_Width_,640
		DC.L	WA_Height_,512
		DC.L	WA_Backdrop_,1
		DC.L	WA_Borderless_,1
		DC.L	WA_Activate_,1
		DC.L	WA_RMBTrap_,1
		DC.L	WA_SimpleRefresh_,1
		DC.L	WA_NoCareRefresh_,1
		DC.L	0,0
rtg_ProcTags:	DC.L	$800003eb,pt_RtgProc	; NP_Entry
		DC.L	$800003f4,rtg_ProcName	; NP_Name
		DC.L	$800003f5,1		; NP_Priority 1, above pt (pt busy waits)
		DC.L	$800003f3,8192		; NP_StackSize
		DC.L	0,0
rtg_ProcName:	DC.B	"PT4.1 RTG",0
rtg_FileName:	DC.B	"PROGDIR:PT.rtg",0
	CNOP	0,2
