require "bundler/gem_tasks"
require 'rake'
require 'rake/testtask'
require 'rspec/core/rake_task'

Dir["./tasks/*.rake"].each do |path|
  load(path)
end

desc "Run minitest"
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

desc "Run minitest + rspec"
task :default do
  Rake::Task["test"].invoke
  Rake::Task["spec"].invoke
end

desc "Run rspec"
RSpec::Core::RakeTask.new(:spec)

# Disable the release task (release the gem to rubygems)
Rake::Task["release"].clear
