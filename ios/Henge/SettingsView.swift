import SwiftUI

struct SettingsView: View {
    @ObservedObject private var jit = JITCoordinator.shared
    @AppStorage(JITCoordinator.autoEnableKey) private var jitAtLaunch = false
    @AppStorage(HardwareMouse.speedKey) private var mouseSpeed = 1.0
    @AppStorage(HardwareMouse.reverseKey) private var reverseScrolling = false
    @AppStorage(HardwareMouse.scrollSpeedKey) private var scrollSpeed = 0.3
    @AppStorage(VolumeClicks.inputModeKey) private var inputMode = VolumeClicks.InputMode.touchscreen
    @AppStorage(VolumeClicks.modeKey) private var volumeMode = VolumeClicks.Mode.delayHold
    @AppStorage(VolumeClicks.swapKey) private var swapButtons = false
    @AppStorage(PhysicalMouseButtons.swapKey) private var swapMouseButtons = false
    @AppStorage(HardwareMouse.sideButtonsKey) private var sideButtonsNavigate = true
    @AppStorage(HardwareKeys.swapCommandOptionKey) private var swapCommandOption = false
    @AppStorage(HardwareKeys.capsLockControlKey) private var capsLockAsControl = false
    @AppStorage(EngineTuning.refreshKey) private var refreshRate = 60
    @AppStorage(EngineTuning.fastFlushKey) private var fastFlush = true
    @AppStorage(EngineTuning.wfiSpinKey) private var wfiSpin = false
    @AppStorage(EngineTuning.superblocksKey) private var superblocks = false
    @AppStorage(JITBootstrap.codeCacheKey) private var codeCacheMB = JITBootstrap.defaultCodeCacheMB

    /// The second footer paragraph: how you click, given the selected input mode.
    private var inputDescription: String {
        if inputMode == .touchscreen {
            return "Einmal tippen zum Klicken. Tippen und halten, um zu ziehen. Schnell mit zwei Fingern tippen für einen Rechtsklick."
        }
        switch volumeMode {
        case .delayHold:
            return "„Verzögert halten“ wartet ab, ob du die Lautstärketaste hältst oder nur klickst. Dadurch dauert jeder Klick etwa 0,5 s."
        case .tapThenDrag:
            return "„Tippen, dann ziehen“ wartet ebenfalls ab, ob du hältst oder klickst, sendet aber immer sofort einen Klick. Das macht Klicks kürzer, schickt aber vor dem Halten einen Klick."
        case .intercept:
            return "Aktiviert die Kamera, um die Lautstärketasten sauber abzufangen. Dann verhalten sie sich genau wie Maustasten, das Gerät wird aber wärmer, weil die Kamera immer läuft."
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("JIT") {
                    LabeledContent("Status", value: JITBootstrap.ready ? "An" : "Aus")
                    Picker("Methode", selection: $jit.method) {
                        ForEach(JITMethod.allCases) { Text($0.title).tag($0) }
                    }
                    Text(jit.method == .automatic ? jit.automaticDescription : "Simplex Mac nutzt \(jit.method.title).")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("JIT einrichten") { jit.showSetup = true }
                    Toggle("JIT beim Öffnen einschalten", isOn: $jitAtLaunch)
                    if jitAtLaunch {
                        Text("Simplex Mac verbindet zuerst LocalDevVPN, falls es aus ist, und kehrt dann zurück.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    LabeledContent("Codebereich", value: "\(JITBootstrap.jitBytes >> 20) MB, einmal pro Start belegt")
                }
                .listRowBackground(Desk.card)
                Section("Arbeitsspeicher") {
                    LabeledContent("Zusätzlicher Speicher", value: Entitlements.increasedMemory ? "An" : "Aus")
                    LabeledContent("Limit der App", value: ByteText.string(UInt64(Entitlements.memoryLimitAtLaunch)))
                    LabeledContent("Frei für die App", value: ByteText.string(UInt64(henge_available_memory())))
                    Text(Entitlements.increasedMemory
                         ? "Sobald JIT an ist, zählt der Arbeitsspeicher eines Macs nicht zu diesem Limit. Lehnt iOS das ab, wird stattdessen freier Speicherplatz genutzt."
                         : "Diese Installation ist nicht mit der Berechtigung für ein erhöhtes Speicherlimit signiert. Installiere Simplex Mac mit einem Zertifikat neu, das sie hat. Exportiere vorher deinen Mac, falls die Neuinstallation die App-Daten ersetzt.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .listRowBackground(Desk.card)
                Group {
                    Section(Device.isPad ? "Maus und Trackpad" : "Maus") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Zeigergeschwindigkeit")
                            Slider(value: $mouseSpeed, in: 0.5...3)
                        }
                        Toggle("Scrollrichtung umkehren", isOn: $reverseScrolling)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scrollgeschwindigkeit")
                            Slider(value: $scrollSpeed, in: 0.1...1.5)
                        }
                        Toggle("Rechte und mittlere Maustaste tauschen", isOn: $swapMouseButtons)
                        Text("Nur einschalten, wenn rechte und mittlere Taste deiner Maus im Mac vertauscht sind. Die Touch-Steuerung bleibt gleich. Gilt nach einem Neustart des Macs.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Toggle("Seitentasten für Zurück und Vor", isOn: $sideButtonsNavigate)
                        Text(Device.isPad
                             ? "Ein Magic Keyboard oder eine USB- oder Bluetooth-Maus bewegt den Zeiger des Macs. Die Zeigergeschwindigkeit gilt beim nächsten Mac-Start, die Scrollgeschwindigkeit sofort."
                             : "Das iPhone nutzt eine Maus über AssistiveTouch: Schalte es unter Einstellungen › Bedienungshilfen › Tippen › AssistiveTouch ein und kopple eine Bluetooth-Maus dort unter „Geräte“ (eine USB-Maus einfach anstecken). Simplex Mac nimmt Bewegung, Tasten und Mausrad direkt von der Maus und ignoriert die Berührungen, die AssistiveTouch für Klicks erzeugt – so kommt jeder Klick genau einmal an. Um den runden iPhone-Zeiger über dem Mac auszublenden, stelle unter „Zeigerstil“ das automatische Ausblenden auf eine kurze Zeit. Die Zeigergeschwindigkeit gilt beim nächsten Mac-Start, die Scrollgeschwindigkeit sofort.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .listRowBackground(Desk.card)
                }
                Section("Tastatur") {
                    Toggle("Command und Option tauschen", isOn: $swapCommandOption)
                    Toggle("Feststelltaste als Control", isOn: $capsLockAsControl)
                    Text("Eine USB- oder Bluetooth-Tastatur tippt direkt in den Mac, mit allen Tasten und Sondertasten. Bei einer PC-Tastatur Command und Option tauschen, damit die Taste neben der Leertaste wie beim Mac ⌘ ist. Änderungen gelten beim nächsten Mac-Start. Das \(Device.name) behält ein paar Kurzbefehle für sich, etwa ⌘-Tab, ⌘-Leertaste und ⌘-H.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .listRowBackground(Desk.card)
                if !Device.isPad {
                    Section("Trackpad") {
                        Picker("Eingabemodus", selection: $inputMode) {
                            Text("Touchscreen").tag(VolumeClicks.InputMode.touchscreen)
                            Text("Lautstärketasten").tag(VolumeClicks.InputMode.volumeButtons)
                        }
                        .pickerStyle(.menu)
                        if inputMode == .volumeButtons {
                            Picker("Tastenmodus", selection: $volumeMode) {
                                Text("Verzögert halten").tag(VolumeClicks.Mode.delayHold)
                                Text("Tippen, dann ziehen").tag(VolumeClicks.Mode.tapThenDrag)
                                Text("Über Kamera abfangen").tag(VolumeClicks.Mode.intercept)
                            }
                            .pickerStyle(.menu)
                            Toggle("Tasten tauschen", isOn: $swapButtons)
                        }
                        Text("Simplex Mac emuliert ein Magic Trackpad, sodass du echte macOS-Gesten auf dem Touchscreen deines Geräts machen kannst.\n\n\(inputDescription)")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .listRowBackground(Desk.card)
                }
                Section("Leistung") {
                    Picker("Bildwiederholrate des Macs", selection: $refreshRate) {
                        Text("30 Hz").tag(30)
                        Text("60 Hz").tag(60)
                        Text("120 Hz").tag(120)
                    }
                    .pickerStyle(.segmented)
                    Toggle("Schnellere Schreibzugriffe", isOn: $fastFlush)
                    Toggle("Schneller aus dem Leerlauf aufwachen", isOn: $wfiSpin)
                    Toggle("Superblöcke (experimentell)", isOn: $superblocks)
                    Picker("Code-Cache", selection: $codeCacheMB) {
                        Text("1 GB").tag(1024)
                        Text("1.5 GB").tag(1536)
                    }
                    Text("Ein größerer Code-Cache wird seltener geleert und braucht mehr Speicher; Simplex Mac wählt 1,5 GB, wo Platz ist. Gilt beim nächsten Öffnen der App. Wenn JIT nicht mehr angeht, wähle 1 GB.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("macOS zeichnet bei jeder Bildwiederholung ein Bild: 30 Hz lässt Apps am meisten emulierte CPU-Leistung, Animationen ruckeln dafür mehr; 60 Hz ist flüssiger. Schnellere Schreibzugriffe ordnen sie, ohne auf eine volle Synchronisierung zu warten; bei plötzlichem Stromverlust könnten die letzten verloren gehen. Schnelleres Aufwachen lässt eine untätige CPU 50 µs nach Arbeit Ausschau halten, kostet etwas Akku. Superblöcke lassen übersetzten Code über bedingte Sprünge hinweg laufen. Änderungen gelten beim nächsten Mac-Start.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .listRowBackground(Desk.card)
                Section("Protokoll") {
                    ShareLink(item: HengeLog.logFileURL) { Label("henge.log teilen", systemImage: "square.and.arrow.up") }
                }
                .listRowBackground(Desk.card)
            }
            .scrollContentBackground(.hidden)
            .background(Desk.page)
            .navigationTitle("Einstellungen")
        }
    }
}
