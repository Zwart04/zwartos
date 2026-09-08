#!/bin/sh
# ============================================================
#  Ambil peringkat distro dari DistroWatch -> zwartos-peringkat.txt
#
#  Dijalankan oleh bot GitHub, bukan oleh ZWARTOS di laptop.
#  Hasilnya ditarik ZWARTOS lewat satu berkas kecil, jadi laptop
#  pemakai tidak pernah menyentuh DistroWatch sama sekali.
#
#  SOPAN SANTUN (robots.txt DistroWatch mensyaratkan Crawl-Delay: 15):
#    - 6 permintaan per hari, jeda 15 detik di antaranya
#    - User-Agent menyebut identitas dan alamat proyek
#  Jangan menambah jumlah permintaan tanpa menaikkan jeda.
#
#  Pemakaian:
#    ./dw-fetch.sh [berkas-keluaran]
#    ./dw-fetch.sh --dari-berkas <halaman.html> <kategori> [mode]
# ============================================================
set -eu

DIR=$(cd "$(dirname "$0")" && pwd)
PARSER="$DIR/dw-rank.py"
OUT="${1:-$DIR/../zwartos-peringkat.txt}"
UA="ZWARTOS-rank/1.0 (+https://github.com/Zwart04/zwartos)"
JEDA=15

if [ "${1:-}" = "--dari-berkas" ]; then
  python3 "$PARSER" "${4:-parse}" "$2" "$3"
  exit 0
fi

# url<TAB>mode<TAB>nama-kategori
#   mode "parse"   -> tabel phr1/phr2/phr3 di index.php?dataspan=
#   mode "ranking" -> tabel dwres.php?resource=ranking
# CATATAN: dataspan=score itu "Most Ratings" (urut BANYAKNYA penilaian) -
# sudah dicocokkan baris demi baris dengan halaman aslinya. Rata-rata
# sesungguhnya hanya ada di resource=ranking&sort=average.
SUMBER="https://distrowatch.com/index.php?dataspan=score	parse	Rating terbanyak
https://distrowatch.com/dwres.php?resource=ranking&sort=average	ranking	Rating rata-rata
https://distrowatch.com/index.php?dataspan=4	parse	Terpopuler 30 hari
https://distrowatch.com/index.php?dataspan=52	parse	Terpopuler 12 bulan
https://distrowatch.com/index.php?dataspan=trending-4	parse	Sedang naik daun 30 hari
https://distrowatch.com/index.php?dataspan=trending-52	parse	Sedang naik daun 12 bulan"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
: > "$TMP/hasil"
PERTAMA=1

printf '%s\n' "$SUMBER" | while IFS='	' read -r url mode nama; do
  [ -n "$url" ] || continue
  [ "$PERTAMA" = 1 ] || sleep "$JEDA"
  PERTAMA=0
  echo "  ambil [$mode] $nama" >&2
  CODE=$(curl -sS --compressed -A "$UA" --max-time 60 -w "%{http_code}" \
         "$url" -o "$TMP/p.html" || echo 000)
  UKURAN=$(wc -c < "$TMP/p.html" 2>/dev/null || echo 0)
  echo "    http=$CODE ukuran=$UKURAN byte" >&2
  if [ "$CODE" != 200 ] || [ "$UKURAN" -lt 2000 ]; then
    echo "    ! halaman tidak wajar - dilewati" >&2
    continue
  fi
  # Kalau struktur halaman berubah, kategori ini dilewati dan markup-nya
  # dicetak ke log - lebih baik kehilangan satu kategori daripada menulis
  # berkas rusak, dan kegagalannya harus bisa didiagnosis tanpa menebak.
  if python3 "$PARSER" "$mode" "$TMP/p.html" "$nama" >> "$TMP/hasil" 2>/dev/null; then
    echo "    ok" >&2
  else
    echo "    ! struktur tidak dikenali - dilewati" >&2
    echo "      phr1=$(grep -c phr1 "$TMP/p.html" || true) ratings=$(grep -c 'resource=ratings' "$TMP/p.html" || true)" >&2
    tr '\n' ' ' < "$TMP/p.html" | grep -o 'resource=ratings.\{0,220\}' | head -1 | sed 's/^/      markup: /' >&2 || true
  fi
done

BARIS=$(wc -l < "$TMP/hasil" | tr -d ' ')
if [ "$BARIS" -lt 20 ]; then
  echo "GAGAL: cuma $BARIS baris terbaca, berkas lama TIDAK ditimpa." >&2
  exit 1
fi

{
  echo "# peringkat distro dari DistroWatch - dibuat otomatis, jangan disunting tangan"
  echo "# kolom: kategori<TAB>peringkat<TAB>slug<TAB>nama<TAB>nilai"
  cat "$TMP/hasil"
} > "$OUT"

echo "OK: $BARIS baris -> $OUT" >&2
