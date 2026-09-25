#!/usr/bin/env bash
set -e

REPO_RAW="https://raw.githubusercontent.com/isaacalvex/stellar-monitor/main"
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="stellar_monitor.py"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="stellar-monitor.service"
SERVICE_PATH="$SERVICE_DIR/$SERVICE_NAME"

echo "STELLAR MONITOR - instalador"

if command -v pacman >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm python python-pyserial lm_sensors curl
  SERIAL_GROUP="uucp"
elif command -v apt >/dev/null 2>&1; then
  sudo apt update
  sudo apt install -y python3 python3-serial lm-sensors curl
  SERIAL_GROUP="dialout"
elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y python3 python3-pyserial lm_sensors curl
  SERIAL_GROUP="dialout"
else
  echo "Gerenciador de pacotes não suportado."
  exit 1
fi

if getent group "$SERIAL_GROUP" >/dev/null 2>&1; then
  if ! id -nG "$USER" | grep -qw "$SERIAL_GROUP"; then
    sudo usermod -aG "$SERIAL_GROUP" "$USER"
    echo "Usuário adicionado ao grupo $SERIAL_GROUP."
    echo "Será necessário sair da sessão e entrar novamente (ou reiniciar) para a permissão serial valer."
  fi
fi

mkdir -p "$INSTALL_DIR" "$SERVICE_DIR"
curl -fL "$REPO_RAW/$SCRIPT_NAME" -o "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="$(command -v python3)"
else
  PYTHON_BIN="$(command -v python)"
fi

"$PYTHON_BIN" -c "import serial"

cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Stellar Monitor - AMD BC250 ESP32 Monitor
After=default.target

[Service]
Type=simple
ExecStart=$PYTHON_BIN -u $SCRIPT_PATH
Restart=always
RestartSec=2
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable "$SERVICE_NAME"
systemctl --user restart "$SERVICE_NAME" || true

echo
echo "Instalação concluída."
echo "Status: systemctl --user status $SERVICE_NAME"
echo "Logs:   journalctl --user -u $SERVICE_NAME -f"
echo
echo "Se a porta serial ainda retornar Permission denied, reinicie a sessão/computador e execute:"
echo "systemctl --user restart $SERVICE_NAME"
