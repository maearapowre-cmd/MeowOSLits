#!/bin/bash

# MeowOS - Instalační skript pro Raspberry Pi OS Lite
# Spouštěj jako běžný uživatel (ne root)

set -e  # skončí při jakékoli chybě

echo "=== Instalace MeowOS ==="

# 1. Aktualizace seznamu balíčků
sudo apt update

# 2. Instalace X serveru a potřebných knihoven
echo "Instaluji X server a vývojové knihovny..."
sudo apt install --no-install-recommends -y \
    xserver-xorg \
    xinit \
    libgtk-3-dev \
    libvte-2.91-dev \
    pcmanfm \
    gcc \
    make \
    pkg-config

# 3. Kompilace programu (pokud existuje MeowOS.c v aktuální složce)
if [ ! -f "MeowOS.c" ]; then
    echo "Chyba: Soubor MeowOS.c nebyl nalezen v aktuální složce!"
    exit 1
fi

echo "Kompiluji MeowOS..."
gcc -o MeowOS MeowOS.c `pkg-config --cflags --libs gtk+-3.0 vte-2.91` -lm

# 4. Nastavení .xinitrc pro spuštění MeowOS
echo "Vytvářím ~/.xinitrc..."
cat > ~/.xinitrc << 'EOF'
#!/bin/sh
exec $HOME/MeowOSLits/MeowOS
EOF

# 5. Nastavení .bash_profile pro automatické spuštění X po přihlášení
echo "Nastavuji .bash_profile..."
BASHRC_ADD='
# Automatické spuštění X serveru na tty1
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    startx
fi
'

# Pokud .bash_profile neexistuje, vytvoříme ho, jinak přidáme na konec
if [ ! -f ~/.bash_profile ]; then
    echo "$BASHRC_ADD" > ~/.bash_profile
else
    # Přidáme jen pokud tam ještě není
    if ! grep -q "startx" ~/.bash_profile; then
        echo "$BASHRC_ADD" >> ~/.bash_profile
    fi
fi

# 6. Závěrečná zpráva
echo
echo "=== Instalace dokončena! ==="
echo
echo "Nyní můžeš buď:"
echo " - ručně spustit X server příkazem: startx"
echo " - nebo restartovat systém: sudo reboot"
echo
echo "Po restartu/přihlášení se MeowOS spustí automaticky."
