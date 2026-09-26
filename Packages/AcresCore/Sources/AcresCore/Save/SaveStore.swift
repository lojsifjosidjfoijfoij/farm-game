import Foundation

/// Where save bytes live. Local files today; an iCloud-backed store can
/// implement the same protocol later without touching the game.
public protocol SaveStore: Sendable {
    /// The current save, or nil if there is none.
    func read() throws -> Data?
    /// The previous good save, or nil.
    func readBackup() throws -> Data?
    /// Writes a new save atomically, keeping the previous one as the backup.
    func write(_ data: Data) throws
    /// Moves unreadable saves aside (never deletes them) so a new game can start.
    func quarantine() throws
    /// Deletes the save and its backup.
    func deleteAll() throws
}

/// Stores `<slot>.json` plus `<slot>.backup.json` in a directory.
public struct FileSaveStore: SaveStore {
    public let directory: URL
    public let slot: String

    public init(directory: URL, slot: String = "farm") {
        self.directory = directory
        self.slot = slot
    }

    /// `Application Support/Saves` — backed up by iCloud Backup/Finder, not
    /// visible to the user, not purged by the system.
    public static func defaultDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        return base.appendingPathComponent("Saves", isDirectory: true)
    }

    public var mainURL: URL { directory.appendingPathComponent("\(slot).json") }
    public var backupURL: URL { directory.appendingPathComponent("\(slot).backup.json") }

    public func read() throws -> Data? { try readIfExists(mainURL) }

    public func readBackup() throws -> Data? { try readIfExists(backupURL) }

    public func write(_ data: Data) throws {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            // Rotate: current → backup. A crash mid-write can never lose both.
            if fm.fileExists(atPath: mainURL.path) {
                if fm.fileExists(atPath: backupURL.path) {
                    try fm.removeItem(at: backupURL)
                }
                try fm.copyItem(at: mainURL, to: backupURL)
            }
            // .atomic writes to a temporary file and renames it into place.
            try data.write(to: mainURL, options: [.atomic])
        } catch {
            throw SaveError.io("Write failed: \(error.localizedDescription)")
        }
    }

    public func quarantine() throws {
        let fm = FileManager.default
        let stamp = Int(Date().timeIntervalSince1970)
        for url in [mainURL, backupURL] where fm.fileExists(atPath: url.path) {
            let target = url.deletingPathExtension().appendingPathExtension("corrupt-\(stamp).json")
            do {
                try fm.moveItem(at: url, to: target)
            } catch {
                throw SaveError.io("Quarantine failed: \(error.localizedDescription)")
            }
        }
    }

    public func deleteAll() throws {
        let fm = FileManager.default
        for url in [mainURL, backupURL] where fm.fileExists(atPath: url.path) {
            do {
                try fm.removeItem(at: url)
            } catch {
                throw SaveError.io("Delete failed: \(error.localizedDescription)")
            }
        }
    }

    private func readIfExists(_ url: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw SaveError.io("Read failed: \(error.localizedDescription)")
        }
    }
}
