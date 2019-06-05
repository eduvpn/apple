source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!
inhibit_all_warnings!

project 'EduVPN', 'Debug' => :debug, 'Release' => :release

# iOS Pods

def pods_ios
  platform :ios, '11.0'
  pod 'TunnelKit', '1.7.1'
end

# macOS Pods

def pods_macos
  platform :osx, '10.12'

  pod 'AppAuth', :git => 'https://github.com/openid/AppAuth-iOS.git'
  pod 'ASN1Decoder'
  pod 'BlueSocket', '1.0.46'
  pod 'Kingfisher', '5.5.0'
  pod 'libsodium'
  pod 'Moya'
  pod 'PromiseKit/CorePromise'
  pod 'ReachabilitySwift', '4.3.1'
  pod 'Sodium', '0.8.0'
  pod 'Sparkle', '1.21.3'
  pod 'Then'
  pod 'TunnelKit', '1.7.1'
  pod 'FileKit', '~> 5.2.0'
end

# Setup targets

target 'EduVPN' do
  pods_ios

  pod 'AlamofireImage'
  pod 'AppAuth', :git => 'https://github.com/openid/AppAuth-iOS.git'
  pod 'ASN1Decoder'
  pod 'Disk'
  pod 'libsodium'
  pod 'Moya'
  pod 'NVActivityIndicatorView'
  pod 'PromiseKit/CorePromise'
  pod 'Then'
  pod 'FileKit', '~> 5.2.0'
end

target 'EduVPNTunnelExtension' do
  pods_ios
end

target 'EduVPN-macOS' do
  pods_macos
end

target 'LetsConnect-macOS' do
  pods_macos
end

# Post install

post_install do | installer |
  require 'fileutils'
  FileUtils.cp_r('Pods/Target Support Files/Pods-EduVPN/Pods-EduVPN-Acknowledgements.plist', 'EduVPN/Resources/Settings.bundle/Acknowledgements.plist', :remove_destination => true)
end
