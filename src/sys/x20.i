; x20: 68020-only tables, alloc'd by pt_MixInitTask, X20LEA ofs,An
	RSRESET
X20_VOLTAB	RS.B	65*256		; voltab[vol][smp] = (smp*vol)>>7
X20_RTGP2C	RS.B	2048		; rtg: p2c 256x8
X20_RTGSIG	RS.L	768		; rtg: line sigs (output lines)
X20_RTGPSIG	RS.L	768		; rtg: plane data sum per line
X20_RTGBSIG	RS.L	768		; rtg: line sigs without the analyzer stage (output lines)
X20_RTGKEY	RS.L	768		; rtg: bank, planes, ptrs per line
X20_RTGHEAT	RS.B	768		; rtg: frames a line stays read
X20_RTGBANKS	RS.W	8*30		; rtg: color banks
X20_RTGSEGS	RS.B	12*32		; rtg: spr segs
X20_RTGSPRRGB	RS.W	256		; rtg: spr colors
X20_RTGCOLMAP	RS.B	4096		; rtg: $0rgb -> clut idx
X20_RTGSPRLN	RS.B	320		; rtg: sprite segs per raster line
X20_RTGPAL	RS.L	2+30*8*3+16*3+1	; rtg: LoadRGB32 table
X20_RTGCTAB	RS.L	256		; rtg: $00rrggbb per pixel value
X20_RPRSLOT	RS.L	80		; content per slot: style, bar gen, row (RPR_MAXN)
X20_RPRRP	RS.B	100		; rastport of the card bitmap
X20_RPRRP2	RS.B	100		; second rastport
X20_RPRBARCOL	RS.B	9*16		; bar lines: scroll column before sprites
X20_RPRVUNEW	RS.W	3*12		; sprite columns of this frame (x, top, end)
X20_RPRVUOLD	RS.W	3*12		; sprite columns of the last frame
X20_SIZE	RS.B	0

X20LEA	MACRO
	MOVEA.L	x20_Base,\2
	IFGT	\1-32767
	ADDA.L	#\1,\2
	ELSE
	LEA	\1(\2),\2
	ENDC
	ENDM

; rtg buffers, alloc'd with the mirror (68020+ only, not in the bss)
RM_TPL		EQU	0		; empty pattern lines even/odd (2 x 640)
RM_BAR		EQU	RM_TPL+2*640	; cursor bar lines 197-205 (9 x 640)
RM_LINE		EQU	RM_BAR+9*640	; slot being built (8 x 640)
RM_VU		EQU	RM_LINE+8*640	; one sprite column (40 x 104)
RM_SPR		EQU	RM_VU+40*104	; sprite data sum per line (256 longs)
RM_SIZE		EQU	RM_SPR+4*256

RMLEA	MACRO
	MOVEA.L	rtg_Mem,\2
	LEA	\1(\2),\2
	ENDM

; rtg wide window buffers, alloc'd only while the wide layout is on
RWD_WMAX	EQU	2560		; widest picture (track view, factor 1)
RWD_TS		EQU	RWD_WMAX/8	; text bytes a line
WM_TXT		EQU	0		; wide text: 64 rows x 8 lines x RWD_TS
WM_TPL		EQU	WM_TXT+64*8*RWD_TS	; empty pattern lines even/odd (2 x width)
WM_LINE		EQU	WM_TPL+2*RWD_WMAX	; slot being built (8 x width)
WM_BAR		EQU	WM_LINE+8*RWD_WMAX	; cursor bar (9 x width)
WM_BPRE		EQU	WM_BAR+9*RWD_WMAX	; narrow bar lines before sprites (9 x 640)
WM_VU		EQU	WM_BPRE+9*640	; one sprite column (80 x 104)
WM_TMAP		EQU	WM_VU+80*104	; wide x -> narrow x: pattern lines
WM_HMAP		EQU	WM_TMAP+2*RWD_WMAX	; ... track heads
WM_FX		EQU	WM_HMAP+2*RWD_WMAX	; narrow x -> wide x, bit 15: 2 px
WM_DBL		EQU	WM_FX+2*640	; byte -> bits doubled
WM_XH		EQU	WM_DBL+2*256	; window x -> line x: heads
WM_XT		EQU	WM_XH+2*4096	; ... pattern lines
WM_XS		EQU	WM_XT+2*4096	; ... full width lines
WM_X0		EQU	WM_XS+2*4096	; ... panel top row (exit wide, title strip)
WM_GLY		EQU	WM_X0+2*4096	; glyph hash -> char + 1
WM_STG		EQU	WM_GLY+256	; analyzer stage: 640 x 125 colour codes
WM_XA		EQU	WM_STG+640*125	; window x -> line x: stage rows
WM_SPRV		EQU	WM_XA+2*4096	; scope height per column (all boxes)
WM_SGEN		EQU	WM_SPRV+640	; stage row changes
WM_SLAST	EQU	WM_SGEN+128	; ... as last seen by the mirror
WM_SOLD		EQU	WM_SLAST+128	; stage rows as the lut buffer was made from them
WM_SIZE		EQU	WM_SOLD+640*125

WMLEA	MACRO
	MOVEA.L	rwd_Mem,\2
	IFGT	\1-32767
	ADDA.L	#\1,\2
	ELSE
	LEA	\1(\2),\2
	ENDC
	ENDM
