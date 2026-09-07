# ZWARTOS

Unduh ISO sistem operasi langsung ke flashdisk **Ventoy** lewat **WiFi**/LAN — pilih OS, ambil versi terbaru, reboot, boot. Satu flashdisk, banyak OS, tanpa menyiapkan ISO dari awal.

Daftar OS ada di **[`zwartos-oslist.txt`](zwartos-oslist.txt)** dan ditarik otomatis oleh ISO ZWARTOS tiap online.

<!-- STATUS:START -->
**Diperiksa robot:** 2026-09-07 08:28 UTC — ✅ Aktif: **123** · ⚠️ Diragukan: **1** · ❌ Rusak: **0** · Total: **124**
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

| Distro | Varian / Versi | Status | Tipe |
|---|---|:---:|:---:|
| Ubuntu | Desktop / 26.04 LTS (~6.0GB) | ✅ | auto |
| Ubuntu | Desktop / 24.04 LTS (~6.2GB) | ✅ | auto |
| Ubuntu | Desktop / 22.04 LTS (~4.4GB) | ✅ | auto |
| Kubuntu | 26.04 (~4.7GB) | ✅ | auto |
| Kubuntu | 24.04 LTS (~4.6GB) | ✅ | auto |
| Xubuntu | 26.04 (~4.8GB) | ✅ | auto |
| Xubuntu | 24.04 LTS (~4.3GB) | ✅ | auto |
| Lubuntu | 26.04 (~3.7GB) | ✅ | auto |
| Lubuntu | 24.04 LTS (~3.3GB) | ✅ | auto |
| Ubuntu MATE | 24.04 LTS (~4.2GB) | ✅ | auto |
| Ubuntu Budgie | 26.04 (~3.8GB) | ✅ | auto |
| Ubuntu Cinnamon | 26.04 (~5.3GB) | ✅ | auto |
| Ubuntu Unity | 26.04 (~3.9GB) | ✅ | auto |
| Ubuntu Kylin | 26.04 (~5.3GB) | ✅ | auto |
| Ubuntu Studio | 26.04 (~5.0GB) | ✅ | auto |
| Edubuntu | 26.04 (~7.4GB) | ✅ | auto |
| Linux Mint | Cinnamon / 22.3 (~2.9GB) | ✅ | auto |
| Linux Mint | Cinnamon / 21.3 (~2.9GB) | ✅ | auto |
| Linux Mint | MATE / 22.3 (~2.9GB) | ✅ | auto |
| Linux Mint | Xfce / 22.3 (~2.8GB) | ✅ | auto |
| LMDE | Cinnamon (~2.9GB) | ✅ | auto |
| Fedora | Workstation GNOME / 44 (~2.7GB) | ✅ | auto |
| Fedora | Workstation GNOME / 43 (~2.6GB) | ✅ | auto |
| Fedora | KDE Plasma / 44 (~2.7GB) | ✅ | auto |
| Fedora | Xfce / 44 (~2.7GB) | ✅ | auto |
| Fedora | Cinnamon / 44 (~3.0GB) | ✅ | auto |
| Fedora | MATE / 44 (~3.0GB) | ✅ | auto |
| Fedora | LXQt / 44 (~2.3GB) | ✅ | auto |
| Fedora | i3 / 44 (~2.3GB) | ✅ | auto |
| Fedora | Budgie / 44 (~2.6GB) | ✅ | auto |
| Fedora | Sway / 44 (~2.4GB) | ✅ | auto |
| Debian | Live GNOME / terbaru (~3.5GB) | ✅ | auto |
| Debian | Live KDE / terbaru (~3.9GB) | ✅ | auto |
| Debian | Live Xfce / terbaru (~3.6GB) | ✅ | auto |
| Debian | Live Cinnamon / terbaru (~3.8GB) | ✅ | auto |
| Debian | Live MATE / terbaru (~3.7GB) | ✅ | auto |
| Debian | Live LXQt / terbaru (~3.7GB) | ✅ | auto |
| Debian | Live standard / terbaru (~1.5GB) | ✅ | auto |
| openSUSE | Tumbleweed DVD (~4.2GB) | ✅ | link |
| openSUSE | Leap 15.6 DVD (~4.3GB) | ✅ | auto |
| Manjaro | KDE Plasma (~4.2GB) | ✅ | link |
| Manjaro | GNOME (~4.0GB) | ✅ | link |
| Manjaro | Xfce (~3.7GB) | ✅ | link |
| Pop!_OS | 22.04 LTS (~2.8GB) | ✅ | link |
| Zorin OS | Core 17 (~3.5GB) | ✅ | auto |
| elementary OS | 8 (~3.0GB) | ✅ | link |
| Garuda | Dragonized (~3.3GB) | ✅ | link |
| Garuda | GNOME (~3.2GB) | ✅ | link |
| Garuda | Xfce (~2.9GB) | ✅ | link |
| Garuda | KDE Lite (~2.4GB) | ✅ | link |
| EndeavourOS | ISO terbaru (~3.6GB) | ✅ | auto |
| CachyOS | Desktop (~3.0GB) | ✅ | link |
| MX Linux | Xfce (~2.1GB) | ✅ | auto |
| MX Linux | KDE (~2.6GB) | ✅ | auto |
| Q4OS | Plasma (~2.5GB) | ✅ | link |
| Linux Lite | terbaru (~2.2GB) | ✅ | link |
| SparkyLinux | Xfce (~2.0GB) | ✅ | link |
| Bodhi Linux | AppPack (~2.7GB) | ✅ | link |
| Nitrux | terbaru (~3.5GB) | ✅ | link |

### SERVER / ENTERPRISE

| Distro | Varian / Versi | Status | Tipe |
|---|---|:---:|:---:|
| Ubuntu | Server / 26.04 LTS (~2.7GB) | ✅ | auto |
| Ubuntu | Server / 24.04 LTS (~3.2GB) | ✅ | auto |
| Ubuntu | Server / 22.04 LTS (~2.0GB) | ✅ | auto |
| Debian | netinst / terbaru (~755MB) | ✅ | auto |
| Debian | netinst / 12 (~670MB) | ✅ | auto |
| Debian | DVD-1 / terbaru (~3.7GB) | ✅ | auto |
| Fedora | Server / 44 (~3.6GB) | ✅ | auto |
| Fedora | Everything netinst / 44 (~700MB) | ✅ | auto |
| AlmaLinux | minimal / 10 (~1.5GB) | ✅ | link |
| AlmaLinux | minimal / 9 (~2.6GB) | ✅ | link |
| AlmaLinux | minimal / 8 (~2.0GB) | ✅ | link |
| AlmaLinux | DVD / 9 (~11GB) | ✅ | link |
| Rocky Linux | minimal / 10 (~1.9GB) | ✅ | auto |
| Rocky Linux | minimal / 9 (~2.6GB) | ✅ | auto |
| Rocky Linux | minimal / 8 (~3.1GB) | ✅ | auto |
| CentOS Stream | boot / 10 (~892MB) | ✅ | auto |
| CentOS Stream | boot / 9 (~1.5GB) | ✅ | auto |
| Oracle Linux | 9 (~1.0GB) | ✅ | link |
| Oracle Linux | 8 (~1.0GB) | ✅ | link |
| openEuler | 24.03 LTS (~3.9GB) | ✅ | auto |
| Proxmox VE | ISO terbaru (~1.6GB) | ✅ | auto |
| Proxmox Backup Server | terbaru (~1.2GB) | ✅ | auto |
| Proxmox Mail Gateway | terbaru (~1.2GB) | ✅ | auto |
| XCP-ng | 8.3 (~900MB) | ✅ | auto |

### RINGAN / ADVANCED / BSD

| Distro | Varian / Versi | Status | Tipe |
|---|---|:---:|:---:|
| Arch Linux | ISO terbaru (~1.5GB) | ✅ | link |
| Alpine | Standard (~352MB) | ✅ | auto |
| Alpine | Extended (~1.4GB) | ✅ | auto |
| Alpine | Virt (~180MB) | ✅ | auto |
| Void Linux | Xfce glibc (~1.3GB) | ✅ | auto |
| Void Linux | Xfce musl (~1.3GB) | ✅ | auto |
| Void Linux | base (~700MB) | ✅ | auto |
| Devuan | Live Desktop (~1.4GB) | ✅ | auto |
| Devuan | netinstall (~450MB) | ✅ | auto |
| Gentoo | minimal install (~1.4GB) | ✅ | auto |
| Gentoo | LiveGUI (~4.5GB) | ✅ | auto |
| NixOS | minimal (~1.6GB) | ✅ | link |
| antiX | full (~1.7GB) | ✅ | link |
| Tiny Core | CorePlus (~250MB) | ✅ | auto |
| Slackware | 15.0 (~3.8GB) | ✅ | link |
| FreeBSD | disc1 / 14.3 (~1.2GB) | ✅ | auto |
| FreeBSD | bootonly / 14.3 (~430MB) | ✅ | auto |
| OpenBSD | install (~800MB) | ✅ | link |
| NetBSD | 10 (~500MB) | ✅ | link |
| GhostBSD | MATE (~2.9GB) | ✅ | auto |
| GhostBSD | Xfce (~2.9GB) | ✅ | auto |

### SECURITY / PRIVACY

| Distro | Varian / Versi | Status | Tipe |
|---|---|:---:|:---:|
| Kali Linux | Installer (~4.5GB) | ✅ | auto |
| Kali Linux | Purple (~4.7GB) | ✅ | auto |
| Kali Linux | netinst (~600MB) | ✅ | auto |
| BlackArch | netinstall (~800MB) | ✅ | auto |
| Tails | ISO terbaru (~1.7GB) | ✅ | link |
| Qubes OS | 4.2 (~6.5GB) | ✅ | auto |

### UTILITAS / RESCUE

| Distro | Varian / Versi | Status | Tipe |
|---|---|:---:|:---:|
| Clonezilla | Live (~546MB) | ✅ | auto |
| SystemRescue | 13.02 (~950MB) | ✅ | link |
| GParted Live | terbaru (~500MB) | ✅ | link |
| Rescuezilla | 2.6.2 (~1.5GB) | ✅ | link |
| Grml | full (~800MB) | ✅ | auto |
| Grml | small (~400MB) | ✅ | auto |
| Kaspersky Rescue | krd (~677MB) | ✅ | link |
| ShredOS | wipe (~394MB) | ✅ | link |
| Redo Rescue | terbaru (~700MB) | ✅ | link |

### WINDOWS & LAINNYA

| Distro | Varian / Versi | Status | Tipe |
|---|---|:---:|:---:|
| Windows Server | 2025 Evaluation (~5.6GB) | ✅ | link |
| Windows Server | 2022 Evaluation (~4.7GB) | ✅ | link |
| Hirens BootCD PE | berbasis Windows (~3.1GB) | ⚠️ | link |
| ChromeOS Flex | recovery .bin.zip (~1.2GB) | ✅ | link |
| netboot.xyz | boot ~100 OS lewat jaringan (~2MB) | ✅ | link |
<!-- OSLIST:END -->
