//
//  NetworkManager.swift
//  Eatery
//
//  Created by Austin Astorga on 10/29/18.
//  Copyright © 2018 CUAppDev. All rights reserved.
//

import Foundation
import Apollo
import CoreLocation

struct NetworkError: Error {

    var message: String

}

struct NetworkManager {

    static let shared = NetworkManager()

    private let apollo = ApolloClient(url: URL(string: "https://eatery-backend.cornellappdev.com")!)

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY-MM-dd"
        return formatter
    }()

    private let timeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY-MM-dd:h:mma"
        formatter.locale = Locale(identifier: "en_US_POSIX") // force the date formatter to use 12-hour time
        return formatter
    }()

    func getCampusEateries(useCachedData: Bool, completion: @escaping ([CampusEatery]?, NetworkError?) -> Void) {
        apollo.fetch(
            query: CampusEateriesQuery(),
            cachePolicy: useCachedData ? .returnCacheDataElseFetch : .fetchIgnoringCacheData
        ) { result in
            if case let .failure(error) = result {
                completion(nil, NetworkError(message: error.localizedDescription))
                return
            }

            guard case let .success(graphQlData) = result,
                let data = graphQlData.data,
                let eateriesArray = data.campusEateries else {
                    completion(nil, NetworkError(message: "Could not parse response"))
                    return
            }
            let eateries = eateriesArray.compactMap { $0 }

            let finalEateries: [CampusEatery] = eateries.map { eatery in
                let eateryType = EateryType(rawValue: eatery.eateryType.lowercased()) ?? .unknown

                let area = Area(rawValue: eatery.campusArea.descriptionShort)

                var paymentTypes: [PaymentMethod] = []
                let paymentMethods = eatery.paymentMethods
                if paymentMethods.brbs {
                    paymentTypes.append(.brb)
                }
                if paymentMethods.cash {
                    paymentTypes.append(.cash)
                }
                if paymentMethods.cornellCard {
                    paymentTypes.append(.cornellCard)
                }
                if paymentMethods.credit {
                    paymentTypes.append(.creditCard)
                }
                if paymentMethods.mobile {
                    paymentTypes.append(.nfc)
                }
                if paymentMethods.swipes {
                    paymentTypes.append(.swipes)
                }

                var diningItems: [String: [Menu.Item]] = [:]
                var eventItems: [String: [String: Event]] = [:]

                eatery.operatingHours.compactMap { $0 }.forEach { operatingHour in
                    let dateString = operatingHour.date

                    let events = operatingHour.events.compactMap { $0 }
                    var allMenuItems: [Menu.Item] = []
                    var eventsDictionary: [String: Event] = [:]

                    events.forEach { event in
                        let menu = event.menu.compactMap { $0 }
                        var categoryToMenu: [String: [Menu.Item]] = [:]
                        menu.forEach { item in
                            let items = item.items.compactMap { $0 }
                            items.forEach { menuItem in
                                allMenuItems.append(
                                    Menu.Item(
                                        name: menuItem.item,
                                        healthy: menuItem.healthy,
                                        favorite: menuItem.favorite
                                    )
                                )
                            }
                            categoryToMenu[item.category] = items.map { itemForEvent in
                                Menu.Item(
                                    name: itemForEvent.item,
                                    healthy: itemForEvent.healthy,
                                    favorite: itemForEvent.favorite
                                )
                            }
                        }

                        let startDate = self.timeDateFormatter.date(from: event.startTime) ?? Date()
                        let endDate = self.timeDateFormatter.date(from: event.endTime) ?? Date()

                        let eventFinal = Event(
                            start: startDate,
                            end: endDate,
                            desc: event.description,
                            summary: event.calSummary,
                            menu: Menu(data: categoryToMenu)
                        )
                        eventsDictionary[event.description] = eventFinal
                    }

                    diningItems[dateString] = allMenuItems
                    eventItems[dateString] = eventsDictionary
                }

                var swipeDataPoints = [SwipeDataPoint]()
                for swipeDatum in eatery.swipeData {
                    guard let swipeDatum = swipeDatum,
                        let startDate = self.timeDateFormatter.date(from: swipeDatum.startTime),
                        let endDate = self.timeDateFormatter.date(from: swipeDatum.endTime) else {
                            continue
                    }

                    let startHour = Calendar.current.component(.hour, from: startDate)
                    let startMinute = Calendar.current.component(.minute, from: startDate)
                    let unadjustedEndMinute = Calendar.current.component(.minute, from: endDate)
                    let endMinute = unadjustedEndMinute <= 0 ? 60 : unadjustedEndMinute

                    guard startMinute <= endMinute else {
                        continue
                    }

                    let swipeDataPoint = SwipeDataPoint(
                        eateryId: eatery.id,
                        militaryHour: startHour,
                        minuteRange: startMinute...endMinute,
                        swipeDensity: swipeDatum.swipeDensity,
                        waitTimeLow: swipeDatum.waitTimeLow,
                        waitTimeHigh: swipeDatum.waitTimeHigh
                    )
                    swipeDataPoints.append(swipeDataPoint)
                }

                let reservationType: EateryReservationType
                if eatery.isGet {
                    reservationType = .get
                } else if let string = eatery.reserveUrl, let url = URL(string: string) {
                    reservationType = .url(url)
                } else {
                    reservationType = .none
                }

                var expandedMenuData: [String: [ExpandedMenu.Item]] = [:]
                var orderedCategories: [String] = []

                eatery.expandedMenu.compactMap { $0 }.forEach { expandedMenu in
                    expandedMenuData[expandedMenu.category] = []
                    orderedCategories.append(expandedMenu.category)
                    var expandedMenuItems: [ExpandedMenu.Item] = []
                    let stations = expandedMenu.stations.compactMap { $0 }

                    stations.forEach { station in
                        let items = station.items.compactMap { $0 }

                        items.forEach { item in
                            let name = item.item
                            let health = item.healthy
                            let favorite = item.favorite
                            let price = item.price

                            let newItem = ExpandedMenu.Item(
                                name: name,
                                healthy: health,
                                favorite: favorite,
                                priceString: price
                            )
                            expandedMenuItems.append(newItem)
                        }
                    }

                    expandedMenuData[expandedMenu.category] = expandedMenuItems
                    orderedCategories = orderedCategories.sorted()
                }

                return CampusEatery(
                    id: eatery.id,
                    name: eatery.name,
                    eateryType: eateryType,
                    about: eatery.about,
                    area: area,
                    address: eatery.location,
                    paymentMethods: paymentTypes,
                    latitude: eatery.coordinates.latitude,
                    longitude: eatery.coordinates.longitude,
                    phone: eatery.phone,
                    slug: eatery.slug,
                    events: eventItems,
                    diningMenu: diningItems,
                    expandedMenu: expandedMenuData,
                    orderedExpandedCategories: orderedCategories,
                    swipeDataPoints: swipeDataPoints,
                    exceptions: eatery.exceptions.compactMap { $0 },
                    reservationType: reservationType
                )
            }

            completion(finalEateries, nil)
        }
    }

    #if os(iOS)

    func getBRBAccountInfo(sessionId: String, completion: @escaping (BRBAccount?, NetworkError?) -> Void) {
        apollo.fetch(query: BrbInfoQuery(accountId: sessionId), cachePolicy: .fetchIgnoringCacheData) { result in
            if case let .failure(error) = result {
                completion(nil, NetworkError(message: error.localizedDescription))
                return
            }

            guard case let .success(graphQlData) = result,
                let data = graphQlData.data,
                let accountInfo = data.accountInfo else {
                    completion(nil, NetworkError(message: "could not safely unwrap response"))
                    return
            }

            let brbHistory = accountInfo.history.compactMap { $0 }.map { historyItem in
                BRBHistory(
                    name: historyItem.name,
                    timestamp: historyItem.timestamp,
                    amount: historyItem.amount,
                    positive: historyItem.positive
                )
            }

            let brbAccount = BRBAccount(
                cityBucks: accountInfo.cityBucks,
                laundry: accountInfo.laundry,
                brbs: accountInfo.brbs,
                swipes: accountInfo.swipes,
                history: brbHistory
            )

            completion(brbAccount, nil)
        }
    }

    func getCollegetownEateries(completion: @escaping ([CollegetownEatery]?, NetworkError?) -> Void) {
        apollo.fetch(query: CollegetownEateriesQuery(), cachePolicy: .fetchIgnoringCacheData) { result in
            if case let .failure(error) = result {
                completion(nil, NetworkError(message: error.localizedDescription))
                return
            }

            guard case let .success(graphQlData) = result,
                let data = graphQlData.data,
                let graphQlEateries = data.collegetownEateries?.compactMap({ $0 }) else {
                    completion(nil, NetworkError(message: "Could not parse response"))
                    return
            }

            var eateries: [CollegetownEatery] = []

            for graphQlEatery in graphQlEateries {
                let eateryType = EateryType(rawValue: graphQlEatery.eateryType.lowercased()) ?? .unknown

                var paymentTypes: [PaymentMethod] = []
                let paymentMethods = graphQlEatery.paymentMethods
                if paymentMethods.brbs {
                    paymentTypes.append(.brb)
                }
                if paymentMethods.cash {
                    paymentTypes.append(.cash)
                }
                if paymentMethods.cornellCard {
                    paymentTypes.append(.cornellCard)
                }
                if paymentMethods.credit {
                    paymentTypes.append(.creditCard)
                }
                if paymentMethods.mobile {
                    paymentTypes.append(.nfc)
                }
                if paymentMethods.swipes {
                    paymentTypes.append(.swipes)
                }

                var events: [String: [String: Event]] = [:]

                for graphQlOperatingHours in graphQlEatery.operatingHours.compactMap({ $0 }) {
                    var eventsByName: [String: Event] = [:]

                    for graphQlEvent in graphQlOperatingHours.events.compactMap({ $0 }) {
                        let startDate = self.timeDateFormatter.date(from: graphQlEvent.startTime) ?? Date()
                        let endDate = self.timeDateFormatter.date(from: graphQlEvent.endTime) ?? Date()

                        let event = Event(
                            start: startDate,
                            end: endDate,
                            desc: graphQlEvent.description,
                            summary: graphQlEvent.description,
                            menu: Menu(data: [:])
                        )
                        eventsByName[graphQlEvent.startTime] = event
                    }

                    events[graphQlOperatingHours.date] = eventsByName
                }

                let eatery = CollegetownEatery(
                    id: graphQlEatery.id,
                    name: graphQlEatery.name,
                    imageUrl: URL(string: graphQlEatery.imageUrl),
                    eateryType: eateryType,
                    address: graphQlEatery.address,
                    paymentMethods: paymentTypes,
                    latitude: graphQlEatery.coordinates.latitude,
                    longitude: graphQlEatery.coordinates.longitude,
                    phone: graphQlEatery.phone,
                    events: events,
                    price: graphQlEatery.price,
                    rating: Double(graphQlEatery.rating),
                    url: URL(string: graphQlEatery.url),
                    categories: graphQlEatery.categories.compactMap { $0 }
                )

                eateries.append(eatery)
            }

            completion(eateries, nil)
        }
    }

    #endif

}
