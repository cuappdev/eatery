//
//  CTownMenuHeaderView.swift
//  Eatery
//
//  Created by Gonzalo Gonzalez on 3/3/19.
//  Copyright © 2019 CUAppDev. All rights reserved.
//

import UIKit
import MapKit

class CollegetownMenuHeaderView: UIView {
    
    var backButton: UIButton!
    
    var backgroundImageView: UIImageView!
    var titleLabel: UILabel!
    var paymentView: PaymentMethodsView!
    var informationView: UIView!
    
    //Information View
    
    var statusLabel: UILabel!
    var hourLabel: UILabel!
    var cuisineLabel: UILabel!
    var locationLabel: UILabel!
    var ratingView: RatingView!
    var priceLabel: UILabel!
    var distanceLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundImageView = UIImageView()
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        addSubview(backgroundImageView)
        
        titleLabel = UILabel()
        titleLabel.isOpaque = false
        titleLabel.font = .boldSystemFont(ofSize: 34)
        titleLabel.textColor = .white
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.25
        addSubview(titleLabel)
        
        paymentView = PaymentMethodsView()
        addSubview(paymentView)
        
        informationView = UIView()
        informationView.backgroundColor = .white
        addSubview(informationView)
        
        statusLabel = UILabel()
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        addSubview(statusLabel)
        
        hourLabel = UILabel()
        hourLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        addSubview(hourLabel)

        cuisineLabel = UILabel()
        cuisineLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        cuisineLabel.lineBreakMode = .byWordWrapping
        cuisineLabel.numberOfLines = 3
        addSubview(cuisineLabel)
        
        locationLabel = UILabel()
        locationLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        locationLabel.textColor = .gray
        addSubview(locationLabel)
        
        ratingView = RatingView()
        addSubview(ratingView)
        
        priceLabel = UILabel()
        priceLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        priceLabel.text = "$$$"
        priceLabel.textColor = .gray
        addSubview(priceLabel)
        
        distanceLabel = UILabel()
        distanceLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        distanceLabel.textColor = .gray
        addSubview(distanceLabel)
        
        setupConstraints()
    }
    
    func setupConstraints(){
        backgroundImageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(258)
        }
        
        paymentView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalTo(titleLabel.snp.centerY)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.trailing.lessThanOrEqualTo(paymentView.snp.leading)
            make.bottom.equalTo(backgroundImageView).inset(15)
        }
        
        informationView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(backgroundImageView.snp.bottom)
            make.height.equalTo(105)
        }
        
        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(informationView).inset(11)
            make.leading.equalTo(informationView).inset(12)
            make.trailing.lessThanOrEqualTo(informationView)
            make.height.equalTo(19)
        }
        
        hourLabel.snp.makeConstraints { make in
            make.centerY.equalTo(statusLabel)
            make.leading.equalTo(statusLabel.snp.trailing).offset(4.5)
            make.trailing.lessThanOrEqualTo(informationView)
            make.height.equalTo(17)
        }
        
        cuisineLabel.snp.makeConstraints { make in
            make.top.equalTo(statusLabel.snp.bottom).offset(2)
            make.leading.equalTo(statusLabel)
            make.height.equalTo(45)
            make.width.equalTo(260)
        }
        
        locationLabel.snp.makeConstraints { make in
            make.top.equalTo(cuisineLabel.snp.bottom).offset(6)
            make.leading.equalTo(cuisineLabel)
            make.trailing.lessThanOrEqualTo(informationView)
            make.height.equalTo(17)
        }
        
        ratingView.snp.makeConstraints { make in
            make.centerY.equalTo(statusLabel)
            make.trailing.equalTo(informationView).inset(12)
        }
        
        priceLabel.snp.makeConstraints { make in
            make.top.equalTo(ratingView.snp.bottom).offset(13)
            make.trailing.equalToSuperview().inset(12.5)
            make.height.equalTo(19)
            make.width.equalTo(30.5)
        }
        
        distanceLabel.snp.makeConstraints { make in
            make.centerY.equalTo(locationLabel)
            make.trailing.equalToSuperview().inset(12.5)
            make.height.equalTo(17)
            make.width.lessThanOrEqualToSuperview()
        }
        
    }
    
    func set(eatery: CollegetownEatery, userLocation: CLLocation?) {
        titleLabel.text = eatery.displayName
        if let url = eatery.imageUrl {
            let placeholder = UIImage.image(withColor: UIColor(white: 0.97, alpha: 1.0))
            backgroundImageView.kf.setImage(with: url, placeholder: placeholder)
        }

        let eateryStatus = eatery.currentStatus()
        
        switch eateryStatus {
        case .open, .closingSoon:
            titleLabel.textColor = .white
            
        case .closed, .openingSoon:
            titleLabel.textColor = UIColor.darkGray
            
            let closedView = UIView()
            closedView.backgroundColor = UIColor(white: 1.0, alpha: 0.65)
            backgroundImageView.addSubview(closedView)
            closedView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        
        paymentView.paymentMethods = eatery.paymentMethods

        switch eateryStatus {
        case let .openingSoon(minutesUntilOpen):
            statusLabel.text = "Opening"
            statusLabel.textColor = .eateryOrange
            hourLabel.text = "in \(minutesUntilOpen)m"

        case .open:
            statusLabel.text = "Open"
            statusLabel.textColor = .eateryGreen
            hourLabel.text = ""

        case let .closingSoon(minutesUntilClose):
            statusLabel.text = "Closing"
            statusLabel.textColor = .eateryOrange
            hourLabel.text = "in \(minutesUntilClose)m"

        case .closed:
            statusLabel.text = "Closed"
            statusLabel.textColor = .eateryRed
            hourLabel.text = ""
        }
        
        cuisineLabel.text = eatery.categories.joined(separator: ", ")
        
        locationLabel.text = eatery.address
        
        let star1 = ratingView.ratingImageView[0]
        let star2 = ratingView.ratingImageView[1]
        let star3 = ratingView.ratingImageView[2]
        let star4 = ratingView.ratingImageView[3]
        let star5 = ratingView.ratingImageView[4]

        if let rating = eatery.rating {
            switch rating {
            case .five:
                star1.image = UIImage(named: "selected")
                star2.image = UIImage(named: "selected")
                star3.image = UIImage(named: "selected")
                star4.image = UIImage(named: "selected")
                star5.image = UIImage(named: "selected")
                break
            case .fourPointFive:
                star1.image = UIImage(named: "selected")
                star2.image = UIImage(named: "selected")
                star3.image = UIImage(named: "selected")
                star4.image = UIImage(named: "selected")
                star5.image = UIImage(named: "halfSelected")
                break
            case .four:
                star1.image = UIImage(named: "selected")
                star2.image = UIImage(named: "selected")
                star3.image = UIImage(named: "selected")
                star4.image = UIImage(named: "selected")
                star5.image = UIImage(named: "unselected")
                break
            case .threePointFive:
                star1.image = UIImage(named: "selected")
                star2.image = UIImage(named: "selected")
                star3.image = UIImage(named: "selected")
                star4.image = UIImage(named: "halfSelected")
                star5.image = UIImage(named: "unselected")
                break
            case .three:
                star1.image = UIImage(named: "selected")
                star2.image = UIImage(named: "selected")
                star3.image = UIImage(named: "selected")
                star4.image = UIImage(named: "unselected")
                star5.image = UIImage(named: "unselected")
                break
            case .twoPointFive:
                star1.image = UIImage(named: "selected")
                star2.image = UIImage(named: "selected")
                star3.image = UIImage(named: "halfSelected")
                star4.image = UIImage(named: "unselected")
                star5.image = UIImage(named: "unselected")
                break
            case .two:
                star1.image = UIImage(named: "selected")
                star2.image = UIImage(named: "selected")
                star3.image = UIImage(named: "unselected")
                star4.image = UIImage(named: "unselected")
                star5.image = UIImage(named: "unselected")
                break
            case .onePointFive:
                star1.image = UIImage(named: "selected")
                star2.image = UIImage(named: "halfSelected")
                star3.image = UIImage(named: "unselected")
                star4.image = UIImage(named: "unselected")
                star5.image = UIImage(named: "unselected")
                break
            case .one:
                star1.image = UIImage(named: "selected")
                star2.image = UIImage(named: "unselected")
                star3.image = UIImage(named: "unselected")
                star4.image = UIImage(named: "unselected")
                star5.image = UIImage(named: "unselected")
                break
            case .zeroPointFive:
                star1.image = UIImage(named: "halfSelected")
                star2.image = UIImage(named: "unselected")
                star3.image = UIImage(named: "unselected")
                star4.image = UIImage(named: "unselected")
                star5.image = UIImage(named: "unselected")
                break
            }
        } else {
            star1.image = UIImage(named: "halfSelected")
            star2.image = UIImage(named: "halfSelected")
            star3.image = UIImage(named: "halfSelected")
            star4.image = UIImage(named: "halfSelected")
            star5.image = UIImage(named: "halfSelected")
        }

        let attributedString = NSMutableAttributedString(string:"$$$")
        switch eatery.price {
        case "$":
            attributedString.addAttribute(NSAttributedStringKey.foregroundColor, value: UIColor.black , range: NSRange(location: 0, length: 1))
            priceLabel.attributedText = attributedString
            break
        case "$$":
            attributedString.addAttribute(NSAttributedStringKey.foregroundColor, value: UIColor.black , range: NSRange(location: 0, length: 2))
            priceLabel.attributedText = attributedString
            break
        case "$$$":
            priceLabel.textColor = .black
            break
        default:
            break
        }
        
        if let userLocation = userLocation {
            let distance = userLocation.distance(from: eatery.location, in: .miles)
            distanceLabel.text = "\(Double(round(10 * distance) / 10)) mi"
        } else {
            distanceLabel.text = "-- mi"
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
