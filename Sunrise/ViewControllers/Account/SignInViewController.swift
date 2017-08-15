//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import CoreNFC
import Commercetools
import ReactiveCocoa
import ReactiveSwift
import Result
import SDWebImage
import SVProgressHUD
import IQDropDownTextField

class SignInViewController: UIViewController {
    
    @IBInspectable var borderColor: UIColor = UIColor.lightGray
    
    @IBOutlet weak var loginFormView: UIView!
    @IBOutlet weak var registerFormView: UIView!

    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var nfcLoginButton: UIButton!
    
    @IBOutlet weak var titleField: IQDropDownTextField!
    @IBOutlet weak var registrationEmailField: UITextField!
    @IBOutlet weak var firstNameField: UITextField!
    @IBOutlet weak var lastNameField: UITextField!
    @IBOutlet weak var registrationPasswordField: UITextField!
    @IBOutlet weak var registrationPasswordConfirmationField: UITextField!

    private var nfcSession: Any?
    private var loginAction: CocoaAction<Void>?
    private var registerAction: CocoaAction<Void>?
    private let disposables = CompositeDisposable()
    
    deinit {
        disposables.dispose()
    }

    private var viewModel: SignInViewModel? {
        didSet {
            bindViewModel()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        emailField.keyboardType = .emailAddress
        registrationEmailField.keyboardType = .emailAddress
        titleField.dropDownMode = .textPicker

        [loginFormView, registerFormView].forEach {
            $0.layer.borderColor = borderColor.cgColor
        }


        [emailField, passwordField, registrationEmailField, firstNameField, lastNameField,
                titleField, registrationPasswordField, registrationPasswordConfirmationField].forEach {
            $0?.layer.borderColor = borderColor.cgColor
            $0?.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 7, height: ($0?.frame.height)!))
            $0?.leftViewMode = .always
        }

        viewModel = SignInViewModel()
    }

    @IBAction func logIn(_ sender: UIButton) {
        loginAction?.execute(())
    }
    
    @IBAction func register(_ sender: UIButton) {
        guard let viewModel = viewModel else { return }

        if viewModel.isRegisterInputValid.value {
            registerAction?.execute(())
        } else {
            let alertController = UIAlertController(
                    title: viewModel.failedTitle,
                    message: viewModel.registrationGuide,
                    preferredStyle: .alert
                    )
            alertController.addAction(UIAlertAction(title: viewModel.okAction, style: .cancel, handler: nil))
            present(alertController, animated: true, completion: nil)
        }
    }
    
    @IBAction func nfcLogIn(_ sender: UIButton) {
        if #available(iOS 11.0, *) {
            let nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
            nfcSession.alertMessage = viewModel?.nfcGuide ?? ""
            self.nfcSession = nfcSession
            nfcSession.begin()
        }
    }
    
    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel else { return }

        if viewModel.isLoggedIn {
            AppRouting.setupMyAccountRootViewController()
        }

        loginAction = CocoaAction(viewModel.loginAction, { _ in return () })
        registerAction = CocoaAction(viewModel.registerAction, { _ in return () })

        viewModel.username <~ emailField.reactive.continuousTextValues.map { $0 ?? "" }
        viewModel.password <~ passwordField.reactive.continuousTextValues.map { $0 ?? "" }
        viewModel.email <~ registrationEmailField.reactive.continuousTextValues.map { $0 ?? "" }
        viewModel.firstName <~ firstNameField.reactive.continuousTextValues.map { $0 ?? "" }
        viewModel.lastName <~ lastNameField.reactive.continuousTextValues.map { $0 ?? "" }
        viewModel.title <~ titleField.reactive.textValues.map { $0 ?? "" }
        viewModel.registrationPassword <~ registrationPasswordField.reactive.continuousTextValues.map { $0 ?? "" }
        viewModel.registrationPasswordConfirmation <~ registrationPasswordConfirmationField.reactive.continuousTextValues.map { $0 ?? "" }
        emailField.reactive.text <~ viewModel.nfcReadEmail.map { nfcReadEmail -> String? in nfcReadEmail != nil ? String(nfcReadEmail!.filter({ $0 != " " })[String.Index(encodedOffset: 3)...]) : nil }

        titleField.itemList = viewModel.titleOptions
        nfcLoginButton.isHidden = !viewModel.nfcLogInAvailable

        viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] isLoading in
            self?.loginButton.isEnabled = !isLoading
            if isLoading {
                SVProgressHUD.show()
            } else {
                SVProgressHUD.dismiss()
            }
        })

        viewModel.isLoginInputValid.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] inputIsValid in
            self?.loginButton.isEnabled = inputIsValid
        })

        let signInSuccess: ((Signal<Void, CTError>.Event) -> Void) = { [weak self] event in
            SVProgressHUD.dismiss()
            switch event {
            case .completed:
                AppRouting.switchAfterLogInSuccess()
            case let .failed(error):
                let alertController = UIAlertController(
                        title: viewModel.failedTitle,
                        message: self?.viewModel?.alertMessage(for: [error]),
                        preferredStyle: .alert
                        )
                alertController.addAction(UIAlertAction(title: viewModel.okAction, style: .cancel, handler: nil))
                self?.present(alertController, animated: true, completion: nil)
            default:
                return
            }
        }

        viewModel.loginAction.events
        .observe(on: UIScheduler())
        .observeValues(signInSuccess)
        
        viewModel.nfcLoginAction.events
        .observe(on: UIScheduler())
        .observeValues(signInSuccess)

        viewModel.registerAction.events
        .observe(on: UIScheduler())
        .observeValues(signInSuccess)
        
        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }
}

@available(iOS 11.0, *)
extension SignInViewController: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {}
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        if let payload = messages.first?.records.first?.payload {
            viewModel?.nfcReadEmail.value = String(data: payload, encoding: .utf8)
        } else {
            viewModel?.nfcReadEmail.value = nil
        }
    }
}
