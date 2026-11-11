import Foundation

/// Engine settings, without a rebuild. Defaults below, then the Performance settings,
/// then Documents/henge-env.txt (KEY=VALUE per line, # comments; {Documents} in a value is that folder) overrides them all.
/// Applied at launch and again before each Mac starts, so changes need no relaunch.
enum EngineTuning {
    static let refreshKey = "henge.perf.hz"
    static let superblocksKey = "henge.perf.superblocks"
    static let wfiSpinKey = "henge.perf.wfiSpin"
    static let fastFlushKey = "henge.perf.fastFlush"
    /// The Mac's CPUs at the highest thread priority (iOS keeps them on performance cores) and idle CPUs that wake
    /// at once. On by default on the newest chips (iPhone 17 Pro and later, M4 iPads), which have the cores and battery for it.
    static let maxPerformanceKey = "henge.perf.max"

    static var newestChip: Bool {
        let model = HengeLog.deviceModel
        guard let major = Int(model.drop { !$0.isNumber }.prefix { $0.isNumber }) else { return false }
        if model.hasPrefix("iPhone") { return major >= 18 }
        if model.hasPrefix("iPad") { return major >= 16 }
        return false
    }

    static var maxPerformance: Bool {
        let d = UserDefaults.standard
        return d.object(forKey: maxPerformanceKey) == nil ? newestChip : d.bool(forKey: maxPerformanceKey)
    }

    static let defaults: [String: String] = [
        // 60, not 120: every frame macOS draws is emulated and replayed, so 120 Hz
        // halves the CPU left for apps for animation few will notice.
        "HV_HZ": "60",         // the refresh rate macOS is told its display has
        "HV_WFI_SPIN": "0",    // microseconds an idle CPU watches for work before sleeping
        "HV_FLUSH": "2",       // disk flush: F_BARRIERFSYNC, ordered but without a full fsync
        "HV_STATS": "10",      // seconds between engine stats lines in the log; 0 = off
    ]

    static func apply() {
        var env = defaults
        let d = UserDefaults.standard
        if [30, 120].contains(d.integer(forKey: refreshKey)) { env["HV_HZ"] = String(d.integer(forKey: refreshKey)) }
        if d.bool(forKey: superblocksKey) { env["HV_SUPERBLOCKS"] = "1" } else { unsetenv("HV_SUPERBLOCKS") }
        if d.bool(forKey: wfiSpinKey) { env["HV_WFI_SPIN"] = "50" }
        if d.object(forKey: fastFlushKey) as? Bool == false { env["HV_FLUSH"] = "0" }
        if maxPerformance {
            env["HV_QOS"] = "ui"        // user-interactive: what iOS schedules first, on performance cores (host/vm.c)
            env["HV_WFI_SPIN"] = "50"   // a CPU that just went idle catches the next interrupt without a wake-up
        } else {
            unsetenv("HV_QOS")          // back to the engine's own default if it was turned off this launch
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // GPU command trace: on while Documents/trace-on exists (it is checked every frame, so it can be toggled live).
        env["HV_PVG_TRACE_FILE"] = docs.appendingPathComponent("trace-on").path
        let url = docs.appendingPathComponent("henge-env.txt")
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            for raw in text.split(whereSeparator: \.isNewline) {
                let line = raw.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init)?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                guard let eq = line.firstIndex(of: "="), eq != line.startIndex else { continue }
                // {Documents} stands for this folder: its absolute path changes when Henge is reinstalled.
                env[String(line[..<eq]).trimmingCharacters(in: .whitespaces)] = String(line[line.index(after: eq)...])
                    .trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "{Documents}", with: docs.path)
            }
        }
        for (k, v) in env.sorted(by: { $0.key < $1.key }) {
            setenv(k, v, 1)
            HengeLog.log("tuning", "\(k)=\(v)")
        }
    }
}
