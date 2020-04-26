//
//  SearchResultsTableViewCell.swift
//  Eatery
//
//  Created by William Ma on 4/22/20.
//  Copyright © 2020 CUAppDev. All rights reserved.
//

import UIKit

class SearchResultsTableViewCell: UITableViewCell {

    private(set) var favoriteButton: UIButton!

    var favoriteButtonPressed: (() -> Void)?

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)

        favoriteButton = UIButton(type: .system)
        favoriteButton.frame = CGRect(x: 0, y: 0, width: 22, height: 22)
        accessoryView = favoriteButton
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, subtitle: String, isFavorite: Bool?) {
        textLabel?.text = title
        detailTextLabel?.text = subtitle

        if let isFavorite = isFavorite {
            favoriteButton.isHidden = false

            if isFavorite {
                favoriteButton.setImage(
                    UIImage(named: "goldStar")?.withRenderingMode(.alwaysOriginal),
                    for: .normal)
            } else {
                favoriteButton.setImage(
                    UIImage(named: "whiteStar")?.withRenderingMode(.alwaysTemplate),
                    for: .normal)
                favoriteButton.tintColor = .separator
            }
        } else {
            favoriteButton.isHidden = true
        }
    }

}