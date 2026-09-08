#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Ubah halaman peringkat DistroWatch jadi daftar yang dibaca ZWARTOS.

  dw-rank.py parse   <berkas.html> <kategori>   halaman index.php?dataspan=…
  dw-rank.py ranking <berkas.html> <kategori>   halaman dwres.php?resource=ranking
  dw-rank.py slugs   <berkas.html>              daftar semua distro + slug

Keluaran per baris, dipisah TAB:
    kategori  peringkat  slug  nama  nilai

DUA HALAMAN, DUA BENTUK:

* `index.php?dataspan=…` memakai tabel `phr1/phr2/phr3` — dipakai untuk
  peringkat kunjungan (30 hari, 12 bulan) dan tren. Nilai `score` di situ
  adalah **Most Ratings** (urut BANYAKNYA penilaian), bukan rata-rata:
  sudah dicocokkan baris demi baris dengan layar "Most Ratings" milik pemilik.
* `dwres.php?resource=ranking&sort=average` memakai tabel berbeda — tiap baris
  memuat `<a href="slug">Nama</a>` dan tautan `resource=ratings&distro=slug`
  berisi nilai rata-ratanya. Ini satu-satunya sumber "Average Rating".

JEBAKAN: halaman yang disimpan lewat Ctrl+S di browser TIDAK sama dengan yang
dikirim server — spasi dirapikan dan tautan relatif diubah jadi absolut
(`href="mint"` menjadi `href="https://distrowatch.com/mint"`). Semua pola di
bawah karena itu sengaja longgar terhadap kedua bentuk.
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

TR = re.compile(r'<tr[^>]*>(.*?)</tr>', re.S)
LINK_DISTRO = re.compile(r'<a[^>]*href="(?:https?://(?:www\.)?distrowatch\.com/)?([a-z0-9][a-z0-9._-]*)"[^>]*>([^<]+)</a>')
NILAI_RATING = re.compile(r'resource=ratings(?:&amp;|&)distro=[a-z0-9._-]+"[^>]*>\s*([0-9.]+)\s*<')
SEL_ANGKA = re.compile(r'<td[^>]*>\s*([0-9]+)\s*</td>', re.S)

OPT = re.compile(r'<option value="([a-z0-9][a-z0-9._-]*)">([^<]+)</option>')
BUKAN_SLUG = re.compile(r'^(\d+|score|trending-\d+|votes|average)$')
TAG = re.compile(r'<[^>]+>')


def baca(path):
    return io.open(path, encoding="utf-8", errors="replace").read()


def bersih(teks):
    teks = TAG.sub("", teks)
    for ent, ch in (("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
                    ("&quot;", '"'), ("&#39;", "'"), ("&nbsp;", " ")):
        teks = teks.replace(ent, ch)
    return " ".join(teks.split())


def slug_dari(href):
    href = re.sub(r'^https?://(www\.)?distrowatch\.com/', "", href.strip())
    return href.strip("/").split("?")[0].split("#")[0]


def parse(path, kategori):
    baris = []
    for rank, href, nama, nilai in ROW.findall(baca(path)):
        slug, nama = slug_dari(href), bersih(nama)
        if slug and nama:
            baris.append("%s\t%s\t%s\t%s\t%s" % (
                kategori, rank, slug, nama, bersih(nilai) or "-"))
    return baris


def ranking(path, kategori):
    """Halaman dwres.php?resource=ranking (Most Ratings / Average Rating).

    Nomor peringkat tidak selalu ada di markup-nya, jadi dipakai urutan baris -
    itu memang arti peringkat di halaman tersebut.
    """
    baris, n = [], 0
    for isi in TR.findall(baca(path)):
        if "resource=ratings" not in isi:
            continue
        m = LINK_DISTRO.search(isi)
        if not m:
            continue
        slug, nama = m.group(1), bersih(m.group(2))
        if not slug or not nama or slug in ("dwres.php", "index.php"):
            continue
        v = NILAI_RATING.search(isi)
        nilai = v.group(1) if v else ""
        if not nilai:
            angka = SEL_ANGKA.findall(isi)
            nilai = angka[-1] if angka else "-"
        n += 1
        baris.append("%s\t%d\t%s\t%s\t%s" % (kategori, n, slug, nama, nilai))
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
    if perintah in ("parse", "ranking"):
        if len(sys.argv) < 4:
            sys.exit("butuh nama kategori")
        hasil = (parse if perintah == "parse" else ranking)(path, sys.argv[3])
    elif perintah == "slugs":
        hasil = slugs(path)
    else:
        sys.exit("perintah tidak dikenal: %s" % perintah)
    if not hasil:
        sys.exit("TIDAK ADA yang terbaca dari %s - struktur halaman berubah?" % path)
    sys.stdout.write("\n".join(hasil) + "\n")


if __name__ == "__main__":
    main()
