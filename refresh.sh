#!/usr/bin/env bash
# ZWARTOS robot: (1) cari versi OS terbaru (bump), (2) update blok status & daftar OS di README.md
# Hanya memperbarui bagian bertanda <!-- STATUS --> & <!-- OSLIST --> ; sisanya dibiarkan.
set -u
F="zwartos-oslist.txt"; RM="README.md"
UA="Mozilla/5.0 (zwartos-bot)"
newest(){ curl -A "$UA" -sL --max-time 45 "$1" 2>/dev/null | grep -oE "$2" | sort -Vu | tail -1; }
code_of(){ curl -A "$UA" -sIL --max-time 45 -o /dev/null -w '%{http_code}' "$1" 2>/dev/null; }
gh_iso(){ curl -A "$UA" -sL --max-time 45 "https://api.github.com/repos/$1/releases/latest" 2>/dev/null | grep -oE 'https://[^"]+\.iso' | grep -iE "$2" | sort -Vu | tail -1; }
bump(){ local t; t=$(mktemp); awk -v p="$1" -v nl="$2" 'BEGIN{d=0}{ if(!d && index($0,p)==1){print nl; d=1} else print }' "$F" > "$t" && mv "$t" "$F"; }
# retry-aware
resolve2(){ local f; f=$(newest "$1" "$2"); [ -z "$f" ] && f=$(newest "$1" "$2"); printf '%s' "$f"; }
code2(){ local c; c=$(code_of "$1"); case "$c" in 200|302) ;; *) c=$(code_of "$1");; esac; printf '%s' "$c"; }

echo "== tugas 1: cari versi terbaru (bump) =="
ob="https://cdn.openbsd.org/pub/OpenBSD/"; ov=$(newest "$ob" '7\.[0-9]/'); ov=${ov%/}
if [ -n "$ov" ]; then n=$(echo "$ov"|tr -d '.'); u="${ob}${ov}/amd64/install${n}.iso"; [ "$(code_of "$u")" = 200 ] && { bump "OpenBSD" "OpenBSD (~800MB)                 | ${u}"; echo "  OpenBSD -> $ov"; }; fi
tb="https://download.tails.net/tails/stable/"; ts=$(newest "$tb" 'tails-amd64-[0-9.]+/'); ts=${ts%/}
if [ -n "$ts" ]; then u="${tb}${ts}/${ts}.iso"; [ "$(code_of "$u")" = 200 ] && { bump "Tails" "Tails (~1.7GB)                   | ${u}"; echo "  Tails -> $ts"; }; fi
cb="https://mirror.cachyos.org/ISO/desktop/"; cs=$(newest "$cb" '[0-9]{6}/'); cs=${cs%/}
if [ -n "$cs" ]; then u="${cb}${cs}/cachyos-desktop-linux-${cs}.iso"; [ "$(code_of "$u")" = 200 ] && { bump "CachyOS" "CachyOS (~3.0GB)                 | ${u}"; echo "  CachyOS -> $cs"; }; fi
su=$(gh_iso "PartialVolume/shredos.x86_64" 'plus-partition\.iso'); [ -z "$su" ] && su=$(gh_iso "PartialVolume/shredos.x86_64" '\.iso')
[ -n "$su" ] && [ "$(code_of "$su")" = 200 ] && { bump "ShredOS" "ShredOS wipe (~394MB)            | ${su}"; echo "  ShredOS -> bump"; }

echo "== tugas 2: validasi + susun blok =="
TSV=$(mktemp); : > "$TSV"; cat="Lainnya"; ok=0; warn=0; bad=0
while IFS= read -r line; do
  case "$line" in
    *'==='*) cat=$(printf '%s' "$line" | sed 's/[#=]//g; s/^[ \t]*//; s/[ \t]*$//'); continue;;
    ''|\#*) continue;;
  esac
  name=$(printf '%s' "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$1);print $1}')
  a=$(printf '%s'    "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$2);print $2}')
  b=$(printf '%s'    "$line" | awk -F'|' 'NF>=3{gsub(/^[ \t]+|[ \t]+$/,"",$3);print $3}')
  [ -n "$b" ] && type="auto" || type="link"
  if [ -n "$b" ]; then f=$(resolve2 "$a" "$b"); [ -z "$f" ] && { warn=$((warn+1)); printf '%s\t%s\t%s\t%s\n' "$cat" "$name" "$type" "⚠️" >> "$TSV"; continue; }; url="$a$f"; else url="$a"; fi
  c=$(code2 "$url")
  case "$c" in
    200|302) ok=$((ok+1)); em="✅";;
    404|410) bad=$((bad+1)); em="❌";;
    *)       warn=$((warn+1)); em="⚠️";;
  esac
  printf '%s\t%s\t%s\t%s\n' "$cat" "$name" "$type" "$em" >> "$TSV"
done < "$F"
total=$((ok+warn+bad))
echo "HASIL: ok=$ok warn=$warn bad=$bad total=$total"

printf '**Diperiksa robot:** %s — ✅ Aktif: **%s** · ⚠️ Diragukan: **%s** · ❌ Rusak: **%s** · Total: **%s**\n' \
  "$(date -u '+%Y-%m-%d %H:%M UTC')" "$ok" "$warn" "$bad" "$total" > /tmp/status.md
{
  awk -F'\t' '!seen[$1]++{print $1}' "$TSV" | while IFS= read -r c; do
    echo; echo "### ${c}"; echo
    echo "| OS | Status | Tipe |"; echo "|---|:---:|:---:|"
    awk -F'\t' -v c="$c" '$1==c{printf "| %s | %s | %s |\n",$2,$4,$3}' "$TSV"
  done
} > /tmp/oslist.md

echo "== update README.md (hanya blok bertanda) =="
rm -f STATUS.md
if grep -q 'STATUS:START' "$RM" 2>/dev/null && grep -q 'OSLIST:START' "$RM" 2>/dev/null; then
  awk '
    /<!-- STATUS:START -->/{print; while((getline l < "/tmp/status.md")>0) print l; close("/tmp/status.md"); s=1; next}
    /<!-- STATUS:END -->/{s=0; print; next}
    /<!-- OSLIST:START -->/{print; while((getline l < "/tmp/oslist.md")>0) print l; close("/tmp/oslist.md"); o=1; next}
    /<!-- OSLIST:END -->/{o=0; print; next}
    (s||o){next}
    {print}
  ' "$RM" > "$RM.tmp" && mv "$RM.tmp" "$RM"
  echo "  README diperbarui (blok status + daftar)."
else
  echo "  penanda hilang -> tulis ulang README dari template"
  {
    echo "# ZWARTOS"; echo
    echo "Unduh ISO sistem operasi langsung ke flashdisk **Ventoy** lewat **WiFi**/LAN."; echo
    echo "<!-- STATUS:START -->"; cat /tmp/status.md; echo "<!-- STATUS:END -->"; echo
    echo "## Daftar OS"; echo
    echo "Legenda: ✅ aktif · ⚠️ diragukan · ❌ rusak"
    echo "<!-- OSLIST:START -->"; cat /tmp/oslist.md; echo "<!-- OSLIST:END -->"
  } > "$RM"
fi
