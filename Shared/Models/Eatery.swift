//
//  Eatery.swift
//  Eatery
//
//  Created by William Ma on 3/9/19.
//  Copyright © 2019 CUAppDev. All rights reserved.
//

import CoreLocation
import SwiftyUserDefaults
import UIKit

// MARK: - Eatery Data

/// Different meals served by eateries
enum Meal: String, Codable {

    case breakfast = "Breakfast"
    case brunch = "Brunch"
    case liteLunch = "Lite Lunch"
    case lunch = "Lunch"
    case dinner = "Dinner"

}

/// Assorted types of payment accepted by an Eatery
enum PaymentMethod: String, Codable {

    case brb = "Meal Plan - Debit"
    case swipes = "Meal Plan - Swipe"
    case cash = "Cash"
    case cornellCard = "Cornell Card"
    case creditCard = "Major Credit Cards"
    case nfc = "Mobile Payments"
    case other = "Other"

}

/// Different types of eateries on campus
enum EateryType: String, Codable {

    case dining = "dining room"
    case cafe = "cafe"
    case cart = "cart"
    case foodCourt = "food court"
    case convenienceStore = "convenience store"
    case coffeeShop = "coffee shop"
    case bakery = "bakery"
    case unknown = ""

}

enum EateryStatus {

    static func equalsIgnoreAssociatedValue(_ lhs: EateryStatus, rhs: EateryStatus) -> Bool {
        switch (lhs, rhs) {
        case (.openingSoon, .openingSoon), (.open, .open), (.closingSoon, .closingSoon), (.closed, .closed):
            return true
        default:
            return false
        }
    }

    case openingSoon(minutesUntilOpen: Int)
    case open
    case closingSoon(minutesUntilClose: Int)
    case closed

}

// MARK: - Eatery

protocol Eatery {

    /// A string of the form YYYY-MM-dd (ISO 8601 Calendar dates)
    /// Read more: https://en.wikipedia.org/wiki/ISO_8601#Calendar_dates
    typealias DayString = String

    typealias EventName = String

    var id: Int { get }

    var name: String { get }

    var displayName: String { get }

    var imageUrl: URL? { get }

    var eateryType: EateryType { get }

    var address: String { get }

    var paymentMethods: [PaymentMethod] { get }

    var latitude: CLLocationDegrees { get }

    var longitude: CLLocationDegrees { get }

    var location: CLLocation { get }

    var phone: String { get }

    var events: [DayString: [EventName: Event]] { get }

    var allEvents: [Event] { get }

    var exceptions: [String] { get }

}

extension Eatery {

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

}

/// Converts the date to its day for use with eatery events
private let dayFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
    formatter.timeZone = TimeZone(identifier: "America/New_York")
    return formatter
}()

// MARK: - Utils

extension Eatery {

    /// The event at an exact date and time, or nil if such an event does not
    /// exist.
    func event(atExactly date: Date) -> Event? {
        allEvents.first { $0.dateInterval.contains(date) }
    }

    /// The events that happen within the specified time interval, regardless of
    /// the day the event occurs on
    /// i.e. events that are active for any amount of time during the interval.
    func events(in dateInterval: DateInterval) -> [Event] {
        allEvents.filter { dateInterval.intersects($0.dateInterval) }
    }

    /// The events by name that occur on the specified day
    // Since events may extend past midnight, this function is required to pick
    // a specific day for an event.
    func eventsByName(onDayOf date: Date) -> [EventName: Event] {
        let dayString = dayFormatter.string(from: date)
        return events[dayString] ?? [:]
    }

    func eventsByDay(withName name: String) -> [DayString: Event] {
        var eventsByDay: [DayString: Event] = [:]
        for (dayString, eventsByName) in events {
            for (eventName, event) in eventsByName where eventName == name {
                eventsByDay[dayString] = event
            }
        }
        return eventsByDay
    }

    func isOpen(onDayOf date: Date) -> Bool {
        !eventsByName(onDayOf: date).isEmpty
    }

    func isOpenToday() -> Bool {
        isOpen(onDayOf: Date())
    }

    func isOpen(atExactly date: Date) -> Bool {
        event(atExactly: date) != nil
    }

    /// The next event if the eatery is closed, or the current event if the eatery is open
    func activeEvent(atExactly date: Date) -> Event? {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date),
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else {
                return nil
        }

        return events(in: DateInterval(start: yesterday, end: tomorrow))
            .filter {
                // disregard events that are not currently happening or that have happened in the past
                $0.occurs(atExactly: date) || date < $0.start
            }
            .min { (lhs, rhs) -> Bool in
            if lhs.occurs(atExactly: date) {
                return true
            } else if rhs.occurs(atExactly: date) {
                return false
            }

            let timeUntilLeftStart = lhs.start.timeIntervalSince(date)
            let timeUntilRightStart = rhs.start.timeIntervalSince(date)
            return timeUntilLeftStart < timeUntilRightStart
            }
    }

    func currentActiveEvent() -> Event? {
        activeEvent(atExactly: Date())
    }

    func status(onDayOf date: Date) -> EateryStatus {
        guard isOpen(onDayOf: date) else {
            return .closed
        }

        guard let event = activeEvent(atExactly: date) else {
            return .closed
        }

        switch event.status(atExactly: date) {
        case .notStarted:
            return .closed

        case .startingSoon:
            let minutesUntilOpen = Int(event.start.timeIntervalSinceNow / 60) + 1
            return .openingSoon(minutesUntilOpen: minutesUntilOpen)

        case .started:
            return .open

        case .endingSoon:
            let minutesUntilClose = Int(event.end.timeIntervalSinceNow / 60) + 1
            return .closingSoon(minutesUntilClose: minutesUntilClose)

        case .ended:
            return .closed
        }
    }

    func currentStatus() -> EateryStatus {
        status(onDayOf: Date())
    }

}

// MARK: - User Defaults / Favoriting

extension Eatery {

    var isFavorite: Bool {
        get {
            Defaults[\.favorites].contains(name)
        }
        nonmutating set {
            if newValue {
                Defaults[\.favorites].append(name)
            } else {
                Defaults[\.favorites].removeAll(where: { $0 == name })
            }

            NotificationCenter.default.post(name: .eateryIsFavoriteDidChange, object: self)
        }
    }

    var hasFavorite: Bool {
        let events = eventsByName(onDayOf: Date())
        for event in events {
            for (_, items) in event.value.menu.data {
                if items.contains(where: { DefaultsKeys.isFavoriteFood($0.name)}) {
                    return true
                }
            }
        }

        if let eatery = self as? CampusEatery, let expandedMenu = eatery.expandedMenu {
            for (_, items) in expandedMenu.data {
                if items.contains(where: { DefaultsKeys.isFavoriteFood($0.name) }) { return true }
            }
        }
        return false
    }

    func getFavorites() -> [String] {
        var favorites = [String]()
        let events = eventsByName(onDayOf: Date())
        for event in events {
            for (_, items) in event.value.menu.data {
                for item in items {
                    if DefaultsKeys.isFavoriteFood(item.name) && !favorites.contains(where: {$0 == item.name}) {
                        favorites.append(item.name)
                    }
                }
            }
        }

        if let eatery = self as? CampusEatery, let expandedMenu = eatery.expandedMenu {
            for (_, items) in expandedMenu.data {
                for item in items {
                    if DefaultsKeys.isFavoriteFood(item.name) && !favorites.contains(where: {$0 == item.name}) {
                        favorites.append(item.name)
                    }
                }
            }
        }
        return favorites
    }

}

extension UIImage {

    static let favoritedImage = UIImage(named: "goldStar")?.withRenderingMode(.alwaysTemplate)
    static let unfavoritedImage = UIImage(named: "whiteStar")?.withRenderingMode(.alwaysTemplate)

}

extension NSNotification.Name {

    static let eateryIsFavoriteDidChange
        = NSNotification.Name("org.cuappdev.eatery.eateryIsFavoriteDidChangeNotificationName")

}

// MARK: - Presentation

struct EateryPresentation {

    let statusText: String
    let statusColor: UIColor
    let nextEventText: String

}

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
}()

extension Eatery {

    func currentPresentation() -> EateryPresentation {
        let statusText: String
        let statusColor: UIColor
        let nextEventText: String

        switch currentStatus() {
        case let .openingSoon(minutesUntilOpen):
            statusText = "Opening"
            statusColor = .eateryOrange
            nextEventText = "in \(minutesUntilOpen)m"

        case .open:
            statusText = "Open"
            statusColor = .eateryGreen

            if let currentEvent = currentActiveEvent() {
                let endTimeText = timeFormatter.string(from: currentEvent.end)
                nextEventText = "until \(endTimeText)"
            } else {
                nextEventText = ""
            }

        case let .closingSoon(minutesUntilClose):
            statusText = "Closing"
            statusColor = .eateryOrange
            nextEventText = "in \(minutesUntilClose)m"

        case .closed:
            statusText = "Closed"
            statusColor = .eateryRed

            if isOpenToday(), let nextEvent = currentActiveEvent() {
                let startTimeText = timeFormatter.string(from: nextEvent.start)
                nextEventText = "until \(startTimeText)"
            } else {
                nextEventText = "today"
            }
        }

        return EateryPresentation(
            statusText: statusText,
            statusColor: statusColor,
            nextEventText: nextEventText
        )
    }

}
