Pod::Spec.new do |s|
  s.name             = 'thai_card_reader'
  s.version          = '0.1.0'
  s.summary          = 'Flutter plugin for reading Thai national ID cards via USB/BT/BLE smart card readers.'
  s.homepage         = 'https://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Author' => 'author@example.com' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '12.0'

  s.source_files        = 'Classes/**/*.{h,m}'
  s.public_header_files = 'Classes/ThaiCardReaderPlugin.h'

  # Static libraries from R&D NID SDK
  s.vendored_libraries = [
    'Classes/NIOSLib/Lib/libNiLib0.42.a',
    'Classes/NIOSLib/Lib/libNiLib0.42C.a',
    'Classes/CCIDLib/lib/libiRockey301_ccid_V3.5.64_Release.a'
  ]

  # Required frameworks
  s.frameworks = 'CoreBluetooth', 'ExternalAccessory', 'UIKit'
  s.libraries  = 'c++'

  s.dependency 'Flutter'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Classes"',
    # Exclude simulator arm64 (static libs may not support it)
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
  }
end
