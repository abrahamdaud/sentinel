# SENTINEL

SENTINEL is a lightweight local security monitor designed for PowerShell and Termux. It runs completely offline and does not require any external server, API, or internet connection. The project is intended to monitor local system activity, detect suspicious processes, suspicious file patterns, and potential file tampering while staying low-overhead and non-intrusive.

## Key Features

- Local process monitoring
- Suspicious process detection
- Suspicious file path/name detection
- File hash snapshot and anti-tamper monitoring
- Remote-control software detection
- Whitelist support
- Quiet stealth mode
- Lightweight TUI dashboard
- Local logging only
- No external dependency

## Architecture

- `sentinel.ps1` — PowerShell implementation
- `sentinel-native.sh` — Bash fallback implementation
- `sentinel` — launcher
- `install.sh` — installation and persistence setup

## Requirements

### Windows / PowerShell

- Windows 10/11
- PowerShell 7+

### Termux / Android

- Termux installed
- `pwsh` recommended for PowerShell mode
- Native bash mode is also available

## Installation

From the project directory:

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
- logs saved locally only
- alert only on meaningful changes
- no external traffic
- no cloud or API dependency

The TUI is optimized for low overhead and fast refresh, aiming for smooth terminal updates without heavy CPU usage.

## Configuration

Default configuration is generated under:

```bash
~/.sentinel/
```

Files generated:

- `config.json`
- `whitelist.txt`
- `state.json`
- `tamper.json`
- `logs/sentinel.log`

## Startup Persistence

On Linux and Termux environments with `crontab` available, the install step adds a lightweight `@reboot` cron entry to start SENTINEL automatically when the device boots.

## Release Checklist

Before publishing or release, verify the following:

- Installer works on target system
- PATH is configured correctly
- `sentinel start` runs without errors
- `sentinel status` shows valid state
- `sentinel scan` performs a local scan correctly
- `sentinel stop` stops the monitor cleanly
- `whitelist.txt` works as expected
- stealth mode stays quiet and minimal
- TUI remains responsive and does not consume excessive CPU
- logs are written locally
- no internet or external service dependency exists
- startup persistence works where supported
- no unsupported commands are causing runtime issues

## Notes

This project is intended as a local monitoring and awareness tool. It is not a full commercial antivirus solution and should be treated as a lightweight local security monitor, not a definitive endpoint protection platform.

## License

MIT
