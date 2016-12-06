platform :ios, '10.0'
use_frameworks!

def common_pods
  pod 'Commercetools', :git => 'https://github.com/commercetools/commercetools-ios-sdk.git', :commit => '8f5076de4c140f7234fd7b2b5a2b4b14012434f0'
  pod 'ReactiveCocoa', '~> 5.0.0-alpha.3'
  pod 'ReactiveObjC'
end

target 'Sunrise' do
  common_pods
  pod 'IQKeyboardManagerSwift'
  pod 'SDWebImage', '4.0.0-beta2'
  pod 'IQDropDownTextField'
  pod 'SVProgressHUD'
  pod 'DZNEmptyDataSet'
end

target 'ReservationNotification' do
  common_pods
  pod 'SDWebImage', '4.0.0-beta2'
end

target 'Sunrise Watch Extension' do
  platform :watchos, '3.0'
  pod 'Commercetools', :git => 'https://github.com/commercetools/commercetools-ios-sdk.git', :commit => '8f5076de4c140f7234fd7b2b5a2b4b14012434f0'
  pod 'ReactiveSwift', '1.0.0-alpha.4'
  pod 'SDWebImage', '4.0.0-beta2'
  pod 'NKWatchActivityIndicator'
end

def testing_pods
  pod 'Quick'
  pod 'Nimble'
end

target 'SunriseTests' do
  testing_pods
  common_pods
end

target 'SunriseUITests' do
  testing_pods
end
