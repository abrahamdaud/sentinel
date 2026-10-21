[CmdletBinding()]
param(
    [ValidateSet('start','scan','status','stop','help','install','stealth','tui')]
    [string]$Command = 'status',
    [string[]]$Path = @()
)

$ErrorActionPreference = 'Stop'

$script:AppName = 'SENTINEL'
$script:HomeDir = Join-Path $HOME '.sentinel'
$script:LogDir = Join-Path $script:HomeDir 'logs'
$script:ConfigFile = Join-Path $script:HomeDir 'config.json'
$script:StateFile = Join-Path $script:HomeDir 'state.json'
$script:StopFile = Join-Path $script:HomeDir 'stop.flag'
$script:WhitelistFile = Join-Path $script:HomeDir 'whitelist.txt'
$script:TamperFile = Join-Path $script:HomeDir 'tamper.json'
$script:DefaultScanInterval = 15

function Write-Log {
    param([string]$Level, [string]$Message)
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$ts] [$Level] $Message"
    New-Item -ItemType Directory -Force -Path $script:LogDir | Out-Null
    Add-Content -LiteralPath (Join-Path $script:LogDir 'sentinel.log') -Value $line -Encoding UTF8
}

function Get-PlatformInfo {
    $termux = ($env:TERMUX_VERSION -ne $null)
    $isAdmin = $false

    if ($IsWindows) {
        try {
            $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
            $isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
        }
        catch {
            $isAdmin = $false
        }
    }
    elseif ($IsLinux -or $termux) {
        try {
            $isAdmin = ((id -u) -eq 0) 2>$null
        }
        catch {
            $isAdmin = $false
        }
    }

    return [pscustomobject]@{
        Termux = $termux
        IsAdmin = [bool]$isAdmin
        Platform = if ($termux) { 'android-termux' } elseif ($IsWindows) { 'windows-powershell' } elseif ($IsLinux) { 'linux-powershell' } else { 'unknown' }
    }
}

function Initialize-Sentinel {
    New-Item -ItemType Directory -Force -Path $script:HomeDir | Out-Null
    New-Item -ItemType Directory -Force -Path $script:LogDir | Out-Null

    if (-not (Test-Path -LiteralPath $script:ConfigFile)) {
        $cfg = [ordered]@{
            ScanInterval = 15
            SuspiciousWords = @('r57','mimikatz','meterpreter','backdoor','rootkit','keylog','dropper','ngrok','frp','proxychains','malware','trojan','stealer','adb','scrcpy','vnc','teamviewer','anydesk','exfil')
            RemoteProcessNames = @('adb','scrcpy','vnc','tightvnc','teamviewer','anydesk','rdp','x11vnc','mimikatz','meterpreter')
            Whitelist = @()
            StealthMode = $true
            TuiRefreshMs = 16
        }
        $cfg | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:ConfigFile -Encoding UTF8
    }

    if (-not (Test-Path -LiteralPath $script:WhitelistFile)) {
        @('# Add full paths to ignore, one per line', '# Example: /data/data/com.termux/files/home/.local/share') | Set-Content -LiteralPath $script:WhitelistFile -Encoding UTF8
    }

    if (-not (Test-Path -LiteralPath $script:TamperFile)) {
        @{} | ConvertTo-Json | Set-Content -LiteralPath $script:TamperFile -Encoding UTF8
    }
}

function Load-Config {
    Initialize-Sentinel
    if (-not (Test-Path -LiteralPath $script:ConfigFile)) {
        return [pscustomobject]@{ ScanInterval = $script:DefaultScanInterval; SuspiciousWords = @(); RemoteProcessNames = @(); Whitelist = @(); StealthMode = $true; TuiRefreshMs = 16 }
    }

    $data = Get-Content -LiteralPath $script:ConfigFile -Raw | ConvertFrom-Json
    $cfg = [ordered]@{
        ScanInterval = if ($null -ne $data.ScanInterval) { [int]$data.ScanInterval } else { $script:DefaultScanInterval }
        SuspiciousWords = if ($null -ne $data.SuspiciousWords) { @($data.SuspiciousWords) } else { @('r57','mimikatz','meterpreter','backdoor','rootkit','keylog','dropper','ngrok','frp','proxychains','malware','trojan','stealer','adb','scrcpy','vnc','teamviewer','anydesk','exfil') }
        RemoteProcessNames = if ($null -ne $data.RemoteProcessNames) { @($data.RemoteProcessNames) } else { @('adb','scrcpy','vnc','tightvnc','teamviewer','anydesk','rdp','x11vnc','mimikatz','meterpreter') }
        Whitelist = if ($null -ne $data.Whitelist) { @($data.Whitelist) } else { @() }
        StealthMode = if ($null -ne $data.StealthMode) { [bool]$data.StealthMode } else { $true }
        TuiRefreshMs = if ($null -ne $data.TuiRefreshMs) { [int]$data.TuiRefreshMs } else { 16 }
    }

    return [pscustomobject]$cfg
}

function Load-Whitelist {
    if (-not (Test-Path -LiteralPath $script:WhitelistFile)) { return @() }
    $lines = Get-Content -LiteralPath $script:WhitelistFile -ErrorAction SilentlyContinue
    return @($lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not $_.StartsWith('#') })
}

function Save-State {
    param([hashtable]$Data)
    $Data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $script:StateFile -Encoding UTF8
}

function Get-DirectoryRoots {
    param([string[]]$Additional)

    $roots = @()
    foreach ($item in @($HOME, (Get-Location).Path, $Additional)) {
        if (-not [string]::IsNullOrWhiteSpace($item) -and (Test-Path -LiteralPath $item)) {
            $roots += $item
        }
    }

    if ($roots.Count -eq 0) {
        $roots += $HOME
    }

    return @($roots | Sort-Object -Unique)
}

function Test-IsWhitelisted {
    param([string]$Path, [string[]]$Whitelist)
    foreach ($entry in $Whitelist) {
        if ([string]::IsNullOrWhiteSpace($entry)) { continue }
        if ($Path.StartsWith($entry, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Get-SuspiciousProcesses {
    param([object]$Config)
    $results = @()
    $keywords = @($Config.SuspiciousWords | ForEach-Object { $_.ToLowerInvariant() })

    foreach ($proc in Get-Process -ErrorAction SilentlyContinue) {
        $name = [string]$proc.ProcessName
        $path = if ($null -ne $proc.Path) { [string]$proc.Path } else { '' }
        $combined = ("$name $path").ToLowerInvariant()

        foreach ($keyword in $keywords) {
            if ($combined.Contains($keyword)) {
                $results += [pscustomobject]@{ ProcessName = $name; Path = $path; Match = $keyword }
                break
            }
        }
    }

    return $results | Sort-Object ProcessName -Unique
}

function Get-SuspiciousFiles {
    param([string[]]$Roots, [object]$Config, [string[]]$Whitelist)
    $results = @()
    $keywords = @($Config.SuspiciousWords | ForEach-Object { $_.ToLowerInvariant() })

    foreach ($root in $Roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        try {
            $items = Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                if ($item.PSIsContainer) { continue }
                $full = $item.FullName
                if (Test-IsWhitelisted -Path $full -Whitelist $Whitelist) { continue }
                $lowerName = $item.Name.ToLowerInvariant()
                $lowerFull = $full.ToLowerInvariant()

                foreach ($keyword in $keywords) {
                    if ($lowerName.Contains($keyword) -or $lowerFull.Contains($keyword)) {
                        $results += [pscustomobject]@{ Path = $full; Match = $keyword; Type = $item.GetType().Name }
                        break
                    }
                }
            }
        }
        catch {
            Write-Log -Level 'WARN' -Message "Skipped scan for '$root': $($_.Exception.Message)"
        }
    }

    return $results | Sort-Object Path -Unique
}

function Get-RemoteControlHits {
    param([object]$Config)
    $results = @()
    $names = @($Config.RemoteProcessNames | ForEach-Object { $_.ToLowerInvariant() })

    foreach ($proc in Get-Process -ErrorAction SilentlyContinue) {
        $name = [string]$proc.ProcessName
        $lower = $name.ToLowerInvariant()
        if ($names -contains $lower) {
            $results += [pscustomobject]@{ ProcessName = $name; Path = if ($null -ne $proc.Path) { [string]$proc.Path } else { '' } }
        }
    }

    return $results | Sort-Object ProcessName -Unique
}

function Capture-TamperSnapshot {
    param([string[]]$Roots, [string[]]$Whitelist)
    $snapshot = [ordered]@{}

    foreach ($root in $Roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        try {
            $items = Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                if ($item.PSIsContainer) { continue }
                $full = $item.FullName
                if (Test-IsWhitelisted -Path $full -Whitelist $Whitelist) { continue }
                $hash = Get-FileHash -Algorithm SHA256 -Path $full -ErrorAction SilentlyContinue
                $snapshot[$full] = if ($null -ne $hash) { $hash.Hash } else { '' }
            }
        }
        catch {
            Write-Log -Level 'WARN' -Message "Tamper snapshot skipped for '$root': $($_.Exception.Message)"
        }
    }

    return $snapshot
}

function Check-TamperChanges {
    param([hashtable]$Previous, [hashtable]$Current)
    $changes = @()

    foreach ($key in $Current.Keys) {
        if (-not $Previous.ContainsKey($key)) {
            $changes += $key
            continue
        }
        if ($Previous[$key] -ne $Current[$key]) {
            $changes += $key
        }
    }

    foreach ($key in $Previous.Keys) {
        if (-not $Current.ContainsKey($key)) {
            $changes += $key
        }
    }

    return @($changes | Sort-Object -Unique)
}

function Invoke-ScanOnce {
    param([string[]]$Roots)
    $config = Load-Config
    $whitelist = Load-Whitelist
    $platform = Get-PlatformInfo
    $processHits = Get-SuspiciousProcesses -Config $config
    $fileHits = Get-SuspiciousFiles -Roots $Roots -Config $config -Whitelist $whitelist
    $remoteHits = Get-RemoteControlHits -Config $config

    $previousTamper = @{}
    if (Test-Path -LiteralPath $script:TamperFile) {
        try {
            $previousTamperJson = Get-Content -LiteralPath $script:TamperFile -Raw | ConvertFrom-Json
            if ($null -ne $previousTamperJson) {
                $previousTamper = @{}
                foreach ($p in $previousTamperJson.PSObject.Properties) {
                    $previousTamper[$p.Name] = [string]$p.Value
                }
            }
        }
        catch {
            $previousTamper = @{}
        }
    }

    $currentTamper = Capture-TamperSnapshot -Roots $Roots -Whitelist $whitelist
    $tamperChanges = Check-TamperChanges -Previous ([hashtable]$previousTamper) -Current ([hashtable]$currentTamper)
    $alerts = @()

    if ($platform.IsAdmin) { $alerts += 'Administrator or root privileges are active' }
    if ($processHits.Count -gt 0) { $alerts += 'Suspicious process detected' }
    if ($fileHits.Count -gt 0) { $alerts += 'Suspicious file pattern detected' }
    if ($remoteHits.Count -gt 0) { $alerts += 'Remote-control software detected' }
    if ($tamperChanges.Count -gt 0) { $alerts += 'Tamper change detected' }

    $report = [ordered]@{
        timestamp = (Get-Date).ToString('o')
        platform = $platform.Platform
        isTermux = $platform.Termux
        isAdmin = $platform.IsAdmin
        suspiciousProcesses = @($processHits)
        suspiciousFiles = @($fileHits)
        remoteControl = @($remoteHits)
        tamperChanges = @($tamperChanges)
        alerts = @($alerts)
        scannedRoots = @($Roots)
    }

    Save-State -Data ([hashtable]$report)
    $currentTamper | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:TamperFile -Encoding UTF8
    Write-Log -Level 'INFO' -Message "Scan complete. Alerts=$($alerts.Count)"
    return [pscustomobject]$report
}

function Install-Sentinel {
    $binDir = Join-Path $HOME '.local/bin'
    New-Item -ItemType Directory -Force -Path $binDir | Out-Null

    $scriptPath = $MyInvocation.MyCommand.Path
    $launcherPath = Join-Path $binDir 'sentinel'
    Copy-Item -LiteralPath $scriptPath -Destination $launcherPath -Force
    
    if (-not (Test-Path -LiteralPath $launcherPath)) {
        throw 'Failed to install sentinel launcher.'
    }

    Initialize-Sentinel
    Write-Log -Level 'INFO' -Message 'SENTINEL installed successfully'
    Write-Host "[SENTINEL] Installed to $launcherPath"
    Write-Host "[SENTINEL] Run: sentinel start"
}

function Start-Monitor {
    param([string[]]$Roots, [switch]$StealthMode, [switch]$TuiMode)

    Initialize-Sentinel
    $config = Load-Config
    $roots = Get-DirectoryRoots -Additional $Roots
    Write-Log -Level 'INFO' -Message 'SENTINEL monitor started'

    if ($TuiMode) {
        while (-not (Test-Path -LiteralPath $script:StopFile)) {
            $report = Invoke-ScanOnce -Roots $roots
            Clear-Host
            Write-Host '=== SENTINEL TUI ===' -ForegroundColor Cyan
            Write-Host "Platform : $($report.platform)"
            Write-Host "Termux   : $($report.isTermux)"
            Write-Host "Admin    : $($report.isAdmin)"
            Write-Host "Alerts   : $($report.alerts.Count)"
            if ($report.alerts.Count -gt 0) {
                Write-Host "Latest   : $($report.alerts[0])" -ForegroundColor Yellow
            }
            else {
                Write-Host 'Latest   : No suspicious activity' -ForegroundColor Green
            }
            Start-Sleep -Milliseconds $config.TuiRefreshMs
        }
        Remove-Item -LiteralPath $script:StopFile -Force -ErrorAction SilentlyContinue
        return
    }

    Write-Host "[$script:AppName] Monitor started. Press Ctrl+C to stop." -ForegroundColor Cyan
    while (-not (Test-Path -LiteralPath $script:StopFile)) {
        $report = Invoke-ScanOnce -Roots $roots

        if ($StealthMode) {
            if ($report.alerts.Count -gt 0) {
                foreach ($alert in $report.alerts) {
                    Write-Log -Level 'ALERT' -Message $alert
                }
            }
            Start-Sleep -Seconds $config.ScanInterval
            continue
        }

        if ($report.alerts.Count -gt 0) {
            foreach ($alert in $report.alerts) {
                Write-Host "[ALERT] $alert" -ForegroundColor Red
                Write-Log -Level 'ALERT' -Message $alert
            }
        }
        else {
            Write-Host "[OK] No suspicious activity detected" -ForegroundColor Green
        }

        Start-Sleep -Seconds $config.ScanInterval
    }

    Remove-Item -LiteralPath $script:StopFile -Force -ErrorAction SilentlyContinue
    Write-Log -Level 'INFO' -Message 'SENTINEL monitor stopped'
    Write-Host "[$script:AppName] Monitor stopped." -ForegroundColor Yellow
}

function Stop-Monitor {
    Set-Content -LiteralPath $script:StopFile -Value (Get-Date).ToString('o') -Encoding UTF8
    Write-Log -Level 'INFO' -Message 'Stop flag created'
    Write-Host "[$script:AppName] Stop requested." -ForegroundColor Yellow
}

function Show-Status {
    Initialize-Sentinel
    if (Test-Path -LiteralPath $script:StateFile) {
        $data = Get-Content -LiteralPath $script:StateFile -Raw | ConvertFrom-Json
        Write-Host "[$script:AppName] Status"
        Write-Host "Platform      : $($data.platform)"
        Write-Host "Termux        : $($data.isTermux)"
        Write-Host "Admin/Root    : $($data.isAdmin)"
        Write-Host "Last scan     : $($data.timestamp)"
        if ($data.alerts.Count -gt 0) { Write-Host "Alerts        : $($data.alerts -join '; ')" }
        else { Write-Host 'Alerts        : none' }
    }
    else {
        Write-Host "[$script:AppName] No state file yet. Run 'pwsh -File sentinel.ps1 scan' first."
    }
}

function Show-Usage {
    @'
SENTINEL - Local Security Monitor

Usage:
  pwsh -File sentinel.ps1 start
  pwsh -File sentinel.ps1 stealth
  pwsh -File sentinel.ps1 tui
  pwsh -File sentinel.ps1 scan
  pwsh -File sentinel.ps1 status
  pwsh -File sentinel.ps1 stop
  pwsh -File sentinel.ps1 install

Notes:
  - Offline and local-only.
  - Compatible with PowerShell Core and Termux.
  - Logs are stored in ~/.sentinel/logs.
'@ | Write-Host
}

Initialize-Sentinel
$roots = Get-DirectoryRoots -Additional $Path

switch ($Command.ToLowerInvariant()) {
    'start' { Start-Monitor -Roots $roots -StealthMode:$false }
    'scan' { $result = Invoke-ScanOnce -Roots $roots; $result | ConvertTo-Json -Depth 8 | Write-Host }
    'status' { Show-Status }
    'stop' { Stop-Monitor }
    'help' { Show-Usage }
    'install' { Install-Sentinel }
    'stealth' { Start-Monitor -Roots $roots -StealthMode:$true }
    'tui' { Start-Monitor -Roots $roots -TuiMode }
    default { Show-Usage }
}
