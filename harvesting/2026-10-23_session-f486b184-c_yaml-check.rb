# yaml-check.rb -- parse a workflow file and print the tail of the Windows profile step
require "yaml"
d = YAML.load_file(ARGV[0])
s = d["jobs"]["windows"]["steps"].find { |x| x["name"].to_s.include?("Profile") }
puts s["run"].lines.last(3)
