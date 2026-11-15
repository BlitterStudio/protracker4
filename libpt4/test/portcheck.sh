#!/bin/sh
# Portability checks for libpt4 (Change 138, task 8.1): gcc and clang -std=c99 -Werror, conversion
# warnings as a stand-in for MSVC /W4 (C4244/C4267), C++20 use of the header.
cd "$(dirname "$0")/.." || exit 1
SRC="src/load.c src/replay.c src/voice.c src/api.c src/tables.c src/float.c"
T=$(mktemp -d)
rc=0
for cc in gcc clang; do
    command -v $cc >/dev/null || { echo "$cc: not installed"; continue; }
    for f in $SRC; do
        $cc -std=c99 -O2 -Wall -Wextra -Wpedantic -Werror -c "$f" -o "$T/x.o" || rc=1
    done
    n=$(for f in $SRC; do $cc -std=c99 -Wall -Wextra -Wconversion -Wsign-conversion -c "$f" -o "$T/x.o" 2>&1; done | grep -c 'warning:')
    echo "$cc -std=c99 -Werror: ok=$((1 - rc)), -Wconversion -Wsign-conversion warnings: $n"
done
printf '#include "pt4.h"\nint main() { pt4_song *s = pt4_open(nullptr, 0, nullptr, nullptr); return s ? 1 : 0; }\n' > "$T/t.cpp"
if command -v g++ >/dev/null; then
    g++ -std=c++20 -Wall -Wextra -Werror -Iinclude "$T/t.cpp" build/libpt4.a -o "$T/t" && echo "g++ -std=c++20 header + link: ok" || rc=1
fi
rm -rf "$T"
exit $rc
