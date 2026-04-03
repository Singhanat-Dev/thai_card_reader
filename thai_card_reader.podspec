Pod::Spec.new do |s|
  s.name             = 'thai_card_reader'
  s.version          = '0.1.0'
  s.summary          = 'Flutter plugin for reading Thai national ID cards via USB/BT/BLE smart card readers.'
  s.homepage         = 'https://example.com'
  s.license          = { :file => 'LICENSE' }
  s.author           = { 'Author' => 'author@example.com' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '12.0'

  s.source_files = 'ios/Classes/**/*.{h,m}'

  # Static libraries from R&D NID SDK
  s.vendored_libraries = [
    'ios/Classes/NIOSLib/Lib/NiLib0.42.a',
    'ios/Classes/NIOSLib/Lib/NiLib0.42C.a',
    'ios/Classes/CCIDLib/lib/libiRockey301_ccid_V3.5.64_Release.a'
  ]

  # Required frameworks
  s.frameworks = 'CoreBluetooth', 'ExternalAccessory', 'UIKit'

  s.dependency 'Flutter'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Exclude simulator arm64 (static libs may not support it)
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
  }
end
