/* libpt4 unit tests and tick trace.
     pt4test TESTDATA_DIR            run the unit tests
     pt4test trace MODULE [TICKS]    per tick: patternpos counter songpos period volume sper svol
                                      (channel as PT's dbg_FxTick: 1, or 5 in 8ch if track 1 row 0 is empty)
     pt4test vtrace MODULE [TICKS]   voice events of the default path: "tick voice S sample offset" (note
                                      start, byte offset in the sample), "tick voice R period" (new rate),
                                      "tick voice V volume" (new volume), "tick voice B" (turns backwards)
   zlib license, see ../LICENSE. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../src/pt4_internal.h"

#ifdef __VBCC__
size_t __stack = 32768;   /* vbcc startup: at least this much stack on AmigaOS */
#endif

static int fails, checks;
#define CHECK(c, ...) do { checks++; if (!(c)) { fails++; printf("FAIL %s:%d: ", __FILE__, __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

static unsigned char *readfile(const char *path, size_t *len)
{
    FILE *f = fopen(path, "rb");
    unsigned char *b;
    long n;
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    n = ftell(f);
    fseek(f, 0, SEEK_SET);
    b = (unsigned char *)malloc((size_t)(n > 0 ? n : 1));
    if (b && n > 0 && fread(b, 1, (size_t)n, f) != (size_t)n) { free(b); b = NULL; }
    fclose(f);
    *len = (size_t)n;
    return b;
}

/* dir/name, dir cut at 900 chars (no %.*s: the reduced printf of vbcc ignores the precision) */
static void join(char *out, const char *dir, const char *name)
{
    size_t n = strlen(dir);
    if (n > 900) n = 900;
    memcpy(out, dir, n);
    out[n] = '/';
    strcpy(out + n + 1, name);
}

static pt4_song *open_file(const char *dir, const char *name, unsigned char **buf, size_t *len)
{
    char path[1024];
    int err;
    pt4_song *s;
    join(path, dir, name);
    *buf = readfile(path, len);
    if (!*buf) { printf("FAIL cannot read %s\n", path); fails++; return NULL; }
    s = pt4_open(*buf, *len, NULL, &err);
    if (!s) { printf("FAIL open %s err %d\n", path, err); fails++; }
    return s;
}

/* run ticks until row r of order 0 was read (tick 0 of that row), return tick count */
static int ticks_to_row(pt4_song *s, int row, int max)
{
    int t;
    for (t = 1; t <= max; t++) {
        pt4__tick(s);
        if (s->st.counter == 0 && s->st.cur_row == row) return t;
    }
    return -1;
}

static int trace(const char *path, int nticks)
{
    size_t len;
    unsigned char *b = readfile(path, &len);
    pt4_song *s;
    int err, t, ch = 0;
    if (!b) { perror(path); return 1; }
    s = pt4_open(b, len, NULL, &err);
    if (!s) { fprintf(stderr, "open error %d\n", err); return 1; }
    pt4_set_option(s, PT4_OPT_PATH, PT4_PATH_PAULA);
    if (s->lay == 8) {
        const uint8_t *c = s->pat;
        if (!(c[0] | c[1] | c[2] | c[3]) && (c[16] | c[17] | c[18] | c[19])) ch = 4;
    }
    for (t = 0; t < nticks && s->st.playing; t++) {
        pt4__tick(s);
        pt4__update_voices(s);
        printf("%u %u %u %u %u %u %u\n", (unsigned)(s->st.patternpos & 0xffff), (unsigned)(s->st.counter & 0xff),
               (unsigned)(s->st.songpos & 0xff), s->st.ch[ch].period, s->st.ch[ch].volume,
               s->st.dbg_per[ch], s->st.dbg_vol[ch]);
    }
    pt4_close(s);
    free(b);
    return 0;
}

static int vtrace(const char *path, int nticks)
{
    size_t len;
    unsigned char *b = readfile(path, &len);
    pt4_song *s;
    int err, t, n;
    uint16_t per[PT4_MAXCH], vol[PT4_MAXCH];
    int back[PT4_MAXCH];
    if (!b) { perror(path); return 1; }
    s = pt4_open(b, len, NULL, &err);
    if (!s) { fprintf(stderr, "open error %d\n", err); return 1; }
    memset(per, 0, sizeof(per));
    memset(vol, 0xff, sizeof(vol));
    memset(back, 0, sizeof(back));
    for (t = 0; t < nticks && s->st.playing; t++) {
        int trig[PT4_MAXCH];
        pt4__tick(s);
        for (n = 0; n < PT4_MAXCH; n++) trig[n] = s->st.ch[n].dmawait || s->st.aud[n].per == 1;
        pt4__update_voices(s);
        for (n = 0; n < PT4_MAXCH; n++) {
            const pt4_voice *v = &s->st.v[n];
            const pt4_chan *c = &s->st.ch[n];
            if (trig[n] && v->active) {
                printf("%d %d S %d %lu\n", t, n, c->samplenum, (unsigned long)(v->pos - s->smp[c->samplenum].addr));
                per[n] = 0;
                vol[n] = 0xffff;
                back[n] = 0;
            }
            if (v->active && v->period != per[n]) {
                printf("%d %d R %u\n", t, n, v->period);
                per[n] = v->period;
            }
            if (v->active && v->vol != vol[n]) {
                printf("%d %d V %u\n", t, n, v->vol);
                vol[n] = v->vol;
            }
            if (v->active && v->back && !back[n]) printf("%d %d B\n", t, n);
            back[n] = v->active && v->back;
        }
    }
    pt4_close(s);
    free(b);
    return 0;
}

static void test_detect(const char *dir)
{
    static const struct { const char *f; int want; } t[] = {
        { "plain_mk.mod", PT4_PLAIN_MOD }, { "pan8xx_plain.mod", PT4_PLAIN_MOD }, { "pt4x_40.mod", PT4_EXT },
        { "fx82y.mod", PT4_PLAIN_MOD }, { "dyn_loop.mod", PT4_EXT }, { "footer_8xy.mod", PT4_EXT },
        { "mkk_70pat.mod", PT4_PLAIN_MOD }, { "1chn.mod", PT4_PLAIN_MOD }, { "9chn.mod", PT4_PLAIN_MOD },
        { "32ch.mod", PT4_PLAIN_MOD }, { "flt8.mod", PT4_PLAIN_MOD }, { "15smp.mod", PT4_PLAIN_MOD },
        { "trunc.mod", PT4_PLAIN_MOD }
    };
    size_t i, len;
    char path[1024];
    static const unsigned char junk[2000] = { 1, 2, 3 };
    for (i = 0; i < sizeof(t) / sizeof(t[0]); i++) {
        unsigned char *b;
        join(path, dir, t[i].f);
        b = readfile(path, &len);
        CHECK(b != NULL, "read %s", t[i].f);
        if (!b) continue;
        CHECK(pt4_detect(b, len) == t[i].want, "detect %s = %d, want %d", t[i].f, pt4_detect(b, len), t[i].want);
        CHECK(pt4_detect(b, 100) == PT4_NONE, "detect %s cut to 100 bytes", t[i].f);
        free(b);
    }
    CHECK(pt4_detect(junk, sizeof(junk)) == PT4_NONE, "junk");
    CHECK(pt4_detect(NULL, 0) == PT4_NONE, "null");
}

static void test_loader(const char *dir)
{
    unsigned char *b;
    size_t len;
    pt4_song *s;
    int note, smp, eff, par;

    s = open_file(dir, "pt4x_40.mod", &b, &len);
    if (s) {
        CHECK(pt4_num_samples(s) == 40, "pt4x samples %d", pt4_num_samples(s));
        CHECK(!strcmp(pt4_sample_name(s, 40), "pt4x entry 40"), "name 40 '%s'", pt4_sample_name(s, 40));
        CHECK(s->smp[40].length == 32 && s->smp[40].volume == 48, "entry 40 header");
        CHECK(s->smp[41].length == 0 && s->smp[41].addr == 0, "entry 41 empty");
        CHECK(pt4_pattern_cell(s, 0, 8, 2, &note, &smp, &eff, &par) == 0 && smp == 40, "cell sample 40: %d", smp);
        CHECK(s->arena[s->smp[32].addr] == 0 && s->arena[s->smp[32].addr + 1] == 0, "first word cleared");
        pt4_close(s);
    }
    free(b);

    s = open_file(dir, "mkk_70pat.mod", &b, &len);
    if (s) {
        CHECK(pt4_num_patterns(s) == 70 && pt4_pattern_at(s, 69) == 69, "M!K! 70 patterns: %d", pt4_num_patterns(s));
        pt4_close(s);
    }
    /* capacity 64 rule: positions >= cap -> 0, samples still found */
    if (b) {
        int ext = 0;
        (void)ext;
        memcpy(b + 1080, "M.K.", 4);   /* M.K. with 70 patterns: still 100 capacity */
        s = pt4_open(b, len, NULL, NULL);
        CHECK(s && pt4_num_patterns(s) == 70, "M.K. 70 patterns");
        if (s) pt4_close(s);
    }
    free(b);

    s = open_file(dir, "flt8.mod", &b, &len);
    if (s) {
        CHECK(pt4_channels(s) == 8 && pt4_num_patterns(s) == 1, "flt8 layout");
        CHECK(pt4_pattern_cell(s, 0, 2, 4, &note, &smp, &eff, &par) == 0 && smp == 2 && note == 8, "flt8 ch5 row2 note %d smp %d", note, smp);
        CHECK(pt4_pattern_cell(s, 0, 2, 0, &note, &smp, &eff, &par) == 0 && smp == 1 && note == 13, "flt8 ch1 row2 note %d", note);
        pt4_close(s);
    }
    free(b);

    s = open_file(dir, "1chn.mod", &b, &len);
    if (s) {
        CHECK(pt4_channels(s) == 1 && s->lay == 8 && pt4_get_option(s, PT4_OPT_PATH) == PT4_PATH_MIXER, "1chn -> 8 track layout");
        CHECK(pt4_pattern_cell(s, 0, 2, 0, &note, &smp, &eff, &par) == 0 && smp == 1, "1chn cell");
        CHECK(pt4_pattern_cell(s, 0, 2, 1, &note, &smp, &eff, &par) == -1, "1chn has one channel");
        CHECK(s->smp[1].length == 32, "1chn samples found");
        pt4_close(s);
    }
    free(b);

    s = open_file(dir, "32ch.mod", &b, &len);
    if (s) {
        CHECK(pt4_channels(s) == 32 && s->wide && pt4_get_option(s, PT4_OPT_PATH) == PT4_PATH_WIDE, "32ch wide");
        CHECK(pt4_pattern_cell(s, 0, 62 % 32, 31, &note, &smp, &eff, &par) == 0 && smp == 2, "32ch ch32 smp %d", smp);
        CHECK(s->smp[2].length == 16, "32ch samples");
        pt4_close(s);
    }
    free(b);

    s = open_file(dir, "15smp.mod", &b, &len);
    if (s) {
        CHECK(!strcmp(pt4_format_id(s), "15smp") && s->smp[1].length == 32 && s->smp[16].replen == 1, "15 samples");
        pt4_close(s);
    }
    free(b);

    s = open_file(dir, "trunc.mod", &b, &len);
    if (s) {
        CHECK(pt4_extensions(s) & PT4_X_TRUNC, "truncated flag");
        CHECK(s->smp[1].length == 2048 && s->arena[s->smp[1].addr + 200] == 0, "truncated: zero padded");
        pt4_close(s);
    }
    free(b);

    s = open_file(dir, "dyn_loop.mod", &b, &len);
    if (s) {
        CHECK(s->smp[3].chunked && s->smp[3].env.nseg == 4 && s->smp[3].env.loopseg == 1, "dyn envelope");
        CHECK(s->smp[3].env.off[3] == 384, "dyn offsets");
        pt4_close(s);
    }
    /* junk length: odd L -> bit 7 dropped, the 4 bytes stay sample data of the next sample */
    if (b) {
        size_t at = len - 4 - 4 - 16;   /* L field */
        unsigned char *c = (unsigned char *)malloc(len);
        memcpy(c, b, len);
        c[at + 3] |= 1;
        s = pt4_open(c, len, NULL, NULL);
        CHECK(s && !s->smp[3].chunked && !(s->smp[3].finetune & 0x80), "junk L");
        if (s) pt4_close(s);
        memcpy(c, b, len);
        c[len - 1] = 65;   /* last segment volume 65 -> invalid */
        s = pt4_open(c, len, NULL, NULL);
        CHECK(s && !s->smp[3].chunked, "dyn vol > 64 invalid");
        if (s) pt4_close(s);
        free(c);
    }
    free(b);

    s = open_file(dir, "footer_8xy.mod", &b, &len);
    if (s) {
        CHECK((pt4_extensions(s) & (PT4_X_FOOTER | PT4_X_8XY)) == (PT4_X_FOOTER | PT4_X_8XY) && !(pt4_extensions(s) & PT4_X_TRUNC), "footer");
        pt4_close(s);
    }
    free(b);

    /* header rules on plain_mk: songlen 0 -> 1, vol > 64, repeat >= length, sample > 63 cleared */
    s = open_file(dir, "plain_mk.mod", &b, &len);
    if (s) pt4_close(s);
    if (b) {
        b[950] = 0;
        b[20 + 25] = 99;                 /* sample 1 volume */
        b[20 + 26] = 0; b[20 + 27] = 40; /* repeat 40 >= length 32 */
        b[1084] |= 0x40;                 /* cell sample 0x41 > 63 */
        s = pt4_open(b, len, NULL, NULL);
        CHECK(s != NULL, "modified plain");
        if (s) {
            CHECK(pt4_num_orders(s) == 1, "songlen 0 -> 1");
            CHECK(s->smp[1].volume == 64 && s->smp[1].repeat == 0 && s->smp[1].replen == 1, "sample rules");
            CHECK(pt4_pattern_cell(s, 0, 0, 0, &note, &smp, &eff, &par) == 0 && smp == 0, "sample > 63 -> 0 (%d)", smp);
            pt4_close(s);
        }
    }
    free(b);
}

static void test_timing(const char *dir)
{
    unsigned char *b;
    size_t len;
    pt4_song *s = open_file(dir, "plain_mk.mod", &b, &len);
    int t;
    if (!s) return;
    pt4_set_option(s, PT4_OPT_PATH, PT4_PATH_PAULA);
    t = ticks_to_row(s, 0, 100);
    CHECK(t == 6, "row 0 on tick %d (want 6 = speed)", t);
    t = ticks_to_row(s, 1, 100);
    CHECK(t == 6, "row 1 after %d ticks", t);
    pt4_set_option(s, PT4_OPT_START_ROW0, 1);
    pt4_seek_ms(s, 0);
    t = ticks_to_row(s, 0, 100);
    CHECK(t == 1, "row0 option: tick %d", t);
    /* CIA tick lengths */
    CHECK(pt4__cia_period(125) == 14187 && pt4__cia_period(32) == 55420 && pt4__cia_period(255) == 6954 && pt4__cia_period(20) == 55420, "cia periods");
    s->rate = 28604;
    pt4__calc_spt(s, 125);
    CHECK(s->st.spt >> 16 == 572, "spt 28604/125 = %u", (unsigned)(s->st.spt >> 16));
    s->rate = 22030;
    pt4__calc_spt(s, 125);
    CHECK(s->st.spt >> 16 == 440, "spt 22030/125");
    CHECK(pt4_length_ms(s) == 2019, "length %ld", pt4_length_ms(s));
    pt4_close(s);
    free(b);
}

/* build a 1-pattern M.K. module in memory with given cells on channel 1 */
static unsigned char *mk_mod(const unsigned char cells[][4], int n, size_t *len)
{
    size_t L = 1084 + 1024 + 64;
    unsigned char *m = (unsigned char *)calloc(L, 1);
    int i;
    memcpy(m, "unit", 4);
    m[20 + 23] = 32; m[20 + 25] = 40; m[20 + 29] = 32;   /* sample 1: 64 bytes, vol 40, loop all */
    for (i = 2; i <= 31; i++) m[20 + 30 * (i - 1) + 29] = 1;
    m[950] = 1;
    memcpy(m + 1080, "M.K.", 4);
    for (i = 0; i < n && i < 64; i++) memcpy(m + 1084 + 16 * i, cells[i], 4);
    for (i = 0; i < 64; i++) m[1084 + 1024 + i] = (unsigned char)(i * 4);
    *len = L;
    return m;
}

static void test_effects(void)
{
    /* row 0: C-2 smp 1, row 1: 822, row 2: A02 + 822, row 3: 83F off, row 4: 862, row 5: 872, row 6: EE1 + 862 */
    static const unsigned char cells[][4] = {
        { 0x01, 0xac, 0x10, 0x00 }, { 0, 0, 0x08, 0x22 }, { 0, 0, 0x0a, 0x02 }, { 0, 0, 0x08, 0x3f },
        { 0, 0, 0x08, 0x62 }, { 0, 0, 0x08, 0x72 }, { 0, 0, 0x0e, 0xe1 }, { 0, 0, 0x0f, 0x00 }
    };
    size_t len;
    unsigned char *m = mk_mod(cells, 8, &len);
    pt4_song *s = pt4_open(m, len, NULL, NULL);
    int t, v0;
    CHECK(s != NULL, "unit module");
    if (!s) { free(m); return; }
    ticks_to_row(s, 0, 10);
    CHECK(s->st.ch[0].volume == 40, "note volume");
    ticks_to_row(s, 1, 10);   /* 822: tick 0 nothing */
    CHECK(s->st.ch[0].volume == 40, "82y not on tick 0");
    for (t = 1; t < 6; t++) pt4__tick(s);
    /* ticks 1..5: set on tick 1 (after the slide of tick 1 which was 0), +2 on ticks 2..5 */
    CHECK(s->st.ch[0].volume == 48, "822 after row: %d (want 48)", s->st.ch[0].volume);
    ticks_to_row(s, 2, 10);   /* A02 row: slide 2 then A02 -2 per tick */
    for (t = 1; t < 6; t++) pt4__tick(s);
    CHECK(s->st.ch[0].volume == 48, "822 + A02 cancel: %d", s->st.ch[0].volume);
    ticks_to_row(s, 3, 10);
    for (t = 1; t < 6; t++) pt4__tick(s);
    v0 = s->st.ch[0].volume;
    CHECK(v0 == 50, "83F stops the slide after tick 1: %d", v0);   /* tick 1 still slides (+2), then 83F = off */
    ticks_to_row(s, 4, 10);   /* 862: retrig on ticks 2 and 4, -4 each */
    for (t = 1; t < 6; t++) pt4__tick(s);
    CHECK(s->st.ch[0].volume == 42, "862 two retrigs: %d", s->st.ch[0].volume);
    ticks_to_row(s, 5, 10);   /* 872 (retrig 2 still on): tremor */
    pt4__tick(s);
    CHECK(s->st.efx8[0][1] == 2, "872 set");
    ticks_to_row(s, 6, 10);   /* EE1: pattern delay, tick 0 of the repeat runs the tick effects */
    CHECK(s->st.pattdelaytime == 2 || s->st.pattdelaycount, "EE1 pattern delay");
    pt4_close(s);
    free(m);
}

static void test_api(const char *dir)
{
    unsigned char *b;
    size_t len, n, total = 0;
    int16_t buf[2 * 1000];
    float fb[2 * 64];
    pt4_song *s = open_file(dir, "plain_mk.mod", &b, &len);
    int o, r;
    if (!s) return;
    while ((n = pt4_render_s16(s, buf, 1000, 48000)) > 0) total += n;
    CHECK(total > 96000 && total < 97500, "frames to the end at 48 kHz: %lu (length %ld ms)", (unsigned long)total, pt4_length_ms(s));
    CHECK(pt4_ended(s), "ended");
    pt4_seek_ms(s, 1000);
    pt4_position(s, &o, &r);
    CHECK(o == 0 && r >= 6 && r <= 8, "seek 1000 ms -> row %d", r);
    CHECK(pt4_render_f32(s, fb, 64, 44100) == 64, "f32 render");
    pt4_set_loop(s, 1);
    pt4_seek_ms(s, 0);
    total = 0;
    while (total < 48000 * 5 && (n = pt4_render_s16(s, buf, 1000, 48000)) > 0) total += n;
    CHECK(total >= 48000 * 5, "loop keeps playing");
    pt4_mute(s, 0, 1);
    pt4_seek_ms(s, 100);
    n = pt4_render_s16(s, buf, 1000, 48000);
    {
        size_t i;
        int nz = 0;
        for (i = 0; i < 2 * n; i++) nz |= buf[i];
        CHECK(n == 1000 && nz == 0, "mute channel 1 silences plain_mk");
    }
    pt4_close(s);
    free(b);
    /* custom allocator */
    {
        pt4_alloc al;
        al.alloc = NULL; al.free = NULL; al.user = NULL;
        s = open_file(dir, "pt4x_40.mod", &b, &len);
        if (s) pt4_close(s);
        s = pt4_open(b, len, &al, NULL);
        CHECK(s != NULL, "null allocator members -> malloc");
        if (s) pt4_close(s);
        free(b);
    }
}

static void test_dyn(const char *dir)
{
    unsigned char *b;
    size_t len;
    int16_t buf[2 * 64];
    pt4_song *s = open_file(dir, "dyn_loop.mod", &b, &len);
    int k, seen[8], vols[8], after0 = 0;
    if (!s) return;
    memset(seen, 0, sizeof(seen));
    memset(vols, 0, sizeof(vols));
    pt4_set_option(s, PT4_OPT_PATH, PT4_PATH_PAULA);
    for (k = 0; k < 28604 / 64; k++) {   /* 1 s, rows 0..7 (note on row 0) */
        pt4_render_s16(s, buf, 64, 28604);
        if (s->st.v[0].active && s->st.v[0].chunkmode) {
            int i = s->st.v[0].ck_idx & 7;
            if (seen[3] && i == 0) after0 = 1;
            seen[i] = 1;
            vols[i] = s->st.v[0].vol;
        }
    }
    CHECK(seen[0] && seen[1] && seen[2] && seen[3] && !after0, "paula: chunks 0..3, loop to chunk 1 (%d%d%d%d after0 %d)", seen[0], seen[1], seen[2], seen[3], after0);
    CHECK(vols[0] == 64 && vols[1] == 32 && vols[2] == 16 && vols[3] == 8, "chunk volumes %d %d %d %d", vols[0], vols[1], vols[2], vols[3]);
    /* mixer path (PT): the envelope is not used, constant volume */
    pt4_set_option(s, PT4_OPT_PATH, PT4_PATH_MIXER);
    pt4_seek_ms(s, 0);
    for (k = 0; k < 28604 / 64; k++) {
        pt4_render_s16(s, buf, 64, 28604);
        CHECK(!s->st.v[0].active || (!s->st.v[0].chunkmode && s->st.v[0].vol == 64), "mixer ignores DYN");
    }
    /* mixer with the switch: envelope heard */
    pt4_set_option(s, PT4_OPT_DYN_MIXER, 1);
    pt4_seek_ms(s, 0);
    memset(seen, 0, sizeof(seen));
    for (k = 0; k < 28604 / 64; k++) {
        pt4_render_s16(s, buf, 64, 28604);
        if (s->st.v[0].active && s->st.v[0].chunkmode) seen[s->st.v[0].ck_idx & 7] = 1;
    }
    CHECK(seen[0] && seen[3], "dyn_in_mixer plays the chunk list");
    pt4_close(s);
    /* loopseg 0: silence after the last chunk */
    if (b) {
        size_t at = len - 16 - 2;   /* loopseg word */
        int ended = 0;
        b[at] = 0; b[at + 1] = 0;
        s = pt4_open(b, len, NULL, NULL);
        CHECK(s && s->smp[3].env.loopseg == 0, "loopseg 0");
        if (s) {
            pt4_set_option(s, PT4_OPT_PATH, PT4_PATH_PAULA);
            for (k = 0; k < 28604 / 64; k++) {
                pt4_render_s16(s, buf, 64, 28604);
                if (k > 20 && !s->st.v[0].active) ended = 1;
            }
            CHECK(ended, "no loop: voice silent after the last chunk");
            pt4_close(s);
        }
    }
    free(b);
}

/* seek must equal playing through: render 1.5 s vs seek 1000 + 0.5 s */
static void test_seek(const char *dir)
{
    static const char *mods[] = { "pt4x_8ch.mod", "dyn_loop.mod", "plain_mk.mod", "fx86y.mod" };
    static const unsigned rates[] = { 48000, 44100, 96000 };
    static int16_t a[2 * 144000], b[2 * 72000];
    size_t m, ri;
    for (m = 0; m < sizeof(mods) / sizeof(mods[0]); m++) {
        for (ri = 0; ri < 3; ri++) {
            unsigned char *buf;
            size_t len, na, nb, cut, half, i, bad = 0;
            unsigned r = rates[ri];
            pt4_song *s = open_file(dir, mods[m], &buf, &len);
            if (!s) continue;
            cut = (size_t)r;            /* 1000 ms */
            half = (size_t)r / 2;
            na = pt4_render_s16(s, a, cut + half, r);
            pt4_set_rate(s, r);
            pt4_seek_ms(s, 1000);
            nb = pt4_render_s16(s, b, half, r);
            CHECK(na == cut + half && nb == half, "seek %s %u: frames %lu/%lu", mods[m], r, (unsigned long)na, (unsigned long)nb);
            for (i = 0; i < 2 * half && i < 2 * nb; i++) if (a[2 * cut + i] != b[i]) bad++;
            CHECK(bad == 0, "seek %s %u Hz: %lu samples differ", mods[m], r, (unsigned long)bad);
            pt4_close(s);
            free(buf);
        }
    }
}

/* replayer/mixer changes of PT 4.1.2: loop start and 9xx above 64 KB when mixed, wide 8xx and notes C-0..B-4,
   15-sample header clamp */
static void put_cell(unsigned char *c, int per, int smp, int eff, int par)
{
    c[0] = (unsigned char)((smp & 0xf0) | (per >> 8));
    c[1] = (unsigned char)(per & 0xff);
    c[2] = (unsigned char)(((smp & 15) << 4) | eff);
    c[3] = (unsigned char)par;
}

static void test_412(const char *dir)
{
    unsigned char *b, *m;
    size_t len;
    pt4_song *s;
    int path;

    for (path = PT4_PATH_PAULA; path <= PT4_PATH_MIXER; path++) {
        s = open_file(dir, "loop64k8.mod", &b, &len);
        if (!s) { free(b); continue; }
        pt4_set_option(s, PT4_OPT_PATH, path);
        ticks_to_row(s, 0, 20);
        if (path == PT4_PATH_MIXER) {
            CHECK(s->st.ch[4].loopstart - s->st.ch[4].samplestart == 66000, "mixed loop start %lu",
                  (unsigned long)(s->st.ch[4].loopstart - s->st.ch[4].samplestart));
            CHECK(s->st.ch[0].length == 36000 - 32640 && s->st.ch[0].start - s->st.ch[0].samplestart == 65280,
                  "mixed 9FF on 36000 words: length %u", s->st.ch[0].length);
        } else {
            CHECK(s->st.ch[4].loopstart - s->st.ch[4].samplestart == 464, "paula loop start (ASL.W) %lu",
                  (unsigned long)(s->st.ch[4].loopstart - s->st.ch[4].samplestart));
            CHECK(s->st.ch[0].start == ADDR_SCRATCH, "paula 9FF on 36000 words cuts the note (silence)");
        }
        pt4_close(s);
        free(b);
    }

    /* 9CHN: ch1 period 60 (C-0..B-4 range), ch2 period 1000, ch3 arpeggio on 60, ch6 82A (wide: panning, no slide) */
    len = 1084 + 9 * 256 + 256;
    m = (unsigned char *)calloc(1, len);
    if (m) {
        int k;
        memcpy(m, "wide 412", 8);
        m[20 + 22] = 0; m[20 + 23] = 128; m[20 + 25] = 32; m[20 + 29] = 128;   /* sample 1: 256 bytes, vol 32, loop */
        for (k = 1; k < 31; k++) m[20 + 30 * k + 29] = 1;
        m[950] = 1;
        memcpy(m + 1080, "9CHN", 4);
        put_cell(m + 1084 + 0 * 4, 60, 1, 0, 0);
        put_cell(m + 1084 + 1 * 4, 1000, 1, 0, 0);
        put_cell(m + 1084 + 2 * 4, 60, 1, 0, 0x37);
        put_cell(m + 1084 + 5 * 4, 428, 1, 8, 0x2a);
        put_cell(m + 1084 + 9 * 4 + 5 * 4, 0, 0, 8, 0x2a);
        for (k = 0; k < 256; k++) m[1084 + 9 * 256 + k] = (unsigned char)(k * 5);
        s = pt4_open(m, len, NULL, NULL);
        CHECK(s != NULL, "9CHN open");
        if (s) {
            ticks_to_row(s, 1, 20);
            pt4__update_voices(s);
            CHECK(s->st.ch[0].period == 60, "wide note period 60: %u", s->st.ch[0].period);
            CHECK(s->st.ch[1].period == 1000, "wide note period 1000: %u", s->st.ch[1].period);
            CHECK(s->st.v[0].period == 60 && s->st.v[0].active, "wide voice at period 60: %u", s->st.v[0].period);
            CHECK(s->st.ch[5].volume == 32 && s->st.ch[1].volume == 32, "wide 82A: no slide (%u, %u)",
                  s->st.ch[5].volume, s->st.ch[1].volume);
            pt4__tick(s);
            CHECK(s->st.aud[2].per == 60, "wide arpeggio keeps period 60: %u", s->st.aud[2].per);
            pt4_close(s);
        }
        /* TakeTracker id 09CN = 9 channels; period 10 plays at the card's top rate (192 kHz) */
        memcpy(m + 1080, "09CN", 4);
        put_cell(m + 1084 + 3 * 4, 10, 1, 0, 0);
        s = pt4_open(m, len, NULL, NULL);
        CHECK(s && pt4_channels(s) == 9 && s->wide, "09CN: wide 9 channels");
        if (s) {
            ticks_to_row(s, 0, 20);
            pt4__update_voices(s);
            CHECK(s->st.v[3].step == (uint32_t)(((uint64_t)192000 << 16) / s->rate), "card rate cap: step %lu",
                  (unsigned long)s->st.v[3].step);
            pt4_close(s);
        }
        put_cell(m + 1084 + 3 * 4, 0, 0, 0, 0);
        /* same cells as 8CHN without NOTES EXT: table lookup (60 -> 0, 1000 -> C-1) */
        memcpy(m + 1080, "8CHN", 4);
        s = pt4_open(m, len, NULL, NULL);
        if (s) {
            ticks_to_row(s, 0, 20);
            CHECK(s->st.ch[0].period == 0 && s->st.ch[1].period == 856, "8CHN table periods %u %u", s->st.ch[0].period,
                  s->st.ch[1].period);
            pt4_close(s);
        }
        free(m);
    }

    /* song name that starts like a foreign magic: a module id at 1080 wins (pt_MagicMod41), a hunk file does not */
    s = open_file(dir, "plain_mk.mod", &b, &len);
    if (s) {
        pt4_close(s);
        memcpy(b, "MMD1", 4);
        CHECK(pt4_detect(b, len) == PT4_PLAIN_MOD, "MMD1 name + M.K. loads");
        memcpy(b + 1080, "TDZ3", 4);
        CHECK(pt4_detect(b, len) != PT4_NONE, "MMD1 name + TDZ3 loads");
        memcpy(b, "SymM", 4);
        memcpy(b + 1080, "FLT4", 4);
        s = pt4_open(b, len, NULL, NULL);
        CHECK(s != NULL, "SymM name + FLT4 opens");
        pt4_close(s);
        memcpy(b + 1080, "XY..", 4);
        CHECK(pt4_detect(b, len) == PT4_NONE, "SymM + unknown id stays rejected");
        b[0] = 0; b[1] = 0; b[2] = 3; b[3] = 0xf3;
        memcpy(b + 1080, "M.K.", 4);
        CHECK(pt4_detect(b, len) == PT4_NONE, "hunk file stays rejected");
    }
    free(b);

    /* 15 samples: loop end past the sample end is clamped like 31-sample modules */
    s = open_file(dir, "15smp.mod", &b, &len);
    if (s) {
        pt4_close(s);
        b[20 + 26] = 0; b[20 + 27] = 10;     /* sample 1 (32 words): loop start 10, length 40 */
        b[20 + 28] = 0; b[20 + 29] = 40;
        s = pt4_open(b, len, NULL, NULL);
        CHECK(s && s->smp[1].repeat == 10 && s->smp[1].replen == 22, "15smp loop clamp: %u/%u",
              s ? s->smp[1].repeat : 0, s ? s->smp[1].replen : 0);
        pt4_close(s);
    }
    free(b);
}

int main(int argc, char **argv)
{
    if (argc >= 3 && !strcmp(argv[1], "trace")) return trace(argv[2], argc > 3 ? atoi(argv[3]) : 2000);
    if (argc >= 3 && !strcmp(argv[1], "vtrace")) return vtrace(argv[2], argc > 3 ? atoi(argv[3]) : 2000);
    if (argc < 2) { printf("usage: pt4test TESTDATA_DIR | trace MODULE [TICKS]\n"); return 2; }
    test_detect(argv[1]);
    test_loader(argv[1]);
    test_timing(argv[1]);
    test_effects();
    test_dyn(argv[1]);
    test_api(argv[1]);
    test_seek(argv[1]);
    test_412(argv[1]);
    printf("%d checks, %d failed\n", checks, fails);
    return fails ? 1 : 0;
}
