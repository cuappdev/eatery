//
//  Eatery.swift
//  Eatery
//
//  Created by William Ma on 3/9/19.
//  Copyright © 2019 CUAppDev. All rights reserved.
//

import CoreLocation
import Foundation

/// Different meals served by eateries
enum Meal: String {

    case breakfast = "Breakfast"
    case brunch = "Brunch"
    case liteLunch = "Lite Lunch"
    case lunch = "Lunch"
    case dinner = "Dinner"

}

/// Assorted types of payment accepted by an Eatery
enum PaymentMethod: String {

    case brb = "Meal Plan - Debit"
    case swipes = "Meal Plan - Swipe"
    case cash = "Cash"
    case cornellCard = "Cornell Card"
    case creditCard = "Major Credit Cards"
    case nfc = "Mobile Payments"
    case other = "Other"

}

/// Different types of eateries on campus
enum EateryType: String {

    case dining = "all you care to eat dining room"
    case cafe = "cafe"
    case cart = "cart"
    case foodCourt = "food court"
    case convenienceStore = "convenience store"
    case coffeeShop = "coffee shop"
    case bakery = "bakery"
    case unknown = ""

}

/// Represents a location on Cornell Campus
enum Area: String {

    case west = "West"
    case north = "North"
    case central = "Central"

}

enum EateryStatus {

    case openingSoon(minutesUntilOpen: Int)
    case open
    case closingSoon(minutesUntilClose: Int)
    case closed

}

protocol Eatery {

    typealias EventName = String

    var id: Int { get }

    var name: String { get }

    var displayName: String { get }

    var imageUrl: URL? { get }

    var eateryType: EateryType { get }

    var area: Area? { get }

    var address: String { get }

    var paymentMethods: [PaymentMethod] { get }

    var location: CLLocation { get }

    var phone: String { get }

    /// The event at an exact date and time, or nil if such an event does not
    /// exist.
    func event(atExactly date: Date) -> Event?

    /// The events that happen within the specified time interval, regardless of
    /// the day the event occurs on
    /// i.e. events that are active for any amount of time during the interval.
    func events(in dateInterval: DateInterval) -> [Event]

    /// The events by name that occur on the specified day
    // Since events may extend past midnight, this function is required to pick
    // a specific day for an event.
    func eventsByName(onDayOf date: Date) -> [EventName: Event]

}

// MARK: -

extension Eatery {

    func isOpen(onDayOf date: Date) -> Bool {
        return !eventsByName(onDayOf: date).isEmpty
    }

    func isOpenToday() -> Bool {
        return isOpen(onDayOf: Date())
    }

    func isOpen(atExactly date: Date) -> Bool {
        return event(atExactly: date) != nil
    }

    func activeEvent(atExactly date: Date) -> Event? {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()),
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) else {
                return nil
        }

        return events(in: DateInterval(start: yesterday, end: tomorrow))
            .filter {
                // disregard events that are not currently happening or that have happened in the past
                $0.occurs(atExactly: date) || date < $0.start
            }.min { (lhs, rhs) -> Bool in
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
        return activeEvent(atExactly: Date())
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
        return status(onDayOf: Date())
    }

}

// MARK: - Deprecated

extension Eatery {

    func isOpen(on date: Date) -> Bool {
        return isOpen(atExactly: date)
    }

    func isOpen(for date: Date) -> Bool {
        return isOpen(onDayOf: date)
    }

    func activeEvent(for date: Date) -> Event? {
        return activeEvent(atExactly: date)
    }

    func eventsByName(on date: Date) -> [EventName: Event] {
        return eventsByName(onDayOf: date)
    }

}
