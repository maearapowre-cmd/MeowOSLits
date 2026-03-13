#!/usr/bin/env python3
"""
MeowOS Lite – jediný soubor, vše v Pygame a Tkinter.
Spuštění bez parametru = desktop.
S parametrem --clock = hodiny, --settings = nastavení.
"""

import sys
import os
import subprocess
import pygame
import psutil
import socket
from datetime import datetime
import tkinter as tk
from tkinter import Label
import time

# Přesměrování chyb do souboru (pro ladění)
import traceback

def log_error(e):
    with open("/home/jakub/meowos_error.log", "a") as f:
        f.write(f"{datetime.now()}: {traceback.format_exc()}\n")

# ======================================================================
# APLIKACE: Hodiny (Tkinter)
# ======================================================================
def run_clock():
    try:
        root = tk.Tk()
        root.title("Hodiny")
        root.geometry("300x150")
        root.configure(bg='#2d2d3a')
        label = Label(root, font=('Helvetica', 40), fg='white', bg='#2d2d3a')
        label.pack(expand=True)

        def update():
            label.config(text=datetime.now().strftime("%H:%M:%S"))
            root.after(1000, update)

        update()
        root.mainloop()
    except Exception as e:
        log_error(e)

# ======================================================================
# APLIKACE: Nastavení (Tkinter)
# ======================================================================
def run_settings():
    try:
        root = tk.Tk()
        root.title("Nastavení")
        root.geometry("400x300")
        root.configure(bg='#2d2d3a')
        label = tk.Label(root, text="Zde budou nastavení", font=('Helvetica', 20), fg='white', bg='#2d2d3a')
        label.pack(expand=True)
        root.mainloop()
    except Exception as e:
        log_error(e)

# ======================================================================
# DESKTOP (Pygame)
# ======================================================================
class Desktop:
    def __init__(self):
        pygame.init()
        info = pygame.display.Info()
        self.width, self.height = info.current_w, info.current_h
        self.screen = pygame.display.set_mode((self.width, self.height), pygame.FULLSCREEN)
        pygame.display.set_caption("MeowOS Lite")
        self.clock = pygame.time.Clock()
        self.running = True

        # Barvy
        self.BLACK = (0,0,0)
        self.WHITE = (255,255,255)
        self.GLASS_BG = (30,30,40,200)  # RGBA
        self.DOCK_BG = (20,20,30,220)
        self.BUTTON_BG = (60,60,80,150)
        self.BUTTON_HOVER = (100,100,140,200)

        # Fonty
        self.font_large = pygame.font.Font(None, 72)
        self.font_medium = pygame.font.Font(None, 48)
        self.font_small = pygame.font.Font(None, 36)

        # Data widgetů
        self.widgets = []
        self.create_widgets()

        # Dock tlačítka
        self.buttons = []
        self.create_dock()

        # Časovače
        self.last_update_1s = time.time()
        self.last_update_5s = time.time()

        # Hlavní smyčka
        self.run()

    def create_widgets(self):
        # První sloupec
        self.clock_widget = self.add_widget(50, 80, 220, 150, "Čas")
        self.ram_widget = self.add_widget(50, 250, 220, 150, "RAM")
        self.cpu_widget = self.add_widget(50, 420, 220, 150, "CPU")

        # Druhý sloupec
        self.disk_widget = self.add_widget(320, 80, 220, 150, "Disk /")
        self.temp_widget = self.add_widget(320, 250, 220, 150, "Teplota")
        self.net_widget = self.add_widget(320, 420, 220, 150, "Síť")

        # Třetí sloupec
        self.uptime_widget = self.add_widget(590, 80, 220, 150, "Běží")
        self.battery_widget = self.add_widget(590, 250, 220, 150, "Baterie")

    def add_widget(self, x, y, w, h, title):
        rect = pygame.Rect(x, y, w, h)
        self.widgets.append({
            'rect': rect,
            'title': title,
            'value': '---',
            'bg': self.GLASS_BG
        })
        return self.widgets[-1]

    def create_dock(self):
        dock_rect = pygame.Rect(0, self.height-90, self.width, 90)
        self.dock_area = dock_rect
        btn_w, btn_h = 80, 60
        spacing = 20
        total_width = 4*btn_w + 3*spacing
        start_x = (self.width - total_width) // 2
        y = self.height - 75
        apps = [
            ("Term", self.launch_terminal),
            ("Hod", self.launch_clock),
            ("Nast", self.launch_settings),
            ("Soub", self.launch_filemanager)
        ]
        for i, (label, cmd) in enumerate(apps):
            x = start_x + i*(btn_w+spacing)
            rect = pygame.Rect(x, y, btn_w, btn_h)
            self.buttons.append({
                'rect': rect,
                'label': label,
                'cmd': cmd,
                'hover': False
            })

    def launch_terminal(self):
        subprocess.Popen(["lxterminal"])

    def launch_clock(self):
        subprocess.Popen(["python3", "/home/jakub/meowos.py", "--clock"])

    def launch_settings(self):
        subprocess.Popen(["python3", "/home/jakub/meowos.py", "--settings"])

    def launch_filemanager(self):
        subprocess.Popen(["pcmanfm"])

    def update_widgets(self):
        # Každou sekundu
        now = time.time()
        if now - self.last_update_1s >= 1:
            self.clock_widget['value'] = datetime.now().strftime("%H:%M:%S")
            # uptime
            try:
                with open('/proc/uptime', 'r') as f:
                    uptime_sec = float(f.read().split()[0])
                    hours = int(uptime_sec // 3600)
                    minutes = int((uptime_sec % 3600) // 60)
                    self.uptime_widget['value'] = f"{hours}h {minutes}m"
            except:
                self.uptime_widget['value'] = "N/A"
            self.last_update_1s = now

        # Každých 5 sekund
        if now - self.last_update_5s >= 5:
            # RAM
            mem = psutil.virtual_memory()
            self.ram_widget['value'] = f"{mem.percent:.1f}% ({mem.used//1024**2}MB/{mem.total//1024**2}MB)"
            # CPU
            cpu = psutil.cpu_percent(interval=None)
            self.cpu_widget['value'] = f"{cpu:.1f}%"
            # Disk
            disk = psutil.disk_usage('/')
            self.disk_widget['value'] = f"{disk.percent:.1f}% ({disk.used//1024**3}G/{disk.total//1024**3}G)"
            # Teplota
            try:
                with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
                    temp = round(int(f.read().strip())/1000, 1)
                self.temp_widget['value'] = f"{temp}°C"
            except:
                self.temp_widget['value'] = "N/A"
            # Síť
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                s.connect(("8.8.8.8", 80))
                ip = s.getsockname()[0]
                s.close()
                self.net_widget['value'] = ip
            except:
                self.net_widget['value'] = "offline"
            self.last_update_5s = now

    def draw(self):
        self.screen.fill((20,20,30))  # tmavé pozadí

        # Vykreslit widgety
        for w in self.widgets:
            # Průhledný podklad
            s = pygame.Surface((w['rect'].width, w['rect'].height), pygame.SRCALPHA)
            pygame.draw.rect(s, w['bg'], s.get_rect(), border_radius=15)
            pygame.draw.rect(s, (255,255,255,60), s.get_rect(), 2, border_radius=15)
            self.screen.blit(s, w['rect'])
            # Titulek
            title = self.font_small.render(w['title'], True, (200,200,200))
            self.screen.blit(title, (w['rect'].x+10, w['rect'].y+5))
            # Hodnota
            val = self.font_medium.render(w['value'], True, self.WHITE)
            val_rect = val.get_rect(center=(w['rect'].centerx, w['rect'].centery+10))
            self.screen.blit(val, val_rect)

        # Vykreslit dock
        dock_surf = pygame.Surface((self.dock_area.width, self.dock_area.height), pygame.SRCALPHA)
        pygame.draw.rect(dock_surf, self.DOCK_BG, dock_surf.get_rect(), border_radius=30)
        self.screen.blit(dock_surf, self.dock_area)

        # Vykreslit tlačítka
        mouse_pos = pygame.mouse.get_pos()
        for btn in self.buttons:
            hover = btn['rect'].collidepoint(mouse_pos)
            color = self.BUTTON_HOVER if hover else self.BUTTON_BG
            s = pygame.Surface((btn['rect'].width, btn['rect'].height), pygame.SRCALPHA)
            pygame.draw.rect(s, color, s.get_rect(), border_radius=10)
            self.screen.blit(s, btn['rect'])
            lbl = self.font_small.render(btn['label'], True, self.WHITE)
            lbl_rect = lbl.get_rect(center=btn['rect'].center)
            self.screen.blit(lbl, lbl_rect)

        pygame.display.flip()

    def handle_events(self):
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    self.running = False
            elif event.type == pygame.MOUSEBUTTONDOWN:
                if event.button == 1:  # levé tlačítko
                    for btn in self.buttons:
                        if btn['rect'].collidepoint(event.pos):
                            btn['cmd']()
                            break

    def run(self):
        while self.running:
            self.handle_events()
            self.update_widgets()
            self.draw()
            self.clock.tick(30)
        pygame.quit()
        sys.exit()

# ======================================================================
# HLAVNÍ VSTUP
# ======================================================================
if __name__ == "__main__":
    try:
        if len(sys.argv) > 1:
            if sys.argv[1] == "--clock":
                run_clock()
            elif sys.argv[1] == "--settings":
                run_settings()
            else:
                print("Neznámý parametr. Použití: meowos.py [--clock|--settings]")
        else:
            Desktop()
    except Exception as e:
        log_error(e)
        # aby nebyla černá obrazovka, vypíšeme chybu na konzoli (pokud nějaká je)
        print("Chyba v MeowOS:", e, file=sys.stderr)
        time.sleep(10)
