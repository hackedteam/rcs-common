module RCS
  module Common
  	module PathUtils

      # Requires an encrypted ruby script (rcs-XXX-releases folders) when
      # available, otherwise requires the clean version of it (rcs-XXX folders)
  		def require_release path
        unless path.start_with?("rcs-")
          raise 'path must start with "rcs-"'
        end

        if path.include?("-release") and File.exists?(path)
          require path
        else
          require path.gsub('-release', '')
        end
  		end
  	end
  end
end

Kernel.send :include, RCS::Common::PathUtils
Object.send :include, Kernel
