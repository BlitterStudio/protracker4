; protracker 4.1

EXT_0000	EQU	$0
ABSEXECBASE	EQU	$4
EXT_0002	EQU	$4A
CIAB_PRA	EQU	$BFD000
CIAB_DDRA	EQU	$BFD200
CIAA_PRA	EQU	$BFE001
CIAA_PRB	EQU	$BFE101
CIAA_DDRB	EQU	$BFE301
CIAA_SDR	EQU	$BFEC01		; keyboard shift reg
HARDBASE	EQU	$DFF000
DMACONR		EQU	$DFF002
JOY1DAT		EQU	$DFF00C
POTGOR		EQU	$DFF016
INTENAR		EQU	$DFF01C
INTREQR		EQU	$DFF01E
BLTCON0		EQU	$DFF040
BLTCON1		EQU	$DFF042
BLTAFWM		EQU	$DFF044
BLTCPTH		EQU	$DFF048
BLTAPTH		EQU	$DFF050
BLTDPTH		EQU	$DFF054
BLTSIZE		EQU	$DFF058
BLTCMOD		EQU	$DFF060
BLTBMOD		EQU	$DFF062
BLTAMOD		EQU	$DFF064
BLTDMOD		EQU	$DFF066
BLTBDAT		EQU	$DFF072
BLTADAT		EQU	$DFF074
DENISEID	EQU	$DFF07C
COP1LCH		EQU	$DFF080
COPJMP1		EQU	$DFF088
DMACON		EQU	$DFF096
INTENA		EQU	$DFF09A
INTREQ		EQU	$DFF09C
AUD0LCH		EQU	$DFF0A0
AUD0VOL		EQU	$DFF0A8
AUD1LCH		EQU	$DFF0B0
AUD1VOL		EQU	$DFF0B8
AUD1DAT		EQU	$DFF0BA
AUD2LCH		EQU	$DFF0C0
AUD2VOL		EQU	$DFF0C8
AUD3LCH		EQU	$DFF0D0
AUD3VOL		EQU	$DFF0D8
BPLCON0		EQU	$DFF100
COLOR00		EQU	$DFF180
COLOR17		EQU	$DFF1A2
BEAMCON0	EQU	$DFF1DC
EXT_002e	EQU	$F80000

; orig was 68020-only tst.x (d16,pc) -> abs, 6 bytes instead of 4
TSTPC	MACRO
	TST.\0	\1
	ENDM

; -DSHIFTTEST=n: pad n bytes at sites picked by SHIFTMASK
SHIFTPAD	MACRO
	IFD	SHIFTTEST
	IF	(SHIFTMASK>>\1)&1
	DS.B	SHIFTTEST
	ENDC
	ENDC
	ENDM
SHIFTPADBIG	MACRO		; data hunks: 8x
	IFD	SHIFTTEST
	IF	(SHIFTMASK>>\1)&1
	DS.B	SHIFTTEST*8
	ENDC
	ENDC
	ENDM

LMB	MACRO
	; same length (8 bytes) in both builds
	IFD	DEBUGAUTO
	JSR	dbg_LMB
	NOP
	ELSE
	JSR	pt_LMB41
	NOP
	ENDC
	ENDM
RMB	MACRO
	IFD	DEBUGAUTO
	JSR	dbg_RMB
	NOP
	ELSE
	JSR	pt_RMB41
	NOP
	ENDC
	ENDM
; diag: one char to the debug output (RawPutChar); flags are lost
AGM	MACRO				; \2 = agus_Mem + \1 (card tables, allocated)
	MOVEA.L	agus_Mem,\2
	ADDA.W	#\1,\2
	ENDM

AGW	MACRO				; card register write -> test log
	IFD	DEBUGAUTO
	IFND	AGNOLOG			; timing builds: no log
	BSR.W	dbg_AgRec
	DC.W	\1
	ENDC
	ENDC
	ENDM

DK	MACRO
	IFD	DIAGK
	MOVEM.L	D0-D1/A0-A1/A6,-(A7)
	MOVEQ	#\1,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	(-516,A6)
	MOVEM.L	(A7)+,D0-D1/A0-A1/A6
	ENDC
	ENDM

; build stamp: date time commit, 25 chars
	IFD	PTSTAMP
	INCLUDE	"build/stamp.i"
	ELSE
STAMP	MACRO
	DC.B	"UNKNOWN                  "
	ENDM
	ENDC

	INCLUDE	"include/pt_structs.i"




;--- hunk 0: original
	INCLUDE	"src/sys/init.asm"
	INCLUDE	"src/sys/input.asm"
	INCLUDE	"src/ui/scope.asm"
	INCLUDE	"src/ui/diskop_ui.asm"
	INCLUDE	"src/ui/mainui.asm"
	INCLUDE	"src/engine/songctl.asm"
	INCLUDE	"src/ui/buttons.asm"
	INCLUDE	"src/ui/setup.asm"
	INCLUDE	"src/ui/paledit.asm"
	INCLUDE	"src/io/iff.asm"
	INCLUDE	"src/ui/mainpanel.asm"
	INCLUDE	"src/io/load.asm"
	INCLUDE	"src/ui/options.asm"
	INCLUDE	"src/ui/patops.asm"
	INCLUDE	"src/ui/smpops.asm"
	INCLUDE	"src/io/fileio.asm"
	INCLUDE	"src/ui/patview.asm"
	INCLUDE	"src/ui/plst.asm"
	INCLUDE	"src/ui/sampler.asm"
	INCLUDE	"src/engine/replayer.asm"
	INCLUDE	"src/ui/info.asm"
;--- hunk 0: 41 modules
	INCLUDE	"src/engine/mixer.asm"
	INCLUDE	"src/engine/mix68k.asm"
	INCLUDE	"src/io/formats.asm"
	INCLUDE	"src/sys/cpu.asm"
	INCLUDE	"src/io/diskop.asm"
	INCLUDE	"src/ui/edit.asm"
	INCLUDE	"src/ui/vu8.asm"
	INCLUDE	"src/engine/efx8.asm"
	INCLUDE	"src/io/samples.asm"
	INCLUDE	"src/sys/ahi.asm"
	INCLUDE	"src/sys/cardflt41.asm"
	INCLUDE	"src/sys/rtg.asm"
	INCLUDE	"src/sys/rtgpat.asm"
	INCLUDE	"src/sys/rtgwide.asm"
	INCLUDE	"src/sys/rtgtrk.asm"
	INCLUDE	"src/sys/diagwin.asm"
	INCLUDE	"src/io/exe8.asm"
	INCLUDE	"src/engine/mixit.asm"
	INCLUDE	"src/ui/setup41.asm"
	INCLUDE	"src/ui/filter41.asm"
	INCLUDE	"src/io/dyn41.asm"
	INCLUDE	"src/io/midi41.asm"
	INCLUDE	"src/sys/amigus41.asm"
	INCLUDE	"src/sys/agfake41.asm"
	INCLUDE	"src/sys/sndout41.asm"
	INCLUDE	"src/io/wide41.asm"
	INCLUDE	"src/io/loadmode.asm"
	INCLUDE	"src/ui/status41.asm"
	INCLUDE	"src/io/iocheck41.asm"
	INCLUDE	"src/engine/smpx41.asm"
	INCLUDE	"src/io/chg41.asm"
	INCLUDE	"src/ui/trk41.asm"
	INCLUDE	"src/ui/wnat41.asm"
	INCLUDE	"src/ui/chn41.asm"
	INCLUDE	"src/io/ftr41.asm"
	INCLUDE	"src/sys/dup41.asm"
	INCLUDE	"src/sys/tail.asm"
;--- data
	INCLUDE	"src/data/data.asm"
	INCLUDE	"src/data/chipdata.asm"
	INCLUDE	"src/data/bss.asm"
	END
