//
//  EateriesGridViewController.swift
//  Eatery
//
//  Created by Eric Appel on 11/18/15.
//  Copyright © 2015 CUAppDev. All rights reserved.
//

import UIKit
import DiningStack

enum CollectionLayout: String {
    case Grid = "grid"
    case Table = "table"
    
    var iconImage: UIImage {
        switch self {
        case .Grid:
            return UIImage(named: "tableIcon")!
        case .Table:
            return UIImage(named: "gridIcon")!
        }
    }
}

let kCollectionViewGutterWidth: CGFloat = 8

class EateriesGridViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, MenuFavoriteDelegate {
    
    var collectionView: UICollectionView!
    private var eateries: [Eatery] = []
    private var eateryData: [String: [Eatery]] = [:]
    
    let gridLayoutDelegate = EateriesCollectionViewGridLayout()
    let tableLayoutDelegate = EateriesCollectionViewTableLayout()
    
    var currentLayout: CollectionLayout = .Grid
    
    private var searchController: UISearchController!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // -- Nav bar
        // TODO: make this a proxy and put it in another file
        navigationController?.view.backgroundColor = UIColor.whiteColor()
        navigationController?.navigationBar.translucent = false
        navigationController?.navigationBar.barTintColor = UIColor.eateryBlue()
        navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        navigationController?.navigationBar.titleTextAttributes = [NSFontAttributeName: UIFont(name: "Avenir Next", size: 20)!]
        navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.whiteColor()]
        
        // Collection View
        var collectionViewFrame = view.frame
        collectionViewFrame.size = CGSize(width: collectionViewFrame.width - 2 * kCollectionViewGutterWidth, height: collectionViewFrame.height - kNavAndStatusBarHeight)
        collectionViewFrame.offsetInPlace(dx: kCollectionViewGutterWidth, dy: 0)
        
        gridLayoutDelegate.controller = self
        tableLayoutDelegate.controller = self
        
        collectionView = UICollectionView(frame: collectionViewFrame, collectionViewLayout: EateriesCollectionViewLayout())
        collectionView.dataSource = self
        collectionView.delegate = tableLayoutDelegate
        
        if shouldShowLayoutButton {
            if let layoutString = NSDefaults.stringForKey(kDefaultsCollectionViewLayoutKey) {
                currentLayout = CollectionLayout(rawValue: layoutString)!
            } else {
                NSDefaults.setObject("grid", forKey: kDefaultsCollectionViewLayoutKey)
                NSDefaults.synchronize()
            }
            
            
            var layoutDelegate: EateriesCollectionViewLayout
            switch currentLayout {
            case .Grid:
                layoutDelegate = gridLayoutDelegate
            case .Table:
                layoutDelegate = tableLayoutDelegate
            }
            collectionView.delegate = layoutDelegate
            
            let layoutButton = UIButton(frame: CGRect(x: 0, y: 0, width: 18, height: 18))
            layoutButton.addTarget(self, action: "layoutButtonPressed:", forControlEvents: .TouchUpInside)
            layoutButton.setImage(currentLayout.iconImage, forState: .Normal)
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: layoutButton)
        }
        
        collectionView.registerNib(UINib(nibName: "EateryCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "Cell")
        collectionView.registerNib(UINib(nibName: "EateriesCollectionViewHeaderView", bundle: nil), forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: "HeaderView")
        
        collectionView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        
        view.addSubview(collectionView)
        
        view.backgroundColor = UIColor(white: 0.93, alpha: 1)
        collectionView.backgroundColor = UIColor(white: 0.93, alpha: 1)
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: "pullToRefresh:", forControlEvents: .ValueChanged)
        collectionView.addSubview(refreshControl)
        
        loadData(false, completion: nil)
    }
    
    func loadData(force: Bool, completion:(() -> Void)?) {
        DATA.fetchEateries(force) { (error) -> (Void) in
            print("Fetched data\n")
            dispatch_async(dispatch_get_main_queue(), {() -> Void in
                if let completionBlock = completion {
                    completionBlock()
                }
                self.eateries = DATA.eateries
                self.processEateries()
                self.collectionView.reloadData()
                })
        }
    }
    
    func pullToRefresh(sender: UIRefreshControl) {
        loadData(true) { () -> Void in
            sender.endRefreshing()
        }
    }
    
    func processEateries() {
        let favoriteEateries = eateries.filter { return $0.favorite }
        let northCampusEateries = eateries.filter { return $0.area == .North }
        let westCampusEateries = eateries.filter { return $0.area == .West }
        let centralCampusEateries = eateries.filter { return $0.area == .Central }

        // TODO: sort by hours?

        eateryData["Favorites"] = favoriteEateries
        eateryData["North"] = northCampusEateries
        eateryData["West"] = westCampusEateries
        eateryData["Central"] = centralCampusEateries
        
        gridLayoutDelegate.eateryData = eateryData
        tableLayoutDelegate.eateryData = eateryData
        
    }
    
    // MARK: -
    // MARK: UICollectionViewDataSource
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        guard eateryData["Favorites"]?.count > 0 else {
            return 3
        }
        return 4
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        var eSection = section
        if eateryData["Favorites"]?.count == 0 {
            eSection += 1
        }
        switch eSection {
        case 0:
            return eateryData["Favorites"] != nil ?     eateryData["Favorites"]!.count : 0
        case 1:
            return eateryData["Central"] != nil ?       eateryData["Central"]!.count : 0
        case 2:
            return eateryData["West"] != nil ?          eateryData["West"]!.count : 0
        case 3:
            return eateryData["North"] != nil ?         eateryData["North"]!.count : 0
        default:
            return 0
        }
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("Cell", forIndexPath: indexPath) as! EateryCollectionViewCell
        
        var eatery: Eatery!
        
        var section = indexPath.section
        if eateryData["Favorites"]?.count == 0 {
            section += 1
        }
        switch section {
        case 0:
            eatery = eateryData["Favorites"]![indexPath.row]
        case 1:
            eatery = eateryData["Central"]![indexPath.row]
        case 2:
            eatery = eateryData["West"]![indexPath.row]
        case 3:
            eatery = eateryData["North"]![indexPath.row]
        default:
            print("Invalid section in grid view.")
        }

        cell.setEatery(eatery)
                
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        
        var reusableHeaderView: UICollectionReusableView!
        
        if kind == UICollectionElementKindSectionHeader {
            let sectionHeaderView = collectionView.dequeueReusableSupplementaryViewOfKind(UICollectionElementKindSectionHeader, withReuseIdentifier: "HeaderView", forIndexPath: indexPath) as! EateriesCollectionViewHeaderView
            
            var section = indexPath.section
            if eateryData["Favorites"] == nil || eateryData["Favorites"]?.count == 0 {
                section += 1
            }
            switch section {
            case 0:
                sectionHeaderView.titleLabel.text = "Favorites"
            case 1:
                sectionHeaderView.titleLabel.text = "Central"
            case 2:
                sectionHeaderView.titleLabel.text = "West"
            case 3:
                sectionHeaderView.titleLabel.text = "North"
            default:
                print("Invalid section.")
            }
            
            reusableHeaderView = sectionHeaderView
        }
        
        return reusableHeaderView
    }
    
    // MARK: -
    // MARK: MenuFavoriteDelegate
    
    func favoriteButtonPressed() {
        // if this is too expensive, set a flag and run it on `viewDidAppear`
        processEateries()
        collectionView.reloadData()
    }
    
    // MARK: -
    // MARK: Nav button
    
    func layoutButtonPressed(sender: UIButton) {
        // toggle
        currentLayout = currentLayout == .Grid ? .Table : .Grid
        NSDefaults.setObject(currentLayout.rawValue, forKey: kDefaultsCollectionViewLayoutKey)
        NSDefaults.synchronize()
        
        let newLayoutDelegate = currentLayout == .Grid ? gridLayoutDelegate : tableLayoutDelegate
        
        sender.setImage(currentLayout.iconImage, forState: .Normal)
        
        collectionView.performBatchUpdates({ () -> Void in
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.delegate = newLayoutDelegate
            }, completion: nil)
    }
    
    var shouldShowLayoutButton: Bool {
        return view.frame.width > 320
    }
}
