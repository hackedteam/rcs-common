spec = Gem::Specification.new do |s|
  s.name = "rcs-common"
  s.version = "0.1.1"
  s.summary = "Common components for RCS backend."
  s.description = %{Common components for RCS backend.}
  s.files = Dir['lib/**/*.rb'] + Dir['test/**/*.rb']
  s.require_path = 'lib'
end

