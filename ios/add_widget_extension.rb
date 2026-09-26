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

# Flutter's own "Thin Binary" run-script phase strips unused architectures
# from every embedded binary and has no declared inputs/outputs, so Xcode's
# dependency analysis can't tell whether it should run before or after a
# newly-added "Embed Foundation Extensions" copy phase — left at its default
# (appended-to-the-end) position, this produces "Cycle inside Runner;
# building could produce unreliable results" and a hard build failure.
# The documented fix is ordering: Embed Foundation Extensions must come
# BEFORE Thin Binary in Runner's build phase list. Re-run on every CI build
# (not just target-creation) since re-opening/re-saving the project can't be
# trusted to preserve a manually-fixed order across runs.
def fix_build_phase_order!(runner_target, embed_phase)
  phases = runner_target.build_phases
  phases.delete(embed_phase)
  thin_binary_index = phases.find_index do |p|
    p.respond_to?(:name) && p.name.to_s.downcase.include?('thin binary')
  end
  # Fallback for Flutter versions that don't name the phase exactly "Thin
  # Binary" — embedding before the first script phase is still correct,
  # since that's Flutter's own generated script phase either way.
  thin_binary_index ||= phases.find_index { |p| p.isa == 'PBXShellScriptBuildPhase' }
  if thin_binary_index
    phases.insert(thin_binary_index, embed_phase)
  else
    phases.push(embed_phase)
  end
end

project = Xcodeproj::Project.open(PROJECT_PATH)

runner_target = project.targets.find { |t| t.name == 'Runner' }
raise "Runner target not found in #{PROJECT_PATH}" if runner_target.nil?

# Runner.entitlements exists on disk (App Group capability, required for the
# main app process to write into the same shared UserDefaults container the
# widget extension reads from) but was never wired into a CODE_SIGN_ENTITLEMENTS
# build setting anywhere — Xcode does not pick up an entitlements file just
# because it's sitting next to the target's source files. Without this, Runner
# builds and signs successfully but silently WITHOUT the App Groups capability,
# so every value the live_activities plugin writes from the main app never
# reaches the container DeliveryWidget reads from — it just silently no-ops,
# no build error, no crash, the Live Activity still starts, it just always
# shows the widget's own hardcoded fallback text. Set on every run (not just
# target-creation) so a build from before this fix landed also gets corrected.
runner_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

if project.targets.any? { |t| t.name == EXTENSION_NAME }
  puts "#{EXTENSION_NAME} target already exists — verifying build phase order..."
  embed_phase = runner_target.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
  if embed_phase
    fix_build_phase_order!(runner_target, embed_phase)
  end
  project.save
  puts 'Done (idempotent run).'
  exit 0
end

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

fix_build_phase_order!(runner_target, embed_phase)

project.save
puts "#{EXTENSION_NAME} target added successfully."
