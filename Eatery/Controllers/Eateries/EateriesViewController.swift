//
//  EateriesViewController.swift
//  Eatery
//
//  Created by William Ma on 3/12/19.
//  Copyright © 2019 CUAppDev. All rights reserved.
//

import CoreLocation
import NVActivityIndicatorView
import UIKit

// MARK: - Data Source

protocol EateriesViewControllerDataSource: AnyObject {

    func eateriesViewController(_ evc: EateriesViewController,
                                eateriesToPresentWithSearchText searchText: String,
                                filters: Set<Filter>) -> [Eatery]

    func eateriesViewController(_ evc: EateriesViewController,
                                sortMethodWithSearchText searchText: String,
                                filters: Set<Filter>) -> EateriesViewController.SortMethod

    func eateriesViewController(_ evc: EateriesViewController,
                                highlightedSearchDescriptionForEatery eatery: Eatery,
                                searchText: String,
                                filters: Set<Filter>) -> NSAttributedString?

}

// MARK: - Delegate

protocol EateriesViewControllerDelegate: AnyObject {

    func eateriesViewController(_ evc: EateriesViewController, didSelectEatery eatery: Eatery)

    func eateriesViewControllerDidPressRetryButton(_ evc: EateriesViewController)

    func eateriesViewControllerDidPushMapViewController(_ evc: EateriesViewController)

    func eateriesViewControllerDidRefreshEateries(_ evc: EateriesViewController)

}

// MARK: - Scroll Delegate

protocol EateriesViewControllerScrollDelegate: AnyObject {
    
    func eateriesViewController(_ evc: EateriesViewController,
                                scrollViewWillBeginDragging scrollView: UIScrollView)

    func eateriesViewController(_ evc: EateriesViewController,
                                scrollViewDidStopScrolling scrollView: UIScrollView)

    func eateriesViewController(_ evc: EateriesViewController,
                                scrollViewDidScroll scrollView: UIScrollView)

}

// MARK: - Eateries View Controller

class EateriesViewController: UIViewController {

    static let collectionViewMargin: CGFloat = 16

    enum AnimationKey: String {

        case backgroundImageView = "backgroundImage"
        case title = "title"
        case starIcon = "starIcon"
        case paymentView = "paymentView"
        case distanceLabel = "distanceLabel"
        case infoContainer = "infoContainer"

        func id(eatery: Eatery) -> String {
            return "\(eatery.id)_\(rawValue)"
        }

    }

    enum Group: CaseIterable {
        case favorites
        case open
        case closed
    }

    typealias EateriesByGroup = [Group: [Eatery]]

    enum State: Equatable {

        case presenting
        case loading
        case failedToLoad(Error)
        
        static func == (lhs: EateriesViewController.State, rhs: EateriesViewController.State) -> Bool {
            switch (lhs, rhs) {
            case (.presenting, .presenting): return true
            case (.loading, .loading): return true
            case (.failedToLoad, .failedToLoad): return true
            default: return false
            }
        }

    }

    private enum CellIdentifier: String {
        case container
        case eatery
    }

    private enum SupplementaryViewIdentifier: String {
        case empty
        case header
    }

    enum SortMethod {
        case nearest(CLLocation)
        case alphabetical
    }

    // Model

    weak var dataSource: EateriesViewControllerDataSource?

    private var state: State = .loading
    private var eateriesByGroup: EateriesByGroup?
    private var presentedGroups: [Group] {
        guard let eateriesByGroup = eateriesByGroup else {
            return []
        }

        return Group.allCases
            .enumerated()
            .filter({ !eateriesByGroup[$0.element, default: []].isEmpty })
            .map { $0.element }
    }

    private var updateTimer: Timer?

    // Views

    weak var delegate: EateriesViewControllerDelegate?
    weak var scrollDelegate: EateriesViewControllerScrollDelegate?
    
    var appDevLogo: UIView?
    
    private var gridLayout: EateriesCollectionViewGridLayout!
    private var collectionView: UICollectionView!
    private var refreshControl: UIRefreshControl!

    private var searchFilterContainer: UIView!
    private var searchBar: UISearchBar!
    private var filterBar: FilterBar!
    var availableFilters: [Filter] {
        get { return filterBar.displayedFilters }
        set { filterBar.displayedFilters = newValue }
    }

    private var failedToLoadView: EateriesFailedToLoadView!
    private var activityIndicator: NVActivityIndicatorView!

    // Location

    var userLocation: CLLocation? {
        didSet {
            for cell in collectionView.visibleCells.compactMap({ $0 as? EateryCollectionViewCell }) {
                cell.userLocation = userLocation
            }
        }
    }

    // MARK: View Controller

    override func viewDidLoad() {
        super.viewDidLoad()

        setUpCollectionView()
        setUpSearchAndFilterBars()
        setUpActivityIndicator()
        setUpFailedToLoadView()

        // set up loading state

        collectionView.alpha = 0

        searchBar.alpha = 0
        filterBar.alpha = 0

        activityIndicator.startAnimating()
        failedToLoadView.alpha = 0

        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let `self` = self else { return }
            print("Updating \(type(of: self))", Date())
            self.collectionView.reloadData()
        }
    }
    
    private func setUpCollectionView() {
        gridLayout = EateriesCollectionViewGridLayout()
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: gridLayout)
        collectionView.backgroundColor = .white
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
        collectionView.delaysContentTouches = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UICollectionViewCell.self,
                                forCellWithReuseIdentifier: CellIdentifier.container.rawValue)
        collectionView.register(EateryCollectionViewCell.self,
                                forCellWithReuseIdentifier: CellIdentifier.eatery.rawValue)
        collectionView.register(UICollectionReusableView.self,
                                forSupplementaryViewOfKind: UICollectionElementKindSectionHeader,
                                withReuseIdentifier: SupplementaryViewIdentifier.empty.rawValue)
        collectionView.register(EateriesCollectionViewHeaderView.self,
                                forSupplementaryViewOfKind: UICollectionElementKindSectionHeader,
                                withReuseIdentifier: SupplementaryViewIdentifier.header.rawValue)
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        refreshControl = UIRefreshControl(frame: .zero)
        refreshControl.tintColor = .white
        refreshControl.addTarget(self, action: #selector(refreshEateries), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    private func setUpSearchAndFilterBars() {
        searchFilterContainer = UIView()
        
        searchBar = UISearchBar(frame: .zero)
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundColor = .white
        searchBar.delegate = self
        searchBar.placeholder = "Search eateries and menus"
        searchBar.autocapitalizationType = .none
        searchBar.enablesReturnKeyAutomatically = false
        searchFilterContainer.addSubview(searchBar)
        searchBar.snp.makeConstraints { make in
            make.top.equalTo(searchFilterContainer)
            make.leading.trailing.equalToSuperview().inset(8)
        }
        
        filterBar = FilterBar(frame: .zero)
        filterBar.delegate = self
        searchFilterContainer.addSubview(filterBar)
        filterBar.snp.makeConstraints { make in
            make.top.equalTo(searchBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(searchFilterContainer)
        }
    }
    
    private func setUpActivityIndicator() {
        activityIndicator = NVActivityIndicatorView(frame: .zero,
                                                    type: .circleStrokeSpin,
                                                    color: .transparentEateryBlue)
        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(44)
        }
    }
    
    private func setUpFailedToLoadView() {
        failedToLoadView = EateriesFailedToLoadView(frame: .zero)
        failedToLoadView.delegate = self
        view.addSubview(failedToLoadView)
        failedToLoadView.snp.makeConstraints { make in
            make.center.equalTo(view.layoutMarginsGuide.snp.center)
            make.top.greaterThanOrEqualTo(view.snp.topMargin).inset(16)
            make.leading.greaterThanOrEqualToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
            make.bottom.lessThanOrEqualTo(view.snp.bottomMargin).inset(16)
            make.edges.equalTo(view.snp.margins).priority(.high)
        }
    }

    func updateState(_ newState: State, animated: Bool) {
        guard state != newState else {
            return
        }

        switch state {
        case .loading:
            fadeOut(views: [activityIndicator], animated: true, completion: activityIndicator.stopAnimating)

        case .presenting:
            fadeOut(views: [collectionView, searchBar, filterBar], animated: true)

        case .failedToLoad:
            fadeOut(views: [failedToLoadView], animated: true)
        }

        state = newState

        switch newState {
        case .loading:
            activityIndicator.startAnimating()

            fadeIn(views: [activityIndicator], animated: true)

        case .presenting:
            reloadEateries()

            fadeIn(views: [collectionView, searchBar, filterBar], animated: animated)

            if animated {
                animateCollectionViewCells()
            }

        case .failedToLoad:
            fadeIn(views: [failedToLoadView], animated: animated)

            break
        }
    }

    private func fadeIn(views: [UIView], animated: Bool, completion: (() -> Void)? = nil) {
        perform(animations: {
            for view in views {
                view.alpha = 1
            }
        }, animated: animated, completion: completion)
    }

    private func fadeOut(views: [UIView], animated: Bool, completion: (() -> Void)? = nil) {
        perform(animations: {
            for view in views {
                view.alpha = 0
            }
        }, animated: animated, completion: completion)
    }

    private func perform(animations: @escaping () -> Void, animated: Bool, completion: (() -> Void)? = nil) {
        let animation = UIViewPropertyAnimator(duration: 0.35, curve: .linear) {
            animations()
        }
        animation.addCompletion { _ in
            completion?()
        }

        animation.startAnimation()
        if !animated {
            animation.stopAnimation(false)
            animation.finishAnimation(at: .end)
        }
    }

    /// Fade in and animate the cells of the collection view
    private func animateCollectionViewCells() {
        // `layoutIfNeeded` forces the collectionView to add cells and headers
        collectionView.layoutIfNeeded()
        collectionView.isHidden = false
        
        let cells = collectionView.visibleCells as [UIView]
        let headers = collectionView.visibleSupplementaryViews(ofKind: UICollectionElementKindSectionHeader) as [UIView]
        let views = (cells + headers).sorted {
            $0.convert($0.bounds, to: nil).minY < $1.convert($1.bounds, to: nil).minY
        }
        
        for view in views {
            view.transform = CGAffineTransform(translationX: 0.0, y: 32.0)
            view.alpha = 0.0
        }
        
        var delay: TimeInterval = 0.15
        for view in views {
            delay += 0.08
            UIView.animate(withDuration: 0.55, delay: delay, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: [.allowUserInteraction], animations: {
                view.transform = .identity
                view.alpha = 1.0
            }, completion: nil)
        }
    }

    // MARK: Refresh

    @objc private func refreshEateries(_ sender: Any) {
        delegate?.eateriesViewControllerDidRefreshEateries(self)
        
        refreshControl.endRefreshing()
    }

    // MARK: Data Source Callers

    private func eateriesByGroup(from eateries: [Eatery], sortedUsing sortMethod: SortMethod) -> EateriesByGroup {
        let sortedEateries: [Eatery]

        switch sortMethod {
        case .alphabetical:
            sortedEateries = eateries.sorted { $0.displayName < $1.displayName }
        case let .nearest(location):
            sortedEateries = eateries.sorted { $0.location.distance(from: location) < $1.location.distance(from: location) }
        }

        let favorites = sortedEateries.filter { $0.isFavorite }
        let open = sortedEateries.filter { !$0.isFavorite && $0.isOpen(atExactly: Date()) }
        let closed = sortedEateries.filter { !$0.isFavorite && !$0.isOpen(atExactly: Date()) }
        return [.favorites: favorites, .open: open, .closed: closed]
    }

    private func reloadEateries() {
        if let dataSource = dataSource {
            let searchText = searchBar.text ?? ""
            let eateries = dataSource.eateriesViewController(self,
                                                             eateriesToPresentWithSearchText: searchText,
                                                             filters: filterBar.selectedFilters)

            let sortMethod = dataSource.eateriesViewController(self,
                                                               sortMethodWithSearchText: searchText,
                                                               filters: filterBar.selectedFilters)

            eateriesByGroup = eateriesByGroup(from: eateries, sortedUsing: sortMethod)
        } else {
            eateriesByGroup = [:]
        }

        collectionView.reloadData()
    }

    private func highlightedText(for eatery: Eatery) -> NSAttributedString? {
        let searchText = searchBar.text ?? ""
        return dataSource?.eateriesViewController(self,
                                                  highlightedSearchDescriptionForEatery: eatery,
                                                  searchText: searchText,
                                                  filters: filterBar.selectedFilters)
    }

    // MARK: Map View

    func pushMapViewController() {
        delegate?.eateriesViewControllerDidPushMapViewController(self)
    }

    // MARK: Scroll View
    
    func scrollToTop() {
        if collectionView.contentOffset.y > 0 {
            let contentOffset = -(filterBar.frame.height + (navigationController?.navigationBar.frame.height ?? 0))
            collectionView.setContentOffset(CGPoint(x: 0, y: contentOffset), animated: true)
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        gridLayout.invalidateLayout()
    }

}

// MARK: - Collection View Helper Methods

extension EateriesViewController {

    private func eateries(in section: Int) -> [Eatery] {
        return eateriesByGroup?[presentedGroups[section - 1]] ?? []
    }

}

// MARK: - Collection View Data Source

extension EateriesViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1 + presentedGroups.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            return eateries(in: section).count
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CellIdentifier.container.rawValue, for: indexPath)
            
            cell.contentView.addSubview(searchFilterContainer)
            searchFilterContainer.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            return cell
            
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CellIdentifier.eatery.rawValue, for: indexPath) as! EateryCollectionViewCell
            let eatery = eateries(in: indexPath.section)[indexPath.row]
            cell.eatery = eatery
            cell.userLocation = userLocation
            
            cell.backgroundImageView.hero.id = AnimationKey.backgroundImageView.id(eatery: eatery)
            cell.titleLabel.hero.id = AnimationKey.title.id(eatery: eatery)
            cell.timeLabel.hero.modifiers = [.useGlobalCoordinateSpace, .fade]
            cell.statusLabel.hero.modifiers = [.useGlobalCoordinateSpace, .fade]
            cell.distanceLabel.hero.id = AnimationKey.distanceLabel.id(eatery: eatery)
            cell.paymentView.hero.id = AnimationKey.paymentView.id(eatery: eatery)
            cell.infoContainer.hero.id = AnimationKey.infoContainer.id(eatery: eatery)
            
            if .presenting == state,
                let searchText = searchBar.text, !searchText.isEmpty,
                let text = highlightedText(for: eatery) {
                cell.menuTextView.attributedText = text
                cell.isMenuTextViewVisible = true
            } else {
                cell.isMenuTextViewVisible = false
            }
            
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if indexPath.section == 0 {
            // This header should never be called since collectionView(layout:referenceSizeForHeaderInSection) should
            // return CGSize.zero for section 0, but to be safe an empty header view is provided
            return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SupplementaryViewIdentifier.empty.rawValue, for: indexPath)
        } else {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SupplementaryViewIdentifier.header.rawValue, for: indexPath) as! EateriesCollectionViewHeaderView
            
            let group = presentedGroups[indexPath.section - 1]
            switch group {
            case .favorites:
                header.titleLabel.text = "Favorites"
                header.titleLabel.textColor = .eateryBlue
            case .open:
                header.titleLabel.text = "Open"
                header.titleLabel.textColor = .eateryBlue
            case .closed:
                header.titleLabel.text = "Closed"
                header.titleLabel.textColor = .gray
            }
            
            return header
        }
    }

}

// MARK: - Collection View Delegate

extension EateriesViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let eatery = eateries(in: indexPath.section)[indexPath.row]
        delegate?.eateriesViewController(self, didSelectEatery: eatery)
    }

    // Cell "Bounce" when selected

    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath),
            cell.reuseIdentifier == CellIdentifier.eatery.rawValue else {
                return
        }

        UIView.animate(withDuration: 0.35,
                       delay: 0.0,
                       usingSpringWithDamping: 1.0,
                       initialSpringVelocity: 0.0,
                       options: [],
                       animations: {
            cell.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        })
    }

    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath),
            cell.reuseIdentifier == CellIdentifier.eatery.rawValue else {
                return
        }

        UIView.animate(withDuration: 0.35,
                       delay: 0.0,
                       usingSpringWithDamping: 1.0,
                       initialSpringVelocity: 0.0,
                       options: [],
                       animations: {
            cell.transform = .identity
        })
    }

}

// MARK: - Collection View Delegate Flow Layout

extension EateriesViewController: UICollectionViewDelegateFlowLayout {
 
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        if indexPath.section == 0 {
            let height = searchFilterContainer.systemLayoutSizeFitting(UILayoutFittingCompressedSize).height
            return CGSize(width: collectionView.bounds.width, height: height)
        } else {
            return gridLayout.itemSize
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if section == 0 {
            return .zero
        } else {
            return gridLayout.sectionInset
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == 0 {
            // Returning CGSize.zero here causes the collectionView to not
            // query for a header at all
            return .zero
        } else {
            return gridLayout.headerReferenceSize
        }
    }
    
}

// MARK: - Search Bar Delegate

extension EateriesViewController: UISearchBarDelegate {

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        reloadEateries()
        searchBar.becomeFirstResponder()
    }

    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        return true
    }

}

// MARK: - Filter Bar

extension EateriesViewController: FilterBarDelegate {

    func filterBar(_ filterBar: FilterBar, selectedFiltersDidChange newValue: [Filter]) {
        reloadEateries()
    }

}

// MARK: - Failed To Load View

extension EateriesViewController: EateriesFailedToLoadViewDelegate {

    func eateriesFailedToLoadViewPressedRetryButton(_ eftlv: EateriesFailedToLoadView) {
        delegate?.eateriesViewControllerDidPressRetryButton(self)
    }

}

// MARK: - Scroll View Delegate

extension EateriesViewController: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollDelegate?.eateriesViewController(self, scrollViewWillBeginDragging: scrollView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            scrollDelegate?.eateriesViewController(self, scrollViewDidStopScrolling: scrollView)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollDelegate?.eateriesViewController(self, scrollViewDidStopScrolling: scrollView)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        searchBar.resignFirstResponder()
        
        transformAppDevLogo()
        
        scrollDelegate?.eateriesViewController(self, scrollViewDidScroll: scrollView)
    }

    /// Change the appearance of the AppDev logo based on the current scroll
    /// position of the collection view
    private func transformAppDevLogo() {
        guard let appDevLogo = appDevLogo else {
            return
        }

        var offset = collectionView.contentOffset.y
        if #available(iOS 11.0, *) {
            offset += collectionView.adjustedContentInset.top
        } else {
            offset += collectionView.contentInset.top
        }

        appDevLogo.alpha = min(0.9, (-15.0 - offset) / 100.0)

        let margin: CGFloat = 4.0
        let width = appDevLogo.frame.width
        let navBarWidth = (navigationController?.navigationBar.frame.width ?? 0.0) / 2
        let navBarHeight = (navigationController?.navigationBar.frame.height ?? 0.0) / 2

        appDevLogo.transform = CGAffineTransform(translationX: navBarWidth - margin - width, y: navBarHeight - margin - width)
        appDevLogo.tintColor = .white
    }

}

// MARK: - Menu Buttons Delegate

extension EateriesViewController: MenuButtonsDelegate {

    func favoriteButtonPressed(on menuHeaderView: MenuHeaderView) {
        reloadEateries()
    }

}

