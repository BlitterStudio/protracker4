# libpt4

Portable C99 replayer for ProTracker 4.1 modules. ProTracker 4.1 by Tom Beyer, Oliver Ickler, Haavard Pedersen and
Akustikrausch (Andreas Wendorf); based on ProTracker by Lars Hamre / Amiga Freelancers and ProTracker 3.15 by
CryptoBurners. zlib license (`LICENSE`).

The library plays modules the way ProTracker 4.1 plays them. It is a port of the 68000 replayer (`pt_Rp*`), the
8xy sub-effects, the PT4X sample table, the DYN envelopes and the 020 software mixer, not a generic MOD player.
Format and playback rules: `docs/PT41_FORMAT.md` in the ProTracker 4.1 repository.

## Formats

All ids the PT 4.1 loader takes: `M.K.`, `M!K!`, `!PM!`, `FLT4`, `EXO4`, `4CHN`, `TDZ1`..`TDZ4`, `CD61`,
`1CHN`..`7CHN`, `8CHN`, `OCTA`, `CD81`, `FLT8`, `9CHN`, `09CH`..`32CH`, and 15-sample modules (unknown id, sane
header). 4.1 extensions: samples 32..63 (`PT4X` block), DYN volume envelopes, 8xy sub-effects 81y..87y, the
`PT41` footer of PT 4.1.2 (detected and stripped). Truncated files load; missing data is silence.

`pt4_detect` classifies a buffer without allocating: `PT4_EXT` (footer, valid `PT4X` block or valid DYN
envelope), `PT4_PLAIN_MOD` (anything else PT loads, including 8xy modules without footer: other players read
8xx as panning there), `PT4_NONE`. `pt4_open` always plays 8xy as PT 4.1 does.

## Output paths

| Path | Used for (AUTO) | Semantics |
|---|---|---|
| PAULA | 4 channel modules | Paula: loop latched at the trigger, DYN chunk lists, hard LRRL panning |
| MIXER | 5..8 channels | PT 4.1 020 mixer: voices n/n+4 summed per Paula channel as int8, byte exact to PT |
| WIDE | 9..32 channels | AmiGUS: mixer voice logic, every voice on its own, AmiGUS panning, DYN applied, no rate below period 5 |

Stereo PCM (int16 or float) at any rate 8 000..192 000 Hz without a resampler: the voice step is computed for the
output rate (`((3546895 / period) << 16) / rate`) as the PT mixer does it for its own rate. `PT4_OPT_STEREO`
narrows the image in quarters like PT's AHI output. Options: see `include/pt4.h`.

## Use

```c
#include "pt4.h"
int err;
pt4_song *s = pt4_open(data, size, NULL, &err);   /* NULL allocator = malloc/free */
float buf[2 * 1024];
while (pt4_render_f32(s, buf, 1024, 48000) > 0) { /* ... */ }
pt4_close(s);
```

No global mutable state, no stdio, no file access; several songs may play at once (one song per thread at a
time). Memory only through the allocator hook. The integer core needs no floating point (`src/float.c` is the only
float code, for `pt4_render_f32`).

## Build

- gcc/clang: `make` (library, `pt4play`, `pt4test`, `pt4sum`), `make test`, `make fuzz` (ASan/UBSan),
  `sh test/portcheck.sh`.
- CMake/MSVC: `cmake -S . -B build && cmake --build build`, or `add_subdirectory()` -> target `pt4`.
  Sources: `src/load.c src/replay.c src/voice.c src/api.c src/tables.c src/float.c`.
- AmigaOS 68000 (vbcc, `VBCC=/opt/vbcc`): `make -f Makefile.amiga` -> `build/amiga/pt4.lib`, `pt4sum`.
  `pt4_open` keeps about 3 KB on the stack; give programs 16 KB (`pt4sum` sets `__stack`).
  `pt4sum MODULE` prints frames and an Adler-32 of the output: the same line as on the host.

## pt4play

`pt4play MODULE -o out.wav [--rate HZ] [--float] [--path auto|paula|mixer|wide] [--seconds S] [--loops N]
[--mute 1,5] [--stereo 0..4] [--interp] [--dyn-mixer] [--notes-ext] [--row0] [--tempo BPM] [--pairs out.raw] [--info]`

`--pairs` writes the four int8 pair streams of the mixer path one after the other, the layout of PT's
`PT:mixdump.raw`.

## Verification

In the ProTracker 4.1 development tree (not part of the public source):
- `tools/pt4_ref.py list` compares with PT 4.1 references in `test/results/pt41ref/` (mix dumps of the debug
  build, byte for byte, and tick traces; wide modules against the register log of an emulated AmiGUS via
  `pt4test vtrace`, `tools/pt4_agus_cmp.py`).
- `tools/pt4_trace_cmp.py`, `tools/pt41_pitch_check.py`, `tools/pt4_openmpt_cmp.py`, unit tests in
  `test/pt4test.c`, test modules from `tools/mk_pt41_testdata.py` in `testdata/`.

## Differences from PT 4.1 by design

- Paula path: no analogue filters, no DMA period limits; E0x (LED filter) is ignored; 8x0 colour is ignored.
- Mute (`pt4_mute`) silences the output of a channel; the replayer keeps running (PT's track switch stops notes).
- Song end: F00 or an order played a second time (PT loops forever; `pt4_set_loop(s, 1)` does that too).
- PT keeps the samples-per-tick fraction from before play start; the library starts at 0. Sample counts per tick
  can therefore differ by one from a PT recording (the reference test searches the start fraction).
- 81y backwards on PT crosses 32 KB address windows with a wrong position (see `docs/PT41_FORMAT.md` 10); the
  library implements the documented semantics.
- DYN `loopseg >= nseg` (PT: endless loop or garbage) is treated as no loop.
