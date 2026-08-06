# Moves the "Embed Foundation Extensions" copy-files phase ahead of the Flutter
# "Thin Binary" and CocoaPods script phases on the Runner target. When it sits
# at the end, Xcode fuses it with the late script phases and the App Intents
# metadata step, producing a "Cycle inside Runner" build error. Idempotent.
require 'xcodeproj'

project_path = File.expand_path('Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found' unless runner

embed = runner.build_phases.find do |p|
  p.respond_to?(:symbol_dst_subfolder_spec) &&
    p.symbol_dst_subfolder_spec == :plug_ins
end
raise 'Embed extensions phase not found' unless embed

# Target index: just after Resources, before the first shell-script phase.
first_script_idx = runner.build_phases.index do |p|
  p.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
end

runner.build_phases.delete(embed)
insert_at = first_script_idx || runner.build_phases.length
runner.build_phases.insert(insert_at, embed)

project.save
puts "Moved Embed Foundation Extensions phase to index #{insert_at}."
puts 'Phase order now:'
runner.build_phases.each_with_index do |p, i|
  name = p.respond_to?(:name) && p.name ? p.name : p.class.name
  puts "  #{i}: #{name}"
end
