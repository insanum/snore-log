import Foundation

enum Format {
    static func duration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        let h = s / 3600, m = s % 3600 / 60, x = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, x) : String(format: "%d:%02d", m, x)
    }

    static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func timeWithSeconds(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().second())
    }

    static func night(_ key: Date) -> String {
        "Night of " + key.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    static func db(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded())) dB"
    }
}
