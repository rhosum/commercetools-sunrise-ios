//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveSwift
import Result
import Commercetools

/// The key used for storing logged in username.
let kMyStoreId = "MyStoreId"

class AccountViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Observer<Void, NoError>
    let sectionExpandedObserver: Observer<Int, NoError>
    let backButtonObserver: Observer<Void, NoError>

    // Outputs
    let isLoading: MutableProperty<Bool>
    let contentChangesSignal: Signal<Changeset, NoError>
    let showReservationSignal: Signal<IndexPath, NoError>
    let ordersExpanded = MutableProperty(false)
    let reservationsExpanded = MutableProperty(false)
    let myStore: MutableProperty<Channel?>
    let navigationShouldPop = MutableProperty(true)
    let backButtonSignal: Signal<Void, NoError>

    var orders = [Order]()
    var reservations = [Order]()

    private let contentChangesObserver: Observer<Changeset, NoError>
    private let showReservationObserver: Observer<IndexPath, NoError>

    /// The UUID of the reservation confirmation received via push notification, to be shown after next refresh.
    private var reservationConfirmationId: String? = nil

    // MARK: - Lifecycle

    override init() {
        isLoading = MutableProperty(true)
        myStore = MutableProperty(nil)

        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        let (sectionExpandedSignal, expandedObserver) = Signal<Int, NoError>.pipe()
        sectionExpandedObserver = expandedObserver

        (contentChangesSignal, contentChangesObserver) = Signal<Changeset, NoError>.pipe()

        (backButtonSignal, backButtonObserver) = Signal<Void, NoError>.pipe()

        (showReservationSignal, showReservationObserver) = Signal<IndexPath, NoError>.pipe()

        super.init()

        refreshSignal
        .observeValues { [weak self] in
            self?.retrieveOrders()
        }

        isLoading.signal.observeValues { [weak self] isLoading in
            if let id = self?.reservationConfirmationId, let row = self?.reservations.index(where: { $0.id == id }), !isLoading {
                self?.showReservationObserver.send(value: IndexPath(row: row, section: 1))
            }
        }

        sectionExpandedSignal
        .observeValues { [weak self] section in
            guard let strongSelf = self else { return }

            let rowsCount = section == 1 ? strongSelf.orders.count : strongSelf.reservations.count
            let rowsToModify = 0...(rowsCount > 0 ? rowsCount - 1 : 0)
            let indexPaths = rowsCount > 0 ? rowsToModify.map { IndexPath(row: $0, section: section) } : []

            let changeset: Changeset
            if section == 1 {
                if strongSelf.ordersExpanded.value {
                    changeset = Changeset(deletions: indexPaths)
                } else {
                    changeset = Changeset(insertions: indexPaths)
                }
                strongSelf.ordersExpanded.value = !strongSelf.ordersExpanded.value
            } else {
                if strongSelf.reservationsExpanded.value {
                    changeset = Changeset(deletions: indexPaths)
                } else {
                    changeset = Changeset(insertions: indexPaths)
                }
                strongSelf.reservationsExpanded.value = !strongSelf.reservationsExpanded.value
            }
            strongSelf.contentChangesObserver.send(value: changeset)
        }
    }

    func orderOverviewViewModelForOrderAtIndexPath(_ indexPath: IndexPath) -> OrderOverviewViewModel? {
        if indexPath.section == 1 {
            let orderOverviewViewModel = OrderOverviewViewModel()
            orderOverviewViewModel.order.value = orders[indexPath.row]
            return orderOverviewViewModel
        }
        return nil
    }

    func reservationViewModelForOrderAtIndexPath(_ indexPath: IndexPath) -> ReservationViewModel? {
        if indexPath.section == 2 {
            return ReservationViewModel(order: reservations[indexPath.row])
        }
        return nil
    }

    // MARK: - Data Source

    func numberOfRowsInSection(_ section: Int) -> Int {
        switch section {
            case 1:
                return ordersExpanded.value ? orders.count : 0
            case 2:
                return reservationsExpanded.value ? reservations.count : 0
            default:
                return 0
        }
    }

    func headerTitleForSection(_ section: Int) -> String {
        return section == 1 ? NSLocalizedString("MY ORDERS", comment: "My orders") : NSLocalizedString("MY RESERVATIONS", comment: "My reservations")
    }

    func orderNumberAtIndexPath(_ indexPath: IndexPath) -> String? {
        return (indexPath.section == 1 ? orders[indexPath.row].orderNumber : reservations[indexPath.row].orderNumber) ?? "            N/A            "
    }

    func totalPriceAtIndexPath(_ indexPath: IndexPath) -> String? {
        return indexPath.section == 1 ? orders[indexPath.row].totalPrice?.description : reservations[indexPath.row].totalPrice?.description
    }

    // MARK: - Presenting reservation confirmation from push notification

    func presentConfirmationForReservationWithId(_ reservationId: String) {
        if let row = reservations.index(where: { $0.id == reservationId }) {
            showReservationObserver.send(value: IndexPath(row: row, section: 1))

        } else if !isLoading.value {
            reservationConfirmationId = reservationId
            refreshObserver.send(value: ())
        }
    }

    // MARK: - Commercetools product projections querying

    private func retrieveOrders() {
        isLoading.value = true

        Order.query(sort: ["createdAt desc"], expansion: ["lineItems[0].distributionChannel"], result: { result in
            if let orders = result.model?.results, result.isSuccess {
                self.orders = orders.filter { $0.isReservation != true }
                self.reservations = orders.filter { $0.isReservation == true }

            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))

            }
            self.isLoading.value = false
        })
        AppDelegate.shared.saveDeviceTokenForCurrentCustomer()
    }

    private func retrieveMyStoreDetails() {
        if let myStoreId = UserDefaults.standard.string(forKey: kMyStoreId) {
            // retrieve stores
        }
    }

    // MARK: - Customer logout

    func logoutCustomer() {
        isLoading.value = true
        UserDefaults.standard.removeObject(forKey: kLoggedInUsername)
        UserDefaults.standard.synchronize()
        Customer.profile { result in
            if let customerVersion = result.model?.version, result.isSuccess {
                let options = SetCustomTypeOptions()
                let updateActions = UpdateActions<CustomerUpdateAction>(version: customerVersion, actions: [.setCustomType(options: options)])
                Customer.update(actions: updateActions) { _ in
                    DispatchQueue.main.async {
                        Commercetools.logoutCustomer()
                        AppRouting.setupMyAccountRootViewController()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    Commercetools.logoutCustomer()
                    AppRouting.setupMyAccountRootViewController()
                }
            }
        }
    }
}
