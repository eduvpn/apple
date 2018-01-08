platform :ios, '10.0'

use_frameworks!

swift_version = "3.0"

target 'EduVPN' do
  pod 'Fabric'
  pod 'Crashlytics'
  pod 'SwiftLint'
  pod 'PromiseKit/CorePromise'
  pod 'KeychainSwift'
  pod 'AppAuth'
  pod 'Moya'
  pod 'Disk'
  pod 'AlamofireImage'
  pod 'Sodium'
  pod 'ASN1Decoder'

  post_install do | installer |
    require 'fileutils'
    FileUtils.cp_r('Pods/Target Support Files/Pods-EduVPN/Pods-EduVPN-Acknowledgements.plist', 'EduVPN/Resources/Settings.bundle/Acknowledgements.plist', :remove_destination => true)

  end
end

