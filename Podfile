source 'https://cdn.cocoapods.org/'
use_frameworks!
inhibit_all_warnings!
install! 'cocoapods', :generate_multiple_pod_projects => true

project 'EduVPN', 'Debug' => :debug, 'Release' => :release

# iOS Pods

def pods_ios
  platform :ios, '12.0'
  pod 'TunnelKit', :git => 'https://github.com/passepartoutvpn/tunnelkit.git'
end

# macOS Pods

def pods_macos
  platform :osx, '10.15'
  pod 'TunnelKit', :git => 'https://github.com/passepartoutvpn/tunnelkit.git'
end

# Setup targets

target 'EduVPN-iOS' do
  pods_ios

  pod 'AppAuth', :git => 'https://github.com/openid/AppAuth-iOS.git'
  pod 'ASN1Decoder'
  pod 'libsodium'
  pod 'Moya'
  pod 'PromiseKit/CorePromise'
end

target 'EduVPNTunnelExtension-iOS' do
  pods_ios
end

target 'EduVPN-macOS' do
  pods_macos
  
  pod 'AppAuth', :git => 'https://github.com/openid/AppAuth-iOS.git'
  pod 'ASN1Decoder'
  pod 'libsodium'
  pod 'Moya'
  pod 'PromiseKit/CorePromise'
end

target 'EduVPNTunnelExtension-macOS' do
  pods_macos
end

# Post install

post_install do | installer |
  require 'fileutils'
  FileUtils.cp_r('Pods/Target Support Files/Pods-EduVPN/Pods-EduVPN-Acknowledgements.plist', 'EduVPN/Resources/Settings.bundle/Acknowledgements.plist', :remove_destination => true)
end
