;--- mixer
	RSRESET
mv_pos		RS.L	1	; abs addr
mv_frac		RS.W	1
mv_step		RS.L	1	; 16.16 smp per out smp
mv_end		RS.L	1	; abs addr, exclusive
mv_loopstart	RS.L	1	; abs addr
mv_looplen	RS.L	1	; bytes, 0 = no loop
mv_period	RS.W	1	; period mv_step is valid for
mv_vol		RS.W	1	; 0..64
mv_active	RS.B	1
mv_back		RS.B	1	; <>0: backwards (81y)
mv_SIZEOF	RS.B	0

MIX_RING	EQU	8192		; bytes per paula ch, power of 2
MIX_TICKMAX	EQU	2560		; smp, 32 bpm at 31.4 khz = 2452
MIX_LEAD	EQU	2		; ticks

mix_AudPtrTable: DS.L	8		; a5 per voice: paula regs or shadow
mix_AudPtrCur:	DS.L	1
mix_Shadow:	DS.B	8*aud_SIZEOF
mix_ChunkLists:	DS.B	4*800		; chunk lists voices 5-8
mix_Voices:	DS.B	8*mv_SIZEOF
mix_TickBuf:	DS.B	MIX_TICKMAX	; one tick of one paula ch
aut_Buf		EQU	mix_TickBuf	; first run setup reads before the mixer exists
aut_Name	EQU	mix_TickBuf+256
mix_Silence:	DS.B	16
mix_Ring:	DS.L	1		; chip 4*MIX_RING or 0
mix_WriteInt:	DS.L	1		; smp
mix_WriteFrac:	DS.W	1
mix_Spt:	DS.L	1		; smp per tick 16.16
mix_SptBpm:	DS.W	1		; bpm mix_Spt was built for
mix_SptMode:	DS.W	1		; dat_ModeFlags bit 0 mix_Spt is valid for
mix_Rate:	DS.W	1		; hz
mix_Period:	DS.W	1
mix_TicksDue:	DS.W	1		; ticks requested, not mixed yet
mix_PairMask:	DS.B	1		; bit n: pair n (voice n+1, n+5) mixed
mix_Active:	DS.B	1
mix_Enabled:	DS.B	1		; dat_CPUType >= 2
mix_Init:	DS.B	1
mix_RingFail:	DS.B	1
mix_RateLock:	DS.B	1		; rmb debounce
mix_RateSel:	DS.B	1		; 0 auto, 1 14khz, 2 22khz, 3 28.6khz
mix_Is68k:	DS.B	1		; 68000 mixer: paula 2/3 mixed, voices 1/2 direct
	EVEN
;--- 68000 mixer
mix68_VolTab:	DS.L	1		; 65*256
mix68_WinBase:	DS.L	1
mix68_RingBlock: DS.L	1		; chip block rings 2/3 (2*MIX_RING), 0 = none
mix68_GroupMv:	DS.L	3
mix68_ExpSrc:	DS.L	16		; per voice loopstart,len the loop buf is valid for
mix68_ExpLen:	DS.L	16		; per voice buf len (idx*8 like ExpSrc)
mix68_StepRate:	DS.W	1		; rate step table is valid for, 0 = none
mix68_Act:	DS.L	3
mix68_PA:	DS.L	1		; pt_Mix68Pair args
mix68_PB:	DS.L	1
mix68_PDst:	DS.L	1
mix68_PRest:	DS.L	1
mix68_PCnt:	DS.L	1
mix68_TBBase:	DS.L	1
mix68_TBWin:	DS.L	1
mix68_TBPos:	DS.W	1
mix68_TBFrac:	DS.W	1
mix68_TBIstep:	DS.W	1
mix68_TBFstep:	DS.W	1
mix68_TBVol:	DS.W	1
mix68_Drops:	DS.W	1		; ticks dropped
mix_TickLine:	DS.W	1		; raster line of last tick
mix68_DTick:	DS.W	1
mix68_DPend:	DS.W	1		; dma bits voices 1/2 started this tick
mix68_DLine:	DS.W	1
mix68_DLead:	DS.W	1		; ticks (2, slow mode 8)
mix68_DFifo:	DS.B	2*16*20		; 16 ticks * 2 voices * M68D_SIZE
mix68_DOn:	DS.B	1
	EVEN
	IFD	DEBUGFX
dbg75_EC:	DS.L	2
dbg75_T0:	DS.L	1
dbg75_WAbs:	DS.L	1
dbg75_Mix:	DS.L	16
dbg75_Dir:	DS.L	16
dbg75_NM:	DS.W	1
dbg75_ND:	DS.W	1
dbg75_Starts:	DS.W	1
dbg68_DTrig:	DS.W	1
dbg68_DDma:	DS.W	1
dbg68_DDmaOr:	DS.W	1
dbg68_CauseLine: DS.W	1
dbg68_LatMax:	DS.W	1		; lines
dbg68_LatSum:	DS.L	1
dbg68_Polls:	DS.L	1
dbg68_TLast:	DS.W	1
	EVEN
dbg68_TUpd:	DS.L	1
dbg68_TMix:	DS.L	1
dbg68_TCopy:	DS.L	1
	ENDC
mix68_Slow:	DS.B	1		; slow mode (7 mhz + fast ram, 5 khz, scopes off)
mix68_MemFail:	DS.B	1
	EVEN
	EVEN
mix_HintChans:	DS.W	1
;--- formats
fmt_Flt8Pending: DS.B	1
fmt_TruncPending:	DS.B	1
	EVEN
fmt_FilePats:	DS.W	1		; patterns in the file (before the cap)
fmt_NarrowCh:	DS.W	1		; 1..7 channel module loading (0 = none)
fmt_ExtPending:	DS.B	1
	EVEN
fmt_ExtPeriods:	DS.W	1		; cells with period outside 113..856
	EVEN
dat_CpuBench:	DS.L	1		; loops per 1/50 s, 0 = not measured
;--- efx8
efx8_State:	DS.L	8		; per ch: slide rate, tremor y, tremor cnt, retrig
efx8_Blend:	DS.B	4		; 84y per pair: share of voice n+4 in 15ths, 0 = off
efx8_PlayPrev:	DS.L	1
efx8_SavePending: DS.B	1
smp_MsgPending:	DS.B	1
	EVEN
;--- diskop
disk_ProcPtr:	DS.L	1
disk_TopStk:	DS.L	8		; disk op: path length, list top per dir level
disk_TopN:	DS.W	1
disk_OldWindowPtr: DS.L	1		; old pr_WindowPtr
disk_CfgProgdir:	DS.B	1
disk_ToolDone:	DS.B	1
disk_LongPtr:	DS.L	1		; full name of clicked entry, 0 = none
disk_LongCount:	DS.W	1
disk_Scratch:	DS.B	32
disk_LongPool:	DS.L	1		; 128*108, allocated on demand, not in bss (1 mb a500+ needs the room)
disk_DosLocked:	DS.B	1
	CNOP	0,2
;--- ahi
ahi_Want:	DS.B	1
ahi_Active:	DS.B	1
ahi_Failed:	DS.B	1
ahi_DevOpen:	DS.B	1
ahi_NoPaula:	DS.B	1
ahi_Half:	DS.B	1		; 0/1
ahi_Step:	DS.B	1
ahi_IoErr:	DS.B	1
	CNOP	0,2
ahi_Freq:	DS.W	1
ahi_FreqNow:	DS.W	1		; rate set at ahi now (servo)
ahi_Peak:	DS.W	1
ahi_ProcState:	DS.B	1		; 0 starting, 1 ready, 2 error, 3 done
	CNOP	0,4
ahi_Proc:	DS.L	1
	CNOP	0,4
ahi_Port:	DS.L	1
ahi_Req1:	DS.L	1
ahi_Base:	DS.L	1
ahi_Ctrl:	DS.L	1
ahi_Buf1:	DS.L	1		; 2 halves s16s
ahi_ReadPos:	DS.L	1		; smp in mixer ring
ahi_Sent:	DS.L	1
ahi_Done:	DS.L	1
ahi_Resync:	DS.L	1
ahi_Polls:	DS.L	1
ahi_SentSeen:	DS.L	1		; ahi_Sent at the last look
ahi_Ticks:	DS.W	1		; replayer ticks since ahi asked for a half
ahi_Stalls:	DS.W	1		; silent ahi seen: 1 = went to 22 khz
ahi_Hook:	DS.L	5		; struct Hook
ahi_Info:	DS.L	12		; 4 * AHISampleInfo
ahi_Tags:	DS.L	12
ahi_FltSt:	DS.L	6		; rc, led1, led2 per channel (l, r)
ahi_FltMode:	DS.B	1		; 0 off, 1 a1200, 2 a500
ahi_FltLed:	DS.B	1		; led state at last half
ahi_FltInit:	DS.B	1
ahi_FltRst:	DS.B	1		; states to clear (set by the task)
	CNOP	0,2
;--- rtg
rtg_Want:	DS.B	1
rtg_Tried:	DS.B	1
rtg_ProcState:	DS.B	1		; 0 starting, 1 running, 2 error, 3 done
rtg_Step:	DS.B	1
rtg_Double:	DS.B	1		; double lines (640x512)
rtg_PalDirty:	DS.B	1		; reload clut
rtg_VblUp:	DS.B	1		; frame clock server installed
rtg_PriOld:	DS.B	1		; pri before the layer lock
	CNOP	0,4
rtg_Proc:	DS.L	1
rtg_Mode:	DS.L	1
rtg_Screen:	DS.L	1
rtg_Window:	DS.L	1
rtg_LineBuf:	DS.L	1		; 2*640
rtg_Blank:	DS.L	1		; empty ptr (chip)
rtg_Vbl:	DS.L	1		; vbl count, frame clock
rtg_FrameT0:	DS.L	1		; vbl count at last frame start
rtg_VblTask:	DS.L	1		; mirror proc, woken each vbl
rtg_VblMask:	DS.L	1
rtg_VblInt:	DS.B	22		; struct Interrupt
rtg_Frames:	DS.L	1
rtg_Stripe:	DS.W	1		; first line of this frame's check stripe
rtg_Full:	DS.B	1		; frames left reading every line (input)
	EVEN
rtg_Lines:	DS.L	1
rtg_Reads:	DS.L	1		; lines read from chip
rtg_Cop2:	DS.L	1
rtg_BplPt:	DS.L	6
rtg_ScrH:	DS.W	1
rtg_YOff:	DS.W	1
rtg_Con0:	DS.W	1
rtg_Mod1:	DS.W	1
rtg_Mod2:	DS.W	1
rtg_VStart:	DS.W	1
rtg_NumBanks:	DS.W	1
rtg_DiwH:	DS.W	1		; diwstrt h (sprite x)
rtg_SprNext:	DS.W	1		; next free sprite color idx (down)
rtg_Colors:	DS.W	32
rtg_DimBuf:	DS.B	96
rtg_SprPt:	DS.L	8
rtg_NumSegs:	DS.W	1
rtg_SprIdx:	DS.B	4
disk_FreeText:	DS.B	8		; "dddd MB"
dat_DiskFreeMB:	DS.L	1		; free mb of diskop drive
cpu_EClock:	DS.L	2
cpu_TimerReq:	DS.B	40
;--- misc
mix_Overrun:	DS.W	1		; softint longer than a tick
	EVEN
mix_SoftInt:	DS.B	22		; struct Interrupt for Cause()
	EVEN
	IFD	DEBUGFX
DBG_MIXCH	EQU	49152		; bytes per ch in mix dump
dbg_MixBuf:	DS.L	1		; 4*DBG_MIXCH, allocated in pt_MixTaskPoll
dbg_MixPos:	DS.L	1
dbg_MixSoftCnt:	DS.L	1
dbg_MixCauseCnt: DS.L	1
dbg_MixStartCnt: DS.L	1
dbg_MixStopCnt:	DS.L	1
dbg_MixInitCnt:	DS.L	1
dbg_MixPlayPrev: DS.L	1
dbg_MixRestartCnt: DS.L	1
dbg_TruncCnt:	DS.L	1
dbg_MixLineStart: DS.W	1
dbg_MixLinesMax: DS.W	1		; lines
dbg_MixLinesSum: DS.L	1		; lines
dbg_NsCnt:	DS.L	20		; note start: 5 kinds x 4 ch
dbg_AhiPos:	DS.L	1		; ahi log entries written
dbg_AhiServo:	DS.L	1		; servo rate changes
dbg_AhiBuf:	DS.L	2*1024		; ahi log: tod, distance | flags
	ENDC

	IFD	DEBUGAUTO
FLT_CAPOUT	EQU	32+AHI_HALF*4
flt_CapPtr:	DS.L	1		; filter capture (alloc): mode, leds, done, rate, states, in, out
flt_CapCnt:	DS.W	1
flt_CapArm:	DS.B	1
	EVEN
dbg_WdTicks:	DS.W	1		; cia ticks since last driver step
dbg_WdDone:	DS.B	1
	EVEN
dbg_WdText:	DS.B	64
dbg_StopInfo:	DS.B	48
dbg_StopCnt:	DS.W	1
dbg80_Idle:	DS.L	1		; exec IdleCount/DispCount/IDNestCnt/TDNestCnt
dbg80_Disp:	DS.L	1
dbg80_IDN:	DS.B	1
dbg80_TDN:	DS.B	1
dbg_InOrig:	DS.L	1		; orig is_Code of input handler
dbg_InEvent:	DS.B	22		; event for IND_WRITEEVENT
dbg_InEvOwn:	DS.W	1		; set while INEV writes: keys pass
dbg_HwSnap:	DS.W	4		; HW cmd: DMACONR, INTENAR, INTREQR, ADKCONR
dbg_F00Cnt:	DS.W	1
dbg_F00Chan:	DS.L	1
dbg_F00Pat:	DS.L	1
dbg_F00Song:	DS.L	1
dbg_F00Note:	DS.L	1
dbg_StopPbCnt:	DS.W	1
dbg_StopPbRet:	DS.L	1
dbg_StopPbRet2: DS.L	1
dbg_StopPbPat:	DS.L	1
dbg_StopWas:	DS.B	1
	EVEN
dbg_ProcNow:	DS.L	1
dbg_WinPtrNow:	DS.L	1
	ENDC
	EVEN
x20_Base:	DS.L	1		; 68020 area, 0 on 68000
mix_Offline:	DS.B	1		; offline render in task, replayer irq calls do nothing
mix_OffCall:	DS.B	1		; pt_RpMusic call from renderer
mixit_SaveRate:	DS.W	1
mixit_SaveTempo:	DS.W	1
mixit_RowSize:	DS.W	1
mixit_SaveSpeed:	DS.L	1
mixit_SavePat:	DS.L	1
mixit_SavePos:	DS.L	1
mixit_SaveSong:	DS.L	1
mixit_Rate:	DS.L	1
mixit_Buf:	DS.L	1
;--- setup
set_Page:	DS.B	1		; 0 setup, 1 system
set_PollCnt:	DS.B	1
set_Line:	DS.B	48
set_Line2:	DS.B	64
set_Line3:	DS.B	64
set_Num:	DS.B	16
set_Num2:	DS.B	16
	EVEN
snd_Choice:	DS.B	1		; 0 none, 1 paula, 2 ahi, 3 amigus, 4 zz9000ax
snd_VolDown:	DS.B	1		; tenths down, 0 = 100%
snd_StereoDown:	DS.B	1		; quarters down, 0 = 100%
snd_NameOk:	DS.B	1		; snd_AhiName valid for snd_AhiMode
snd_AhiMode:	DS.L	1		; 0 = AHI_DEFAULT_ID
snd_AhiName:	DS.B	40
snd_Tags:	DS.L	6
snd_Req:	DS.L	20		; AHIRequest (80 bytes)
rtg_UserMode:	DS.L	1		; 0 = auto
rtg_Scale1x:	DS.B	1		; no 2x, centered
rtg_WaitAdj:	DS.B	1		; frame period in vbl = 1 + adj (0..3)
;--- rtg window
prf_Chan:	DS.B	1		; 4/8, 0 = not saved
prf_LoadKeep:	DS.B	1		; ON LOAD: 0 auto, $ff keep 8ch
rtg_WinMode:	DS.B	1		; window on default public screen
rtg_BackCnt:	DS.B	1
rtg_BplOff:	DS.B	1		; mirror switched native bpl dma off
rtg_RunWin:	DS.B	1		; running mirror is the wb window (rtg_WinMode when it started)
rtg_WinHeld:	DS.B	1		; frames left before drawing again after a drag
rtg_LmbEv:	DS.B	1		; lmb held as seen by input events (any mouse)
rtg_SysDrag:	DS.B	1		; lmb went down on our frame: intuition drags/sizes
rtg_GeoCnt:	DS.B	1		; frames the new window size stood still
rtg_GeoPend:	DS.B	1		; a new window size waits to stand still
rtg_GeoWide:	DS.B	1
	EVEN
rtg_GeoW:	DS.W	1		; new window size waiting to be taken
rtg_GeoH:	DS.W	1
rtg_InBlock:	DS.B	1		; 1 = input not for pt
rtg_WinFail:	DS.B	1		; failed window step (10..14), 0 = ok
rtg_CloseReq:	DS.B	1		; window close gadget hit, pt acts
	EVEN
rtg_TitleCur:	DS.L	1		; title the window shows
rtg_CgxBase:	DS.L	1
rtg_InOrig:	DS.L	1		; orig is_Code
rtg_XMap:	DS.L	1		; 4096 words src x per dst x, then 4096 bytes scale buf
rtg_ScaleBuf:	DS.L	1
rtg_WinLastPos:	DS.L	1		; window left/top seen last frame
rtg_LutBuf:	DS.L	1		; win w x h pixel values, 0 = direct rows
rtg_LutSize:	DS.L	1
rtg_WinW:	DS.W	1
rtg_WinH:	DS.W	1
rtg_DirtyY0:	DS.W	1		; dst rows to blit, y0 > y1 = none
rtg_DirtyY1:	DS.W	1
rtg_BlitAll:	DS.B	1		; next blit: whole window
	EVEN
rtg_Synth:	DS.B	22		; synthetic RAWMOUSE event
rtg_AbsPtr:	DS.B	1		; absolute pointer seen (tablet, virtual mouse)
rtg_PatOn:	DS.B	1		; this frame: pattern view, output taller
rtg_PatLast:	DS.B	1		; rtg_PatOn of the last frame
rtg_NoSpr:	DS.B	1		; row without sprites (synthetic rows)
rtg_TplOk:	DS.B	1		; template row seen this frame
rtg_BlankOk:	DS.B	1		; rows below the picture cleared
	EVEN
rtg_OutH:	DS.W	1		; output lines (256 = classic)
rtg_OutRow:	DS.W	1		; output line of the row being drawn
rtg_NatRow:	DS.W	1		; native line of the row being drawn
rtg_PatRow:	DS.W	1		; pattern row under the cursor
rtg_Shift:	DS.W	1		; native pattern lines -> output (+)
rtg_YtOut:	DS.W	1		; output line of the cursor row text
rtg_ThumbIdx:	DS.W	1		; clut idx red, dark red (scroll thumb)
rtg_TplPt:	DS.L	6		; plane ptrs of the template row
rtg_TplCol:	DS.W	8		; its colors
rtg_TplCon0:	DS.W	1
rtg_TplBank:	DS.L	1		; color bank of the template
rtg_SavPt:	DS.L	6		; native state around synthetic rows
rtg_SavCol:	DS.W	8
rtg_SavCon0:	DS.W	1
rtg_ScrCol:	DS.B	32		; scroll bar column, even and odd line
rtg_Zero80:	DS.B	80		; empty plane line
rtg_RprOn:	DS.B	1		; this frame: pattern section by the renderer
rtg_NoEmit:	DS.B	1		; mirror converts a line only for the renderer
rtg_ColDirty:	DS.B	1		; colors 0-7 written since the last bank search
rtg_StateOk:	DS.B	1		; line states valid for a steady frame
rtg_InSteady:	DS.B	1
rtg_P3Moved:	DS.B	1		; only BPL3PT differs from the last frame
rpr_Fail:	DS.B	1
rpr_Force:	DS.B	1		; blit the pattern area again
rpr_TplNew:	DS.B	1
rpr_BlitDone:	DS.B	1		; ring blitted this frame: vu bars again
rpr_Off:	DS.B	1		; vu columns into rpr_BM2
	EVEN
rtg_LastBank:	DS.L	1
rtg_Mem:	DS.L	1		; rtg buffers (RM_*, src/sys/x20.i)
rtg_PrevCop:	DS.L	1		; copper list of the last frame (steady test)
rtg_RowSt:	DS.L	1		; line states of the last full frame
rtg_PrevSegSig:	DS.L	1		; sprite segments of the last frame (signature)
rtg_NewP3:	DS.L	1		; pattern ptr (BPL3PT) in this frame's list
rtg_OldP3:	DS.L	1
rtg_ProfT:	DS.L	1
rtg_ProfT0:	DS.L	1
rtg_ProfX:	DS.L	2		; sprite build, steady lines
rtg_ProfLen:	DS.W	1
rtg_Prof:	DS.L	6		; vbl spent: walk, lines, renderer, blit, wait, frames
rtg_ProfN:	DS.L	13		; debug counts: whole window, pool reset, pattern area busy, lut over it,
				; copper walk cut, renderer off for a frame, kept on/last on, flags,
				; renderer all again: pattern drawn, template, row jump; slots drawn,
				; of them for a cell pt drew
rtg_PatGen:	DS.L	1		; pt drew the whole pattern (count)
rtg_RprWas:	DS.B	1		; renderer on in the last full walk
rtg_RprMiss:	DS.B	1		; ... kept on for one walk without it
mid_On:		DS.B	1		; midi in running
mid_Sel:	DS.B	1		; setup: 0 off, 1 all, 2..17 channel 1-16
mid_Chan:	DS.B	1		; 0 all, 1..16
mid_Head:	DS.B	1
mid_Tail:	DS.B	1
mid_Status:	DS.B	1		; running status
mid_Cnt:	DS.B	1
mid_Data:	DS.B	2
mid_QHead:	DS.B	1
mid_QTail:	DS.B	1
mid_Pass:	DS.B	1		; main loop passes
mid_PassSeen:	DS.B	1		; ... at the last pt_MidiTask
agus_Tried:	DS.B	1
agus_On:	DS.B	1		; card output (amigus or zz9000ax, see zzax_On)
agus_SyncCnt:	DS.B	1
agus_Busy:	DS.B	1		; sample upload running
agus_UpFail:	DS.B	1		; write fifo lost data (reported)
agus_Late:	DS.B	1		; card runs still to skip (the tick started late)
snd_Target:	DS.B	1		; output switch: 1 paula, 2 ahi, 3 amigus, 4 zz9000ax
snd_Switch:	DS.B	1		; output changes hands: mixer keeps off paula
zzax_Tried:	DS.B	1
zzax_On:	DS.B	1		; the card output is the zz9000ax (agus_On too)
zx_Ready:	DS.B	1		; voice session open and usable
zx_Open:	DS.B	1		; voice session open (buffers to free)
zx_Lost:	DS.B	1		; the card ended the session: the task opens a new one
zx_Fails:	DS.B	1		; new sessions that failed in a row
zx_Busy:	DS.B	1		; task uses the session: the tick keeps off
zx_Hold:	DS.B	1		; this tick waits for the card clock
zx_Fresh:	DS.B	1		; status of this tick already read
zx_Anch:	DS.B	1		; timeline started (stamps are valid)
snd_Alt:	DS.B	1		; both cards: the next card output is the zz9000ax
	EVEN
mid_Misc:	DS.L	1		; misc.resource
mid_OldInt:	DS.L	1
mid_Int:	DS.B	22		; rbf interrupt
mid_Ring:	DS.B	256
mid_Q:		DS.B	16
agus_Base:	DS.L	1		; amigus.library
agus_Card:	DS.L	1		; struct AmiGUS of the first card
agus_Wave:	DS.L	1		; wavetable registers (output on)
agus_Mem:	DS.L	1		; card tables (AGM_*), with output amigus
agus_Spt5:	DS.L	1		; 5 * tick length in e clocks
agus_ChBase:	DS.L	1		; tick: channel structs, voices, count
agus_VoBase:	DS.L	1
agus_NV:	DS.W	1
zzax_Base:	DS.L	1		; zz9k.library
zzax_Card:	DS.L	1		; same, revision 42 or later (0 = none)
zzax_Mem:	DS.L	1		; session, status, records (ZXM_*), with output zz9000ax
zx_Lead:	DS.L	1		; granted lead in 48 khz frames
zx_Stamp:	DS.L	1		; stamp of the next tick
zx_Spt16:	DS.L	1		; frames per tick, 16.16
zx_SptKey:	DS.L	1		; agus_Spt5 it was made for
zx_Frac:	DS.W	1		; fraction of the frames of a tick
zx_PCnt:	DS.W	1		; records waiting for the ring: count, taken
zx_PDone:	DS.W	1
zx_Master:	DS.W	1		; gain the card has (-1 = none)
wide_Pat:	DS.L	1		; wide module: patterns, 32 ch a row
wide_PatSize:	DS.L	1
wide_SaveBuf:	DS.L	1		; save: header + patterns, ch wide
wide_SaveLen:	DS.L	1
wide_Tmp:	DS.L	1		; load: one raw pattern, taken at the id
wide_Mute:	DS.L	1		; muted wide channels, bit = ch
wide_Ch:	DS.W	1
wide_ChTxt:	DS.B	4		; setup CHANNELS text
wide_On:	DS.B	1
wide_Pend:	DS.B	1
wide_MsgPend:	DS.B	1
brk_Asking:	DS.B	1		; ctrl-c: quit dialog open
io_BakOn:	DS.B	1		; save: the old file waits under its backup name
io_WrFail:	DS.B	1		; save: a write came up short
io_BakName:	DS.B	125		; backup name (even total)
agus_Retry:	DS.B	1		; tries left for the saved amigus output
trk_On:		DS.B	1		; rtg track view (wide module, wide layout)
trk_HeadHot:	DS.B	1		; frames the head lines are read again
wsc_State:	DS.B	1		; panel box: 0 pt, 1 logo, 2 bars, 3 off
wsc_Ch:		DS.B	1		; ... channels the bars are laid out for
	EVEN
stat_Date:	DS.L	3		; status marquee: dos DateStamp
stat_Next:	DS.L	1		; tick of the next step
fmt_SeekTo:	DS.L	1		; file pos of the samples after cut patterns
agus_RetryAt:	DS.L	1		; saved amigus output: tick of the next try
stat_Later:	DS.L	1		; text for the next main pass
stat_Len:	DS.W	1		; 0 = no marquee
stat_Pos:	DS.W	1
stat_Field:	DS.W	1
stat_Buf:	DS.B	80
set_MqNext:	DS.L	1		; AHI mode field marquee: next step
set_MqLen:	DS.W	1		; 0 = fits the field
set_MqPos:	DS.W	1
set_MqBuf:	DS.B	40		; SET_MQMAX
trk_First:	DS.W	1		; first track on screen (0-based)
trk_Cell:	DS.B	8		; cell text
trk_SPitch:	DS.W	1		; stage box pitch
rwd_StX:	DS.W	1		; stage in the window: first px
rwd_StE:	DS.W	1		; ... width
wsc_N:		DS.W	1		; panel bars: channels a box
wsc_P:		DS.W	1		; ... pitch
wsc_Pad:	DS.W	1		; ... left pad in a box
wsc_BP:		DS.W	1		; ... box to box px
trk_Lev:	DS.B	32		; level per channel 0..64 (replayer tick)
agus_Hit:	DS.B	32		; card voice started this tick
wsc_Prv:	DS.B	32		; panel bars: height drawn
trk_VuH:	DS.B	32		; track view vu: height drawn per track
wide_Row:	DS.B	128		; added pattern row: the edited group, rest 0
trk_NoRow:	DS.B	128		; empty row: track view past wide_Pat
	EVEN
note_Ext41:	DS.B	1		; note range c-0..b-4 (setup NOTES)
note_Up41:	DS.B	1		; key above b-3: entered one octave up
rtg_RowsReq:	DS.B	1		; setup: rows to add to the window (signed)
	EVEN
gfx_RowsShown:	DS.W	1		; rows value on the system page
gfx_Sig:	DS.B	1		; rtg state shown on the system page
rtg_WinBad:	DS.B	1		; window open failed, skip it in the cycle
gfx_RowsAsk:	DS.B	1		; polls left to see a rows change
	DS.B	1
gfx_RowsAskV:	DS.W	1		; rows value when asked
rtg_RowDirty:	DS.B	64		; pt drew a cell in this row
rpr_Gen:	DS.L	1
rpr_BM:		DS.L	1		; card bitmap: ring of row slots
rpr_SBuf:	DS.L	1		; scaled slot (fast ram)
rpr_SBSize:	DS.L	1
rpr_W:		DS.W	1		; output width
rpr_XF:		DS.W	1
rpr_YF:		DS.W	1
rpr_RowH:	DS.W	1
rpr_N:		DS.W	1		; slots
rpr_C:		DS.W	1		; slot of the cursor row
rpr_Head:	DS.W	1		; ring start
rpr_LastPR:	DS.W	1
rpr_BarGen:	DS.W	1
rpr_BarShown:	DS.W	1
rpr_BM2:	DS.L	1		; pattern area off screen, 0 = none
rpr_H2:		DS.W	1		; its height
rpr_VuIdx:	DS.B	4
rpr_VuTop:	DS.W	1
rpr_VuLines:	DS.W	1
rpr_VuNewN:	DS.W	1
rpr_VuOldN:	DS.W	1
rpr_VuW:	DS.W	1		; width of the sprite column
rwd_Mem:	DS.L	1		; wide window buffers (WM_*), 0 = none
rwd_W:		DS.W	1		; picture width: 1280, track view the window
trk_Vis:	DS.W	1		; tracks on screen (track view)
trk_XE:		DS.W	1		; x after the last of them
trk_K0:		DS.W	1		; slider knob (wide x)
trk_K1:		DS.W	1
trk_Grab:	DS.W	1		; pointer - knob while it is dragged
trk_BarKey:	DS.L	1		; first, vis of the slider map
trk_Drag:	DS.B	1		; 1 knob held, 2 groove clicked
trk_LmbOld:	DS.B	1
trk_Pen:	DS.B	4		; bar rows: light, grey, dark, red
trk_Grp:	DS.W	1		; group of four tracks in pt's view (edited)
trk_UndoGrp:	DS.W	1		; group the undo snapshot belongs to
trk_UndoPat:	DS.W	1		; pattern the undo snapshot belongs to
trk_Swap:	DS.B	1		; view being swapped: replayer leaves it alone
trk_FxNew:	DS.B	1
trk_FxKey:	DS.L	1		; first track, group of the cursor map
trk_ChKey:	DS.W	1		; channels the track view was built for
trk_StgFirst:	DS.W	1		; group the wells were drawn for
trk_StgVis:	DS.W	1
trk_StgMute:	DS.L	1		; mutes the wells were drawn for
trk_Frame:	DS.W	1		; stage frames (peak fall)
trk_Pk:		DS.B	64		; peak segment, hold frames per channel
trk_SegC:	DS.B	32*27		; segment codes drawn per channel
trk_SmKey:	DS.B	1		; first track and 3 of that build
rwd_ShowKey:	DS.B	1		; tracks shown in the 8 track view built
rwd_XEn:	DS.W	1		; x after the last shown track (8 track view)
rwd_Font:	DS.L	1		; track font of the glyph table
rwd_BarKey:	DS.L	1		; bar gen, row of the wide bar
trk_GrownCh:	DS.W	1		; window widened for this wide module
rwd_Slot:	DS.W	1		; track pitch, 8 track view (fills the width)
rwd_PadA:	DS.W	1		; extra px in the note field
rwd_PadB:	DS.W	1		; ... sample field (effect: the rest)
rwd_TxA:	DS.W	1		; text shift in the note field
rwd_TxB:	DS.W	1		; ... sample field
rwd_TxC:	DS.W	1		; ... effect field
rwd_HdC:	DS.W	1		; head text offset in the slot
trk_Slot:	DS.W	1		; track view: track pitch (fills the width)
trk_VuCur:	DS.W	1		; track view vu: height of the column drawn
trk_VuKey:	DS.W	2		; ... layout the bars were drawn for
trk_StgMem:	DS.L	1		; stage: buffer and width it was built for
trk_StgW:	DS.W	1
trk_WideN:	DS.W	1		; first tracks on screen a byte wider
trk_PadA:	DS.W	1		; extra px in the note field
trk_PadB:	DS.W	1		; ... sample field (effect: the rest)
trk_TxA:	DS.W	1		; text shift in the note field
trk_TxB:	DS.W	1		; ... sample field
trk_TxC:	DS.W	1		; ... effect field
rwd_BoxP:	DS.W	1		; analyzer box pitch
rwd_BoxW:	DS.W	1		; ... width
rwd_BoxX:	DS.W	1		; ... first x
rwd_Step:	DS.W	1		; scope sample step per column (8.8)
main_Pri:	DS.B	1		; priority set for pt's own task
main_PriOrg:	DS.B	1		; the priority it had before
rtg_HoldSize:	DS.B	1		; window held for a new size
	EVEN
rwd_TCol:	DS.W	3		; panel colours 1-3 (title strip on help)
rwd_G:		DS.B	8		; glyph being looked up
rtg_Wide:	DS.B	1		; 8 tracks over the full window width
rtg_WideWant:	DS.B	1		; window snapped to the wide layout
rtg_WideFail:	DS.B	1		; no wide layout this session
rtg_WideMsg:	DS.B	1		; failure text shown
rtg_InStage:	DS.B	1		; pointer over the stage: no buttons
rwd_BarOk:	DS.B	1
rwd_On:		DS.B	1		; last frame: wide pattern view by the renderer
rwd_ScMute:	DS.B	1		; scope labels drawn dimmed, bit per track
rwd_StCol:	DS.B	20		; stage colour codes -> line colours
rwd_Main:	DS.B	1		; main panel in the top row: exit widened
	EVEN
prf_Loaded:	DS.B	1
snd_Started:	DS.B	1
prf_Buf:	DS.L	16		; PREFS_MAX: newer files read in part
prf_WinBox:	DS.W	4		; rtg window left, top, inner w, h (0 = default)
	EVEN
set_Ready:	DS.B	1
sch_Scheme:	DS.B	1		; 0 = 4.1, 1 = 2.3
	EVEN
snd_Defer:	DS.B	1		; output switch in n main loops
scr41_Fail:	DS.B	1
	EVEN
scr41_Win:	DS.L	1		; 0 = none
	IFD	DEBUGAUTO
dbg_ScrBackPolls: DS.W	1
dbg_MonEsc:	DS.W	1		; sample monitor quits after n polls like esc
dbg_HwVolIn:	DS.W	1		; last paula volume before / after setup VOLUME
dbg_HwVolOut:	DS.W	1
dbg_RingVol:	DS.W	1		; last ring channel volume from the setup VOLUME gad
dbg_RateSteps:	DS.W	1		; ahi rate arrow steps
dbg_ChipDeny:	DS.W	1		; sample move finds no chip ram
dbg_AllocDeny:	DS.W	1		; song load buffer alloc fails
dbg_WideDeny:	DS.W	1		; wide pattern grow fails
dbg_ScrBackDma:	DS.W	1		; dmaconr at the fake click
	EVEN
dbg_ScrBackWin:	DS.L	1
dbg_AllocFh:	DS.L	1		; file handle seen at that alloc
	ENDC
snd_ResDefer:	DS.B	1		; resume in n main loops
snd_RateHeld:	DS.B	1		; ahi rate arrow: one step per press
	EVEN
snd_ResMode:	DS.L	1		; dat_RpPlayMode, 0 = none
snd_ResSong:	DS.L	1
snd_ResPat:	DS.L	1
snd_ResEdit:	DS.L	1		; dat_SongDataPtr ('edit' = recording)
	EVEN
prf_Found:	DS.B	1
prf_AutoAhi:	DS.B	1
prf_AutoRtg:	DS.B	1
prf_AutoAgus:	DS.B	1
smp_ChipDue:	DS.B	1		; samples may sit in fast ram
smp_ChipFail:	DS.B	1
smp_ChipRetry:	DS.B	1		; a move found no chip ram: try again later
smp_ChipPoll:	DS.B	1
prf_MsgDone:	DS.B	1
	EVEN
prf_MsgCnt:	DS.W	1
prf_AgusKeep:	DS.B	1		; prefs say amigus, not taken (no card / busy)
ahi_ModeGone:	DS.B	1		; saved ahi mode id unknown, default used
snd_RateFit:	DS.B	1		; last mix rate was moved into the ahi mode range
	EVEN
ahi_Real:	DS.L	1		; mix rate ahi runs at, 0 = unknown
snd_AhiMin:	DS.L	1		; mode limits while ahi runs, 0 = unknown
snd_AhiMax:	DS.L	1
smp_ChipNeed:	DS.L	1		; smallest sample that found no chip ram
	EVEN
;--- help
hlp_Tail:	DS.B	6		; 'K' first k n step
;--- vu8
vu8_On:		DS.B	1		; sprite data in 2-bar format
vu8_Cop:	DS.B	1		; copper multiplex jump installed
vu8_Frame:	DS.B	1		; plot every 2nd call
vu8_BarCh:	DS.B	1		; sampler play bar ch
	EVEN
vu8_Dummy:	DS.L	2		; sprite header sink
vu8_Pos:	DS.B	8*20		; scope pos per ch like dat_ScopeChanPos
vu8_Src:	DS.B	8*8		; per ch: src ptr.l, scale.w, pad
vu8_CopOrg:	DS.L	3		; dat_14AB start before the jump
vu8_Bar2:	DS.L	4*48		; 2nd bar data per spr and row, like dma
vu8_Prev:	DS.W	4*3		; per spr: thresholds bar 1/2, pos
wsb_Pos:	DS.B	32*20		; wide sampler: scope pos per ch
;--- formats
smx_Mem:	DS.L	1		; table of samples 32-63 or 0
smx_Tag:	DS.L	2		; 'PT4X', count
smx_Swp:	DS.W	1		; sample in slot 31 or 0
smx_Sv:		DS.W	1
smx_Ld:		DS.W	1		; entry in loading
smx_LdN:	DS.W	1
smx_WrN:	DS.W	1		; entries left to save
smx_WrL:	DS.W	1
smx_AllL:	DS.W	1		; all-samples loop: entry in slot 31
smx_AllN:	DS.W	1
smx_AllSv:	DS.W	1
smx_Saving:	DS.W	1		; module save running: errors stay on the status line
smx_Zero:	DS.B	34		; empty header + pointer
chg_Base:	DS.L	2		; module fingerprint after load/clear/save
chg_Valid:	DS.B	1
chg_Due:	DS.B	1		; fingerprint on next main loop pass
disk_RenLong:	DS.L	1		; rename: long name of the old file
fmt_Buf:	DS.L	1		; pattern work buffer while converting (2 kb)
;--- tracks
trk_Show:	DS.B	1		; 1..8 tracks of the song in 8ch (4 in 4ch)
trk_Drawn:	DS.B	1		; slots the backdrop shows, 0 = 8
trk_Pack:	DS.B	1		; save: rows packed to trk_Show cells
trk_Pad:	DS.B	1
chn_Ask:	DS.B	48		; channel count question, number filled in
chn_Paused:	DS.B	1		; count change paused the play
chn_Pad:	DS.B	1
WB_Y0		EQU	136		; slider: frame lines over the heads
WB_ROWS		EQU	4
WB_B0		EQU	6		; byte of x 48: over track 1
WB_NB		EQU	72		; bytes: 8 tracks of 72 px
WB_KMIN		EQU	4		; smallest knob (bytes)
WB_PL		EQU	WB_ROWS*WB_NB	; plane 1 in wbar_Save
wide_Hdr:	DS.B	mod_patterns	; header while pt's view changes size
wbar_Save:	DS.B	2*WB_ROWS*WB_NB	; slider rows as they were (planes 0, 1)
wbar_DrA:	DS.B	WB_NB		; upper half: first row, plane 0, as drawn
wbar_DrB:	DS.B	WB_NB		; lower half
wbar_Sel:	DS.B	6		; planes 0, 1: light, face, dark -> $ff / 0
wbar_K0:	DS.W	1		; knob, bytes of the bar
wbar_K1:	DS.W	1
wbar_KN:	DS.W	1		; grip byte
wbar_OkA:	DS.B	1		; upper half saved and drawn
wbar_OkB:	DS.B	1		; lower half
wbar_DrK:	DS.W	1		; knob start while dragged
wbar_DrOn:	DS.B	1		; knob follows the pointer
wbar_DrPad:	DS.B	1
chc_Org:	DS.B	48		; 4/8 cells as pt drew them (glyph rows)
chc_Drw:	DS.B	48		; cells with the count, as drawn
chc_N:		DS.W	1		; count drawn
chc_On:		DS.B	1		; cells show the count
wsc_Busy:	DS.B	1		; panel box being drawn (scope irq)
wide_NoView:	DS.B	1		; view change failed: not again for this module
wide_Is64:	DS.B	1		; view change fell back to 64 patterns
wnat_Req:	DS.B	1		; key wish: group step (signed)
wnat_Pad:	DS.B	1
trk_HeadReq:	DS.W	1		; rtg head click: channel + 1 to switch
trk_HeadLatch:	DS.B	1		; button still down since that click
trk_PenOn:	DS.B	1		; head number pens
trk_PenOff:	DS.B	1
trk_PenPad:	DS.B	1
ftr_Buf:	DS.L	2		; save footer
req_Patch:	DS.B	1		; intuition patch in place
req_Front:	DS.B	1		; ctrl-f from a second start (count)
req_PwBack:	DS.B	1		; pp password: pt was sent back
req_Pad:	DS.B	1
	IFD	DEBUGAUTO
mid_DbgCnt:	DS.B	2		; midi notes entered (test)
dbg_WideOk:	DS.B	2
dbg_Wide4:	DS.B	2		; wide module keeps pt's 4 track view
dbg_ChnMsg:	DS.L	1		; last channel count message (test)
dbg_ChnAsk:	DS.W	1		; channel questions asked (test)
mem_Largest:	DS.L	1
smx_DbgHit:	DS.W	1		; largest chip block before the 64 pattern try
dbg_FakeAgus:	DS.B	2		; card faked in ram
dbg_AgFail:	DS.B	2		; next uploads end with fifo full
dbg_AhiRealSet:	DS.L	1		; test: rate the ahi driver reports
dbg_AhiMute:	DS.B	2		; test: ahi never asks for a half
dbg_FakeRegs:	DS.B	80		; its wavetable registers
dbg_AgHead:	DS.L	1		; write log: records so far
dbg_AgStarts:	DS.W	32		; start writes per voice
dbg_AgTime:	DS.W	8		; card run: raster line at the stages, last run, 5 = irq entry
dbg_AgMaxT:	DS.W	8		; stage lengths of the longest tick, 5 = replayer
dbg_AgLen:	DS.W	8		; stage lengths of the last tick
dbg_AgSum:	DS.L	8		; ... summed, 6 = ticks
dbg_AgSkip:	DS.W	1		; runs cut short
dbg_AgLate:	DS.W	1		; ticks that started late
dbg_LvHits:	DS.W	32		; level hits per channel
dbg_AgShadow:	DS.L	32*6		; per voice: ctrl start loop end rate vol
dbg_AgRing:	DS.B	AGLOG_N*8	; tick.w voice.b reg.b value.l
	ENDC
