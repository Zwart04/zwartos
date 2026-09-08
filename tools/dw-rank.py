#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Ubah halaman peringkat DistroWatch jadi daftar yang dibaca ZWARTOS.

Dipakai dua arah:
  dw-rank.py parse <berkas.html> <kategori>   -> baris peringkat ke stdout
  dw-rank.py slugs <berkas.html>              -> daftar semua distro + slug

Struktur yang dibaca (sudah diverifikasi pada halaman asli yang disimpan
pemilik, 8 Sep 2026):

    <th class="phr1">1 </th>
    <td class="phr2"><a href="https://distrowatch.com/mint">Linux Mint</a></td>
    <td class="phr3">8.87</td>

Kolom phr3 berisi rating (mode "Average Rating") atau jumlah kunjungan
(mode peringkat harian) - keduanya disimpan apa adanya sebagai "nilai".

Keluaran per baris, dipisah TAB:
    kategori  peringkat  slug  nama  nilai
"""
import io
import re
import sys

ROW = re.compile(
    r'<th class="phr1">\s*(\d+)\s*</th>\s*'
    r'<td class="phr2">\s*<a href="https://distrowatch\.com/([^"]+)">([^<]+)</a>\s*</td>\s*'
    r'<td class="phr3">\s*([^<]*?)\s*</td>'
)

# Dropdown distro di halaman DistroWatch: <option value="mint">Linux Mint</option>.
# Slug boleh diawali angka - ada "3cx" dan "4mlinux" - jadi jangan mensyaratkan
# huruf di depan.
OPT = re.compile(r'<option value="([a-z0-9][a-z0-9._-]*)">([^<]+)</option>')

# Nilai dataspan memakai <select> yang sama bentuknya: angka murni (tahun,
# "52", "4"), "score", dan "trending-N". Semuanya harus dibuang, tapi angka
# murni saja - "3cx" dan "4mlinux" tetap lolos.
BUKAN_SLUG = re.compile(r'^(\d+|score|trending-\d+)$')


def baca(path):
    return io.open(path, encoding="utf-8", errors="replace").read()


def bersih(teks):
    """DistroWatch memakai entitas HTML pada beberapa nama distro."""
    for ent, ch in (
        ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
        ("&quot;", '"'), ("&#39;", "'"), ("&nbsp;", " "),
    ):
        teks = teks.replace(ent, ch)
    return teks.strip()


def parse(path, kategori):
    baris = []
    for rank, slug, nama, nilai in ROW.findall(baca(path)):
        baris.append("%s\t%s\t%s\t%s\t%s" % (
            kategori, rank, slug, bersih(nama), bersih(nilai) or "-"))
    return baris


def slugs(path):
    keluar, seen = [], set()
    for slug, nama in OPT.findall(baca(path)):
        if BUKAN_SLUG.match(slug) or slug in seen:
            continue
        seen.add(slug)
        keluar.append("%s\t%s" % (slug, bersih(nama)))
    return keluar


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    perintah, path = sys.argv[1], sys.argv[2]
    if perintah == "parse":
        if len(sys.argv) < 4:
            sys.exit("butuh nama kategori")
        hasil = parse(path, sys.argv[3])
    elif perintah == "slugs":
        hasil = slugs(path)
    else:
        sys.exit("perintah tidak dikenal: %s" % perintah)
    if not hasil:
        sys.exit("TIDAK ADA yang terbaca dari %s - struktur halaman berubah?" % path)
    sys.stdout.write("\n".join(hasil) + "\n")


if __name__ == "__main__":
    main()
