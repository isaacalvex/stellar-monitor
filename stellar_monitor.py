#!/usr/bin/env python3
import glob
import os
import re
import signal
import subprocess
import time
import serial

BAUDRATE = 115200
INTERVALO = 1.0
rodando = True

def encerrar(_signal_num, _frame):
    global rodando
    print("\nEncerrando STELLAR...", flush=True)
    rodando = False

signal.signal(signal.SIGINT, encerrar)
signal.signal(signal.SIGTERM, encerrar)

def encontrar_porta():
    by_id = sorted(glob.glob("/dev/serial/by-id/*"))
    if by_id:
        return by_id[0]
    portas = sorted(glob.glob("/dev/ttyACM*")) + sorted(glob.glob("/dev/ttyUSB*"))
    return portas[0] if portas else None

def ler_cpu():
    try:
        resultado = subprocess.run(["sensors"], capture_output=True, text=True, timeout=0.8)
        for linha in resultado.stdout.splitlines():
            if linha.strip().startswith("Tctl:"):
                match = re.search(r"([+-]?\d+(?:\.\d+)?)°C", linha)
                if match:
                    valor = float(match.group(1))
                    if -20 <= valor <= 120:
                        return valor
    except Exception:
        pass
    return None

def ler_gpu():
    try:
        arquivos = glob.glob("/sys/class/drm/card*/device/hwmon/hwmon*/temp*_input")
        for arquivo in arquivos:
            try:
                nome_arquivo = os.path.join(os.path.dirname(arquivo), "name")
                if not os.path.exists(nome_arquivo):
                    continue
                with open(nome_arquivo, "r") as f:
                    nome = f.read().strip().lower()
                if "amdgpu" not in nome:
                    continue
                with open(arquivo, "r") as f:
                    valor = int(f.read().strip()) / 1000.0
                if 0 <= valor <= 120:
                    return valor
            except Exception:
                continue
    except Exception:
        pass

    try:
        resultado = subprocess.run(["sensors"], capture_output=True, text=True, timeout=0.8)
        dentro_gpu = False
        for linha in resultado.stdout.splitlines():
            limpa = linha.strip()
            if limpa.startswith("amdgpu-pci"):
                dentro_gpu = True
                continue
            if dentro_gpu and limpa.startswith("edge:"):
                match = re.search(r"([+-]?\d+(?:\.\d+)?)°C", limpa)
                if match:
                    valor = float(match.group(1))
                    if 0 <= valor <= 120:
                        return valor
    except Exception:
        pass
    return None

def conectar():
    while rodando:
        porta = encontrar_porta()
        if not porta:
            print("ESP32 não encontrado. Tentando novamente...", flush=True)
            time.sleep(1)
            continue
        try:
            print(f"Conectando ao ESP32 em {porta}...", flush=True)
            ser = serial.Serial(porta, BAUDRATE, timeout=0.5, write_timeout=0.5)
            time.sleep(2)
            ser.reset_input_buffer()
            ser.reset_output_buffer()
            print("ESP32 conectado.", flush=True)
            return ser
        except Exception as erro:
            print(f"Falha ao conectar: {erro}", flush=True)
            time.sleep(1)
    return None

def main():
    print("STELLAR THERMAL MONITOR rodando...", flush=True)
    ser = None
    proximo_envio = time.monotonic()

    while rodando:
        if ser is None or not ser.is_open:
            if ser is not None:
                try:
                    ser.close()
                except Exception:
                    pass
            ser = conectar()
            if ser is None:
                break

        agora = time.monotonic()
        if agora >= proximo_envio:
            cpu = ler_cpu()
            gpu = ler_gpu()

            # Nunca envia temperaturas fictícias.
            # O ESP32 permanece no splash até CPU e GPU reais estarem disponíveis.
            if cpu is None or gpu is None:
                print("Aguardando leitura válida de CPU e GPU...", flush=True)
            else:
                pacote = f"CPU:{cpu:.1f};GPU:{gpu:.1f}\n"
                try:
                    ser.write(pacote.encode("utf-8"))
                    ser.flush()
                    print(f"CPU: {cpu:5.1f} °C | GPU: {gpu:5.1f} °C", flush=True)
                except Exception as erro:
                    print(f"Falha USB: {erro}", flush=True)
                    try:
                        ser.close()
                    except Exception:
                        pass
                    ser = None
            proximo_envio = agora + INTERVALO
        time.sleep(0.05)

    if ser is not None:
        try:
            ser.close()
        except Exception:
            pass

if __name__ == "__main__":
    main()
