#!/bin/sh
# ============================================================
#  ZWARTOS  -  unduh ISO sistem operasi ke flashdisk Ventoy
#  lewat WiFi / LAN.  Tiny Core (busybox ash) + fzf.
#
#  Daftar OS diambil berurutan dari:
#    1. online  -> repo GitHub (selalu terbaru)
#    2. file zwartos-oslist.txt di flashdisk (opsional)
#    3. daftar bawaan di dalam ISO (dipakai saat offline)
#
#  Format nama entri:  Distro / Varian / Versi
#  -> menu otomatis bertingkat; tingkat berisi 1 pilihan dilewati.
# ============================================================
UA='Mozilla/5.0 (ZWARTOS)'
ESC=$(printf '\033')
R="${ESC}[0m"; B="${ESC}[1m"; DIM="${ESC}[2m"
CY="${ESC}[38;5;44m"; GN="${ESC}[38;5;42m"; YL="${ESC}[38;5;220m"
RD="${ESC}[38;5;203m"; GY="${ESC}[38;5;245m"; WH="${ESC}[1;38;5;255m"
TAB=$(printf '\t')
VENTOY="/mnt/ventoy"
LOCLIST="$VENTOY/zwartos-oslist.txt"
CONF="$VENTOY/zwartos.conf"
BAKED="/usr/local/share/zwartos/oslist.txt"
FONT="/usr/local/share/zwartos/font.psf"
REMOTE_DEFAULT="https://raw.githubusercontent.com/Zwart04/zwartos/main/zwartos-oslist.txt"
RANK_REMOTE_DEFAULT="https://raw.githubusercontent.com/Zwart04/zwartos/main/zwartos-peringkat.txt"
BAKEDRANK="/usr/local/share/zwartos/peringkat.txt"
RANKF="/tmp/zwrank.txt"
VERSION="1.7"; GHREPO="github.com/Zwart04/zwartos"
BUILDDATE=$(cat /usr/local/share/zwartos/builddate 2>/dev/null || echo "?")
ACTIVE="/tmp/zwartos-active.txt"
TMPL="/tmp/zos_index"
REMOTE=""; SRC="?"
# Default negara WiFi (bisa ditimpa di zwartos.conf di flashdisk)
WIFI_COUNTRY="${WIFI_COUNTRY:-ID}"

# busybox tidak selalu mendukung sleep pecahan -> deteksi sekali di awal
if sleep 0.2 2>/dev/null; then TICK="0.2"; else TICK="1"; fi

have(){ command -v "$1" >/dev/null 2>&1; }
cls(){ printf '\033[2J\033[H'; }
curs_off(){ printf '\033[?25l'; }
curs_on(){ printf '\033[?25h'; }
cols(){ c=$(stty size 2>/dev/null | cut -d' ' -f2); [ -z "$c" ] && c=80; printf '%s' "$c"; }
rows(){ r=$(stty size 2>/dev/null | cut -d' ' -f1); [ -z "$r" ] && r=25; printf '%s' "$r"; }
pause(){ printf "\n  ${DIM}tekan Enter untuk kembali…${R}"; read _x; }
ctext(){ _t="$1"; _c="$2"; _w=$(cols); _l=${#_t}; _p=$(((_w-_l)/2)); [ "$_p" -lt 0 ]&&_p=0; printf "%${_p}s%b%s%b\n" "" "$_c" "$_t" "$R"; }
hr(){ _w=$(cols); _i=0; _s=""; while [ $_i -lt $((_w-4)) ]; do _s="$_s-"; _i=$((_i+1)); done; printf "  ${DIM}%s${R}\n" "$_s"; }

# jalankan perintah panjang sambil menampilkan animasi berputar
spin(){
  msg="$1"; shift
  "$@" >/dev/null 2>&1 &
  sp=$!; i=0
  while kill -0 "$sp" 2>/dev/null; do
    case $((i%4)) in 0) f="-";; 1) f="\\";; 2) f="|";; 3) f="/";; esac
    printf "\r  ${DIM}%s %s${R}   " "$f" "$msg"
    i=$((i+1)); sleep "$TICK"
  done
  wait "$sp"; rc=$?
  printf "\r\033[K"
  return $rc
}

# ---- jaringan: status ------------------------------------------------------
NETOK=1; NETTS=-999
netup(){
  # ping saja tidak cukup: banyak jaringan (hotspot, kantor, NAT VM) memblokir
  # ICMP padahal HTTP jalan. Hasil di-cache 15 detik supaya menu tidak tersendat.
  now=$(cut -d' ' -f1 /proc/uptime 2>/dev/null | cut -d. -f1); [ -z "$now" ] && now=0
  [ $((now - NETTS)) -lt 15 ] && return $NETOK
  NETTS=$now
  if ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; then NETOK=0; return 0; fi
  if have curl && curl -sf --connect-timeout 2 --max-time 3 -o /dev/null \
       http://connectivitycheck.gstatic.com/generate_204 2>/dev/null; then NETOK=0; return 0; fi
  NETOK=1; return 1
}

# ---- penyimpanan -----------------------------------------------------------
load_exfat(){ modprobe vfat 2>/dev/null; modprobe exfat 2>/dev/null; modprobe ntfs 2>/dev/null; have mount.exfat-fuse || { have tce-load && tce-load -i fuse-exfat exfat-utils >/dev/null 2>&1; }; return 0; }
mount_ventoy(){
  mountpoint -q "$VENTOY" 2>/dev/null && return 0
  load_exfat
  DEV=$(blkid 2>/dev/null | grep -i 'LABEL="Ventoy"' | head -1 | cut -d: -f1)
  [ -z "$DEV" ] && DEV=$(blkid 2>/dev/null | grep -i 'TYPE="exfat"' | head -1 | cut -d: -f1)
  [ -z "$DEV" ] && return 1
  mkdir -p "$VENTOY"
  mount "$DEV" "$VENTOY" 2>/dev/null && return 0
  mount -t exfat "$DEV" "$VENTOY" 2>/dev/null && return 0
  mount.exfat-fuse "$DEV" "$VENTOY" 2>/dev/null && return 0
  return 1
}
free_kb(){ df -P -k "$VENTOY" 2>/dev/null | awk 'NR==2{print $4}'; }
human(){ # byte -> "1.2 GB"
  b="$1"; [ -z "$b" ] && { printf '?'; return; }
  awk -v b="$b" 'BEGIN{
    if(b>=1073741824) printf "%.1f GB", b/1073741824;
    else if(b>=1048576) printf "%.0f MB", b/1048576;
    else if(b>=1024) printf "%.0f KB", b/1024;
    else printf "%d B", b }'
}
battery(){ # cetak "78% (mengisi)" atau kosong kalau tak ada baterai
  for d in /sys/class/power_supply/BAT*; do
    [ -r "$d/capacity" ] || continue
    c=$(cat "$d/capacity" 2>/dev/null); s=$(cat "$d/status" 2>/dev/null)
    case "$s" in
      Charging)    t="mengisi" ;;
      Full)        t="penuh" ;;
      Discharging) t="pakai baterai" ;;
      *)           t="$s" ;;
    esac
    printf '%s|%s|%s' "$c" "$s" "$t"; return 0
  done
  return 1
}

# ---- daftar OS -------------------------------------------------------------
load_conf(){
  REMOTE="$REMOTE_DEFAULT"
  WIFI_COUNTRY="${WIFI_COUNTRY:-}"
  MIN_FREE_MB="${MIN_FREE_MB:-200}"
  [ -f "$CONF" ] || return 0
  line=$(grep -iE '^[[:space:]]*REMOTE_LIST[[:space:]]*=' "$CONF" 2>/dev/null | head -1)
  # JEBAKAN: dulu di sini ada '[ -z "$line" ] && return 0', yang membuat
  # SELURUH sisa berkas conf diabaikan kalau REMOTE_LIST kebetulan tidak
  # ditulis - MIN_FREE_MB dan WIFI_COUNTRY tidak pernah terbaca, padahal
  # layar bantuan 5 GHz menyuruh pemakai menulis WIFI_COUNTRY saja.
  if [ -n "$line" ]; then
    v=${line#*=}
    v=$(printf '%s' "$v" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/\r//g; s/^"//; s/"$//')
    [ -n "$v" ] && REMOTE="$v"
  fi
  # Cadangan ruang flashdisk dalam MB. Contoh: MIN_FREE_MB=500
  m=$(grep -iE '^[[:space:]]*MIN_FREE_MB[[:space:]]*=' "$CONF" 2>/dev/null | head -1)
  if [ -n "$m" ]; then
    m=${m#*=}
    m=$(printf '%s' "$m" | sed 's/[^0-9]//g')
    [ -n "$m" ] && MIN_FREE_MB="$m"
  fi

  # Kode negara untuk 5 GHz (lihat wifi_reg_hint). Contoh: WIFI_COUNTRY=ID
  c=$(grep -iE '^[[:space:]]*WIFI_COUNTRY[[:space:]]*=' "$CONF" 2>/dev/null | head -1)
  if [ -n "$c" ]; then
    w=${c#*=}
    w=$(printf '%s' "$w" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/\r//g; s/^"//; s/"$//')
    [ -n "$w" ] && WIFI_COUNTRY="$w"
  fi
}
fetch_remote(){
  rm -f /tmp/zwremote
  [ -n "$REMOTE" ] && have curl || return 1
  curl -A "$UA" -fsSL --connect-timeout 4 --max-time 10 "$REMOTE" -o /tmp/zwremote 2>/dev/null \
    || curl -A "$UA" -fsSL -k --connect-timeout 4 --max-time 10 "$REMOTE" -o /tmp/zwremote 2>/dev/null
}
refresh_list(){
  SRC="?"
  fetch_remote
  if [ -s /tmp/zwremote ] && grep -q '|' /tmp/zwremote 2>/dev/null; then
    cat /tmp/zwremote > "$ACTIVE"; SRC="online (GitHub)"
  elif [ -f "$LOCLIST" ]; then
    cat "$LOCLIST" > "$ACTIVE"; SRC="flashdisk"
  elif [ -f "$BAKED" ]; then
    cat "$BAKED" > "$ACTIVE"; SRC="bawaan ISO"
  fi
  fetch_rank
  build_index
  printf '%s' "$SRC" > /tmp/zwsrc      # spin() menjalankan ini di subshell
}
# pembungkus: animasi + ambil kembali SRC yang ditulis subshell
refresh_ui(){
  spin "menyegarkan daftar OS…" refresh_list
  [ -s /tmp/zwsrc ] && SRC=$(cat /tmp/zwsrc)
}

# index: distro \t sub \t versi \t url \t regex \t kategori \t nama-lengkap
# ---- peringkat DistroWatch (dari bot GitHub) -------------------------------------------------
# Berkas: kategori<TAB>peringkat<TAB>slug<TAB>nama<TAB>nilai
# Dipakai saat MULAI: tidak menyentuh jaringan sama sekali. Saat boot biasanya
# belum ada koneksi, dan curl yang menunggu 10 detik = 10 detik layar hitam
# sebelum splash. Cukup pakai salinan terakhir / bawaan ISO.
rank_local(){
  [ -s "$RANKF" ] && return 0
  [ -f "$BAKEDRANK" ] && cp -f "$BAKEDRANK" "$RANKF"
  return 0
}

# Dipakai HANYA sesudah jaringan hidup (dipanggil dari refresh_list).
fetch_rank(){
  rank_local
  netup || return 0
  RR="${RANK_REMOTE:-$RANK_REMOTE_DEFAULT}"
  have curl && [ -n "$RR" ] || return 0
  curl -A "$UA" -fsSL --connect-timeout 4 --max-time 10 "$RR" -o /tmp/zwrank.new 2>/dev/null
  if [ -s /tmp/zwrank.new ] && grep -q "$TAB" /tmp/zwrank.new 2>/dev/null; then
    mv -f /tmp/zwrank.new "$RANKF"
  fi
  rm -f /tmp/zwrank.new
  return 0
}

have_rank(){ [ -s "$RANKF" ]; }

# Cocokkan nama DistroWatch dengan distro yang punya link unduh.
# Namanya sering beda ekor: "Manjaro Linux" vs "Manjaro", "Devuan GNU+Linux"
# vs "Devuan", "Void" vs "Void Linux". Jadi setelah dinormalkan (huruf kecil,
# tanpa tanda baca) dua nama dianggap sama kalau salah satunya awalan yang lain.
fzf_populer(){
  if ! have_rank; then
    header "Distro populer"
    printf "  ${YL}Daftar peringkat belum ada.${R}\n\n"
    printf "  ${DIM}Sambungkan ke internet lalu pilih \"Segarkan daftar OS\".${R}\n"
    pause; return
  fi
  while :; do
    KAT=$(awk -F'\t' '!/^#/ && NF>=5 && !seen[$1]++ {
            printf "%s\t   %s\n", $1, $1 }' "$RANKF" \
          | fzf --ansi --delimiter="$TAB" --with-nth=2 $FZFOPTS \
                --prompt='peringkat · cari: ' \
                --header="Peringkat DistroWatch   ·   Esc kembali" --color="$FZFCLR" 2>/dev/null)
    [ -z "$KAT" ] && return
    K=$(printf '%s' "$KAT" | cut -f1)
    fzf_rank_list "$K"
  done
}

fzf_rank_list(){
  K="$1"
  while :; do
    # SATU awk untuk seluruh layar: baca dulu distro yang punya link unduh
    # (TMPL), lalu susun barisnya. Versi lama memanggil satu awk per baris -
    # 100 proses awk untuk satu layar di mesin yang lambat.
    awk -F'\t' -v k="$K" -v R="$R" -v YL="$YL" -v CY="$CY" -v GN="$GN" -v DIM="$DIM" '
      function norm(x){ x=tolower(x); gsub(/[^a-z0-9]/,"",x); return x }
      function kata(x){ x=tolower(x); gsub(/[^a-z0-9]+/," ",x); return " " x " " }
      function generik(x){ return x=="linux" || x=="gnulinux" || x=="os" || x=="gnu" \
                               || x=="project" || x=="desktop" || x=="edition" || x=="" }
      function cari(w,  i,n,m,best,bl){
        for(i=1;i<=nd;i++) if(norm(d[i])==norm(w)) return d[i]
        best=""; bl=999
        for(i=1;i<=nd;i++){ n=norm(d[i]); m=norm(w)
          if(n=="") continue
          # nama kita lebih panjang -> terima (cuma itu yang kita punya)
          if(index(n,m)==1 && length(n)<bl){ bl=length(n); best=d[i]; continue }
          # nama DistroWatch lebih panjang -> hanya kalau sisanya ekor generik,
          # supaya "Ubuntu Sway" TIDAK jatuh ke "Ubuntu"
          if(index(m,n)==1 && generik(substr(m,length(n)+1)) && length(n)<bl){ bl=length(n); best=d[i] } }
        if(best!="") return best
        bl=999
        for(i=1;i<=nd;i++) if(index(kata(d[i]), kata(w))>0 && length(d[i])<bl){ bl=length(d[i]); best=d[i] }
        return best
      }
      NR==FNR { if(!($1 in seen)){ seen[$1]=1; d[++nd]=$1 } next }
      /^#/ { next }
      NF>=5 && $1==k {
        m=cari($4)
        tag = (m!="") ? GN "unduh langsung" R : DIM "buka halaman resmi" R
        printf "%s\t%s\t%s\t   %s#%-4s%s %-24s %s%-7s%s %s\n", $3, $4, m, YL, $2, R, $4, CY, $5, R, tag
      }
    ' "$TMPL" "$RANKF" > /tmp/zwrl2 2>/dev/null
    [ -s /tmp/zwrl2 ] || return
    SEL=$(fzf --ansi --delimiter="$TAB" --with-nth=4 $FZFOPTS \
              --prompt='distro · cari: ' \
              --header="$K   ·   Esc kembali" --color="$FZFCLR" < /tmp/zwrl2 2>/dev/null)
    [ -z "$SEL" ] && return
    SLUG=$(printf '%s' "$SEL" | cut -f1)
    NAMA=$(printf '%s' "$SEL" | cut -f2)
    D=$(printf '%s' "$SEL" | cut -f3)
    if [ -n "$D" ]; then
      fzf_varian "$D"
    else
      header "$NAMA"
      printf "  ${DIM}ZWARTOS belum punya link unduh langsung untuk %s.${R}\n\n" "$NAMA"
      printf "  Halaman DistroWatch-nya memuat tautan unduh resmi.\n"
      printf "  ${CY}Buka di browser sekarang? (y/t) ${R}"
      read _a
      case "$_a" in y|Y) open_browser "https://distrowatch.com/$SLUG" ;; esac
    fi
  done
}

build_index(){
  : > "$TMPL"; [ -f "$ACTIVE" ] || return 0
  awk -F'|' '
    function trim(s){ gsub(/^[ \t\r]+|[ \t\r]+$/,"",s); return s }
    /===/ && /^[[:space:]]*#/ { c=$0; gsub(/[#=]/,"",c); cat=trim(c); next }
    /^[[:space:]]*#/ { next }  /^[[:space:]]*$/ { next }
    {
      name=trim($1); a=trim($2); b=(NF>=3)?trim($3):""
      if(name=="" || a=="") next
      n=split(name, P, /[ \t]*\/[ \t]*/)
      d=trim(P[1]); s=(n>=2)?trim(P[2]):""; v=(n>=3)?trim(P[3]):""
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", d, s, v, a, b, cat, name
    }
  ' "$ACTIVE" > "$TMPL" 2>/dev/null
}
count_os(){ wc -l < "$TMPL" 2>/dev/null | tr -d ' '; }
count_distro(){ awk -F'\t' '{print $1}' "$TMPL" 2>/dev/null | sort -u | wc -l | tr -d ' '; }
count_kat(){ awk -F'\t' '{print $6}' "$TMPL" 2>/dev/null | sort -u | wc -l | tr -d ' '; }

catclr(){
  case "$1" in
    *DESKTOP*)            printf '\033[38;5;110m';;
    *SERVER*)             printf '\033[38;5;108m';;
    *RINGAN*|*ADVANCED*|*BSD*) printf '\033[38;5;139m';;
    *SECURITY*|*PRIVACY*) printf '\033[38;5;168m';;
    *UTIL*|*RESCUE*)      printf '\033[38;5;179m';;
    *)                    printf '\033[38;5;252m';;
  esac
}

# ---- jaringan: koneksi -----------------------------------------------------
wifi_if(){ for d in /sys/class/net/*; do [ -e "$d/wireless" ]&&{ basename "$d"; return; }; case $(basename "$d") in wlan*|wlp*) basename "$d"; return;; esac; done; }
eth_if(){ for d in /sys/class/net/*; do i=$(basename "$d"); [ "$i" = lo ]&&continue; [ -e "$d/wireless" ]&&continue; case $i in eth*|en*) echo "$i"; return;; esac; done; }

# hasil: "dBm \t SSID" per baris, terkuat dulu.
# JEBAKAN: pemindaian tepat setelah interface dinyalakan sering mengembalikan
# kosong -> harus diulang beberapa kali sebelum menyerah.
wifi_scan(){
  IFC="$1"; try=0
  while [ "$try" -lt 5 ]; do
    out=$(iw dev "$IFC" scan 2>/dev/null)
    if [ -n "$out" ]; then
      printf '%s\n' "$out" | awk '
        /^[Bb][Ss][Ss] /            { sig="-999" }
        /signal:/                   { if (match($0,/-[0-9]+/)) sig=substr($0,RSTART,RLENGTH) }
        /^[ \t]*SSID: /             { s=$0; sub(/^[ \t]*SSID: /,"",s); if (s!="") print sig "\t" s }
      ' | sort -k2,2 -k1,1nr | awk -F'\t' '!seen[$2]++' | sort -k1,1nr
      return 0
    fi
    out=$(iwlist "$IFC" scanning 2>/dev/null)
    if [ -n "$out" ]; then
      printf '%s\n' "$out" | awk '
        /Signal level=/ { if (match($0,/-[0-9]+/)) sig=substr($0,RSTART,RLENGTH) }
        /ESSID:/        { s=$0; sub(/.*ESSID:"?/,"",s); sub(/"[ \t]*$/,"",s); if (s!="") print (sig==""?"-999":sig) "\t" s }
      ' | sort -k2,2 -k1,1nr | awk -F'\t' '!seen[$2]++' | sort -k1,1nr
      return 0
    fi
    try=$((try+1)); sleep 2
  done
  return 1
}

# Nama WiFi yang sedang tersambung. Ditulis saat koneksi berhasil dan
# dibaca ulang dari kartu supaya tetap benar walau ZWARTOS baru dijalankan.
SSIDF=/tmp/zwssid
ssid_aktif(){
  _w=$(wifi_if)
  if [ -n "$_w" ]; then
    _s=$(iw dev "$_w" link 2>/dev/null | sed -n 's/.*SSID: *//p' | head -1)
    [ -n "$_s" ] && { printf '%s' "$_s" > "$SSIDF"; printf '%s' "$_s"; return 0; }
  fi
  # tidak ada kartu WiFi / tidak terhubung -> jangan menampilkan nama basi
  rm -f "$SSIDF" 2>/dev/null
  return 1
}

bars(){ # dBm -> [####-]
  s=$1; [ -z "$s" ] && s=-999
  n=1
  [ "$s" -gt -80 ] && n=2; [ "$s" -gt -70 ] && n=3
  [ "$s" -gt -60 ] && n=4; [ "$s" -gt -50 ] && n=5
  i=0; o=""
  while [ $i -lt 5 ]; do [ $i -lt $n ] && o="$o#" || o="$o-"; i=$((i+1)); done
  printf '%s' "$o"
}

# rfkill.tcz tidak ikut di ISO, jadi soft-block dibuka langsung lewat
# /dev/rfkill. Struct rfkill_event 8 byte: idx(u32)=0, type(u8)=1 (WLAN),
# op(u8)=3 (CHANGE_ALL), soft(u8)=0, hard(u8)=0.
wifi_unblock(){ [ -c /dev/rfkill ] || return 0; printf '\000\000\000\000\001\003\000\000' > /dev/rfkill 2>/dev/null; return 0; }

# "" = tidak terblokir, "lunak" = bisa dibuka perangkat lunak,
# "keras" = sakelar/tombol pesawat fisik, hanya bisa dibuka pemakai.
wifi_block_state(){
  for f in /sys/class/rfkill/*; do
    [ -f "$f/type" ] || continue
    [ "$(cat "$f/type" 2>/dev/null)" = wlan ] || continue
    [ "$(cat "$f/hard" 2>/dev/null)" = 1 ] && { printf 'keras'; return; }
    [ "$(cat "$f/soft" 2>/dev/null)" = 1 ] && { printf 'lunak'; return; }
  done
}

# ---- regulasi nirkabel (regulatory.db) --------------------------------------
# Tanpa database regulasi, kernel memakai "world domain" dan MELARANG
# pemancaran di channel 5 GHz (ditandai "no IR"). Akibatnya, koneksi ke WiFi
# 5 GHz gagal meski sandi sudah benar - persis gejala di kartu ath10k/QCA6174.
# ISO baru sudah membundel /lib/firmware/regulatory.db lewat build-iso.sh.
wifi_reg_db(){ [ -f /lib/firmware/regulatory.db ] || [ -f /usr/lib/crda/regulatory.bin ]; }
wifi_reg_init(){
  # kalau db-nya belum ada, coba muat ekstensi (andai pengguna menaruhnya di stik)
  if ! wifi_reg_db && have tce-load; then
    tce-load -i wireless-regdb 2>/dev/null || true
  fi
  # setel negara sesuai konfigurasi supaya channel 5 GHz ikut terbuka
  if [ -n "$WIFI_COUNTRY" ] && have iw; then
    iw reg set "$WIFI_COUNTRY" 2>/dev/null || true
  fi
}
# cetak bantuan khusus bila SSID terlihat 5 GHz tapi channel diblokir
wifi_reg_hint(){
  wifi_reg_db && return 1
  printf '%s' "$1" | grep -qiE '5g|5ghz|[_ .-]5[gG]' || return 1
  printf "  ${YL}Sepertinya ini WiFi 5 GHz, tapi chip (ath10k) tidak bisa memakai${R}\n"
  printf "  ${YL}channel 5 GHz: database regulasi (regulatory.db) tidak ditemukan,${R}\n"
  printf "  ${YL}jadi semua channel 5 GHz diblokir (\"no IR\") oleh kernel.${R}\n\n"
  printf "  ${DIM}Solusi:${R}\n"
  printf "   1. Sambung dulu ke WiFi 2.4 GHz - itu pasti jalan.\n"
  printf "   2. Supaya 5 GHz ikut jalan, tambahkan ${WH}WIFI_COUNTRY=ID${R} di\n"
  printf "      ${DIM}zwartos.conf${R} (ganti ID sesuai negara) lalu build ulang ISO\n"
  printf "      dengan ${DIM}build-iso.sh${R} - database regulasi ikut dibundel.\n\n"
  return 0
}

# chip nirkabel yang terpasang beserta driver yang menempel padanya.
# Kalau chip terbaca tapi driver "-", berarti firmware/modulnya yang kurang.
wifi_chips(){
  for d in /sys/bus/pci/devices/*; do
    [ -f "$d/class" ] || continue
    case "$(cat "$d/class" 2>/dev/null)" in 0x0280*) ;; *) continue ;; esac
    v=$(cat "$d/vendor" 2>/dev/null); q=$(cat "$d/device" 2>/dev/null)
    drv="-"; [ -e "$d/driver" ] && drv=$(basename "$(readlink -f "$d/driver" 2>/dev/null)")
    printf 'PCI %s:%s  driver=%s\n' "${v#0x}" "${q#0x}" "$drv"
  done
}

fw_errors(){
  dmesg 2>/dev/null | grep -iE "firmware|iwlwifi|ath[0-9]|rtw|rtl8|mt7|brcm" \
    | grep -iE "fail|error|not found|missing|direct firmware load" | tail -6
}

# Laporan lengkap ke flashdisk supaya masalah di laptop bisa dibaca di komputer
# lain. Sandi WiFi tidak pernah ikut tersimpan.
wifi_report(){
  mount_ventoy 2>/dev/null
  F="$VENTOY/zwartos-wifi-report.txt"
  mountpoint -q "$VENTOY" 2>/dev/null || F="/tmp/zwartos-wifi-report.txt"
  {
    printf 'ZWARTOS %s - laporan WiFi\n\n' "$VERSION"
    printf '== antarmuka ==\n';        ip link 2>/dev/null
    printf '\n== alamat IP ==\n';      ip -4 addr 2>/dev/null
    printf '\n== chip nirkabel ==\n';  wifi_chips
    printf '\n== rfkill ==\n'
    for f in /sys/class/rfkill/*; do
      [ -f "$f/type" ] && printf '%s type=%s soft=%s hard=%s\n' "$(basename "$f")" \
        "$(cat "$f/type" 2>/dev/null)" "$(cat "$f/soft" 2>/dev/null)" "$(cat "$f/hard" 2>/dev/null)"
    done
    printf '\n== iw dev ==\n';         iw dev 2>/dev/null
    printf '\n== modul ==\n';          lsmod 2>/dev/null | head -40
    printf '\n== kernel (jaringan) ==\n'
    dmesg 2>/dev/null | grep -iE "firmware|wlan|wifi|iwlwifi|ath|rtw|rtl8|mt7|brcm|cfg80211|mac80211" | tail -60
    printf '\n== driver wpa yang dipakai ==\n'
    grep -iE "nl80211|wext|SIOCSIWENCODEEXT|jalankan:|gagal start" /tmp/wpa.log 2>/dev/null | head -20
    printf '\n== wpa_supplicant ==\n'; tail -80 /tmp/wpa.log 2>/dev/null
    printf '\n== versi wpa_supplicant ==\n'; wpa_supplicant -v 2>&1 | head -2
    printf '\n== media boot (USB?) ==\n'; cat /proc/cmdline 2>/dev/null; printf '\n'; dmesg 2>/dev/null | grep -iE "usb|sd[a-z]|squashfs|loop" | tail -10
    printf '\n== dhcp ==\n';           tail -20 /tmp/dhcp.log 2>/dev/null
    printf '\n== resolv.conf ==\n';    cat /etc/resolv.conf 2>/dev/null
  } > "$F" 2>&1
  sed -i 's/psk=.*/psk=<disensor>/g; s/[Pp]assword=.*/password=<disensor>/g' "$F" 2>/dev/null
  printf "\n  ${GN}Laporan disimpan:${R} %s\n" "$F"
  printf "  ${DIM}Buka di komputer lain. Sandi WiFi tidak ikut tersimpan.${R}\n"
}

offer_report(){
  printf "\n  ${CY}Simpan laporan lengkap ke flashdisk? (y/t) ${R}"
  read _a; case "$_a" in y|Y) wifi_report ;; esac
}

# tampilkan KENAPA kartu WiFi tidak muncul, alih-alih menyerah begitu saja
wifi_absent_screen(){
  printf "  ${RD}Kartu WiFi tidak terdeteksi.${R}\n\n"
  case "$(wifi_block_state)" in
    keras) printf "  ${YL}WiFi dimatikan lewat sakelar fisik / mode pesawat.${R}\n"
           printf "  ${DIM}Tekan Fn + tombol bergambar antena, lalu coba lagi.${R}\n\n" ;;
    lunak) printf "  ${YL}WiFi masih terkunci perangkat lunak.${R}\n\n" ;;
  esac
  C=$(wifi_chips)
  if [ -n "$C" ]; then
    printf "  ${DIM}Chip terbaca, tapi drivernya belum menempel:${R}\n"
    printf '%s\n' "$C" | sed 's/^/    /'
    printf "\n  ${DIM}Artinya firmware chip ini belum ada di ISO - simpan laporannya${R}\n"
    printf "  ${DIM}supaya firmware yang tepat bisa ditambahkan.${R}\n"
  else
    printf "  ${DIM}Tidak ada chip WiFi yang terbaca sama sekali.${R}\n"
  fi
  E=$(fw_errors)
  [ -n "$E" ] && { printf "\n  ${DIM}Pesan kernel:${R}\n"; printf '%s\n' "$E" | cut -c1-72 | sed 's/^/    /'; }
  offer_report
  pause
}

# input sandi bertopeng "*"; tekan Ctrl+R atau Tab untuk melihat sementara.
# Karakter yang diketik TIDAK pernah ditampilkan apa adanya (kecuali mode
# "lihat"), dan sandi tidak di-echo ke layar atau disimpan ke log.
read_pass(){
  PASS=""; SHOW=0
  stty -icanon -echo min 1 time 0 2>/dev/null
  while :; do
    c=$(dd bs=1 count=1 2>/dev/null)
    case "$c" in
      ""|"$(printf '\r')"|"$(printf '\n')") break ;;
      "$(printf '\177')"|"$(printf '\b')") PASS="${PASS%?}" ;;
      "$(printf '\025')") PASS="" ;;                       # Ctrl+U: hapus semua
      "$(printf '\003')") stty sane 2>/dev/null; printf "\n\n"; return 1 ;; # Ctrl+C
      "$(printf '\022')"|"$(printf '\011')") SHOW=$((1-SHOW)) ;; # Ctrl+R / Tab
      *) PASS="$PASS$c" ;;
    esac
    if [ "$SHOW" = 1 ]; then
      printf "\r\033[K  Password ${DIM}(Ctrl+R/Tab: sembunyi)${R}: %s" "$PASS"
    else
      MASK=$(printf '%*s' "${#PASS}" "" | tr ' ' '*')
      printf "\r\033[K  Password ${DIM}(kosongkan kalau WiFi terbuka, Ctrl+R lihat)${R}: %s" "$MASK"
    fi
  done
  stty sane 2>/dev/null
  printf "\n\n"
  return 0
}

# ---- DHCP: satu jalur untuk WiFi dan LAN -----------------------------------
# Dulu logika ini disalin dua kali (connect_wifi dan connect_lan) dan keduanya
# punya cacat yang sama. Satu salinan saja supaya tidak menyimpang lagi.
punya_ip(){
  # Jangan mengharuskan bentuk "inet 1.2.3.4/24" persis, dan sediakan cadangan
  # ifconfig untuk busybox.
  _a=$(ip -4 addr show "$1" 2>/dev/null | sed -n 's#.*inet \([0-9][0-9.]*\).*#\1#p' | head -1)
  [ -z "$_a" ] && _a=$(ifconfig "$1" 2>/dev/null | sed -n 's#.*inet addr:\([0-9][0-9.]*\).*#\1#p' | head -1)
  [ -z "$_a" ] && _a=$(ifconfig "$1" 2>/dev/null | sed -n 's#.*inet \([0-9][0-9.]*\).*#\1#p' | head -1)
  printf '%s' "$_a"
}

# dhcpcd BERCABANG ke latar belakang lalu mengembalikan 0 - alamatnya belum
# tentu terbaca pada detik itu juga. Karena itu ditunggu, bukan dicek sekali.
tunggu_ip(){                        # $1 = iface, $2 = detik maksimal
  _i=0
  while [ "$_i" -lt "$2" ]; do
    [ -n "$(punya_ip "$1")" ] && { printf "\r\033[K"; return 0; }
    printf "\r\033[K  ${DIM}menunggu alamat IP… %s detik${R}" "$_i"
    sleep 1; _i=$((_i+1))
  done
  printf "\r\033[K"
  return 1
}

dhcp_jalankan(){                    # $1 = nama, sisanya perintah
  _nm="$1"; shift
  printf '== jalankan: %s ==\n' "$*" >> /tmp/dhcp.log
  "$@" >> /tmp/dhcp.log 2>&1
  printf '%s exit code: %s\n' "$_nm" "$?" >> /tmp/dhcp.log
}

# Coba klien DHCP satu per satu sampai dapat alamat. Pesan hanya menyebut klien
# yang BENAR-BENAR dijalankan - jangan pernah menyalahkan yang tidak terpasang.
dapat_ip(){                         # $1 = iface
  _if="$1"
  rm -f /tmp/dhcp.log
  printf '== DHCP dimulai ==\ninterface: %s\n' "$_if" >> /tmp/dhcp.log
  if have udhcpc; then
    dhcp_jalankan udhcpc udhcpc -i "$_if" -f -n -q -t 15 -T 5 -A 30
    tunggu_ip "$_if" 3 && return 0
  fi
  if have dhcpcd; then
    printf "  ${YL}udhcpc belum dapat IP, coba dhcpcd…${R}\n"
    dhcp_jalankan dhcpcd dhcpcd "$_if"
    tunggu_ip "$_if" 20 && return 0
  fi
  if have dhclient; then
    printf "  ${YL}dhcpcd belum dapat IP, coba dhclient…${R}\n"
    dhcp_jalankan dhclient dhclient -v "$_if"
    tunggu_ip "$_if" 10 && return 0
  fi
  return 1
}


connect_wifi(){
  header "Konek WiFi"
  wifi_unblock
  wifi_reg_init
  IFC=$(wifi_if)
  [ -z "$IFC" ] && { wifi_absent_screen; return; }

  printf "  Kartu WiFi : ${GN}%s${R}" "$IFC"
  BS=$(wifi_block_state)
  [ -n "$BS" ] && printf "   ${YL}masih terblokir (%s)${R}" "$BS"
  printf "\n\n"
  if [ "$BS" = keras ]; then
    printf "  ${YL}Nyalakan dulu WiFi lewat tombol Fn / mode pesawat.${R}\n"
    printf "  ${DIM}Selama sakelar fisiknya mati, sistem tidak bisa berbuat apa-apa.${R}\n"
    pause; return
  fi
  ip link set "$IFC" up 2>/dev/null
  spin "menyalakan kartu WiFi…" sleep 2

  LIST=/tmp/zwwifi; : > "$LIST"
  scan_to_file(){ wifi_scan "$1" > "$LIST" 2>/dev/null; }
  spin "memindai jaringan WiFi di sekitar…" scan_to_file "$IFC"

  SSID=""
  if [ -s "$LIST" ] && have fzf; then
    SEL=$(
      { while IFS="$TAB" read -r sg ss; do
          printf '%s\t   %-30s %s[%s]%s  %s%s dBm%s\n' "$ss" "$ss" "$GY" "$(bars "$sg")" "$R" "$DIM" "$sg" "$R"
        done < "$LIST"
        printf '__MANUAL__\t   %sjaringan tidak ada di daftar - ketik manual…%s\n' "$DIM" "$R"
      } | fzf --ansi --delimiter="$TAB" --with-nth=2 $FZFOPTS \
              --prompt='WiFi · cari: ' --header="Pilih jaringan WiFi   ·   Esc batal" --color="$FZFCLR" 2>/dev/null
    )
    [ -z "$SEL" ] && return
    SSID=$(printf '%s' "$SEL" | cut -f1)
    [ "$SSID" = "__MANUAL__" ] && SSID=""
  else
    printf "  ${YL}Tidak ada jaringan yang terbaca.${R} ${DIM}Ketik namanya manual.${R}\n\n"
  fi

  if [ -z "$SSID" ]; then
    printf "  Nama WiFi (SSID) : "; read SSID
    [ -z "$SSID" ] && return
  fi
  header "Konek WiFi"
  printf "  Jaringan : ${GN}%s${R}\n\n" "$SSID"
  printf "  Password ${DIM}(kosongkan kalau WiFi terbuka, Ctrl+R untuk lihat)${R}\n  "
  read_pass || return

  # WPA mensyaratkan 8-63 karakter. Dulu wpa_passphrase gagal diam-diam di
  # sini, dan akibatnya baru muncul jauh kemudian sebagai "belum dapat
  # internet" - petunjuk yang menyesatkan.
  if [ -n "$PASS" ]; then
    PL=${#PASS}
    if [ "$PL" -lt 8 ] || [ "$PL" -gt 63 ]; then
      printf "  ${RD}Sandi WiFi harus 8-63 karakter.${R} ${DIM}(kamu mengetik %s)${R}\n" "$PL"
      printf "  ${DIM}Ini aturan WPA, bukan batasan ZWARTOS. Cek lagi sandinya.${R}\n"
      pause; return
    fi
  fi

  have wpa_supplicant || { printf "  ${RD}wpa_supplicant belum termuat.${R}\n"; pause; return; }
  CF=/tmp/wpa.conf; WLOG=/tmp/wpa.log
  rm -f "$WLOG"
  # ctrl_interface wajib ada supaya wpa_cli bisa membaca status koneksi.
  # Baris '#psk="…"' dari wpa_passphrase dibuang supaya sandi tidak tersimpan.
  {
    printf 'ctrl_interface=/var/run/wpa_supplicant\n'
    printf 'update_config=1\n'
    if [ -z "$PASS" ]; then
      printf 'network={\n ssid="%s"\n key_mgmt=NONE\n}\n' "$SSID"
    else
      wpa_passphrase "$SSID" "$PASS" 2>>"$WLOG" | grep -v '^[[:space:]]*#'
    fi
  } > "$CF"
  chmod 600 "$CF" 2>/dev/null   # sandi di dalamnya tidak boleh dibaca pengguna lain
  if ! grep -q 'ssid=' "$CF" 2>/dev/null; then
    printf "  ${RD}Gagal menyiapkan sandi WiFi.${R}\n\n"
    tail -3 "$WLOG" 2>/dev/null | sed 's/^/    /'
    offer_report; pause; return
  fi

  mkdir -p /var/run/wpa_supplicant 2>/dev/null
  pkill wpa_supplicant 2>/dev/null; sleep 1
  rm -f /tmp/wpa.pid
  # WAJIB "-D nl80211". Tanpa opsi ini wpa_supplicant memilih driver bawaannya,
  # yaitu WEXT (Wireless Extensions) yang sudah usang. Kartu berbasis
  # cfg80211/mac80211 menolak ioctl WEXT dengan
  #     ioctl[SIOCSIWENCODEEXT]: Invalid argument
  # sehingga kunci WPA tidak pernah terpasang dan asosiasi tidak pernah jadi -
  # dengan sandi benar sekalipun. Biner di ISO mendukung keduanya
  # ("-D = driver name (can be multiple drivers: nl80211,wext)").
  echo "== jalankan: wpa_supplicant -D nl80211 -i $IFC ==" >> "$WLOG"
  wpa_supplicant -B -D nl80211 -i "$IFC" -c "$CF" -f "$WLOG" -P /tmp/wpa.pid 2>>"$WLOG"
  if [ ! -s /tmp/wpa.pid ] || ! kill -0 "$(cat /tmp/wpa.pid 2>/dev/null)" 2>/dev/null; then
    # nl80211 tidak bisa dipakai sama sekali di kartu ini -> baru izinkan
    # wpa_supplicant memilih sendiri, sebagai upaya terakhir.
    echo "== nl80211 gagal start, coba driver bawaan ==" >> "$WLOG"
    pkill wpa_supplicant 2>/dev/null; sleep 1
    rm -f /tmp/wpa.pid
    wpa_supplicant -B -i "$IFC" -c "$CF" -f "$WLOG" -P /tmp/wpa.pid 2>>"$WLOG"
  fi

  # tunggu asosiasi sungguhan, bukan sekadar tidur 5 detik. Kalau proses
  # wpa_supplicant mati di tengah jalan (Bus error), berhenti cepat dan
  # beri tahu, jangan menunggu 30 detik penuh.
  ASSOC=1; WPA_DEAD=0; i=0
  if [ ! -s /tmp/wpa.pid ] || ! kill -0 "$(cat /tmp/wpa.pid 2>/dev/null)" 2>/dev/null; then
    WPA_DEAD=1
  else
    while [ $i -lt 30 ]; do
      if [ -s /tmp/wpa.pid ] && ! kill -0 "$(cat /tmp/wpa.pid 2>/dev/null)" 2>/dev/null; then
        WPA_DEAD=1; break
      fi
      if iw dev "$IFC" link 2>/dev/null | grep -qi "connected to"; then ASSOC=0; break; fi
      # dulu di sini ada wpa_cli yang dipanggil TIAP DETIK - 30 proses baru
      # dari squashfs yang di-loop-mount di USB, sumber "Bus error" paling
      # mungkin. Statusnya toh sudah terbaca dari iw di baris atas.
      printf "\r\033[K  ${DIM}menghubungkan ke %s… %s detik${R}" "$SSID" "$i"
      sleep 1; i=$((i+1))
    done
  fi
  printf "\r\033[K"

  if [ "$ASSOC" != 0 ]; then
    printf "  ${RD}Gagal tersambung ke %s.${R}\n\n" "$SSID"
    if [ "$WPA_DEAD" = 1 ]; then
      # prosesnya mati ("Bus error") -> bukan masalah sandi/jaringan
      grep -q "Bus error" "$WLOG" 2>/dev/null && echo "PROSES MATI: Bus error (wpa_supplicant)" >> "$WLOG"
      printf "  ${YL}Program WiFi (wpa_supplicant) mati mendadak.${R}\n"
      printf "  ${DIM}Ini biasanya 'Bus error' - sering muncul saat ISO dijalankan${R}\n"
      printf "  ${DIM}dari flashdisk USB yang sedang bermasalah (loop-mount gagal${R}\n"
      printf "  ${DIM}saat halaman programnya dibaca).${R}\n\n"
      printf "  ${WH}Coba dulu:${R}\n"
      printf "   1. Colok flashdisk ke port USB lain (langsung di laptop,\n"
      printf "      bukan lewat hub), lalu boot ulang ZWARTOS.\n"
      printf "   2. Kalau tetap mati, coba flashdisk / port USB yang lain.\n\n"
      grep -iE "Bus error" "$WLOG" 2>/dev/null | tail -3 | sed 's/^/    /'
    elif grep -q "SIOCSIWENCODEEXT" "$WLOG" 2>/dev/null; then
      printf "  ${YL}Kartu WiFi ini dipaksa memakai antarmuka lama (WEXT).${R}\n"
      printf "  ${DIM}Kunci WPA tidak bisa dipasang lewat jalur itu, jadi koneksi${R}\n"
      printf "  ${DIM}gagal walau sandinya benar. Seharusnya sudah tidak terjadi${R}\n"
      printf "  ${DIM}di versi ini - simpan laporannya.${R}\n"
    elif grep -qiE "WRONG_KEY|pre-shared key may be incorrect|handshake failed|reason=15" "$WLOG" 2>/dev/null; then
      printf "  ${YL}Sandi WiFi-nya salah.${R} ${DIM}Ketik ulang, perhatikan huruf besar/kecil.${R}\n"
    elif grep -qiE "NETWORK-NOT-FOUND|No suitable network" "$WLOG" 2>/dev/null; then
      printf "  ${YL}Jaringan \"%s\" tidak ditemukan.${R} ${DIM}Cek ejaan atau dekati router.${R}\n" "$SSID"
    else
      printf "  ${DIM}Pesan terakhir dari sistem:${R}\n"
      grep -iE "CTRL-EVENT|reason|fail|Bus error" "$WLOG" 2>/dev/null | tail -4 | cut -c1-72 | sed 's/^/    /'
    fi
    wifi_reg_hint "$SSID"
    rm -f "$CF" /tmp/wpa.pid 2>/dev/null   # sandi tidak dibiarkan mengendap di /tmp
    offer_report; pause; return
  fi

  printf "  ${GN}Tersambung ke %s.${R}\n" "$SSID"
  ip link set "$IFC" down 2>/dev/null; sleep 1
  ip link set "$IFC" up   2>/dev/null; sleep 2
  dapat_ip "$IFC"

  # Yang benar-benar kita pedulikan adalah "ada internet", bukan "apakah
  # perintah ip mencetak sesuatu" - jadi netup() jadi penentu terakhir.
  IP=$(punya_ip "$IFC")
  if [ -z "$IP" ]; then
    NETTS=-999
    netup && IP="terpasang"
  fi
  if [ -z "$IP" ]; then
    printf "  ${RD}Tidak dapat alamat IP.${R}\n\n"
    if grep -qiE "leased|bound to|lease of|offered" /tmp/dhcp.log 2>/dev/null; then
      printf "  ${YL}Router SUDAH memberi alamat, tapi belum menempel di %s.${R}\n\n" "$IFC"
      printf "  ${DIM}Tunggu sebentar lalu pilih \"Konek WiFi\" lagi -${R}\n"
      printf "  ${DIM}biasanya percobaan kedua langsung jadi.${R}\n"
    else
      printf "  ${DIM}Tidak ada DHCP client yang berhasil. Penyebab mungkin:${R}\n"
      printf "   - Router/hotspot tidak membagikan IP (DHCP mati)\n"
      printf "   - DHCP server lambat merespon\n"
      printf "   - Isolasi klien aktif (client isolation)\n"
      printf "   - Masalah driver firmware\n"
    fi
    printf "\n  ${DIM}Detail:${R}\n"
    tail -10 /tmp/dhcp.log 2>/dev/null | cut -c1-72 | sed 's/^/    /'
    rm -f "$CF" /tmp/wpa.pid 2>/dev/null

    offer_report; pause; return
  fi
  
  rm -f "$CF" /tmp/wpa.pid 2>/dev/null   # koneksi jadi: buang berkas sandi
  printf "  ${GN}Alamat IP : %s${R}\n\n" "$IP"

  NETTS=-999            # jangan pakai hasil cek lama yang masih tersimpan
  if netup; then
    printf "  ${GN}Internet aktif.${R}\n\n"
    load_conf; refresh_ui
    printf "  ${GN}Daftar OS: %s${R} ${DIM}(%s pilihan)${R}\n" "$SRC" "$(count_os)"
  else
    printf "  ${YL}Sudah tersambung, tapi internet belum bisa dipakai.${R}\n\n"
    printf "  ${DIM}Biasanya WiFi seperti ini minta login dulu lewat halaman browser${R}\n"
    printf "  ${DIM}(WiFi kafe, hotel, kantor, kampus).${R}\n"
    printf "\n  ${CY}Buka halaman login sekarang? (y/t) ${R}"
    read _a
    case "$_a" in y|Y) open_browser "http://neverssl.com" ;; esac
  fi
  pause
}

connect_lan(){
  header "Konek LAN (kabel)"
  IFC=$(eth_if)
  [ -z "$IFC" ] && { printf "  ${RD}Port LAN tak terdeteksi.${R}\n"; pause; return; }
  printf "  Port LAN : ${GN}%s${R}\n\n" "$IFC"
  ip link set "$IFC" up 2>/dev/null
  dapat_ip "$IFC"

  if netup; then
    printf "  ${GN}LAN tersambung${R}\n\n"
    load_conf; refresh_ui
    printf "  ${GN}Daftar OS: %s${R} ${DIM}(%s pilihan)${R}\n" "$SRC" "$(count_os)"
  else
    printf "  ${RD}Gagal.${R} ${DIM}Cek kabel atau DHCP jaringan.${R}\n"
  fi
  pause
}

# ---- unduh -----------------------------------------------------------------
resolve_newest(){
  M=$(curl -A "$UA" -sL --max-time 40 "$1" 2>/dev/null | grep -oE "$2" | sort -Vu 2>/dev/null)
  [ -z "$M" ] && M=$(curl -A "$UA" -sL --max-time 40 "$1" 2>/dev/null | grep -oE "$2" | sort -u)
  printf '%s' "$M" | tail -1
}
remote_size(){
  curl -A "$UA" -sIL --max-time 30 "$1" 2>/dev/null \
    | awk 'BEGIN{IGNORECASE=1} /^content-length:/{v=$2} END{gsub(/\r/,"",v); print v+0}'
}
is_iso(){ # ISO9660 punya penanda "CD001" di offset 32769
  [ -f "$1" ] || return 1
  # bukan berkas .iso (mis. ChromeOS Flex .bin.zip) -> tidak perlu diperiksa
  case "$1" in *.iso) ;; *) return 0 ;; esac
  s=$(dd if="$1" bs=1 skip=32769 count=5 2>/dev/null)
  [ "$s" = "CD001" ]
}

do_get(){
  nm="$1"; a="$2"; b="$3"
  header "Unduh OS"
  printf "  ${WH}%s${R}\n\n" "$nm"
  netup || printf "  ${YL}Jaringan belum terdeteksi${R} ${DIM}(tetap dicoba)${R}\n\n"
  mount_ventoy || { printf "  ${RD}Flashdisk Ventoy tidak ditemukan.${R}\n  ${DIM}Pastikan stiknya tercolok, lalu coba lagi.${R}\n"; pause; return; }

  URL="$a"
  if [ -n "$b" ]; then
    resolve_to_file(){ resolve_newest "$1" "$2" > /tmp/zwres; }
    spin "mencari versi terbaru di server…" resolve_to_file "$a" "$b"
    f=$(cat /tmp/zwres 2>/dev/null)
    [ -z "$f" ] && { printf "  ${RD}Tidak menemukan berkasnya di server.${R}\n  ${DIM}Mungkin link di daftar sudah usang, atau koneksi bermasalah.${R}\n"; pause; return; }
    URL="$a$f"
  fi
  # nama berkas: header Content-Disposition -> URL akhir -> URL awal
  # (link seperti sourceforge ".../latest/download" tidak memuat namanya)
  probe_head(){ curl -A "$UA" -sIL --max-time 30 -D /tmp/zwhdr -o /dev/null -w '%{url_effective}' "$1" > /tmp/zweff 2>/dev/null; }
  spin "mengecek berkas di server…" probe_head "$URL"
  FN=$(sed -n 's/.*[Ff]ilename="\{0,1\}\([^";]*\)"\{0,1\}.*/\1/p' /tmp/zwhdr 2>/dev/null | tr -d '\r' | tail -1)
  [ -z "$FN" ] && FN=$(basename "$(cat /tmp/zweff 2>/dev/null)" | sed 's/[?#].*$//')
  case "$FN" in ""|download|index*|*/*) FN=$(basename "$URL" | sed 's/[?#].*$//');; esac
  # bersihkan nama berkas dari percobaan traversal direktori (../, /, spasi dll)
  FN=$(printf '%s' "$FN" | sed 's#^[/. ]*##; s#[/\\][/\\]*#_#g; s/[^A-Za-z0-9._-]/_/g')
  [ -z "$FN" ] && FN="unduhan.iso"
  # pertahankan ekstensi yang memang dikenal Ventoy / alat lain
  case "$FN" in
    *.iso|*.img|*.zip|*.wim|*.vhd|*.vhdx|*.bin|*.efi|*.qcow2) ;;
    *) FN="$FN.iso" ;;
  esac
  DEST="$VENTOY/$FN"

  SZ=$(awk 'BEGIN{IGNORECASE=1} /^content-length:/{v=$2} END{gsub(/\r/,"",v); print v+0}' /tmp/zwhdr 2>/dev/null)
  [ "${SZ:-0}" -eq 0 ] && SZ=$(remote_size "$URL")
  PUNYA=0; [ -f "$DEST" ] && PUNYA=$(wc -c < "$DEST" 2>/dev/null)
  FREE=$(free_kb); FREEB=$((${FREE:-0} * 1024))

  hr
  printf "  Berkas        : ${GN}%s${R}\n" "$FN"
  if [ "${SZ:-0}" -gt 0 ]; then printf "  Ukuran        : ${WH}%s${R}\n" "$(human "$SZ")"
  else                          printf "  Ukuran        : ${DIM}tidak diketahui${R}\n"; fi
  printf "  Disimpan ke   : ${WH}%s${R} ${DIM}(langsung ke flashdisk)${R}\n" "$VENTOY"
  printf "  Sisa flashdisk: %s" "$(human "$FREEB")"

  # Cadangan ruang. Flashdisk yang terisi sampai betul-betul penuh sering
  # gagal menulis justru di akhir unduhan - kegagalan paling mahal, karena
  # muncul setelah berjam-jam. Sisakan MIN_FREE_MB (bawaan 200 MB).
  MINFREE=$(( ${MIN_FREE_MB:-200} * 1024 * 1024 ))
  KURANG=0
  if [ "${SZ:-0}" -gt 0 ] && [ "$FREEB" -gt 0 ]; then
    BUTUH=$((SZ - PUNYA)); [ "$BUTUH" -lt 0 ] && BUTUH=0
    PERLU=$((BUTUH + MINFREE))
    if [ "$FREEB" -lt "$PERLU" ]; then
      KURANG=$((PERLU - FREEB))
      printf "   ${RD}(tidak cukup)${R}\n"
    else
      printf "   ${GN}(cukup)${R}\n"
    fi
  elif [ "${SZ:-0}" -eq 0 ]; then
    printf "   ${YL}(ukuran berkas tidak diketahui - pastikan ruangnya cukup)${R}\n"
  else
    printf "\n"
  fi
  BAT=$(battery) && {
    bc=$(printf '%s' "$BAT" | cut -d'|' -f1); bs=$(printf '%s' "$BAT" | cut -d'|' -f2); bt=$(printf '%s' "$BAT" | cut -d'|' -f3)
    if [ "$bs" = "Discharging" ] && [ "${bc:-100}" -lt 40 ]; then
      printf "  Baterai       : ${YL}%s%% (%s) - colok charger dulu, unduhan besar makan waktu${R}\n" "$bc" "$bt"
    else
      printf "  Baterai       : %s%% ${DIM}(%s)${R}\n" "$bc" "$bt"
    fi
  }
  hr

  if [ "$KURANG" -gt 0 ]; then
    printf "\n  ${RD}Ruang flashdisk tidak cukup - unduhan tidak dimulai.${R}\n\n"
    printf "    berkas ini      : %s\n" "$(human "$BUTUH")"
    printf "    cadangan wajib  : %s\n" "$(human "$MINFREE")"
    printf "    tersedia        : %s\n" "$(human "$FREEB")"
    printf "    ${RD}kurang          : %s${R}\n\n" "$(human "$KURANG")"
    printf "  ${DIM}Hapus ISO lama di flashdisk lewat komputer lain, lalu coba lagi.${R}\n"
    printf "  ${DIM}Cadangan %s sengaja disisakan supaya penulisan tidak gagal${R}\n" "$(human "$MINFREE")"
    printf "  ${DIM}justru di akhir unduhan. Bisa diubah lewat MIN_FREE_MB${R}\n"
    printf "  ${DIM}di berkas zwartos.conf pada flashdisk.${R}\n"
    pause; return
  fi

  RESUME=""; ULANG=""
  if [ "$PUNYA" -gt 0 ] && [ "${SZ:-0}" -gt 0 ] && [ "$PUNYA" -lt "$SZ" ]; then
    PCT=$(awk -v a="$PUNYA" -v b="$SZ" 'BEGIN{printf "%d", a*100/b}')
    printf "\n  ${YL}Ada unduhan yang belum selesai: %s dari %s (%s%%).${R}\n" "$(human "$PUNYA")" "$(human "$SZ")" "$PCT"
    printf "  ${GN}Akan DILANJUTKAN dari titik terakhir, bukan mulai dari nol.${R}\n"
    RESUME="ya"
  elif [ "$PUNYA" -gt 0 ] && [ "${SZ:-0}" -gt 0 ] && [ "$PUNYA" -ge "$SZ" ]; then
    printf "\n  ${GN}Berkas ini sudah lengkap ada di flashdisk.${R}\n"
    printf "  Unduh ulang dari awal? [y/${B}T${R}] "; read yn
    # JANGAN menghapus di sini. Berkasnya ikut terhapus walaupun pemakai
    # membatalkan di pertanyaan berikutnya - unduhan berjam-jam hilang
    # padahal ia tidak jadi mengunduh ulang. Hapus setelah benar-benar mulai.
    case "$yn" in y|Y) ULANG=ya; PUNYA=0;; *) pause; return;; esac
  fi

  printf "\n  ${DIM}Kalau internet putus atau laptop mati, unduhan TIDAK hilang -${R}\n"
  printf "  ${DIM}pilih OS yang sama lagi nanti, dan ini akan dilanjutkan.${R}\n"
  printf "\n  Mulai unduh sekarang? [${B}Y${R}/t] "; read yn
  case "$yn" in t|T|n|N) return;; esac
  # baru sekarang aman menghapus: pemakai sudah menyatakan mulai
  [ "${ULANG:-}" = ya ] && rm -f "$DEST"

  if dl_running; then
    printf "\n  ${YL}Masih ada unduhan lain yang berjalan.${R}\n"
    printf "  ${DIM}Tunggu selesai dulu, atau hentikan dari menu \"Unduhan\".${R}\n"
    pause; return
  fi
  dl_start "$nm" "$URL" "$DEST" "${SZ:-0}"
  printf "\n  ${GN}Unduhan dimulai di latar belakang.${R}\n"
  printf "  ${DIM}Kamu bisa kembali ke menu dan memakai ZWARTOS seperti biasa -${R}\n"
  printf "  ${DIM}termasuk membuka browser - sambil menunggu.${R}\n"
  sleep 2
  dl_screen
  return
}
do_url(){
  header "Unduh dari URL"
  printf "  Tempel atau ketik alamat berkas .iso, lalu Enter.\n"
  printf "  ${DIM}Kosongkan lalu Enter untuk batal.${R}\n\n"
  printf "  URL: "
  read U; [ -n "$U" ] && do_get "URL manual" "$U" ""
}


# ---- unduhan latar belakang ------------------------------------------------
# Unduhan besar dijalankan sebagai proses terpisah supaya menu bisa dipakai
# lagi (mis. browsing) sambil menunggu. Statusnya disimpan di berkas kecil.
DLPID=/tmp/zwdl.pid; DLINFO=/tmp/zwdl.info; DLLOG=/tmp/zwdl.log; DLRC=/tmp/zwdl.rc

dl_running(){ [ -s "$DLPID" ] && kill -0 "$(cat "$DLPID" 2>/dev/null)" 2>/dev/null; }
dl_field(){ sed -n "${1}p" "$DLINFO" 2>/dev/null; }
dl_name(){ dl_field 1; }
dl_dest(){ dl_field 2; }
dl_size(){ dl_field 3; }
dl_done(){ [ -s "$DLINFO" ] && ! dl_running; }
dl_pct(){
  _tot=$(dl_size); _now=$(wc -c < "$(dl_dest)" 2>/dev/null)
  [ -z "$_now" ] && _now=0
  [ "${_tot:-0}" -gt 0 ] || { printf '?'; return; }
  awk -v a="$_now" -v b="$_tot" 'BEGIN{printf "%d", a*100/b}'
}
dl_start(){   # nama url dest ukuran
  printf '%s\n%s\n%s\n%s\n' "$1" "$3" "$4" "$2" > "$DLINFO"
  rm -f "$DLRC"
  (
    curl -A "$UA" -L --fail -C - \
         --retry 20 --retry-delay 5 --retry-max-time 0 \
         --connect-timeout 20 --speed-limit 2048 --speed-time 120 \
         -sS -o "$3" "$2" > "$DLLOG" 2>&1
    printf '%s' "$?" > "$DLRC"
  ) &
  printf '%s' "$!" > "$DLPID"
}
dl_stop(){ [ -s "$DLPID" ] && kill "$(cat "$DLPID")" 2>/dev/null; pkill -f "curl.*$(dl_dest)" 2>/dev/null; rm -f "$DLPID"; }

# satu tekan tombol tanpa menunggu (untuk layar yang menyegarkan sendiri)
peekkey(){
  stty -icanon -echo min 0 time 0 2>/dev/null
  _k=$(dd bs=1 count=1 2>/dev/null)
  stty sane 2>/dev/null
  printf '%s' "$_k"
}

# Cek apakah flashdisk masih sibuk menulis (pending disk writes)
disk_busy(){
  # Cek apakah ada proses yang sedang menulis ke mountpoint Ventoy
  if mountpoint -q "$VENTOY" 2>/dev/null; then
    # cek apakah ada proses dengan file terbuka di Ventoy
    have lsof && lsof +D "$VENTOY" 2>/dev/null | grep -q . && return 0
    # cek dirty pages (data belum ditulis ke disk)
    grep -q "Dirty:" /proc/meminfo 2>/dev/null || return 1
    dirty=$(grep "Dirty:" /proc/meminfo 2>/dev/null | awk '{print $2}')
    [ "${dirty:-0}" -gt 1024 ] && return 0  # > 1MB dirty = masih menulis
  fi
  return 1
}

# Sync dan tunggu sampai disk benar-benar idle
safe_sync(){
  printf "  ${DIM}menyimpan data ke flashdisk…${R}"
  sync
  # Tunggu sampai dirty pages habis (max 30 detik)
  _wait=0
  while [ "$_wait" -lt 30 ]; do
    dirty=$(grep "Dirty:" /proc/meminfo 2>/dev/null | awk '{print $2}')
    [ "${dirty:-0}" -lt 256 ] && break  # < 256KB = aman
    sleep 1; _wait=$((_wait+1))
    printf "."
  done
  printf "\r\033[K"
}

waktu_singkat(){        # detik -> "45 detik" / "8 menit" / "1 jam 5 menit"
  _d=${1:-0}
  if   [ "$_d" -lt 60 ];   then printf '%s detik' "$_d"
  elif [ "$_d" -lt 3600 ]; then printf '%s menit' "$((_d/60))"
  else printf '%s jam %s menit' "$((_d/3600))" "$(((_d%3600)/60))"; fi
}

dl_screen(){
  curs_off
  # contoh awal untuk hitung kecepatan; diperbarui tiap >=2 detik supaya
  # angkanya stabil, bukan melompat tiap penyegaran layar
  SP_B=""; SP_T=""; SPD=""; ETA=""
  while :; do
    printf '\033[H'
    header "Unduhan"
    NM=$(dl_name); TOT=$(dl_size)
    NOW=$(wc -c < "$(dl_dest)" 2>/dev/null); [ -z "$NOW" ] && NOW=0
    # Kalau unduhan sudah selesai, tampilkan angka akhirnya - jangan 99%
    # gara-gara penyegaran terakhir jatuh sebelum byte terakhir mendarat.
    SELESAI=""
    if ! dl_running && [ "$(cat "$DLRC" 2>/dev/null)" = 0 ]; then
      SELESAI=ya
      [ "${TOT:-0}" -gt 0 ] && NOW="$TOT"
    fi

    # kecepatan = pertambahan ukuran berkas DI FLASHDISK per detik.
    # Karena curl menulis langsung ke sana, ini sekaligus kecepatan simpannya.
    _t=$(date +%s 2>/dev/null); [ -z "$_t" ] && _t=0
    [ -z "$SP_T" ] && { SP_B="$NOW"; SP_T="$_t"; }
    _dt=$((_t - SP_T))
    if [ "$_dt" -ge 2 ]; then
      _db=$((NOW - SP_B)); [ "$_db" -lt 0 ] && _db=0
      _bps=$((_db / _dt))
      SP_B="$NOW"; SP_T="$_t"
      if [ "$_bps" -gt 0 ]; then
        SPD="$(human "$_bps")/detik"
        _sisa=$((TOT - NOW))
        if [ "${TOT:-0}" -gt 0 ] && [ "$_sisa" -gt 0 ]; then
          ETA=$(waktu_singkat $((_sisa / _bps)))
        else
          ETA=""
        fi
      else
        SPD="menunggu…"; ETA=""
      fi
    fi

    printf "  ${WH}%s${R}\033[K\n\n" "$NM"
    printf "  Berkas    : %s\033[K\n" "$(basename "$(dl_dest)")"
    printf "  Ukuran    : %s dari %s\033[K\n" "$(human "$NOW")" "$(human "$TOT")"
    printf "  Kecepatan : %s\033[K\n" "${SPD:-menghitung…}"
    printf "  Sisa waktu: %s\033[K\n\n" "${ETA:-–}"
    P=$(dl_pct); [ "$P" = "?" ] && P=0
    [ "$SELESAI" = ya ] && P=100
    _n=$((P*30/100)); _f=""; _j=0
    while [ "$_j" -lt "$_n" ]; do _f="$_f#"; _j=$((_j+1)); done
    _r=""; _j=$_n
    while [ "$_j" -lt 30 ]; do _r="$_r."; _j=$((_j+1)); done
    printf "  [%s%s]  %s%%\033[K\n\n" "$_f" "$_r" "$P"
    if dl_running; then
      printf "  ${GN}sedang mengunduh${R} ${DIM}- ditulis langsung ke flashdisk${R}\033[K\n\n"
      printf "  ${DIM}tombol apa saja = kembali ke menu, unduhan tetap jalan${R}\033[K\n"
      printf "  ${DIM}b = berhenti${R}\033[K\n"
      k=$(peekkey)
      case "$k" in
        b|B) dl_stop; ;;
        "")  sleep 1; continue ;;
        *)   curs_on; return ;;
      esac
    fi
    RC=$(cat "$DLRC" 2>/dev/null)
    printf "\033[K\n"
    if [ "${RC:-1}" = 0 ] && is_iso "$(dl_dest)"; then
      printf "  ${GN}Selesai. ISO siap dipakai di menu Ventoy.${R}\033[K\n"
    elif [ "${RC:-1}" = 0 ]; then
      printf "  ${YL}Selesai, tapi berkasnya tidak terlihat seperti ISO.${R}\033[K\n"
      printf "  ${DIM}Mungkin server mengirim halaman error.${R}\033[K\n"
    else
      printf "  ${RD}Unduhan berhenti.${R} ${DIM}%s sudah tersimpan dan TIDAK dihapus.${R}\033[K\n" "$(human "$NOW")"
      printf "  ${DIM}Pilih OS yang sama lagi untuk melanjutkan dari sini.${R}\033[K\n"
    fi
    rm -f "$DLINFO" "$DLPID" "$DLRC"
    printf "\033[J"
    curs_on; pause; return
  done
}

# ---- browser web (Dillo + X) ----------------------------------------------
XDISP=":1"
load_browser(){
  have dillo && have Xfbdev && return 0
  have tce-load || return 1
  # cadangan: kalau ekstensi belum termuat saat boot, muat sekarang dan
  # TAMPILKAN keluarannya - dulu ini gagal diam-diam dan cuma terlihat
  # sebagai "Browser tidak bisa dimuat" tanpa petunjuk apa pun.
  header "Menyiapkan browser"
  printf "  Memuat komponen browser, sekali saja…

"
  tce-load -i Xfbdev dillo 2>&1 | tail -15
  printf "
"
  have dillo && have Xfbdev
}
fb_size(){ # "1920 1080"
  v=$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null | tr -d ' \n')
  case "$v" in
    *,*) printf '%s %s' "${v%%,*}" "${v##*,}" ;;
    *)   printf '1024 768' ;;
  esac
}
dillo_conf(){
  W="$1"; H="$2"
  D="${HOME:-/home/tc}/.dillo"
  mkdir -p "$D" 2>/dev/null
  cat > "$D/dillorc" <<EOF
geometry=${W}x${H}+0+0
font_factor=1.5
show_tooltip=YES
# Tanpa baris ini Bing menganggap Dillo klien tak lazim dan hanya mengirim
# hasil seadanya (puluhan, tidak relevan). Dengan User-Agent biasa hasilnya
# normal seperti di browser lain.
http_user_agent="Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"
home="https://search.brave.com/search?q=linux+iso+download"
start_page="https://search.brave.com/search?q=linux+iso+download"
search_url="Brave https://search.brave.com/search?q=%s"
EOF
  # cookie diatur di cookiesrc, bukan dillorc. Sebagai pertahanan privasi,
  # cookie hanya DITERIMA untuk situs yang memang dipakai alat ini; selebihnya
  # ditolak (pelacak iklan, pihak ketiga, dll).
  printf 'DEFAULT REJECT\n' > "$D/cookiesrc" 2>/dev/null
  for d in .brave.com .duckduckgo.com .google.com .bing.com \
           .distrowatch.com .distro.se .distro2.com .sourceforge.net \
           .githubusercontent.com .github.com .kernel.org .releases.ubuntu.com \
           .cdimage.debian.org .download.opensuse.org .archlinux.org \
           .voidlinux.org .alpinelinux.org .fedoraproject.org; do
    printf '%s ACCEPT\n' "$d" >> "$D/cookiesrc" 2>/dev/null
  done
}
has_mouse(){ [ -e /dev/input/mice ] || [ -e /dev/input/mouse0 ]; }

# browser teks: sepenuhnya keyboard, tidak butuh mouse sama sekali
open_links(){
  U="$1"
  have links || { header "Browser web"; printf "  ${RD}Browser teks tidak tersedia.${R}\n"; pause; return; }
  LH="${HOME:-/home/tc}/.links"
  mkdir -p "$LH" 2>/dev/null
  [ -f "$LH/links.cfg" ] || : > "$LH/links.cfg" 2>/dev/null
  [ -f "$LH/html.cfg" ]  || : > "$LH/html.cfg"  2>/dev/null
  cls
  printf "\n  ${B}Browser${R}  ${DIM}(mode keyboard)${R}\n\n"
  printf "  ${CY}Semua pakai keyboard - tidak perlu mouse:${R}\n"
  printf "   ${B}Panah atas/bawah${R} pindah antar link    ${B}Enter${R} buka link\n"
  printf "   ${B}Panah kiri${R}       kembali              ${B}g${R}     ketik alamat lain\n"
  printf "   ${B}d${R}                unduh berkas         ${B}q${R}     keluar ke menu ZWARTOS\n\n"
  printf "  ${DIM}Unduhan dari browser disimpan ke %s${R}\n" "$VENTOY"
  sleep 3
  mount_ventoy 2>/dev/null
  ( cd "$VENTOY" 2>/dev/null || cd /tmp; links "$U" )
  stty sane 2>/dev/null
  cls
}

open_dillo(){
  U="$1"
  if ! load_browser; then
    printf "  ${RD}Browser grafis tidak bisa dimuat.${R}\n"; pause; return
  fi
  set -- $(fb_size); W=$1; H=$2
  dillo_conf "$W" "$H"
  cls
  printf "\n\n"
  ctext "membuka browser…" "$WH"
  printf "\n"
  ctext "tutup jendela browser untuk kembali ke menu ZWARTOS" "$DIM"
  mount_ventoy 2>/dev/null
  pkill Xfbdev 2>/dev/null; sleep 1
  for m in mousedev psmouse usbhid hid_generic hid_multitouch i2c_hid i2c_hid_acpi; do
    modprobe "$m" 2>/dev/null
  done
  sleep 1
  MOPT=""
  [ -e /dev/input/mice ] && MOPT="-mouse /dev/input/mice,3"
  Xfbdev "$XDISP" -screen "${W}x${H}" -br $MOPT >/dev/null 2>&1 &
  XPID=$!
  sleep 3
  ( cd "$VENTOY" 2>/dev/null || cd /tmp; DISPLAY="$XDISP" dillo "$U" >/tmp/dillo.log 2>&1 )
  DRC=$?
  kill "$XPID" 2>/dev/null; pkill Xfbdev 2>/dev/null; sleep 1
  stty sane 2>/dev/null
  printf '\033c' 2>/dev/null
  [ -f "$FONT" ] && /usr/sbin/loadfont < "$FONT" 2>/dev/null
  cls
  if [ "${DRC:-0}" != 0 ]; then
    header "Browser web"
    printf "  ${YL}Browser tertutup lebih cepat dari biasanya.${R} ${DIM}(kode %s)${R}\n\n" "${DRC:-?}"
    head -n 12 /tmp/dillo.log 2>/dev/null | sed 's/^/  /'
    pause
  fi
}

# pilih sendiri: mouse ada -> tampilan gambar, tidak ada -> mode keyboard
open_browser(){
  case "${ZWBROWSER:-auto}" in
    teks)   open_links "$1" ;;
    gambar) open_dillo "$1" ;;
    *)      if has_mouse; then open_dillo "$1"; else open_links "$1"; fi ;;
  esac
}

browser_mode_label(){
  case "${ZWBROWSER:-auto}" in
    teks)   printf 'keyboard (tanpa mouse)' ;;
    gambar) printf 'tampilan gambar (butuh mouse)' ;;
    *)      if has_mouse; then printf 'otomatis - mouse terdeteksi'
            else printf 'otomatis - mouse tidak ada, pakai keyboard'; fi ;;
  esac
}
browse_menu(){
  while :; do
    SEL=$({
      printf 'SEP\t%sCari di internet%s\n' "$GY" "$R"
      printf '__SEARCH__\t   Cari cepat…             %sketik yang dicari, hasil langsung terbuka%s\n' "$DIM" "$R"
      printf 'SEP\t \n'
      printf 'SEP\t%sBuka situs%s\n' "$GY" "$R"
      printf 'https://search.brave.com/search?q=linux+iso+download\t   Brave Search            %shasilnya bisa diklik langsung%s\n' "$DIM" "$R"
      printf 'https://distrowatch.com\t   DistroWatch             %sdaftar & rilis distro Linux%s\n' "$DIM" "$R"
      printf 'https://archive.org\t   Archive.org             %sarsip ISO versi lama%s\n' "$DIM" "$R"
      printf 'SEP\t \n'
      printf '__ASK__\t   Ketik alamat sendiri…\n'
      printf 'SEP\t \n'
      printf 'SEP\t%sMode tampilan browser%s\n' "$GY" "$R"
      printf '__MODE__\t   Ganti mode              %ssekarang: %s%s\n' "$DIM" "$(browser_mode_label)" "$R"
    } | fzf --ansi --delimiter="$TAB" --with-nth=2 $FZFOPTS --bind 'load:down' \
            --prompt='browser · cari: ' --header="Enter buka   ·   Esc kembali" --color="$FZFCLR" 2>/dev/null)
    [ -z "$SEL" ] && return
    U=$(printf '%s' "$SEL" | cut -f1)
    case "$U" in
      SEP)        continue ;;
      __MODE__)
        case "${ZWBROWSER:-auto}" in
          auto)   ZWBROWSER=gambar ;;
          gambar) ZWBROWSER=teks ;;
          *)      ZWBROWSER=auto ;;
        esac
        continue ;;
      __SEARCH__)
        header "Cari di internet"
        printf "  Ketik yang mau dicari, lalu Enter.\n"
        printf "  ${DIM}Contoh:  zorin os iso   ·   windows 11 iso   ·   driver wifi${R}\n\n"
        printf "  Cari: "
        read Q; [ -z "$Q" ] && continue
        Q=$(printf '%s' "$Q" | sed 's/[&#?]//g; s/^[ \t]*//; s/[ \t]*$//; s/[ \t][ \t]*/+/g')
        [ -z "$Q" ] && continue
        U="https://search.brave.com/search?q=$Q"
        ;;
      __ASK__)
        header "Buka alamat"
        printf "  Alamat situs ${DIM}(mis. distrowatch.com)${R}: "
        read U; [ -z "$U" ] && continue
        case "$U" in http://*|https://*) ;; *) U="https://$U";; esac
        ;;
    esac
    open_browser "$U"
  done
}

# ---- Ventoy: lewati menu, langsung boot ZWARTOS ---------------------------
# Pengaturan ini milik FLASHDISK (/ventoy/ventoy.json), bukan ISO - Ventoy
# membacanya sebelum ISO mana pun dijalankan. Kunci-kuncinya sesuai dokumentasi
# resmi Ventoy.
ventoy_fast(){
  header "Percepat boot Ventoy"
  mount_ventoy 2>/dev/null
  if ! mountpoint -q "$VENTOY" 2>/dev/null; then
    printf "  ${RD}Flashdisk Ventoy tidak terpasang.${R}\n"
    printf "  ${DIM}Pengaturan ini ditulis ke flashdisk, jadi flashdisknya harus terbaca.${R}\n"
    pause; return
  fi

  # cari ISO ZWARTOS di flashdisk - itu yang akan dijadikan pilihan bawaan
  find "$VENTOY" -maxdepth 3 -iname '*zwartos*.iso' 2>/dev/null > /tmp/zwiso
  N=$(wc -l < /tmp/zwiso 2>/dev/null); [ -z "$N" ] && N=0
  if [ "$N" -eq 0 ]; then
    printf "  ${YL}Tidak menemukan berkas ZWARTOS .iso di flashdisk.${R}\n\n"
    printf "  ${DIM}Salin dulu zwartos.iso ke flashdisk Ventoy, lalu ulangi.${R}\n"
    pause; return
  fi
  ISOPATH=$(head -1 /tmp/zwiso)
  if [ "$N" -gt 1 ] && have fzf; then
    SEL=$(awk -v v="$VENTOY" '{p=$0; sub("^" v, "", p); printf "%s\t   %s\n", $0, p}' /tmp/zwiso \
          | fzf --ansi --delimiter="$TAB" --with-nth=2 $FZFOPTS \
                --prompt='pilih ISO · ' --header="Ada beberapa ISO ZWARTOS - pilih yang dipakai" \
                --color="$FZFCLR" 2>/dev/null)
    [ -z "$SEL" ] && return
    ISOPATH=$(printf '%s' "$SEL" | cut -f1)
  fi
  REL=${ISOPATH#$VENTOY}
  case "$REL" in /*) ;; *) REL="/$REL" ;; esac

  printf "  ISO yang akan di-boot otomatis:\n    ${GN}%s${R}\n\n" "$REL"

  JSON="$VENTOY/ventoy/ventoy.json"
  if [ -f "$JSON" ]; then
    printf "  ${YL}Flashdisk ini sudah punya ventoy.json:${R}\n"
    head -n 12 "$JSON" | sed 's/^/    /'
    printf "\n  ${DIM}Salinannya akan disimpan sebagai ventoy.json.bak-zwartos.${R}\n"
    printf "  ${CY}Timpa dengan pengaturan ZWARTOS? (y/t) ${R}"
    read _a; case "$_a" in y|Y) ;; *) return ;; esac
    cp -f "$JSON" "$VENTOY/ventoy/ventoy.json.bak-zwartos" 2>/dev/null
  fi

  printf "\n  ${CY}Muat seluruh ISO ke RAM dulu (memdisk)? (y/${B}T${R}${CY}) ${R}"
  printf "\n  ${DIM}Ya  : sesudah tersalin ke RAM, ZWARTOS berjalan tanpa membaca${R}"
  printf "\n  ${DIM}      flashdisk lagi - lebih tahan terhadap USB yang rewel.${R}"
  printf "\n  ${DIM}Tidak: boot mulai lebih cepat karena tidak menyalin 125 MB dulu.${R}"
  printf "\n  ${DIM}Belum diuji di perangkat asli - kalau boot jadi gagal, hapus${R}"
  printf "\n  ${DIM}      berkas /ventoy/ventoy.json di flashdisk lewat komputer lain.${R}\n  > "
  read _m
  MEM=""
  case "$_m" in y|Y) MEM="ya" ;; esac

  mkdir -p "$VENTOY/ventoy" 2>/dev/null
  {
    printf '{\n'
    printf '    "control": [\n'
    printf '        { "VTOY_DEFAULT_IMAGE": "%s" },\n' "$REL"
    printf '        { "VTOY_MENU_TIMEOUT": "3" },\n'
    printf '        { "VTOY_SECONDARY_BOOT_MENU": "0" }\n'
    printf '    ]'
    if [ -n "$MEM" ]; then
      printf ',\n    "auto_memdisk": [\n        "%s"\n    ]\n' "$REL"
    else
      printf '\n'
    fi
    printf '}\n'
  } > "$JSON" 2>/dev/null

  if [ -s "$JSON" ]; then
    sync
    printf "\n  ${GN}Selesai.${R} Ventoy akan langsung memilih ZWARTOS dan\n"
    printf "  mem-boot-nya sendiri setelah 3 detik.\n\n"
    printf "  ${DIM}Isi berkas %s:${R}\n" "/ventoy/ventoy.json"
    sed 's/^/    /' "$JSON"
    printf "\n  ${DIM}Mau menu Ventoy kembali seperti semula? Hapus berkas itu,${R}\n"
    printf "  ${DIM}atau kembalikan ventoy.json.bak-zwartos.${R}\n"
  else
    printf "\n  ${RD}Gagal menulis ke flashdisk.${R} ${DIM}Mungkin ter-mount read-only.${R}\n"
  fi
  pause
}

# ---- tampilan --------------------------------------------------------------
header(){
  cls
  if netup; then
    _sd=$(ssid_aktif)
    if [ -n "$_sd" ]; then
      NS=$(printf "${GN}online${R} ${DIM}- %s${R}" "$_sd")
    else
      NS="${GN}online${R}"
    fi
  else
    NS="${RD}offline${R}"
  fi
  mountpoint -q "$VENTOY" 2>/dev/null && VS="${GN}ventoy siap${R}" || VS="${GY}ventoy belum${R}"
  printf "\n  ${B}ZWART OS${R}   ${DIM}v%s${R}" "$VERSION"
  [ -n "$1" ] && printf "   ${DIM}·${R}   ${WH}%s${R}" "$1"
  printf "\n  %b   ${DIM}·${R}   %b   ${DIM}·${R}   ${DIM}daftar: %s${R}\n\n" "$NS" "$VS" "$SRC"
}

help_screen(){
  header "Bantuan"
  printf "   ${WH}1${R}  Sambungkan internet\n"
  printf "      ${DIM}\"Konek WiFi\" - pilih jaringan, isi password.${R}\n"
  printf "      ${DIM}Pakai kabel? Pilih \"Konek LAN\".${R}\n\n"
  printf "   ${WH}2${R}  Pilih sistem operasinya\n"
  printf "      ${DIM}\"Pilih OS per distro\" - Ubuntu, Fedora, lalu varian & versinya.${R}\n"
  printf "      ${DIM}\"Cari semua OS\" kalau sudah tahu namanya.${R}\n"
  printf "      ${DIM}\"Peringkat DistroWatch\" - distro yang sedang ramai.${R}\n"
  printf "      ${DIM}Tidak ada di daftar? Pakai \"Browser web\" atau \"Unduh dari URL\".${R}\n\n"
  printf "   ${WH}3${R}  Tunggu selesai, lalu Reboot\n"
  printf "      ${DIM}ISO tersimpan di flashdisk Ventoy. Pilih ISO itu di menu Ventoy${R}\n"
  printf "      ${DIM}untuk mencoba atau memasangnya.${R}\n\n"
  hr
  printf "  ${CY}Tombol:${R} ${B}panah${R} pilih  ${B}ketik${R} menyaring  ${B}Enter${R} jalankan  ${B}Esc${R} kembali

"
  printf "  ${CY}Unduhan aman:${R} internet putus atau laptop mati - berkas tidak hilang.\n"
  printf "  Pilih OS yang sama lagi, unduhan otomatis dilanjutkan.\n"
  pause
}

splash(){
  cls; curs_off
  W=$(cols); H=$(rows)
  pad=$(( (W-60)/2 )); [ "$pad" -lt 0 ]&&pad=0; SP=$(printf "%${pad}s" "")
  oc=$(count_os); oc=${oc:-0}; dc=$(count_distro); dc=${dc:-0}
  netup && st="${GN}online${R}" || st="${GY}offline${R}"
  W1="${ESC}[1;38;5;255m"; W2="${ESC}[1;38;5;252m"; W3="${ESC}[1;38;5;249m"; W4="${ESC}[1;38;5;246m"
  top=$(( (H - 16) / 3 )); [ "$top" -lt 1 ] && top=1
  i=0; while [ "$i" -lt "$top" ]; do printf '\n'; i=$((i+1)); done
  printf "%s%s██████  ██   ██    ██    █████   ██████        ████    █████${R}\n" "$W1" "$SP"
  printf "%s%s    ██  ██   ██   ████   ██  ██    ██         ██  ██  ██    ${R}\n" "$W1" "$SP"
  printf "%s%s   ██   ██   ██  ██  ██  █████     ██         ██  ██   ████ ${R}\n" "$W2" "$SP"
  printf "%s%s  ██    ██ █ ██  ██████  ████      ██         ██  ██      ██${R}\n" "$W2" "$SP"
  printf "%s%s ██     ███████  ██  ██  ██ ██     ██         ██  ██      ██${R}\n" "$W3" "$SP"
  printf "%s%s██████   ██ ██   ██  ██  ██  ██    ██          ████   █████ ${R}\n" "$W4" "$SP"
  printf '\n'
  ctext "unduh sistem operasi ke flashdisk Ventoy lewat WiFi atau LAN" "$DIM"
  printf '\n'
  ctext "$oc pilihan OS dari $dc distro" "$GY"
  printf '\n\n'
  ctext "tekan Enter untuk mulai" "$WH"
  # footer menempel di baris terakhir
  used=$((top + 13))
  i=$used; while [ "$i" -lt $((H-1)) ]; do printf '\n'; i=$((i+1)); done
  left="  $GHREPO"; right="v$VERSION · $BUILDDATE  "
  fpad=$(( W - ${#left} - ${#right} )); [ "$fpad" -lt 1 ]&&fpad=1
  printf "${DIM}%s%${fpad}s%s${R}" "$left" "" "$right"
  stty echo icanon 2>/dev/null; read _x
  curs_on
}

# layar perpisahan + animasi, dipakai saat Reboot / Matikan
bye(){
  act="$1"; msg="$2"
  if dl_running; then
    header "Masih ada unduhan berjalan"
    printf "  ${YL}%s${R} baru %s%%.\n\n" "$(dl_name)" "$(dl_pct)"
    printf "  Kalau dilanjutkan sekarang, unduhan berhenti di titik ini.\n"
    printf "  ${DIM}Tidak hilang - bisa dilanjutkan nanti dengan memilih OS yang sama.${R}\n\n"
    printf "  Tetap lanjut? [y/${B}T${R}] "; read _yn
    case "$_yn" in y|Y) dl_stop ;; *) return ;; esac
  fi

  # Dulu di sini ada penjaga yang MENOLAK mematikan selama /proc/meminfo
  # melaporkan dirty page > 1 MB. Itu angka seluruh sistem, bukan flashdisk,
  # dan pada mesin yang hidup nyaris selalu di atas ambang itu - akibatnya
  # menu Reboot/Matikan menunggu 60 detik lalu menolak jalan.
  # Menolak mematikan justru lebih berbahaya: pemakai akan menekan tombol
  # power, dan itu benar-benar memutus tulisan di tengah jalan. Yang benar
  # adalah MENYELESAIKAN tulisannya - dan sync() memang menunggu sampai
  # semua data turun ke flashdisk sebelum kembali.
  header "Menyimpan data"
  safe_sync
  VENTOY_ADA=0
  if mountpoint -q "$VENTOY" 2>/dev/null; then
    VENTOY_ADA=1
    umount "$VENTOY" 2>/dev/null || umount -l "$VENTOY" 2>/dev/null
  fi
  sync
  if [ "$VENTOY_ADA" = 1 ]; then
    printf "  ${GN}Semua unduhan sudah tersimpan ke flashdisk.${R}\n"
    printf "  ${DIM}Flashdisk aman dicabut.${R}\n"
  else
    printf "  ${DIM}Tidak ada flashdisk terpasang.${R}\n"
  fi
  sleep 2

  stty sane 2>/dev/null
  cls; curs_off
  H=$(rows); top=$(( (H-8)/2 )); [ "$top" -lt 2 ] && top=2
  w=30; i=0
  while [ "$i" -le "$w" ]; do
    fill=""; j=0
    while [ "$j" -lt "$i" ]; do fill="$fill#"; j=$((j+1)); done
    rest=""; j=$i
    while [ "$j" -lt "$w" ]; do rest="$rest."; j=$((j+1)); done
    # gambar ulang seluruh layar tiap langkah - tidak bergantung pada
    # dukungan "kursor naik", yang bisa hilang setelah sesi X
    # kursor ke pojok lalu timpa - tanpa menghapus layar, jadi tidak berkedip
    printf '\033[H'
    k=0; while [ "$k" -lt "$top" ]; do printf '\n'; k=$((k+1)); done
    ctext "Z W A R T   O S" "$WH"
    printf '\n'
    ctext "$msg" "$DIM"
    printf '\n\n'
    ctext "[$fill$rest]" "$GY"
    i=$((i+1)); sleep "$TICK"
  done
  sync
  # layar bersih terakhir - tanpa teks skrip shutdown yang berantakan
  cls
  H=$(rows); top=$(( (H-3)/2 )); [ "$top" -lt 1 ] && top=1
  i=0; while [ "$i" -lt "$top" ]; do printf '\n'; i=$((i+1)); done
  ctext "Z W A R T   O S" "$WH"
  printf '\n'
  case "$act" in
    reboot)   ctext "menyalakan ulang…" "$DIM" ;;
    poweroff) ctext "aman dimatikan" "$DIM" ;;
  esac
  # layar ini menetap sampai mesin mati - di sinilah konfirmasi terbaca.
  # Hanya ditampilkan kalau flashdisk memang sempat terpasang, supaya
  # tidak menjanjikan sesuatu yang tidak terjadi.
  if [ "$VENTOY_ADA" = 1 ]; then
    printf '
'
    ctext "unduhan tersimpan di flashdisk" "$GN"
  fi
  sleep 1
  # -f = langsung, tanpa menjalankan skrip shutdown TinyCore.
  # Aman di sini: sistem hidup di RAM dan flashdisk sudah di-sync + di-umount
  # di atas. Tanpa -f, keluaran skrip shutdown mengotori layar terakhir.
  case "$act" in
    reboot)   reboot -f 2>/dev/null || reboot ;;
    poweroff) poweroff -f 2>/dev/null || poweroff ;;
  esac
  sleep 20
}

# ---- menu (fzf) ------------------------------------------------------------
FZFOPTS='--layout=reverse --height=100% --no-border --info=hidden --no-mouse --cycle --highlight-line --pointer='
FZFCLR='fg:250,fg+:15,bg:-1,bg+:4,hl:180,hl+:223,prompt:245,header:15,gutter:-1,query:255'

fzf_head(){
  if netup; then
    n="online"
    _sd=$(ssid_aktif) && n="online · $_sd"
  else
    n="offline"
  fi
  printf 'ZWART OS  v%s\n%s  ·  daftar: %s  ·  %s OS dari %s distro' \
         "$VERSION" "$n" "$SRC" "$(count_os)" "$(count_distro)"
}

# --- tingkat 3: versi ---
fzf_versi(){
  d="$1"; s="$2"
  C=$(catclr "$(awk -F'\t' -v d="$d" '$1==d{print $6; exit}' "$TMPL")")
  SEL=$(awk -F'\t' -v d="$d" -v s="$s" -v c="$C" -v r="${ESC}[0m" '
      $1==d && $2==s { printf "%s\t   %s%s%s\t%s\t%s\t%s\n", NR, c, ($3==""?$2:$3), r, $4, $5, $7 }' "$TMPL" \
    | fzf --ansi --delimiter="$TAB" --with-nth=2 $FZFOPTS \
          --prompt="$d $s · cari: " --header="Pilih versi   ·   Enter unduh   ·   Esc kembali" --color="$FZFCLR" 2>/dev/null)
  [ -z "$SEL" ] && return
  do_get "$(printf '%s' "$SEL"|cut -f5)" "$(printf '%s' "$SEL"|cut -f3)" "$(printf '%s' "$SEL"|cut -f4)"
}

# --- tingkat 2: varian ---
fzf_varian(){
  d="$1"
  nsub=$(awk -F'\t' -v d="$d" '$1==d && $2!=""' "$TMPL" | wc -l)
  ntot=$(awk -F'\t' -v d="$d" '$1==d' "$TMPL" | wc -l)
  if [ "$nsub" -eq 0 ] && [ "$ntot" -eq 1 ]; then
    L=$(awk -F'\t' -v d="$d" '$1==d{print; exit}' "$TMPL")
    do_get "$(printf '%s' "$L"|cut -f7)" "$(printf '%s' "$L"|cut -f4)" "$(printf '%s' "$L"|cut -f5)"
    return
  fi
  while :; do
    C=$(catclr "$(awk -F'\t' -v d="$d" '$1==d{print $6; exit}' "$TMPL")")
    SEL=$(awk -F'\t' -v d="$d" -v c="$C" -v r="${ESC}[0m" -v dm="${ESC}[2m" '
        $1==d { k=$2; if(!(k in seen)){ seen[k]=1; ord[++n]=k } cnt[k]++ }
        END{ for(i=1;i<=n;i++){ k=ord[i]
               if(cnt[k]>1) printf "%s\t   %s%-24s%s %s%s versi%s\n", k, c, k, r, dm, cnt[k], r
               else         printf "%s\t   %s%-24s%s\n", k, c, k, r } }' "$TMPL" \
      | fzf --ansi --delimiter="$TAB" --with-nth=2 $FZFOPTS \
            --prompt="$d · cari: " --header="Pilih varian   ·   Esc kembali" --color="$FZFCLR" 2>/dev/null)
    [ -z "$SEL" ] && return
    s=$(printf '%s' "$SEL" | cut -f1)
    n=$(awk -F'\t' -v d="$d" -v s="$s" '$1==d && $2==s' "$TMPL" | wc -l)
    if [ "$n" -le 1 ]; then
      L=$(awk -F'\t' -v d="$d" -v s="$s" '$1==d && $2==s{print; exit}' "$TMPL")
      do_get "$(printf '%s' "$L"|cut -f7)" "$(printf '%s' "$L"|cut -f4)" "$(printf '%s' "$L"|cut -f5)"
    else
      fzf_versi "$d" "$s"
    fi
  done
}

# --- tingkat 1: distro ---
fzf_distro(){
  while :; do
    SEL=$(awk -F'\t' -v r="${ESC}[0m" -v dm="${ESC}[2m" '
        function cc(c){ if(c~/DESKTOP/)return "\033[38;5;110m"; if(c~/SERVER/)return "\033[38;5;108m";
                        if(c~/RINGAN|ADVANCED|BSD/)return "\033[38;5;139m"; if(c~/SECURITY|PRIVACY/)return "\033[38;5;168m";
                        if(c~/UTIL|RESCUE/)return "\033[38;5;179m"; return "\033[38;5;252m" }
        { if(!($1 in s)){s[$1]=1; ord[++n]=$1; kat[$1]=$6} c[$1]++ }
        END{ for(i=1;i<=n;i++){ d=ord[i]
               if(c[d]>1) printf "%s\t   %s%-24s%s %s%s pilihan%s\n", d, cc(kat[d]), d, r, dm, c[d], r
               else       printf "%s\t   %s%-24s%s\n", d, cc(kat[d]), d, r } }' "$TMPL" \
      | fzf --ansi --delimiter="$TAB" --with-nth=2 $FZFOPTS \
            --prompt='distro · cari: ' --header="Pilih distro   ·   Esc kembali" --color="$FZFCLR" 2>/dev/null)
    [ -z "$SEL" ] && return
    fzf_varian "$(printf '%s' "$SEL" | cut -f1)"
  done
}

# --- daftar mendatar (semua OS / per kategori) ---
fzf_flat(){
  cat="$1"; ttl="$2"
  SEL=$(awk -F'\t' -v want="$cat" -v r="${ESC}[0m" -v dm="${ESC}[2m" '
      function cc(c){ if(c~/DESKTOP/)return "\033[38;5;110m"; if(c~/SERVER/)return "\033[38;5;108m";
                      if(c~/RINGAN|ADVANCED|BSD/)return "\033[38;5;139m"; if(c~/SECURITY|PRIVACY/)return "\033[38;5;168m";
                      if(c~/UTIL|RESCUE/)return "\033[38;5;179m"; return "\033[38;5;252m" }
      (want=="" || $6==want) { printf "%s\t%s%s%s\t%s\t%s\t%s\t%s%s%s\n", NR, cc($6), $7, r, $4, $5, $7, dm, $6, r }' "$TMPL" \
    | fzf --ansi --delimiter="$TAB" --with-nth=2,7 $FZFOPTS \
          --prompt="$ttl · cari: " --header="Ketik nama OS   ·   Enter unduh   ·   Esc kembali" --color="$FZFCLR" 2>/dev/null)
  [ -z "$SEL" ] && return
  # kolom 5 = nama OS, kolom 6 = kategori. Dulu terpakai kolom 6, sehingga
  # layar unduh menampilkan nama KATEGORI, bukan nama OS-nya.
  do_get "$(printf '%s' "$SEL"|cut -f5)" "$(printf '%s' "$SEL"|cut -f3)" "$(printf '%s' "$SEL"|cut -f4)"
}

fzf_kategori(){
  while :; do
    SEL=$(awk -F'\t' -v r="${ESC}[0m" -v dm="${ESC}[2m" '
        function cc(c){ if(c~/DESKTOP/)return "\033[38;5;110m"; if(c~/SERVER/)return "\033[38;5;108m";
                        if(c~/RINGAN|ADVANCED|BSD/)return "\033[38;5;139m"; if(c~/SECURITY|PRIVACY/)return "\033[38;5;168m";
                        if(c~/UTIL|RESCUE/)return "\033[38;5;179m"; return "\033[38;5;252m" }
        { if(!($6 in s)){s[$6]=1; ord[++n]=$6} c[$6]++ }
        END{ for(i=1;i<=n;i++) printf "%s\t   %s%-28s%s %s%s OS%s\n", ord[i], cc(ord[i]), ord[i], r, dm, c[ord[i]], r }' "$TMPL" \
      | fzf --ansi --delimiter="$TAB" --with-nth=2 $FZFOPTS \
            --prompt='kategori · cari: ' --header="Pilih kategori   ·   Esc kembali" --color="$FZFCLR" 2>/dev/null)
    [ -z "$SEL" ] && return
    fzf_flat "$(printf '%s' "$SEL" | cut -f1)" "$(printf '%s' "$SEL" | cut -f1)"
  done
}

layar_segarkan(){
  header "Segarkan daftar OS"; mount_ventoy 2>/dev/null; load_conf
  refresh_ui
  printf "  ${GN}Daftar OS: %s${R} ${DIM}(%s pilihan dari %s distro)${R}\n" \
    "$SRC" "$(count_os)" "$(count_distro)"; pause
}

layar_periksa_wifi(){
  header "Periksa WiFi"
  wifi_unblock
  WI=$(wifi_if)
  if [ -z "$WI" ]; then wifi_absent_screen; return; fi
  printf "  Kartu WiFi   : ${GN}%s${R}\n" "$WI"
  BS=$(wifi_block_state)
  printf "  Status blokir: %s\n" "${BS:-${GN}terbuka${R}}"
  printf "  Alamat IP    : %s\n" "$(punya_ip "$WI")"
  NETTS=-999
  netup && printf "  Internet     : ${GN}aktif${R}\n" \
        || printf "  Internet     : ${RD}tidak aktif${R}\n"
  printf "\n  ${DIM}Chip nirkabel:${R}\n"; wifi_chips | sed 's/^/    /'
  offer_report; pause
}

# Pintu kedua: semua yang tidak dibutuhkan pemula di layar pertama.
menu_lain(){
  while :; do
    {
      printf 'SEP\t%sCari OS dengan cara lain%s\n' "$GY" "$R"
      printf 'ACT_CAT\t   Jelajah per kategori    %sdesktop / server / ringan / security%s\n' "$DIM" "$R"
      printf 'ACT_WEB\t   Browser web             %scari sendiri di internet%s\n' "$DIM" "$R"
      printf 'ACT_URL\t   Unduh dari URL          %skalau sudah punya link .iso%s\n' "$DIM" "$R"
      printf 'SEP\t \n'
      printf 'SEP\t%sAlat%s\n' "$GY" "$R"
      printf 'ACT_REFRESH\t   Segarkan daftar OS\n'
      printf 'ACT_WDIAG\t   Periksa WiFi            %scek kartu, blokir, simpan laporan%s\n' "$DIM" "$R"
      printf 'ACT_VTOY\t   Percepat boot Ventoy    %slangsung ke ZWARTOS, tanpa memilih%s\n' "$DIM" "$R"
      printf 'ACT_HELP\t   Bantuan\n'
    } > /tmp/zlain
    # 'load:down' supaya kursor mulai di pilihan pertama, bukan judul kelompok
    SEL=$(fzf --ansi --delimiter="$TAB" --with-nth=2 $FZFOPTS --bind 'load:down' \
              --prompt='cari: ' --header="Alat lain   ·   Esc kembali" \
              --color="$FZFCLR" < /tmp/zlain 2>/dev/null)
    [ -z "$SEL" ] && return
    case "$(printf '%s' "$SEL"|cut -f1)" in
      ACT_CAT)     fzf_kategori ;;
      ACT_WEB)     browse_menu ;;
      ACT_URL)     do_url ;;
      ACT_REFRESH) layar_segarkan ;;
      ACT_WDIAG)   layar_periksa_wifi ;;
      ACT_VTOY)    ventoy_fast ;;
      ACT_HELP)    help_screen ;;
    esac
  done
}

fzf_main(){
  while :; do
    {
      printf 'SEP\t%s1. Sambungkan internet%s\n' "$GY" "$R"
      printf 'ACT_WIFI\t   Konek WiFi              %spilih jaringan, isi password%s\n' "$DIM" "$R"
      printf 'ACT_LAN\t   Konek LAN (kabel)       %scolok kabel, otomatis%s\n' "$DIM" "$R"
      printf 'SEP\t \n'
      printf 'SEP\t%s2. Pilih sistem operasi%s\n' "$GY" "$R"
      printf 'ACT_DISTRO\t   Pilih OS                %sjelajah %s distro%s\n' "$DIM" "$(count_distro)" "$R"
      printf 'ACT_ALL\t   Cari nama OS            %sketik langsung (%s pilihan)%s\n' "$DIM" "$(count_os)" "$R"
      if have_rank; then
        printf 'ACT_POP\t   Distro populer          %speringkat & rating DistroWatch%s\n' "$DIM" "$R"
      fi
      if dl_running; then
        printf 'SEP\t \n'
        printf 'ACT_DL\t   %s* Unduhan berjalan%s      %s%s - %s%%%s\n' "$GN" "$R" "$DIM" "$(dl_name)" "$(dl_pct)" "$R"
      elif dl_done; then
        printf 'SEP\t \n'
        printf 'ACT_DL\t   %s* Unduhan selesai%s       %s%s%s\n' "$GN" "$R" "$DIM" "$(dl_name)" "$R"
      fi
      printf 'SEP\t \n'
      printf 'ACT_MORE\t   Alat lain…              %sbrowser, kategori, bantuan%s\n' "$DIM" "$R"
      printf 'ACT_REBOOT\t   Reboot\n'
      printf 'ACT_OFF\t   Matikan\n'
    } > /tmp/zmain
    SEL=$(fzf --ansi --delimiter="$TAB" --with-nth=2 $FZFOPTS --bind 'load:down' \
              --prompt='cari: ' --header="$(fzf_head)" --color="$FZFCLR" < /tmp/zmain 2>/dev/null)
    [ -z "$SEL" ] && continue
    tag=$(printf '%s' "$SEL"|cut -f1)
    case "$tag" in
      ACT_DL)      dl_screen ;;
      ACT_WIFI)    connect_wifi ;;
      ACT_LAN)     connect_lan ;;
      ACT_DISTRO)  fzf_distro ;;
      ACT_ALL)     fzf_flat "" "semua OS" ;;
      ACT_POP)     fzf_populer ;;
      ACT_MORE)    menu_lain ;;
      ACT_REBOOT)  bye reboot   "menyimpan & menyalakan ulang…" ;;
      ACT_OFF)     bye poweroff "menyimpan & mematikan…" ;;
      SEP)         ;;
      *)           ;;
    esac
  done
}

# ---- menu cadangan (kalau fzf hilang) --------------------------------------
plain_ui(){
  while :; do
    header "mode sederhana"
    awk -F'\t' '{printf "   %3d. %s\n", NR, $7}' "$TMPL" | head -30
    printf "\n  ${B}w${R} WiFi   ${B}l${R} LAN   ${B}d${R} DistroWatch   ${B}r${R} segarkan   ${B}x${R} reboot   ${B}q${R} keluar\n"
    printf "  nomor / huruf: "; read k
    case "$k" in
      w|W) connect_wifi ;;  l|L) connect_lan ;;
      r|R) load_conf; refresh_ui ;;
      x|X) bye reboot "menyimpan & menyalakan ulang…" ;;
      q|Q) cls; exit 0 ;;
      ''|*[!0-9]*) ;;
      *) L=$(sed -n "${k}p" "$TMPL"); [ -n "$L" ] && do_get "$(printf '%s' "$L"|cut -f7)" "$(printf '%s' "$L"|cut -f4)" "$(printf '%s' "$L"|cut -f5)" ;;
    esac
  done
}

# ---- mulai -----------------------------------------------------------------
[ "$(id -u)" = 0 ] || { have sudo && exec sudo "$0" "$@"; }
export TERM=xterm-256color
# Berkas konfigurasi sementara dibuat tanpa izin untuk pengguna lain
umask 077
# jangan biarkan pesan kernel (mis. enumerasi USB) menimpa tampilan menu
dmesg -n 1 2>/dev/null
mount_ventoy 2>/dev/null; load_conf
# isi daftar dari bawaan dulu supaya splash tampil INSTAN (tak menunggu jaringan)
: > "$ACTIVE"; SRC="bawaan ISO"
[ -f "$BAKED" ] && cat "$BAKED" > "$ACTIVE"
[ -f "$LOCLIST" ] && { cat "$LOCLIST" > "$ACTIVE"; SRC="flashdisk"; }
rank_local
build_index
splash
printf "\n"
refresh_ui
if have fzf; then fzf_main; else plain_ui; fi
