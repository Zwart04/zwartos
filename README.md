# ZWARTOS

Unduh ISO sistem operasi langsung ke flashdisk **Ventoy** lewat **WiFi**/LAN — pilih OS, ambil versi terbaru, reboot, boot. Satu flashdisk, banyak OS, tanpa menyiapkan ISO dari awal.

Daftar OS ada di **[`zwartos-oslist.txt`](zwartos-oslist.txt)** dan ditarik otomatis oleh ISO ZWARTOS tiap online.

<!-- STATUS:START -->
_(status diisi robot saat pertama jalan)_
<!-- STATUS:END -->

## Cara pakai
1. Salin `zwartos.iso` ke flashdisk Ventoy.
2. Boot flashdisk → pilih **ZWARTOS** → tekan `w` untuk sambungkan WiFi.
3. Ketik **nomor OS** → versi terbaru terunduh ke flashdisk → tekan `x` reboot → pilih ISO baru di menu Ventoy.

## Menambah / memperbaiki OS
Edit [`zwartos-oslist.txt`](zwartos-oslist.txt). Dua format baris:
- `Nama | https://folder/ | pola-nama-file` — **auto**: cari versi terbaru sendiri.
- `Nama | https://link-langsung.iso` — **link tetap**.

Simpan → semua flashdisk ZWARTOS ikut terbaru saat online berikutnya.

## Robot (GitHub Action)
Terjadwal tiap minggu (+ tombol **Run workflow** manual). Dua tugasnya:
1. **Cari versi baru** — entri berversi (OpenBSD, Tails, CachyOS, ShredOS) di-update ke rilis terbaru otomatis.
2. **Perbarui README** — status tiap OS (aktif/diragukan/rusak) & jumlahnya, di bagian bertanda di bawah.

Robot **hanya memperbarui** blok status & daftar OS; bagian lain di atas aman diedit manual.

## Daftar OS

Legenda: ✅ aktif · ⚠️ diragukan (mungkin blokir bot/CI; biasanya tetap bisa dari laptop) · ❌ rusak

<!-- OSLIST:START -->
_(daftar diisi robot saat pertama jalan)_
<!-- OSLIST:END -->
