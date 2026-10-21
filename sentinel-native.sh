#!/usr/bin/env bash
set -u

APP_NAME="SENTINEL"
APP_HOME="${HOME}/.sentinel"
LOG_DIR="${APP_HOME}/logs"
CONFIG_FILE="${APP_HOME}/config.json"
STATE_FILE="${APP_HOME}/state.json"
STOP_FILE="${APP_HOME}/stop.flag"
WHITELIST_FILE="${APP_HOME}/whitelist.txt"
TAMPER_FILE="${APP_HOME}/tamper.json"

mkdir -p "${APP_HOME}" "${LOG_DIR}"

log() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "${LOG_DIR}/sentinel.log"
}

ensure_defaults() {
  if [ ! -f "${CONFIG_FILE}" ]; then
    cat > "${CONFIG_FILE}" <<'EOF'
{
  "ScanInterval": 15,
  "SuspiciousWords": [
    "r57", "mimikatz", "meterpreter", "backdoor", "rootkit", "keylog",
    "dropper", "ngrok", "frp", "proxychains", "malware", "trojan",
    "stealer", "adb", "scrcpy", "vnc", "teamviewer", "anydesk", "exfil"
  ],
  "RemoteProcessNames": [
    "adb", "scrcpy", "vnc", "tightvnc", "teamviewer", "anydesk",
    "rdp", "x11vnc", "mimikatz", "meterpreter"
  ],
  "Whitelist": [],
  "StealthMode": true,
  "TuiRefreshMs": 16
}
EOF
  fi

  if [ ! -f "${WHITELIST_FILE}" ]; then
    cat > "${WHITELIST_FILE}" <<'EOF'
# Add full paths to ignore, one per line.
# Example: /data/data/com.termux/files/home/.cache
EOF
  fi

  if [ ! -f "${TAMPER_FILE}" ]; then
    printf '{}\n' > "${TAMPER_FILE}"
  fi
}

load_whitelist() {
  if [ -f "${WHITELIST_FILE}" ]; then
    grep -vE '^[[:space:]]*#|^[[:space:]]*$' "${WHITELIST_FILE}" || true
  fi
}

is_whitelisted() {
  local target="$1"
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    case "$target" in
      "$entry"*) return 0 ;;
    esac
  done < <(load_whitelist)
  return 1
}

scan_processes() {
  local line name path combined keyword
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    name="$(printf '%s\n' "$line" | awk '{print $2}')"
    path="$(printf '%s\n' "$line" | awk '{$1=""; $2=""; print $0}' | sed 's/^ *//')"
    combined="$(printf '%s %s' "$name" "$path" | tr '[:upper:]' '[:lower:]')"

    for keyword in r57 mimikatz meterpreter backdoor rootkit keylog dropper ngrok frp proxychains malware trojan stealer adb scrcpy vnc teamviewer anydesk exfil; do
      if printf '%s' "$combined" | grep -qi -- "$keyword"; then
        printf '%s|%s\n' "$name" "$keyword"
        break
      fi
    done
  done < <(ps -eo pid,comm,args --no-headers 2>/dev/null || true)
}

scan_files() {
  local root="$1"
  local file name lower keyword
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    is_whitelisted "$file" && continue

    name="$(basename "$file")"
    lower="$(printf '%s %s' "$file" "$name" | tr '[:upper:]' '[:lower:]')"

    for keyword in r57 mimikatz meterpreter backdoor rootkit keylog dropper ngrok frp proxychains malware trojan stealer adb scrcpy vnc teamviewer anydesk exfil; do
      if printf '%s' "$lower" | grep -qi -- "$keyword"; then
        printf '%s|%s\n' "$file" "$keyword"
        break
      fi
    done
  done < <(find "$root" -type f 2>/dev/null | sort || true)
}

capture_snapshot() {
  local root="$1"
  local file hash
  : > "${APP_HOME}/.tamper.current"

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    is_whitelisted "$file" && continue

    if command -v sha256sum >/dev/null 2>&1; then
      hash="$(sha256sum "$file" 2>/dev/null | awk '{print $1}')"
      printf '%s %s\n' "$hash" "$file" >> "${APP_HOME}/.tamper.current"
    fi
  done < <(find "$root" -type f 2>/dev/null | sort || true)
}

compare_snapshot() {
  local prev="$1"
  local curr="$2"

  if [ ! -f "$prev" ]; then
    return 0
  fi

  if ! diff -q "$prev" "$curr" >/dev/null 2>&1; then
    diff -u "$prev" "$curr" || true
  fi
}

run_scan() {
  local process_hits=""
  local file_hits=""
  local remote_hits=""
  local tamper_hits=""
  local alert_list=""
  local root

  process_hits="$(scan_processes || true)"

  for root in "$HOME" "$PWD"; do
    [ -d "$root" ] || continue
    file_hits+="$(scan_files "$root" || true)"
    file_hits+=$'\n'
  done

  for proc in adb scrcpy vnc tightvnc teamviewer anydesk rdp x11vnc mimikatz meterpreter; do
    if ps -eo comm --no-headers 2>/dev/null | grep -qi "^${proc}$"; then
      remote_hits+="${proc}"$'\n'
    fi
  done

  local before="${APP_HOME}/.tamper.previous"
  local current="${APP_HOME}/.tamper.current"

  if [ -f "$before" ]; then
    capture_snapshot "$HOME"
    tamper_hits="$(compare_snapshot "$before" "$current" || true)"
  else
    capture_snapshot "$HOME"
  fi

  cp -f "$current" "$before"

  if [ "$(id -u 2>/dev/null || echo 0)" = "0" ]; then
    alert_list+=$'Administrator or root privileges are active\n'
  fi

  if [ -n "$process_hits" ]; then
    alert_list+=$'Suspicious process detected\n'
  fi

  if [ -n "$file_hits" ]; then
    alert_list+=$'Suspicious file pattern detected\n'
  fi

  if [ -n "$remote_hits" ]; then
    alert_list+=$'Remote-control software detected\n'
  fi

  if [ -n "$tamper_hits" ]; then
    alert_list+=$'Tamper change detected\n'
  fi

  local ts
  ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

  cat > "${STATE_FILE}" <<EOF
{
  "timestamp": "${ts}",
  "platform": "$(uname -s)",
  "isTermux": "$( [ -d /data/data/com.termux ] || [ -n "${TERMUX_VERSION:-}" ] && echo true || echo false )",
  "isAdmin": "$( [ "$(id -u 2>/dev/null || echo 0)" = "0" ] && echo true || echo false )",
  "processHits": "$(printf '%s' "$process_hits" | tr '\n' ';' | sed 's/;*$//')",
  "fileHits": "$(printf '%s' "$file_hits" | tr '\n' ';' | sed 's/;*$//')",
  "remoteHits": "$(printf '%s' "$remote_hits" | tr '\n' ';' | sed 's/;*$//')",
  "tamperHits": "$(printf '%s' "$tamper_hits" | tr '\n' ';' | sed 's/;*$//')",
  "alerts": "$(printf '%s' "$alert_list" | tr '\n' ';' | sed 's/;*$//')"
}
EOF

  if [ -n "$alert_list" ]; then
    printf '%s\n' "$alert_list" | while IFS= read -r line; do
      [ -n "$line" ] || continue
      echo "[ALERT] $line"
      log 'ALERT' "$line"
    done
  else
    echo "[OK] No suspicious activity detected"
  fi
}

show_status() {
  ensure_defaults
  if [ -f "${STATE_FILE}" ]; then
    echo "[${APP_NAME}] Status"
    cat "${STATE_FILE}"
  else
    echo "[${APP_NAME}] No state file yet. Run './sentinel scan' first."
  fi
}

show_usage() {
  cat <<'EOF'
SENTINEL - Local Security Monitor

Usage:
  ./sentinel start
  ./sentinel stealth
  ./sentinel tui
  ./sentinel scan
  ./sentinel status
  ./sentinel stop
  ./sentinel install
  ./sentinel help

Notes:
  - Offline and local-only.
  - Works on Termux and Linux shells.
  - Logs are stored in ~/.sentinel/logs
EOF
}

start_loop() {
  local mode="${1:-normal}"
  ensure_defaults
  rm -f "${STOP_FILE}"
  log 'INFO' 'SENTINEL monitor started'

  while [ ! -f "${STOP_FILE}" ]; do
    if [ "$mode" = "stealth" ]; then
      run_scan >/tmp/sentinel_last.out 2>&1 || true
      tail -n 5 /tmp/sentinel_last.out 2>/dev/null | sed 's/^/[STEALTH] /' >/dev/null || true
      sleep 15
    else
      echo "[SENTINEL] Running scan..."
      run_scan
      sleep 15
    fi
  done

  log 'INFO' 'SENTINEL monitor stopped'
  echo "[SENTINEL] Monitor stopped."
}

run_tui() {
  ensure_defaults
  log 'INFO' 'TUI mode started'

  while [ ! -f "${STOP_FILE}" ]; do
    clear
    echo "=== SENTINEL TUI ==="
    if [ -f "${STATE_FILE}" ]; then
      cat "${STATE_FILE}"
    else
      echo "Waiting for first scan..."
    fi
    echo ""
    echo "Press Ctrl+C to quit"
    sleep 0.016
  done
}

install_local() {
  local bin_dir="${HOME}/.local/bin"
  mkdir -p "${bin_dir}"
  cp "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/sentinel" "${bin_dir}/sentinel"
  chmod +x "${bin_dir}/sentinel"
  ensure_defaults
  echo "[SENTINEL] Installed to ${bin_dir}/sentinel"
  echo "[SENTINEL] Run: sentinel start"
}

case "${1:-help}" in
  start) start_loop normal ;;
  stealth) start_loop stealth ;;
  tui) run_tui ;;
  scan) ensure_defaults; run_scan ;;
  status) show_status ;;
  stop) : > "${STOP_FILE}"; echo "[SENTINEL] Stop requested."; log 'INFO' 'Stop flag created' ;;
  install) install_local ;;
  help|-h|--help) show_usage ;;
  *) show_usage ;;
esac
