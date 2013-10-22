module RCS
  module Common
  	module PathUtils
      # Requires and rcs module. Sarch for a folder named rcs-NAME, where NAME is
      # the given name, and requires a script named NAME.rb
      #
      # @note The current directory is changed (chdir command)
      def require_module(name, opts = {})
        init_script = caller[0].scan(/^(.+)\:\d+\:.+$/)[0][0]

        unless init_script.end_with?("lib/rcs-#{name}.rb")
          raise "Invalid execution directory. Cannot lauch rcs-#{name}"
        end

        execution_directory = File.expand_path('../..', init_script)

        puts "WARN: chdir to #{execution_directory}"
        Dir.chdir(execution_directory)

        require_release("#{execution_directory}/lib/rcs-#{name}-release/#{name}.rb", warn: true)

      rescue LoadError => error
        puts "FATAL: cannot find any rcs-#{name} code!"
      end

      # Requires an encrypted ruby script (rcs-XXX-releases folders) when
      # available, otherwise requires the clean version of it (rcs-XXX folders)
      def require_release(path, opts = {})
        if path.include?("-release")
          new_path = path
        else
          new_path = path.gsub(/(.*)rcs-([^\/]+)/, '\1rcs-\2-release')
        end

        if opts[:warn] and !new_path.include?('-release') and File.exists?(new_path)
          puts "WARNING: Executing clear text code... (debug only)"
        end

        begin
          require(new_path)
        rescue LoadError => error
          new_path.gsub!('-release', '')
          require(new_path)
        end
  		end
  	end
  end
end

unless Kernel.respond_to?(:require_release)
  Kernel.__send__(:include, RCS::Common::PathUtils)
  Object.__send__(:include, Kernel)
end
