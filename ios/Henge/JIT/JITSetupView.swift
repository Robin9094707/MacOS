// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import UniformTypeIdentifiers

/// The JIT walkthrough: pick a way in, follow its numbered steps, end with JIT on.
///
/// Three ways in. Pairing on this iPhone (iOS 27) and a pairing file made on a
/// computer both lead to Built-in StikJIT and share the last two steps,
/// LocalDevVPN and enabling. StikDebug has its own short page. Presented from
/// onboarding, Settings › JIT, and whenever Start finds JIT not set up.
struct JITSetupFlow: View {
    enum Step: Hashable { case pairOnDevice, importFile, connect, enable, stikDebug, trollStore, jailbreak }

    @ObservedObject private var jit = JITCoordinator.shared
    @ObservedObject private var pairing = OnDevicePairing.shared
    @State private var path: [Step] = []
    @State private var importing = false
    @Environment(\.dismiss) private var dismiss

    private var device: String { OnDevicePairing.deviceKind }

    var body: some View {
        NavigationStack(path: $path) {
            choose
                .hengeDestination(for: Step.self) { step in
                    switch step {
                    case .pairOnDevice: pairOnDevice
                    case .importFile: importFile
                    case .connect: connect
                    case .enable: enable
                    case .stikDebug: stikDebug
                    case .trollStore: trollStore
                    case .jailbreak: jailbreak
                    }
                }
        }
        .tint(Theme.accent)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.propertyList, .data]) { result in
            switch result {
            case .success(let url): jit.importPairingFile(url)
            case .failure(let failure):
                HengeLog.log("jit", "pairing import failed: \(failure.localizedDescription)")
            }
        }
        .onAppear {
            jit.refreshPairingStatus()
            pairing.reset()
            // A failed enable from the Library lands on the step that can fix it.
            if jit.error != nil, jit.hasPairing, jit.resolvedMethod == .builtIn {
                path = [.enable]
            }
            HengeLog.log("ui", "JIT walkthrough opened")
        }
        // Swiping the sheet away, or a copy shown from onboarding, must not
        // leave a request to show it again behind.
        .onDisappear { jit.showSetup = false }
    }

    private func close() {
        jit.showSetup = false
        dismiss()
    }

    // MARK: Choose

    private var choose: some View {
        page(symbol: "bolt.fill", title: "JIT einschalten",
             subtitle: "Ein Mac braucht Speicher, den er beschreiben und dann ausführen kann. Das erlaubt iOS nur einem "
                     + "angehängten Debugger. Wähle, wie dein \(device) einen bekommt.") {
            VStack(spacing: 10) {
                let builtIn = HengeBuiltInJIT.unavailableReason
                way("Auf diesem \(device) koppeln", symbol: "iphone.radiowaves.left.and.right",
                    detail: builtIn ?? (!OnDevicePairing.isSupported ? "Benötigt iOS 27 oder neuer."
                        : jit.pairingSource == .onDevice ? "Auf diesem \(device) gekoppelt."
                        : "Kein Computer nötig. Koppelt in einer Minute über die Einstellungen."),
                    done: jit.pairingSource == .onDevice,
                    enabled: builtIn == nil && OnDevicePairing.isSupported) { path.append(.pairOnDevice) }
                way("Kopplungsdatei verwenden", symbol: "doc.badge.plus",
                    detail: builtIn ?? (jit.pairingSource == .imported ? "Kopplungsdatei importiert."
                        : "Eine auf einem Computer erstellte Kopplungsdatei importieren."),
                    done: jit.pairingSource == .imported,
                    enabled: builtIn == nil) { path.append(.importFile) }
                way("StikDebug verwenden", symbol: "ant",
                    detail: JITBootstrap.isStikDebugInstalled ? "StikDebug ist installiert."
                        : "JIT über die StikDebug-App einschalten.",
                    done: jit.method == .stikDebug) { path.append(.stikDebug) }
                way("TrollStore verwenden", symbol: "sparkles",
                    detail: JITBootstrap.isTrollStoreInstalled ? "TrollStore ist installiert."
                        : "Für ein über TrollStore installiertes Simplex Mac.",
                    done: jit.method == .trollStore) { path.append(.trollStore) }
                way("Jailbreak verwenden", symbol: "lock.open",
                    detail: JITBootstrap.debuggedAtLaunch ? "JIT war schon an, als Simplex Mac geöffnet wurde."
                        : JITBootstrap.isJailbroken ? "Ein Jailbreak wurde gefunden. Schalte „Allow JIT in Apps“ ein."
                        : "Dopamine kann jeder App mit einer Einstellung JIT geben.",
                    done: jit.method == .jailbreak || JITBootstrap.debuggedAtLaunch) { path.append(.jailbreak) }
            }
            if jit.hasPairing && HengeBuiltInJIT.isAvailable {
                Button { path.append(.connect) } label: {
                    Label("Mit der aktuellen Kopplung fortfahren", systemImage: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.top, 4)
            }
        } actions: {
            Button("Nicht jetzt") { close() }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textDim)
        }
    }

    private func way(_ title: String, symbol: String, detail: String, done: Bool,
                     enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.text)
                    Text(detail).font(.system(size: 13)).foregroundStyle(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: done ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: done ? 18 : 13, weight: .semibold))
                    .foregroundStyle(done ? .green : Theme.textDim.opacity(0.7))
            }
            .padding(14)
            .contentShape(Rectangle())
            .hengeCard()
        }
        .buttonStyle(CardButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }

    // MARK: Pair on this device

    private var pairedOnDevice: Bool {
        if case .paired = pairing.phase { return true }
        return false
    }

    private var pairOnDevice: some View {
        page(symbol: "iphone.radiowaves.left.and.right", title: "Auf diesem \(device) koppeln",
             subtitle: "Simplex Mac gibt sich in deinem WLAN als Computer aus, und dein \(device) koppelt sich damit "
                     + "wie mit einem Mac.") {
            VStack(alignment: .leading, spacing: 14) {
                point(1, "Schalte WLAN ein, tippe unten auf **Kopplung starten** und erlaube den Zugriff auf das lokale Netzwerk.",
                      done: pairing.phase != .idle)
                point(2, "Öffne **Einstellungen › Datenschutz & Sicherheit › Entwicklermodus**, scrolle nach unten und tippe auf "
                       + "**Mit \(OnDevicePairing.hostName) koppeln**.",
                      done: pairing.isShowingPin || pairedOnDevice)
                point(3, "Gib den Code ein, den Simplex Mac anzeigt. Er erscheint auch als Banner und Mitteilung, "
                       + "du musst also nicht zurückwechseln.",
                      done: pairedOnDevice)
                point(4, "Komm zurück zu Simplex Mac.", done: pairedOnDevice)
            }
            .padding(16).hengeCard()
            pairingStatus
        } actions: {
            switch pairing.phase {
            case .idle, .failed:
                Button { pairing.start() } label: {
                    Label("Kopplung starten", systemImage: "dot.radiowaves.left.and.right")
                }
                .buttonStyle(PrimaryButtonStyle())
            case .waiting, .pin:
                Button("Kopplung abbrechen", role: .cancel) { pairing.cancel() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textDim)
            case .paired:
                Button("Weiter") { path.append(.connect) }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    @ViewBuilder private var pairingStatus: some View {
        switch pairing.phase {
        case .idle:
            EmptyView()
        case .waiting:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ProgressView().tint(Theme.accent)
                    Text("Warte auf dein \(device) …").font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
                Button("Einstellungen öffnen") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .font(.system(size: 14, weight: .semibold))
                if pairing.backgroundLimited {
                    Text("Diese Installation kann im Hintergrund nur etwa 30 Sekunden warten, "
                       + "wechsle also sofort in die Einstellungen.")
                        .font(.system(size: 13)).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16).hengeCard()
        case .pin(let pin):
            VStack(spacing: 8) {
                Text("Gib diesen Code auf deinem \(device) ein").font(.system(size: 14))
                    .foregroundStyle(Theme.textDim)
                Text(pin).font(.system(size: 40, weight: .bold, design: .monospaced)).tracking(6)
                    .foregroundStyle(Theme.text)
                    .textSelection(.enabled)
                    .accessibilityLabel("Kopplungscode \(pin.map(String.init).joined(separator: " "))")
            }
            .frame(maxWidth: .infinity)
            .padding(18).hengeCard(high: true)
        case .paired(let name):
            outcome("Gekoppelt mit \(name)", ok: true)
        case .failed(let message):
            outcome(message, ok: false)
        }
    }

    // MARK: Import a pairing file

    private var importFile: some View {
        page(symbol: "doc.badge.plus", title: "Kopplungsdatei verwenden",
             subtitle: "Mit einer auf einem Computer erstellten Kopplungsdatei spricht Simplex Mac genauso mit diesem \(device).") {
            VStack(alignment: .leading, spacing: 14) {
                point(1, "Erstelle auf einem Computer die Kopplungsdatei dieses \(device) mit der "
                       + "[StikDebug-Anleitung](https://github.com/StikDebug/StikDebug-Guide/blob/main/pairing_file.md).",
                      done: jit.pairingSource == .imported)
                point(2, "Sichere sie in „Dateien“ oder schick sie per AirDrop an dieses \(device).",
                      done: jit.pairingSource == .imported)
                point(3, "Tippe auf **Kopplungsdatei wählen** und wähle sie aus.", done: jit.pairingSource == .imported)
            }
            .padding(16).hengeCard()
            Label("Die Kopplungsdatei bleibt im Dokumente-Ordner von Simplex Mac und geht nur an den eigenen Helfer der App.",
                  systemImage: "lock.fill")
                .font(.system(size: 13)).foregroundStyle(Theme.textDim)
            if let error = jit.error { outcome(error, ok: false) }
        } actions: {
            if jit.pairingSource == .imported {
                Button("Weiter") { path.append(.connect) }.buttonStyle(PrimaryButtonStyle())
                Button("Andere Datei wählen") { importing = true }
                    .font(.system(size: 15, weight: .medium))
            } else {
                Button { importing = true } label: { Label("Kopplungsdatei wählen", systemImage: "folder") }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    // MARK: LocalDevVPN

    private var connect: some View {
        page(symbol: "network.badge.shield.half.filled", title: "LocalDevVPN verbinden",
             subtitle: "Der Helfer von Simplex Mac erreicht den Debug-Dienst dieses \(device) über ein lokales VPN. "
                     + "Nichts verlässt dein \(device).") {
            VStack(alignment: .leading, spacing: 14) {
                point(1, "Installiere [LocalDevVPN](\(LocalDevVPN.appStore.absoluteString)) aus dem App Store.",
                      done: LocalDevVPN.isInstalled)
                point(2, "Tippe auf **LocalDevVPN verbinden**. Das schaltet das VPN ein und kehrt direkt zu Simplex Mac zurück.")
                point(3, "Lass es immer verbunden, wenn du JIT einschaltest.")
            }
            .padding(16).hengeCard()
        } actions: {
            Button(LocalDevVPN.actionTitle) { LocalDevVPN.open() }
                .buttonStyle(PrimaryButtonStyle())
            Button("Es ist verbunden") { path.append(.enable) }
                .font(.system(size: 15, weight: .medium))
        }
    }

    // MARK: Enable

    private var attached: Bool { jit.attachGeneration > 0 || JITBootstrap.debuggedFlag }

    private var enable: some View {
        page(symbol: "bolt.badge.checkmark", title: "JIT einschalten",
             subtitle: "Die erste Prüfung lädt Apples Developer Disk Image und bindet es ein, "
                     + "das kann eine Minute dauern.") {
            VStack(alignment: .leading, spacing: 14) {
                point(1, "Tippe auf **Einrichtung prüfen**. Simplex Mac prüft LocalDevVPN und bereitet das Developer Disk Image vor.",
                      done: jit.prepared || attached)
                point(2, "Tippe auf **JIT einschalten**. Der Helfer hängt sich an, und ein Mac kann starten.", done: attached)
            }
            .padding(16).hengeCard()

            if jit.busy {
                HStack(spacing: 11) {
                    ProgressView().tint(Theme.accent)
                    Text(jit.status ?? "Arbeite …").font(.system(size: 14)).foregroundStyle(Theme.text)
                    Spacer(minLength: 0)
                }
                .padding(16).hengeCard(high: true)
            } else if attached {
                outcome("JIT ist an. Ein Mac kann starten.", ok: true)
            } else if let error = jit.error {
                VStack(alignment: .leading, spacing: 10) {
                    outcome(error, ok: false)
                    if jit.advice?.actions.contains(.pairAgain) == true {
                        Button(OnDevicePairing.isSupported ? "Erneut koppeln" : "Neue Kopplungsdatei importieren") {
                            path = [OnDevicePairing.isSupported ? .pairOnDevice : .importFile]
                        }
                        .font(.system(size: 14, weight: .semibold))
                    }
                    if jit.advice?.actions.contains(.connectLocalDevVPN) == true {
                        Button(LocalDevVPN.actionTitle) { LocalDevVPN.open() }
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            } else if let status = jit.status {
                outcome(status, ok: true)
            }

            if !attached {
                Button("Developer Disk Image zurücksetzen", role: .destructive) { jit.resetDDI() }
                    .font(.system(size: 13, weight: .medium))
                    .disabled(jit.busy)
                    .padding(.top, 4)
            }
        } actions: {
            if attached {
                Button("Fertig") { close() }.buttonStyle(PrimaryButtonStyle())
            } else if jit.prepared {
                Button { jit.enableBuiltIn() } label: { Label("JIT einschalten", systemImage: "bolt.fill") }
                    .buttonStyle(PrimaryButtonStyle(enabled: !jit.busy))
                    .disabled(jit.busy)
            } else {
                Button("Einrichtung prüfen") { jit.prepareBuiltIn() }
                    .buttonStyle(PrimaryButtonStyle(enabled: !jit.busy))
                    .disabled(jit.busy)
            }
        }
    }

    // MARK: StikDebug

    private var stikDebug: some View {
        page(symbol: "ant", title: "StikDebug verwenden",
             subtitle: "StikDebug ist eine eigene App, die sich an Simplex Mac anhängt. Simplex Mac schickt ihr das JIT-Skript "
                     + "selbst, in StikDebug muss also nichts eingerichtet werden.") {
            VStack(alignment: .leading, spacing: 14) {
                point(1, "Installiere [StikDebug](https://github.com/StikDebug/StikDebug/releases/latest).",
                      done: JITBootstrap.isStikDebugInstalled)
                point(2, "Importiere die Kopplungsdatei dieses \(device) in StikDebug.")
                point(3, "Installiere und verbinde [LocalDevVPN](\(LocalDevVPN.appStore.absoluteString)).")
                point(4, "Bei jedem Mac-Start öffnet Simplex Mac StikDebug, das sich anhängt und zurückkehrt.")
            }
            .padding(16).hengeCard()
        } actions: {
            Button("StikDebug verwenden") {
                jit.method = .stikDebug
                HengeLog.log("ui", "JIT method set to StikDebug")
                close()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: TrollStore

    private var trollStore: some View {
        page(symbol: "sparkles", title: "TrollStore verwenden",
             subtitle: "TrollStore kann JIT für Apps einschalten, die es installiert hat – ohne Kopplungsdatei, "
                     + "VPN oder Computer.") {
            VStack(alignment: .leading, spacing: 14) {
                point(1, "Installiere Henge.ipa über TrollStore, auf einer iOS-Version, die TrollStore unterstützt. Sie enthält die "
                       + "Berechtigungen, die TrollStore behält, also funktioniert dieselbe Datei dort und in einem Sideloader.",
                      done: JITBootstrap.isInstalledWithTrollStore)
                point(2, "Schalte in den TrollStore-Einstellungen „URL Scheme“ ein. Ohne das ignoriert TrollStore JIT-Anfragen.")
                point(3, "Bei jedem Mac-Start bittet Simplex Mac TrollStore, JIT einzuschalten. TrollStore öffnet die App, "
                       + "hängt sich kurz an und lässt wieder los. Danach darf sie selbst geschriebenen Code ausführen.")
            }
            .padding(16).hengeCard()
            if !JITBootstrap.isTrollStoreInstalled {
                Label("TrollStore wurde auf diesem \(device) nicht gefunden. Es lässt sich auf iOS 14.0 bis 17.0 installieren.", systemImage: "info.circle")
                    .font(.system(size: 13)).foregroundStyle(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } actions: {
            Button("TrollStore verwenden") {
                jit.method = .trollStore
                HengeLog.log("ui", "JIT method set to TrollStore")
                close()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: Jailbreak

    private var jailbreak: some View {
        page(symbol: "lock.open", title: "Jailbreak verwenden",
             subtitle: "Auf einem mit Dopamine gejailbreakten Gerät ist JIT eine Einstellung: Der Jailbreak markiert jede App beim Öffnen "
                     + "als debuggt, und eine debuggte App darf selbst geschriebenen Code ausführen. Mehr braucht Simplex Mac nicht.") {
            VStack(alignment: .leading, spacing: 14) {
                point(1, "Öffne Dopamine und gehe in die Einstellungen.", done: JITBootstrap.isJailbroken)
                point(2, "Schalte „Allow JIT in Apps“ ein.")
                point(3, "Schließe Simplex Mac ganz und öffne es erneut. Die Einstellung gilt für Apps beim Start.",
                      done: JITBootstrap.debuggedAtLaunch)
            }
            .padding(16).hengeCard()
            if JITBootstrap.debuggedAtLaunch {
                Label("Simplex Mac wurde beim Öffnen als debuggt markiert, JIT ist also an.", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13)).foregroundStyle(.green)
            } else if !JITBootstrap.isJailbroken {
                Label("Auf diesem \(device) wurde kein Jailbreak gefunden.", systemImage: "info.circle")
                    .font(.system(size: 13)).foregroundStyle(Theme.textDim)
            }
        } actions: {
            Button("Jailbreak verwenden") {
                jit.method = .jailbreak
                HengeLog.log("ui", "JIT method set to jailbreak")
                close()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: Pieces

    private func page<Content: View, Actions: View>(
        symbol: String, title: String, subtitle: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions) -> some View {
        ZStack {
            Theme.backdrop
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: symbol)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 56, height: 56)
                        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text(title).font(.system(size: 28, weight: .semibold)).foregroundStyle(Theme.text)
                    Text(subtitle).font(.system(size: 15)).foregroundStyle(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                    content()
                }
                .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 12) { actions() }
                .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 16)
                .background(Theme.backdrop)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Schließen") { close() }
            }
        }
    }

    private func point(_ number: Int, _ text: String, done: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(done ? Color.green.opacity(0.18) : Theme.accentSoft)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.green)
                } else {
                    Text("\(number)").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.accent)
                }
            }
            .frame(width: 26, height: 26)
            Text(.init(text))
                .font(.system(size: 15))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func outcome(_ text: String, ok: Bool) -> some View {
        Label(text, systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(ok ? .green : .red)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14).hengeCard()
    }
}
