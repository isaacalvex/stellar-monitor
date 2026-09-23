#!/usr/bin/env python3

import serial
import subprocess
import time
import os
import glob
import signal

PORTA = "/dev/ttyACM0"
BAUDRATE = 115200
INTERVALO = 1.0

ultima_cpu = 40.0
ultima_gpu = 40.0
rodando = True

def encerrar(signal_num, frame):
    global rodando
    print("\nEncerrando STELLAR...")
    rodando = False

signal.signal(signal.SIGINT, encerrar)
signal.signal(signal.SIGTERM, encerrar)

def encontrar_porta():
    if os.path.exists(PORTA):
        return PORTA
    portas = glob.glob("/dev/ttyACM*") + glob.glob("/dev/ttyUSB*")
    return portas[0] if portas else None

def ler_cpu():
    global ultima_cpu
    try:
        resultado = subprocess.run(["sensors"], capture_output=True, text=True, timeout=0.8)
        for linha in resultado.stdout.splitlines():
            if linha.strip().startswith("Tctl:"):
                import re
                match = re.search(r"([+-]?\d+(?:\.\d+)?)°C", linha)
                if match:
                    valor = float(match.group(1))
                    if -20 <= valor <= 120:
                        ultima_cpu = valor
                        return valor
    except Exception:
        pass
    return ultima_cpu

def ler_gpu():
    global ultima_gpu
    try:
        arquivos = glob.glob("/sys/class/drm/card*/device/hwmon/hwmon*/temp*_input")
        for arquivo in arquivos:
            try:
                with open(arquivo, "r") as f:
                    valor = int(f.read().strip()) / 1000.0
                if 0 <= valor <= 120:
                    nome_arquivo = os.path.join(os.path.dirname(arquivo), "name")
                    if os.path.exists(nome_arquivo):
                        with open(nome_arquivo, "r") as f:
                            if "amdgpu" in f.read().strip().lower():
                                ultima_gpu = valor
                                return valor
            except Exception:
                continue
    except Exception:
        pass
    return ultima_gpu

def main():
    print("STELLAR THERMAL MONITOR rodando...")
    ser = None
    proximo_envio = time.monotonic()

    while rodando:
        if ser is None or not ser.is_open:
            porta = encontrar_porta()
            if porta:
                try:
                    ser = serial.Serial(porta, BAUDRATE, timeout=0.5)
                except Exception:
                    ser = None
            if not ser:
                time.sleep(1)
                continue

        cpu = ler_cpu()
        gpu = ler_gpu()
        agora = time.monotonic()

        if agora >= proximo_envio:
            try:
                ser.write(f"CPU:{cpu:.1f};GPU:{gpu:.1f}\n".encode("utf-8"))
                ser.flush()
                print(f"\rCPU: {cpu:5.1f} °C | GPU: {gpu:5.1f} °C", end="", flush=True)
            except Exception:
                ser = None
            proximo_envio = agora + INTERVALO
        time.sleep(0.05)

if __name__ == "__main__":
    main()
