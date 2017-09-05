//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import ReactiveSwift

/// The key used for storing logged in username.
let kLoggedInUsername = "LoggedInUsername"

class SignInViewModel: BaseViewModel {

    // Inputs
    let username = MutableProperty("")
    let password = MutableProperty("")
    let title = MutableProperty("")
    let firstName = MutableProperty("")
    let lastName = MutableProperty("")
    let email = MutableProperty("")
    let registrationPassword = MutableProperty("")
    let registrationPasswordConfirmation = MutableProperty("")

    // Outputs
    let isLoading: MutableProperty<Bool>
    let isLoginInputValid = MutableProperty(false)
    let isRegisterInputValid = MutableProperty(false)
    let registrationGuide = NSLocalizedString("All mandatory fields (*) have to be filled, and your password and confirmation must match", comment: "Registration form instructions")
    var isLoggedIn: Bool {
        return AppRouting.isLoggedIn
    }

    // Actions
    lazy var loginAction: Action<Void, Void, CTError> = { [unowned self] in
        return Action(enabledIf: self.isLoginInputValid) { _ in
            self.isLoading.value = true
            return self.login(username: self.username.value, password: self.password.value)
        }
    }()
    lazy var registerAction: Action<Void, Void, CTError> = { [unowned self] in
        return Action(enabledIf: self.isRegisterInputValid) { _ in
            self.isLoading.value = true
            return self.registerUser()
        }
    }()

    // MARK: Lifecycle

    override init() {
        isLoading = MutableProperty(false)

        super.init()

        isLoginInputValid <~ SignalProducer.combineLatest(username.producer, password.producer).map { let (username, password) = $0
            return username.characters.count > 0 && password.characters.count > 0
        }

        isRegisterInputValid <~ SignalProducer.combineLatest(email.producer, firstName.producer, lastName.producer,
                registrationPassword.producer, registrationPasswordConfirmation.producer).map { let (email, firstName, lastName, password, passwordConfirmation) = $0
            var isRegisterInputValid = true
            [email, firstName, lastName, password].forEach {
                if $0.characters.count == 0 {
                    isRegisterInputValid = false
                }
            }
            if password != passwordConfirmation {
                isRegisterInputValid = false
            }
            return isRegisterInputValid
        }
    }

    // MARK: - Commercetools platform user log in and sign up

    private func login(username: String, password: String) -> SignalProducer<Void, CTError> {
        return SignalProducer { [weak self] observer, disposable in
            Commercetools.loginCustomer(username: username, password: password,
                    activeCartSignInMode: .mergeWithExistingCustomerCart) { result in
                if let error = result.errors?.first as? CTError, result.isFailure {
                    observer.send(error: error)
                } else {
                    observer.sendCompleted()
                    // Save username to user defaults for displaying it later on in the app
                    UserDefaults.standard.set(username, forKey: kLoggedInUsername)
                    UserDefaults.standard.synchronize()
                }
                self?.isLoading.value = false
            }
        }
    }

    private func registerUser() -> SignalProducer<Void, CTError> {
        let username = email.value
        let password = registrationPassword.value
        let draft = CustomerDraft(email: username, password: password, firstName: firstName.value, lastName: lastName.value, title: title.value)

        return SignalProducer { [weak self] observer, disposable in
            Commercetools.signUpCustomer(draft, result: { result in
                if let error = result.errors?.first as? CTError, result.isFailure {
                    observer.send(error: error)
                } else {
                    self?.login(username: username, password: password).startWithSignal { signal, signalDisposable in
                        disposable += signalDisposable
                        signal.observe { event in
                            switch event {
                                case let .failed(error):
                                    observer.send(error: error)
                                default:
                                    observer.sendCompleted()
                            }
                        }
                    }
                }
            })
        }
    }
}
