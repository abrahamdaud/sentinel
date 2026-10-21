# SENTINEL

SENTINEL adalah proyek keamanan lokal untuk Windows PowerShell dan Termux yang berjalan sepenuhnya secara offline. Aplikasi ini tidak memerlukan server, API, atau koneksi internet untuk aktif. Fokus utamanya adalah memonitor sistem lokal, mendeteksi proses mencurigakan, file yang berpotensi berbahaya, dan perubahan file sensitif secara otomatis.

## Fitur utama

- Pemantauan proses lokal secara realtime
- Deteksi proses yang mirip malware, rootkit, keylogger, trojan, atau alat remote control
- Pemindaian berkas untuk pola mencurigakan pada nama atau path file
- Deteksi perubahan file penting menggunakan snapshot SHA256 (anti-tamper)
- Whitelist path agar folder tertentu tidak ikut dipindai
- Mode stealth / silent yang lebih halus dan minim gangguan
- TUI ringan untuk monitoring visual dengan refresh cepat
- Logging lokal otomatis di folder ~/.sentinel/logs
- Kompatibel dengan PowerShell dan Termux

## Arsitektur

Proyek ini terdiri dari 4 komponen utama:

- `sentinel.ps1` — versi utama berbasis PowerShell
- `sentinel-native.sh` — versi fallback berbasis bash untuk Termux/Linux
- `sentinel` — launcher otomatis yang memilih runtime yang tersedia
- `install.sh` — installer yang menyalin launcher ke `~/.local/bin` dan menyiapkan struktur kerja

## Prasyarat

### Windows / PowerShell

- Windows 10/11
- PowerShell 7+ direkomendasikan

### Termux / Android

- Termux sudah terinstall
- `pwsh` bila ingin memakai versi PowerShell
- bila tidak ada `pwsh`, launcher akan otomatis memakai versi bash native

## Instalasi otomatis

Masuk ke folder project, lalu jalankan:

```bash
chmod +x sentinel install.sh sentinel-native.sh
./install.sh
```

Setelah itu, jalankan:

```bash
sentinel start
```

Atau kalau Anda ingin menjalankan langsung dari folder project:

```bash
./sentinel start
```

## Cara penggunaan

### PowerShell

```powershell
pwsh -File sentinel.ps1 start
pwsh -File sentinel.ps1 stealth
pwsh -File sentinel.ps1 tui
pwsh -File sentinel.ps1 status
pwsh -File sentinel.ps1 scan
pwsh -File sentinel.ps1 stop
```

### Termux / Linux

```bash
./sentinel start
./sentinel stealth
./sentinel tui
./sentinel status
./sentinel scan
./sentinel stop
```

## Mode stealth dan TUI

SENTINEL dibuat untuk berjalan dengan karakteristik sebagai berikut:

- tidak mengirim data ke server luar
- tidak memerlukan internet
- output di terminal dibuat seminimal mungkin dalam mode stealth
- monitoring dilakukan secara lokal dan ringan
- TUI menampilkan status ringkas dengan refresh sekitar 60 FPS seperti tampilan dashboard teks
- log tetap disimpan di file lokal agar audit tetap tersedia

## Konfigurasi

Semua konfigurasi default dibuat otomatis di folder:

```bash
~/.sentinel/
```

File yang dibuat:

- `config.json` — pengaturan awal
- `whitelist.txt` — path yang diabaikan
- `state.json` — hasil scan terakhir
- `tamper.json` — snapshot file untuk deteksi perubahan
- `logs/sentinel.log` — riwayat log

## Catatan keamanan

Proyek ini dibuat untuk kebutuhan pemantauan dan deteksi lokal. Ia bukan alat antivirus komersial dan tidak menggantikan solusi keamanan profesional. Kegunaan utamanya adalah analisis, pemberitahuan, dan audit keamanan di mesin lokal.

## Lisensi

MIT
