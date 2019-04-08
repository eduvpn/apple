source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

platform :ios, '11.0'

swift_version = "4.2"

project 'EduVPN', 'Debug' => :debug, 'Release' => :release

target 'EduVPN' do
  pod 'SwiftLint'
  pod 'PromiseKit/CorePromise'
  pod 'AppAuth', :git => 'https://github.com/openid/AppAuth-iOS.git'
  pod 'Moya', '~> 13.0.0-beta'
  pod 'Disk'
  pod 'AlamofireImage'
  pod 'libsodium'
  pod 'ASN1Decoder'
  pod 'NVActivityIndicatorView'
  pod 'TunnelKit'

  post_install do | installer |
    require 'fileutils'
    FileUtils.cp_r('Pods/Target Support Files/Pods-EduVPN/Pods-EduVPN-Acknowledgements.plist', 'EduVPN/Resources/Settings.bundle/Acknowledgements.plist', :remove_destination => true)

  end
end

target 'EduVPNTunnelExtension' do
  pod 'TunnelKit'
end
