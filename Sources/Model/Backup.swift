import FossifyCommons
import Foundation

/// Automatic backups (AutomaticBackupReceiver). Android schedules an alarm at 6 AM;
/// iOS has no reliable alarm for sideloaded apps, so a backup is written the first
/// time the app runs after the scheduled time has passed.
@MainActor
enum BackupScheduler {
    static var folder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Backups", isDirectory: true)
    }

    /// getPreviousAutoBackupTime(): today's 6 AM if already passed, else yesterday's.
    static func previousBackupTime(now: Date = Date()) -> Date {
        let cal = Calendar.current
        let six = cal.date(bySettingHour: 6, minute: 0, second: 0, of: now)!
        return now >= six ? six : cal.date(byAdding: .day, value: -1, to: six)!
    }

    static func runIfDue(_ store: ContactsStore) {
        let config = Config.shared
        guard config.autoBackup, store.access == .granted else { return }
        let due = previousBackupTime()
        guard config.lastAutoBackupTime < due.timeIntervalSince1970 else { return }
        do {
            try backup(store)
            config.lastAutoBackupTime = Date().timeIntervalSince1970
        } catch {
            store.toast = "Automatic backup failed: \(error.localizedDescription)"
        }
    }

    static func backup(_ store: ContactsStore) throws {
        let config = Config.shared
        let ignored = Set(store.sources.map(\.id)).subtracting(config.autoBackupContactSources.isEmpty
            ? Set(store.sources.map(\.id)) : config.autoBackupContactSources)
        let (data, _) = try store.vcard(sources: ignored)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(filename(config.autoBackupFilename) + ".vcf")
        try data.write(to: url, options: .atomic)
    }

    /// Expands Fossify's %Y %M %D %h %m %s filename pattern.
    static func filename(_ pattern: String, date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        func two(_ v: Int?) -> String { String(format: "%02d", v ?? 0) }
        return pattern
            .replacingOccurrences(of: "%Y", with: String(c.year ?? 0))
            .replacingOccurrences(of: "%M", with: two(c.month))
            .replacingOccurrences(of: "%D", with: two(c.day))
            .replacingOccurrences(of: "%h", with: two(c.hour))
            .replacingOccurrences(of: "%m", with: two(c.minute))
            .replacingOccurrences(of: "%s", with: two(c.second))
    }
}
