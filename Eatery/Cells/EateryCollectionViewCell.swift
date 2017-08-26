import UIKit
import DiningStack
import CoreLocation
import Kingfisher

let metersInMile: Double = 1609.344

class EateryCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var backgroundContainer: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var closedView: UIView!
    @IBOutlet weak var menuTextView: UITextView!
    @IBOutlet weak var menuTextViewHeight: NSLayoutConstraint!
    @IBOutlet var paymentImageViews: [UIImageView]!
    @IBOutlet weak var paymentContainer: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        menuTextView.text = nil
        menuTextView.textContainerInset = UIEdgeInsets(top: 10.0, left: 6.0, bottom: 10.0, right: 6.0)
    }
    
    var eatery: Eatery!
    
    func update(userLocation: CLLocation?) {
        if let distance = userLocation?.distance(from: eatery.location) {
            distanceLabel.text = "\(Double(round(10 * distance / metersInMile) / 10)) mi"
        } else {
            distanceLabel.text = "-- mi"
        }
    }
    
    func set(eatery: Eatery, userLocation: CLLocation?) {
        self.eatery = eatery
        
        titleLabel.text = eatery.nickname

        if let url = URL(string: eateryImagesBaseURL + eatery.slug + ".jpg") {
            let placeholder = UIImage.image(withColor: UIColor(white: 0.97, alpha: 1.0))
            backgroundImageView.kf.setImage(with: url, placeholder: placeholder)
        }
        
        update(userLocation: userLocation)
        
        contentView.layer.cornerRadius = 4
        contentView.layer.masksToBounds = true
        
        var images: [UIImage] = []
        
        if (eatery.paymentMethods.contains(.Cash) || eatery.paymentMethods.contains(.CreditCard)) {
            images.append(#imageLiteral(resourceName: "cashIcon"))
        }
        
        if (eatery.paymentMethods.contains(.BRB)) {
            images.append(#imageLiteral(resourceName: "brbIcon"))
        }
        
        if (eatery.paymentMethods.contains(.Swipes)) {
            images.append(#imageLiteral(resourceName: "swipeIcon"))
        }
        
        for (index, imageView) in paymentImageViews.enumerated() {
            if index < images.count {
                imageView.image = images[index]
                imageView.isHidden = false
            } else {
                imageView.isHidden = true
            }
        }
        
        let eateryStatus = eatery.generateDescriptionOfCurrentState()
        switch eateryStatus {
        case .open(let message):
            titleLabel.textColor = UIColor.black
            timeLabel.text = message
            timeLabel.textColor = UIColor.darkGray
            distanceLabel.textColor = UIColor.darkGray
            closedView.backgroundColor = .clear
        case .closed(let message):
            titleLabel.textColor = UIColor.gray
            timeLabel.text = message
            timeLabel.textColor = UIColor.gray
            distanceLabel.textColor = UIColor.gray
            closedView.backgroundColor = UIColor(white: 1.0, alpha: 0.65)
        }
    }
}
