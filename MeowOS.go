package main

import (
	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/driver/desktop"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
	"image/color"
	"os/exec"
	"strings"
	"time"
)

// ============================================================================
// Hlavní struktura desktopového prostředí
// ============================================================================
type MeowOS struct {
	app    fyne.App
	window fyne.Window
}

func NewMeowOS() *MeowOS {
	a := app.New()
	// Nastavíme vlastní motiv (glass)
	a.Settings().SetTheme(&myTheme{})
	w := a.NewWindow("MeowOS")
	w.SetPadded(false)                // žádné okraje
	w.CenterOnScreen()
	w.SetFullScreen(true)              // celá obrazovka

	return &MeowOS{app: a, window: w}
}

// ============================================================================
// Vlastní motiv (glass efekty)
// ============================================================================
type myTheme struct {}

func (m *myTheme) Color(name fyne.ThemeColorName, variant fyne.ThemeVariant) color.Color {
	switch name {
	case theme.ColorNameBackground:
		return color.NRGBA{30, 30, 40, 255}      // tmavé pozadí
	case theme.ColorNamePrimary:
		return color.NRGBA{100, 100, 200, 255}
	case theme.ColorNameForeground:
		return color.White
	case theme.ColorNameInputBackground:
		return color.NRGBA{255, 255, 255, 30}    // průhledné vstupy
	case theme.ColorNameShadow:
		return color.NRGBA{0, 0, 0, 80}
	default:
		return theme.DefaultTheme().Color(name, variant)
	}
}

func (m *myTheme) Font(style fyne.TextStyle) fyne.Resource {
	return theme.DefaultTheme().Font(style)
}

func (m *myTheme) Icon(name fyne.ThemeIconName) fyne.Resource {
	return theme.DefaultTheme().Icon(name)
}

func (m *myTheme) Size(name fyne.ThemeSizeName) float32 {
	switch name {
	case theme.SizeNamePadding:
		return 8
	case theme.SizeNameInnerPadding:
		return 8
	case theme.SizeNameScrollBar:
		return 10
	case theme.SizeNameText:
		return 14
	default:
		return theme.DefaultTheme().Size(name)
	}
}

// ============================================================================
// Horní lišta s menu
// ============================================================================
func (os *MeowOS) createTopBar() fyne.CanvasObject {
	// Logo (ikona kočky)
	logo := canvas.NewText("🐱", color.White)
	logo.TextSize = 24

	// Systémové menu
	sysMenu := widget.NewPopUpMenu(fyne.NewMenu("",
		fyne.NewMenuItem("O aplikaci", func() {
			os.showAboutDialog()
		}),
		fyne.NewMenuItemSeparator(),
		fyne.NewMenuItem("Konec", func() {
			os.window.Close()
		}),
	), os.window.Canvas())

	// Tlačítko pro otevření menu
	menuBtn := widget.NewButtonWithIcon("", theme.MenuIcon(), func() {
		sysMenu.ShowAtPosition(fyne.NewPos(10, 30))
	})
	menuBtn.Importance = widget.LowImportance

	// Hodiny uprostřed
	clock := widget.NewLabel("")
	updateClock := func() {
		clock.SetText(time.Now().Format("15:04:05"))
	}
	updateClock()
	go func() {
		for range time.Tick(time.Second) {
			updateClock()
		}
	}()

	// Systémové ikony vpravo (Wi‑Fi, baterie – placeholder)
	wifiIcon := widget.NewIcon(theme.ComputerIcon())   // dočasně
	batteryIcon := widget.NewIcon(theme.InfoIcon())    // dočasně

	rightBox := container.NewHBox(wifiIcon, batteryIcon)

	// Složení horní lišty
	topBar := container.NewHBox(
		menuBtn,
		logo,
		layout.NewSpacer(),
		clock,
		layout.NewSpacer(),
		rightBox,
	)
	// Průhledné pozadí
	topBarBg := canvas.NewRectangle(color.NRGBA{20, 20, 30, 200})
	topBarBg.SetMinSize(fyne.NewSize(800, 40))
	return container.NewStack(topBarBg, topBar)
}

// ============================================================================
// Dock (spodní lišta s aplikacemi)
// ============================================================================
func (os *MeowOS) createDock() fyne.CanvasObject {
	// Tlačítka pro spouštění aplikací
	termBtn := widget.NewButtonWithIcon("", theme.ContentPasteIcon(), func() {
		os.openTerminal()
	})
	clockBtn := widget.NewButtonWithIcon("", theme.ClockIcon(), func() {
		os.openClock()
	})
	settingsBtn := widget.NewButtonWithIcon("", theme.SettingsIcon(), func() {
		os.openSettings()
	})
	fileBtn := widget.NewButtonWithIcon("", theme.FolderIcon(), func() {
		os.openFileManager()
	})

	// Seskupení do kontejneru s mezerami
	dockContent := container.NewHBox(
		layout.NewSpacer(),
		termBtn, clockBtn, settingsBtn, fileBtn,
		layout.NewSpacer(),
	)

	// Průhledné pozadí docku
	dockBg := canvas.NewRectangle(color.NRGBA{20, 20, 30, 200})
	dockBg.SetMinSize(fyne.NewSize(800, 70))
	dockBg.CornerRadius = 20

	return container.NewStack(dockBg, dockContent)
}

// ============================================================================
// Aplikace: Terminál
// ============================================================================
func (os *MeowOS) openTerminal() {
	win := os.app.NewWindow("Terminál")
	win.Resize(fyne.NewSize(600, 400))

	// Vstupní řádek
	input := widget.NewEntry()
	input.SetPlaceHolder("Zadej příkaz...")

	// Oblast pro výstup
	output := widget.NewLabel("")
	output.Wrapping = fyne.TextWrapWord

	// Scroll pro výstup
	scroll := container.NewScroll(output)
	scroll.SetMinSize(fyne.NewSize(580, 300))

	// Spuštění příkazu po stisku Enter
	input.OnSubmitted = func(cmd string) {
		if cmd == "" {
			return
		}
		output.SetText(output.Text + "\n$ " + cmd + "\n")

		// Spustíme příkaz v shellu
		go func() {
			parts := strings.Fields(cmd)
			if len(parts) == 0 {
				return
			}
			var out []byte
			var err error
			if len(parts) == 1 {
				out, err = exec.Command(parts[0]).CombinedOutput()
			} else {
				out, err = exec.Command(parts[0], parts[1:]...).CombinedOutput()
			}
			res := string(out)
			if err != nil {
				res += "\n" + err.Error()
			}
			// Aktualizujeme výstup v hlavním vlákně
			output.SetText(output.Text + res + "\n")
			scroll.ScrollToBottom()
		}()
		input.SetText("")
	}

	win.SetContent(container.NewBorder(
		input, nil, nil, nil,
		scroll,
	))
	win.Show()
}

// ============================================================================
// Aplikace: Hodiny
// ============================================================================
func (os *MeowOS) openClock() {
	win := os.app.NewWindow("Hodiny")
	win.Resize(fyne.NewSize(300, 150))

	timeLabel := widget.NewLabel("")
	timeLabel.TextStyle = fyne.TextStyle{Bold: true}
	timeLabel.Alignment = fyne.TextAlignCenter

	update := func() {
		timeLabel.SetText(time.Now().Format("15:04:05"))
	}
	update()
	go func() {
		for range time.Tick(time.Second) {
			update()
		}
	}()

	win.SetContent(container.NewCenter(timeLabel))
	win.Show()
}

// ============================================================================
// Aplikace: Nastavení (placeholder)
// ============================================================================
func (os *MeowOS) openSettings() {
	win := os.app.NewWindow("Nastavení")
	win.Resize(fyne.NewSize(400, 300))
	win.SetContent(widget.NewLabel("Zde budou nastavení"))
	win.Show()
}

// ============================================================================
// Aplikace: Souborový manažer (placeholder – spustí pcmanfm)
// ============================================================================
func (os *MeowOS) openFileManager() {
	exec.Command("pcmanfm").Start()
}

// ============================================================================
// Dialog O aplikaci
// ============================================================================
func (os *MeowOS) showAboutDialog() {
	widget.NewPopUp(
		container.NewVBox(
			widget.NewLabelWithStyle("MeowOS", fyne.TextAlignCenter, fyne.TextStyle{Bold: true}),
			widget.NewLabel("Verze 1.0"),
			widget.NewLabel("Desktopové prostředí pro RPi Zero 2W"),
			widget.NewLabel("Vytvořeno v Go + Fyne"),
			widget.NewButton("Zavřít", func() {
				// zavře se automaticky
			}),
		),
		os.window.Canvas(),
	).ShowAtPosition(fyne.NewPos(100, 100))
}

// ============================================================================
// Hlavní funkce – sestavení desktopu
// ============================================================================
func main() {
	os := NewMeowOS()

	// Vytvoření horní lišty
	topBar := os.createTopBar()

	// Vytvoření docku
	dock := os.createDock()

	// Plocha – jen pozadí (můžeme přidat tapetu)
	background := canvas.NewRectangle(color.NRGBA{30, 30, 40, 255})
	background.SetMinSize(fyne.NewSize(800, 480))

	// Složení celé obrazovky
	content := container.NewBorder(
		topBar,                // nahoře
		dock,                  // dole
		nil, nil,              // vlevo, vpravo
		background,            // střed (plocha)
	)

	os.window.SetContent(content)
	os.window.ShowAndRun()
}
