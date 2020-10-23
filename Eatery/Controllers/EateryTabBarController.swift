//
//  EateryTabBarController.swift
//  Eatery
//
//  Created by Kevin Chan on 11/9/18.
//  Copyright © 2018 CUAppDev. All rights reserved.
//

import BLTNBoard
import SwiftyUserDefaults
import UIKit
import WatchConnectivity

class EateryTabBarController: UITabBarController {

    // MARK: View controllers

    let eateriesViewController = CampusEateriesViewController()
    let lookAheadViewController = LookAheadViewController()
    let brbViewController = BRBViewController()

    override func viewDidLoad() {
        delegate = self
        eateriesViewController.tabBarItem = UITabBarItem(
            title: nil,
            image: UIImage(named: "eateryTabIcon.png"),
            tag: 0
        )
        
        let lookAheadNavigationController = EateryNavigationController(rootViewController: lookAheadViewController)
        lookAheadNavigationController.tabBarItem = UITabBarItem(title: nil, image: #imageLiteral(resourceName: "menu icon"), tag: 1)

        let brbNavigationController = EateryNavigationController(rootViewController: brbViewController)
        brbNavigationController.tabBarItem = UITabBarItem(title: nil, image: UIImage(named: "accountIcon.png"), tag: 2)

        let navigationControllers = [
            eateriesViewController.campusNavigationVC,
            lookAheadNavigationController,
            brbNavigationController
        ]
        navigationControllers.forEach {
            $0.tabBarItem.imageInsets = UIEdgeInsets(top: 6, left: 0, bottom: -6, right: 0)
        }

        setViewControllers(navigationControllers, animated: false)

        tabBar.barTintColor = .white
        tabBar.tintColor = .eateryBlue
        tabBar.shadowImage = UIImage()
    }

    func tabBarControllerSupportedInterfaceOrientations(
        _ tabBarController: UITabBarController
    ) -> UIInterfaceOrientationMask {
        .portrait
    }

    func tabBarControllerPreferredInterfaceOrientationForPresentation(
        _ tabBarController: UITabBarController
    ) -> UIInterfaceOrientation {
        .portrait
    }
    
    func preselectEatery(withName name: String) {
        eateriesViewController.preselectEatery(withName: name)
    }

}

extension EateryTabBarController: UITabBarControllerDelegate {

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if selectedViewController === viewController,
            let campusEateries = viewController as? CampusEateriesViewController {
            if campusEateries.activeNavigationController.viewControllers.count > 1 {
                campusEateries.activeNavigationController.popViewController(animated: true)
            } else {
                campusEateries.activeViewController.scrollToTop(animated: true)
            }
        }

        return true
    }

    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        switch item.tag {
        case 0: AppDevAnalytics.shared.logFirebase(EateryPressPayload())
        case 1: AppDevAnalytics.shared.logFirebase(LookAheadPressPayload())
        case 2: AppDevAnalytics.shared.logFirebase(BRBPressPayload())
        default:
            break
        }

    }

}
