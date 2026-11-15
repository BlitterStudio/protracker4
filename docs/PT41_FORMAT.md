# ProTracker 4.1 module format and playback semantics

For people who write a player that should load and play ProTracker 4.1 modules the way PT 4.1 does.
Everything here is taken from the source in `src/` (state 2026-11-09). References are `file:label`
(files relative to `src/`). Where the code leaves something open, the text says **unclear**. Nothing is
taken from other trackers; where 4.1 matches ProTracker 2.3D, the text says so because the code is the
same routine (the replayer `pt_Rp*` is the 2.3D replayer).

Terms: *cell* = 4 bytes of one channel in one row. *Tick* = one replayer call. *Counter* = tick within the
row (`dat_RpCounter`, 0 = first tick). *Mixer* = the software mixer (`engine/mixer.asm`), *Paula path* =
channels played directly by the Amiga sound chip.

---

## 1 File layout

### 1.1 Header (all formats except 15-sample)

| Offset | Size | Field | Load rule (`io/formats.asm:pt_FmtAfterHeader`, `pt_FmtPatCount`) |
|---|---|---|---|
| 0 | 20 | song name | raw |
| 20 + 30·(n-1) | 30 | sample header n = 1..31 | see 1.2 |
| 950 | 1 | song length | 0 -> 1; >= 128 -> 128 |
| 951 | 1 | restart byte | ignored, overwritten with `$7F` on load and on save |
| 952 | 128 | position table | raw; entries >= pattern capacity -> 0 (1.4) |
| 1080 | 4 | format id | 1.3 |
| 1084 | ... | patterns, then sample data, then optional `PT4X` block | |

The restart byte has no effect on playback: after the last position the song always continues at position 0
(`engine/replayer.asm:pt_RpNextPosition`).

### 1.2 Sample header (30 bytes, big endian)

| Offset | Size | Field |
|---|---|---|
| 0 | 22 | name |
| 22 | 2 | length in words |
| 24 | 1 | finetune: bits 0-3 finetune (0..7 = +0..+7, 8..15 = -8..-1); **bit 7 = DYN envelope follows the sample data** (section 4) |
| 25 | 1 | volume 0..64 |
| 26 | 2 | loop start (repeat) in words |
| 28 | 2 | loop length (replen) in words |

Sanitizing on load, samples 1-31 of a 31-sample module (`io/formats.asm:pt_FmtAfterHeader`):
volume > 64 -> 64; finetune `AND $8F` (bits 4-6 cleared, bit 7 kept); replen 0 -> 1; repeat >= length ->
repeat 0, replen 1; repeat + replen > length -> replen reduced by the overhang (min. 1).
Before 4.1.2 the loop end was summed with the stale high word of D1: depending on the
caller (always with XPK packed files) every loop was stretched to the sample end and one-shot samples
(repeat 0, replen 1) looped over their whole length. libpt4 was not affected.
For every loaded sample (also 15-sample modules and `PT4X` entries): replen 0 -> 1 (`io/fileio.asm:pt_CheckRowDataSize`)
and the **first word of the sample data is set to 0** (`ui/sampler.asm:pt_SampleClearLoop`).
15-sample modules get the same clamps for samples 1-15 (`io/formats.asm:pt_Fmt15Clamp41`, 4.1.2). `PT4X` entries get the same clamps as
samples 1-31 right after the header block is read (`engine/smpx41.asm:pt_SmxClampHdrs`, same routine
`io/formats.asm:pt_FmtClampSmp`).

### 1.3 Format ids read at offset 1080

Order of the checks: `io/fileio.asm:pt_DosLibDiskOp`, then `io/formats.asm:pt_FmtCheckMore`
(`io/wide41.asm:pt_WideCheck` first, then `pt_FmtNarrowId`).
Before that, `pt_DosLibDiskOp` tests the first 4 bytes for packers, IFF and foreign formats (MMD0-3, SymM, DIGI, TFMX,
FC14, SOAR, hunk file `$3F3`). Since 4.1.2 a known id at 1080 wins over a foreign magic at offset 0 (a song name
that starts with "MMD1", `io/formats.asm:pt_MagicMod41`): `M.K.`, `M!K!`, `FLT4`, `FLT8`, `EXO4`, `!PM!`, `CD81`,
`OCTA`, `CD61`, `TDZ` + any byte, `1CHN`..`9CHN`, two digits + `CH`/`CN` (`pt_ModIdOk41`). Packers, IFF and hunk
files are tested before and are never taken as a module.

| Id | Channels | Pattern size in file | Handling |
|---|---|---|---|
| `M.K.`, `!PM!`, `FLT4`, `EXO4` | 4 | 1024 | standard |
| `M!K!` | 4 | 1024 | standard, pattern buffer forced to 100 (64 if memory fails, `io/loadmode.asm`) |
| `4CHN`, `TDZ4` | 4 | 1024 | as `M.K.` |
| `8CHN` | 8 | 2048 | standard 8 channel layout (row = 8 cells) |
| `CD81`, `OCTA` | 8 | 2048 | as `8CHN` |
| `FLT8` | 8 | 2 x 1024 | see below |
| `1CHN`..`7CHN` (not 4), `TDZ1`..`TDZ3`, `CD61` (6) | n | n·256 | loaded into the 8 channel layout, tracks n+1..8 empty and hidden (`pt_FmtNarrow`) |
| `9CHN`, `10CH`..`32CH` (also `09CH`), `09CN`..`32CN` (TakeTracker) | 9..32 | n·256 | wide module, see 1.6 |
| anything else | 4 | 1024 | requester "15 or 31 samples"; 15-sample layout (1.5) |

`FLT8`: positions in the file are even (one 8-channel pattern = two consecutive 4-channel patterns). PT halves
every position byte before counting patterns (`pt_FmtAfterHeader`, bit 0 is lost), reads
`max(positions)+1` blocks of 2048 bytes and interleaves each block row by row: first 1024 bytes = channels 1-4,
second 1024 bytes = channels 5-8 (`pt_FmtAfterPatterns`). Afterwards the module is `8CHN`.

`OCTA` is only accepted at offset 1080; `OCTA`, `MMD0..3`, `SymM`, `DIGI`, `TFMX`, `FC14`, `SOAR` at file
offset 0 are rejected.

Pattern cell (all formats): byte 0 high nibble + byte 2 high nibble = sample number,
`sample = (byte0 & $F0) | (byte2 >> 4)`; period = `(byte0 & $0F) << 8 | byte1`; effect = `byte2 & $0F`,
parameter = byte 3 (`engine/replayer.asm:pt_RpReadNote`). Because the full high nibble of byte 0 is used,
samples 32..63 are stored with byte 0 high nibble 2 or 3. Sample numbers > 63 found on load are cleared to 0
(both nibbles, `io/formats.asm:pt_FmtScanPeriods`); in wide modules only tracks 1-4 are scanned, tracks 5..32 keep
the number and play it as sample 63 (`engine/smpx41.asm:pt_SmxPhys`). Periods are not changed; periods outside 113..856 are only
counted (message "NOTES OUTSIDE PT OCTAVES").

### 1.4 Pattern count

`io/formats.asm:pt_FmtPatCount`: patterns in the file = highest value of **all 128** position bytes + 1
(also entries behind the song length, as 2.3D). The pattern buffer holds C patterns: C = 100 normally, 64 with the
editor setting PATTERN 64 or when the 100-pattern buffer could not be allocated (`M!K!` asks for 100). If the file
has more than C patterns: only C are read, every position byte >= C becomes 0, the file is positioned at
`1084 + filepatterns·patternsize` for the samples, message "TOO MANY PATTERNS: REST NOT LOADED".
A player that wants PT's result uses C = 100.

### 1.5 15-sample modules

`io/fileio.asm:pt_0E43`: 20 bytes name, 15 sample headers (470 bytes), then song length, restart, 128 positions
(130 bytes, total 600); patterns follow at offset 600. Samples 16-31 are empty headers with replen 1. The id
field becomes `M.K.`. Restart is set to `$7F`. On file load the requester answer 2 aborts ("unknown format"),
answers 1 and 3 both take this branch (`io/formats.asm:pt_FmtCheckMore` `.unknown`, as in the original); the label
on each button is in the requester bitmap.

### 1.6 Wide modules (9..32 channels)

`io/wide41.asm`. Rows are n·4 bytes in the file. PT keeps the first 4 channels as a 4-channel module
(id changed to `M.K.` in memory) and all channels in `wide_Pat` (32 cells per row, unused cells 0).
The replayer runs the module **as a 4-channel module** (row step 16 bytes, pattern end at 1024, `Dxx` limit 63)
but processes 32 channel structures per row with the cells from `wide_Pat` (`pt_WideLoop`). Pattern count as 1.4
with the capacity of the 4-channel pattern buffer (64, or 100 with PATTERN 100; `pt_WideCap`); like any module,
patterns past it are not kept and the positions using them become 0. Playback in PT only with AmiGUS output (see 7.5).

### 1.7 Sample data

After the patterns: samples 1..31 in order, each `length·2` bytes signed 8-bit. Directly behind the data of a
sample with finetune bit 7 the DYN envelope follows (section 4). A sample of length 0 has no data and no
envelope (`io/fileio.asm:pt_0E5F`, `BEQ pt_CheckRowDataSize`). A short file is padded with 0
(`io/formats.asm:pt_FmtRead`, message "MODULE TRUNCATED").

---

## 2 Ids written on save

| Editor state | Id | Rows | Source |
|---|---|---|---|
| 4 channel mode | `M.K.`; `M!K!` if the highest pattern index >= 64 | 4 cells | `io/fileio.asm` at `pt_0ED1` |
| 8 channel mode, 8 tracks shown | `8CHN` | 8 cells | same |
| 8 channel mode, n < 8 tracks shown | `nCHN`; n = 4: `M.K.`/`M!K!` | n cells | `ui/trk41.asm:pt_TrkSaveId41`, `pt_TrkWrite41` |
| wide module | `9CHN` or `xxCH` | all channels | `io/wide41.asm:pt_WideSaveId` |

Always: restart byte `$7F`; patterns `0..highest index in the 128 positions`; samples 1..31 (+ envelope);
then the `PT4X` block if any sample 32..63 is used (not in packed/XPK saves, not in SAVE EXE). Ids `CD81`, `OCTA`,
`FLT8`, `TDZx`, `CD61`, `4CHN`, `!PM!`, `FLT4`, `EXO4` are never written.

### 2.1 Footer `PT41`

`io/ftr41.asm` (`pt_FtrTail41`, `pt_FtrFlags41`). If the saved module uses a 4.1 extra, the save appends 8 bytes as
the **last bytes of the file** (after sample 31 and its envelope, or after the `PT4X` block):

```
'PT41'                    4 bytes
version                   2 bytes, big endian, $0412
flags                     2 bytes, big endian
  bit 0                   a saved pattern cell has 8xy with x = 1, 2, 3, 4, 6 or 7 and y != 0 (sub-effect, 5.4)
  bit 1                   block PT4X written (section 3)
  bit 2                   at least one DYN envelope written (4.1, samples 1..31 or PT4X entries)
  bits 3-15               0
```

- No extra -> no footer: such a module is byte-identical to a save without this feature.
- `80y`, `85y`, `88y`..`8Fy` (y != 0) do nothing in 4.1 and do not set bit 0; the save message "8XY EFFECTS:
  PT 4.1 ONLY" still appears for them (it tests y != 0 only). `8x0` (colour) never counts.
- Scanned cells are exactly the saved ones: patterns `0..highest position byte`, 4 cells per row (4ch), the shown
  tracks (`nCHN`, `8CHN`) or all channels of a wide module (`wide_Pat`).
- Bit 2 is set when the save really wrote an envelope (bit 7 of finetune alone does not count).
- Not written: packed saves (PowerPacker/XPK, as `PT4X`), SAVE EXE (own writer `pt_SaveSampleLoop`). Written in the
  normal and the wide module save, also with the Disk-Op `FORM` setting (behind the IFF data, like `PT4X`).
- Loading: PT reads 8 bytes after sample 31 (section 3); `'PT41'` is not `'PT4X'`, so loading ends there without a
  message. Behind a `PT4X` block nothing is read. 4.1.1 and older stop after sample 31 and never read the footer.
  A player that wants the module data strips the footer if the last 8 bytes start with `'PT41'`.

---

## 3 Samples 32..63: block `PT4X`

`engine/smpx41.asm`. Written by `pt_SmxWrite`, read by `pt_SmxNext`.

Position: immediately after the data of sample 31 (and its DYN envelope, if any), i.e. at the end of a normal
module.

```
'PT4X'                    4 bytes
count                     4 bytes, big endian, 1..32 (entries for samples 32..31+count)
count x 30 bytes          sample headers as 1.2 (bit 7 of finetune = DYN envelope follows the entry's data)
data of entry 32          length*2 bytes, then DYN envelope if bit 7 (section 4)
data of entry 33 ...      same, up to 31+count
```

Detection: after sample 31 PT reads exactly 8 bytes (a footer `'PT41'` there ends loading, 2.1). A block is accepted only if they are `'PT4X'` and
`1 <= count <= 32`; otherwise loading ends there (the 8 bytes are not given back, nothing else is read). Not read
from PowerPacker/XPK files or from memory images (`dat_FileIOState`, `dat_XpkLibFlag`).

Count written = last used entry + 1; an entry is "used" if its name does not start with 0 or its length is not 0
(`pt_SmxCount`). Entries with only volume/loop/finetune set and no name/length at the end are dropped.

Cells: sample number 32..63 as in 1.3. The replayer maps a logical number to a physical slot (`pt_SmxPhys`,
`pt_SmxNote`); numbers > 63 are clamped to 63 there. If a cell names 32..63 and no block was loaded, the entry
is an all-zero header: the note sets volume 0 and plays silence (`pt_SmxNote`, label `.z`).
Other players ignore the trailing block; cells with 32..63 are invalid for them.

---

## 4 DYN volume envelopes

### 4.1 Storage in a module

`io/fileio.asm:pt_0E60`, `io/dyn41.asm`. Only for samples with length > 0 and finetune bit 7 set:

```
sample data               length*2 bytes
L                         4 bytes, big endian: envelope size in bytes
envelope                  L bytes:
  nseg                    word, number of segments (> 0)
  loopseg                 word (dyn41.asm calls it "pad"; pt_BuildChunkList uses it as loop index, see 4.3)
  nseg x { len, vol }     words: segment length in sample words, volume 0..64
```

Validation (`pt_DynLenCheck41`, `pt_DynValid41`):
- L = 0: the 4 bytes are consumed, no envelope; bit 7 stays set (**unclear** if intended).
- L odd, L < 8 or L > 65536: "junk bit" -> file position goes back 4 bytes (they belong to the next sample),
  bit 7 cleared.
- After reading L bytes: nseg <= 0 (signed), nseg > (L-4)/4, or any vol > 64 (unsigned) -> file goes back L+4
  bytes, envelope dropped, bit 7 cleared.

Save writes bit 7, L and the envelope again (`io/fileio.asm` after `pt_0EE0`). In 8SVX the envelope is chunk
`DYN ` (same content). PT4X entries carry envelopes the same way.

### 4.2 UNDYN

Setup UNDYN MOD (`dat_UIBitFlags` bit 4) bakes the envelope into the data on load and removes it
(`io/dyn41.asm:pt_DynModRead`, `pt_DynApply`): segments are applied in order from the sample start, each byte
`b -> b·vol / 64` (signed `MULS`, `DIVS`, truncation toward 0); bytes behind the last segment stay unchanged; segments
past the sample end are ignored; `loopseg` is ignored. Bit 7 is cleared, the saved module has no envelope.

### 4.3 Playback semantics

A sample with envelope is played as a *chunk list* instead of start/length/loop
(`engine/songctl.asm:pt_BuildChunkList`, Paula path `sys/init.asm:pt_RpAudInt`):
- chunk i starts at `sample + 2·(len_0 + .. + len_{i-1})`, is `len_i` words long and has volume `vol_i`;
- chunks play back to back; the sample's own repeat/replen is **not used**;
- after the last chunk: `loopseg = 0` -> silence (16 zero words); `loopseg = k > 0` -> continue with chunk k
  (0-based) and repeat chunks k..nseg-1 forever;
- volume of the playing chunk = `(vol_i · irqvol + 32) >> 6`, at least 1 if both factors are non-zero, with
  `irqvol = (n_volume · volscale + 32) >> 6` recomputed every tick (`engine/replayer.asm:pt_RpSetVolumeChunked`);
- `9xx` on such a sample: the chunk containing the offset is shortened and the list is cut at `n_length`
  (`pt_RpStartChunked`);
- `87y` tremor does not gate envelope samples (`engine/efx8.asm:pt_Efx8SetVolume`).

**Unclear / inconsistent in the code:** the software mixers (`engine/mixer.asm:pt_MixUpdateVoice`,
`engine/mix68k.asm`) do not evaluate the chunk list: they play an envelope sample linearly from `n_start` with its
normal loop at the constant volume `irqvol`. The AmiGUS path applies the chunk volume at the play position
(`sys/amigus41.asm:pt_AgusDynVol`, loop from the chunk list `pt_AgusLoop`). So the envelope is heard on Paula 4ch and
AmiGUS, not in 8 channel mixing or AHI. A library should implement 4.3 and offer the mixer behaviour only as a
compatibility switch.

---

## 5 Replayer

### 5.1 Timing

| Item | Rule | Source |
|---|---|---|
| Start | speed 6 after load (`pt_0E67`), tempo = setup TEMPO (default 125). The counter starts at 0 and is increased before the compare, so row 0 is read on the `speed`-th tick (2.3D semantics) | `ui/mainui.asm`, `pt_RpMusic` |
| Tick | `counter++`; `counter >= speed` -> counter 0, new row (or pattern delay repeat); else effects only | `pt_RpMusic` |
| CIA mode (default) | tick period = `floor(base / bpm)` E-clock cycles, base PAL 1 773 447, NTSC 1 789 773; E-clock PAL 709 379 Hz. bpm < 32 -> 32 | `sys/init.asm:pt_SetTempo` |
| Tempo latch | the timer is restarted with `START` only (no `LOAD`): the new period applies from the next underflow, i.e. the tick that executed `Fxx` still has the old length (as 2.3D) | `pt_SetTempo` (`ORI.B #$01`) |
| VBlank mode | tick = vertical blank (50 Hz PAL); **every** `Fxx` with xx > 0 sets the speed | `pt_RpSetSpeed` |
| `Fxx` | xx = 0: playback stops (`dat_RpPlayMode` = 0); xx < 32: speed = xx, counter = 0; xx >= 32 (CIA mode): tempo | `pt_RpSetSpeed` |
| Song end | after the last position: position 0 (restart byte not used); `Bxx`: next position = xx, `& $7F`, >= song length -> 0 | `pt_RpNextPosition`, `pt_RpPositionJump` |
| Pattern end | 4ch: row offset 1024, 8ch: 2048 (64 rows) | `pt_RpNextRow` |
| End of playback | only F00 or user stop; the song loops forever | `openspec/specs/playback` |

Mixer tick length (only relevant for the mixer reference, 7.2): samples per tick as 16.16 fixed point
`spt = rate · floor(base/bpm) / 709379` (CIA) or `rate / VBlankFrequency` (VBlank, NTSC corrected), the
fraction is carried in 16 bits (`engine/mixer.asm:pt_MixCalcSpt`, `pt_MixOneTick`). The mixer recomputes
`spt` before it mixes a tick when the tempo changed, so in the mixer the tick that executed `Fxx` is already
mixed with the new length (differs from the CIA latch by one tick; **unclear** if intended).

### 5.2 Note handling (tick 0)

As 2.3D (`pt_RpPlayVoice`, `pt_RpSetRegs`, `pt_RpSetPeriod`):
- Sample number != 0: sets start, length, finetune, volume, loop from the header. Loop: `repeat != 0` ->
  `n_loopstart = start + 2·repeat`, `n_length = repeat + replen` (Paula path: `2·repeat` as a word, `ASL.W`, so a
  loop start at or above 64 KB wraps as in 2.3D; mixer and card add it as a long, `engine/efx8.asm:pt_LoopSet41`); `repeat = 0` -> `n_loopstart = start`,
  `n_length` = sample length, `n_replen` = header replen.
- Period != 0: `3xx`/`5xx` set the porta target only; `E5x` sets finetune before the lookup; `Cxx` is applied
  before, `9xx` before the lookup; `EDx` skips the trigger (note delay).
- Period lookup: first entry of the finetune-0 row with `period >= entry` gives the index, the period is taken from
  the row of `n_finetune & $0F`. The table has 16 rows of **37** words: 36 periods (856..113) and a terminating 0
  (`ui/info.asm:dat_PeriodTable`, stride 74 bytes). Consequence: a cell period > 856 gets index 0 (C-1 of the
  finetune row); a cell period 1..112 hits the terminator and sets `n_period = 0` (silent). With setup NOTES EXT or in a wide module (`pt_NoteExt41`) a cell period above 856 or below 113 is taken as it is (`pt_PerLookup41`); arpeggio, glissando, `3xx` and the `1xx`/`2xx` limits (57..1712) follow.
- Vibrato/tremolo position reset unless wave bit 2 resp. 6 is set; then the sample is triggered.
- Sample with `n_start = 0` or `n_length <= 2` (words): Paula plays a 16-word zero loop, the mixer marks the voice
  silent.
- Instrument without note: volume and the stored start/loop change, no retrigger. Paula path: the loop registers
  are written only once after a trigger (`sys/init.asm:pt_RpAudIntStartLoop`), so the old sample keeps looping.
  Mixer: loop start/length are taken every tick (`pt_MixUpdateVoice` `.loop`) and become active at the next loop
  wrap (sample swap). **Paula path and mixer differ here.**

### 5.3 Standard effects

Identical routine to 2.3D unless noted (`engine/replayer.asm`). Tick 0 = `pt_RpCheckMoreEfx`/`...Efx2`,
ticks >= 1 = `pt_RpCheckEfx`. On ticks >= 1 a cell without effect (`n_cmd & $FFF = 0`) leaves the period alone.

| Effect | 4.1 detail |
|---|---|
| 0xy | counter mod 3, period search in the finetune row (as 2.3D) |
| 1xx/2xx | limits 113 / 856 (`engine/efx8.asm:pt_PortaMin41`, `pt_PortaMax41`); with setup NOTES EXT and in every wide module (`pt_NoteExt41`) 57 / 1712. The setting is not stored in the module |
| 3xx | glissando E3x as 2.3D; finetune < 0 -> target index - 1 (2.3D); with NOTES EXT a note outside 113..856 is its own target (`pt_TpTarget41`) |
| 4xy, 6xy | vibrato depth `>> 7`, sine table 32 bytes `dat_RpVibratoTable` |
| 7xy | depth `>> 6`; ramp-down tests the *vibrato* position (2.3D bug kept); writes the volume itself `(v·master+32)>>6` and returns past the tick's volume write, so `87y` tremor does not gate it |
| 8x0 | background colour (COLOR00), no audio effect; x = 1..F, 0 = nothing |
| 8xy, y > 0 | 4.1 sub-effects, 5.4 |
| 9xx | `xx = 0` reuses the last offset. Offset `o = xx·128` words; `o >= n_length` -> `n_length = 1` (Paula path signed `BGE` as in 2.3D, so `9xx` on a sample of 32 768 words or more
cuts the note; mixer and card unsigned, `pt_OfsCmp41`); else `n_length = sample length - o`, `n_start = sample start + 2·o`. For a looped sample `n_length` is repeat + replen at that point, so an offset behind the loop end cuts the note. **Absolute, not cumulative** (2.3D adds to the current start/length); without a note `9xx` changes `n_start`/`n_length` with no trigger |
| Axy | x has priority (x != 0 -> up), clamp 0..64 |
| Bxx | as 2.3D |
| Cxx | > 64 -> 64 |
| Dxx | row = x·10 + y; > 63 -> row 0. In 8ch mode the row is stored ·2, limit `$7E` (same result) |
| E0x | LED filter (CIA-A PRA bit 1) |
| E1x/E2x, EAx/EBx | tick 0 only |
| E3x, E4x, E5x, E7x | as 2.3D |
| E6x | as 2.3D (loop row per channel) |
| E8x | no operation |
| E9x | x = 0 no-op; retrigger when `counter mod x = 0`, on tick 0 only if the cell has no period |
| ECx | volume 0 when counter = x |
| EDx | note starts when counter = x (only if the cell has a period) |
| EEx | as 2.3D; during repeats tick 0 runs the per-tick effects (5.4 rule applies) |
| EFx | funk repeat with the 2.3D table `0,5,6,7,8,10,11,13,16,19,22,26,32,43,64,128` (4.0 Beta 2 read a wrong table; fixed, `ui/info.asm:dat_RpFunkTable`). Inverts sample bytes in memory inside the loop (`NOT b`); the update runs on every tick >= 1 before the effects (`pt_RpCheckEfx`) and once when EFx is set on tick 0 (`pt_RpFunkIt`), as 2.3D |
| Fxx | 5.1 |

### 5.4 8xy sub-effects (4.1)

`engine/efx8.asm`. 8xy with y = 0 is the colour effect (5.3). For y > 0:

**Tick rule.** `pt_Efx8Set` is called only from the per-tick dispatcher, i.e. on ticks with counter >= 1 and on
the tick-0 call of pattern-delay repeats; never on tick 0 of a normal row. At speed 1 a sub-effect never starts.
While the cell is present it is executed again on every such tick. `y = F` means "off" (value 0).

State per channel (4 bytes `efx8_State`, index `n_pt4_chanbit & 7`): slide, tremor y, tremor counter, retrigger
interval; plus `efx8_Blend[4]` per channel pair. Cleared when playback starts or the play mode changes
(`engine/mixer.asm:pt_MixMusicEntry` -> `pt_Efx8Reset`). **Not** cleared by new notes, `Cxx`, pattern or song
position changes.

Per tick with counter >= 1 (and pattern-delay tick 0), for every channel that is not switched off, in this order
(`pt_RpCheckEfxChanOn`, `pt_RpCheckEfx`):
1. funk update (EFx);
2. `pt_Efx8Tick`: (a) slide != 0: `n_volume = clamp(n_volume + slide, 0, 64)`;
   (b) retrigger interval r != 0 and `counter mod r = 0`: `n_volume = max(n_volume - 4, 0)`, then the sample is
   retriggered (`pt_RpDoRetrig`: restart at `n_start`/`n_length`, i.e. after `9xx` from the offset);
   (c) tremor y != 0: `tcnt = tcnt + 1`; if `tcnt >= 2y` then `tcnt = 0`;
3. the cell's normal effect (0..F; `8xy` with y > 0 runs `pt_Efx8Set`, see below);
4. volume write `(n_volume·volscale+32)>>6`, then tremor gate: if tremor y != 0 and `tcnt >= y` and the sample has
   no envelope -> output volume 0 (`n_volume` unchanged). Skipped when the cell's effect was `7xy` (5.3).

`pt_Efx8Set` (x = sub-effect, y = 1..F):

| Cell | Action | Paula 4ch | Mixer |
|---|---|---|---|
| `81y` | y = 1..E: voice plays backwards, `81F`: forwards | no effect | yes, 7.3 |
| `82y` | slide = +y (`82F`: slide = 0) | yes | yes |
| `83y` | slide = -y (`83F`: slide = 0); `82y`/`83y` share one slot, the last one wins | yes | yes |
| `84y` | blend of the pair (n, n+4), n = channel & 3: `efx8_Blend[n] = y` (`84F`: off) | no effect | yes, 7.2 |
| `85y` | nothing | | |
| `86y` | retrigger interval = y (`86F`: off) | yes | yes |
| `87y` | if y differs from the stored value: tremor y = y, `tcnt = 0` (`87F`: off) | yes | yes |
| `88y`..`8Fy` | nothing | | |

Consequences an implementer must reproduce:
- `82y`/`83y` act **before** `Axy` of the same tick; both apply. On tick 0 neither acts, so a new note or `Cxx`
  sets the volume on tick 0 and the slide continues from tick 1.
- Max slide per tick is 14 (`82E`); with `822` at speed 6 the volume rises by 10 per row.
- `86y`: counter 0 never retriggers (except pattern-delay tick 0, where `0 mod r = 0`). With `r >= speed` no
  retrigger happens. Each retrigger lowers the volume by 4 first.
- `87y`: tick 0 of a normal row writes the volume without the gate, so the channel is audible on every tick 0;
  the tremor counter only counts ticks >= 1, cycle `2y` ticks, starting "on" on the tick where `87y` was set.
- The state index is `n_pt4_chanbit & 7`: channels 1-8 have one slot each. In wide modules `8xx` is panning of the
  originating tracker: `pt_Efx8Set` and `pt_Efx8Tick` do nothing there (no colour flash, no sub-effect), so the
  shared state of channels 1, 5, 9, ... stays unused.
- Saving a module with any `8xy`, y != 0 shows "8XY EFFECTS: PT 4.1 ONLY"; other players treat `8xx` as panning.
  Modules with `81y`..`84y`, `86y`, `87y` (y != 0) get footer bit 0 (2.1).

### 5.5 Channel mute

A channel switched off (`n_pt4_chanoff`) is skipped completely: cells are not read, no effects, output untouched
(`pt_RpPlayVoice`, `pt_RpCheckEfxChan`). Mute via `dat_RpDmaChanMask` sets the volume scale of the channel to 0
(`pt_MixLoopInit`).

---

## 6 Which path plays what

| Situation | Path | Source |
|---|---|---|
| 4 channel module, Paula output | Paula direct, no mixing | `engine/mixer.asm:pt_MixWanted` |
| 8 channel module (incl. 1..7CHN, FLT8, OCTA, CD81), 68020+ | all 8 voices through the 020 mixer, pair n / n+4 on Paula channel n | `pt_MixStart` (`mix_PairMask = $0F`) |
| 8 channel module, fast 68000 | voices 1/2 direct (volume ~1/3), 3..8 mixed into Paula 2 (3+6+7) and 3 (4+5+8) | `engine/mix68k.asm` |
| 8 channel module, 7 MHz 68000 without fast RAM | tracks 1-4 only | help chapter 5 |
| any module, AHI output | 020 mixer for all pairs, then 7.4 | `pt_MixWanted` |
| any module, AmiGUS output | mixer voice logic, the card resamples | `sys/amigus41.asm:pt_AgusRun` |
| wide module 9..32 | AmiGUS only (PT refuses without card and RTG) | `io/wide41.asm:pt_WideCheck` |

Recommended reference for a library: Paula model for 4 channels (7.1) and the 020 mixer for everything else (7.2),
because the 020 mixer is deterministic and can be compared byte for byte (section 8).

---

## 7 Output

### 7.1 Paula direct (4 channels)

- Period -> rate: `3 546 895 / period` Hz (PAL clock `PAULA_CLOCK`), 8-bit samples, volume 0..64 linear.
- Volume per tick: `(n_volume · volscale + 32) >> 6`, volscale = master volume (`dat_RpMasterVol`, 64 = unity),
  then the setup VOLUME `(v · pv + 32) >> 6`, pv from `64,58,51,45,38,32,26,19,13,6,0`
  (`sys/sndout41.asm:pt_SndHwVolX`, `ui/setup41.asm:pt_SndPaulaVol`).
- Trigger: DMA off, `AUDxLC = n_start`, `AUDxLEN = n_length`; the first audio interrupt sets volume, DMA on and the
  period, the second sets `AUDxLC = n_loopstart`, `AUDxLEN = n_replen` (`pt_RpStartDma`, `pt_RpAudIntStart*`).
  For a player: play `n_length` words from `n_start`, then loop `n_replen` words from `n_loopstart` (replen 1 =
  the zeroed first word, i.e. silence).
- Panning: Paula channels 0 and 3 left, 1 and 2 right (hard).
- Periods below the DMA limit and the analogue filters are hardware behaviour, not reproducible bit-exactly.

### 7.2 020 mixer (8 channels, AHI)

`engine/mixer.asm`. Per tick, after the replayer tick:

1. Rate: setup choice `AUTO` (22 050, or 28 604 when the CPU bench >= 8000), 14 000, 22 050, 28 604 Hz.
   `mix_Period = round(3546895/rate)`, actual `mix_Rate = round(3546895/mix_Period)`: 14 000 -> 14 019,
   22 050 -> 22 030, 28 604 -> 28 604 (`pt_MixSetRate`). AHI may move it into the mode's range (`pt_SndAhiFit41`).
2. Samples this tick: `frac16 += spt` (5.1), n = integer part, max 2560 (`MIX_TICKMAX`).
3. Per voice (`pt_MixUpdateVoice`, voices 1..8, "shadow" = the voice's virtual Paula registers):
   - trigger when the replayer started DMA (`n_pt4_dmawait`) or the shadow period is 1: `pos = n_start`,
     `frac = 0`, `end = n_start + 2·n_length`, direction forward; silent if `n_start = 0` or `n_length <= 2`;
   - every tick: `loopstart = n_loopstart`, `looplen = 2·n_replen` if `n_replen > 1`, else 0 (no loop);
   - volume = shadow volume (as 7.1 without setup VOLUME; envelope samples: `irqvol`; channel off: 0), max 64;
   - `84y` blend y != 0 for this pair: voice n (1..4) `vol·(15-y)/15`, voice n+4 `vol·y/15` (integer division);
   - period = shadow period if >= 2 (vibrato/arpeggio write there), else `n_period`; unchanged if both < 2;
     `step = ((3546895 / max(period,55)) << 16) / mix_Rate`, both divisions truncating (`MIX_MINPER = 55`).
4. Per pair p = 0..3 (voices p+1 and p+5), n output samples (`pt_MixPair`):
   `out = T[volA][sA] + T[volB][sB]` as signed 8 bit, `T[v][s] = (s·v) >> 7` (arithmetic shift, `X20_VOLTAB`).
   No interpolation: `s` = byte at the integer part of the position; then `pos += step` (16.16).
   Forward wrap (`pt_MixVoiceWrap`): when `pos >= end`: `looplen = 0` -> voice off; else
   `over = pos - end`, `over >= looplen` -> 0, `pos = loopstart + over`, `end = loopstart + looplen`.
5. Pair p goes to Paula channel p at full volume (setup VOLUME) with period `mix_Period` (ring buffer, 2 ticks
   lead): left = pairs 0 + 3 (voices 1, 4, 5, 8), right = pairs 1 + 2 (voices 2, 3, 6, 7).

### 7.3 Backwards (`81y`, mixer only)

`engine/efx8.asm:pt_Efx8Backwards`, `pt_MixVoiceAvail`, `pt_MixVoiceWindow`, `pt_MixVoiceWrap`.
- Only if the voice is active; sets `back`. A new trigger always clears it (a note in the same row plays forward
  on tick 0 and turns backwards on tick 1).
- Backwards: `s` = byte at the integer position, then `pos -= step`. Phase start is `loopstart` (taken from
  `n_loopstart` every tick; for an unlooped sample this is the sample start).
- When `pos < loopstart`: `looplen = 0` -> voice off; else `under = loopstart - pos`, `under >= looplen` -> 0,
  `end = loopstart + looplen`, `pos = end - under - 1` (integer part; fraction kept). The voice continues backwards
  inside the loop. If the voice is still before the loop when it turns, the first wrap jumps into the loop.
- `81F` sets forward again from the current position.

### 7.4 AHI

`sys/ahi.asm:pt_AhiSoundFunc`: from the four pair streams r0..r3 (int8):
`L = r0 + r3`, `R = r1 + r2`; stereo width s = 0 (100 %) .. 4 (0 %) in quarter steps: `d = L - R`,
`L -= (d·s) >> 3`, `R += (d·s) >> 3` (arithmetic); output `L << 7`, `R << 7` as 16 bit; setup VOLUME as AHI volume.
First start uses STEREO 50 % (s = 2).

### 7.5 AmiGUS and wide modules

Voice state as 7.2 (`pt_MixUpdateVoice`), the card plays each voice itself at
`step = 3546895·2^30 / 192000 / period` (`AGUS_RATEA/B`). Volume 0..64 -> 16 bit with 64 = `$4000`, setup VOLUME in
tenths, panning: channel k (0-based) left if `k & 3` is 0 or 3, else right; stereo width as 7.4
(`pt_AgusVol`). The card does not use `MIX_MINPER`; its rate register is capped at `$3fffffff` (one sample per
192 kHz clock, periods below about 19 play at that rate, `pt_AgusRate`); a voice whose period is below 5 at its
start stays off (`pt_AgusStart`), a running voice keeps its rate. The card's interpolation is unknown, so AmiGUS output is not bit-reproducible.
In wide modules `8xx` is ignored (5.4). The card holds all 63 samples (slot = number - 1, 512 KB each: sample and a copy of the loop behind it, the sample backwards at +256 KB); samples 32..63 come from the `PT4X` table. A loop that starts after 0 is played inside the sample (LOOP = start + loop start), a loop from 0 that ends before the sample end through the copy. A sample upload that loses data (FIFO full) is tried 3 times in all, then the sample stays silent and a message is shown.

### 7.6 68000 mixer (reference only)

`engine/mix68k.asm`: voices 1/2 direct at volume `master·21 >> 6`, voices 3,6,7 mixed into Paula 2 (right) and
4,5,8 into Paula 3 (left) with a third-volume table; rate AUTO by CPU speed (6.9/11/14/22 kHz) or the setup choice (8.3/11/22 kHz), A500 mode 5 kHz.
Hardware-dependent; a library does not need it.

---

## 8 Comparing with PT 4.1

libpt4 was checked against recordings of PT 4.1 itself: the output of the software mixer (one signed 8-bit stream
per Paula pair, from play start) and the period and volume of every tick on the Paula path; modules with 9 to 32
channels against the register writes to the AmiGUS. Two things to know when you compare your own player with
such a recording:

- The mixer goes on mixing for about two ticks after the `F00` tick.
- `mix_WriteFrac` (16-bit fraction of samples per tick) is not reset at play start, so the first ticks can be one
  sample longer or shorter than a rendering that starts with fraction 0.

## 9 Test modules

`libpt4/testdata/` holds small generated modules, one feature each: `fx81y`..`fx87y.mod` (8CHN, one sub-effect
each), `pt4x_40.mod` / `pt4x_8ch.mod` (PT4X in 4 and 8 channel modules), `dyn_loop.mod` (DYN with `loopseg` 1 and
9xx on the envelope sample), `mkk_70pat.mod`, `1chn.mod`, `9chn.mod`, `32ch.mod`, `flt8.mod`, `15smp.mod`,
`trunc.mod`, `footer_8xy.mod` (footer 2.1), `tempo8.mod` (tempo changes, 8CHN), `pan8xx_plain.mod` (8xx panning
without footer), `plain_mk.mod`, `loop64k8.mod` (8CHN, 72 000-byte sample with loop start 66 000 and `9xx` on it:
mixer long/unsigned against Paula word/signed).

Not yet compared with a PT 4.1 recording: 15-sample modules, `OCTA`, `TDZx`, `CD61`, `2/3/5/7CHN`, `86y` on
pattern-delay ticks.

## 10 Open points from the code

1. Cell periods 1..112 give `n_period = 0` (5.2) - intended or not? Wide modules and NOTES EXT use the cell period instead.
2. Envelope samples sound different in Paula 4ch / AmiGUS and in the software mixers (4.3).
3. Instrument without note: no sample swap on Paula, swap at loop end in the mixer (5.2).
4. Mixer applies a new tempo one tick earlier than the CIA latch (5.1).
5. 6CHN/8CHN modules from other trackers still run `8xx` as 8xy sub-effect (5.4).
6. DYN length 0 keeps bit 7 (4.1); the meaning of `loopseg` is only given by `pt_BuildChunkList`.
7. Answered: `PT4X` headers are clamped (1.2), the 15-sample branch is reached by requester answers 1 and 3 (1.5).
8. Live play start clears only the high word of the counter (`CLR.W dat_RpCounter`, `ui/mainui.asm`); the stated
   start behaviour (row 0 on the `speed`-th tick) is the measured one with counter 0.
9. (From reading the code, not reproduced.) 81y backwards in the 020 mixer: when a segment ends because
   the voice reaches the start of a 32 KB address window (`pt_MixVoiceAvail` `.back`), the position after the
   segment is usually below the window base; `pt_MixVoiceStore` takes `CLR.W`/`SWAP` of a negative offset as
   0..65535 and also uses `pos & ~$7fff` instead of `(pos-1) & ~$7fff` as the base. A backwards voice that crosses
   a 32 KB boundary of its sample address continues at a wrong address. Depends on where the sample lies in memory.
   Second reading (14.11.2026): `pt_MixVoiceAvail` `.back` and `pt_MixVoiceWindow` already use the `(pos-1)` base;
   only `pt_MixVoiceStore` takes `old_pos & $ffff8000`, wrong only when the old position is a multiple of 32 768.
10. DYN `loopseg = nseg` makes `pt_BuildChunkList` write a loop entry that points to itself
    (`pt_RpAudInt` loops forever in the interrupt); `loopseg > nseg` points into the uninitialised list start.
    The loader accepts both.
11. `pt_RpStartChunked` with `n_sampleoffset != 0` (any 9xx earlier on the channel, it is never
    cleared) cuts the chunk list at `n_length`; if the chunks before the loop entry are shorter than `n_length`, the
    cut loop walks onto the loop entry and past the terminator.
12. The software mixer's trigger test `aud_PER = 1` also fires when an effect writes period 1 (e.g.
    vibrato on a very low period): the voice restarts.

## 11 libpt4

`libpt4/` is a C99 port of the replayer and the 020 mixer that follows this document. Against PT 4.1 (last checked
with PT 4.1.2): the mixer output is byte for byte the same over the whole song or up to `F00`, the tick traces are
the same, and on the Paula path the pitch `3546895/period` is within 0.01 % at 44.1/48/96 kHz with a row length of
`floor(1773447/bpm)/709379` s. Where the library deliberately differs: README of `libpt4`.
