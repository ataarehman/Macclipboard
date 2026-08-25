import Foundation

enum RelativeTime {
    static func string(from date: Date, now: Date = .now) -> String {
        let interval = now.timeIntervalSince(date)
        if interval < 5 { return "Just now" }
        if interval < 60 {
            let seconds = max(1, Int(interval))
            return "\(seconds) sec ago"
        }
        if interval < 3600 {
            let minutes = max(1, Int(interval / 60))
            return minutes == 1 ? "1 min ago" : "\(minutes) min ago"
        }
        if interval < 86_400 {
            let hours = max(1, Int(interval / 3600))
            return hours == 1 ? "1 hr ago" : "\(hours) hr ago"
        }

        var calendar = Calendar.current
        calendar.timeZone = .current
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
