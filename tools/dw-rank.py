#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Ubah halaman peringkat DistroWatch jadi daftar yang dibaca ZWARTOS.

Dipakai dua arah:
  dw-rank.py parse <berkas.html> <kategori>   -> baris peringkat ke stdout
  dw-rank.py slugs <berkas.html>              -> daftar semua distro + slug

Keluaran per baris, dipisah TAB:
    kategori  peringkat  slug  nama  nilai

JEBAKAN yang sudah memakan satu putaran: halaman yang disimpan lewat Ctrl+S
di browser TIDAK sama dengan yang dikirim server. Browser merapikan spasi dan
**mengubah tautan relatif jadi absolut** - `href="mint"` menjadi
`href="https://distrowatch.com/mint"`. Pola di bawah karena itu sengaja
longgar: menerima kedua bentuk href, tidak peduli spasi antar-tag, dan tidak
mengunci `th` atau `td`.
"""
import io
import re
import sys

ROW = re.compile(
    r'<t[hd][^>]*class="phr1"[^>]*>\s*(\d+)[^<]*</t[hd]>\s*'
    r'<t[hd][^>]*class="phr2"[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>\s*</t[hd]>\s*'
    r'<t[hd][^>]*class="phr3"[^>]*>\s*(.*?)\s*</t[hd]>',
    re.S,
)

# Dropdown distro: <option value="mint">Linux Mint</option>. Slug boleh diawali
# angka - ada "3cx" dan "4mlinux" - jadi jangan mensyaratkan huruf di depan.
OPT = re.compile(r'<option value="([a-z0-9][a-z0-9._-]*)">([^<]+)</option>')

# Nilai dataspan memakai <select> yang bentuknya sama: angka murni (tahun,
# "52", "4"), "score", dan "trending-N". Semuanya dibuang - tapi angka murni
# saja, supaya "3cx" dan "4mlinux" tetap lolos.
BUKAN_SLUG = re.compile(r'^(\d+|score|trending-\d+)$')

TAG = re.compile(r'<[^>]+>')


def baca(path):
    return io.open(path, encoding="utf-8", errors="replace").read()


def bersih(teks):
    """Buang tag sisa dan pulihkan entitas HTML pada nama distro."""
    teks = TAG.sub("", teks)
    for ent, ch in (
        ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
        ("&quot;", '"'), ("&#39;", "'"), ("&nbsp;", " "),
    ):
        teks = teks.replace(ent, ch)
    return " ".join(teks.split())


def slug_dari(href):
    """'https://distrowatch.com/mint', '/mint', 'mint' -> 'mint'."""
    href = href.strip()
    href = re.sub(r'^https?://(www\.)?distrowatch\.com/', "", href)
    return href.strip("/").split("?")[0].split("#")[0]


def parse(path, kategori):
    baris = []
    for rank, href, nama, nilai in ROW.findall(baca(path)):
        slug = slug_dari(href)
        nama = bersih(nama)
        if not slug or not nama:
            continue
        baris.append("%s\t%s\t%s\t%s\t%s" % (
            kategori, rank, slug, nama, bersih(nilai) or "-"))
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
