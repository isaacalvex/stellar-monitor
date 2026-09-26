# AMD BC250 Monitor Display (ESP32-C3 1.28 inch)

Monitor de temperatura da AMD BC250 usando CachyOS/Linux e um ESP32-C3 com display circular GC9A01 240x240.

## Como funciona

O Linux lê as temperaturas reais da CPU e GPU, e o `stellar_monitor.py` envia pela USB Serial, a 115200 baud, no formato:

```text
CPU:46.6;GPU:44.0
```

O ESP32 controla o display. Enquanto CPU e GPU reais ainda não estiverem disponíveis, nenhum pacote é enviado e o display permanece no splash STELLAR. Depois do primeiro pacote válido, a tela passa a mostrar as temperaturas e é atualizada a cada segundo.

## Estrutura

```text
stellar-monitor/
├── README.md
├── setup.sh
├── stellar_monitor.py
└── arduino/
    └── AMD_BC250_Monitor_Display.ino
```

## ESP32-C3

Hardware usado:

- ESP32-C3
- GC9A01 1.28"
- 240x240
- MOSI GPIO 7
- SCLK GPIO 6
- CS GPIO 10
- DC GPIO 2
- RST -1
- Backlight GPIO 3

No Arduino IDE, instale o pacote `esp32 by Espressif Systems` e as bibliotecas `U8g2` e `Arduino_GFX_Library`. Para placas compatíveis, use `ESP32C3 Dev Module`, abra `arduino/AMD_BC250_Monitor_Display.ino` e faça o upload.

### Configuração obrigatória: USB CDC On Boot

Antes de gravar o firmware, abra **Tools / Ferramentas** no Arduino IDE e configure:

```text
Board: ESP32C3 Dev Module
USB CDC On Boot: Enabled
```

O **USB CDC On Boot precisa estar em Enabled** neste projeto quando a comunicação com o Linux é feita pela USB nativa do ESP32-C3. Assim, após iniciar o firmware, o ESP32 disponibiliza a interface serial USB usada pelo `stellar_monitor.py`.

Com o CDC habilitado, a porta normalmente aparecerá no Linux em `/dev/ttyACM*` ou através de `/dev/serial/by-id/`. O monitor utiliza `Serial.begin(115200)` e o serviço Linux envia as temperaturas por essa interface.

Se o ESP32 grava normalmente, mas depois o STELLAR Monitor não encontra uma porta serial para enviar os dados, confirme primeiro que **USB CDC On Boot = Enabled** e reinicie a placa.

## CachyOS / Arch

Instalação automática:

```bash
curl -sSL https://raw.githubusercontent.com/isaacalvex/stellar-monitor/main/setup.sh | bash
```

O instalador configura Python, PySerial, lm_sensors, permissão serial e o serviço systemd do usuário.

No Arch/CachyOS, a porta serial normalmente usa o grupo `uucp`. Se o instalador adicionar seu usuário a esse grupo, reinicie a sessão ou o computador antes de testar.

## Teste dos sensores

```bash
sensors
```

Na AMD BC250, o script procura `Tctl` para CPU e `amdgpu`/hwmon para GPU.

## Serviço

```bash
systemctl --user status stellar-monitor.service
```

Logs:

```bash
journalctl --user -u stellar-monitor.service -f
```

Reiniciar:

```bash
systemctl --user restart stellar-monitor.service
```

## Comunicação

```text
AMD BC250
   |
   v
sensors / hwmon
   |
   v
stellar_monitor.py
   |
   | CPU:xx.x;GPU:xx.x
   | USB Serial 115200
   v
ESP32-C3
   |
   v
GC9A01 240x240
```

O script procura primeiro dispositivos persistentes em `/dev/serial/by-id/` e depois `/dev/ttyACM*` e `/dev/ttyUSB*`.

Não são enviados valores padrão/fictícios: sem leitura válida de CPU e GPU, o ESP32 continua aguardando no splash.
