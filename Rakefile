require "bundler/gem_tasks"

require 'rake'

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test

require 'rcs-common/deploy'
ENV['DEPLOY_USER'] = 'Administrator'
ENV['DEPLOY_ADDRESS'] = '192.168.100.100'
RCS::Deploy::Task.import
