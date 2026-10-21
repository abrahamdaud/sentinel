#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_HOME="${HOME}/.sentinel"
LOG_DIR="${APP_HOME}/logs"
CONFIG_FILE="${APP_HOME}/config.json"

ensure_runtime_dirs() {
  mkdir -p "${APP_HOME}" "${LOG_DIR}"
  if [ ! -f "${CONFIG_FILE}" ]; then
    cat > "${CONFIG_FILE}" <<'EOF'
{
  "ScanInterval": 15,
  "SuspiciousWords": [
    "r57","mimikatz","meterpreter","backdoor","rootkit","keylog","dropper","ngrok","frp","proxychains","malware","trojan","stealer","adb","scrcpy","vnc","teamviewer","anydesk","exfil"
  ],
  "RemoteProcessNames": [
    "adb","scrcpy","vnc","tightvnc","teamviewer","anydesk","rdp","x11vnc","mimikatz","meterpreter"
  ],
  "Whitelist": [],
  "StealthMode": true,
  "TuiRefreshMs": 16
}
EOF
  fi
}

install_autostart() {
  local cron_name="sentinel-startup"
  local cron_line="@reboot ${HOME}/.local/bin/sentinel start >/dev/null 2>&1"

  if command -v crontab >/dev/null 2>&1; then
    local current_cron
    current_cron="$(crontab -l 2>/dev/null || true)"
    if ! printf '%s\n' "$current_cron" | grep -Fq "$cron_line"; then
      { printf '%s\n' "$current_cron"; printf '%s\n' "$cron_line"; } | crontab -
    fi
    echo "[SENTINEL] Added @reboot cron entry for startup persistence."
  else
    echo "[SENTINEL] crontab not available; startup persistence skipped."
  fi
}

install_main() {
  mkdir -p "${HOME}/.local/bin"
  cp "${SCRIPT_DIR}/sentinel" "${HOME}/.local/bin/sentinel"
  chmod +x "${HOME}/.local/bin/sentinel"

  ensure_runtime_dirs

  if [ -f "${HOME}/.bashrc" ] && ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "${HOME}/.bashrc" 2>/dev/null; then
    printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "${HOME}/.bashrc"
  fi

  if [ -f "${HOME}/.profile" ] && ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "${HOME}/.profile" 2>/dev/null; then
    printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "${HOME}/.profile"
  fi

  install_autostart
  echo "[SENTINEL] Installed to ${HOME}/.local/bin/sentinel"
  echo "[SENTINEL] Run: sentinel start"
}

case "${1:-install}" in
  install) install_main ;;
  *) echo "Use: ./install.sh" ;;
esac
