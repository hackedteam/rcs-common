# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "rcs-common/version"

gemspec = Gem::Specification.new do |s|
  s.name        = "rcs-common"
  s.version     = RCS::Common::VERSION
  s.authors     = ["alor", "daniele"]
  s.email       = ["alor@hackingteam.it", "daniele@hackingteam.it"]
  s.homepage    = ""
  s.summary     = %q{rcs-common}
  s.description = %q{Common components for the RCS Backend}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency("log4r", ">= 1.1.9")
  s.add_dependency('mime-types')
  s.add_dependency('sys-filesystem')
  s.add_dependency('sys-cpu')
  s.add_dependency('ffi')
  s.add_dependency('mail')
  s.add_dependency('sbdb')
  s.add_dependency('mongoid')
  s.add_dependency('yajl-ruby')
  s.add_dependency('eventmachine')
  s.add_dependency('em-http-server')

  s.add_development_dependency("bundler")
  s.add_development_dependency('rake')
  s.add_development_dependency('test-unit')
  s.add_development_dependency('simplecov')
  s.add_development_dependency('rspec')
  s.add_development_dependency('pry')
end

if ENV['PROTECTED']
  files = gemspec.files.dup

  gemspec.instance_variable_set(:'@test_files', [])
  gemspec.instance_variable_set(:'@files', [])

  exclusions = [
    /.gitignore/,
    /.ruby-version/,
    /Rakefile/,
    /lib\/rcs-common\/evidence\/content\//,
    /^test\//,
    /^tasks\//,
    /^spec\//
  ]

  files.reject! do |path|
    exclusions.find { |regexp| path =~ regexp }
  end

  files.concat(Dir["lib/rgloader/**/*"])

  gemspec.instance_variable_set(:'@files', files)
end

gemspec
