//
//  CertificateExpiryHelper.swift
//  EduVPN
//

import Foundation

class SessionExpiryHelper {

    enum SessionStatus: Equatable {
        case validFor(timeInterval: TimeInterval, canRenew: Bool)
        case expired
    }

    let browserSessionValidity: TimeInterval = 60 * 32 // 32 minutes

    let expiresAt: Date
    let authenticatedAt: Date?
    let canRenewAfter: Date?

    private let handler: (SessionStatus) -> Void

    fileprivate var refreshTimes: [Date]

    private var timer: Timer? {
        didSet(oldValue) {
            oldValue?.invalidate()
        }
    }

    init(expiresAt: Date, authenticatedAt: Date?, handler: @escaping (SessionStatus) -> Void) {
        self.expiresAt = expiresAt
        self.authenticatedAt = authenticatedAt
        self.canRenewAfter = authenticatedAt?.addingTimeInterval(browserSessionValidity)
        self.handler = handler
        self.refreshTimes = Self.computeRefreshTimes(from: Date(), to: expiresAt, canRenewAfter: canRenewAfter)
        self.scheduleNextRefresh()
    }

    deinit {
        self.timer = nil // invalidate
    }
}

private extension SessionExpiryHelper {
    struct NumberOfSeconds {
        static let inADay: Int = 60 * 60 * 24
        static let inAnHour: Int = 60 * 60
        static let inAMinute: Int = 60
        static let one: Int = 1

        static let tillWhichToShowDaysHours: Int = inADay
        static let tillWhichToShowHoursMinutes: Int = inAnHour
        static let tillWhichToShowMinutesOnly: Int = inAMinute * 2
        static let tillWhichToShowMinutesSeconds: Int = 0
    }

    static let browserSessionValidity: TimeInterval = 60 * 32 // 32 minutes

    static func computeRefreshTimes(from startDate: Date,
                                    to endDate: Date,
                                    canRenewAfter: Date?) -> [Date] {
        let endingTimeInterval = endDate.timeIntervalSince(startDate)
        let canRenewTimeInterval = canRenewAfter?.timeIntervalSince(startDate)

        var refreshTimes: [Date] = []
        var currentTimeInterval: TimeInterval = 0
        var isAddedRenewalTime = false

        while currentTimeInterval < endingTimeInterval {

            var canRenew = true
            if let canRenewTimeInterval = canRenewTimeInterval {
                canRenew = currentTimeInterval >= canRenewTimeInterval
                if currentTimeInterval > canRenewTimeInterval && !isAddedRenewalTime {
                    refreshTimes.append(Date(timeInterval: canRenewTimeInterval, since: startDate))
                }
                if canRenew {
                    isAddedRenewalTime = true
                }
            }

            refreshTimes.append(Date(timeInterval: currentTimeInterval, since: startDate))

            let secondsRemaining = Int(endingTimeInterval - currentTimeInterval)
            if secondsRemaining > NumberOfSeconds.tillWhichToShowDaysHours {
                let remainder = secondsRemaining % NumberOfSeconds.inAnHour
                currentTimeInterval += TimeInterval(remainder > 0 ? remainder : NumberOfSeconds.inAnHour)
            } else if secondsRemaining > NumberOfSeconds.tillWhichToShowMinutesOnly {
                let remainder = secondsRemaining % NumberOfSeconds.inAMinute
                currentTimeInterval += TimeInterval(remainder > 0 ? remainder : NumberOfSeconds.inAMinute)
            } else {
                currentTimeInterval += TimeInterval(NumberOfSeconds.one)
            }
        }

        refreshTimes.append(endDate)
        refreshTimes.append(endDate.addingTimeInterval(1)) // To be really sure we go to the expired state
        return refreshTimes
    }

    func scheduleNextRefresh() {
        assert(Thread.isMainThread)
        guard !refreshTimes.isEmpty else {
            self.timer = nil
            return
        }
        let refreshAt = refreshTimes.removeFirst()
        let timer = Timer(fire: refreshAt, interval: 0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            let status = Self.status(at: Date(), expiryDate: self.expiresAt, canRenewAfter: self.canRenewAfter)
            self.handler(status)
            self.pruneRefreshTimesInThePast()
            self.scheduleNextRefresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func pruneRefreshTimesInThePast() {
        let now = Date()
        var pastRefreshTimeCount = 0
        for time in refreshTimes {
            if time < now {
                pastRefreshTimeCount += 1
            } else {
                break
            }
        }
        refreshTimes.removeFirst(pastRefreshTimeCount)
    }

    static func status(at date: Date, expiryDate: Date, canRenewAfter: Date?) -> SessionStatus {
        let timeToExpiry = expiryDate.timeIntervalSince(date)
        if timeToExpiry >= 0 {
            let canRenew: Bool = {
                if let canRenewAfter = canRenewAfter {
                    return date > canRenewAfter
                }
                return true
            }()
            return .validFor(timeInterval: timeToExpiry, canRenew: canRenew)
        } else {
            return .expired
        }
    }
}

extension SessionExpiryHelper.SessionStatus {
    static let daysHoursFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour]
        formatter.unitsStyle = .full
        formatter.formattingContext = .middleOfSentence
        return formatter
    }()

    static let hoursMinutesFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        formatter.formattingContext = .middleOfSentence
        return formatter
    }()

    static let minutesOnlyFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute]
        formatter.unitsStyle = .full
        formatter.formattingContext = .middleOfSentence
        return formatter
    }()

    static let minutesSecondsFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .full
        formatter.formattingContext = .middleOfSentence
        return formatter
    }()

    var localizedText: String {
        switch self {
        case .validFor(let timeInterval, _):
            let localizedTimeLeftString: String?
            if timeInterval > TimeInterval(SessionExpiryHelper.NumberOfSeconds.tillWhichToShowDaysHours) {
                localizedTimeLeftString = Self.daysHoursFormatter.string(from: timeInterval)
            } else if timeInterval > TimeInterval(SessionExpiryHelper.NumberOfSeconds.tillWhichToShowHoursMinutes) {
                localizedTimeLeftString = Self.hoursMinutesFormatter.string(from: timeInterval)
            } else if timeInterval > TimeInterval(SessionExpiryHelper.NumberOfSeconds.tillWhichToShowMinutesOnly) {
                localizedTimeLeftString = Self.minutesOnlyFormatter.string(from: timeInterval)
            } else {
                localizedTimeLeftString = Self.minutesSecondsFormatter.string(from: timeInterval)
            }
            return String(format: NSLocalizedString(
                              "Valid for %@",
                              comment: "Connection screen session validity"),
                          localizedTimeLeftString ??
                              NSLocalizedString(
                                "an unknown amount of time",
                                comment: "Connection screen session validity suffix"))
        case .expired:
            return NSLocalizedString(
                "This session has expired",
                comment: "Connection screen session expired")
        }
    }

    var shouldShowRenewSessionButton: Bool {
        switch self {
        case .validFor(_, let canRenew):
            // Don't show renewal button in the first 30 mins after authenticating.
            // Show it all other times.
            return canRenew
        case .expired:
            return true
        }
    }
}

/*
// To test this helper as a script, uncomment and run:
// $ xcrun swift /path/to/this/file.swift | less
let helper = SessionExpiryHelper(
    expiresAt: Date(timeIntervalSinceNow: (60 * 60 * 11.0)),
    authenticatedAt: Date(timeIntervalSinceNow: -1 * 20 * 60),
    handler: { _ in })
print("\(helper.refreshTimes.count) refresh times from: \(Date())")
for refreshAt in helper.refreshTimes {
    let status = SessionExpiryHelper.status(
        at: refreshAt, expiryDate: helper.expiresAt, canRenewAfter: helper.canRenewAfter)
    print("    At \(refreshAt) (\(refreshAt.timeIntervalSince1970)): [\(status.localizedText)]   [\(status.shouldShowRenewSessionButton)]")
}
*/
