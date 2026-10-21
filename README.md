# SENTINEL

Offline Local Security Monitoring for PowerShell & Termux

SENTINEL is a lightweight local security monitor for PowerShell and Termux. It runs completely offline and does not require any external server, API, or internet connection. The project is designed to watch local activity, detect suspicious processes, suspicious file patterns, and changes in important files while staying low-overhead and quiet.

## Features

- Local process monitoring
- Suspicious process detection
- Suspicious file path/name detection
- File hash snapshot and anti-tamper monitoring
- Remote-control software detection
- Whitelist support
- Quiet stealth mode
- Lightweight TUI dashboard
- Local-only logging
- No external service dependency

## Architecture

- `sentinel.ps1` — PowerShell implementation
- `sentinel-native.sh` — Bash fallback for Linux/Termux
- `sentinel` — launcher
- `install.sh` — installer and persistence setup

## Requirements

### Windows / PowerShell

- Windows 10/11
- PowerShell 7+

### Termux / Android

- Termux installed
- `pwsh` recommended
- Native bash mode also available

## Installation

```bash
chmod +x sentinel install.sh sentinel-native.sh
./install.sh
```

Then:

```bash
sentinel start
```

Or run directly from the project folder:

```bash
./sentinel start
```

## Usage

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

## Stealth Mode and TUI

SENTINEL is designed to be quiet:

- minimal terminal output
- logs stored locally only
- alerts only on meaningful changes
- no external traffic
- no cloud or API dependency

The TUI is optimized for low-overhead and smooth terminal refresh without heavy CPU usage.

## Configuration

All default configuration is generated automatically under:

```bash
~/.sentinel/
```

Files created:

- `config.json`
- `whitelist.txt`
- `state.json`
- `tamper.json`
- `logs/sentinel.log`

## Startup Persistence

On Linux and Termux environments with `crontab` available, the installer adds a lightweight `@reboot` cron entry to start SENTINEL automatically when the device boots.

## Notes

This project is intended as a local monitoring and awareness tool. It is not a full commercial antivirus solution and should be treated as a lightweight local security monitor, not a definitive endpoint protection platform.

## License

MIT
