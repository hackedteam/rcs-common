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

  s.add_runtime_dependency(%q<log4r>, [">= 1.1.9"])
  s.add_runtime_dependency(%q<mime-types>, [">= 0"])
  s.add_runtime_dependency(%q<sys-filesystem>, [">= 0"])
  s.add_runtime_dependency(%q<sys-cpu>, [">= 0"])
  s.add_runtime_dependency(%q<ffi>, [">= 0"])
  s.add_runtime_dependency(%q<mail>, [">= 0"])

  s.add_development_dependency(%q<bundler>, [">= 0"])
  s.add_development_dependency(%q<rcov>, [">= 0"])
  s.add_development_dependency(%q<test-unit>, [">= 0"])
end

if ENV['PROTECTED']
  files = gemspec.files.dup

  gemspec.instance_variable_set(:'@test_files', [])
  gemspec.instance_variable_set(:'@files', [])

  exclusions = [".gitignore", ".ruby-version", "Rakefile"]

  files.reject! do |path|
    path.start_with?("test/") or path.start_with?("tasks/") or exclusions.include?(path)
  end

  files.concat(Dir["lib/rgloader/**/*"])

  gemspec.instance_variable_set(:'@files', files)
end

gemspec
