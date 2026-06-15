import Foundation

extension DateFormatter {
    static let cardDate: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df
    }()

    static let cardTime: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        return df
    }()

    static let fullDateTime: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()
}

extension TimeInterval {
    var formattedMMSS: String {
        let total = Int(self)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    var formattedHHMMSS: String {
        let total = Int(self)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
