//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import Foundation
import ReactiveSwift

class MainMenuInterfaceController: WKInterfaceController {
    
    @IBOutlet var signInGroup: WKInterfaceGroup!
    @IBOutlet var mainMenuGroup: WKInterfaceGroup!

    private var interfaceModel: MainMenuInterfaceModel? {
        didSet {
            bindInterfaceModel()
        }
    }

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        signInGroup.setAlpha(0)
        signInGroup.setHidden(true)
        
        interfaceModel = MainMenuInterfaceModel()
    }

    private func bindInterfaceModel() {
        guard let interfaceModel = interfaceModel else { return }

        interfaceModel.presentSignInMessage.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] presentSignIn in
            self?.animate(withDuration: 0.3) {
                self?.signInGroup.setAlpha(0)
                self?.mainMenuGroup.setAlpha(0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.signInGroup.setHidden(!presentSignIn)
                self?.mainMenuGroup.setHidden(presentSignIn)
                self?.animate(withDuration: 0.3) {
                    self?.signInGroup.setAlpha(presentSignIn ? 1 : 0)
                    self?.mainMenuGroup.setAlpha(presentSignIn ? 0 : 1)
                }
            }
        })
    }
}