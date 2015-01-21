require 'tmpdir'

module RCS
  module Updater
    module TmpDir
      def windows?
        @is_windows ||= (RbConfig::CONFIG['host_os'] =~ /mingw/)
      end

      def tmpdir
        @tmpdir ||= windows? ? "#{File.expand_path(Dir.tmpdir)}/rcs.temp/updater" : "/tmp/rcs_updater"
      end
    end
  end
end
