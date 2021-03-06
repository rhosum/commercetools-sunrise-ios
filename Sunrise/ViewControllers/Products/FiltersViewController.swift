//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit
import ReactiveSwift
import ReactiveCocoa

class FiltersViewController: UIViewController {
    
    @IBOutlet weak var aToGBrandButton: UIButton!
    @IBOutlet weak var hToQBrandButton: UIButton!
    @IBOutlet weak var rToZBrandButton: UIButton!
    @IBOutlet weak var symbolBrandButton: UIButton!
    @IBOutlet weak var resetFiltersButton: UIButton!
    @IBOutlet weak var doneButton: UIButton!

    @IBOutlet weak var lowerPriceLabel: UILabel!
    @IBOutlet weak var higherPriceLabel: UILabel!
    
    @IBOutlet weak var priceSlider: RangeSlider!
    
    @IBOutlet weak var myStyleSwitch: UISwitch!

    @IBOutlet weak var brandsCollectionView: UICollectionView!
    @IBOutlet weak var sizesCollectionView: UICollectionView!
    @IBOutlet weak var colorsCollectionView: UICollectionView!

    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: FiltersViewModel? {
        didSet {
            bindViewModel()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        myStyleSwitch.onTintColor = UIColor(patternImage: #imageLiteral(resourceName: "switch_background"))

        viewModel = FiltersViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.isActive.value = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        viewModel?.isActive.value = false
        super.viewWillDisappear(animated)
    }

    func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += viewModel.isLoading.producer
        .filter { !$0 }
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] _ in
            [self.brandsCollectionView, self.sizesCollectionView, self.colorsCollectionView].forEach { $0.reloadData() }
            if let visibleIndexPath = self.brandsCollectionView.indexPathForItem(at: self.brandsCollectionView.contentOffset) {
                self.viewModel?.visibleBrandIndex.value = visibleIndexPath
            }
        }

        let brandButtons = [aToGBrandButton, hToQBrandButton, rToZBrandButton, symbolBrandButton]
        disposables += viewModel.activeBrandButtonIndex.producer
        .skipRepeats()
        .observe(on: UIScheduler())
        .startWithValues {
            brandButtons.forEach { $0?.isSelected = false }
            brandButtons[$0]?.isSelected = true
        }

        disposables += viewModel.scrollBrandAction.values
        .filter { $0 != nil }
        .observe(on: UIScheduler())
        .observeValues { [unowned self] in
            self.brandsCollectionView.scrollToItem(at: $0!, at: .left, animated: true)
        }

        disposables += viewModel.priceRange.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] in
            guard !self.priceSlider.isTracking else { return }
            self.priceSlider.lowerValue = Double($0.0)
            self.priceSlider.upperValue = Double($0.1)
        }

        disposables += myStyleSwitch.reactive.isOnValues
        .observeValues { [unowned self] in
            self.viewModel?.toggleMyStyleObserver.send(value: $0)
        }

        disposables += viewModel.priceRange <~ priceSlider.reactive.mapControlEvents(.valueChanged) { (Int($0.lowerValue), Int($0.upperValue)) }
        viewModel.priceSetSignal = priceSlider.reactive.mapControlEvents(.editingDidEnd) { _ in }
        disposables += lowerPriceLabel.reactive.text <~ viewModel.lowerPrice
        disposables += higherPriceLabel.reactive.text <~ viewModel.higherPrice
        disposables += myStyleSwitch.reactive.isOn <~ viewModel.isMyStyleApplied

        aToGBrandButton.reactive.pressed = CocoaAction(viewModel.scrollBrandAction) { _ in return 0 }
        hToQBrandButton.reactive.pressed = CocoaAction(viewModel.scrollBrandAction) { _ in return 1 }
        rToZBrandButton.reactive.pressed = CocoaAction(viewModel.scrollBrandAction) { _ in return 2 }
        symbolBrandButton.reactive.pressed = CocoaAction(viewModel.scrollBrandAction) { _ in return 3 }
        resetFiltersButton.reactive.pressed = CocoaAction(viewModel.resetFiltersAction)

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }
    
    @IBAction func closeFilters(_ sender: UIButton? = nil) {
        guard let mainViewController = parent as? MainViewController else { return }
        if mainViewController.searchFilterBackgroundTopConstraint.isActive {
            mainViewController.searchFilter(mainViewController.searchFilterButton)
        } else {
            mainViewController.filter(mainViewController.filterButton)
        }
    }
}

extension FiltersViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }
        switch collectionView {
            case brandsCollectionView:
                return viewModel.numberOfBrands
            case sizesCollectionView:
                return viewModel.numberOfSizes
            case colorsCollectionView:
                return viewModel.numberOfColors
            default:
                return 1
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch collectionView {
            case brandsCollectionView:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BrandCell", for: indexPath) as! BrandCell
                cell.brandLabel.text = viewModel?.brandName(at: indexPath)
                cell.selectedBrandImageView.isHidden = viewModel?.isBrandActive(at: indexPath) == false
                return cell
            case sizesCollectionView:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SizeCell", for: indexPath) as! SizeCell
                cell.sizeLabel.text = viewModel?.sizeName(at: indexPath)
                cell.selectedSizeImageView.isHidden = viewModel?.isSizeActive(at: indexPath) == false
                cell.sizeLabel.textColor = viewModel?.isSizeActive(at: indexPath) == true ? .white : UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0)
                return cell
            case colorsCollectionView:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ColorCell", for: indexPath) as! ColorCell
                cell.colorView.backgroundColor = viewModel?.color(at: indexPath)
                cell.selectedColorImageView.image = viewModel?.color(at: indexPath) != .white ? #imageLiteral(resourceName: "selected_color") : #imageLiteral(resourceName: "selected_color_inverted")
                cell.selectedColorImageView.isHidden = viewModel?.isColorActive(at: indexPath) == false
                return cell
            default:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProductTypeCell", for: indexPath) as! ProductTypeCell
                cell.selectedProductImageView.isHidden = false
                return cell
        }
    }
}

extension FiltersViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch collectionView {
        case brandsCollectionView:
            viewModel?.toggleBrandObserver.send(value: indexPath)
        case sizesCollectionView:
            viewModel?.toggleSizeObserver.send(value: indexPath)
        case colorsCollectionView:
            viewModel?.toggleColorObserver.send(value: indexPath)
        default:
            return
        }
    }
}

extension FiltersViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let visibleIndexPath = brandsCollectionView.indexPathForItem(at: scrollView.contentOffset), scrollView == brandsCollectionView {
            viewModel?.visibleBrandIndex.value = visibleIndexPath
        }
    }
}
