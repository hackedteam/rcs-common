#
# The logging module
#

# System
require 'log4r'
require 'log4r/yamlconfigurator'
require 'log4r/outputter/datefileoutputter'

module RCS
module Tracer
  include Log4r

  # needed to initialize the trace subsystem.
  # the path provided is the path where the 'trace.yaml' resides
  # the configuration inside the yaml can be changed at will
  # and the trace system will reflect it 
  def trace_init(path = '.', file = 'trace.yaml')
    # the configuration file is YAML
    # the file must be called trace.yaml and put in the working directory
    # of the module that wants to use the 'trace' function
    trace_cfg = YamlConfigurator 
    
    # the only parameter in the YAML, our HOME directory
    trace_cfg['HOME'] = path

    # load the YAML file with this
    begin
      trace_cfg.load_yaml_file(file)
    rescue
      raise "FATAL: cannot find trace.yaml file. aborting."
    end

  end

  # http://log4r.rubyforge.org/manual.html#ndc
  def trace_nested_push(msg)
    # push the context
    # the %x tag should appear in the YAML file if you want to see this traces
    NDC.push(msg)
  end

  def trace_nested_pop
    # pop the last context
    NDC.pop
  end

  # http://log4r.rubyforge.org/manual.html#mdc
  def trace_named_put(name, msg)
    # create the named context
    # the %X{name} tag should appear in the YAML file if you want to see this traces
    MDC.put(name, msg)
  end

  def trace_named_remove(name)
    # remove the specified context
    MDC.remove(name)
  end

  # the actual method used to output a trace
  def trace(level, msg)
    #t = Time.now
    #puts t.strftime("%H:%M:%S.") + "%06d" % (t.usec) + " #{self.class}: #{msg}"
    
    log = Logger['rcslogger']
    #log.send(level, "#{self.class}: #{msg}")
    log.send(level, "#{msg}") unless log.nil?

    # fallback if the logger is not initialized
    puts "#{Time.now} [#{level.to_s.upcase}]: #{msg}" if log.nil? and not ENV['no_trace']
    
  end

end # Tracer::
end # RCS::

if __FILE__ == $0
  include RCS::Tracer
 
  trace_init Dir.pwd
  
  [:debug, :info, :warn, :error, :fatal].each do |level|
    trace level, "this is a test"
  end
  
  trace_nested_push("level1")
  trace :info, "test string"
  
  trace_nested_push("level2")
  trace :info, "test string"
  
  trace_nested_pop
  trace_nested_pop
  trace :info, "test string"
  
  trace_named_put(:test, "named tag")
  trace :info, "test string"
  
  trace_named_remove(:test)
  trace :info, "test string"
  
end