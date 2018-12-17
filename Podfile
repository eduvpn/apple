source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

platform :ios, '11.0'

swift_version = "4.2"

project 'EduVPN', 'Debug' => :debug, 'Release' => :release, 'Debug AppForce1' => :debug, 'Release AppForce1' => :release, 'Debug LetsConnect' => :debug, 'Release LetsConnect' => :release

target 'EduVPN' do
  pod 'SwiftLint'
  pod 'PromiseKit/CorePromise'
  pod 'KeychainSwift'
  pod 'AppAuth', :git => 'https://github.com/openid/AppAuth-iOS.git'
  pod 'Moya'
  pod 'Disk'
  pod 'AlamofireImage'
  pod 'Sodium'
  pod 'ASN1Decoder'
  pod 'BNRCoreDataStack'
  pod 'NVActivityIndicatorView'
  pod 'TunnelKit'

  post_install do | installer |
    require 'fileutils'
    FileUtils.cp_r('Pods/Target Support Files/Pods-EduVPN/Pods-EduVPN-Acknowledgements.plist', '$(target.product_name)/Resources/Settings.bundle/Acknowledgements.plist', :remove_destination => true)

  end
end

target 'EduVPNTunnelExtension' do
  pod 'TunnelKit'
end
