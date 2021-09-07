//
//  CertificateExpiryHelper.swift
//  EduVPN
//

import Foundation

class CertificateExpiryHelper {

    enum CertificateStatus: Equatable {
        case validFor(timeInterval: TimeInterval, canRenew: Bool)
        case expired
    }

    let expiresAt: Date
    let authenticatedAt: Date?

    private let handler: (CertificateStatus) -> Void

    fileprivate var refreshTimes: [(refreshAt: Date, state: CertificateStatus)]

    private var timer: Timer? {
        didSet(oldValue) {
            oldValue?.invalidate()
        }
    }

    init(expiresAt: Date, authenticatedAt: Date?, handler: @escaping (CertificateStatus) -> Void) {
        self.expiresAt = expiresAt
        self.authenticatedAt = authenticatedAt
        self.handler = handler
        self.refreshTimes = Self.computeRefreshTimes(from: Date(), to: expiresAt, authenticatedAt: authenticatedAt)
        self.scheduleNextRefresh()
    }

    deinit {
        self.timer = nil // invalidate
    }
}

private extension CertificateExpiryHelper {
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
                                    authenticatedAt: Date?) -> [(refreshAt: Date, state: CertificateStatus)] {
        let endingTimeInterval = endDate.timeIntervalSince(startDate)
        let canRenewTimeInterval = authenticatedAt?.addingTimeInterval(browserSessionValidity).timeIntervalSince(startDate)

        var refreshTimes: [(refreshAt: Date, state: CertificateStatus)] = []
        var currentTimeInterval: TimeInterval = 0
        var isAddedRenewalTime = false

        while currentTimeInterval < endingTimeInterval {

            var canRenew = true
            if let canRenewTimeInterval = canRenewTimeInterval {
                canRenew = currentTimeInterval >= canRenewTimeInterval
                if currentTimeInterval > canRenewTimeInterval && !isAddedRenewalTime {
                    refreshTimes.append(
                        (refreshAt: Date(timeInterval: canRenewTimeInterval, since: startDate),
                         state: .validFor(timeInterval: endingTimeInterval - canRenewTimeInterval, canRenew: canRenew))
                    )
                }
                if canRenew {
                    isAddedRenewalTime = true
                }
            }

            refreshTimes.append(
                (refreshAt: Date(timeInterval: currentTimeInterval, since: startDate),
                 state: .validFor(timeInterval: endingTimeInterval - currentTimeInterval,
                                  canRenew: canRenew)))

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

        refreshTimes.append((refreshAt: endDate, state: .expired))
        return refreshTimes
    }

    func scheduleNextRefresh() {
        assert(Thread.isMainThread)
        guard !refreshTimes.isEmpty else {
            self.timer = nil
            return
        }
        let (refreshAt, state) = refreshTimes.removeFirst()
        let timer = Timer(fire: refreshAt, interval: 0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.handler(state)
            self.scheduleNextRefresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}

extension CertificateExpiryHelper.CertificateStatus {
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
            if timeInterval > TimeInterval(CertificateExpiryHelper.NumberOfSeconds.tillWhichToShowDaysHours) {
                localizedTimeLeftString = Self.daysHoursFormatter.string(from: timeInterval)
            } else if timeInterval > TimeInterval(CertificateExpiryHelper.NumberOfSeconds.tillWhichToShowHoursMinutes) {
                localizedTimeLeftString = Self.hoursMinutesFormatter.string(from: timeInterval)
            } else if timeInterval > TimeInterval(CertificateExpiryHelper.NumberOfSeconds.tillWhichToShowMinutesOnly) {
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
        case .validFor(let timeRemaining, let canRenew):
            // Show renewal button if session expires in
            // less than a week. But don't show it in the
            // first 30 mins after authenticating.
            return canRenew && timeRemaining < (60 * 60 * 24 * 7)
        case .expired:
            return true
        }
    }
}

/*
// To test this helper as a script, uncomment and run:
// $ xcrun swift /path/to/this/file.swift | less
let certificateExpiryHelper = CertificateExpiryHelper(
    expiresAt: Date(timeIntervalSinceNow: (60 * 60 * 11.0)),
    authenticatedAt: Date(timeIntervalSinceNow: -1 * 20 * 60),
    handler: { _ in })
print("\(certificateExpiryHelper.refreshTimes.count) refresh times from: \(Date())")
for (refreshAt, state) in certificateExpiryHelper.refreshTimes {
    print("    At \(refreshAt) (\(refreshAt.timeIntervalSince1970)): [\(state.localizedText)]   [\(state.shouldShowRenewSessionButton)]")
}
*/
