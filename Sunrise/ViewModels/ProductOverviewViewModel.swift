//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveCocoa
import Result
import ObjectMapper
import Commercetools

class ProductOverviewViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Observer<Void, NoError>
    let nextPageObserver: Observer<Void, NoError>
    let searchText = MutableProperty("")

    // Outputs
    let title: String
    let isLoading: MutableProperty<Bool>

    let pageSize: UInt = 16
    var products: [ProductProjection]

    // MARK: - Lifecycle

    override init() {
        products = []

        title = NSLocalizedString("Products", comment: "POP Title")

        isLoading = MutableProperty(true)

        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        let (nextPageSignal, pageObserver) = Signal<Void, NoError>.pipe()
        nextPageObserver = pageObserver

        super.init()

        refreshSignal
        .observeNext { [weak self] in
            self?.queryForProductProjections(offset: 0)
        }

        nextPageSignal
        .observeNext { [weak self] in
            if let productCount = self?.products.count where productCount > 0 {
                self?.queryForProductProjections(offset: UInt(productCount), text: self?.searchText.value ?? "")
            }
        }

        searchText.signal
        .observeNext({ [weak self] searchText in
            self?.queryForProductProjections(offset: 0, text: searchText)
        })
    }

    func productDetailsViewModelForProductAtIndexPath(indexPath: NSIndexPath) -> ProductViewModel {
        let product = products[indexPath.row]
        return ProductViewModel(product: product)
    }

    // MARK: - Data Source

    func numberOfProductsInSection(section: Int) -> Int {
        return products.count
    }

    func productNameAtIndexPath(indexPath: NSIndexPath) -> String {
        return products[indexPath.row].name?.localizedString ?? ""
    }

    func productImageUrlAtIndexPath(indexPath: NSIndexPath) -> String {
        return products[indexPath.row].mainVariantWithPrice?.images?.first?.url ?? ""
    }

    func productPriceAtIndexPath(indexPath: NSIndexPath) -> String {
        guard let price = products[indexPath.row].mainVariantWithPrice?.independentPrice, value = price.value else { return "" }

        if let discounted = price.discounted?.value {
            return discounted.description
        } else {
            return value.description
        }
    }

    func productOldPriceAtIndexPath(indexPath: NSIndexPath) -> String {
        guard let price = products[indexPath.row].mainVariantWithPrice?.independentPrice, value = price.value,
        _ = price.discounted?.value else { return "" }

        return value.description
    }

    // MARK: - Commercetools product projections querying

    private func queryForProductProjections(offset offset: UInt, text: String = "") {
        isLoading.value = true

        Commercetools.ProductProjection.search(sort: ["createdAt desc"], limit: pageSize, offset: offset,
                lang: NSLocale(localeIdentifier: "en"), text: text, result: { result in
            if let results = result.response?["results"] as? [[String: AnyObject]],
            products = Mapper<ProductProjection>().mapArray(results) where result.isSuccess {
                self.products = offset == 0 ? products : self.products + products

            } else if let errors = result.errors where result.isFailure {
                super.alertMessageObserver.sendNext(self.alertMessageForErrors(errors))

            }
            self.isLoading.value = false
        })
    }



}