import Foundation
import Darwin

/// A Mac's saved starting point ("Werkszustand"), to go back to without installing macOS again.
///
/// The disk and the Mac's NVRAM (auxiliary.bin) are cloned on APFS: a clone shares every block with the file it
/// came from, so saving takes a moment and no space at first. Only what the Mac changes afterwards is stored twice,
/// at most the size of the Mac's disk. Going back clones the saved files over the Mac's own: whatever was set up,
/// installed or saved on the Mac since is gone, and macOS starts as it was when the state was saved.
///
/// It lives in its own folder inside the Mac's directory, which nothing else in the app reads, so Macs, exports and
/// the original Henge app don't notice it (deleting the Mac deletes it too).
enum MacSnapshot {
    static let folderName = "Werkszustand"

    static func directory(for mac: VirtualMac) -> URL { mac.directory.appendingPathComponent(folderName, isDirectory: true) }
    private static func savedDisk(_ mac: VirtualMac) -> URL { directory(for: mac).appendingPathComponent("disk.img") }
    private static func savedAux(_ mac: VirtualMac) -> URL { directory(for: mac).appendingPathComponent("auxiliary.bin") }

    static func exists(for mac: VirtualMac) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: savedDisk(mac).path) && fm.fileExists(atPath: savedAux(mac).path)
    }

    /// When the state was saved.
    static func date(for mac: VirtualMac) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: savedDisk(mac).path))?[.modificationDate] as? Date
    }

    /// Only while no Mac is running in this launch: a running Mac writes to its disk all the time.
    static var macRunning: Bool {
        let state = henge_vm_state()
        return state == 1 || state == 3
    }

    /// Saves the Mac's current disk and NVRAM as its starting point, replacing one saved before.
    static func save(_ mac: VirtualMac) async throws {
        guard !macRunning else { throw failure("Schalte den Mac zuerst aus.") }
        let disk = mac.disk, aux = mac.aux, folder = directory(for: mac)
        let staging = mac.directory.appendingPathComponent(folderName + ".neu", isDirectory: true)
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            try? fm.removeItem(at: staging)
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)
            do {
                try MacSnapshot.clone(disk, to: staging.appendingPathComponent("disk.img"))
                try MacSnapshot.clone(aux, to: staging.appendingPathComponent("auxiliary.bin"))
                // Swapped in whole, so a cut-short save never leaves half a starting point.
                try? fm.removeItem(at: folder)
                try fm.moveItem(at: staging, to: folder)
            } catch {
                try? fm.removeItem(at: staging)
                throw error
            }
        }.value
        HengeLog.log("snapshot", "\(mac.name): starting point saved")
    }

    /// Puts the Mac back to its saved starting point. The saved state stays, so this can be done again.
    static func restore(_ mac: VirtualMac) async throws {
        guard !macRunning else { throw failure("Schalte den Mac zuerst aus.") }
        guard exists(for: mac) else { throw failure("Für diesen Mac ist kein Werkszustand gesichert.") }
        let fromDisk = savedDisk(mac), fromAux = savedAux(mac)
        let disk = mac.disk, aux = mac.aux, dir = mac.directory
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let newDisk = dir.appendingPathComponent("disk.img.zurueck")
            let newAux = dir.appendingPathComponent("auxiliary.bin.zurueck")
            try? fm.removeItem(at: newDisk)
            try? fm.removeItem(at: newAux)
            do {
                try MacSnapshot.clone(fromDisk, to: newDisk)
                try MacSnapshot.clone(fromAux, to: newAux)
                // rename(2) replaces the old file in one step: the Mac is never left without a disk.
                try MacSnapshot.replace(disk, with: newDisk)
                try MacSnapshot.replace(aux, with: newAux)
            } catch {
                try? fm.removeItem(at: newDisk)
                try? fm.removeItem(at: newAux)
                throw error
            }
            try? fm.removeItem(at: dir.appendingPathComponent("ram.tmp"))
        }.value
        HengeLog.log("snapshot", "\(mac.name): reset to its starting point")
    }

    static func delete(_ mac: VirtualMac) {
        try? FileManager.default.removeItem(at: directory(for: mac))
        HengeLog.log("snapshot", "\(mac.name): starting point deleted")
    }

    /// A copy-on-write clone, or an error: never a slow full copy of tens of gigabytes behind the user's back.
    private static func clone(_ from: URL, to: URL) throws {
        flush(from)
        // COPYFILE_CLONE_FORCE: clone, or fail instead of falling back to copying.
        let cloneForce = copyfile_flags_t(1 << 25)
        guard copyfile(from.path, to.path, nil, cloneForce) == 0 else {
            let code = errno
            throw failure("Konnte \(from.lastPathComponent) nicht klonen (\(String(cString: strerror(code)))).")
        }
    }

    /// What the engine wrote may still sit in the file cache: write it out before cloning.
    private static func flush(_ url: URL) {
        let fd = open(url.path, O_RDONLY)
        guard fd >= 0 else { return }
        if fcntl(fd, F_FULLFSYNC) != 0 { fsync(fd) }
        close(fd)
    }

    private static func replace(_ target: URL, with source: URL) throws {
        guard rename(source.path, target.path) == 0 else {
            let code = errno
            throw failure("Konnte \(target.lastPathComponent) nicht ersetzen (\(String(cString: strerror(code)))).")
        }
    }

    private static func failure(_ text: String) -> NSError {
        NSError(domain: "SimplexMac", code: 30, userInfo: [NSLocalizedDescriptionKey: text])
    }
}
