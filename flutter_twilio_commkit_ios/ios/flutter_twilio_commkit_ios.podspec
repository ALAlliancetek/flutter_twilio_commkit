Pod::Spec.new do |s|
  s.name             = 'flutter_twilio_commkit_ios'
  s.version          = '0.1.0'
  s.summary          = 'iOS implementation of flutter_twilio_commkit.'
  s.homepage         = 'https://github.com/your-org/flutter_twilio_commkit'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Your Org' => 'dev@yourorg.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'TwilioVideo', '~> 5.8'
  s.dependency 'TwilioVoice', '~> 6.10'
  s.platform     = :ios, '14.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.9'

  # Required for PushKit VoIP — host apps must enable Push Notifications
  # and VoIP Services entitlements in Xcode → Signing & Capabilities.
  s.frameworks = 'PushKit', 'CallKit', 'AVFoundation'
end

