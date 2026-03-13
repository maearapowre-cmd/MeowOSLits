#!/bin/bash
# MeowOS Arch – finální verze s opraveným Nastavením a prohlížečem
# Autor: Jakub (s asistencí AI)

set -e

echo "🔧 Aktualizuji systém a instaluji potřebné balíčky..."
sudo apt update
sudo apt install -y python3-flask python3-psutil wireless-tools

echo "📁 Vytvářím složku pro aplikaci..."
mkdir -p ~/meowos-arch
cd ~/meowos-arch

echo "🐧 Vytvářím hlavní soubor app.py (může to chvíli trvat)..."

cat > app.py << 'EOF'
#!/usr/bin/env python3
"""
MeowOS Arch – finální verze s opraveným Nastavením a prohlížečem
"""

import os
import psutil
import subprocess
import json
import time
from datetime import datetime
from flask import Flask, render_template_string, jsonify, request

app = Flask(__name__)

# ============================================================================
# Konfigurace
# ============================================================================
CONFIG_FILE = os.path.expanduser('~/meowos-arch/config.json')

DEFAULT_CONFIG = {
    'username': 'Jakub',
    'wallpaper': 'linear-gradient(145deg, #0f172a, #1e293b)',
    'primary_color': '#4facfe',
    'widget_bg_color': '#0f192a',
    'widget_opacity': 0.8,
    'theme': 'dark',
    'font_size': '14px',
    'avatar': 'user-astronaut',
    'wifi_enabled': True,
    'volume': 80,
    'default_window_width': 600,
    'default_window_height': 400
}

def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, 'r') as f:
                config = json.load(f)
                for k, v in DEFAULT_CONFIG.items():
                    if k not in config:
                        config[k] = v
                return config
        except:
            return DEFAULT_CONFIG.copy()
    return DEFAULT_CONFIG.copy()

def save_config(config):
    with open(CONFIG_FILE, 'w') as f:
        json.dump(config, f, indent=2)

# ============================================================================
# Systémové funkce
# ============================================================================
def get_cpu_temperature():
    try:
        with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
            return round(int(f.read().strip()) / 1000, 1)
    except:
        return 0

def get_disks():
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
    try:
        result = subprocess.run(['iwgetid', '-r'], capture_output=True, text=True, timeout=2)
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except:
        pass
    return 'Nepřipojeno'

def get_ip_addresses():
    ips = []
    try:
        for iface in psutil.net_if_addrs():
            for addr in psutil.net_if_addrs()[iface]:
                if addr.family == 2:
                    ips.append(f"{iface}: {addr.address}")
    except:
        pass
    return ips

def get_system_info():
    return {
        'hostname': os.uname().nodename,
        'os': f"{os.uname().sysname} {os.uname().release}",
        'cpu': psutil.cpu_percent(interval=0.1),
        'ram': psutil.virtual_memory().percent,
        'temp': get_cpu_temperature(),
        'uptime': time.time() - psutil.boot_time(),
        'disks': get_disks(),
        'ips': get_ip_addresses()
    }

# ============================================================================
# HTML šablona
# ============================================================================
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="cs">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MeowOS Arch</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: 'Segoe UI', 'Roboto', system-ui, sans-serif;
        }

        :root {
            --wallpaper: {{ wallpaper }};
            --primary: {{ primary_color }};
            --widget-bg: {{ widget_bg_color }};
            --widget-opacity: {{ widget_opacity }};
            --theme: {{ theme }};
            --text-color: {% if theme == 'dark' %}white{% else %}black{% endif %};
            --font-size: {{ font_size }};
            --default-win-width: {{ default_window_width }}px;
            --default-win-height: {{ default_window_height }}px;
        }

        body {
            width: 100vw;
            height: 100vh;
            overflow: hidden;
            background: var(--wallpaper);
            background-size: cover;
            background-position: center;
            position: relative;
            transition: background 0.3s, color 0.2s;
            color: var(--text-color);
            font-size: var(--font-size);
        }

        #desktop {
            width: 100%;
            height: 100%;
            padding-bottom: 48px;
            position: relative;
            overflow: hidden;
        }

        .window {
            position: absolute;
            min-width: 300px;
            min-height: 200px;
            width: var(--default-win-width);
            height: var(--default-win-height);
            background: color-mix(in srgb, var(--widget-bg) calc(var(--widget-opacity) * 100%), transparent);
            backdrop-filter: blur(15px);
            -webkit-backdrop-filter: blur(15px);
            border: 1px solid rgba(255,255,255,0.1);
            border-radius: 12px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.6);
            display: flex;
            flex-direction: column;
            z-index: 10;
            color: var(--text-color);
            resize: both;
            overflow: auto;
        }
        .window.maximized {
            width: 100% !important;
            height: calc(100% - 48px) !important;
            top: 0 !important;
            left: 0 !important;
            border-radius: 0;
            resize: none;
        }
        .window.minimized {
            display: none !important;
        }
        .window-header {
            background: color-mix(in srgb, var(--widget-bg) 90%, black);
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
            color: var(--text-color);
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
            color: var(--text-color);
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
        .window-content {
            flex: 1;
            padding: 16px;
            overflow-y: auto;
        }

        #taskbar {
            position: fixed;
            bottom: 0;
            left: 0;
            width: 100%;
            height: 48px;
            background: color-mix(in srgb, var(--widget-bg) calc(var(--widget-opacity) * 100%), transparent);
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            border-top: 1px solid rgba(255,255,255,0.1);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 1000;
            color: white;
        }
        .taskbar-center {
            display: flex;
            gap: 4px;
            background: rgba(255,255,255,0.03);
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
            font-size: 20px;
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

        #start-menu {
            position: fixed;
            bottom: 60px;
            left: 50%;
            transform: translateX(-50%);
            width: 520px;
            background: color-mix(in srgb, var(--widget-bg) calc(var(--widget-opacity) * 100%), transparent);
            backdrop-filter: blur(30px);
            -webkit-backdrop-filter: blur(30px);
            border-radius: 20px;
            border: 1px solid rgba(255,255,255,0.1);
            padding: 20px;
            color: white;
            box-shadow: 0 30px 60px rgba(0,0,0,0.8);
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
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .start-apps {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 12px;
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
            font-size: 24px;
        }
        .start-app span {
            font-size: 11px;
            text-align: center;
        }

        .icon-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(90px, 1fr));
            gap: 16px;
            padding: 10px;
        }
        .file-icon {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 6px;
            padding: 12px 6px;
            border-radius: 10px;
            background: color-mix(in srgb, var(--widget-bg) calc(var(--widget-opacity) * 100%), transparent);
            backdrop-filter: blur(5px);
            border: 1px solid rgba(255,255,255,0.1);
            cursor: pointer;
            transition: 0.2s;
            text-align: center;
        }
        .file-icon:hover {
            background: rgba(255,255,255,0.15);
        }
        .file-icon i {
            font-size: 36px;
            filter: drop-shadow(0 8px 6px rgba(0,0,0,0.5));
        }

        .terminal-container {
            display: flex;
            flex-direction: column;
            height: 100%;
            background: rgba(0,0,0,0.3);
            border-radius: 8px;
            font-family: 'Courier New', monospace;
        }
        .terminal-output {
            flex: 1;
            padding: 10px;
            overflow-y: auto;
            color: #0f0;
            white-space: pre-wrap;
            font-size: 14px;
        }
        .terminal-input-line {
            display: flex;
            padding: 5px 10px;
            background: rgba(0,0,0,0.5);
            border-top: 1px solid #0f0;
        }
        .terminal-prompt {
            color: #0f0;
            margin-right: 8px;
            font-weight: bold;
        }
        .terminal-input {
            flex: 1;
            background: transparent;
            border: none;
            color: #0f0;
            font-family: 'Courier New', monospace;
            font-size: 14px;
            outline: none;
        }

        .calculator {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 6px;
            padding: 10px;
            background: rgba(0,0,0,0.2);
            border-radius: 8px;
        }
        .calc-display {
            grid-column: span 4;
            background: rgba(0,0,0,0.5);
            color: white;
            text-align: right;
            padding: 12px;
            font-size: 24px;
            border-radius: 6px;
            margin-bottom: 8px;
            font-family: monospace;
        }
        .calc-btn {
            background: rgba(255,255,255,0.1);
            border: none;
            color: white;
            padding: 12px;
            font-size: 16px;
            border-radius: 6px;
            cursor: pointer;
        }
        .calc-btn:hover {
            background: rgba(255,255,255,0.2);
        }
        .calc-btn.operator {
            background: var(--primary);
            opacity: 0.7;
        }

        .settings-tabs {
            display: flex;
            gap: 5px;
            margin-bottom: 20px;
            border-bottom: 1px solid rgba(255,255,255,0.2);
            padding-bottom: 10px;
            flex-wrap: wrap;
        }
        .settings-tab {
            padding: 8px 16px;
            border-radius: 20px;
            cursor: pointer;
            background: rgba(255,255,255,0.05);
        }
        .settings-tab.active {
            background: var(--primary);
            opacity: 0.8;
        }
        .settings-panel {
            display: none;
        }
        .settings-panel.active {
            display: block;
        }
        .settings-row {
            margin-bottom: 15px;
        }
        .settings-label {
            display: block;
            margin-bottom: 5px;
            opacity: 0.7;
            font-size: 13px;
        }
        .settings-input, .settings-select {
            width: 100%;
            padding: 8px;
            background: rgba(0,0,0,0.3);
            border: 1px solid rgba(255,255,255,0.2);
            border-radius: 6px;
            color: inherit;
        }
        .settings-btn {
            background: var(--primary);
            border: none;
            color: white;
            padding: 8px 16px;
            border-radius: 6px;
            cursor: pointer;
            margin-right: 10px;
        }
        .wallpaper-option {
            display: inline-block;
            width: 80px;
            height: 50px;
            margin: 5px;
            border-radius: 6px;
            cursor: pointer;
            border: 2px solid transparent;
            background-size: cover;
            background-position: center;
        }
        .wallpaper-option:hover {
            border-color: white;
        }
        .color-preview {
            width: 30px;
            height: 30px;
            border-radius: 6px;
            display: inline-block;
            margin-right: 10px;
            vertical-align: middle;
            border: 1px solid rgba(255,255,255,0.3);
        }
        .slider {
            width: 100%;
            margin: 10px 0;
        }
        .url-input {
            display: flex;
            gap: 10px;
            margin-top: 10px;
        }
        .url-input input {
            flex: 1;
        }
        .browser-input {
            display: flex;
            gap: 10px;
            margin-bottom: 15px;
        }
        .browser-input input {
            flex: 1;
            padding: 8px;
            background: rgba(0,0,0,0.3);
            border: 1px solid rgba(255,255,255,0.2);
            border-radius: 6px;
            color: white;
        }
    </style>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
</head>
<body>
    <!-- Předání konfigurace do JavaScriptu -->
    <script>
        window.meowConfig = {
            username: {{ username|tojson }},
            wallpaper: {{ wallpaper|tojson }},
            primary_color: {{ primary_color|tojson }},
            widget_bg_color: {{ widget_bg_color|tojson }},
            widget_opacity: {{ widget_opacity|tojson }},
            theme: {{ theme|tojson }},
            font_size: {{ font_size|tojson }},
            avatar: {{ avatar|tojson }},
            wifi_enabled: {{ wifi_enabled|tojson }},
            volume: {{ volume|tojson }},
            default_window_width: {{ default_window_width|tojson }},
            default_window_height: {{ default_window_height|tojson }}
        };
    </script>

    <div id="desktop"></div>

    <div id="taskbar">
        <div class="taskbar-center">
            <div class="taskbar-icon" onclick="toggleStartMenu()"><i class="fa-brands fa-linux"></i></div>
            <div class="taskbar-icon" onclick="openBrowserWindow()"><i class="fa-solid fa-globe"></i></div>
            <div class="taskbar-icon" onclick="openFileManager()"><i class="fa-regular fa-folder-open"></i></div>
            <div class="taskbar-icon" onclick="openTerminal()"><i class="fa-solid fa-terminal"></i></div>
            <div class="taskbar-icon" onclick="openCalculator()"><i class="fa-solid fa-calculator"></i></div>
        </div>
        <div class="taskbar-right">
            <div class="taskbar-icon" onclick="openSettings()"><i class="fa-solid fa-gear"></i></div>
            <div><i class="fa-solid fa-wifi"></i> <span id="wifi-status">Načítám...</span></div>
            <div><i class="fa-solid fa-battery-full"></i> <span>100%</span></div>
            <div class="taskbar-time" id="taskbar-time"></div>
        </div>
    </div>

    <div id="start-menu">
        <div class="start-header">
            <i class="fa-solid fa-{{ avatar }}"></i> <span id="start-username">{{ username }}</span>
        </div>
        <div class="start-apps">
            <div class="start-app" onclick="openSettings()"><i class="fa-solid fa-gear"></i><span>Nastavení</span></div>
            <div class="start-app" onclick="openFileManager()"><i class="fa-regular fa-folder"></i><span>Správce</span></div>
            <div class="start-app" onclick="openTerminal()"><i class="fa-solid fa-terminal"></i><span>Terminál</span></div>
            <div class="start-app" onclick="openCalculator()"><i class="fa-solid fa-calculator"></i><span>Kalkulačka</span></div>
            <div class="start-app" onclick="openThisPC()"><i class="fa-solid fa-computer"></i><span>Tento PC</span></div>
            <div class="start-app" onclick="openBrowserWindow()"><i class="fa-solid fa-globe"></i><span>Prohlížeč</span></div>
            <div class="start-app" onclick="openApp('store')"><i class="fa-solid fa-store"></i><span>Obchod</span></div>
            <div class="start-app" onclick="openApp('calendar')"><i class="fa-regular fa-calendar"></i><span>Kalendář</span></div>
        </div>
    </div>

    <script>
        // ========================= GLOBÁLNÍ PROMĚNNÉ =========================
        let windows = [];
        let zIndexCounter = 100;
        let draggedWindow = null;
        let dragOffsetX, dragOffsetY;
        let startMenuVisible = false;
        let terminalHistory = [];
        let historyIndex = -1;

        // ========================= POMOCNÉ FUNKCE =========================
        function updateClock() {
            const now = new Date();
            document.getElementById('taskbar-time').innerText = now.toLocaleTimeString('cs-CZ', { hour: '2-digit', minute: '2-digit' });
        }
        setInterval(updateClock, 1000);
        updateClock();

        function updateWifi() {
            fetch('/api/wifi').then(r => r.text()).then(s => document.getElementById('wifi-status').innerText = s);
        }
        setInterval(updateWifi, 5000);
        updateWifi();

        // ========================= SPRÁVA OKEN =========================
        function createWindow(title, contentHtml, width = null, height = null, x = 100, y = 100) {
            const id = 'win_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5);
            const desktop = document.getElementById('desktop');

            const defaultWidth = meowConfig.default_window_width || 600;
            const defaultHeight = meowConfig.default_window_height || 400;

            const winDiv = document.createElement('div');
            winDiv.className = 'window';
            winDiv.id = id;
            winDiv.style.width = (width || defaultWidth) + 'px';
            winDiv.style.height = (height || defaultHeight) + 'px';
            winDiv.style.left = x + 'px';
            winDiv.style.top = y + 'px';
            winDiv.style.zIndex = ++zIndexCounter;

            const header = document.createElement('div');
            header.className = 'window-header';
            header.innerHTML = `
                <div class="window-title"><i class="fa-brands fa-linux"></i> ${title}</div>
                <div class="window-controls">
                    <button class="window-btn" onclick="minimizeWindow('${id}')"><i class="fa-solid fa-minus"></i></button>
                    <button class="window-btn" onclick="maximizeWindow('${id}')"><i class="fa-solid fa-square"></i></button>
                    <button class="window-btn close-btn" onclick="closeWindow('${id}')"><i class="fa-solid fa-xmark"></i></button>
                </div>
            `;
            const content = document.createElement('div');
            content.className = 'window-content';
            content.innerHTML = contentHtml;

            winDiv.appendChild(header);
            winDiv.appendChild(content);
            desktop.appendChild(winDiv);

            header.addEventListener('mousedown', (e) => startDrag(e, winDiv));
            winDiv.addEventListener('mousedown', () => bringToFront(winDiv));

            windows.push({ id, element: winDiv });
            return id;
        }

        function startDrag(e, win) {
            if (e.target.closest('.window-btn')) return;
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
            const desktop = document.getElementById('desktop');
            const maxX = desktop.clientWidth - draggedWindow.offsetWidth;
            const maxY = desktop.clientHeight - draggedWindow.offsetHeight - 48;
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
            document.getElementById(id)?.classList.add('minimized');
        }

        function maximizeWindow(id) {
            const win = document.getElementById(id);
            if (!win) return;
            win.classList.toggle('maximized');
            win.classList.remove('minimized');
        }

        function closeWindow(id) {
            document.getElementById(id)?.remove();
            windows = windows.filter(w => w.id !== id);
        }

        // ========================= APLIKACE =========================
        function openFileManager() {
            createWindow('Správce souborů', `
                <div style="display: flex; gap: 15px;">
                    <div style="width: 180px; background: rgba(0,0,0,0.2); border-radius: 8px; padding: 10px;">
                        <div style="padding: 8px;"><i class="fa-regular fa-house"></i> Domů</div>
                        <div style="padding: 8px;"><i class="fa-regular fa-image"></i> Obrázky</div>
                        <div style="padding: 8px;"><i class="fa-regular fa-file"></i> Dokumenty</div>
                        <div style="padding: 8px;"><i class="fa-regular fa-music"></i> Hudba</div>
                        <div style="padding: 8px;"><i class="fa-regular fa-video"></i> Videa</div>
                    </div>
                    <div style="flex:1;">
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
            `, null, null, 120, 80);
        }

        function openThisPC() {
            fetch('/api/disks')
                .then(r => r.json())
                .then(disks => {
                    let html = '<div style="display: flex; flex-direction: column; gap: 15px;">';
                    disks.forEach(disk => {
                        const total = (disk.total / 1e9).toFixed(1);
                        const used = (disk.used / 1e9).toFixed(1);
                        html += `
                            <div>
                                <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
                                    <span><i class="fa-regular fa-hard-drive"></i> ${disk.name}</span>
                                    <span>${used} GB / ${total} GB</span>
                                </div>
                                <div style="width:100%; height:8px; background: rgba(255,255,255,0.2); border-radius:4px;">
                                    <div style="width:${disk.percent}%; height:100%; background: linear-gradient(90deg, var(--primary), #00f2fe); border-radius:4px;"></div>
                                </div>
                            </div>
                        `;
                    });
                    html += '</div>';
                    createWindow('Tento počítač', html, 500, 300, 180, 120);
                });
        }

        function openTerminal() {
            const termId = 'term-' + Date.now();
            const content = `
                <div class="terminal-container" id="${termId}">
                    <div class="terminal-output" id="${termId}-output">Vítejte v terminálu\\n</div>
                    <div class="terminal-input-line">
                        <span class="terminal-prompt">$</span>
                        <input type="text" class="terminal-input" id="${termId}-input" autofocus>
                    </div>
                </div>
            `;
            const winId = createWindow('Terminál', content, 600, 380, 200, 150);
            setTimeout(() => {
                const input = document.getElementById(`${termId}-input`);
                const output = document.getElementById(`${termId}-output`);
                if (!input) return;

                input.addEventListener('keydown', function(e) {
                    if (e.key === 'Enter') {
                        const cmd = input.value;
                        output.innerHTML += `$ ${cmd}\\n`;
                        fetch('/api/cmd', {
                            method: 'POST',
                            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                            body: 'cmd=' + encodeURIComponent(cmd)
                        })
                        .then(r => r.text())
                        .then(data => {
                            output.innerHTML += data + '\\n';
                            output.scrollTop = output.scrollHeight;
                        });
                        terminalHistory.push(cmd);
                        historyIndex = terminalHistory.length;
                        input.value = '';
                    } else if (e.key === 'ArrowUp') {
                        if (historyIndex > 0) {
                            historyIndex--;
                            input.value = terminalHistory[historyIndex];
                        }
                        e.preventDefault();
                    } else if (e.key === 'ArrowDown') {
                        if (historyIndex < terminalHistory.length - 1) {
                            historyIndex++;
                            input.value = terminalHistory[historyIndex];
                        } else {
                            historyIndex = terminalHistory.length;
                            input.value = '';
                        }
                        e.preventDefault();
                    }
                });
            }, 100);
        }

        function openCalculator() {
            createWindow('Kalkulačka', `
                <div class="calculator">
                    <div class="calc-display" id="calc-display">0</div>
                    <button class="calc-btn" onclick="calcInput('7')">7</button>
                    <button class="calc-btn" onclick="calcInput('8')">8</button>
                    <button class="calc-btn" onclick="calcInput('9')">9</button>
                    <button class="calc-btn operator" onclick="calcOperator('/')">/</button>
                    <button class="calc-btn" onclick="calcInput('4')">4</button>
                    <button class="calc-btn" onclick="calcInput('5')">5</button>
                    <button class="calc-btn" onclick="calcInput('6')">6</button>
                    <button class="calc-btn operator" onclick="calcOperator('*')">*</button>
                    <button class="calc-btn" onclick="calcInput('1')">1</button>
                    <button class="calc-btn" onclick="calcInput('2')">2</button>
                    <button class="calc-btn" onclick="calcInput('3')">3</button>
                    <button class="calc-btn operator" onclick="calcOperator('-')">-</button>
                    <button class="calc-btn" onclick="calcInput('0')">0</button>
                    <button class="calc-btn" onclick="calcDot()">.</button>
                    <button class="calc-btn" onclick="calcEquals()">=</button>
                    <button class="calc-btn operator" onclick="calcOperator('+')">+</button>
                    <button class="calc-btn" style="grid-column: span 4;" onclick="calcClear()">C</button>
                </div>
            `, 300, 380, 220, 180);
        }

        window.calcInput = function(d) {
            const disp = document.getElementById('calc-display');
            if (disp.innerText === '0') disp.innerText = d;
            else disp.innerText += d;
        };
        window.calcOperator = function(op) {
            const disp = document.getElementById('calc-display');
            disp.innerText += ' ' + op + ' ';
        };
        window.calcDot = function() {
            const disp = document.getElementById('calc-display');
            if (!disp.innerText.includes('.')) disp.innerText += '.';
        };
        window.calcClear = function() {
            document.getElementById('calc-display').innerText = '0';
        };
        window.calcEquals = function() {
            try {
                const result = eval(document.getElementById('calc-display').innerText);
                document.getElementById('calc-display').innerText = result;
            } catch {
                document.getElementById('calc-display').innerText = 'Error';
            }
        };

        function openBrowserWindow() {
            createWindow('Prohlížeč', `
                <div style="padding: 20px;">
                    <div class="browser-input">
                        <input type="text" id="browser-url" placeholder="Zadejte URL (např. https://seznam.cz)">
                        <button class="settings-btn" onclick="navigateBrowser()">Otevřít</button>
                    </div>
                    <p style="color: #ccc; font-size: 12px;">Stránka se otevře v novém okně tvého prohlížeče.</p>
                </div>
            `, 500, 200, 250, 150);
        }

        window.navigateBrowser = function() {
            const url = document.getElementById('browser-url').value;
            if (url) {
                let fullUrl = url;
                if (!url.startsWith('http://') && !url.startsWith('https://')) {
                    fullUrl = 'https://' + url;
                }
                window.open(fullUrl, '_blank');
            }
        };

        function openApp(app) {
            if (app === 'store') createWindow('Obchod', '<div style="padding:20px; text-align:center;">Obchod s aplikacemi (demo)</div>', 400, 300, 200, 150);
            else if (app === 'calendar') createWindow('Kalendář', '<div style="padding:20px; text-align:center;">Kalendář (demo)</div>', 400, 300, 200, 150);
        }

        // ========================= NASTAVENÍ =========================
        function openSettings() {
            fetch('/api/system-info')
                .then(r => r.json())
                .then(info => {
                    const uptime = Math.floor(info.uptime / 3600) + 'h ' + Math.floor((info.uptime % 3600) / 60) + 'm';
                    const content = `
                        <div>
                            <div class="settings-tabs">
                                <div class="settings-tab active" onclick="showSettingsTab('vzhled')">Vzhled</div>
                                <div class="settings-tab" onclick="showSettingsTab('okna')">Okna</div>
                                <div class="settings-tab" onclick="showSettingsTab('system')">Systém</div>
                                <div class="settings-tab" onclick="showSettingsTab('uzivatele')">Uživatelé</div>
                                <div class="settings-tab" onclick="showSettingsTab('sit')">Síť</div>
                                <div class="settings-tab" onclick="showSettingsTab('zvuk')">Zvuk</div>
                                <div class="settings-tab" onclick="showSettingsTab('napajeni')">Napájení</div>
                                <div class="settings-tab" onclick="showSettingsTab('o-aplikaci')">O aplikaci</div>
                            </div>
                            <div id="settings-vzhled" class="settings-panel active">
                                <div class="settings-row">
                                    <div class="settings-label">Tapeta</div>
                                    <div>
                                        <div class="wallpaper-option" style="background: linear-gradient(145deg, #0f172a, #1e293b);" onclick="changeWallpaper('linear-gradient(145deg, #0f172a, #1e293b)')"></div>
                                        <div class="wallpaper-option" style="background: linear-gradient(145deg, #2d1a3a, #1a2f3f);" onclick="changeWallpaper('linear-gradient(145deg, #2d1a3a, #1a2f3f)')"></div>
                                        <div class="wallpaper-option" style="background: linear-gradient(145deg, #1a3a2d, #1a2f3f);" onclick="changeWallpaper('linear-gradient(145deg, #1a3a2d, #1a2f3f)')"></div>
                                        <div class="wallpaper-option" style="background: url('https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=200') center/cover;" onclick="changeWallpaper('url(https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800)')"></div>
                                        <div class="wallpaper-option" style="background: url('https://images.unsplash.com/photo-1510798831971-661eb04b3739?w=200') center/cover;" onclick="changeWallpaper('url(https://images.unsplash.com/photo-1510798831971-661eb04b3739?w=800)')"></div>
                                    </div>
                                    <div class="url-input">
                                        <input type="text" id="wallpaper-url" placeholder="Nebo zadej URL obrázku...">
                                        <button class="settings-btn" onclick="setWallpaperFromUrl()">Nastavit</button>
                                    </div>
                                </div>
                                <div class="settings-row">
                                    <div class="settings-label">Primární barva</div>
                                    <div>
                                        <span class="color-preview" style="background: ${meowConfig.primary_color};"></span>
                                        <input type="color" id="primary-color" value="${meowConfig.primary_color}" onchange="changePrimaryColor(this.value)">
                                    </div>
                                </div>
                                <div class="settings-row">
                                    <div class="settings-label">Barva widgetů</div>
                                    <div>
                                        <span class="color-preview" style="background: ${meowConfig.widget_bg_color};"></span>
                                        <input type="color" id="widget-bg-color" value="${meowConfig.widget_bg_color}" onchange="changeWidgetBgColor(this.value)">
                                    </div>
                                </div>
                                <div class="settings-row">
                                    <div class="settings-label">Průhlednost widgetů (${Math.round(meowConfig.widget_opacity*100)}%)</div>
                                    <input type="range" min="0.3" max="1" step="0.05" value="${meowConfig.widget_opacity}" class="slider" id="widget-opacity-slider" oninput="changeWidgetOpacity(this.value)">
                                </div>
                                <div class="settings-row">
                                    <div class="settings-label">Barevný režim</div>
                                    <select class="settings-select" id="theme-select" onchange="changeTheme(this.value)">
                                        <option value="dark" ${meowConfig.theme=='dark'?'selected':''}>Tmavý</option>
                                        <option value="light" ${meowConfig.theme=='light'?'selected':''}>Světlý</option>
                                    </select>
                                </div>
                                <div class="settings-row">
                                    <div class="settings-label">Velikost písma</div>
                                    <select class="settings-select" id="font-size" onchange="changeFontSize(this.value)">
                                        <option value="12px" ${meowConfig.font_size=='12px'?'selected':''}>Malá</option>
                                        <option value="14px" ${meowConfig.font_size=='14px'?'selected':''}>Střední</option>
                                        <option value="16px" ${meowConfig.font_size=='16px'?'selected':''}>Velká</option>
                                    </select>
                                </div>
                            </div>
                            <div id="settings-okna" class="settings-panel">
                                <div class="settings-row">
                                    <div class="settings-label">Výchozí šířka oken (px)</div>
                                    <input type="number" class="settings-input" id="win-width" value="${meowConfig.default_window_width}" min="300" max="1200">
                                </div>
                                <div class="settings-row">
                                    <div class="settings-label">Výchozí výška oken (px)</div>
                                    <input type="number" class="settings-input" id="win-height" value="${meowConfig.default_window_height}" min="200" max="900">
                                </div>
                                <button class="settings-btn" onclick="saveWindowSize()">Uložit velikost</button>
                            </div>
                            <div id="settings-system" class="settings-panel">
                                <div class="settings-row"><span class="settings-label">Hostname</span> ${info.hostname}</div>
                                <div class="settings-row"><span class="settings-label">OS</span> ${info.os}</div>
                                <div class="settings-row"><span class="settings-label">CPU</span> ${info.cpu}%</div>
                                <div class="settings-row"><span class="settings-label">RAM</span> ${info.ram}%</div>
                                <div class="settings-row"><span class="settings-label">Teplota</span> ${info.temp}°C</div>
                                <div class="settings-row"><span class="settings-label">Běží</span> ${uptime}</div>
                                <div class="settings-row"><span class="settings-label">Disky</span> ${info.disks.map(d => `<div>${d.name}: ${(d.used/1e9).toFixed(1)}/${(d.total/1e9).toFixed(1)} GB</div>`).join('')}</div>
                            </div>
                            <div id="settings-uzivatele" class="settings-panel">
                                <div class="settings-row">
                                    <div class="settings-label">Uživatelské jméno</div>
                                    <input type="text" class="settings-input" id="username-input" value="${meowConfig.username}">
                                </div>
                                <div class="settings-row">
                                    <div class="settings-label">Avatar</div>
                                    <select class="settings-select" id="avatar-select">
                                        <option value="user-astronaut" ${meowConfig.avatar=='user-astronaut'?'selected':''}>Astronaut</option>
                                        <option value="user-ninja" ${meowConfig.avatar=='user-ninja'?'selected':''}>Ninja</option>
                                        <option value="user-secret" ${meowConfig.avatar=='user-secret'?'selected':''}>Tajný</option>
                                    </select>
                                </div>
                                <button class="settings-btn" onclick="saveUserSettings()">Uložit</button>
                            </div>
                            <div id="settings-sit" class="settings-panel">
                                <div class="settings-row">
                                    <label><input type="checkbox" id="wifi-checkbox" ${meowConfig.wifi_enabled?'checked':''} onchange="toggleWifi(this.checked)"> Povolit Wi-Fi</label>
                                </div>
                                <div class="settings-row">IP: ${info.ips.join('<br>')}</div>
                            </div>
                            <div id="settings-zvuk" class="settings-panel">
                                <div class="settings-row">
                                    <div class="settings-label">Hlasitost (${meowConfig.volume}%)</div>
                                    <input type="range" min="0" max="100" value="${meowConfig.volume}" class="slider" id="volume-slider" oninput="changeVolume(this.value)">
                                </div>
                            </div>
                            <div id="settings-napajeni" class="settings-panel">
                                <button class="settings-btn" onclick="powerAction('restart')">Restartovat</button>
                                <button class="settings-btn" onclick="powerAction('shutdown')">Vypnout</button>
                            </div>
                            <div id="settings-o-aplikaci" class="settings-panel">
                                <div style="text-align:center;">
                                    <i class="fa-brands fa-linux" style="font-size:64px;"></i>
                                    <h3>MeowOS Arch 3.0</h3>
                                    <p>Pro RPi Zero 2W</p>
                                </div>
                            </div>
                        </div>
                    `;
                    createWindow('Nastavení', content, 750, 550, 150, 80);
                });
        }

        window.showSettingsTab = function(tab) {
            document.querySelectorAll('.settings-tab').forEach(t => t.classList.remove('active'));
            document.querySelectorAll('.settings-panel').forEach(p => p.classList.remove('active'));
            event.target.classList.add('active');
            document.getElementById('settings-' + tab).classList.add('active');
        };

        window.changeWallpaper = function(value) {
            document.body.style.setProperty('--wallpaper', value);
            fetch('/api/set-wallpaper', { method: 'POST', body: 'wallpaper=' + encodeURIComponent(value), headers: {'Content-Type': 'application/x-www-form-urlencoded'} });
        };

        window.setWallpaperFromUrl = function() {
            const url = document.getElementById('wallpaper-url').value;
            if (url) changeWallpaper("url('" + url + "')");
        };

        window.changePrimaryColor = function(value) {
            document.body.style.setProperty('--primary', value);
            fetch('/api/set-primary', { method: 'POST', body: 'color=' + value, headers: {'Content-Type': 'application/x-www-form-urlencoded'} });
        };

        window.changeWidgetBgColor = function(value) {
            document.body.style.setProperty('--widget-bg', value);
            fetch('/api/set-widget-bg', { method: 'POST', body: 'color=' + value, headers: {'Content-Type': 'application/x-www-form-urlencoded'} });
        };

        window.changeWidgetOpacity = function(value) {
            document.body.style.setProperty('--widget-opacity', value);
            fetch('/api/set-widget-opacity', { method: 'POST', body: 'opacity=' + value, headers: {'Content-Type': 'application/x-www-form-urlencoded'} });
        };

        window.changeTheme = function(value) {
            const root = document.documentElement;
            root.style.setProperty('--theme', value);
            root.style.setProperty('--text-color', value === 'dark' ? 'white' : 'black');
            fetch('/api/set-theme', { method: 'POST', body: 'theme=' + value, headers: {'Content-Type': 'application/x-www-form-urlencoded'} });
        };

        window.changeFontSize = function(value) {
            document.body.style.setProperty('--font-size', value);
            fetch('/api/set-fontsize', { method: 'POST', body: 'size=' + value, headers: {'Content-Type': 'application/x-www-form-urlencoded'} });
        };

        window.saveUserSettings = function() {
            const newName = document.getElementById('username-input').value;
            const newAvatar = document.getElementById('avatar-select').value;
            document.getElementById('start-username').innerText = newName;
            document.getElementById('start-username').previousElementSibling.className = `fa-solid fa-${newAvatar}`;
            fetch('/api/set-username', { method: 'POST', body: 'username=' + encodeURIComponent(newName), headers: {'Content-Type': 'application/x-www-form-urlencoded'} });
            fetch('/api/set-avatar', { method: 'POST', body: 'avatar=' + newAvatar, headers: {'Content-Type': 'application/x-www-form-urlencoded'} });
        };

        window.saveWindowSize = function() {
            const w = document.getElementById('win-width').value;
            const h = document.getElementById('win-height').value;
            document.documentElement.style.setProperty('--default-win-width', w + 'px');
            document.documentElement.style.setProperty('--default-win-height', h + 'px');
            fetch('/api/set-window-size', { method: 'POST', body: `width=${w}&height=${h}`, headers: {'Content-Type': 'application/x-www-form-urlencoded'} });
        };

        window.toggleWifi = function(enabled) {
            fetch('/api/set-wifi', { method: 'POST', body: 'enabled=' + enabled, headers: {'Content-Type': 'application/x-www-form-urlencoded'} });
        };

        window.changeVolume = function(value) {
            fetch('/api/set-volume', { method: 'POST', body: 'volume=' + value, headers: {'Content-Type': 'application/x-www-form-urlencoded'} });
        };

        window.powerAction = function(action) {
            if (action === 'restart' && confirm('Opravdu restartovat?')) fetch('/api/restart');
            else if (action === 'shutdown' && confirm('Opravdu vypnout?')) fetch('/api/shutdown');
        };

        // ========================= START MENU =========================
        function toggleStartMenu() {
            const menu = document.getElementById('start-menu');
            startMenuVisible = !startMenuVisible;
            menu.classList.toggle('visible', startMenuVisible);
        }

        document.addEventListener('click', function(e) {
            const menu = document.getElementById('start-menu');
            const startBtn = document.querySelector('.taskbar-icon:first-child');
            if (startMenuVisible && !menu.contains(e.target) && !startBtn.contains(e.target)) {
                menu.classList.remove('visible');
                startMenuVisible = false;
            }
        });

        // ========================= INICIALIZACE =========================
        window.onload = function() {
            openFileManager();
            openThisPC();
        };
    </script>
</body>
</html>
"""

# ============================================================================
# FLASK ROUTY
# ============================================================================

@app.route('/')
def index():
    config = load_config()
    return render_template_string(HTML_TEMPLATE, **config)

@app.route('/api/disks')
def api_disks():
    return jsonify(get_disks())

@app.route('/api/wifi')
def api_wifi():
    return get_wifi_status()

@app.route('/api/system-info')
def api_system_info():
    return jsonify(get_system_info())

@app.route('/api/cmd', methods=['POST'])
def api_cmd():
    cmd = request.form.get('cmd', '')
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        output = result.stdout + result.stderr
    except Exception as e:
        output = str(e)
    return output

@app.route('/api/set-username', methods=['POST'])
def api_set_username():
    config = load_config()
    config['username'] = request.form.get('username', 'Jakub')
    save_config(config)
    return 'OK'

@app.route('/api/set-avatar', methods=['POST'])
def api_set_avatar():
    config = load_config()
    config['avatar'] = request.form.get('avatar', 'user-astronaut')
    save_config(config)
    return 'OK'

@app.route('/api/set-wallpaper', methods=['POST'])
def api_set_wallpaper():
    config = load_config()
    config['wallpaper'] = request.form.get('wallpaper', config['wallpaper'])
    save_config(config)
    return 'OK'

@app.route('/api/set-primary', methods=['POST'])
def api_set_primary():
    config = load_config()
    config['primary_color'] = request.form.get('color', '#4facfe')
    save_config(config)
    return 'OK'

@app.route('/api/set-widget-bg', methods=['POST'])
def api_set_widget_bg():
    config = load_config()
    config['widget_bg_color'] = request.form.get('color', '#0f192a')
    save_config(config)
    return 'OK'

@app.route('/api/set-widget-opacity', methods=['POST'])
def api_set_widget_opacity():
    config = load_config()
    config['widget_opacity'] = float(request.form.get('opacity', 0.8))
    save_config(config)
    return 'OK'

@app.route('/api/set-theme', methods=['POST'])
def api_set_theme():
    config = load_config()
    config['theme'] = request.form.get('theme', 'dark')
    save_config(config)
    return 'OK'

@app.route('/api/set-fontsize', methods=['POST'])
def api_set_fontsize():
    config = load_config()
    config['font_size'] = request.form.get('size', '14px')
    save_config(config)
    return 'OK'

@app.route('/api/set-window-size', methods=['POST'])
def api_set_window_size():
    config = load_config()
    config['default_window_width'] = int(request.form.get('width', 600))
    config['default_window_height'] = int(request.form.get('height', 400))
    save_config(config)
    return 'OK'

@app.route('/api/set-wifi', methods=['POST'])
def api_set_wifi():
    config = load_config()
    config['wifi_enabled'] = request.form.get('enabled') == 'true'
    save_config(config)
    return 'OK'

@app.route('/api/set-volume', methods=['POST'])
def api_set_volume():
    config = load_config()
    config['volume'] = int(request.form.get('volume', 80))
    save_config(config)
    return 'OK'

@app.route('/api/restart')
def api_restart():
    subprocess.Popen(['sudo', 'reboot'])
    return 'Restarting...'

@app.route('/api/shutdown')
def api_shutdown():
    subprocess.Popen(['sudo', 'poweroff'])
    return 'Shutting down...'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
EOF

echo "✅ Aplikace vytvořena."
echo "🚀 Spouštím server..."
echo "Připoj se na http://$(hostname -I | awk '{print $1}'):5000"
cd ~/meowos-arch
python3 app.py
EOF
