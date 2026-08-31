# ZWARTOS

Unduh ISO sistem operasi langsung ke flashdisk **Ventoy** lewat **WiFi**/LAN — pilih OS, ambil versi terbaru, reboot, boot. Satu flashdisk, banyak OS, tanpa menyiapkan ISO dari awal.

Daftar OS ada di **[`zwartos-oslist.txt`](zwartos-oslist.txt)** dan ditarik otomatis oleh ISO ZWARTOS tiap online.

<!-- STATUS:START -->
**Diperiksa robot:** 2026-08-31 09:52 UTC — ✅ Aktif: **64** · ⚠️ Diragukan: **1** · ❌ Rusak: **0** · Total: **65**
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

### DESKTOP POPULER

| OS | Status | Tipe |
|---|:---:|:---:|
| Ubuntu Desktop (~6.0GB) | ✅ | auto |
| Kubuntu (~4.7GB) | ✅ | auto |
| Xubuntu (~4.8GB) | ✅ | auto |
| Lubuntu (~3.7GB) | ✅ | auto |
| Ubuntu Budgie (~3.8GB) | ✅ | auto |
| Ubuntu Cinnamon (~5.3GB) | ✅ | auto |
| Ubuntu Unity (~3.9GB) | ✅ | auto |
| Ubuntu Kylin (~5.3GB) | ✅ | auto |
| Edubuntu (~7.4GB) | ✅ | auto |
| Linux Mint Cinnamon (~2.9GB) | ✅ | auto |
| Linux Mint MATE (~2.9GB) | ✅ | auto |
| Linux Mint Xfce (~2.8GB) | ✅ | auto |
| Fedora Workstation (~2.7GB) | ✅ | auto |
| Fedora KDE (~2.7GB) | ✅ | auto |
| Fedora Xfce (~2.7GB) | ✅ | auto |
| Fedora Cinnamon (~3.0GB) | ✅ | auto |
| Fedora MATE (~3.0GB) | ✅ | auto |
| Fedora LXQt (~2.3GB) | ✅ | auto |
| Fedora i3 (~2.3GB) | ✅ | auto |
| Debian Live GNOME (~3.5GB) | ✅ | auto |
| Debian Live KDE (~3.9GB) | ✅ | auto |
| Debian Live Xfce (~3.6GB) | ✅ | auto |
| Debian Live Cinnamon (~3.8GB) | ✅ | auto |
| Debian Live MATE (~3.7GB) | ✅ | auto |
| Debian Live LXQt (~3.7GB) | ✅ | auto |
| openSUSE Tumbleweed (~4.2GB) | ✅ | link |
| EndeavourOS (~3.6GB) | ✅ | auto |
| CachyOS (~3.0GB) | ✅ | link |
| Ubuntu 24.04 Desktop LTS (~6.2GB) | ✅ | auto |
| Ubuntu 22.04 Desktop LTS (~4.4GB) | ✅ | auto |
| Ubuntu MATE 24.04 (~4.2GB) | ✅ | auto |
| Linux Mint 21 Cinnamon (~2.9GB) | ✅ | auto |
| Fedora 43 Workstation (~2.6GB) | ✅ | auto |
| Garuda Dragonized (~3.3GB) | ✅ | link |

### SERVER / ENTERPRISE

| OS | Status | Tipe |
|---|:---:|:---:|
| Ubuntu Server (~2.7GB) | ✅ | auto |
| Debian netinst (~755MB) | ✅ | auto |
| Fedora Server (~3.6GB) | ✅ | auto |
| AlmaLinux 9 minimal (~2.6GB) | ✅ | link |
| AlmaLinux 10 minimal (~1.5GB) | ✅ | link |
| Rocky Linux 9 minimal (~2.6GB) | ✅ | auto |
| Rocky Linux 10 minimal (~1.9GB) | ✅ | auto |
| CentOS Stream 9 boot (~1.5GB) | ✅ | auto |
| CentOS Stream 10 boot (~892MB) | ✅ | auto |
| openSUSE Leap 15.6 (~4.3GB) | ✅ | auto |
| openEuler 24.03 LTS (~3.9GB) | ✅ | auto |
| Proxmox VE (~1.6GB) | ✅ | auto |
| Ubuntu 24.04 Server LTS (~3.2GB) | ✅ | auto |
| Debian 12 netinst (~670MB) | ✅ | auto |
| AlmaLinux 8 minimal (~2.0GB) | ✅ | link |
| Rocky Linux 8 minimal (~3.1GB) | ✅ | auto |

### RINGAN / ADVANCED / BSD

| OS | Status | Tipe |
|---|:---:|:---:|
| Arch Linux (~1.5GB) | ✅ | link |
| Alpine Standard (~352MB) | ✅ | auto |
| Alpine Extended (~1.4GB) | ✅ | auto |
| Void Linux Xfce (~1.3GB) | ✅ | auto |
| Devuan Live (~1.4GB) | ✅ | auto |
| Gentoo minimal (~1.4GB) | ✅ | auto |
| NixOS minimal (~1.6GB) | ✅ | link |
| FreeBSD 14 disc1 (~1.2GB) | ✅ | auto |
| OpenBSD (~800MB) | ✅ | link |
| Void Linux musl Xfce (~1.3GB) | ✅ | auto |

### SECURITY / PRIVACY

| OS | Status | Tipe |
|---|:---:|:---:|
| Kali Installer (~4.5GB) | ✅ | auto |
| Tails (~1.7GB) | ✅ | link |

### UTILITAS / RESCUE

| OS | Status | Tipe |
|---|:---:|:---:|
| Clonezilla Live (~546MB) | ✅ | auto |
| Kaspersky Rescue (~677MB) | ⚠️ | link |
| ShredOS wipe (~394MB) | ✅ | link |
<!-- OSLIST:END -->
