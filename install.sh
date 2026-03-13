#!/bin/bash
# MeowOS Web Desktop – Arch Linux edice
# Autor: Jakub (s asistencí AI)

set -e

echo "🔧 Aktualizuji systém a instaluji potřebné balíčky..."
sudo apt update
sudo apt install -y python3-flask python3-psutil wireless-tools

echo "📁 Vytvářím složku pro aplikaci..."
mkdir -p ~/meowos-arch
cd ~/meowos-arch

echo "🐧 Vytvářím hlavní soubor app.py..."
cat > app.py << 'EOF'
#!/usr/bin/env python3
"""
MeowOS Arch – desktopová simulace ve stylu Arch Linuxu
Autor: Jakub
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
# Pomocné funkce
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

        body {
            width: 100vw;
            height: 100vh;
            overflow: hidden;
            background: var(--wallpaper, linear-gradient(145deg, #0f172a 0%, #1e293b 100%));
            background-size: cover;
            background-position: center;
            position: relative;
            transition: background 0.3s;
        }

        #desktop {
            width: 100%;
            height: 100%;
            padding-bottom: 48px;
            position: relative;
            overflow: hidden;
        }

        /* ========================= OKNA ========================= */
        .window {
            position: absolute;
            min-width: 400px;
            min-height: 300px;
            background: rgba(15, 25, 45, 0.7);
            backdrop-filter: blur(15px);
            -webkit-backdrop-filter: blur(15px);
            border: 1px solid rgba(255,255,255,0.1);
            border-radius: 12px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.6);
            display: flex;
            flex-direction: column;
            z-index: 10;
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
        .window-header {
            background: rgba(20, 30, 50, 0.8);
            padding: 8px 12px;
            border-radius: 12px 12px 0 0;
            display: flex;
            justify-content: space-between;
            align-items: center;
            cursor: grab;
            user-select: none;
            border-bottom: 1px solid rgba(255,255,255,0.1);
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
        .window-content {
            flex: 1;
            padding: 16px;
            color: white;
            overflow-y: auto;
        }

        /* ========================= TASKBAR ========================= */
        #taskbar {
            position: fixed;
            bottom: 0;
            left: 0;
            width: 100%;
            height: 48px;
            background: rgba(10, 15, 25, 0.7);
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

        /* ========================= START MENU ========================= */
        #start-menu {
            position: fixed;
            bottom: 60px;
            left: 50%;
            transform: translateX(-50%);
            width: 480px;
            background: rgba(15, 20, 30, 0.8);
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

        /* ========================= IKONY SOUBORŮ ========================= */
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
        }
        .file-icon i {
            font-size: 40px;
            filter: drop-shadow(0 10px 8px rgba(0,0,0,0.3));
        }

        /* ========================= TERMINÁL ========================= */
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
            line-height: 1.4;
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

        /* ========================= KALKULAČKA ========================= */
        .calculator {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 8px;
            padding: 10px;
            background: rgba(0,0,0,0.2);
            border-radius: 8px;
        }
        .calc-display {
            grid-column: span 4;
            background: rgba(0,0,0,0.5);
            color: white;
            text-align: right;
            padding: 15px;
            font-size: 24px;
            border-radius: 8px;
            margin-bottom: 10px;
            font-family: monospace;
        }
        .calc-btn {
            background: rgba(255,255,255,0.1);
            border: none;
            color: white;
            padding: 15px;
            font-size: 18px;
            border-radius: 8px;
            cursor: pointer;
            transition: 0.2s;
        }
        .calc-btn:hover {
            background: rgba(255,255,255,0.2);
        }
        .calc-btn.operator {
            background: rgba(100, 150, 255, 0.3);
        }

        /* ========================= TAPETY ========================= */
        #wallpaper-picker {
            position: fixed;
            top: 60px;
            right: 20px;
            background: rgba(0,0,0,0.7);
            backdrop-filter: blur(10px);
            border-radius: 10px;
            padding: 10px;
            display: none;
            z-index: 2000;
        }
        #wallpaper-picker.visible {
            display: block;
        }
        .wallpaper-option {
            width: 80px;
            height: 50px;
            margin: 5px;
            border-radius: 5px;
            cursor: pointer;
            border: 2px solid transparent;
        }
        .wallpaper-option:hover {
            border-color: white;
        }
    </style>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
</head>
<body>
    <div id="desktop"></div>

    <div id="taskbar">
        <div class="taskbar-center">
            <div class="taskbar-icon" onclick="toggleStartMenu()"><i class="fa-brands fa-linux"></i></div>
            <div class="taskbar-icon" onclick="openApp('search')"><i class="fa-solid fa-magnifying-glass"></i></div>
            <div class="taskbar-icon" onclick="openApp('edge')"><i class="fa-brands fa-edge"></i></div>
            <div class="taskbar-icon" onclick="openFileManager()"><i class="fa-regular fa-folder-open"></i></div>
            <div class="taskbar-icon" onclick="openApp('firefox')"><i class="fa-brands fa-firefox-browser"></i></div>
        </div>
        <div class="taskbar-right">
            <div class="taskbar-icon" onclick="toggleWallpaperPicker()"><i class="fa-solid fa-image"></i></div>
            <div><i class="fa-solid fa-wifi"></i> <span id="wifi-status">Načítám...</span></div>
            <div><i class="fa-solid fa-battery-full"></i> <span>100%</span></div>
            <div class="taskbar-time" id="taskbar-time"></div>
        </div>
    </div>

    <div id="start-menu">
        <div class="start-header">
            <i class="fa-brands fa-linux"></i> Arch Linux
        </div>
        <div class="start-apps">
            <div class="start-app" onclick="openApp('settings')"><i class="fa-solid fa-gear"></i><span>Nastavení</span></div>
            <div class="start-app" onclick="openFileManager()"><i class="fa-regular fa-folder"></i><span>Explorer</span></div>
            <div class="start-app" onclick="openTerminal()"><i class="fa-solid fa-terminal"></i><span>Terminál</span></div>
            <div class="start-app" onclick="openCalculator()"><i class="fa-solid fa-calculator"></i><span>Kalkulačka</span></div>
            <div class="start-app" onclick="openThisPC()"><i class="fa-solid fa-computer"></i><span>Tento PC</span></div>
            <div class="start-app" onclick="openApp('edge')"><i class="fa-brands fa-edge"></i><span>Edge</span></div>
            <div class="start-app" onclick="openApp('firefox')"><i class="fa-brands fa-firefox-browser"></i><span>Firefox</span></div>
            <div class="start-app" onclick="openApp('store')"><i class="fa-solid fa-store"></i><span>Store</span></div>
        </div>
    </div>

    <div id="wallpaper-picker">
        <div class="wallpaper-option" style="background: linear-gradient(145deg, #0f172a, #1e293b);" onclick="changeWallpaper('linear-gradient(145deg, #0f172a, #1e293b)')"></div>
        <div class="wallpaper-option" style="background: linear-gradient(145deg, #2d1a3a, #1a2f3f);" onclick="changeWallpaper('linear-gradient(145deg, #2d1a3a, #1a2f3f)')"></div>
        <div class="wallpaper-option" style="background: linear-gradient(145deg, #1a3a2d, #1a2f3f);" onclick="changeWallpaper('linear-gradient(145deg, #1a3a2d, #1a2f3f)')"></div>
        <div class="wallpaper-option" style="background: url('https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=200') center/cover;" onclick="changeWallpaper('url(https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800)')"></div>
        <div class="wallpaper-option" style="background: url('https://images.unsplash.com/photo-1510798831971-661eb04b3739?w=200') center/cover;" onclick="changeWallpaper('url(https://images.unsplash.com/photo-1510798831971-661eb04b3739?w=800)')"></div>
    </div>

    <script>
        // ========================= GLOBÁLNÍ PROMĚNNÉ =========================
        let windows = [];
        let zIndexCounter = 100;
        let draggedWindow = null;
        let dragOffsetX, dragOffsetY;
        let startMenuVisible = false;
        let wallpaperPickerVisible = false;
        let terminalHistory = [];
        let historyIndex = -1;

        // ========================= POMOCNÉ FUNKCE =========================
        function updateClock() {
            const now = new Date();
            const timeStr = now.toLocaleTimeString('cs-CZ', { hour: '2-digit', minute: '2-digit' });
            document.getElementById('taskbar-time').innerText = timeStr;
        }
        setInterval(updateClock, 1000);
        updateClock();

        function updateWifi() {
            fetch('/api/wifi').then(r => r.text()).then(s => document.getElementById('wifi-status').innerText = s);
        }
        setInterval(updateWifi, 5000);
        updateWifi();

        // ========================= SPRÁVA OKEN =========================
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

            windows.push({ id, element: winDiv, title, minimized: false, maximized: false });
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
            const win = document.getElementById(id);
            if (win) win.classList.add('minimized');
        }

        function maximizeWindow(id) {
            const win = document.getElementById(id);
            if (!win) return;
            if (win.classList.contains('maximized')) {
                win.classList.remove('maximized');
            } else {
                win.classList.add('maximized');
                win.classList.remove('minimized');
            }
        }

        function closeWindow(id) {
            const win = document.getElementById(id);
            if (win) win.remove();
            windows = windows.filter(w => w.id !== id);
        }

        // ========================= APLIKACE =========================
        function openFileManager() {
            const content = `
                <div style="display: flex; gap: 20px;">
                    <div style="width: 200px; background: rgba(0,0,0,0.2); border-radius: 10px; padding: 10px;">
                        <div class="fm-sidebar-item"><i class="fa-regular fa-house"></i> Home</div>
                        <div class="fm-sidebar-item"><i class="fa-regular fa-image"></i> Obrázky</div>
                        <div class="fm-sidebar-item"><i class="fa-regular fa-file"></i> Dokumenty</div>
                        <div class="fm-sidebar-item"><i class="fa-regular fa-music"></i> Hudba</div>
                        <div class="fm-sidebar-item"><i class="fa-regular fa-video"></i> Videa</div>
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
            `;
            createWindow('Správce souborů', content, 700, 450, 150, 100);
        }

        function openThisPC() {
            fetch('/api/disks')
                .then(r => r.json())
                .then(disks => {
                    let html = '<div style="display: flex; flex-direction: column; gap: 15px;">';
                    disks.forEach(disk => {
                        const totalGB = (disk.total / 1e9).toFixed(1);
                        const usedGB = (disk.used / 1e9).toFixed(1);
                        html += `
                            <div>
                                <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
                                    <span><i class="fa-regular fa-hard-drive"></i> ${disk.name}</span>
                                    <span>${usedGB} GB / ${totalGB} GB</span>
                                </div>
                                <div style="width:100%; height:10px; background: rgba(255,255,255,0.2); border-radius:5px;">
                                    <div style="width:${disk.percent}%; height:100%; background: linear-gradient(90deg, #4facfe, #00f2fe); border-radius:5px;"></div>
                                </div>
                            </div>
                        `;
                    });
                    html += '</div>';
                    createWindow('Tento počítač', html, 500, 350, 200, 150);
                });
        }

        function openTerminal() {
            const content = `
                <div class="terminal-container" id="term-${Date.now()}">
                    <div class="terminal-output" id="term-output">Vítejte v terminálu MeowOS Arch\\n</div>
                    <div class="terminal-input-line">
                        <span class="terminal-prompt">$</span>
                        <input type="text" class="terminal-input" id="term-input" autofocus>
                    </div>
                </div>
            `;
            const winId = createWindow('Terminál', content, 650, 400, 250, 200);
            setTimeout(() => {
                const input = document.getElementById('term-input');
                const output = document.getElementById('term-output');
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
            const content = `
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
            `;
            createWindow('Kalkulačka', content, 300, 400, 300, 150);
        }

        // Globální funkce pro kalkulačku
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

        function openApp(appName) {
            if (appName === 'search') {
                createWindow('Hledání', '<div style="padding:20px;">Zadejte hledaný výraz...</div>', 400, 200, 200, 150);
            } else if (appName === 'edge') {
                window.open('https://www.microsoft.com/edge', '_blank');
            } else if (appName === 'firefox') {
                window.open('https://www.mozilla.org/firefox', '_blank');
            } else if (appName === 'settings') {
                createWindow('Nastavení', '<div style="padding:20px;">Nastavení systému (zatím není implementováno)</div>', 500, 400, 200, 150);
            } else if (appName === 'store') {
                createWindow('Obchod', '<div style="padding:20px;">Obchod s aplikacemi (demo)</div>', 500, 400, 200, 150);
            }
        }

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

        // ========================= TAPETY =========================
        function toggleWallpaperPicker() {
            const picker = document.getElementById('wallpaper-picker');
            wallpaperPickerVisible = !wallpaperPickerVisible;
            picker.classList.toggle('visible', wallpaperPickerVisible);
        }

        window.changeWallpaper = function(value) {
            document.body.style.setProperty('--wallpaper', value);
            toggleWallpaperPicker();
        };

        // ========================= INICIALIZACE =========================
        window.onload = function() {
            openFileManager();
            openThisPC();
        };
    </script>
</body>
</html>
"""

# ========================= ROUTY =========================
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

echo "✅ Aplikace vytvořena."
echo "🚀 Spouštím server..."
echo "Připoj se na http://$(hostname -I | awk '{print $1}'):5000"
cd ~/meowos-arch
python3 app.py
EOF
