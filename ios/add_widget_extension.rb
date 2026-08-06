# One-off script: adds the ChronoWidgetExtension target (home widgets + Live
# Activity) to Runner.xcodeproj. Run from ios/: ruby add_widget_extension.rb
# Safe to re-run: exits if the target already exists.
require 'xcodeproj'

project_path = File.expand_path('Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

if project.targets.any? { |t| t.name == 'ChronoWidgetExtension' }
  puts 'ChronoWidgetExtension target already exists - nothing to do.'
  exit 0
end

runner = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found' unless runner

ext = project.new_target(:app_extension, 'ChronoWidgetExtension', :ios, '16.1')

# Group + source files
group = project.main_group.find_subpath('ChronoWidget', true)
group.set_source_tree('<group>')
group.set_path('ChronoWidget')

%w[
  ChronoWidgetBundle.swift
  ChronoWidget.swift
  ChronoGoalsWidget.swift
  ChronoRoutinesWidget.swift
  ChronoTimerLiveActivity.swift
].each do |file|
  ref = group.new_reference(file)
  ext.add_file_references([ref])
end
group.new_reference('Info.plist')
group.new_reference('ChronoWidget.entitlements')

# Generated.xcconfig gives the extension FLUTTER_BUILD_NAME/NUMBER so its
# version can track the app's.
flutter_group = project.main_group.find_subpath('Flutter', false)
generated_ref = flutter_group&.files&.find { |f| f.path == 'Generated.xcconfig' }

ext.build_configurations.each do |config|
  config.base_configuration_reference = generated_ref if generated_ref
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.aturdi.chrono.ChronoWidget'
  config.build_settings['INFOPLIST_FILE'] = 'ChronoWidget/Info.plist'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'ChronoWidget/ChronoWidget.entitlements'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.1'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['DEVELOPMENT_TEAM'] = 'BGJTZW3T5C'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
end

# Embed the extension into Runner
runner.add_dependency(ext)
embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
bf = embed.add_file_reference(ext.product_reference)
bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# App group entitlements for Runner itself
runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end
runner_group = project.main_group.find_subpath('Runner', false)
runner_group.new_reference('Runner.entitlements') if runner_group

project.save
puts 'ChronoWidgetExtension target added and embedded into Runner.'
