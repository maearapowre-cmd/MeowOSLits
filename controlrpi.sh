#!/bin/bash
# MeowOS – verze bez xterm.js, terminál přes textarea
# Autor: Jakub (s asistencí AI)

set -e

echo "🔧 Aktualizuji systém a instaluji potřebné balíčky..."
sudo apt update
sudo apt install -y python3-flask python3-psutil wireless-tools gcc golang-go

echo "📁 Vytvářím složku pro aplikaci..."
mkdir -p ~/meowos
cd ~/meowos

echo "🐧 Vytvářím hlavní soubor app.py (1500 řádků)..."

cat > app.py << 'EOF'
#!/usr/bin/env python3
"""
MeowOS – verze bez xterm.js, terminál přes textarea
"""

import os
import psutil
import subprocess
import json
import time
import tempfile
from datetime import datetime
from flask import Flask, render_template_string, jsonify, request, send_from_directory

app = Flask(__name__)

# ============================================================================
# Konfigurace
# ============================================================================
CONFIG_FILE = os.path.expanduser('~/meowos/config.json')

DEFAULT_CONFIG = {
    'username': 'jakub',
    'wallpaper': 'linear-gradient(145deg, #0f172a, #1e1b2b)',
    'primary_color': '#c084fc',
    'widget_bg_color': '#0a0a0f',
    'widget_opacity': 0.8,
    'blur_intensity': 20,
    'theme': 'dark',
    'font_size': '13px',
    'avatar': 'user-astronaut',
    'wifi_enabled': True,
    'volume': 80,
    'default_window_width': 640,
    'default_window_height': 440,
    'taskbar_position': 'bottom',
    'profiles': {
        'Výchozí': {
            'wallpaper': 'linear-gradient(145deg, #0f172a, #1e1b2b)',
            'primary_color': '#c084fc',
            'widget_bg_color': '#0a0a0f',
            'widget_opacity': 0.8,
            'blur_intensity': 20,
            'theme': 'dark',
            'font_size': '13px'
        }
    },
    'active_profile': 'Výchozí'
}

def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, 'r') as f:
                config = json.load(f)
                for k, v in DEFAULT_CONFIG.items():
                    if k not in config:
                        config[k] = v
                if 'profiles' not in config:
                    config['profiles'] = {}
                if 'Výchozí' not in config['profiles']:
                    config['profiles']['Výchozí'] = DEFAULT_CONFIG.copy()
                    for key in ['username', 'avatar', 'wifi_enabled', 'volume', 
                                'default_window_width', 'default_window_height', 
                                'taskbar_position', 'profiles', 'active_profile']:
                        if key in config['profiles']['Výchozí']:
                            del config['profiles']['Výchozí'][key]
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
# Spouštění kódu
# ============================================================================
def run_code(code, lang):
    timeout = 5
    with tempfile.TemporaryDirectory() as tmpdir:
        if lang == 'python':
            file_path = os.path.join(tmpdir, 'script.py')
            with open(file_path, 'w') as f:
                f.write(code)
            try:
                result = subprocess.run(['python3', file_path], capture_output=True, text=True, timeout=timeout)
                return result.stdout + result.stderr
            except subprocess.TimeoutExpired:
                return f"Chyba: běh trval déle než {timeout} sekund."
        elif lang == 'c':
            file_path = os.path.join(tmpdir, 'program.c')
            with open(file_path, 'w') as f:
                f.write(code)
            try:
                compile_result = subprocess.run(['gcc', file_path, '-o', os.path.join(tmpdir, 'program')], capture_output=True, text=True, timeout=timeout)
                if compile_result.returncode != 0:
                    return compile_result.stderr
                run_result = subprocess.run([os.path.join(tmpdir, 'program')], capture_output=True, text=True, timeout=timeout)
                return run_result.stdout + run_result.stderr
            except subprocess.TimeoutExpired:
                return f"Chyba: běh trval déle než {timeout} sekund."
        elif lang == 'go':
            file_path = os.path.join(tmpdir, 'program.go')
            with open(file_path, 'w') as f:
                f.write(code)
            try:
                result = subprocess.run(['go', 'run', file_path], capture_output=True, text=True, timeout=timeout)
                return result.stdout + result.stderr
            except subprocess.TimeoutExpired:
                return f"Chyba: běh trval déle než {timeout} sekund."
        elif lang == 'bash':
            file_path = os.path.join(tmpdir, 'script.sh')
            with open(file_path, 'w') as f:
                f.write(code)
            try:
                result = subprocess.run(['bash', file_path], capture_output=True, text=True, timeout=timeout)
                return result.stdout + result.stderr
            except subprocess.TimeoutExpired:
                return f"Chyba: běh trval déle než {timeout} sekund."
        else:
            return "Nepodporovaný jazyk."

# ============================================================================
# API routy
# ============================================================================
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

@app.route('/api/run', methods=['POST'])
def api_run():
    data = request.get_json()
    code = data.get('code', '')
    lang = data.get('lang', 'python')
    output = run_code(code, lang)
    return output

@app.route('/api/set-username', methods=['POST'])
def api_set_username():
    config = load_config()
    config['username'] = request.form.get('username', 'jakub')
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
    config['primary_color'] = request.form.get('color', '#c084fc')
    save_config(config)
    return 'OK'

@app.route('/api/set-widget-bg', methods=['POST'])
def api_set_widget_bg():
    config = load_config()
    config['widget_bg_color'] = request.form.get('color', '#0a0a0f')
    save_config(config)
    return 'OK'

@app.route('/api/set-widget-opacity', methods=['POST'])
def api_set_widget_opacity():
    config = load_config()
    config['widget_opacity'] = float(request.form.get('opacity', 0.8))
    save_config(config)
    return 'OK'

@app.route('/api/set-blur', methods=['POST'])
def api_set_blur():
    config = load_config()
    config['blur_intensity'] = int(request.form.get('blur', 20))
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
    config['font_size'] = request.form.get('size', '13px')
    save_config(config)
    return 'OK'

@app.route('/api/set-window-size', methods=['POST'])
def api_set_window_size():
    config = load_config()
    config['default_window_width'] = int(request.form.get('width', 640))
    config['default_window_height'] = int(request.form.get('height', 440))
    save_config(config)
    return 'OK'

@app.route('/api/set-taskbar-pos', methods=['POST'])
def api_set_taskbar_pos():
    config = load_config()
    config['taskbar_position'] = request.form.get('pos', 'bottom')
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

@app.route('/api/save-profile', methods=['POST'])
def api_save_profile():
    config = load_config()
    name = request.form.get('name', 'Nový profil')
    profile = {
        'wallpaper': config['wallpaper'],
        'primary_color': config['primary_color'],
        'widget_bg_color': config['widget_bg_color'],
        'widget_opacity': config['widget_opacity'],
        'blur_intensity': config['blur_intensity'],
        'theme': config['theme'],
        'font_size': config['font_size']
    }
    config['profiles'][name] = profile
    save_config(config)
    return 'OK'

@app.route('/api/load-profile', methods=['POST'])
def api_load_profile():
    config = load_config()
    name = request.form.get('name', 'Výchozí')
    if name in config['profiles']:
        profile = config['profiles'][name]
        config.update(profile)
        config['active_profile'] = name
        save_config(config)
    return 'OK'

@app.route('/api/delete-profile', methods=['POST'])
def api_delete_profile():
    config = load_config()
    name = request.form.get('name', '')
    if name in config['profiles'] and name != 'Výchozí':
        del config['profiles'][name]
        if config['active_profile'] == name:
            config['active_profile'] = 'Výchozí'
            config.update(config['profiles']['Výchozí'])
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

# ============================================================================
# Hlavní stránka
# ============================================================================
@app.route('/')
def index():
    config = load_config()
    return render_template_string(HTML_TEMPLATE, **config)

# ============================================================================
# HTML šablona (bez xterm.js)
# ============================================================================
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="cs">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MeowOS</title>
    <!-- CodeMirror -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.5/codemirror.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.5/theme/dracula.min.css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.5/codemirror.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.5/mode/python/python.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.5/mode/clike/clike.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.5/mode/go/go.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.5/mode/shell/shell.min.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: 'Segoe UI', 'Roboto', 'Inter', system-ui, sans-serif;
        }

        :root {
            --wallpaper: {{ wallpaper }};
            --primary: {{ primary_color }};
            --widget-bg: {{ widget_bg_color }};
            --widget-opacity: {{ widget_opacity }};
            --blur-intensity: {{ blur_intensity }}px;
            --theme: {{ theme }};
            --text-color: {% if theme == 'dark' %}rgba(255,255,255,0.9){% else %}rgba(0,0,0,0.9){% endif %};
            --font-size: {{ font_size }};
            --default-win-width: {{ default_window_width }}px;
            --default-win-height: {{ default_window_height }}px;
            --border-radius: 12px;
            --border-size: 1px;
            --taskbar-pos: {{ taskbar_position }};
        }

        body {
            width: 100vw;
            height: 100vh;
            overflow: hidden;
            background: var(--wallpaper);
            background-size: cover;
            background-position: center;
            position: relative;
            color: var(--text-color);
            font-size: var(--font-size);
        }

        ::-webkit-scrollbar {
            width: 8px;
            height: 8px;
        }
        ::-webkit-scrollbar-track {
            background: rgba(0,0,0,0.2);
            border-radius: 10px;
        }
        ::-webkit-scrollbar-thumb {
            background: rgba(255,255,255,0.2);
            border-radius: 10px;
        }
        ::-webkit-scrollbar-thumb:hover {
            background: rgba(255,255,255,0.3);
        }

        #desktop {
            width: 100%;
            height: 100%;
            padding-bottom: {% if taskbar_position == 'bottom' %}48px{% else %}0{% endif %};
            padding-top: {% if taskbar_position == 'top' %}48px{% else %}0{% endif %};
            position: relative;
            overflow: hidden;
        }

        .window {
            position: absolute;
            min-width: 300px;
            min-height: 200px;
            width: var(--default-win-width);
            height: var(--default-win-height);
            background: rgba(var(--widget-bg-rgb), calc(var(--widget-opacity) * 100%));
            backdrop-filter: blur(var(--blur-intensity));
            -webkit-backdrop-filter: blur(var(--blur-intensity));
            border: var(--border-size) solid rgba(255,255,255,0.1);
            border-radius: var(--border-radius);
            box-shadow: 0 15px 35px rgba(0,0,0,0.6);
            display: flex;
            flex-direction: column;
            z-index: 10;
            color: var(--text-color);
            transition: box-shadow 0.2s ease;
            will-change: transform, opacity, left, top, width, height;
        }
        .window:active {
            box-shadow: 0 20px 45px rgba(0,0,0,0.8);
        }
        .window.maximized {
            width: 100% !important;
            height: calc(100% - 48px) !important;
            top: {% if taskbar_position == 'top' %}48px{% else %}0{% endif %} !important;
            left: 0 !important;
            border-radius: 0;
            resize: none;
        }
        .window.minimized {
            display: none !important;
        }
        .window-header {
            background: rgba(var(--widget-bg-rgb), 0.95);
            padding: 8px 12px;
            border-radius: var(--border-radius) var(--border-radius) 0 0;
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
            color: var(--primary);
            font-size: 13px;
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
            width: 26px;
            height: 26px;
            border: none;
            border-radius: 6px;
            background: rgba(255,255,255,0.05);
            color: var(--text-color);
            font-size: 13px;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            transition: transform 0.15s ease, background-color 0.15s ease;
        }
        .window-btn:hover {
            transform: scale(1.15);
            background: rgba(255,255,255,0.2);
        }
        .close-btn:hover {
            background: #c42b1c !important;
        }
        .window-content {
            flex: 1;
            padding: 16px;
            overflow-y: auto;
            display: flex;
            flex-direction: column;
        }

        #taskbar {
            position: fixed;
            {% if taskbar_position == 'bottom' %}
            bottom: 0;
            top: auto;
            {% else %}
            top: 0;
            bottom: auto;
            {% endif %}
            left: 0;
            width: 100%;
            height: 48px;
            background: rgba(var(--widget-bg-rgb), calc(var(--widget-opacity) * 100%));
            backdrop-filter: blur(var(--blur-intensity));
            -webkit-backdrop-filter: blur(var(--blur-intensity));
            border-{% if taskbar_position == 'bottom' %}top{% else %}bottom{% endif %}: var(--border-size) solid rgba(255,255,255,0.1);
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
            border-radius: 20px;
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
            transition: 0.15s;
            cursor: pointer;
        }
        .taskbar-icon:hover {
            background: rgba(255,255,255,0.15);
            color: var(--primary);
        }
        .taskbar-right {
            position: absolute;
            right: 16px;
            display: flex;
            gap: 16px;
            color: white;
            font-size: 13px;
            align-items: center;
        }
        .taskbar-time {
            background: rgba(255,255,255,0.1);
            padding: 6px 12px;
            border-radius: 20px;
        }

        #start-menu {
            position: fixed;
            {% if taskbar_position == 'bottom' %}
            bottom: 60px;
            {% else %}
            top: 60px;
            {% endif %}
            left: 50%;
            transform: translateX(-50%);
            width: 540px;
            background: rgba(var(--widget-bg-rgb), calc(var(--widget-opacity) * 100%));
            backdrop-filter: blur(var(--blur-intensity));
            -webkit-backdrop-filter: blur(var(--blur-intensity));
            border-radius: 20px;
            border: var(--border-size) solid rgba(255,255,255,0.1);
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
            font-weight: 500;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 1px solid rgba(255,255,255,0.1);
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
            background: rgba(255,255,255,0.03);
            cursor: pointer;
            transition: 0.15s;
        }
        .start-app:hover {
            background: rgba(255,255,255,0.1);
            color: var(--primary);
        }
        .start-app i {
            font-size: 24px;
        }
        .start-app span {
            font-size: 11px;
            text-align: center;
        }

        #overview {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0,0,0,0.5);
            backdrop-filter: blur(15px);
            z-index: 2000;
            display: none;
            justify-content: center;
            align-items: center;
            flex-wrap: wrap;
            gap: 20px;
            padding: 40px;
        }
        #overview.visible {
            display: flex;
        }
        .overview-window {
            width: 200px;
            height: 150px;
            background: rgba(var(--widget-bg-rgb), 0.7);
            border-radius: 10px;
            border: 2px solid transparent;
            overflow: hidden;
            cursor: pointer;
            transition: 0.2s;
            display: flex;
            flex-direction: column;
            box-shadow: 0 10px 20px rgba(0,0,0,0.5);
        }
        .overview-window:hover {
            border-color: var(--primary);
            transform: scale(1.05);
        }
        .overview-header {
            background: rgba(var(--widget-bg-rgb), 0.9);
            padding: 5px 8px;
            font-size: 12px;
            display: flex;
            align-items: center;
            gap: 5px;
            border-bottom: 1px solid rgba(255,255,255,0.1);
        }
        .overview-content {
            flex: 1;
            background: rgba(0,0,0,0.2);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 24px;
            color: var(--primary);
        }

        .icon-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(80px, 1fr));
            gap: 12px;
            padding: 10px;
        }
        .file-icon {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 6px;
            padding: 10px 4px;
            border-radius: 10px;
            background: rgba(var(--widget-bg-rgb), 0.5);
            backdrop-filter: blur(calc(var(--blur-intensity)/2));
            border: var(--border-size) solid rgba(255,255,255,0.05);
            cursor: pointer;
            transition: 0.15s;
            text-align: center;
        }
        .file-icon:hover {
            background: rgba(255,255,255,0.1);
            border-color: var(--primary);
        }
        .file-icon i {
            font-size: 32px;
            filter: drop-shadow(0 6px 8px rgba(0,0,0,0.5));
        }

        .calculator {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 8px;
            padding: 12px;
            background: rgba(0,0,0,0.3);
            border-radius: 10px;
            height: 100%;
        }
        .calc-display {
            grid-column: span 4;
            background: rgba(0,0,0,0.5);
            color: white;
            text-align: right;
            padding: 15px;
            font-size: 28px;
            border-radius: 8px;
            margin-bottom: 10px;
            font-family: monospace;
        }
        .calc-btn {
            background: rgba(255,255,255,0.05);
            border: none;
            color: white;
            padding: 14px;
            font-size: 18px;
            border-radius: 8px;
            cursor: pointer;
            transition: 0.1s;
        }
        .calc-btn:hover {
            background: rgba(255,255,255,0.15);
        }
        .calc-btn.operator {
            background: color-mix(in srgb, var(--primary) 30%, transparent);
        }
        .calc-btn.operator:hover {
            background: color-mix(in srgb, var(--primary) 50%, transparent);
        }

        .code-editor-container {
            display: flex;
            flex-direction: column;
            height: 100%;
            gap: 10px;
        }
        .editor-toolbar {
            display: flex;
            gap: 10px;
            align-items: center;
            background: rgba(0,0,0,0.2);
            padding: 5px 10px;
            border-radius: 8px;
        }
        .editor-select {
            background: rgba(0,0,0,0.4);
            color: white;
            border: 1px solid rgba(255,255,255,0.2);
            border-radius: 6px;
            padding: 4px 8px;
        }
        .editor-run-btn {
            background: var(--primary);
            border: none;
            color: #0a0a0f;
            padding: 4px 12px;
            border-radius: 6px;
            cursor: pointer;
            font-weight: 500;
            display: flex;
            align-items: center;
            gap: 5px;
        }
        .editor-run-btn:hover {
            filter: brightness(1.1);
        }
        .CodeMirror {
            flex: 1;
            border-radius: 8px;
            background: rgba(0,0,0,0.3);
            color: white;
        }
        .cm-s-dracula .CodeMirror-gutters {
            background: rgba(0,0,0,0.5);
            border-right: 1px solid rgba(255,255,255,0.1);
        }

        .terminal-output {
            background: rgba(0,0,0,0.6);
            border-radius: 8px;
            padding: 10px;
            font-family: 'Courier New', monospace;
            font-size: 13px;
            color: #a5d6ff;
            height: 150px;
            overflow-y: auto;
            white-space: pre-wrap;
        }
        .terminal-input {
            width: 100%;
            padding: 8px;
            margin-top: 8px;
            background: rgba(0,0,0,0.4);
            border: 1px solid rgba(255,255,255,0.2);
            border-radius: 6px;
            color: white;
            font-family: 'Courier New', monospace;
            font-size: 13px;
        }

        .settings-tabs {
            display: flex;
            gap: 5px;
            margin-bottom: 20px;
            border-bottom: 1px solid rgba(255,255,255,0.1);
            padding-bottom: 10px;
            flex-wrap: wrap;
        }
        .settings-tab {
            padding: 8px 16px;
            border-radius: 20px;
            cursor: pointer;
            background: rgba(255,255,255,0.03);
            transition: 0.15s;
            border: var(--border-size) solid transparent;
        }
        .settings-tab:hover {
            background: rgba(255,255,255,0.08);
        }
        .settings-tab.active {
            background: var(--primary);
            color: #0a0a0f;
            font-weight: 500;
            border-color: rgba(255,255,255,0.2);
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
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .settings-input, .settings-select {
            width: 100%;
            padding: 8px;
            background: rgba(0,0,0,0.4);
            border: var(--border-size) solid rgba(255,255,255,0.1);
            border-radius: 6px;
            color: inherit;
        }
        .settings-btn {
            background: var(--primary);
            border: none;
            color: #0a0a0f;
            padding: 8px 16px;
            border-radius: 6px;
            cursor: pointer;
            margin-right: 10px;
            font-weight: 500;
        }
        .wallpaper-option {
            display: inline-block;
            width: 80px;
            height: 50px;
            margin: 5px;
            border-radius: 8px;
            cursor: pointer;
            border: 2px solid transparent;
            background-size: cover;
            background-position: center;
            transition: 0.1s;
        }
        .wallpaper-option:hover {
            border-color: var(--primary);
        }
        .color-preview {
            width: 30px;
            height: 30px;
            border-radius: 6px;
            display: inline-block;
            margin-right: 10px;
            vertical-align: middle;
            border: 1px solid rgba(255,255,255,0.2);
        }
        .slider {
            width: 100%;
            margin: 10px 0;
            accent-color: var(--primary);
        }
        .url-input {
            display: flex;
            gap: 10px;
            margin-top: 10px;
        }
        .url-input input {
            flex: 1;
        }
        .profiles-section {
            margin-top: 20px;
            padding-top: 15px;
            border-top: 1px solid rgba(255,255,255,0.1);
        }
        .profile-item {
            display: flex;
            align-items: center;
            justify-content: space-between;
            background: rgba(255,255,255,0.05);
            padding: 8px 12px;
            border-radius: 8px;
            margin-bottom: 8px;
        }
        .profile-name {
            font-weight: 500;
        }
        .profile-actions button {
            background: none;
            border: none;
            color: var(--text-color);
            margin-left: 8px;
            cursor: pointer;
            opacity: 0.7;
        }
        .profile-actions button:hover {
            opacity: 1;
            color: var(--primary);
        }
        .profile-active {
            border-left: 3px solid var(--primary);
        }
    </style>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
</head>
<body>
    <script>
        function hexToRgb(hex) {
            const result = /^#?([a-f\\d]{2})([a-f\\d]{2})([a-f\\d]{2})$/i.exec(hex);
            return result ? `${parseInt(result[1], 16)}, ${parseInt(result[2], 16)}, ${parseInt(result[3], 16)}` : '10, 20, 30';
        }

        window.meowConfig = {
            username: {{ username|tojson }},
            wallpaper: {{ wallpaper|tojson }},
            primary_color: {{ primary_color|tojson }},
            widget_bg_color: {{ widget_bg_color|tojson }},
            widget_bg_rgb: hexToRgb({{ widget_bg_color|tojson }}),
            widget_opacity: {{ widget_opacity|tojson }},
            blur_intensity: {{ blur_intensity|tojson }},
            theme: {{ theme|tojson }},
            font_size: {{ font_size|tojson }},
            avatar: {{ avatar|tojson }},
            wifi_enabled: {{ wifi_enabled|tojson }},
            volume: {{ volume|tojson }},
            default_window_width: {{ default_window_width|tojson }},
            default_window_height: {{ default_window_height|tojson }},
            taskbar_position: {{ taskbar_position|tojson }},
            profiles: {{ profiles|tojson }},
            active_profile: {{ active_profile|tojson }}
        };

        if (!meowConfig.wallpaper || meowConfig.wallpaper.trim() === '') {
            meowConfig.wallpaper = 'linear-gradient(145deg, #0f172a, #1e1b2b)';
        }
        document.documentElement.style.setProperty('--widget-bg-rgb', meowConfig.widget_bg_rgb);
    </script>

    <div id="desktop"></div>

    <div id="taskbar">
        <div class="taskbar-center">
            <div class="taskbar-icon" onclick="toggleOverview()"><i class="fa-solid fa-grid-2"></i></div>
            <div class="taskbar-icon" onclick="toggleStartMenu()"><i class="fa-brands fa-linux"></i></div>
            <div class="taskbar-icon" onclick="openFileManager()"><i class="fa-regular fa-folder-open"></i></div>
            <div class="taskbar-icon" onclick="openTerminal()"><i class="fa-solid fa-terminal"></i></div>
            <div class="taskbar-icon" onclick="openCalculator()"><i class="fa-solid fa-calculator"></i></div>
            <div class="taskbar-icon" onclick="openCodeEditor()"><i class="fa-solid fa-code"></i></div>
            <div class="taskbar-icon" onclick="openGameSelector()"><i class="fa-solid fa-gamepad"></i></div>
        </div>
        <div class="taskbar-right">
            <div class="taskbar-icon" onclick="openSettings()"><i class="fa-solid fa-gear"></i></div>
            <div><i class="fa-solid fa-wifi"></i> <span id="wifi-status">Načítám...</span></div>
            <div><i class="fa-solid fa-battery-full"></i> <span>100%</span></div>
            <div class="taskbar-time" id="taskbar-time"></div>
        </div>
    </div>

    <div id="overview" onclick="toggleOverview()"></div>

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
            <div class="start-app" onclick="openCodeEditor()"><i class="fa-solid fa-code"></i><span>Code Editor</span></div>
            <div class="start-app" onclick="openGameSelector()"><i class="fa-solid fa-gamepad"></i><span>Hry</span></div>
            <div class="start-app" onclick="openApp('calendar')"><i class="fa-regular fa-calendar"></i><span>Kalendář</span></div>
        </div>
    </div>

    <script>
        let windows = [];
        let zIndexCounter = 100;
        let draggedWindow = null;
        let dragOffsetX, dragOffsetY;
        let resizeData = null;
        let startMenuVisible = false;
        let overviewVisible = false;
        let terminalHistory = [];
        let historyIndex = -1;

        let resizeHoverThrottle = false;
        let dragThrottle = false;
        let resizeThrottle = false;

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

        function createWindow(title, contentHtml, width = null, height = null, x = 100, y = 100) {
            const id = 'win_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5);
            const desktop = document.getElementById('desktop');

            const defaultWidth = meowConfig.default_window_width || 640;
            const defaultHeight = meowConfig.default_window_height || 440;

            if (meowConfig.taskbar_position === 'top' && y < 48) {
                y = 48;
            }

            const winDiv = document.createElement('div');
            winDiv.className = 'window';
            winDiv.id = id;
            winDiv.dataset.title = title;
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
            winDiv.addEventListener('mousemove', onResizeHoverThrottled);
            winDiv.addEventListener('mousedown', (e) => startResize(e, winDiv));
            winDiv.addEventListener('mouseup', stopResize);
            winDiv.addEventListener('mouseleave', stopResize);

            windows.push({ id, element: winDiv, title });
            return id;
        }

        function startDrag(e, win) {
            if (e.target.closest('.window-btn') || resizeData) return;
            draggedWindow = win;
            const rect = win.getBoundingClientRect();
            dragOffsetX = e.clientX - rect.left;
            dragOffsetY = e.clientY - rect.top;
            document.addEventListener('mousemove', onDragThrottled);
            document.addEventListener('mouseup', stopDrag);
            e.preventDefault();
        }

        function onDrag(e) {
            if (!draggedWindow) return;
            let newX = e.clientX - dragOffsetX;
            let newY = e.clientY - dragOffsetY;
            const desktop = document.getElementById('desktop');
            const taskbarHeight = 48;
            const maxX = desktop.clientWidth - draggedWindow.offsetWidth;
            const maxY = desktop.clientHeight - draggedWindow.offsetHeight - (meowConfig.taskbar_position === 'bottom' ? taskbarHeight : 0);
            newX = Math.max(0, Math.min(newX, maxX));
            newY = Math.max(meowConfig.taskbar_position === 'top' ? taskbarHeight : 0, Math.min(newY, maxY));
            draggedWindow.style.left = newX + 'px';
            draggedWindow.style.top = newY + 'px';
        }

        const onDragThrottled = (e) => {
            if (!dragThrottle) {
                requestAnimationFrame(() => {
                    onDrag(e);
                    dragThrottle = false;
                });
                dragThrottle = true;
            }
        };

        function stopDrag() {
            draggedWindow = null;
            document.removeEventListener('mousemove', onDragThrottled);
            document.removeEventListener('mouseup', stopDrag);
        }

        function onResizeHover(e) {
            const win = e.currentTarget;
            if (resizeData || win.classList.contains('maximized')) return;
            const rect = win.getBoundingClientRect();
            const edge = getResizeEdge(e.clientX, e.clientY, rect);
            if (!edge) return;

            switch (edge) {
                case 'n': win.style.cursor = 'n-resize'; break;
                case 's': win.style.cursor = 's-resize'; break;
                case 'e': win.style.cursor = 'e-resize'; break;
                case 'w': win.style.cursor = 'w-resize'; break;
                case 'ne': win.style.cursor = 'ne-resize'; break;
                case 'nw': win.style.cursor = 'nw-resize'; break;
                case 'se': win.style.cursor = 'se-resize'; break;
                case 'sw': win.style.cursor = 'sw-resize'; break;
                default: win.style.cursor = 'default';
            }
        }

        const onResizeHoverThrottled = (e) => {
            if (!resizeHoverThrottle) {
                requestAnimationFrame(() => {
                    onResizeHover(e);
                    resizeHoverThrottle = false;
                });
                resizeHoverThrottle = true;
            }
        };

        function getResizeEdge(mx, my, rect) {
            const edgeSize = 8;
            const top = my <= rect.top + edgeSize;
            const bottom = my >= rect.bottom - edgeSize;
            const left = mx <= rect.left + edgeSize;
            const right = mx >= rect.right - edgeSize;

            if (top && left) return 'nw';
            if (top && right) return 'ne';
            if (bottom && left) return 'sw';
            if (bottom && right) return 'se';
            if (top) return 'n';
            if (bottom) return 's';
            if (left) return 'w';
            if (right) return 'e';
            return null;
        }

        function startResize(e, win) {
            if (e.target.closest('.window-btn') || draggedWindow || win.classList.contains('maximized')) return;
            const edge = getResizeEdge(e.clientX, e.clientY, win.getBoundingClientRect());
            if (!edge) return;

            const rect = win.getBoundingClientRect();
            resizeData = {
                win,
                edge,
                startX: e.clientX,
                startY: e.clientY,
                startWidth: rect.width,
                startHeight: rect.height,
                startLeft: rect.left,
                startTop: rect.top
            };
            document.addEventListener('mousemove', onResizeThrottled);
            document.addEventListener('mouseup', stopResize);
            e.preventDefault();
            e.stopPropagation();
        }

        function onResize(e) {
            if (!resizeData) return;
            const { win, edge, startX, startY, startWidth, startHeight, startLeft, startTop } = resizeData;
            const dx = e.clientX - startX;
            const dy = e.clientY - startY;
            const desktop = document.getElementById('desktop');
            const taskbarHeight = 48;
            const minW = 300, minH = 200;
            const maxW = desktop.clientWidth - startLeft;
            const maxH = desktop.clientHeight - startTop - (meowConfig.taskbar_position === 'bottom' ? taskbarHeight : 0);

            let newWidth = startWidth;
            let newHeight = startHeight;
            let newLeft = startLeft;
            let newTop = startTop;

            if (edge.includes('e')) {
                newWidth = Math.min(maxW, Math.max(minW, startWidth + dx));
            }
            if (edge.includes('w')) {
                const change = Math.min(startLeft, Math.max(-(startWidth - minW), dx));
                newWidth = startWidth - change;
                newLeft = startLeft + change;
            }
            if (edge.includes('s')) {
                newHeight = Math.min(maxH, Math.max(minH, startHeight + dy));
            }
            if (edge.includes('n')) {
                const change = Math.min(startTop, Math.max(-(startHeight - minH), dy));
                newHeight = startHeight - change;
                newTop = startTop + change;
            }

            win.style.width = newWidth + 'px';
            win.style.height = newHeight + 'px';
            win.style.left = newLeft + 'px';
            win.style.top = newTop + 'px';
        }

        const onResizeThrottled = (e) => {
            if (!resizeThrottle) {
                requestAnimationFrame(() => {
                    onResize(e);
                    resizeThrottle = false;
                });
                resizeThrottle = true;
            }
        };

        function stopResize() {
            resizeData = null;
            document.removeEventListener('mousemove', onResizeThrottled);
            document.removeEventListener('mouseup', stopResize);
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
            win.style.cursor = 'default';
        }

        function closeWindow(id) {
            document.getElementById(id)?.remove();
            windows = windows.filter(w => w.id !== id);
        }

        function toggleOverview() {
            const overview = document.getElementById('overview');
            if (!overviewVisible) {
                let html = '';
                windows.forEach(w => {
                    if (!w.element.classList.contains('minimized')) {
                        html += `
                            <div class="overview-window" onclick="activateWindow('${w.id}'); event.stopPropagation();">
                                <div class="overview-header"><i class="fa-brands fa-linux"></i> ${w.title}</div>
                                <div class="overview-content"><i class="fa-regular fa-window-maximize"></i></div>
                            </div>
                        `;
                    }
                });
                if (html === '') html = '<div style="color:white;">Žádná otevřená okna</div>';
                overview.innerHTML = html;
                overview.classList.add('visible');
                overviewVisible = true;
            } else {
                overview.classList.remove('visible');
                overviewVisible = false;
            }
        }

        function activateWindow(id) {
            const win = document.getElementById(id);
            if (win) {
                bringToFront(win);
                toggleOverview();
            }
        }

        function openFileManager() {
            createWindow('Správce souborů', `
                <div style="display: flex; gap: 15px;">
                    <div style="width: 180px; background: rgba(0,0,0,0.2); border-radius: 8px; padding: 10px;">
                        <div style="padding: 6px;"><i class="fa-regular fa-house"></i> Domů</div>
                        <div style="padding: 6px;"><i class="fa-regular fa-image"></i> Obrázky</div>
                        <div style="padding: 6px;"><i class="fa-regular fa-file"></i> Dokumenty</div>
                        <div style="padding: 6px;"><i class="fa-regular fa-music"></i> Hudba</div>
                        <div style="padding: 6px;"><i class="fa-regular fa-video"></i> Videa</div>
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
                                <div style="width:100%; height:6px; background: rgba(255,255,255,0.1); border-radius:3px;">
                                    <div style="width:${disk.percent}%; height:100%; background: linear-gradient(90deg, var(--primary), #a5d6ff); border-radius:3px;"></div>
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
                <div style="display: flex; flex-direction: column; height: 100%;">
                    <div id="${termId}-output" class="terminal-output">Vítejte v terminálu\\n$ </div>
                    <input type="text" id="${termId}-input" class="terminal-input" placeholder="zadej příkaz" autofocus>
                </div>
            `;
            const winId = createWindow('Terminál', content, 600, 350, 200, 150);
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
                            output.innerHTML += data + '\\n$ ';
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
            `, 350, 500, 220, 180);
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

        function openApp(app) {
            if (app === 'calendar') createWindow('Kalendář', '<div style="padding:20px; text-align:center;">Kalendář (demo)</div>', 400, 300, 200, 150);
        }

        function openCodeEditor() {
            const editorId = 'editor-' + Date.now();
            const termId = 'term-' + Date.now();
            const content = `
                <div class="code-editor-container">
                    <div class="editor-toolbar">
                        <select class="editor-select" id="${editorId}-lang">
                            <option value="python">Python</option>
                            <option value="c">C</option>
                            <option value="go">Go</option>
                            <option value="bash">Bash</option>
                        </select>
                        <button class="editor-run-btn" id="${editorId}-run"><i class="fa-solid fa-play"></i> Run</button>
                    </div>
                    <textarea id="${editorId}-code">#!/bin/bash\\necho "Hello from MeowOS!"</textarea>
                    <div style="height: 150px; margin-top: 10px;">
                        <div id="${termId}-output" class="terminal-output" style="height:100%;">Výstup se zobrazí zde...</div>
                    </div>
                </div>
            `;
            const winId = createWindow('Code Editor', content, 750, 600, 250, 150);
            
            setTimeout(() => {
                const textarea = document.getElementById(`${editorId}-code`);
                const langSelect = document.getElementById(`${editorId}-lang`);
                const runBtn = document.getElementById(`${editorId}-run`);
                const outputDiv = document.getElementById(`${termId}-output`);
                if (!textarea || !outputDiv) return;

                const cm = CodeMirror.fromTextArea(textarea, {
                    lineNumbers: true,
                    mode: 'bash',
                    theme: 'dracula',
                    indentUnit: 4,
                    smartIndent: true,
                    lineWrapping: true,
                    value: textarea.value
                });

                langSelect.addEventListener('change', (e) => {
                    const mode = e.target.value;
                    if (mode === 'python') cm.setOption('mode', 'python');
                    else if (mode === 'c') cm.setOption('mode', 'text/x-csrc');
                    else if (mode === 'go') cm.setOption('mode', 'go');
                    else if (mode === 'bash') cm.setOption('mode', 'shell');
                });

                runBtn.addEventListener('click', () => {
                    const code = cm.getValue();
                    const lang = langSelect.value;
                    outputDiv.innerHTML = `Spouštím ${lang}...\\n`;
                    fetch('/api/run', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({ code: code, lang: lang })
                    })
                    .then(r => r.text())
                    .then(output => {
                        outputDiv.innerHTML += output;
                        outputDiv.scrollTop = outputDiv.scrollHeight;
                    })
                    .catch(err => {
                        outputDiv.innerHTML += `Chyba: ${err}`;
                    });
                });

                cm.setSize('100%', '300px');
            }, 100);
        }

        function openPong() {
            const gameId = 'pong-' + Date.now();
            const content = `
                <div style="width:100%; height:100%; display:flex; flex-direction:column;">
                    <canvas id="${gameId}" width="600" height="400" style="flex:1; background:rgba(0,0,0,0.3); border-radius:8px;"></canvas>
                    <div style="text-align:center; margin-top:8px; font-size:12px; opacity:0.7;">
                        Ovládání: pohyb myší (levý pálka)
                    </div>
                </div>
            `;
            const winId = createWindow('Pong', content, 650, 500, 200, 150);
            setTimeout(() => {
                const canvas = document.getElementById(gameId);
                if (!canvas) return;
                const ctx = canvas.getContext('2d');

                let ball = { x: 300, y: 200, dx: 4, dy: 4, radius: 8 };
                let leftPaddle = { y: 160, width: 10, height: 80 };
                let rightPaddle = { y: 160, width: 10, height: 80 };
                let leftScore = 0, rightScore = 0;
                let gameOver = false;
                let animationId;

                function draw() {
                    ctx.clearRect(0, 0, 600, 400);
                    ctx.fillStyle = 'rgba(255,255,255,0.1)';
                    ctx.fillRect(0, 0, 600, 400);
                    ctx.strokeStyle = 'rgba(255,255,255,0.2)';
                    ctx.lineWidth = 2;
                    ctx.strokeRect(0, 0, 600, 400);

                    ctx.fillStyle = 'rgba(192,132,252,0.8)';
                    ctx.fillRect(20, leftPaddle.y, leftPaddle.width, leftPaddle.height);
                    ctx.fillRect(570, rightPaddle.y, rightPaddle.width, rightPaddle.height);

                    ctx.beginPath();
                    ctx.arc(ball.x, ball.y, ball.radius, 0, Math.PI*2);
                    ctx.fillStyle = 'rgba(255,255,255,0.9)';
                    ctx.fill();
                    ctx.shadowColor = 'rgba(192,132,252,0.5)';
                    ctx.shadowBlur = 10;
                    ctx.fill();
                    ctx.shadowBlur = 0;

                    ctx.strokeStyle = 'rgba(255,255,255,0.2)';
                    ctx.setLineDash([5, 5]);
                    ctx.beginPath();
                    ctx.moveTo(300, 0);
                    ctx.lineTo(300, 400);
                    ctx.stroke();
                    ctx.setLineDash([]);

                    ctx.font = '24px "Segoe UI"';
                    ctx.fillStyle = 'rgba(255,255,255,0.5)';
                    ctx.fillText(leftScore, 150, 50);
                    ctx.fillText(rightScore, 450, 50);
                }

                function update() {
                    if (gameOver) return;

                    ball.x += ball.dx;
                    ball.y += ball.dy;

                    if (ball.y - ball.radius < 0 || ball.y + ball.radius > 400) {
                        ball.dy *= -1;
                    }

                    rightPaddle.y += (ball.y - (rightPaddle.y + rightPaddle.height/2)) * 0.1;
                    rightPaddle.y = Math.max(0, Math.min(320, rightPaddle.y));

                    if (ball.x - ball.radius < 30 && 
                        ball.y > leftPaddle.y && 
                        ball.y < leftPaddle.y + leftPaddle.height) {
                        ball.dx = Math.abs(ball.dx);
                        ball.x = 30 + ball.radius;
                    }

                    if (ball.x + ball.radius > 570 && 
                        ball.y > rightPaddle.y && 
                        ball.y < rightPaddle.y + rightPaddle.height) {
                        ball.dx = -Math.abs(ball.dx);
                        ball.x = 570 - ball.radius;
                    }

                    if (ball.x - ball.radius < 0) {
                        rightScore++;
                        resetBall();
                    }
                    if (ball.x + ball.radius > 600) {
                        leftScore++;
                        resetBall();
                    }

                    draw();
                    animationId = requestAnimationFrame(update);
                }

                function resetBall() {
                    ball.x = 300;
                    ball.y = 200;
                    ball.dx = (Math.random() > 0.5 ? 4 : -4);
                    ball.dy = (Math.random() > 0.5 ? 3 : -3);
                }

                canvas.addEventListener('mousemove', (e) => {
                    const rect = canvas.getBoundingClientRect();
                    const scaleY = canvas.height / rect.height;
                    let mouseY = (e.clientY - rect.top) * scaleY;
                    leftPaddle.y = Math.max(0, Math.min(320, mouseY - leftPaddle.height/2));
                });

                resetBall();
                update();

                const checkInterval = setInterval(() => {
                    if (!document.getElementById(winId)) {
                        cancelAnimationFrame(animationId);
                        clearInterval(checkInterval);
                    }
                }, 1000);
            }, 100);
        }

        function openSnake() {
            const gameId = 'snake-' + Date.now();
            const content = `
                <div style="width:100%; height:100%; display:flex; flex-direction:column; align-items:center;">
                    <canvas id="${gameId}" width="400" height="400" style="background:rgba(0,0,0,0.3); border-radius:8px;"></canvas>
                    <div style="margin-top:8px; font-size:12px; opacity:0.7;">
                        Ovládání: šipky, mezerník pro restart
                    </div>
                </div>
            `;
            const winId = createWindow('Had', content, 450, 500, 250, 150);
            setTimeout(() => {
                const canvas = document.getElementById(gameId);
                if (!canvas) return;
                const ctx = canvas.getContext('2d');

                const gridSize = 20;
                const tileCount = 20;
                let snake = [{x:10, y:10}];
                let direction = {x:0, y:0};
                let food = {x:15, y:15};
                let score = 0;
                let gameOver = false;
                let animationId;

                function draw() {
                    ctx.clearRect(0, 0, 400, 400);
                    ctx.fillStyle = 'rgba(255,255,255,0.05)';
                    ctx.fillRect(0, 0, 400, 400);

                    ctx.fillStyle = 'rgba(255,100,100,0.8)';
                    ctx.shadowColor = 'rgba(255,100,100,0.5)';
                    ctx.shadowBlur = 10;
                    ctx.fillRect(food.x * gridSize, food.y * gridSize, gridSize-2, gridSize-2);
                    ctx.shadowBlur = 0;

                    snake.forEach((segment, i) => {
                        const alpha = 1 - i * 0.03;
                        ctx.fillStyle = `rgba(192,132,252,${alpha})`;
                        ctx.shadowColor = 'rgba(192,132,252,0.5)';
                        ctx.shadowBlur = 8;
                        ctx.fillRect(segment.x * gridSize, segment.y * gridSize, gridSize-2, gridSize-2);
                    });
                    ctx.shadowBlur = 0;

                    ctx.font = '16px "Segoe UI"';
                    ctx.fillStyle = 'rgba(255,255,255,0.5)';
                    ctx.fillText(`Skóre: ${score}`, 10, 30);
                }

                function update() {
                    if (gameOver) return;

                    const head = {x: snake[0].x + direction.x, y: snake[0].y + direction.y};

                    if (head.x < 0 || head.x >= tileCount || head.y < 0 || head.y >= tileCount) {
                        gameOver = true;
                        drawGameOver();
                        return;
                    }

                    if (snake.some(s => s.x === head.x && s.y === head.y)) {
                        gameOver = true;
                        drawGameOver();
                        return;
                    }

                    snake.unshift(head);

                    if (head.x === food.x && head.y === food.y) {
                        score++;
                        food.x = Math.floor(Math.random() * tileCount);
                        food.y = Math.floor(Math.random() * tileCount);
                    } else {
                        snake.pop();
                    }

                    draw();
                    animationId = requestAnimationFrame(update);
                }

                function drawGameOver() {
                    ctx.fillStyle = 'rgba(0,0,0,0.5)';
                    ctx.fillRect(0, 0, 400, 400);
                    ctx.font = '20px "Segoe UI"';
                    ctx.fillStyle = 'white';
                    ctx.fillText('Konec hry', 140, 200);
                }

                window.addEventListener('keydown', (e) => {
                    if (e.key.startsWith('Arrow')) e.preventDefault();
                    if (gameOver && e.key === ' ') {
                        snake = [{x:10, y:10}];
                        direction = {x:0, y:0};
                        food = {x:15, y:15};
                        score = 0;
                        gameOver = false;
                        update();
                        return;
                    }
                    switch(e.key) {
                        case 'ArrowUp': if (direction.y === 0) direction = {x:0, y:-1}; break;
                        case 'ArrowDown': if (direction.y === 0) direction = {x:0, y:1}; break;
                        case 'ArrowLeft': if (direction.x === 0) direction = {x:-1, y:0}; break;
                        case 'ArrowRight': if (direction.x === 0) direction = {x:1, y:0}; break;
                    }
                });

                update();

                const checkInterval = setInterval(() => {
                    if (!document.getElementById(winId)) {
                        cancelAnimationFrame(animationId);
                        clearInterval(checkInterval);
                    }
                }, 1000);
            }, 100);
        }

        function openTicTacToe() {
            const gameId = 'tictactoe-' + Date.now();
            let board = ['', '', '', '', '', '', '', '', ''];
            let currentPlayer = 'X';
            let gameOver = false;

            const content = `
                <div style="width:100%; height:100%; display:flex; flex-direction:column; align-items:center;">
                    <div id="${gameId}-board" style="display:grid; grid-template-columns:repeat(3,1fr); gap:8px; width:240px; height:240px; margin:20px auto;"></div>
                    <div id="${gameId}-status" style="margin-top:10px; font-size:16px;">Na tahu: X (ty)</div>
                    <button class="window-btn" onclick="resetTTT('${gameId}')" style="margin-top:10px; width:auto; padding:5px 15px;">Nová hra</button>
                </div>
            `;
            const winId = createWindow('Piškvorky', content, 350, 400, 280, 170);
            setTimeout(() => {
                const boardDiv = document.getElementById(`${gameId}-board`);
                const statusDiv = document.getElementById(`${gameId}-status`);
                if (!boardDiv) return;

                function renderBoard() {
                    boardDiv.innerHTML = '';
                    board.forEach((cell, index) => {
                        const cellDiv = document.createElement('div');
                        cellDiv.style.width = '80px';
                        cellDiv.style.height = '80px';
                        cellDiv.style.background = 'rgba(255,255,255,0.1)';
                        cellDiv.style.borderRadius = '8px';
                        cellDiv.style.display = 'flex';
                        cellDiv.style.alignItems = 'center';
                        cellDiv.style.justifyContent = 'center';
                        cellDiv.style.fontSize = '40px';
                        cellDiv.style.color = 'white';
                        cellDiv.style.textShadow = '0 0 10px rgba(192,132,252,0.5)';
                        cellDiv.style.cursor = 'pointer';
                        cellDiv.innerText = cell;
                        cellDiv.onclick = () => playerMove(index);
                        boardDiv.appendChild(cellDiv);
                    });
                }

                function checkWinner() {
                    const lines = [
                        [0,1,2], [3,4,5], [6,7,8],
                        [0,3,6], [1,4,7], [2,5,8],
                        [0,4,8], [2,4,6]
                    ];
                    for (let line of lines) {
                        const [a,b,c] = line;
                        if (board[a] && board[a] === board[b] && board[a] === board[c]) {
                            return board[a];
                        }
                    }
                    if (board.every(cell => cell !== '')) return 'tie';
                    return null;
                }

                function playerMove(index) {
                    if (gameOver || board[index] !== '' || currentPlayer !== 'X') return;
                    board[index] = 'X';
                    renderBoard();
                    const win = checkWinner();
                    if (win) {
                        gameOver = true;
                        if (win === 'X') statusDiv.innerText = 'Vyhrál jsi!';
                        else if (win === 'O') statusDiv.innerText = 'Vyhrála AI!';
                        else statusDiv.innerText = 'Remíza!';
                        return;
                    }
                    currentPlayer = 'O';
                    statusDiv.innerText = 'Na tahu: AI...';
                    setTimeout(aiMove, 300);
                }

                function aiMove() {
                    if (gameOver) return;
                    const empty = board.reduce((acc, cell, idx) => cell === '' ? [...acc, idx] : acc, []);
                    if (empty.length === 0) {
                        const win = checkWinner();
                        if (win === 'tie') statusDiv.innerText = 'Remíza!';
                        gameOver = true;
                        return;
                    }
                    const move = empty[Math.floor(Math.random() * empty.length)];
                    board[move] = 'O';
                    renderBoard();
                    const win = checkWinner();
                    if (win) {
                        gameOver = true;
                        if (win === 'O') statusDiv.innerText = 'Vyhrála AI!';
                        else if (win === 'X') statusDiv.innerText = 'Vyhrál jsi!';
                        else statusDiv.innerText = 'Remíza!';
                        return;
                    }
                    currentPlayer = 'X';
                    statusDiv.innerText = 'Na tahu: X (ty)';
                }

                window.resetTTT = (id) => {
                    board = ['', '', '', '', '', '', '', '', ''];
                    currentPlayer = 'X';
                    gameOver = false;
                    renderBoard();
                    statusDiv.innerText = 'Na tahu: X (ty)';
                };

                renderBoard();
            }, 100);
        }

        function openGameSelector() {
            const content = `
                <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; padding: 20px;">
                    <div class="file-icon" onclick="openPong()">
                        <i class="fa-solid fa-table-tennis-paddle-ball"></i>
                        <span>Pong</span>
                        <small>proti AI</small>
                    </div>
                    <div class="file-icon" onclick="openSnake()">
                        <i class="fa-solid fa-worm"></i>
                        <span>Had</span>
                        <small>Snake</small>
                    </div>
                    <div class="file-icon" onclick="openTicTacToe()">
                        <i class="fa-solid fa-hashtag"></i>
                        <span>Piškvorky</span>
                        <small>tic-tac-toe</small>
                    </div>
                </div>
            `;
            createWindow('Hry', content, 500, 300, 250, 150);
        }

        function openSettings() {
            fetch('/api/system-info')
                .then(r => r.json())
                .then(info => {
                    const uptime = Math.floor(info.uptime / 3600) + 'h ' + Math.floor((info.uptime % 3600) / 60) + 'm';
                    const profilesHtml = Object.keys(meowConfig.profiles).map(profileName => {
                        const isActive = (profileName === meowConfig.active_profile);
                        return `
                            <div class="profile-item ${isActive ? 'profile-active' : ''}">
                                <span class="profile-name">${profileName}</span>
                                <div class="profile-actions">
                                    <button onclick="loadProfile('${profileName.replace(/'/g, "\\\\'")}')" title="Načíst"><i class="fa-solid fa-rotate-right"></i></button>
                                    ${profileName !== 'Výchozí' ? `<button onclick="deleteProfile('${profileName.replace(/'/g, "\\\\'")}')" title="Smazat"><i class="fa-solid fa-trash"></i></button>` : ''}
                                </div>
                            </div>
                        `;
                    }).join('');

                    const content = `
                        <div class="settings-container" id="settings-container-${Date.now()}">
                            <div class="settings-tabs">
                                <div class="settings-tab active" data-tab="vzhled">Vzhled</div>
                                <div class="settings-tab" data-tab="okna">Okna</div>
                                <div class="settings-tab" data-tab="system">Systém</div>
                                <div class="settings-tab" data-tab="uzivatele">Uživatelé</div>
                                <div class="settings-tab" data-tab="lista">Lišta</div>
                                <div class="settings-tab" data-tab="sit">Síť</div>
                                <div class="settings-tab" data-tab="zvuk">Zvuk</div>
                                <div class="settings-tab" data-tab="napajeni">Napájení</div>
                                <div class="settings-tab" data-tab="o-aplikaci">O aplikaci</div>
                            </div>
                            <div id="settings-vzhled" class="settings-panel active">
                                <div class="settings-row">
                                    <div class="settings-label">Tapeta</div>
                                    <div>
                                        <div class="wallpaper-option" style="background: linear-gradient(145deg, #0f172a, #1e1b2b);" data-wall="linear-gradient(145deg, #0f172a, #1e1b2b)"></div>
                                        <div class="wallpaper-option" style="background: linear-gradient(145deg, #2d1a3a, #1a1a2f);" data-wall="linear-gradient(145deg, #2d1a3a, #1a1a2f)"></div>
                                        <div class="wallpaper-option" style="background: linear-gradient(145deg, #1a3a2d, #1a2f3f);" data-wall="linear-gradient(145deg, #1a3a2d, #1a2f3f)"></div>
                                        <div class="wallpaper-option" style="background: url('https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=200') center/cover;" data-wall="url(https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800)"></div>
                                        <div class="wallpaper-option" style="background: url('https://images.unsplash.com/photo-1510798831971-661eb04b3739?w=200') center/cover;" data-wall="url(https://images.unsplash.com/photo-1510798831971-661eb04b3739?w=800)"></div>
                                    </div>
                                    <div class="url-input">
                                        <input type="text" id="wallpaper-url" placeholder="Nebo zadej URL obrázku...">
                                        <button class="settings-btn" id="set-wallpaper-url">Nastavit</button>
                                    </div>
                                </div>
                                <div class="settings-row">
                                    <div class="settings-label">Primární barva</div>
                                    <div>
                                        <span class="color-preview" style="background: ${meowConfig.primary_color};"></span>
                                        <input type="color" id="primary-color" value="${meowConfig.primary_color}">
                                    </div>
                                </div>
                                <div class="settings-row">
                                    <div class="settings-label">Barva widgetů</div>
                                    <div>
                                        <span class="color-preview" style="background: ${meowConfig.widget_bg_color};"></span>
                                        <input type="color" id="widget-bg-color" value="${meowConfig.widget_bg_color}">
                                    </div>
                                </div>
                                <div class="settings-row">
                                    <div class="settings-label">Průhlednost (${Math.round(meowConfig.widget_opacity*100)}%)</div>
                                    <input type="range" min="0.1" max="1" step="0.05" value="${meowConfig.widget_opacity}" class="slider" id="widget-opacity-slider">
                                </div>
                                <div class="settings-row">
                                    <div class="settings-label">Intenzita rozostření (${meowConfig.blur_intensity} px)</div>
                                    <input type="range" min="0" max="20" step="1" value="${meowConfig.blur_intensity}" class="slider" id="blur-intensity-slider">
                                </div>
                                <div class="settings-row">
                                    <div class="settings-label">Barevný režim</div>
                                    <select class="settings-select" id="theme-select">
                                        <option value="dark" ${meowConfig.theme=='dark'?'selected':''}>Tmavý</option>
                                        <option value="light" ${meowConfig.theme=='light'?'selected':''}>Světlý</option>
                                    </select>
                                </div>
                                <div class="settings-row">
                                    <div class="settings-label">Velikost písma</div>
                                    <select class="settings-select" id="font-size">
                                        <option value="12px" ${meowConfig.font_size=='12px'?'selected':''}>Malá</option>
                                        <option value="13px" ${meowConfig.font_size=='13px'?'selected':''}>Střední</option>
                                        <option value="14px" ${meowConfig.font_size=='14px'?'selected':''}>Velká</option>
                                    </select>
                                </div>
                                <div class="profiles-section">
                                    <div class="settings-label">Uložené profily</div>
                                    <div id="profiles-list">
                                        ${profilesHtml}
                                    </div>
                                    <div style="display: flex; gap: 10px; margin-top: 10px;">
                                        <input type="text" id="new-profile-name" placeholder="Název nového profilu" class="settings-input" style="flex:1;">
                                        <button class="settings-btn" id="save-profile-btn">Uložit aktuální jako profil</button>
                                    </div>
                                </div>
                            </div>
                            <div id="settings-okna" class="settings-panel">
                                <div class="settings-row">
                                    <div class="settings-label">Výchozí šířka (px)</div>
                                    <input type="number" class="settings-input" id="win-width" value="${meowConfig.default_window_width}" min="300" max="1200">
                                </div>
                                <div class="settings-row">
                                    <div class="settings-label">Výchozí výška (px)</div>
                                    <input type="number" class="settings-input" id="win-height" value="${meowConfig.default_window_height}" min="200" max="900">
                                </div>
                                <button class="settings-btn" id="save-window-size">Uložit velikost</button>
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
                                <button class="settings-btn" id="save-user-settings">Uložit</button>
                            </div>
                            <div id="settings-lista" class="settings-panel">
                                <div class="settings-row">
                                    <div class="settings-label">Umístění lišty</div>
                                    <select class="settings-select" id="taskbar-position">
                                        <option value="bottom" ${meowConfig.taskbar_position=='bottom'?'selected':''}>Dole</option>
                                        <option value="top" ${meowConfig.taskbar_position=='top'?'selected':''}>Nahoře</option>
                                    </select>
                                    <button class="settings-btn" id="save-taskbar-position" style="margin-top:10px;">Uložit</button>
                                </div>
                            </div>
                            <div id="settings-sit" class="settings-panel">
                                <div class="settings-row">
                                    <label><input type="checkbox" id="wifi-checkbox" ${meowConfig.wifi_enabled?'checked':''}> Povolit Wi-Fi</label>
                                </div>
                                <div class="settings-row">IP: ${info.ips.join('<br>')}</div>
                            </div>
                            <div id="settings-zvuk" class="settings-panel">
                                <div class="settings-row">
                                    <div class="settings-label">Hlasitost (${meowConfig.volume}%)</div>
                                    <input type="range" min="0" max="100" value="${meowConfig.volume}" class="slider" id="volume-slider">
                                </div>
                            </div>
                            <div id="settings-napajeni" class="settings-panel">
                                <button class="settings-btn" id="restart-btn">Restartovat</button>
                                <button class="settings-btn" id="shutdown-btn">Vypnout</button>
                            </div>
                            <div id="settings-o-aplikaci" class="settings-panel">
                                <div style="text-align:center;">
                                    <i class="fa-brands fa-linux" style="font-size:64px;"></i>
                                    <h3>MeowOS</h3>
                                    <p>Finální edice 2026</p>
                                </div>
                            </div>
                        </div>
                    `;
                    const winId = createWindow('Nastavení', content, 780, 580, 140, 70);

                    setTimeout(() => {
                        const container = document.querySelector(`#${winId} .settings-container`);
                        if (!container) return;

                        container.querySelectorAll('.settings-tab').forEach(tab => {
                            tab.addEventListener('click', (e) => {
                                container.querySelectorAll('.settings-tab').forEach(t => t.classList.remove('active'));
                                container.querySelectorAll('.settings-panel').forEach(p => p.classList.remove('active'));
                                e.target.classList.add('active');
                                const targetId = 'settings-' + e.target.dataset.tab;
                                container.querySelector('#' + targetId)?.classList.add('active');
                            });
                        });

                        container.querySelectorAll('.wallpaper-option').forEach(el => {
                            el.addEventListener('click', () => {
                                const wall = el.dataset.wall;
                                if (wall) changeWallpaper(wall);
                            });
                        });

                        const urlBtn = container.querySelector('#set-wallpaper-url');
                        if (urlBtn) {
                            urlBtn.addEventListener('click', () => {
                                const url = container.querySelector('#wallpaper-url')?.value;
                                if (url) changeWallpaper("url('" + url + "')");
                            });
                        }

                        const primaryInput = container.querySelector('#primary-color');
                        if (primaryInput) {
                            primaryInput.addEventListener('change', (e) => changePrimaryColor(e.target.value));
                        }

                        const widgetBgInput = container.querySelector('#widget-bg-color');
                        if (widgetBgInput) {
                            widgetBgInput.addEventListener('change', (e) => changeWidgetBgColor(e.target.value));
                        }

                        const opacitySlider = container.querySelector('#widget-opacity-slider');
                        if (opacitySlider) {
                            opacitySlider.addEventListener('input', (e) => changeWidgetOpacity(e.target.value));
                        }

                        const blurSlider = container.querySelector('#blur-intensity-slider');
                        if (blurSlider) {
                            blurSlider.addEventListener('input', (e) => changeBlurIntensity(e.target.value));
                        }

                        const themeSelect = container.querySelector('#theme-select');
                        if (themeSelect) {
                            themeSelect.addEventListener('change', (e) => changeTheme(e.target.value));
                        }

                        const fontSizeSelect = container.querySelector('#font-size');
                        if (fontSizeSelect) {
                            fontSizeSelect.addEventListener('change', (e) => changeFontSize(e.target.value));
                        }

                        const saveWinBtn = container.querySelector('#save-window-size');
                        if (saveWinBtn) {
                            saveWinBtn.addEventListener('click', () => {
                                const w = container.querySelector('#win-width')?.value;
                                const h = container.querySelector('#win-height')?.value;
                                if (w && h) saveWindowSize(w, h);
                            });
                        }

                        const saveUserBtn = container.querySelector('#save-user-settings');
                        if (saveUserBtn) {
                            saveUserBtn.addEventListener('click', () => {
                                const name = container.querySelector('#username-input')?.value;
                                const avatar = container.querySelector('#avatar-select')?.value;
                                if (name && avatar) saveUserSettings(name, avatar);
                            });
                        }

                        const taskbarPosSelect = container.querySelector('#taskbar-position');
                        const saveTaskbarBtn = container.querySelector('#save-taskbar-position');
                        if (saveTaskbarBtn && taskbarPosSelect) {
                            saveTaskbarBtn.addEventListener('click', () => {
                                const pos = taskbarPosSelect.value;
                                changeTaskbarPosition(pos);
                            });
                        }

                        const wifiCheck = container.querySelector('#wifi-checkbox');
                        if (wifiCheck) {
                            wifiCheck.addEventListener('change', (e) => toggleWifi(e.target.checked));
                        }

                        const volumeSlider = container.querySelector('#volume-slider');
                        if (volumeSlider) {
                            volumeSlider.addEventListener('input', (e) => changeVolume(e.target.value));
                        }

                        const restartBtn = container.querySelector('#restart-btn');
                        if (restartBtn) restartBtn.addEventListener('click', () => powerAction('restart'));
                        const shutdownBtn = container.querySelector('#shutdown-btn');
                        if (shutdownBtn) shutdownBtn.addEventListener('click', () => powerAction('shutdown'));

                        const saveProfileBtn = container.querySelector('#save-profile-btn');
                        if (saveProfileBtn) {
                            saveProfileBtn.addEventListener('click', () => {
                                const profileName = container.querySelector('#new-profile-name')?.value;
                                if (profileName) saveProfile(profileName);
                            });
                        }
                    }, 50);
                });
        }

        function loadProfile(name) {
            fetch('/api/load-profile', {
                method: 'POST',
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: 'name=' + encodeURIComponent(name)
            }).then(() => {
                window.location.href = window.location.href.split('?')[0] + '?t=' + Date.now();
            });
        }

        function saveProfile(name) {
            fetch('/api/save-profile', {
                method: 'POST',
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: 'name=' + encodeURIComponent(name)
            }).then(() => {
                window.location.href = window.location.href.split('?')[0] + '?t=' + Date.now();
            });
        }

        function deleteProfile(name) {
            if (confirm(`Opravdu smazat profil "${name}"?`)) {
                fetch('/api/delete-profile', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                    body: 'name=' + encodeURIComponent(name)
                }).then(() => {
                    window.location.href = window.location.href.split('?')[0] + '?t=' + Date.now();
                });
            }
        }

        function changeWallpaper(value) {
            document.body.style.setProperty('--wallpaper', value);
            fetch('/api/set-wallpaper', { method: 'POST', body: 'wallpaper=' + encodeURIComponent(value), headers: {'Content-Type': 'application/x-www-form-urlencoded'} })
            .then(() => {
                meowConfig.wallpaper = value;
            });
        }

        function changePrimaryColor(value) {
            document.body.style.setProperty('--primary', value);
            fetch('/api/set-primary', { method: 'POST', body: 'color=' + value, headers: {'Content-Type': 'application/x-www-form-urlencoded'} })
            .then(() => {
                meowConfig.primary_color = value;
            });
        }

        function changeWidgetBgColor(value) {
            document.body.style.setProperty('--widget-bg', value);
            const rgb = hexToRgb(value);
            document.documentElement.style.setProperty('--widget-bg-rgb', rgb);
            fetch('/api/set-widget-bg', { method: 'POST', body: 'color=' + value, headers: {'Content-Type': 'application/x-www-form-urlencoded'} })
            .then(() => {
                meowConfig.widget_bg_color = value;
                meowConfig.widget_bg_rgb = rgb;
            });
        }

        function changeWidgetOpacity(value) {
            document.body.style.setProperty('--widget-opacity', value);
            fetch('/api/set-widget-opacity', { method: 'POST', body: 'opacity=' + value, headers: {'Content-Type': 'application/x-www-form-urlencoded'} })
            .then(() => {
                meowConfig.widget_opacity = parseFloat(value);
            });
        }

        function changeBlurIntensity(value) {
            document.body.style.setProperty('--blur-intensity', value + 'px');
            fetch('/api/set-blur', { method: 'POST', body: 'blur=' + value, headers: {'Content-Type': 'application/x-www-form-urlencoded'} })
            .then(() => {
                meowConfig.blur_intensity = parseInt(value);
            });
        }

        function changeTheme(value) {
            const root = document.documentElement;
            root.style.setProperty('--theme', value);
            root.style.setProperty('--text-color', value === 'dark' ? 'rgba(255,255,255,0.9)' : 'rgba(0,0,0,0.9)');
            fetch('/api/set-theme', { method: 'POST', body: 'theme=' + value, headers: {'Content-Type': 'application/x-www-form-urlencoded'} })
            .then(() => {
                meowConfig.theme = value;
            });
        }

        function changeFontSize(value) {
            document.body.style.setProperty('--font-size', value);
            fetch('/api/set-fontsize', { method: 'POST', body: 'size=' + value, headers: {'Content-Type': 'application/x-www-form-urlencoded'} })
            .then(() => {
                meowConfig.font_size = value;
            });
        }

        function saveUserSettings(name, avatar) {
            document.getElementById('start-username').innerText = name;
            document.getElementById('start-username').previousElementSibling.className = `fa-solid fa-${avatar}`;
            fetch('/api/set-username', { method: 'POST', body: 'username=' + encodeURIComponent(name), headers: {'Content-Type': 'application/x-www-form-urlencoded'} });
            fetch('/api/set-avatar', { method: 'POST', body: 'avatar=' + avatar, headers: {'Content-Type': 'application/x-www-form-urlencoded'} });
        }

        function saveWindowSize(width, height) {
            document.documentElement.style.setProperty('--default-win-width', width + 'px');
            document.documentElement.style.setProperty('--default-win-height', height + 'px');
            fetch('/api/set-window-size', { method: 'POST', body: `width=${width}&height=${height}`, headers: {'Content-Type': 'application/x-www-form-urlencoded'} });
        }

        function changeTaskbarPosition(pos) {
            fetch('/api/set-taskbar-pos', { method: 'POST', body: 'pos=' + pos, headers: {'Content-Type': 'application/x-www-form-urlencoded'} })
            .then(() => {
                location.reload();
            });
        }

        function toggleWifi(enabled) {
            fetch('/api/set-wifi', { method: 'POST', body: 'enabled=' + enabled, headers: {'Content-Type': 'application/x-www-form-urlencoded'} });
        }

        function changeVolume(value) {
            fetch('/api/set-volume', { method: 'POST', body: 'volume=' + value, headers: {'Content-Type': 'application/x-www-form-urlencoded'} });
        }

        function powerAction(action) {
            if (action === 'restart' && confirm('Opravdu restartovat?')) fetch('/api/restart');
            else if (action === 'shutdown' && confirm('Opravdu vypnout?')) fetch('/api/shutdown');
        }

        function toggleStartMenu() {
            const menu = document.getElementById('start-menu');
            startMenuVisible = !startMenuVisible;
            menu.classList.toggle('visible', startMenuVisible);
        }

        document.addEventListener('click', function(e) {
            const menu = document.getElementById('start-menu');
            const startBtn = document.querySelector('.taskbar-icon:nth-child(2)');
            if (startMenuVisible && !menu.contains(e.target) && !startBtn.contains(e.target)) {
                menu.classList.remove('visible');
                startMenuVisible = false;
            }
        });

        window.onload = function() {
            openFileManager();
            openThisPC();
        };
    </script>
</body>
</html>
"""

# ============================================================================
# Spuštění serveru
# ============================================================================
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
EOF

echo "✅ Aplikace vytvořena (1500 řádků, bez xterm.js)."
echo "🚀 Spouštím server..."
echo "Připoj se na http://$(hostname -I | awk '{print $1}'):5000"
cd ~/meowos
python3 app.py
EOF
