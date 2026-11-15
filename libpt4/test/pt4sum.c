/* pt4sum MODULE [SECONDS] [RATE]: render s16 stereo and print a checksum (Adler-32 of the little endian
   samples) and the frame count. Same output on the host and on the Amiga = same library result.
   zlib license, see ../LICENSE. */
#include <stdio.h>
#include <stdlib.h>
#include "../include/pt4.h"

#ifdef __VBCC__
size_t __stack = 16384;   /* vbcc startup: at least this much stack on AmigaOS */
#endif

int main(int argc, char **argv)
{
    FILE *f;
    long len, secs = argc > 2 ? atol(argv[2]) : 5;
    unsigned rate = argc > 3 ? (unsigned)atol(argv[3]) : 22050;
    unsigned char *buf;
    pt4_song *s;
    static int16_t out[2 * 256];
    unsigned long a = 1, b = 0, frames = 0, want;
    int err;
    if (argc < 2) { printf("usage: pt4sum MODULE [SECONDS] [RATE]\n"); return 5; }
    f = fopen(argv[1], "rb");
    if (!f) { printf("cannot open %s\n", argv[1]); return 10; }
    fseek(f, 0, SEEK_END);
    len = ftell(f);
    fseek(f, 0, SEEK_SET);
    buf = (unsigned char *)malloc((size_t)len);
    if (!buf || fread(buf, 1, (size_t)len, f) != (size_t)len) { printf("read error\n"); return 10; }
    fclose(f);
    s = pt4_open(buf, (size_t)len, NULL, &err);
    if (!s) { printf("open error %d\n", err); return 10; }
    want = (unsigned long)secs * rate;
    while (frames < want) {
        size_t n = want - frames > 256 ? 256 : (size_t)(want - frames), i;
        size_t got = pt4_render_s16(s, out, n, rate);
        for (i = 0; i < 2 * got; i++) {
            unsigned v = (unsigned)(uint16_t)out[i];
            a = (a + (v & 255)) % 65521UL;
            b = (b + a) % 65521UL;
            a = (a + (v >> 8)) % 65521UL;
            b = (b + a) % 65521UL;
        }
        frames += (unsigned long)got;
        if (got < n) break;
    }
    printf("%s: %lu frames, adler32 %08lx, length %ld ms, detect %d\n", argv[1], frames, (b << 16) | a,
           pt4_length_ms(s), pt4_detect(buf, (size_t)len));
    pt4_close(s);
    free(buf);
    return 0;
}
