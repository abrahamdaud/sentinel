# Usage Guide

This is the quick reference for regular use of SENTINEL.

## Installation

```bash
chmod +x sentinel install.sh sentinel-native.sh
./install.sh
```

This installs the launcher to `~/.local/bin` and prepares the local runtime directory at `~/.sentinel`.

## Common commands

### Start monitoring

```bash
sentinel start
```

### Run in stealth mode

```bash
sentinel stealth
```

### Open the lightweight TUI dashboard

```bash
sentinel tui
```

### Run one scan immediately

```bash
sentinel scan
```

### Check latest status

```bash
sentinel status
```

### Stop monitoring

```bash
sentinel stop
```

### Show help

```bash
sentinel help
```

## PowerShell direct usage

```powershell
pwsh -File sentinel.ps1 start
pwsh -File sentinel.ps1 stealth
pwsh -File sentinel.ps1 tui
pwsh -File sentinel.ps1 status
pwsh -File sentinel.ps1 scan
pwsh -File sentinel.ps1 stop
```

## Runtime notes

- Default scan interval: 15 seconds
- Logs are stored in `~/.sentinel/logs`
- Local configuration is stored in `~/.sentinel/config.json`
- Whitelist entries can be added in `~/.sentinel/whitelist.txt`
- Startup persistence is attempted via `cron @reboot` when available

## Troubleshooting

### Command not found

Make sure your PATH includes `~/.local/bin`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### No runtime found

Install PowerShell Core or use the bash-native launcher:

```bash
pkg install powershell
```

### No output in stealth mode

Stealth mode intentionally keeps output minimal. Use `sentinel status` or `sentinel scan` for explicit status checks.
