//
//  Menu.swift
//  Eatery
//
//  Created by William Ma on 3/1/19.
//  Copyright © 2019 CUAppDev. All rights reserved.
//

import Foundation
import SwiftyUserDefaults

struct Menu: Codable {

    /**
     * Basic representation of an individual menu entry
     */
    struct Item: Codable {

        /// English description of the menu item
        let name: String

        /// Flag indicating if the item is deemed healthy or not by Cornell
        let healthy: Bool
        
        /// Flag indicating if the user has favorited this item
        
        var favorited: Bool {
            get {
                Defaults[\.favoriteMenuItems].contains(name)
            }
            nonmutating set {
                if newValue {
                    Defaults[\.favoriteMenuItems].append(name)
                } else {
                    Defaults[\.favoriteMenuItems].removeAll { $0 == name }
                }
            }
        }

    }

    typealias Category = String

    typealias StringRepresentation = [(String, [String])]

    var data: [Category: [Item]]

    /**
     A list of tuples in the form (category, [item list]).
     For each category we create a tuple containing the food category name as a string
     and the food items available for the category as a string list.

     Used to easily iterate over all items in the event menu.

     Ex: [("Entrees",["Chicken", "Steak", "Fish"]), ("Fruit", ["Apples"])]
     */
    var stringRepresentation: StringRepresentation {
        return data.compactMap { (category, items) -> (String, [String])? in
            items.isEmpty ? nil : (category, items.map { $0.name })
        }
    }

}
