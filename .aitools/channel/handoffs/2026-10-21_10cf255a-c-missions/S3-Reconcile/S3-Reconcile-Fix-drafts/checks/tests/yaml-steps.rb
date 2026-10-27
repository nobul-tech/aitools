# yaml-steps.rb -- parse a workflow file and print step counts per job.
require "yaml"
ARGV.each do |f|
  d = YAML.load_file(f)
  puts "#{f}: " + d["jobs"].map { |k, v| "#{k}=#{v["steps"].size}" }.join(" ")
end
