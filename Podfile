source 'https://cdn.cocoapods.org/'
use_frameworks!
inhibit_all_warnings!
install! 'cocoapods', :generate_multiple_pod_projects => true

project 'EduVPN', 'Debug' => :debug, 'Release' => :release

# Setup targets

target 'EduVPN-iOS' do
  pod 'AppAuth', :git => 'https://github.com/openid/AppAuth-iOS.git'
  pod 'ASN1Decoder'
  pod 'libsodium'
  pod 'Moya'
  pod 'PromiseKit/CorePromise'
end

target 'EduVPN-macOS' do
  pod 'AppAuth', :git => 'https://github.com/openid/AppAuth-iOS.git'
  pod 'ASN1Decoder'
  pod 'libsodium'
  pod 'Moya'
  pod 'PromiseKit/CorePromise'
end
