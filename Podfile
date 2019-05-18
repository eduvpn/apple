project 'EduVPN', 'Debug' => :debug, 'Release' => :release

def tunnelkit_pod
  pod 'TunnelKit', :git => 'https://github.com/keeshux/tunnelkit.git'
end

# iOS Pods

def pods_ios
  source 'https://github.com/CocoaPods/Specs.git'
  use_frameworks!

  platform :ios, '11.0'
end

# macOS Pods

def pods_macos
  platform :osx, '10.12'
  
  pod 'AppAuth', :git => 'https://github.com/openid/AppAuth-iOS.git'
  pod 'BlueSocket', '1.0.46'
  pod 'Kingfisher', '5.5.0'
  pod 'ReachabilitySwift', '4.3.1'
  pod 'Sodium', '0.8.0'
  pod 'Sparkle', '1.21.3'
end

# Setup targets

target 'EduVPN' do
  pods_ios
  
  pod 'PromiseKit/CorePromise'
  pod 'AppAuth', :git => 'https://github.com/openid/AppAuth-iOS.git'
  pod 'Moya'
  pod 'Disk'
  pod 'AlamofireImage'
  pod 'libsodium'
  pod 'ASN1Decoder'
  pod 'NVActivityIndicatorView'
  
  tunnelkit_pod
end

target 'EduVPNTunnelExtension' do
  pods_ios
  tunnelkit_pod
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

