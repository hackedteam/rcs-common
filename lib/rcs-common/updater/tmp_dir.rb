module RCS
  module Updater
    module TmpDir
      def windows?
        @is_windows ||= (RbConfig::CONFIG['host_os'] =~ /mingw/)
      end

      def tmpdir
        "C:/Windows/Temp/rcsupdr.tmp"
      end
    end
  end
end
