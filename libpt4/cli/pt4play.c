/* pt4play: render a ProTracker 4.1 module to WAV with libpt4. zlib license, see ../LICENSE. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../include/pt4.h"

static void usage(void)
{
    fprintf(stderr,
        "usage: pt4play MODULE [-o OUT.wav] [--rate HZ] [--float] [--path auto|paula|mixer|wide]\n"
        "                [--seconds S] [--loops N] [--mute C,C,..] [--stereo 0..4] [--interp]\n"
        "                [--dyn-mixer] [--notes-ext] [--row0] [--tempo BPM] [--pairs OUT.raw] [--info]\n"
        "  --pairs writes the four int8 pair streams of the mixer path one after the other\n"
        "  (as PT:mixdump.raw) instead of a WAV; with --seconds the stream length is fixed.\n");
}

static void put16(FILE *f, unsigned v) { fputc((int)(v & 255), f); fputc((int)((v >> 8) & 255), f); }
static void put32(FILE *f, unsigned long v) { put16(f, (unsigned)(v & 0xffff)); put16(f, (unsigned)((v >> 16) & 0xffff)); }

static void wav_header(FILE *f, unsigned rate, int fl, unsigned long frames)
{
    unsigned long bytes = frames * 2u * (fl ? 4u : 2u);
    fwrite("RIFF", 1, 4, f);
    put32(f, 36 + bytes);
    fwrite("WAVEfmt ", 1, 8, f);
    put32(f, 16);
    put16(f, fl ? 3 : 1);
    put16(f, 2);
    put32(f, rate);
    put32(f, (unsigned long)rate * 2u * (fl ? 4u : 2u));
    put16(f, fl ? 8 : 4);
    put16(f, fl ? 32 : 16);
    fwrite("data", 1, 4, f);
    put32(f, bytes);
}

int main(int argc, char **argv)
{
    const char *in = NULL, *out = "out.wav", *pairs_out = NULL;
    unsigned rate = 44100;
    int fl = 0, loops = 0, info = 0, i, err;
    double seconds = 0;
    FILE *f;
    long len;
    unsigned char *buf;
    pt4_song *s;
    int opts[16][2], nopt = 0;
    char *mute = NULL;

    for (i = 1; i < argc; i++) {
        const char *a = argv[i];
        if (!strcmp(a, "-o") && i + 1 < argc) out = argv[++i];
        else if (!strcmp(a, "--rate") && i + 1 < argc) rate = (unsigned)atoi(argv[++i]);
        else if (!strcmp(a, "--float")) fl = 1;
        else if (!strcmp(a, "--seconds") && i + 1 < argc) seconds = atof(argv[++i]);
        else if (!strcmp(a, "--loops") && i + 1 < argc) loops = atoi(argv[++i]);
        else if (!strcmp(a, "--mute") && i + 1 < argc) mute = argv[++i];
        else if (!strcmp(a, "--pairs") && i + 1 < argc) pairs_out = argv[++i];
        else if (!strcmp(a, "--info")) info = 1;
        else if (!strcmp(a, "--path") && i + 1 < argc) {
            const char *p = argv[++i];
            int v = !strcmp(p, "paula") ? PT4_PATH_PAULA : !strcmp(p, "mixer") ? PT4_PATH_MIXER
                  : !strcmp(p, "wide") ? PT4_PATH_WIDE : PT4_PATH_AUTO;
            opts[nopt][0] = PT4_OPT_PATH; opts[nopt++][1] = v;
        }
        else if (!strcmp(a, "--stereo") && i + 1 < argc) { opts[nopt][0] = PT4_OPT_STEREO; opts[nopt++][1] = atoi(argv[++i]); }
        else if (!strcmp(a, "--tempo") && i + 1 < argc) { opts[nopt][0] = PT4_OPT_TEMPO; opts[nopt++][1] = atoi(argv[++i]); }
        else if (!strcmp(a, "--frac0") && i + 1 < argc) { opts[nopt][0] = 100; opts[nopt++][1] = atoi(argv[++i]); }
        else if (!strcmp(a, "--interp")) { opts[nopt][0] = PT4_OPT_INTERP; opts[nopt++][1] = 1; }
        else if (!strcmp(a, "--dyn-mixer")) { opts[nopt][0] = PT4_OPT_DYN_MIXER; opts[nopt++][1] = 1; }
        else if (!strcmp(a, "--notes-ext")) { opts[nopt][0] = PT4_OPT_NOTES_EXT; opts[nopt++][1] = 1; }
        else if (!strcmp(a, "--row0")) { opts[nopt][0] = PT4_OPT_START_ROW0; opts[nopt++][1] = 1; }
        else if (a[0] != '-' && !in) in = a;
        else { usage(); return 2; }
        if (nopt >= 16) nopt = 15;
    }
    if (!in) { usage(); return 2; }
    f = fopen(in, "rb");
    if (!f) { perror(in); return 1; }
    fseek(f, 0, SEEK_END);
    len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0) { fclose(f); fprintf(stderr, "%s: empty\n", in); return 1; }
    buf = (unsigned char *)malloc((size_t)len);
    if (!buf || fread(buf, 1, (size_t)len, f) != (size_t)len) { fclose(f); fprintf(stderr, "%s: read error\n", in); return 1; }
    fclose(f);
    s = pt4_open(buf, (size_t)len, NULL, &err);
    if (!s) { fprintf(stderr, "%s: not loaded (error %d, detect %d)\n", in, err, pt4_detect(buf, (size_t)len)); free(buf); return 1; }
    for (i = 0; i < nopt; i++) pt4_set_option(s, opts[i][0], opts[i][1]);
    if (mute) {
        char *p = mute;
        while (*p) {
            pt4_mute(s, atoi(p) - 1, 1);
            while (*p && *p != ',') p++;
            if (*p) p++;
        }
    }
    if (info) {
        int k;
        printf("detect %d id %s channels %d samples %d orders %d patterns %d length_ms %ld ext 0x%x path %d\n",
               pt4_detect(buf, (size_t)len), pt4_format_id(s), pt4_channels(s), pt4_num_samples(s),
               pt4_num_orders(s), pt4_num_patterns(s), pt4_length_ms(s), pt4_extensions(s),
               pt4_get_option(s, PT4_OPT_PATH));
        printf("title '%s'\n", pt4_title(s));
        for (k = 1; k <= pt4_num_samples(s); k++)
            if (pt4_sample_name(s, k)[0]) printf("%2d '%s'\n", k, pt4_sample_name(s, k));
    }
    free(buf);
    if (loops > 1) pt4_set_loop(s, 1);

    if (pairs_out) {
        unsigned long total = seconds > 0 ? (unsigned long)(seconds * rate) : (unsigned long)rate * 600u, got = 0;
        int8_t *pb[4];
        FILE *o;
        int k;
        for (k = 0; k < 4; k++) {
            pb[k] = (int8_t *)calloc(total ? total : 1, 1);
            if (!pb[k]) { fprintf(stderr, "no memory\n"); return 1; }
        }
        while (got < total) {
            int8_t *p4[4];
            size_t want = total - got > 4096 ? 4096 : total - got, n;
            for (k = 0; k < 4; k++) p4[k] = pb[k] + got;
            n = pt4_render_pairs(s, p4, want, rate);
            got += (unsigned long)n;
            if (n < want) break;
        }
        o = fopen(pairs_out, "wb");
        if (!o) { perror(pairs_out); return 1; }
        for (k = 0; k < 4; k++) fwrite(pb[k], 1, got, o);
        fclose(o);
        for (k = 0; k < 4; k++) free(pb[k]);
        if (info) printf("pairs %lu frames each\n", got);
        pt4_close(s);
        return 0;
    }

    f = fopen(out, "wb");
    if (!f) { perror(out); pt4_close(s); return 1; }
    wav_header(f, rate, fl, 0);
    {
        unsigned long frames = 0, limit = seconds > 0 ? (unsigned long)(seconds * rate) : 0;
        long songlen = pt4_length_ms(s);
        static float fb[2 * 4096];
        static int16_t sb[2 * 4096];
        if (!limit && loops > 1 && songlen > 0) limit = (unsigned long)((double)songlen * loops / 1000.0 * rate);
        if (!limit && songlen < 0) limit = (unsigned long)rate * 600u;
        for (;;) {
            size_t want = 4096, n;
            if (limit && limit - frames < want) want = limit - frames;
            if (want == 0) break;
            if (fl) {
                n = pt4_render_f32(s, fb, want, rate);
                fwrite(fb, sizeof(float), 2 * n, f);   /* little endian hosts */
            } else {
                size_t k;
                n = pt4_render_s16(s, sb, want, rate);
                for (k = 0; k < 2 * n; k++) put16(f, (unsigned)(uint16_t)sb[k]);
            }
            frames += (unsigned long)n;
            if (n < want) break;
        }
        fseek(f, 0, SEEK_SET);
        wav_header(f, rate, fl, frames);
        if (info) printf("wrote %lu frames (%.3f s)\n", frames, (double)frames / rate);
    }
    fclose(f);
    pt4_close(s);
    return 0;
}
