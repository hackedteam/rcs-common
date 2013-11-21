require 'rcs-common/trace'
require 'rcs-common/systemstatus'
require 'socket'

module RCS::HeartBeat
  class Base
    extend RCS::Tracer
    include RCS::Tracer

    def initialize(component_name, component_fullname: nil, before_heartbeat: nil)
      @component_name     = component_name.to_s.downcase
      @component_fullname = component_fullname || "RCS::#{component_name.to_s.capitalize}"
      @before_heartbeat   = before_heartbeat
    end

    def ip_addr
      @ip_addr ||= Socket.gethostname rescue 'unknown'
    end

    # @note: This must be implemented by subclasses
    def message
      raise("You should implement the message method")
    end

    def update_component_status
      instance_exec(&@before_heartbeat) if @before_heartbeat.respond_to?(:call)

      RCS::SystemStatus.reset

      status = RCS::SystemStatus.my_status
      stats = {:disk => RCS::SystemStatus.disk_free, :cpu => RCS::SystemStatus.cpu_load, :pcpu => RCS::SystemStatus.my_cpu_load(@component_fullname)}
      msg = RCS::SystemStatus.my_error_msg || message

      ::Status.status_update(@component_fullname, ip_addr, status, msg, stats, @component_name, $version)
    end

    # Declare the component
    # To use as an helper in the subclasses
    def self.component(component_name, component_fullname = nil)
      @component_name     = component_name
      @component_fullname = component_fullname
    end

    def self.before_heartbeat(&block)
      @before_heartbeat = block
    end

    # This method is called from outside
    def self.perform
      raise("Undefined component version") unless $version
      raise("Undefined component name") unless @component_name

      new(@component_name, component_fullname: @component_fullname, before_heartbeat: @before_heartbeat).update_component_status
    rescue Interrupt
      trace :fatal, "Heartbeat was interrupted because of a term signal"
    rescue Exception => ex
      trace :fatal, "Cannot perform status update: #{ex.message}"
      trace :fatal, ex.backtrace
    end
  end
end
