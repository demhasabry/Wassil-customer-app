#!/usr/bin/env ruby
# Programmatically adds the DeliveryWidget Widget Extension target to
# Runner.xcodeproj, using the `xcodeproj` gem instead of hand-editing the
# project file directly — this is the same library CocoaPods/fastlane use
# internally for exactly this kind of target surgery, which handles the
# internal UUID bookkeeping correctly rather than risking hand-typed
# references. Run once per CI build, before `flutter build ios` — idempotent
# (safe to run again if the target already exists).
require 'xcodeproj'

PROJECT_PATH = File.join(__dir__, 'Runner.xcodeproj')
EXTENSION_NAME = 'DeliveryWidget'
EXTENSION_BUNDLE_ID = 'com.example.customerApp.DeliveryWidget'
DEPLOYMENT_TARGET = '16.1'

project = Xcodeproj::Project.open(PROJECT_PATH)

if project.targets.any? { |t| t.name == EXTENSION_NAME }
  puts "#{EXTENSION_NAME} target already exists — skipping (idempotent run)."
  exit 0
end

runner_target = project.targets.find { |t| t.name == 'Runner' }
raise "Runner target not found in #{PROJECT_PATH}" if runner_target.nil?

puts "Creating #{EXTENSION_NAME} target..."
extension_target = project.new_target(:app_extension, EXTENSION_NAME, :ios, DEPLOYMENT_TARGET)

# Group + file references for the extension's own source files, living in
# the ios/DeliveryWidget/ folder alongside this script.
group = project.main_group.new_group(EXTENSION_NAME, EXTENSION_NAME)

['DeliveryWidgetBundle.swift', 'DeliveryLiveActivityWidget.swift'].each do |file_name|
  file_ref = group.new_reference(file_name)
  extension_target.source_build_phase.add_file_reference(file_ref)
end

group.new_reference('Info.plist')
group.new_reference("#{EXTENSION_NAME}.entitlements")

# Frameworks the widget's Swift code imports.
['WidgetKit.framework', 'SwiftUI.framework', 'ActivityKit.framework'].each do |framework_name|
  framework_ref = project.frameworks_group.new_reference("System/Library/Frameworks/#{framework_name}")
  framework_ref.source_tree = 'SDKROOT'
  extension_target.frameworks_build_phase.add_file_reference(framework_ref)
end

extension_target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = "#{EXTENSION_NAME}/Info.plist"
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = "#{EXTENSION_NAME}/#{EXTENSION_NAME}.entitlements"
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = EXTENSION_BUNDLE_ID
  config.build_settings['PRODUCT_NAME'] = EXTENSION_NAME
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  # Matches how the rest of this project builds unsigned in CI
  # (flutter build ios --no-codesign) — see .github/workflows/ios-build.yml.
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
  config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
end

# Runner needs to build the extension first, then embed the resulting
# .appex into its own PlugIns folder.
runner_target.add_dependency(extension_target)

embed_phase = runner_target.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
if embed_phase.nil?
  embed_phase = runner_target.new_copy_files_build_phase('Embed Foundation Extensions')
  embed_phase.dst_subfolder_spec = '13' # PlugIns — Xcode's own convention for extension targets.
end
embedded_file = embed_phase.add_file_reference(extension_target.product_reference)
embedded_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

project.save
puts "#{EXTENSION_NAME} target added successfully."
