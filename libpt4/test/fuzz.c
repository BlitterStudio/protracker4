/* libpt4 fuzz smoke: random cuts and byte damage of the test modules, open + detect + render.
   Build with -fsanitize=address,undefined (make fuzz). pt4fuzz TESTDATA_DIR [CASES]
   zlib license, see ../LICENSE. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../include/pt4.h"

static const char *const names[] = {
    "plain_mk.mod", "pan8xx_plain.mod", "pt4x_40.mod", "fx81y.mod", "fx84y.mod", "fx86y.mod", "fx87y.mod",
    "dyn_loop.mod", "mkk_70pat.mod", "1chn.mod", "9chn.mod", "32ch.mod", "flt8.mod", "15smp.mod", "trunc.mod",
    "footer_8xy.mod", "loop64k8.mod"
};
#define NF (sizeof(names) / sizeof(names[0]))

static unsigned long rng = 12345;
static unsigned rnd(void) { rng = rng * 1103515245UL + 12345UL; return (unsigned)((rng >> 16) & 0x7fff); }

int main(int argc, char **argv)
{
    unsigned char *data[NF];
    size_t len[NF], i;
    long cases = argc > 2 ? atol(argv[2]) : 100000, c, opened = 0;
    static int16_t out[2 * 2048];
    for (i = 0; i < NF; i++) {
        char p[1024];
        FILE *f;
        sprintf(p, "%.900s/%s", argc > 1 ? argv[1] : "testdata", names[i]);
        f = fopen(p, "rb");
        if (!f) { printf("missing %s\n", p); return 1; }
        fseek(f, 0, SEEK_END);
        len[i] = (size_t)ftell(f);
        fseek(f, 0, SEEK_SET);
        data[i] = (unsigned char *)malloc(len[i]);
        if (fread(data[i], 1, len[i], f) != len[i]) return 1;
        fclose(f);
    }
    for (c = 0; c < cases; c++) {
        size_t k = rnd() % NF, n = len[k], j, damage;
        unsigned char *b;
        pt4_song *s;
        int mode = (int)(rnd() % 4);
        if (mode == 0) n = (size_t)(rnd() * 37u) % (len[k] + 1);      /* cut */
        b = (unsigned char *)malloc(n ? n : 1);
        memcpy(b, data[k], n);
        damage = mode == 0 ? 0 : 1 + rnd() % (mode == 3 ? 200 : 8);
        for (j = 0; j < damage && n; j++) {
            size_t at = mode == 2 ? (size_t)(rnd() % 1200) % n : ((size_t)rnd() * 7919u) % n;
            b[at] = (unsigned char)rnd();
        }
        (void)pt4_detect(b, n);
        s = pt4_open(b, n, NULL, NULL);
        if (s) {
            int r;
            opened++;
            pt4_set_option(s, PT4_OPT_PATH, (int)(rnd() % 4));
            pt4_set_option(s, PT4_OPT_INTERP, (int)(rnd() & 1));
            pt4_set_option(s, PT4_OPT_DYN_MIXER, (int)(rnd() & 1));
            for (r = 0; r < 3; r++) pt4_render_s16(s, out, 2048, 8000 + (rnd() % 185) * 1000);
            pt4_seek_ms(s, (long)(rnd() % 5000));
            pt4_render_s16(s, out, 512, 44100);
            pt4_close(s);
        }
        free(b);
        if ((c + 1) % 10000 == 0) { printf("%ld cases, %ld opened\n", c + 1, opened); fflush(stdout); }
    }
    printf("done: %ld cases, %ld opened, no crash\n", cases, opened);
    for (i = 0; i < NF; i++) free(data[i]);
    return 0;
}
