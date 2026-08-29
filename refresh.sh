#!/usr/bin/env bash
# ZWARTOS robot: auto-bump entri versi-mati + validasi semua link + tulis README.md
set -u
F="zwartos-oslist.txt"
UA="Mozilla/5.0 (zwartos-bot)"
newest(){ curl -A "$UA" -sL --max-time 45 "$1" 2>/dev/null | grep -oE "$2" | sort -Vu | tail -1; }
code_of(){ curl -A "$UA" -sIL --max-time 45 -o /dev/null -w '%{http_code}' "$1" 2>/dev/null; }
gh_iso(){ curl -A "$UA" -sL --max-time 45 "https://api.github.com/repos/$1/releases/latest" 2>/dev/null | grep -oE 'https://[^"]+\.iso' | grep -iE "$2" | sort -Vu | tail -1; }
bump(){ local t; t=$(mktemp); awk -v p="$1" -v nl="$2" 'BEGIN{d=0}{ if(!d && index($0,p)==1){print nl; d=1} else print }' "$F" > "$t" && mv "$t" "$F"; }

echo "== auto-bump entri berversi =="
ob="https://cdn.openbsd.org/pub/OpenBSD/"; ov=$(newest "$ob" '7\.[0-9]/'); ov=${ov%/}
if [ -n "$ov" ]; then n=$(echo "$ov"|tr -d '.'); u="${ob}${ov}/amd64/install${n}.iso"; [ "$(code_of "$u")" = 200 ] && { bump "OpenBSD" "OpenBSD (~800MB)                 | ${u}"; echo "  OpenBSD -> $ov"; }; fi
tb="https://download.tails.net/tails/stable/"; ts=$(newest "$tb" 'tails-amd64-[0-9.]+/'); ts=${ts%/}
if [ -n "$ts" ]; then u="${tb}${ts}/${ts}.iso"; [ "$(code_of "$u")" = 200 ] && { bump "Tails" "Tails (~1.7GB)                   | ${u}"; echo "  Tails -> $ts"; }; fi
cb="https://mirror.cachyos.org/ISO/desktop/"; cs=$(newest "$cb" '[0-9]{6}/'); cs=${cs%/}
if [ -n "$cs" ]; then u="${cb}${cs}/cachyos-desktop-linux-${cs}.iso"; [ "$(code_of "$u")" = 200 ] && { bump "CachyOS" "CachyOS (~3.0GB)                 | ${u}"; echo "  CachyOS -> $cs"; }; fi
su=$(gh_iso "PartialVolume/shredos.x86_64" 'plus-partition\.iso'); [ -z "$su" ] && su=$(gh_iso "PartialVolume/shredos.x86_64" '\.iso')
[ -n "$su" ] && [ "$(code_of "$su")" = 200 ] && { bump "ShredOS" "ShredOS wipe (~394MB)            | ${su}"; echo "  ShredOS -> bump"; }

echo "== validasi + kumpulkan status =="
TSV=$(mktemp); : > "$TSV"; cat="Lainnya"
ok=0; warn=0; bad=0
while IFS= read -r line; do
  case "$line" in
    *'==='*) cat=$(printf '%s' "$line" | sed 's/[#=]//g; s/^[ \t]*//; s/[ \t]*$//'); continue;;
    ''|\#*) continue;;
  esac
  name=$(printf '%s' "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$1);print $1}')
  a=$(printf '%s'    "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$2);print $2}')
  b=$(printf '%s'    "$line" | awk -F'|' 'NF>=3{gsub(/^[ \t]+|[ \t]+$/,"",$3);print $3}')
  [ -n "$b" ] && type="auto" || type="link"
  if [ -n "$b" ]; then f=$(newest "$a" "$b"); [ -z "$f" ] && { bad=$((bad+1)); printf '%s\t%s\t%s\t%s\n' "$cat" "$name" "$type" "❌" >> "$TSV"; continue; }; url="$a$f"; else url="$a"; fi
  c=$(code_of "$url")
  if [ "$c" = 200 ] || [ "$c" = 302 ]; then ok=$((ok+1)); em="✅"
  elif [ "$c" = 403 ] || [ "$c" = 429 ]; then warn=$((warn+1)); em="⚠️"
  else bad=$((bad+1)); em="❌"; fi
  printf '%s\t%s\t%s\t%s\n' "$cat" "$name" "$type" "$em" >> "$TSV"
done < "$F"
total=$((ok+warn+bad))
echo "HASIL: ok=$ok warn=$warn bad=$bad total=$total"

echo "== tulis README.md =="
rm -f STATUS.md
{
  echo "# ZWARTOS"
  echo
  echo "Unduh ISO sistem operasi langsung ke flashdisk **Ventoy** lewat **WiFi**/LAN — pilih OS, ambil versi terbaru, reboot, boot. Satu flashdisk, banyak OS, tanpa siapkan ISO dari awal."
  echo
  echo "Daftar OS ada di **[\`zwartos-oslist.txt\`](zwartos-oslist.txt)** dan ditarik otomatis oleh ISO ZWARTOS tiap online. Robot (GitHub Action) memeriksa link & memperbarui versi tiap minggu."
  echo
  echo "**Diperiksa robot:** $(date -u '+%Y-%m-%d %H:%M UTC') — ✅ Aktif: **${ok}** · ⚠️ Diragukan: **${warn}** · ❌ Rusak: **${bad}** · Total: **${total}**"
  echo
  echo "## Cara pakai"
  echo "1. Salin \`zwartos.iso\` ke flashdisk Ventoy."
  echo "2. Boot flashdisk → pilih **ZWARTOS** → tekan \`w\` untuk sambungkan WiFi."
  echo "3. Ketik **nomor OS** → versi terbaru terunduh ke flashdisk → tekan \`x\` reboot → pilih ISO baru di menu Ventoy."
  echo
  echo "## Menambah / memperbaiki OS"
  echo "Edit [\`zwartos-oslist.txt\`](zwartos-oslist.txt). Dua format baris:"
  echo '- `Nama | https://folder/ | pola-nama-file` — **auto**: robot & ISO cari versi terbaru sendiri.'
  echo '- `Nama | https://link-langsung.iso` — **link tetap**.'
  echo
  echo "Simpan → semua flashdisk ZWARTOS ikut terbaru saat online berikutnya."
  echo
  echo "## Daftar OS"
  echo
  echo "Legenda: ✅ aktif · ⚠️ diragukan (mungkin blokir bot/CI; biasanya tetap bisa dari laptop) · ❌ rusak"
  awk -F'\t' '!seen[$1]++{print $1}' "$TSV" | while IFS= read -r c; do
    echo
    echo "### ${c}"
    echo
    echo "| OS | Status | Tipe |"
    echo "|---|:---:|:---:|"
    awk -F'\t' -v c="$c" '$1==c{printf "| %s | %s | %s |\n",$2,$4,$3}' "$TSV"
  done
  echo
  echo "---"
  echo "_README ini digenerate otomatis oleh robot (\`refresh.sh\` via GitHub Actions)._"
} > README.md
echo "README.md ditulis."
