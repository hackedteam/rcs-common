# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "rcs-common/version"

Gem::Specification.new do |s|
  s.name        = "rcs-common"
  s.version     = RCS::Common::VERSION
  s.authors     = ["alor", "daniele"]
  s.email       = ["alor@hackingteam.it", "daniele@hackingteam.it"]
  s.homepage    = ""
  s.summary     = %q{rcs-common}
  s.description = %q{Common components for the RCS Backend}

  s.rubyforge_project = "rcs-common"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
end
