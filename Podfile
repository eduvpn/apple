source 'https://cdn.cocoapods.org/'
use_frameworks!
inhibit_all_warnings!
install! 'cocoapods', :generate_multiple_pod_projects => true

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

  pod 'Kingfisher'
  pod 'AppAuth', :git => 'https://github.com/openid/AppAuth-iOS.git'
  pod 'ASN1Decoder'
  pod 'libsodium'
  pod 'Moya'
  pod 'PromiseKit/CorePromise'
end

target 'EduVPNTunnelExtension' do
  pods_ios
end

target 'EduVPN-macOS' do
  pods_macos
  
  pod 'AppAuth', :git => 'https://github.com/openid/AppAuth-iOS.git'
  pod 'ASN1Decoder'
  pod 'Kingfisher'
  pod 'libsodium'
  pod 'Moya'
  pod 'PromiseKit/CorePromise'
  pod 'FileKit'
end

target 'EduVPNTunnelExtension-macOS' do
  pods_macos
end

# Post install

post_install do | installer |
  require 'fileutils'
  FileUtils.cp_r('Pods/Target Support Files/Pods-EduVPN/Pods-EduVPN-Acknowledgements.plist', 'EduVPN/Resources/Settings.bundle/Acknowledgements.plist', :remove_destination => true)
end
