module RCS
  module Common
  	module PathUtils

      # Requires an encrypted ruby script (rcs-XXX-releases folders) when
      # available, otherwise requires the clean version of it (rcs-XXX folders)
  		def require_release(path)
        if path.include?("-release")
          new_path = path
        else
          new_path = path.gsub(/(.*)rcs-([^\/]+)/, '\1rcs-\2-release')
        end

        begin
          require new_path
        rescue LoadError => error
          require new_path.gsub('-release', '')
        end
  		end
  	end
  end
end

Kernel.send :include, RCS::Common::PathUtils
Object.send :include, Kernel
