require 'rcs-common/trace'

module RCS
  module Component
    def self.included(base)
      base.__send__(:include, RCS::Tracer)
      base.__send__(:extend, ClassMethods)

      base.__send__(:define_singleton_method, :component) do |value, name: nil|
        @_component = value.to_sym
        @_component_name = name || "RCS #{value.to_s.capitalize}"
      end

      db_class = base.to_s.split("::")[0..-2].join("::")+"::DB"
      base.instance_variable_set '@_db_class', const_get(db_class)
    end

    def component
      self.class.instance_variable_get('@_component')
    end

    def component_name
      self.class.instance_variable_get('@_component_name')
    end

    def show_startup_message
      build = File.read(Dir.pwd + '/config/VERSION_BUILD')
      version = File.read(Dir.pwd + '/config/VERSION')

      trace :fatal, "Starting the #{component_name} #{version} (#{build})..."
    end

    def database
      db_class = self.class.instance_variable_get('@_db_class')
      db_class.instance
    end

    def establish_database_connection(wait_until_connected: false)
      loop do
        if database.connect!(:carrier)
          trace :info, "Database connection succeeded"
        end

        break if database.connected? or wait_until_connected == false

        trace :warn, "Database connection failed, retry..."
        sleep 1
      end
    end

    def run_with_rescue
      show_startup_message
      yield
    rescue Interrupt
      trace :info, "User asked to exit. Bye bye!"
      exit(0)
    rescue Exception => e
      trace :fatal, "FAILURE: " << e.message
      trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
      exit(1)
    end

    module ClassMethods
      def run!(*argv)
        return new.run(argv)
      end
    end
  end
end
