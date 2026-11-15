#!/bin/sh
# print module info for each argument (libpt4/build/pt4play --info)
d=$(dirname "$0")/..
for m in "$@"; do
    echo "== $m"
    "$d/build/pt4play" "$m" --info -o /dev/null --seconds 5 | grep -v "^ *[0-9]* '"
done
