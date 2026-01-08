import Foundation

/// Represents a time-based blocking schedule
struct BlockSchedule: Codable, Identifiable {
    let id: UUID
    var name: String
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var activeDays: Set<Int>  // 1=Sunday, 2=Monday... 7=Saturday (Calendar weekday)
    var excludedAppTokenHashes: Set<String>  // Token hashes to exclude from blocking
    var isEnabled: Bool
    var createdAt: Date

    init(
        name: String = "New Schedule",
        startHour: Int = 22,
        startMinute: Int = 0,
        endHour: Int = 7,
        endMinute: Int = 0,
        activeDays: Set<Int> = Set(1...7),  // All days by default
        excludedAppTokenHashes: Set<String> = [],
        isEnabled: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.activeDays = activeDays
        self.excludedAppTokenHashes = excludedAppTokenHashes
        self.isEnabled = isEnabled
        self.createdAt = Date()
    }

    /// Formatted start time string (e.g., "10:00 PM")
    var formattedStartTime: String {
        formatTime(hour: startHour, minute: startMinute)
    }

    /// Formatted end time string (e.g., "7:00 AM")
    var formattedEndTime: String {
        formatTime(hour: endHour, minute: endMinute)
    }

    /// Time range display string
    var timeRangeString: String {
        "\(formattedStartTime) - \(formattedEndTime)"
    }

    /// Active days as abbreviated string (e.g., "Mon Tue Wed")
    var activeDaysString: String {
        let dayAbbreviations = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let sortedDays = activeDays.sorted()
        return sortedDays.map { dayAbbreviations[$0] }.joined(separator: " ")
    }

    /// Check if schedule spans overnight (e.g., 10 PM to 7 AM)
    var spansOvernight: Bool {
        startHour > endHour || (startHour == endHour && startMinute > endMinute)
    }

    /// Check if the current time falls within this schedule
    func isActiveNow() -> Bool {
        guard isEnabled else { return false }

        let calendar = Calendar.current
        let now = Date()
        let currentWeekday = calendar.component(.weekday, from: now)

        // Check if today is an active day
        guard activeDays.contains(currentWeekday) else { return false }

        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTimeMinutes = currentHour * 60 + currentMinute
        let startTimeMinutes = startHour * 60 + startMinute
        let endTimeMinutes = endHour * 60 + endMinute

        if spansOvernight {
            // Schedule crosses midnight (e.g., 22:00 to 07:00)
            return currentTimeMinutes >= startTimeMinutes || currentTimeMinutes < endTimeMinutes
        } else {
            // Schedule within same day (e.g., 09:00 to 17:00)
            return currentTimeMinutes >= startTimeMinutes && currentTimeMinutes < endTimeMinutes
        }
    }

    /// Check if an app token hash should be excluded from this schedule
    func isAppExcluded(_ tokenHash: String) -> Bool {
        excludedAppTokenHashes.contains(tokenHash)
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):\(String(format: "%02d", minute))"
    }
}

// MARK: - Day of Week Helper
extension BlockSchedule {
    static let weekdaySymbols: [(id: Int, short: String, full: String)] = [
        (1, "S", "Sunday"),
        (2, "M", "Monday"),
        (3, "T", "Tuesday"),
        (4, "W", "Wednesday"),
        (5, "T", "Thursday"),
        (6, "F", "Friday"),
        (7, "S", "Saturday")
    ]

    /// Available break duration options in minutes
    static let breakDurationOptions: [(minutes: Int, label: String)] = [
        (1, "1 min"),
        (3, "3 min"),
        (5, "5 min"),
        (10, "10 min"),
        (15, "15 min"),
        (30, "30 min"),
        (60, "1 hour")
    ]
}
