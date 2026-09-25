#!/usr/bin/env bash

set -e

# ============================================================
# STELLAR MONITOR - INSTALADOR
# AMD BC250 + ESP32
#
# Repositório:
# https://github.com/isaacalvex/stellar-monitor
# ============================================================

REPO_RAW="https://raw.githubusercontent.com/isaacalvex/stellar-monitor/main"

INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="stellar_monitor.py"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"

SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="stellar-monitor.service"
SERVICE_PATH="$SERVICE_DIR/$SERVICE_NAME"


echo "=========================================="
echo "       STELLAR MONITOR - INSTALADOR"
echo "=========================================="
echo


# ============================================================
# 1. DETECTAR DISTRIBUIÇÃO
# ============================================================

echo "[1/7] Detectando sistema..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "Sistema detectado: ${PRETTY_NAME:-Linux}"
else
    echo "Não foi possível identificar a distribuição."
fi

echo


# ============================================================
# 2. INSTALAR DEPENDÊNCIAS
# ============================================================

echo "[2/7] Verificando dependências..."

if command -v pacman >/dev/null 2>&1; then

    echo "Sistema baseado em Arch/CachyOS detectado."

    sudo pacman -S --needed --noconfirm \
        python \
        python-pyserial \
        lm_sensors \
        curl

elif command -v apt >/dev/null 2>&1; then

    echo "Sistema baseado em Debian/Ubuntu detectado."

    sudo apt update

    sudo apt install -y \
        python3 \
        python3-serial \
        lm-sensors \
        curl

elif command -v dnf >/dev/null 2>&1; then

    echo "Sistema baseado em Fedora detectado."

    sudo dnf install -y \
        python3 \
        python3-pyserial \
        lm_sensors \
        curl

else

    echo "ERRO: Gerenciador de pacotes não suportado."
    echo
    echo "Instale manualmente:"
    echo "  Python 3"
    echo "  pyserial"
    echo "  lm-sensors"
    echo "  curl"
    exit 1

fi

echo
echo "Dependências instaladas."
echo


# ============================================================
# 3. CRIAR DIRETÓRIO
# ============================================================

echo "[3/7] Preparando diretório..."

mkdir -p "$INSTALL_DIR"

echo "Diretório:"
echo "$INSTALL_DIR"
echo


# ============================================================
# 4. BAIXAR stellar_monitor.py
# ============================================================

echo "[4/7] Baixando Stellar Monitor..."

if ! curl -fL \
    "$REPO_RAW/$SCRIPT_NAME" \
    -o "$SCRIPT_PATH"; then

    echo
    echo "ERRO: não foi possível baixar:"
    echo "$REPO_RAW/$SCRIPT_NAME"
    exit 1
fi


if [ ! -s "$SCRIPT_PATH" ]; then
    echo "ERRO: stellar_monitor.py foi baixado vazio."
    rm -f "$SCRIPT_PATH"
    exit 1
fi


chmod +x "$SCRIPT_PATH"

echo
echo "Arquivo instalado em:"
echo "$SCRIPT_PATH"
echo


# ============================================================
# 5. VERIFICAR PYTHON
# ============================================================

echo "[5/7] Verificando Python e PySerial..."

if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3)"
elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python)"
else
    echo "ERRO: Python não encontrado."
    exit 1
fi


if ! "$PYTHON_BIN" -c "import serial" >/dev/null 2>&1; then

    echo "ERRO: módulo PySerial não encontrado."
    echo
    echo "Python utilizado:"
    echo "$PYTHON_BIN"

    exit 1
fi


echo "Python: $PYTHON_BIN"
echo "PySerial: OK"
echo


# ============================================================
# 6. CRIAR SERVIÇO SYSTEMD
# ============================================================

echo "[6/7] Criando serviço systemd..."

mkdir -p "$SERVICE_DIR"


cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Stellar Monitor - AMD BC250 ESP32 Monitor
After=default.target

[Service]
Type=simple

ExecStart=$PYTHON_BIN $SCRIPT_PATH

Restart=always
RestartSec=3

Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=default.target
EOF


echo "Serviço criado:"
echo "$SERVICE_PATH"
echo


# ============================================================
# 7. ATIVAR SERVIÇO
# ============================================================

echo "[7/7] Ativando Stellar Monitor..."

systemctl --user daemon-reload

systemctl --user enable "$SERVICE_NAME"

systemctl --user restart "$SERVICE_NAME"


sleep 2

echo
echo "=========================================="
echo "          VERIFICAÇÃO FINAL"
echo "=========================================="
echo


if systemctl --user is-active --quiet "$SERVICE_NAME"; then

    echo "STELLAR MONITOR ESTÁ RODANDO!"

else

    echo "ATENÇÃO: o serviço não está ativo."
    echo
    echo "Veja o erro usando:"
    echo
    echo "journalctl --user -u $SERVICE_NAME -f"

fi


echo
echo "------------------------------------------"
echo "ESP32 detectado:"
echo "------------------------------------------"

FOUND=0

for PORT in /dev/ttyACM* /dev/ttyUSB*; do

    if [ -e "$PORT" ]; then
        echo "$PORT"
        FOUND=1
    fi

done


if [ "$FOUND" -eq 0 ]; then
    echo "Nenhum ESP32 encontrado em ttyACM/ttyUSB."
    echo "Conecte o ESP32 e reinicie o serviço com:"
    echo
    echo "systemctl --user restart $SERVICE_NAME"
fi


echo
echo "=========================================="
echo "         INSTALAÇÃO CONCLUÍDA"
echo "=========================================="
echo
echo "Status:"
echo "systemctl --user status $SERVICE_NAME"
echo
echo "Logs:"
echo "journalctl --user -u $SERVICE_NAME -f"
echo
echo "Reiniciar:"
echo "systemctl --user restart $SERVICE_NAME"
echo
