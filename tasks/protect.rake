require 'fileutils'

namespace :protect do

  def windows?
    RbConfig::CONFIG['host_os'] =~ /mingw/
  end

  if windows?
    RUBYENCPATH = 'C:/Program Files (x86)/RubyEncoder'
    RUBYENC = "\"C:\\Program Files (x86)\\RubyEncoder\\rgencoder.exe\""
  else
    paths = ['/Applications/Development/RubyEncoder.app/Contents/MacOS', '/Applications/RubyEncoder.app/Contents/MacOS']
    RUBYENCPATH = File.exists?(paths.first) ? paths.first : paths.last
    RUBYENC = "#{RUBYENCPATH}/rgencoder"
  end

  LIB_PATH = File.expand_path('../../lib', __FILE__)

  raise("Invalid lib path") unless File.exists?("#{LIB_PATH}/rcs-common.rb")


  desc "Build an encrypted version of rcs-common gem into the pkg directory"
  task :build do
    begin
      FileUtils.cp_r(LIB_PATH, "#{LIB_PATH}_src")

      # Encoding files

      system "#{RUBYENC} --stop-on-error --encoding UTF-8 -b- -r --ruby 2.0.0 #{LIB_PATH}/*.rb"


      # Copy rgloader to lib folder

      rgpath = "#{LIB_PATH}/rgloader"
      FileUtils.rm_rf(rgpath)
      FileUtils.mkdir(rgpath)

      files = Dir["#{RUBYENCPATH}/Loaders/**/**"]
        # keep only the interesting files (2.0.x windows, macos)
      files.delete_if {|v| v.match(/bsd/i) or v.match(/linux/i)}
      files.keep_if {|v| v.match(/20/) or v.match(/loader.rb/) }

      files.each { |f| FileUtils.cp(f, rgpath) }


      # Building the gem

      export_protected = windows? ? "set PROTECTED=1 &&" : "export RPROTECTED=1 ;"
      system "#{export_protected} rake build"
    ensure
      # Restore the lib folder
      if Dir.exists?("#{LIB_PATH}_src")
        FileUtils.rm_rf(LIB_PATH) if Dir.exists?(LIB_PATH)
        FileUtils.mv("#{LIB_PATH}_src", LIB_PATH)
      end
    end
  end

  desc "Build and install an encrypted version of rcs-common into system gems"
  task :install do
    FileUtils.rm_rf("#{LIB_PATH}/../pkg")
    Rake::Task['protect:build'].invoke
    gemfile = Dir["#{LIB_PATH}/../pkg/*.gem"].first
    system("gem install #{gemfile}")
  end
end
