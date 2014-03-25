require 'bundler'
require 'rspec'
require 'mongoid'
require 'pry'

RSpec.configure do |config|
  config.before(:all) do
    ENV['MONGOID_ENV'] = 'spec'
    Mongoid.load! File.expand_path('../mongoid.yaml', __FILE__), :spec
  end

  config.before(:each) do
    Mongoid.purge!
  end
end

$LOAD_PATH << File.expand_path('../lib', __FILE__)

require 'rcs-common'
