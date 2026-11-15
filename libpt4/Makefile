# libpt4 - gcc/clang build. make CC=clang to switch compilers.
CC      ?= cc
CFLAGS  ?= -std=c99 -O2 -Wall -Wextra -Wpedantic -Werror
AR      ?= ar
SRCS    := src/load.c src/replay.c src/voice.c src/api.c src/tables.c src/float.c
OBJDIR  := build
OBJS    := $(SRCS:src/%.c=$(OBJDIR)/%.o)

all: $(OBJDIR)/libpt4.a $(OBJDIR)/pt4play $(OBJDIR)/pt4test $(OBJDIR)/pt4sum

$(OBJDIR)/%.o: src/%.c src/pt4_internal.h include/pt4.h
	@mkdir -p $(OBJDIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJDIR)/libpt4.a: $(OBJS)
	$(AR) rcs $@ $^

$(OBJDIR)/pt4play: cli/pt4play.c $(OBJDIR)/libpt4.a
	$(CC) $(CFLAGS) $< $(OBJDIR)/libpt4.a -o $@

$(OBJDIR)/pt4test: test/pt4test.c $(OBJDIR)/libpt4.a
	$(CC) $(CFLAGS) $< $(OBJDIR)/libpt4.a -o $@

$(OBJDIR)/pt4sum: test/pt4sum.c $(OBJDIR)/libpt4.a
	$(CC) $(CFLAGS) $< $(OBJDIR)/libpt4.a -o $@

test: $(OBJDIR)/pt4test
	$(OBJDIR)/pt4test testdata

# fuzz smoke with ASan/UBSan (clang or gcc)
fuzz:
	@mkdir -p $(OBJDIR)
	$(CC) -std=c99 -g -O1 -fsanitize=address,undefined -fno-sanitize-recover=all $(SRCS) test/fuzz.c -o $(OBJDIR)/pt4fuzz
	$(OBJDIR)/pt4fuzz testdata 100000

clean:
	rm -rf $(OBJDIR)

.PHONY: all test fuzz clean
