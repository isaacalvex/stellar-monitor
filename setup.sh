#!/usr/bin/env bash
set -e

echo "=== Instalando STELLAR Thermal Monitor ==="

if command -v pacman &> /dev/null; then
    sudo pacman -S --needed --noconfirm python-pyserial lm_sensors
elif command -v apt &> /dev/null; then
    sudo apt update && sudo apt install -y python3-serial lm-sensors
fi

USER_GROUPS=$(groups "$USER")
if command -v pacman &> /dev/null; then
    echo "$USER_GROUPS" | grep -q "uucp" || sudo usermod -aG uucp "$USER"
else
    echo "$USER_GROUPS" | grep -q "dialout" || sudo usermod -aG dialout "$USER"
fi

TARGET_DIR="$HOME/.local/bin"
mkdir -p "$TARGET_DIR"
cp "$HOME/Downloads/stellar_monitor.py" "$TARGET_DIR/stellar_monitor.py" 2>/dev/null || cp stellar_monitor.py "$TARGET_DIR/stellar_monitor.py"
chmod +x "$TARGET_DIR/stellar_monitor.py"

SYSTEMD_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_DIR"

cat <<EOF_SERVICE > "$SYSTEMD_DIR/stellar-monitor.service"
[Unit]
Description=Stellar Thermal Monitor (PC to ESP32 USB)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/env python3 $TARGET_DIR/stellar_monitor.py
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF_SERVICE

systemctl --user daemon-reload
systemctl --user enable --now stellar-monitor.service
echo "=== Instalação Concluída com Sucesso! ==="
