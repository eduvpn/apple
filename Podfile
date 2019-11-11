source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!
inhibit_all_warnings!

project 'EduVPN', 'Debug' => :debug, 'Release' => :release

# iOS Pods

def pods_ios
  platform :ios, '11.0'
  pod 'TunnelKit'
end

# macOS Pods

def pods_macos
  platform :osx, '10.12'
  pod 'TunnelKit'
end

# Setup targets

target 'EduVPN' do
  pods_ios

  pod 'AlamofireImage'
  pod 'AppAuth', :git => 'https://github.com/openid/AppAuth-iOS.git'
  pod 'ASN1Decoder'
  pod 'libsodium'
  pod 'Moya'
  pod 'NVActivityIndicatorView'
  pod 'PromiseKit/CorePromise'
  pod 'FileKit', '~> 5.2.0'
end

target 'EduVPNTunnelExtension' do
  pods_ios
end

target 'EduVPN-macOS' do
  pods_macos
  
  pod 'AppAuth', :git => 'https://github.com/openid/AppAuth-iOS.git'
  pod 'ASN1Decoder'
  pod 'Kingfisher', '~> 5.5.0'
  pod 'libsodium'
  pod 'Moya'
  pod 'PromiseKit/CorePromise'
  pod 'ReachabilitySwift', '~> 4.3.1'
  pod 'FileKit', '~> 5.2.0'
end

target 'EduVPNTunnelExtension-macOS' do
  pods_macos
end

# Post install

post_install do | installer |
  require 'fileutils'
  FileUtils.cp_r('Pods/Target Support Files/Pods-EduVPN/Pods-EduVPN-Acknowledgements.plist', 'EduVPN/Resources/Settings.bundle/Acknowledgements.plist', :remove_destination => true)
end
