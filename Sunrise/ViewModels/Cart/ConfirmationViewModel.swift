//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class ConfirmationViewModel: BaseViewModel {

    // Inputs

    // Outputs
    let isLoading = MutableProperty(false)
    let orderCreatedSignal: Signal<Void, NoError>

    let shippingFirstName: MutableProperty<String?> = MutableProperty(nil)
    let shippingLastName: MutableProperty<String?> = MutableProperty(nil)
    let shippingStreetName: MutableProperty<String?> = MutableProperty(nil)
    let shippingCity: MutableProperty<String?> = MutableProperty(nil)
    let shippingPostalCode: MutableProperty<String?> = MutableProperty(nil)
    let shippingRegion: MutableProperty<String?> = MutableProperty(nil)
    let shippingCountry: MutableProperty<String?> = MutableProperty(nil)

    let billingFirstName: MutableProperty<String?> = MutableProperty(nil)
    let billingLastName: MutableProperty<String?> = MutableProperty(nil)
    let billingStreetName: MutableProperty<String?> = MutableProperty(nil)
    let billingCity: MutableProperty<String?> = MutableProperty(nil)
    let billingPostalCode: MutableProperty<String?> = MutableProperty(nil)
    let billingRegion: MutableProperty<String?> = MutableProperty(nil)
    let billingCountry: MutableProperty<String?> = MutableProperty(nil)

    let shippingMethodName: MutableProperty<String?> = MutableProperty(nil)
    let shippingMethodDescription: MutableProperty<String?> = MutableProperty(nil)
    let payment: MutableProperty<String?> = MutableProperty(nil)

    let orderCreatedTitle = NSLocalizedString("Thank you ", comment: "Order Created")
    let orderCreatedMessage = NSLocalizedString("Your order has been successfully created", comment: "Your order has been successfully created")

    lazy var continueCheckoutAction: Action<Void, Void, CTError> = { [unowned self] in
        return Action(enabledIf: Property(value: true), { [unowned self] _ in
            self.createOrder()
            return SignalProducer.empty
        })
    }()

    private let disposables = CompositeDisposable()
    private let cart: MutableProperty<Cart?>
    private let orderCreatedObserver: Observer<Void, NoError>
    private let currentLocale = NSLocale.init(localeIdentifier: NSLocale.current.identifier)

    // MARK: - Lifecycle

    init(cart: Cart? = nil) {
        self.cart = MutableProperty(cart)
        (orderCreatedSignal, orderCreatedObserver) = Signal<Void, NoError>.pipe()

        super.init()

        shippingFirstName <~ self.cart.map { cart in
            let address = cart?.shippingAddress
            if let title = address?.title, title != "" {
                return "\(title) \(address?.firstName ?? "")"
            }
            return address?.firstName ?? ""
        }
        shippingLastName <~ self.cart.map { return $0?.shippingAddress?.lastName }
        shippingStreetName <~ self.cart.map { return ($0?.shippingAddress?.streetName ?? "") + " " + ($0?.shippingAddress?.additionalStreetInfo ?? "") }
        shippingCity <~ self.cart.map { return $0?.shippingAddress?.city }
        shippingPostalCode <~ self.cart.map { return $0?.shippingAddress?.postalCode }
        shippingRegion <~ self.cart.map { return $0?.shippingAddress?.region }
        shippingCountry <~ self.cart.map { [weak self] in
            guard let countryCode = $0?.shippingAddress?.country else { return "" }
            return self?.currentLocale.displayName(forKey: NSLocale.Key.countryCode, value: countryCode) ?? countryCode
        }
        billingFirstName <~ self.cart.map { cart in
            let address = cart?.billingAddress
            if let title = address?.title, title != "" {
                return "\(title) \(address?.firstName ?? "")"
            }
            return address?.firstName ?? ""
        }
        billingLastName <~ self.cart.map { return $0?.billingAddress?.lastName }
        billingStreetName <~ self.cart.map { return ($0?.billingAddress?.streetName ?? "") + " " + ($0?.billingAddress?.additionalStreetInfo ?? "") }
        billingCity <~ self.cart.map { return $0?.billingAddress?.city }
        billingPostalCode <~ self.cart.map { return $0?.billingAddress?.postalCode }
        billingRegion <~ self.cart.map { return $0?.billingAddress?.region }
        billingCountry <~ self.cart.map { [weak self] in
            guard let countryCode = $0?.billingAddress?.country else { return "" }
            return self?.currentLocale.displayName(forKey: NSLocale.Key.countryCode, value: countryCode) ?? countryCode
        }

        shippingMethodName <~ self.cart.map { return $0?.shippingInfo?.shippingMethod?.obj?.name }
        shippingMethodDescription <~ self.cart.map { return $0?.shippingInfo?.shippingMethod?.obj?.description }
        payment.value = "Prepaid" // TODO: remove once we have the API support for payments

        if self.cart.value == nil {
            retrieveCart()
        }
    }

    deinit {
        disposables.dispose()
    }

    // MARK: - Cart retrieval, order creation

    private func retrieveCart() {
        Cart.active(expansion: ["shippingInfo.shippingMethod"]) { result in
            if let cart = result.model, result.isSuccess {
                self.cart.value = cart
            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
            self.isLoading.value = false
        }
    }

    private func createOrder() {
        guard let id = cart.value?.id, let version = cart.value?.version else { return }
        isLoading.value = false

        var orderDraft = OrderDraft()
        orderDraft.id = id
        orderDraft.version = version

        Order.create(orderDraft, expansion: nil, result: { result in
            if result.isSuccess {
                self.orderCreatedObserver.send(value: ())
            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
            self.isLoading.value = false
        })
    }
}