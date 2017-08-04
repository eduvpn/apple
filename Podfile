platform :ios, '10.0'

use_frameworks!

swift_version = "3.0"

target 'EduVPN' do
  pod 'SwiftLint'
  pod 'PromiseKit/CorePromise'
  pod 'KeychainSwift'
  pod 'AppAuth'
  pod 'Moya'
  pod 'AlamofireImage'

  post_install do | installer |
    require 'fileutils'
    FileUtils.cp_r('Pods/Target Support Files/Pods-EduVPN/Pods-EduVPN-Acknowledgements.plist', 'EduVPN/Resources/Settings.bundle/Acknowledgements.plist', :remove_destination => true)
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '3.0'
        end
    end

  end
end

