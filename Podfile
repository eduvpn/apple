platform :ios, '10.0'

use_frameworks!

swift_version = "4.2"

target 'EduVPN' do
  pod 'SwiftLint'
  pod 'PromiseKit/CorePromise'
  pod 'KeychainSwift'
  pod 'AppAuth'
  pod 'Moya'
  pod 'Disk'
  pod 'AlamofireImage'
  pod 'Sodium'
  pod 'ASN1Decoder'
  pod 'BNRCoreDataStack'
  pod 'NVActivityIndicatorView'

  post_install do | installer |
    require 'fileutils'
    FileUtils.cp_r('Pods/Target Support Files/Pods-EduVPN/Pods-EduVPN-Acknowledgements.plist', 'EduVPN/Resources/Settings.bundle/Acknowledgements.plist', :remove_destination => true)

  end
end

