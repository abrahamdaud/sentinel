# SENTINEL

SENTINEL adalah proyek keamanan lokal untuk Windows PowerShell dan Termux yang berjalan sepenuhnya secara offline. Aplikasi ini tidak memerlukan server, API, atau koneksi internet untuk aktif. Fokus utamanya adalah memonitor sistem lokal, mendeteksi proses mencurigakan, file yang berpotensi berbahaya, serta perubahan file sensitif secara otomatis.

## Fitur utama

- Pemantauan proses lokal secara realtime
- Deteksi proses yang mirip malware, rootkit, keylogger, trojan, atau alat remote control
- Pemindaian berkas untuk pola mencurigakan pada nama atau path file
- Deteksi perubahan file penting dengan teknik SHA256 snapshot (anti-tamper)
- Whitelist path agar folder tertentu tidak ikut dipindai
- Mode silent / stealth-friendly agar lebih aman saat berjalan di perangkat personal
- Logging lokal otomatis di folder ~/.sentinel/logs
- kompatibel dengan PowerShell dan Termux

## Arsitektur

Proyek ini terdiri dari 3 komponen utama:

- `sentinel.ps1` — versi utama berbasis PowerShell
- `sentinel-native.sh` — versi fallback berbasis bash untuk Termux/Linux
- `sentinel` — launcher otomatis yang memilih runtime yang tersedia

## Prasyarat

### Windows / PowerShell

- Windows 10/11
- PowerShell 7+ (pwsh) direkomendasikan

### Termux / Android

- Termux terinstall
- `pwsh` bila ingin memakai versi PowerShell
- atau cukup jalankan launcher `./sentinel` yang akan otomatis memilih runtime yang tersedia

## Instalasi otomatis

Masuk ke folder project, lalu jalankan:

```bash
chmod +x sentinel sentinel-native.sh
./sentinel install
```

Kalau Anda ingin instalasi versi manual tanpa launcher otomatis, cukup jalankan:

```bash
chmod +x sentinel sentinel-native.sh sentinel.ps1
```

## Cara penggunaan

### PowerShell

```powershell
pwsh -File sentinel.ps1 start
pwsh -File sentinel.ps1 status
pwsh -File sentinel.ps1 scan
pwsh -File sentinel.ps1 stop
```

### Termux / Linux

```bash
./sentinel start
./sentinel status
./sentinel scan
./sentinel stop
```

## Mode silent / stealth-friendly

SENTINEL memiliki mode yang dibuat agar tampak lebih "siluman" ketika dijalankan di lingkungan lokal:

- tidak mengirim data ke server luar
- tidak memerlukan internet
- proses berjalan di background secara lokal
- output dibuat sederhana dan log disimpan ke file
- operasi hanya di perangkat lokal

Mode ini dapat dikombinasikan dengan:

- whitelist path tertentu
- menyesuaikan interval scan
- membatasi folder yang dipantau
- menghilangkan output verbose saat dijalankan tanpa interaksi user

## Konfigurasi

Semua konfigurasi default dibuat otomatis pada folder:

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

Proyek ini dibuat untuk kebutuhan pemantauan dan deteksi lokal. Ia bukan alat antivirus komersial dan tidak menggantikan solusi keamanan profesional. KEGUNAANNYA TERBATAS PADA ANALISIS DAN PEMBERITAHUAN DI MESIN LOKAL.

## Lisensi

MIT
