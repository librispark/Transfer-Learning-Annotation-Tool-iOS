# Uncomment the next line to define a global platform for your project
platform :ios, '14.0'

target 'LSTFL_Gather' do
    # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
    use_frameworks!

    # Pods for LSTFL_Gather
    pod 'Alamofire', '~> 4.8.0'
    pod 'AWSCore', '~> 2.8.4'
    pod 'AWSCognitoIdentityProvider', '~> 2.8.4'

end

post_install do |installer|
    installer.generated_projects.each do |project|
          project.targets.each do |target|
              target.build_configurations.each do |config|
                  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
               end
          end
   end
end
