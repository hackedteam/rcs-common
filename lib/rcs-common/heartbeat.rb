require 'rcs-common/trace'
require 'rcs-common/systemstatus'
require 'socket'

module RCS::HeartBeat
  class Base
    extend RCS::Tracer
    include RCS::Tracer
    include RCS::SystemStatusCodes

    # Declare the component
    # To use as an helper in the subclasses
    def self.component(component_name, component_fullname = nil)
      @component_name     = component_name
      @component_fullname = component_fullname
    end

    # This method is called from outside
    def self.perform
      heartbeat = new(@component_name, component_fullname: @component_fullname)
      status, message = *heartbeat.perform
      if status
        heartbeat.update(status, message)
      else
        # trace(:warn, "heartbeat prevented")
      end
    rescue Interrupt
      trace :fatal, "Heartbeat was interrupted because of a term signal"
    rescue Exception => ex
      trace :fatal, "Cannot perform heartbeat: #{ex.message}"
      trace :fatal, ex.backtrace
    end


    def initialize(component_name, component_fullname: nil)
      raise("Undefined component version") unless version
      raise("Undefined component name") unless component_name

      @component_name     = component_name.to_s.downcase
      @component_fullname = component_fullname || "RCS::#{component_name.to_s.capitalize}"
    end

    def update(status, message)
      system_status, system_message = *system_status_and_message

      if status == OK and system_status != OK
        status, message = system_status, system_message
      end

      attributes = [@component_fullname, hostname, status, message, machine_stats, @component_name, version]

      if defined?(::Status)
        # Db
        ::Status.status_update(*attributes)
      else
        # Collector
        db_class = Object.const_get(@component_fullname)::DB
        attributes[1] = ''
        db_class.instance.update_status(*attributes)
      end
    ensure
      reset_system_status_and_message
    end

    # Override this method
    def perform
      system_status_and_message
    end

    private

    def hostname
      @hostname ||= Socket.gethostname rescue 'unknown'
    end

    def reset_system_status_and_message
      RCS::SystemStatus.reset
    end

    def system_status_and_message
      [RCS::SystemStatus.status, RCS::SystemStatus.message]
    end

    def version
      $version
    end

    def machine_stats
      {
        disk: RCS::SystemStatus.disk_free,
        cpu: RCS::SystemStatus.cpu_load,
        pcpu: RCS::SystemStatus.my_cpu_load(@component_fullname)
      }
    end
  end
end
