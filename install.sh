#!/bin/bash
# MeowOS Web Desktop – automatická instalace
# Autor: Jakub (s asistencí AI)

set -e  # Skript se zastaví při jakékoli chybě

echo "🔧 Aktualizuji systém a instaluji potřebné balíčky..."
sudo apt update
sudo apt install -y python3-flask python3-psutil wireless-tools

echo "📁 Vytvářím složku pro aplikaci..."
mkdir -p ~/meowos-web
cd ~/meowos-web

echo "🐱 Vytvářím hlavní soubor app.py..."
cat > app.py << 'EOF'
#!/usr/bin/env python3
"""
MeowOS Web – desktopová simulace Windows 11 s glass efekty a reálnými daty
Autor: Jakub (upraveno s asistencí AI)
Licence: MIT
"""

import os
import psutil
import subprocess
import time
from datetime import datetime
from flask import Flask, render_template_string, jsonify, request

app = Flask(__name__)

# ============================================================================
# Pomocné funkce pro získání systémových dat
# ============================================================================

def get_cpu_temperature():
    """Vrátí teplotu CPU ve °C."""
    try:
        with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
            return round(int(f.read().strip()) / 1000, 1)
    except:
        return 0

def get_disks():
    """Vrátí seznam disků (mount pointů) s informacemi o využití."""
    disks = []
    for part in psutil.disk_partitions():
        if part.fstype and part.device.startswith('/dev'):
            try:
                usage = psutil.disk_usage(part.mountpoint)
                disks.append({
                    'name': part.mountpoint,
                    'device': part.device,
                    'total': usage.total,
                    'used': usage.used,
                    'free': usage.free,
                    'percent': usage.percent
                })
            except:
                pass
    return disks

def get_wifi_status():
    """Zkusí zjistit název připojené Wi-Fi sítě (přes iwgetid)."""
    try:
        result = subprocess.run(['iwgetid', '-r'], capture_output=True, text=True, timeout=2)
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except:
        pass
    return 'Nepřipojeno'

# ============================================================================
# Hlavní HTML šablona (vše v jednom)
# ============================================================================

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="cs">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MeowOS Web</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: 'Segoe UI', system-ui, -apple-system, BlinkMacSystemFont, Roboto, sans-serif;
        }

        body {
            width: 100vw;
            height: 100vh;
            overflow: hidden;
            background: linear-gradient(145deg, #0f172a 0%, #1e293b 100%);
            position: relative;
        }

        /* ==================================================================
           DESKTOP – plocha pro okna
           ================================================================== */
        #desktop {
            width: 100%;
            height: 100%;
            padding-bottom: 48px;  /* místo pro taskbar */
            position: relative;
            overflow: hidden;
        }

        /* ==================================================================
           OKNA (WINDOWS) – glass efekt, zaoblené rohy, přetahovatelné
           ================================================================== */
        .window {
            position: absolute;
            min-width: 400px;
            min-height: 300px;
            background: rgba(15, 25, 45, 0.65);
            backdrop-filter: blur(15px);
            -webkit-backdrop-filter: blur(15px);
            border: 1px solid rgba(255, 255, 255, 0.15);
            border-radius: 12px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);
            display: flex;
            flex-direction: column;
            transition: box-shadow 0.2s;
            z-index: 10;
        }
        .window:active {
            box-shadow: 0 25px 50px rgba(0, 0, 0, 0.8);
        }
        .window.maximized {
            width: 100% !important;
            height: calc(100% - 48px) !important;
            top: 0 !important;
            left: 0 !important;
            border-radius: 0;
        }
        .window.minimized {
            display: none !important;
        }

        /* Hlavička okna */
        .window-header {
            background: rgba(30, 40, 60, 0.8);
            padding: 8px 12px;
            border-radius: 12px 12px 0 0;
            display: flex;
            justify-content: space-between;
            align-items: center;
            cursor: grab;
            user-select: none;
            border-bottom: 1px solid rgba(255,255,255,0.1);
        }
        .window-header:active {
            cursor: grabbing;
        }
        .window-title {
            color: white;
            font-size: 14px;
            font-weight: 500;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .window-controls {
            display: flex;
            gap: 8px;
        }
        .window-btn {
            width: 28px;
            height: 28px;
            border: none;
            border-radius: 6px;
            background: rgba(255,255,255,0.1);
            color: white;
            font-size: 14px;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            transition: 0.2s;
        }
        .window-btn:hover {
            background: rgba(255,255,255,0.2);
        }
        .close-btn:hover {
            background: #c42b1c !important;
        }

        /* Obsah okna */
        .window-content {
            flex: 1;
            padding: 16px;
            color: white;
            overflow-y: auto;
            scrollbar-width: thin;
            scrollbar-color: rgba(255,255,255,0.3) transparent;
        }
        .window-content::-webkit-scrollbar {
            width: 6px;
        }
        .window-content::-webkit-scrollbar-thumb {
            background: rgba(255,255,255,0.3);
            border-radius: 3px;
        }

        /* ==================================================================
           TASKBAR (Windows 11 styl)
           ================================================================== */
        #taskbar {
            position: fixed;
            bottom: 0;
            left: 0;
            width: 100%;
            height: 48px;
            background: rgba(20, 25, 40, 0.7);
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            border-top: 1px solid rgba(255,255,255,0.1);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 1000;
        }
        .taskbar-center {
            display: flex;
            gap: 4px;
            background: rgba(255,255,255,0.05);
            padding: 4px 8px;
            border-radius: 12px;
        }
        .taskbar-icon {
            width: 40px;
            height: 40px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 18px;
            transition: 0.2s;
            cursor: pointer;
        }
        .taskbar-icon:hover {
            background: rgba(255,255,255,0.15);
        }
        .taskbar-right {
            position: absolute;
            right: 16px;
            display: flex;
            gap: 16px;
            color: white;
            font-size: 14px;
            align-items: center;
        }
        .taskbar-time {
            background: rgba(255,255,255,0.1);
            padding: 6px 12px;
            border-radius: 20px;
        }

        /* ==================================================================
           START MENU
           ================================================================== */
        #start-menu {
            position: fixed;
            bottom: 60px;
            left: 50%;
            transform: translateX(-50%);
            width: 480px;
            background: rgba(25, 30, 45, 0.8);
            backdrop-filter: blur(30px);
            -webkit-backdrop-filter: blur(30px);
            border-radius: 20px;
            border: 1px solid rgba(255,255,255,0.15);
            padding: 20px;
            color: white;
            box-shadow: 0 30px 60px rgba(0,0,0,0.6);
            display: none;
            z-index: 1100;
        }
        #start-menu.visible {
            display: block;
        }
        .start-header {
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 1px solid rgba(255,255,255,0.2);
        }
        .start-apps {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 16px;
        }
        .start-app {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 6px;
            padding: 12px;
            border-radius: 12px;
            background: rgba(255,255,255,0.05);
            cursor: pointer;
            transition: 0.2s;
        }
        .start-app:hover {
            background: rgba(255,255,255,0.15);
        }
        .start-app i {
            font-size: 28px;
        }
        .start-app span {
            font-size: 12px;
        }

        /* ==================================================================
           IKONY A DALŠÍ PRVKY
           ================================================================== */
        .icon-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(90px, 1fr));
            gap: 20px;
            padding: 10px;
        }
        .file-icon {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 8px;
            padding: 15px 8px;
            border-radius: 12px;
            background: rgba(255,255,255,0.05);
            backdrop-filter: blur(5px);
            border: 1px solid rgba(255,255,255,0.1);
            cursor: pointer;
            transition: 0.2s;
            color: white;
            text-align: center;
        }
        .file-icon:hover {
            background: rgba(255,255,255,0.15);
            transform: scale(1.02);
            border-color: rgba(100, 150, 255, 0.5);
        }
        .file-icon i {
            font-size: 40px;
            filter: drop-shadow(0 10px 8px rgba(0,0,0,0.3));
        }

        /* Navigační panel file manageru */
        .fm-sidebar {
            width: 200px;
            background: rgba(0,0,0,0.2);
            border-radius: 10px;
            padding: 12px;
        }
        .fm-sidebar-item {
            padding: 10px 12px;
            border-radius: 8px;
            margin-bottom: 4px;
            color: rgba(255,255,255,0.8);
            display: flex;
            align-items: center;
            gap: 10px;
            cursor: pointer;
        }
        .fm-sidebar-item:hover {
            background: rgba(255,255,255,0.1);
        }
        .fm-main {
            flex: 1;
            padding-left: 20px;
        }

        /* Progress bar pro disky */
        .disk-item {
            margin-bottom: 20px;
        }
        .disk-info {
            display: flex;
            justify-content: space-between;
            margin-bottom: 5px;
            color: white;
        }
        .progress-bar {
            width: 100%;
            height: 10px;
            background: rgba(255,255,255,0.2);
            border-radius: 5px;
            overflow: hidden;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #4facfe, #00f2fe);
            border-radius: 5px;
            transition: width 0.3s;
        }

        /* Utility */
        .hidden { display: none; }
        .flex-row { display: flex; flex-direction: row; gap: 16px; }
        .flex-col { display: flex; flex-direction: column; gap: 8px; }
    </style>
    <!-- Font Awesome pro ikony -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
</head>
<body>
    <div id="desktop">
        <!-- Okna se budou přidávat dynamicky JavaScriptem -->
    </div>

    <!-- Taskbar -->
    <div id="taskbar">
        <div class="taskbar-center">
            <div class="taskbar-icon" onclick="toggleStartMenu()"><i class="fa-brands fa-windows"></i></div>
            <div class="taskbar-icon" onclick="openApp('search')"><i class="fa-solid fa-magnifying-glass"></i></div>
            <div class="taskbar-icon" onclick="openApp('edge')"><i class="fa-brands fa-edge"></i></div>
            <div class="taskbar-icon" onclick="openFileManager()"><i class="fa-regular fa-folder-open"></i></div>
            <div class="taskbar-icon" onclick="openApp('firefox')"><i class="fa-brands fa-firefox-browser"></i></div>
        </div>
        <div class="taskbar-right">
            <div><i class="fa-solid fa-wifi"></i> <span id="wifi-status">Načítám...</span></div>
            <div><i class="fa-solid fa-battery-full"></i> <span>100%</span></div>
            <div class="taskbar-time" id="taskbar-time"></div>
        </div>
    </div>

    <!-- Start Menu -->
    <div id="start-menu">
        <div class="start-header">
            <i class="fa-regular fa-user"></i> Jakub
        </div>
        <div class="start-apps">
            <div class="start-app" onclick="openApp('settings')"><i class="fa-solid fa-gear"></i><span>Nastavení</span></div>
            <div class="start-app" onclick="openFileManager()"><i class="fa-regular fa-folder"></i><span>Explorer</span></div>
            <div class="start-app" onclick="openTerminal()"><i class="fa-solid fa-terminal"></i><span>Terminál</span></div>
            <div class="start-app" onclick="openApp('calculator')"><i class="fa-solid fa-calculator"></i><span>Kalkulačka</span></div>
            <div class="start-app" onclick="openThisPC()"><i class="fa-solid fa-computer"></i><span>Tento PC</span></div>
            <div class="start-app" onclick="openApp('edge')"><i class="fa-brands fa-edge"></i><span>Edge</span></div>
            <div class="start-app" onclick="openApp('firefox')"><i class="fa-brands fa-firefox-browser"></i><span>Firefox</span></div>
            <div class="start-app" onclick="openApp('store')"><i class="fa-solid fa-store"></i><span>Store</span></div>
        </div>
    </div>

    <script>
        // ====================================================================
        // GLOBÁLNÍ PROMĚNNÉ
        // ====================================================================
        let windows = [];
        let zIndexCounter = 100;
        let draggedWindow = null;
        let dragOffsetX, dragOffsetY;
        let startMenuVisible = false;

        // ====================================================================
        // POMOCNÉ FUNKCE
        // ====================================================================
        function updateClock() {
            const now = new Date();
            const timeStr = now.toLocaleTimeString('cs-CZ', { hour: '2-digit', minute: '2-digit' });
            document.getElementById('taskbar-time').innerText = timeStr;
        }
        setInterval(updateClock, 1000);
        updateClock();

        // Načtení Wi‑Fi stavu z API
        function updateWifi() {
            fetch('/api/wifi')
                .then(r => r.text())
                .then(status => document.getElementById('wifi-status').innerText = status);
        }
        setInterval(updateWifi, 5000);
        updateWifi();

        // ====================================================================
        // SPRÁVA OKEN
        // ====================================================================
        function createWindow(title, contentHtml, width = 600, height = 400, x = 100, y = 100) {
            const id = 'win_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5);
            const desktop = document.getElementById('desktop');

            const winDiv = document.createElement('div');
            winDiv.className = 'window';
            winDiv.id = id;
            winDiv.style.width = width + 'px';
            winDiv.style.height = height + 'px';
            winDiv.style.left = x + 'px';
            winDiv.style.top = y + 'px';
            winDiv.style.zIndex = ++zIndexCounter;

            // Hlavička
            const header = document.createElement('div');
            header.className = 'window-header';
            header.innerHTML = `
                <div class="window-title"><i class="fa-regular fa-window-maximize"></i> ${title}</div>
                <div class="window-controls">
                    <button class="window-btn" onclick="minimizeWindow('${id}')"><i class="fa-solid fa-minus"></i></button>
                    <button class="window-btn" onclick="maximizeWindow('${id}')"><i class="fa-solid fa-square"></i></button>
                    <button class="window-btn close-btn" onclick="closeWindow('${id}')"><i class="fa-solid fa-xmark"></i></button>
                </div>
            `;
            // Obsah
            const content = document.createElement('div');
            content.className = 'window-content';
            content.innerHTML = contentHtml;

            winDiv.appendChild(header);
            winDiv.appendChild(content);
            desktop.appendChild(winDiv);

            // Události pro přetahování
            header.addEventListener('mousedown', (e) => startDrag(e, winDiv));
            winDiv.addEventListener('mousedown', () => bringToFront(winDiv));

            windows.push({ id, element: winDiv, title, minimized: false, maximized: false });
            return id;
        }

        function startDrag(e, win) {
            if (e.target.closest('.window-btn')) return; // nechytat tlačítka
            draggedWindow = win;
            const rect = win.getBoundingClientRect();
            dragOffsetX = e.clientX - rect.left;
            dragOffsetY = e.clientY - rect.top;
            document.addEventListener('mousemove', onDrag);
            document.addEventListener('mouseup', stopDrag);
            e.preventDefault();
        }

        function onDrag(e) {
            if (!draggedWindow) return;
            let newX = e.clientX - dragOffsetX;
            let newY = e.clientY - dragOffsetY;
            // Omezení na desktop (s rezervou pro taskbar)
            const desktop = document.getElementById('desktop');
            const maxX = desktop.clientWidth - draggedWindow.offsetWidth;
            const maxY = desktop.clientHeight - draggedWindow.offsetHeight - 48; // nad taskbarem
            newX = Math.max(0, Math.min(newX, maxX));
            newY = Math.max(0, Math.min(newY, maxY));
            draggedWindow.style.left = newX + 'px';
            draggedWindow.style.top = newY + 'px';
        }

        function stopDrag() {
            draggedWindow = null;
            document.removeEventListener('mousemove', onDrag);
            document.removeEventListener('mouseup', stopDrag);
        }

        function bringToFront(win) {
            win.style.zIndex = ++zIndexCounter;
        }

        function minimizeWindow(id) {
            const win = document.getElementById(id);
            if (win) {
                win.classList.add('minimized');
                const w = windows.find(w => w.id === id);
                if (w) w.minimized = true;
            }
        }

        function maximizeWindow(id) {
            const win = document.getElementById(id);
            if (!win) return;
            const w = windows.find(w => w.id === id);
            if (w && w.maximized) {
                // obnovit původní velikost – pro jednoduchost jen odstraníme třídu
                win.classList.remove('maximized');
                w.maximized = false;
            } else {
                win.classList.add('maximized');
                w.maximized = true;
                w.minimized = false;
                win.classList.remove('minimized');
            }
        }

        function closeWindow(id) {
            const win = document.getElementById(id);
            if (win) {
                win.remove();
                windows = windows.filter(w => w.id !== id);
            }
        }

        // ====================================================================
        // APLIKACE
        // ====================================================================
        function openFileManager() {
            const content = `
                <div class="flex-row">
                    <div class="fm-sidebar">
                        <div class="fm-sidebar-item"><i class="fa-regular fa-house"></i> Home</div>
                        <div class="fm-sidebar-item"><i class="fa-regular fa-image"></i> Gallery</div>
                        <div class="fm-sidebar-item"><i class="fa-brands fa-onedrive"></i> OneDrive</div>
                        <div class="fm-sidebar-item"><i class="fa-regular fa-desktop"></i> Desktop</div>
                        <div class="fm-sidebar-item"><i class="fa-regular fa-file"></i> Documents</div>
                        <div class="fm-sidebar-item"><i class="fa-regular fa-image"></i> Pictures</div>
                        <div class="fm-sidebar-item"><i class="fa-regular fa-music"></i> Music</div>
                        <div class="fm-sidebar-item"><i class="fa-regular fa-video"></i> Videos</div>
                    </div>
                    <div class="fm-main">
                        <div class="icon-grid">
                            <div class="file-icon"><i class="fa-regular fa-folder"></i><span>Desktop</span></div>
                            <div class="file-icon"><i class="fa-regular fa-folder"></i><span>Downloads</span></div>
                            <div class="file-icon"><i class="fa-regular fa-folder"></i><span>Documents</span></div>
                            <div class="file-icon"><i class="fa-regular fa-folder"></i><span>Pictures</span></div>
                            <div class="file-icon"><i class="fa-regular fa-folder"></i><span>Music</span></div>
                            <div class="file-icon"><i class="fa-regular fa-folder"></i><span>Videos</span></div>
                        </div>
                    </div>
                </div>
            `;
            createWindow('Souborový manažer', content, 700, 450, 150, 100);
        }

        function openThisPC() {
            fetch('/api/disks')
                .then(r => r.json())
                .then(disks => {
                    let html = '<div class="flex-col">';
                    disks.forEach(disk => {
                        const totalGB = (disk.total / 1e9).toFixed(1);
                        const usedGB = (disk.used / 1e9).toFixed(1);
                        html += `
                            <div class="disk-item">
                                <div class="disk-info">
                                    <span><i class="fa-regular fa-hard-drive"></i> ${disk.name} (${disk.device})</span>
                                    <span>${usedGB} GB / ${totalGB} GB</span>
                                </div>
                                <div class="progress-bar">
                                    <div class="progress-fill" style="width: ${disk.percent}%"></div>
                                </div>
                            </div>
                        `;
                    });
                    html += '</div>';
                    createWindow('Tento PC', html, 500, 350, 200, 150);
                });
        }

        function openTerminal() {
            const content = `
                <div style="display: flex; flex-direction: column; height: 100%;">
                    <div id="term-output" style="background: rgba(0,0,0,0.3); border-radius: 8px; padding: 10px; flex: 1; overflow-y: auto; font-family: monospace; white-space: pre-wrap; color: #0f0;"></div>
                    <div style="display: flex; margin-top: 8px;">
                        <span style="color: #0f0; margin-right: 5px;">$</span>
                        <input type="text" id="term-input" style="flex: 1; background: rgba(0,0,0,0.5); border: none; border-radius: 4px; color: #0f0; padding: 5px; font-family: monospace;" placeholder="zadej příkaz">
                    </div>
                </div>
            `;
            const winId = createWindow('Terminál', content, 600, 400, 250, 200);
            // Po vytvoření okna připojíme event listener na input
            setTimeout(() => {
                const input = document.getElementById('term-input');
                if (input) {
                    input.addEventListener('keypress', (e) => {
                        if (e.key === 'Enter') {
                            const cmd = input.value;
                            const outputDiv = document.getElementById('term-output');
                            outputDiv.innerHTML += `$ ${cmd}\\n`;
                            fetch('/api/cmd', {
                                method: 'POST',
                                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                                body: 'cmd=' + encodeURIComponent(cmd)
                            })
                            .then(r => r.text())
                            .then(data => {
                                outputDiv.innerHTML += data + '\\n';
                                outputDiv.scrollTop = outputDiv.scrollHeight;
                            });
                            input.value = '';
                        }
                    });
                }
            }, 100);
        }

        function openApp(appName) {
            if (appName === 'filemanager') openFileManager();
            else if (appName === 'thispc') openThisPC();
            else if (appName === 'terminal') openTerminal();
            else {
                createWindow(appName.charAt(0).toUpperCase() + appName.slice(1), `<div style="padding:20px; text-align:center;">Aplikace ${appName} by zde byla otevřena.</div>`, 400, 250, 300, 150);
            }
        }

        // ====================================================================
        // START MENU
        // ====================================================================
        function toggleStartMenu() {
            const menu = document.getElementById('start-menu');
            startMenuVisible = !startMenuVisible;
            if (startMenuVisible) {
                menu.classList.add('visible');
            } else {
                menu.classList.remove('visible');
            }
        }

        // Kliknutí mimo start menu ho zavře
        document.addEventListener('click', function(e) {
            const menu = document.getElementById('start-menu');
            const startBtn = document.querySelector('.taskbar-icon:first-child');
            if (startMenuVisible && !menu.contains(e.target) && !startBtn.contains(e.target)) {
                menu.classList.remove('visible');
                startMenuVisible = false;
            }
        });

        // ====================================================================
        // INICIALIZACE – vytvoříme úvodní okna
        // ====================================================================
        window.onload = function() {
            openFileManager();
            openThisPC();
        };
    </script>
</body>
</html>
"""

# ============================================================================
# ROUTY FLASK
# ============================================================================

@app.route('/')
def index():
    return render_template_string(HTML_TEMPLATE)

@app.route('/api/disks')
def api_disks():
    return jsonify(get_disks())

@app.route('/api/wifi')
def api_wifi():
    return get_wifi_status()

@app.route('/api/cmd', methods=['POST'])
def api_cmd():
    cmd = request.form.get('cmd', '')
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        output = result.stdout + result.stderr
    except Exception as e:
        output = str(e)
    return output

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
EOF

echo "✅ Soubor app.py byl vytvořen."

echo "🚀 Spouštím server..."
echo "Pro přístup otevři prohlížeč na adrese: http://$(hostname -I | awk '{print $1}'):5000"
echo "Pro ukončení serveru stiskni Ctrl+C."

cd ~/meowos-web
python3 app.py
EOF
