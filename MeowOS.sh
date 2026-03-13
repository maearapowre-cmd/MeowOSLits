#!/bin/bash

# MeowOS Lite - kompletní instalace do jednoho souboru
# Autor: asistent
# Verze: 1.0 (Pygame verze)

set -e  # skončí při chybě

# Barvy pro výpis
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== MeowOS Lite Instalátor ===${NC}"
echo "Tento skript provede kompletní instalaci MeowOS Lite na Raspberry Pi Zero 2W."
echo "Bude použit Pygame (odlehčená varianta) místo PyQt5."
echo ""

# Zjištění aktuálního uživatele
CURRENT_USER=$(whoami)
echo -e "${YELLOW}Aktuálně jsi přihlášen jako: ${CURRENT_USER}${NC}"
if [ "$CURRENT_USER" = "jakub" ]; then
    USERNAME="jakub"
    echo -e "${GREEN}Uživatel jakub nalezen. Pokračujeme.${NC}"
else
    echo -e "${RED}Varování: Nejsi přihlášen jako jakub.${NC}"
    read -p "Zadej uživatelské jméno, pod kterým bude MeowOS Lite spuštěn (např. jakub): " USERNAME
    if [ -z "$USERNAME" ]; then
        echo "Chyba: musíš zadat uživatelské jméno."
        exit 1
    fi
fi

HOME_DIR="/home/$USERNAME"
if [ ! -d "$HOME_DIR" ]; then
    echo -e "${RED}Domovský adresář $HOME_DIR neexistuje. Zkontroluj uživatelské jméno.${NC}"
    exit 1
fi

echo -e "${GREEN}Instalace bude provedena pro uživatele $USERNAME v adresáři $HOME_DIR${NC}"
read -p "Pokračovat? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Instalace zrušena."
    exit 0
fi

# Aktualizace systému
echo -e "${YELLOW}Aktualizuji systém...${NC}"
sudo apt update && sudo apt upgrade -y

# Instalace balíčků
echo -e "${YELLOW}Instaluji potřebné balíčky...${NC}"
sudo apt install --no-install-recommends -y \
    xorg \
    openbox \
    lxterminal \
    pcmanfm \
    python3 \
    python3-pygame \
    python3-psutil \
    git \
    wget

# Vytvoření adresářové struktury
echo -e "${YELLOW}Vytvářím adresáře projektu...${NC}"
mkdir -p "$HOME_DIR/meowoslite/apps"
mkdir -p "$HOME_DIR/meowoslite/icons"
mkdir -p "$HOME_DIR/.config/openbox"

# ============================================
# Vytváření souborů
# ============================================

# boot.py
cat > "$HOME_DIR/meowoslite/boot.py" << 'EOF'
#!/usr/bin/env python3
import pygame
import time
import sys

pygame.init()
info = pygame.display.Info()
screen = pygame.display.set_mode((info.current_w, info.current_h), pygame.FULLSCREEN)
pygame.display.set_caption("MeowOS Lite")

# Černá obrazovka s textem
font = pygame.font.Font(None, 74)
text = font.render("MeowOS Lite se spouští...", True, (255,255,255))
text_rect = text.get_rect(center=(info.current_w//2, info.current_h//2))

screen.fill((0,0,0))
screen.blit(text, text_rect)
pygame.display.flip()
time.sleep(2)
EOF

# kernel.py (hlavní desktop)
cat > "$HOME_DIR/meowoslite/kernel.py" << 'EOF'
#!/usr/bin/env python3
import pygame
import sys
import os
import subprocess
import psutil
import socket
from datetime import datetime

# Inicializace Pygame
pygame.init()
info = pygame.display.Info()
WIDTH, HEIGHT = info.current_w, info.current_h
screen = pygame.display.set_mode((WIDTH, HEIGHT), pygame.FULLSCREEN)
pygame.display.set_caption("MeowOS Lite")
clock = pygame.time.Clock()

# Barvy (RGBA)
BLACK = (0,0,0)
WHITE = (255,255,255)
GLASS_BG = (30,30,40,200)      # průhledné pozadí widgetů
DOCK_BG = (20,20,30,220)        # dock
BUTTON_BG = (60,60,80,150)
BUTTON_HOVER = (100,100,150,200)

# Fonty
font_large = pygame.font.Font(None, 72)
font_medium = pygame.font.Font(None, 48)
font_small = pygame.font.Font(None, 36)
font_tiny = pygame.font.Font(None, 24)

# =========================================================================
# Třída Widget
# =========================================================================
class Widget:
    def __init__(self, x, y, width, height, title):
        self.rect = pygame.Rect(x, y, width, height)
        self.title = title
        self.value = "---"
        self.bg_color = GLASS_BG

    def draw(self, surface):
        # Průhledné pozadí
        s = pygame.Surface((self.rect.width, self.rect.height), pygame.SRCALPHA)
        pygame.draw.rect(s, self.bg_color, s.get_rect(), border_radius=15)
        pygame.draw.rect(s, (255,255,255,60), s.get_rect(), 2, border_radius=15)
        surface.blit(s, self.rect)

        # Titulek
        title_surf = font_tiny.render(self.title, True, (200,200,200))
        surface.blit(title_surf, (self.rect.x+10, self.rect.y+5))

        # Hodnota
        value_surf = font_medium.render(self.value, True, WHITE)
        value_rect = value_surf.get_rect(center=(self.rect.centerx, self.rect.centery+10))
        surface.blit(value_surf, value_rect)

    def update_value(self, new_value):
        self.value = new_value

# =========================================================================
# Třída DockButton (tlačítko v docku)
# =========================================================================
class DockButton:
    def __init__(self, x, y, width, height, text, command):
        self.rect = pygame.Rect(x, y, width, height)
        self.text = text
        self.command = command
        self.hovered = False

    def draw(self, surface):
        color = BUTTON_HOVER if self.hovered else BUTTON_BG
        s = pygame.Surface((self.rect.width, self.rect.height), pygame.SRCALPHA)
        pygame.draw.rect(s, color, s.get_rect(), border_radius=10)
        surface.blit(s, self.rect)

        # Text tlačítka (první písmeno jako záložní)
        if len(self.text) > 1:
            display_text = self.text[0]
        else:
            display_text = self.text
        text_surf = font_medium.render(display_text, True, WHITE)
        text_rect = text_surf.get_rect(center=self.rect.center)
        surface.blit(text_surf, text_rect)

    def handle_event(self, event):
        if event.type == pygame.MOUSEMOTION:
            self.hovered = self.rect.collidepoint(event.pos)
        elif event.type == pygame.MOUSEBUTTONDOWN and self.hovered:
            self.command()

# =========================================================================
# Funkce pro získání systémových informací
# =========================================================================
def get_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return "offline"

def get_cpu_temp():
    try:
        with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
            temp_raw = f.read().strip()
            return round(int(temp_raw) / 1000, 1)
    except:
        return "N/A"

def get_uptime():
    try:
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = float(f.read().split()[0])
            hours = int(uptime_seconds // 3600)
            minutes = int((uptime_seconds % 3600) // 60)
            return f"{hours}h {minutes}m"
    except:
        return "N/A"

# =========================================================================
# Aplikace (spouštěné externě)
# =========================================================================
def launch_terminal():
    subprocess.Popen(["lxterminal"])

def launch_clock():
    subprocess.Popen(["python3", "/home/USERNAME/meowoslite/apps/clock.py"])

def launch_settings():
    subprocess.Popen(["python3", "/home/USERNAME/meowoslite/apps/settings.py"])

def launch_filemanager():
    subprocess.Popen(["pcmanfm"])

# =========================================================================
# Hlavní smyčka
# =========================================================================
def main():
    # Vytvoření widgetů
    margin = 20
    w_w, w_h = 200, 150
    x1, x2, x3 = margin, margin*2 + w_w, margin*3 + w_w*2

    widgets = [
        Widget(x1, margin, w_w, w_h, "Čas"),
        Widget(x2, margin, w_w, w_h, "RAM"),
        Widget(x3, margin, w_w, w_h, "CPU"),
        Widget(x1, margin*2 + w_h, w_w, w_h, "Disk"),
        Widget(x2, margin*2 + w_h, w_w, w_h, "Teplota"),
        Widget(x3, margin*2 + w_h, w_w, w_h, "Síť"),
        Widget(x1, margin*3 + w_h*2, w_w, w_h, "Běží"),
    ]

    # Vytvoření docku a tlačítek
    dock_rect = pygame.Rect(50, HEIGHT-100, WIDTH-100, 70)
    btn_w, btn_h = 60, 60
    btn_spacing = 20
    total_btns_width = 4*btn_w + 3*btn_spacing
    start_x = (WIDTH - total_btns_width) // 2
    buttons = [
        DockButton(start_x, HEIGHT-85, btn_w, btn_h, "Terminál", launch_terminal),
        DockButton(start_x + btn_w + btn_spacing, HEIGHT-85, btn_w, btn_h, "Hodiny", launch_clock),
        DockButton(start_x + 2*(btn_w + btn_spacing), HEIGHT-85, btn_w, btn_h, "Nastavení", launch_settings),
        DockButton(start_x + 3*(btn_w + btn_spacing), HEIGHT-85, btn_w, btn_h, "Soubor", launch_filemanager),
    ]

    # Časovač pro aktualizaci
    last_update = pygame.time.get_ticks()

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
            # Předáme události tlačítkům
            for btn in buttons:
                btn.handle_event(event)

        # Aktualizace widgetů (každých 500 ms)
        now = pygame.time.get_ticks()
        if now - last_update > 500:
            last_update = now

            # Čas
            now_str = datetime.now().strftime("%H:%M:%S")
            widgets[0].update_value(now_str)

            # RAM
            mem = psutil.virtual_memory()
            widgets[1].update_value(f"{mem.percent}%")

            # CPU
            cpu_percent = psutil.cpu_percent(interval=None)
            widgets[2].update_value(f"{cpu_percent}%")

            # Disk
            disk = psutil.disk_usage('/')
            widgets[3].update_value(f"{disk.percent}%")

            # Teplota
            temp = get_cpu_temp()
            widgets[4].update_value(f"{temp}°C")

            # IP adresa
            ip = get_ip()
            widgets[5].update_value(ip)

            # Uptime
            uptime = get_uptime()
            widgets[6].update_value(uptime)

        # Vykreslení pozadí (gradient)
        for y in range(HEIGHT):
            color_val = int(20 + (y / HEIGHT) * 30)
            pygame.draw.line(screen, (color_val, color_val, color_val+10), (0, y), (WIDTH, y))

        # Vykreslení widgetů
        for w in widgets:
            w.draw(screen)

        # Vykreslení docku
        s = pygame.Surface((dock_rect.width, dock_rect.height), pygame.SRCALPHA)
        pygame.draw.rect(s, DOCK_BG, s.get_rect(), border_radius=20)
        pygame.draw.rect(s, (255,255,255,40), s.get_rect(), 2, border_radius=20)
        screen.blit(s, dock_rect)

        # Vykreslení tlačítek
        for btn in buttons:
            btn.draw(screen)

        pygame.display.flip()
        clock.tick(30)

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    # Nahraď USERNAME skutečným uživatelským jménem (bude nahrazeno instalátorem)
    main()
EOF

# Nahrazení USERNAME v kernel.py
sed -i "s/USERNAME/$USERNAME/g" "$HOME_DIR/meowoslite/kernel.py"

# apps/clock.py
cat > "$HOME_DIR/meowoslite/apps/clock.py" << 'EOF'
#!/usr/bin/env python3
import pygame
import sys
from datetime import datetime

pygame.init()
screen = pygame.display.set_mode((300, 150))
pygame.display.set_caption("Hodiny")
clock = pygame.time.Clock()
font = pygame.font.Font(None, 72)

running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False

    screen.fill((30,30,40))
    now = datetime.now().strftime("%H:%M:%S")
    text = font.render(now, True, (255,255,255))
    text_rect = text.get_rect(center=(150,75))
    screen.blit(text, text_rect)
    pygame.display.flip()
    clock.tick(10)

pygame.quit()
sys.exit()
EOF

# apps/settings.py
cat > "$HOME_DIR/meowoslite/apps/settings.py" << 'EOF'
#!/usr/bin/env python3
import pygame
import sys

pygame.init()
screen = pygame.display.set_mode((400, 300))
pygame.display.set_caption("Nastavení")
clock = pygame.time.Clock()
font = pygame.font.Font(None, 48)

running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False

    screen.fill((30,30,40))
    text = font.render("Zde budou nastavení", True, (255,255,255))
    text_rect = text.get_rect(center=(200,150))
    screen.blit(text, text_rect)
    pygame.display.flip()
    clock.tick(10)

pygame.quit()
sys.exit()
EOF

# Nastavení práv
chmod +x "$HOME_DIR/meowoslite/"*.py
chmod +x "$HOME_DIR/meowoslite/apps/"*.py

# ============================================
# Konfigurace Openbox a X
# ============================================

# .xinitrc
cat > "$HOME_DIR/.xinitrc" << EOF
#!/bin/sh
exec openbox-session
EOF

# Openbox autostart
cat > "$HOME_DIR/.config/openbox/autostart" << EOF
# Nastavení pozadí
xsetroot -solid "#1a1a24"

# Spuštění MeowOS
python3 $HOME_DIR/meowoslite/boot.py &
python3 $HOME_DIR/meowoslite/kernel.py &
EOF

# .bash_profile pro automatické spuštění X po přihlášení
if ! grep -q "startx" "$HOME_DIR/.bash_profile" 2>/dev/null; then
    cat >> "$HOME_DIR/.bash_profile" << 'EOF'

if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    startx
fi
EOF
fi

# Vlastnictví souborů (aby patřily uživateli)
chown -R "$USERNAME:$USERNAME" "$HOME_DIR/meowoslite"
chown "$USERNAME:$USERNAME" "$HOME_DIR/.xinitrc"
chown -R "$USERNAME:$USERNAME" "$HOME_DIR/.config"

echo -e "${GREEN}Instalace dokončena!${NC}"
echo -e "Pro spuštění MeowOS Lite můžeš:"
echo -e "  1. Restartovat systém (doporučeno): sudo reboot"
echo -e "  2. Nebo ručně spustit X: startx"
read -p "Restartovat nyní? (y/n): " RESTART
if [ "$RESTART" = "y" ]; then
    sudo reboot
else
    echo "Pro ruční spuštění zadej: startx"
fi
