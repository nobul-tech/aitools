# yaml-steps.rb -- parse a workflow file and list step names per job
require "yaml"
d = YAML.load_file(ARGV[0])
d["jobs"].each do |job, spec|
  puts "#{job}:"
  spec["steps"].each { |s| puts "  - #{s['name'] || s['uses']}" }
end
