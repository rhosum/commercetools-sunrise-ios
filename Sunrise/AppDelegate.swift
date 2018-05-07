//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import UserNotifications
import Commercetools
import Contentful
import CoreLocation
import AVFoundation
import IQKeyboardManagerSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    static var currentCountry: String?
    static var currentCurrency: String?
    static var customerGroup: Reference<CustomerGroup>?

    var contentfulClient: Client = {
        let spaceId = Bundle.main.object(forInfoDictionaryKey: "ContentfulSpaceId") as? String ?? ""
        let accessToken = Bundle.main.object(forInfoDictionaryKey: "ContentfulAccessToken") as? String ?? ""
        return Client(spaceId: spaceId, accessToken: accessToken)
    }()

    var window: UIWindow?

    var deviceToken: String?

    private var locationManager: CLLocationManager?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        if let configuration = Project.config {
            Commercetools.config = configuration

        } else {
            // Inform user about the configuration error
        }

        locationManager = CLLocationManager()
        locationManager?.requestWhenInUseAuthorization()
        IQKeyboardManager.sharedManager().enable = true

        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: [.badge, .alert, .sound]) { success, _ in
            if !success {
                // Requesting authorization for notifications failed. Perhaps let the API know.
            }
        }
        notificationCenter.delegate = self
        application.registerForRemoteNotifications()
        addNotificationCategories()

        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Swift.Void) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
            let pathComponents = url.pathComponents
            // POP (e.g https://demo.commercetools.com/en/search?q=jeans)
            if let indexOfSearch = pathComponents.index(of: "search"), let urlComponents = URLComponents(string: url.absoluteString),
               let queryItems = urlComponents.queryItems, let query = queryItems["q"].first, indexOfSearch > 0 {
                AppRouting.search(query: query, filters: queryItems)
                return true

            // PDP (e.g https://demo.commercetools.com/en/brunello-cucinelli-coat-mf9284762-cream-M0E20000000DQR5.html)
            } else if let sku = pathComponents.last?.components(separatedBy: "-").last, sku.count > 5, sku.contains(".html") {
                AppRouting.showProductDetails(for: String(sku[...String.Index(encodedOffset: sku.count - 6)]))
                return true

            // Orders (e.g https://demo.commercetools.com/en/user/orders)
            } else if pathComponents.last?.contains("orders") == true {
                AppRouting.showMyOrders()
                return true

            // Order details (e.g https://demo.commercetools.com/en/user/orders/87896195?)
            } else if pathComponents.contains("orders"), let orderNumber = pathComponents.last, !orderNumber.contains("orders") {
                AppRouting.showOrderDetails(for: orderNumber)

            // Category overview (e.g https://demo.commercetools.com/en/women-clothing-blazer)
            } else if pathComponents.count == 3, pathComponents[1].count == 2 {
                AppRouting.showCategory(locale: pathComponents[1], slug: pathComponents[2])
            }
        }
        return false
    }

    fileprivate func handleNotification(notificationInfo: [AnyHashable: Any]) {
        if let reservationId = notificationInfo["reservation-id"] as? String {
            AppRouting.showReservationDetails(for: reservationId)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        deviceToken = nil
        saveDeviceTokenForCurrentCustomer()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let deviceToken = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
        self.deviceToken = deviceToken
        saveDeviceTokenForCurrentCustomer()
    }
    
    func saveDeviceTokenForCurrentCustomer() {
        if Commercetools.authState == .customerToken {
            Customer.addCustomTypeIfNotExists { version, errors in
                if let version = version, let deviceToken = self.deviceToken, errors == nil {
                    let updateActions = UpdateActions(version: version, actions: [CustomerUpdateAction.setCustomField(name: "apnsToken", value: .string(value: deviceToken))])

                    Customer.update(actions: updateActions) { result in
                        if result.isFailure {
                            result.errors?.forEach { debugPrint($0) }
                        }
                    }
                } else {
                    errors?.forEach { debugPrint($0) }
                }
            }
        }
    }

    func addNotificationCategories() {
        let viewAction = UNNotificationAction(identifier: Notification.Action.view, title: NSLocalizedString("View", comment: "View"), options: [.authenticationRequired, .foreground])
        let getDirectionsAction = UNNotificationAction(identifier: Notification.Action.getDirections, title: NSLocalizedString("Get Directions", comment: "Get Directions"), options: [.foreground])

        let reservationConfirmationCategory = UNNotificationCategory(identifier: Notification.Category.reservationConfirmation, actions: [viewAction, getDirectionsAction], intentIdentifiers: [], options: [])

        UNUserNotificationCenter.current().setNotificationCategories([reservationConfirmationCategory])
    }
    
    // MARK: - Project configuration

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        if let queryItems = URLComponents(string: url.absoluteString)?.queryItems, url.scheme == "ctpclient", url.host == "changeProject" {
            var projectConfig = [String: Any]()
            queryItems.forEach {
                if $0.value != "true" && $0.value != "false" {
                    projectConfig[$0.name] = $0.value
                } else {
                    // Handle boolean values explicitly
                    projectConfig[$0.name] = $0.value == "true"
                }
            }
            if Config(config: projectConfig as NSDictionary) != nil {
                let alertController = UIAlertController(
                    title: "Valid Configuration",
                    message: "Confirm to store the new configuration and quit the app, or tap cancel to abort",
                    preferredStyle: .alert
                )
                alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                alertController.addAction(UIAlertAction(title: "Confirm", style: .default) { _ in
//                    AppRouting.accountViewController?.viewModel?.logoutCustomer()
                    Commercetools.logoutCustomer()
                    Project.update(config: projectConfig as NSDictionary)
                    exit(0)
                })
                window?.rootViewController?.present(alertController, animated: true)
            } else {
                let alertController = UIAlertController(
                    title: "Invalid Configuration",
                    message: "Project has not been changed",
                    preferredStyle: .alert
                )
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                window?.rootViewController?.present(alertController, animated: true)
            }
            return true
        }
        return false
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.handleNotification(notificationInfo: response.notification.request.content.userInfo)
            completionHandler()
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert])
    }
}

extension AppDelegate: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        try? AVAudioSession.sharedInstance().setActive(false, with: .notifyOthersOnDeactivation)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        try? AVAudioSession.sharedInstance().setActive(false, with: .notifyOthersOnDeactivation)
    }
}
