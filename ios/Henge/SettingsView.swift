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
            return "Tap to click once. Tap then hold to begin dragging. Quickly tap with two fingers to right-click."
        }
        switch volumeMode {
        case .delayHold:
            return "Delay hold waits to see if you're holding or just clicking the volume button, which results in all clicks being ~0.5s long."
        case .tapThenDrag:
            return "Tap then drag waits to see if you're holding or just clicking the volume button, but it unconditionally sends a single click regardless of whether you tap or hold, which results in shorter clicks at the cost of sending a click before holding."
        case .intercept:
            return "Activates the camera in order to intercept volume keys properly. This causes the volume keys to behave in the same way a mouse's buttons do, but it causes higher temperatures, as the camera is always on."
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("JIT") {
                    LabeledContent("Status", value: JITBootstrap.ready ? "On" : "Off")
                    Picker("Method", selection: $jit.method) {
                        ForEach(JITMethod.allCases) { Text($0.title).tag($0) }
                    }
                    Text(jit.method == .automatic ? jit.automaticDescription : "Henge uses \(jit.method.title).")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Set up JIT") { jit.showSetup = true }
                    Toggle("Turn on JIT when Henge opens", isOn: $jitAtLaunch)
                    if jitAtLaunch {
                        Text("Henge connects LocalDevVPN first when it is off, and comes back.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    LabeledContent("Code region", value: "\(JITBootstrap.jitBytes >> 20) MB, claimed once per launch")
                }
                .listRowBackground(Desk.card)
                Section("Memory") {
                    LabeledContent("Extra memory", value: Entitlements.increasedMemory ? "On" : "Off")
                    LabeledContent("Henge's limit", value: ByteText.string(UInt64(Entitlements.memoryLimitAtLaunch)))
                    LabeledContent("Free for Henge", value: ByteText.string(UInt64(henge_available_memory())))
                    Text(Entitlements.increasedMemory
                         ? "A Mac's memory is kept out of this limit once JIT is on. If iOS refuses that, it uses free storage instead."
                         : "This install isn't signed with the increased memory limit entitlement. Reinstall Henge with a certificate that has it. Export your Mac first if the reinstall replaces the app's data.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .listRowBackground(Desk.card)
                Group {
                    Section(Device.isPad ? "Mouse and Trackpad" : "Mouse") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pointer speed")
                            Slider(value: $mouseSpeed, in: 0.5...3)
                        }
                        Toggle("Reverse scrolling", isOn: $reverseScrolling)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scroll speed")
                            Slider(value: $scrollSpeed, in: 0.1...1.5)
                        }
                        Toggle("Swap physical right and middle buttons", isOn: $swapMouseButtons)
                        Text("Only enable this if your physical mouse's right and middle buttons are reversed in the Mac. Touch controls stay unchanged. Restart the Mac session to apply.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Toggle("Side buttons go back and forward", isOn: $sideButtonsNavigate)
                        Text(Device.isPad
                             ? "A Magic Keyboard, or a USB or Bluetooth mouse, moves the Mac's pointer. Pointer speed changes apply the next time a Mac starts; scroll speed changes apply immediately."
                             : "iPhone uses a mouse through AssistiveTouch: turn it on in Settings › Accessibility › Touch › AssistiveTouch, and pair a Bluetooth mouse under Devices there (a USB mouse just plugs in). Henge takes the mouse's own movement, buttons and wheel, and ignores the touches AssistiveTouch makes for its clicks, so each click lands once. To hide iPhone's round cursor over the Mac, set Pointer Style › Auto-Hide to a short time. Pointer speed changes apply the next time a Mac starts; scroll speed changes apply immediately.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .listRowBackground(Desk.card)
                }
                Section("Keyboard") {
                    Toggle("Swap Command and Option", isOn: $swapCommandOption)
                    Toggle("Caps Lock is Control", isOn: $capsLockAsControl)
                    Text("A USB or Bluetooth keyboard types straight into the Mac, every key and modifier. On a PC keyboard, swap Command and Option so the key beside the space bar is Command, as on a Mac. Changes apply the next time a Mac starts. \(Device.name) keeps a few shortcuts for itself, such as ⌘-Tab, ⌘-Space and ⌘-H.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .listRowBackground(Desk.card)
                if !Device.isPad {
                    Section("Trackpad") {
                        Picker("Input mode", selection: $inputMode) {
                            Text("Touchscreen").tag(VolumeClicks.InputMode.touchscreen)
                            Text("Volume buttons").tag(VolumeClicks.InputMode.volumeButtons)
                        }
                        .pickerStyle(.menu)
                        if inputMode == .volumeButtons {
                            Picker("Button mode", selection: $volumeMode) {
                                Text("Delay hold").tag(VolumeClicks.Mode.delayHold)
                                Text("Tap then drag").tag(VolumeClicks.Mode.tapThenDrag)
                                Text("Camera intercept").tag(VolumeClicks.Mode.intercept)
                            }
                            .pickerStyle(.menu)
                            Toggle("Swap buttons", isOn: $swapButtons)
                        }
                        Text("Henge is able to emulate a Magic Trackpad, allowing you to perform native macOS gestures using your device's touchscreen.\n\n\(inputDescription)")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .listRowBackground(Desk.card)
                }
                Section("Performance") {
                    Picker("Mac refresh rate", selection: $refreshRate) {
                        Text("30 Hz").tag(30)
                        Text("60 Hz").tag(60)
                        Text("120 Hz").tag(120)
                    }
                    .pickerStyle(.segmented)
                    Toggle("Faster disk writes", isOn: $fastFlush)
                    Toggle("Quicker wake from idle", isOn: $wfiSpin)
                    Toggle("Superblocks (experimental)", isOn: $superblocks)
                    Picker("Code cache", selection: $codeCacheMB) {
                        Text("1 GB").tag(1024)
                        Text("1.5 GB").tag(1536)
                    }
                    Text("A bigger code cache empties less often and takes more memory; Henge picks 1.5 GB where there is room for it. Applies the next time Henge opens. If JIT stops turning on, choose 1 GB.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("macOS draws a frame for every refresh: 30 Hz leaves the most of the emulated CPU to apps, at the cost of choppier animation; 60 Hz is smoother. Faster disk writes order them without waiting for a full sync; a sudden power loss could lose the last ones. Quicker wake keeps an idle CPU watching for work for 50 µs, at some battery cost. Superblocks let translated code run past conditional branches. Changes apply the next time a Mac starts.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .listRowBackground(Desk.card)
                Section("Log") {
                    ShareLink(item: HengeLog.logFileURL) { Label("Share henge.log", systemImage: "square.and.arrow.up") }
                }
                .listRowBackground(Desk.card)
            }
            .scrollContentBackground(.hidden)
            .background(Desk.page)
            .navigationTitle("Settings")
        }
    }
}
