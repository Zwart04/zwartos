#!/bin/sh
# ============================================================
#  Ambil peringkat distro dari DistroWatch -> zwartos-peringkat.txt
#
#  Dijalankan oleh bot GitHub, bukan oleh ZWARTOS di laptop.
#  Hasilnya ditarik ZWARTOS lewat satu berkas kecil, jadi laptop
#  pemakai tidak pernah menyentuh DistroWatch sama sekali.
#
#  SOPAN SANTUN (robots.txt DistroWatch mensyaratkan Crawl-Delay: 15):
#    - hanya 5 permintaan per hari
#    - jeda 15 detik di antaranya
#    - User-Agent menyebut identitas dan alamat proyek
#  Jangan menambah jumlah permintaan tanpa menaikkan jeda.
#
#  Pemakaian:
#    ./dw-fetch.sh [berkas-keluaran]
#    ./dw-fetch.sh --dari-berkas <halaman.html> <kategori>   (uji tanpa jaringan)
# ============================================================
set -eu

DIR=$(cd "$(dirname "$0")" && pwd)
PARSER="$DIR/dw-rank.py"
OUT="${1:-$DIR/../zwartos-peringkat.txt}"
UA="ZWARTOS-rank/1.0 (+https://github.com/Zwart04/zwartos)"
JEDA=15

# Uji parser tanpa menyentuh jaringan.
if [ "${1:-}" = "--dari-berkas" ]; then
  python3 "$PARSER" parse "$2" "$3"
  exit 0
fi

# dataspan -> nama kategori. Nilai-nilai ini diambil dari <select name="dataspan">
# di halaman aslinya, bukan tebakan. "Most Ratings" TIDAK ada di select itu;
# yang tersedia untuk rating hanyalah "score" (Average Rating).
SPANS='score:Rating tertinggi
4:Terpopuler 30 hari
52:Terpopuler 12 bulan
trending-4:Sedang naik daun 30 hari
trending-52:Sedang naik daun 12 bulan'

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

: > "$TMP/hasil"
PERTAMA=1
printf '%s\n' "$SPANS" | while IFS=: read -r span nama; do
  [ -n "$span" ] || continue
  [ "$PERTAMA" = 1 ] || sleep "$JEDA"
  PERTAMA=0
  echo "  ambil dataspan=$span ($nama)" >&2
  if ! curl -sS --fail --compressed -A "$UA" --max-time 60 \
        "https://distrowatch.com/index.php?dataspan=$span" -o "$TMP/p.html"; then
    echo "  ! gagal mengambil $span - dilewati" >&2
    continue
  fi
  # Kalau struktur halaman berubah, parser keluar dengan galat dan kategori ini
  # dilewati - lebih baik kehilangan satu kategori daripada menulis berkas rusak.
  if python3 "$PARSER" parse "$TMP/p.html" "$nama" >> "$TMP/hasil" 2>/dev/null; then
    echo "  ok" >&2
  else
    echo "  ! struktur halaman $span tidak dikenali - dilewati" >&2
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
