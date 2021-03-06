//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import IntentsUI

class OrderDetailsViewController: UIViewController {

    @IBOutlet weak var orderCreatedLabel: UILabel!
    @IBOutlet weak var orderNumberLabel: UILabel!
    @IBOutlet weak var expectedDeliveryLabel: UILabel!
    @IBOutlet weak var deliveryAddressLabel: UILabel!
    @IBOutlet weak var totalLabel: UILabel!
    @IBOutlet weak var cardInfoLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var orderSummaryView: UIView!
    
    @IBOutlet weak var closeButtonTopSpaceConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollViewContentHeightConstraint: NSLayoutConstraint!
    
    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: OrderDetailsViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 11.0, *), let safeAreaTop = UIView.safeAreaFrame?.origin.y {
            closeButtonTopSpaceConstraint.constant = safeAreaTop + 14
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIView.animate(withDuration: 0.3) {
            SunriseTabBarController.currentlyActive?.navigationView.alpha = 0
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        UIView.animate(withDuration: 0.3) {
            SunriseTabBarController.currentlyActive?.navigationView.alpha = 1
        }
        super.viewWillDisappear(animated)
    }

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += orderCreatedLabel.reactive.text <~ viewModel.orderCreated
        disposables += orderNumberLabel.reactive.text <~ viewModel.orderNumber
        disposables += deliveryAddressLabel.reactive.text <~ viewModel.deliveryAddress
        disposables += totalLabel.reactive.text <~ viewModel.orderTotal

        self.tableView.reloadData()
        DispatchQueue.main.async {
            let newHeight = (0..<viewModel.numberOfLineItems).reduce(CGFloat(0), { $0 + self.tableView.rectForRow(at: IndexPath(row: $1, section: 0)).height })
            self.scrollViewContentHeightConstraint.constant += newHeight - self.tableViewHeightConstraint.constant
            self.tableViewHeightConstraint.constant = newHeight
        }

        if #available(iOS 12.0, *), let shortcut = INShortcut(intent: viewModel.orderIntent) {
            addSiriShortcutButton(for: shortcut)
        }
    }

    @available(iOS 12.0, *)
    private func addSiriShortcutButton(for shortcut: INShortcut) {
        let addShortcutButton = INUIAddVoiceShortcutButton(style: .whiteOutline)
        addShortcutButton.shortcut = shortcut
        addShortcutButton.delegate = self

        addShortcutButton.translatesAutoresizingMaskIntoConstraints = false
        orderSummaryView.addSubview(addShortcutButton)
        addShortcutButton.topAnchor.constraint(equalTo: cardInfoLabel.bottomAnchor, constant: 30).isActive = true
        orderSummaryView.centerXAnchor.constraint(equalTo: addShortcutButton.centerXAnchor).isActive = true
    }

    @IBAction func closeOrderDetails(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
}

extension OrderDetailsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfLineItems ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LineItemCell") as! CheckoutLineItemCell
        guard let viewModel = viewModel else { return cell }
        cell.productNameLabel.text = viewModel.lineItemName(at: indexPath)
        cell.quantityLabel.text = viewModel.lineItemQuantity(at: indexPath)
        cell.priceLabel.text = viewModel.lineItemPrice(at: indexPath)
        return cell
    }
}

@available(iOS 12.0, *)
extension OrderDetailsViewController: INUIAddVoiceShortcutButtonDelegate {
    func present(_ addVoiceShortcutViewController: INUIAddVoiceShortcutViewController, for addVoiceShortcutButton: INUIAddVoiceShortcutButton) {
        addVoiceShortcutViewController.delegate = self
        present(addVoiceShortcutViewController, animated: true)
    }

    func present(_ editVoiceShortcutViewController: INUIEditVoiceShortcutViewController, for addVoiceShortcutButton: INUIAddVoiceShortcutButton) {
        editVoiceShortcutViewController.delegate = self
        present(editVoiceShortcutViewController, animated: true)
    }
}

@available(iOS 12.0, *)
extension OrderDetailsViewController: INUIAddVoiceShortcutViewControllerDelegate {
    func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController, didFinishWith voiceShortcut: INVoiceShortcut?, error: Error?) {
        if let error = error {
            debugPrint(error)
        }
        controller.dismiss(animated: true)
    }

    func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
        controller.dismiss(animated: true)
    }
}

@available(iOS 12.0, *)
extension OrderDetailsViewController: INUIEditVoiceShortcutViewControllerDelegate {
    func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController, didUpdate voiceShortcut: INVoiceShortcut?, error: Error?) {
        if let error = error {
            debugPrint(error)
        }
        controller.dismiss(animated: true)
    }

    func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController, didDeleteVoiceShortcutWithIdentifier deletedVoiceShortcutIdentifier: UUID) {
        controller.dismiss(animated: true)
    }

    func editVoiceShortcutViewControllerDidCancel(_ controller: INUIEditVoiceShortcutViewController) {
        controller.dismiss(animated: true)
    }
}

extension UIView {
    @available(iOS 11, *)
    static var safeAreaFrame: CGRect? {
        return UIApplication.shared.keyWindow?.rootViewController?.view.safeAreaLayoutGuide.layoutFrame
    }
}
