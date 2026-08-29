#!/usr/bin/env bash
# ZWARTOS robot: auto-bump entri versi-mati + validasi semua link + tulis STATUS.md
set -u
F="zwartos-oslist.txt"
UA="Mozilla/5.0 (zwartos-bot)"
newest(){ curl -A "$UA" -sL --max-time 45 "$1" 2>/dev/null | grep -oE "$2" | sort -Vu | tail -1; }
code_of(){ curl -A "$UA" -sIL --max-time 45 -o /dev/null -w '%{http_code}' "$1" 2>/dev/null; }
gh_iso(){ curl -A "$UA" -sL --max-time 45 "https://api.github.com/repos/$1/releases/latest" 2>/dev/null | grep -oE 'https://[^"]+\.iso' | grep -iE "$2" | sort -Vu | tail -1; }
bump(){ # $1 name-prefix (di awal baris)  $2 baris-baru
  local t; t=$(mktemp)
  awk -v p="$1" -v nl="$2" 'BEGIN{d=0}{ if(!d && index($0,p)==1){print nl; d=1} else print }' "$F" > "$t" && mv "$t" "$F"
}

echo "== auto-bump entri berversi =="
# OpenBSD -> versi terbaru
ob="https://cdn.openbsd.org/pub/OpenBSD/"; ov=$(newest "$ob" '7\.[0-9]/'); ov=${ov%/}
if [ -n "$ov" ]; then n=$(echo "$ov"|tr -d '.'); u="${ob}${ov}/amd64/install${n}.iso"
  [ "$(code_of "$u")" = 200 ] && { bump "OpenBSD" "OpenBSD (~800MB)                 | ${u}"; echo "  OpenBSD -> $ov"; }; fi
# Tails
tb="https://download.tails.net/tails/stable/"; ts=$(newest "$tb" 'tails-amd64-[0-9.]+/'); ts=${ts%/}
if [ -n "$ts" ]; then u="${tb}${ts}/${ts}.iso"
  [ "$(code_of "$u")" = 200 ] && { bump "Tails" "Tails (~1.7GB)                   | ${u}"; echo "  Tails -> $ts"; }; fi
# CachyOS
cb="https://mirror.cachyos.org/ISO/desktop/"; cs=$(newest "$cb" '[0-9]{6}/'); cs=${cs%/}
if [ -n "$cs" ]; then u="${cb}${cs}/cachyos-desktop-linux-${cs}.iso"
  [ "$(code_of "$u")" = 200 ] && { bump "CachyOS" "CachyOS (~3.0GB)                 | ${u}"; echo "  CachyOS -> $cs"; }; fi
# ShredOS (github release)
su=$(gh_iso "PartialVolume/shredos.x86_64" 'plus-partition\.iso'); [ -z "$su" ] && su=$(gh_iso "PartialVolume/shredos.x86_64" '\.iso')
[ -n "$su" ] && [ "$(code_of "$su")" = 200 ] && { bump "ShredOS" "ShredOS wipe (~394MB)            | ${su}"; echo "  ShredOS -> bump"; }

echo "== validasi semua entri =="
ok=0; bad=0; broken=""
while IFS= read -r line; do
  case "$line" in ''|\#*) continue;; esac
  name=$(printf '%s' "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$1);print $1}')
  a=$(printf '%s'    "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$2);print $2}')
  b=$(printf '%s'    "$line" | awk -F'|' 'NF>=3{gsub(/^[ \t]+|[ \t]+$/,"",$3);print $3}')
  if [ -n "$b" ]; then f=$(newest "$a" "$b"); [ -z "$f" ] && { bad=$((bad+1)); broken="${broken}\n- ${name} (resolve gagal)"; continue; }; url="$a$f"; else url="$a"; fi
  c=$(code_of "$url")
  if [ "$c" = 200 ] || [ "$c" = 302 ]; then ok=$((ok+1)); else bad=$((bad+1)); broken="${broken}\n- ${name} (HTTP ${c})"; fi
done < "$F"

{
  echo "# ZWARTOS — status daftar OS"
  echo
  echo "Terakhir dicek robot: $(date -u '+%Y-%m-%d %H:%M UTC')"
  echo
  echo "- Link sehat : ${ok}"
  echo "- Bermasalah : ${bad}"
  if [ "$bad" -gt 0 ]; then echo; echo "## Perlu diperbaiki manual"; printf '%b\n' "$broken"; fi
} > STATUS.md
echo "HASIL: ok=$ok bad=$bad"
