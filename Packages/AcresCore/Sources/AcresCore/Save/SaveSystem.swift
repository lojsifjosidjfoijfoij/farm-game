import Foundation

/// Result of trying to load the farm.
public enum LoadOutcome: Equatable, Sendable {
    /// No save exists: start a new game.
    case noSave
    /// Loaded successfully. `fromBackup` means the main file was damaged and
    /// the previous save was used instead.
    case loaded(SaveFile, fromBackup: Bool)
    /// Could not load. The caller must decide what to do; see `SaveError`.
    case failed(SaveError)
}

/// Encodes, versions, migrates and persists save files.
public struct SaveSystem: Sendable {
    public let store: any SaveStore
    public let migrator: SaveMigrator
    public let deviceID: String

    public init(store: any SaveStore, migrator: SaveMigrator = .standard, deviceID: String) {
        self.store = store
        self.migrator = migrator
        self.deviceID = deviceID
    }

    /// Loads the main save, falling back to the backup if the main file is
    /// unreadable. A save from a *newer* game version is never replaced by the
    /// backup and never overwritten — the player must update the app.
    public func load() -> LoadOutcome {
        let mainData: Data?
        do {
            mainData = try store.read()
        } catch let error as SaveError {
            return .failed(error)
        } catch {
            return .failed(.io(error.localizedDescription))
        }

        if let mainData {
            switch decode(mainData) {
            case .success(let file):
                return .loaded(file, fromBackup: false)
            case .failure(let error):
                if case .newerVersion = error { return .failed(error) }
                // Fall through to the backup.
                if let backup = try? store.readBackup(), case .success(let file) = decode(backup) {
                    return .loaded(file, fromBackup: true)
                }
                return .failed(error)
            }
        }

        // No main file. A lone backup can exist if a write was interrupted
        // at exactly the wrong moment.
        if let backup = try? store.readBackup(), case .success(let file) = decode(backup) {
            return .loaded(file, fromBackup: true)
        }
        return .noSave
    }

    /// Decodes (and migrates) raw save bytes.
    public func decode(_ data: Data) -> Result<SaveFile, SaveError> {
        do {
            let current = try migrator.migrate(data)
            let file = try SaveCoding.makeDecoder().decode(SaveFile.self, from: current)
            return .success(file)
        } catch let error as SaveError {
            return .failure(error)
        } catch {
            return .failure(.corrupt(String(describing: error)))
        }
    }

    /// Builds the next save file from the current one (or a fresh lineage).
    public func makeFile(
        state: GameState,
        presentation: PresentationState,
        previous: SaveFile?,
        now: Date
    ) -> SaveFile {
        SaveFile(
            version: SaveFile.currentVersion,
            revision: (previous?.revision ?? 0) + 1,
            deviceID: deviceID,
            createdAt: previous?.createdAt ?? now,
            savedAt: now,
            state: state,
            presentation: presentation
        )
    }

    /// Writes a save file.
    public func write(_ file: SaveFile) throws {
        let data: Data
        do {
            data = try SaveCoding.makeEncoder().encode(file)
        } catch {
            throw SaveError.corrupt("Encoding failed: \(error)")
        }
        try store.write(data)
    }
}
