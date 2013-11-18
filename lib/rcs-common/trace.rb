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

  TRACE_YAML_NAME = 'trace.yaml'

  # Ensures that the log directories exists
  def trace_ensure_log_folders
    pwd = File.expand_path(Dir.pwd)

    ["#{pwd}/log", "#{pwd}/log/err"].each do |path|
      Dir.mkdir(path) unless File.directory?(path)
    end
  end

  def trace_setup
    pwd = File.expand_path(Dir.pwd)

    raise "FATAL: Invalid execution directory." unless File.directory?("#{pwd}/lib")

    trace_file_path = File.exist?(TRACE_YAML_NAME) ? TRACE_YAML_NAME : "#{pwd}/config/#{TRACE_YAML_NAME}"
    raise "FATAL: Unable to find #{TRACE_YAML_NAME} file" unless File.exist?(trace_file_path)

    trace_ensure_log_folders

    trace_cfg = YamlConfigurator

    # the only parameter in the YAML, our HOME directory
    trace_cfg['HOME'] = pwd

    # load the YAML file with this
    trace_cfg.load_yaml_file(trace_file_path)
  rescue Exception => ex
    raise "FATAL: Unable to load #{TRACE_YAML_NAME}: #{ex.message}"
  end

  # needed to initialize the trace subsystem.
  # the path provided is the path where the 'trace.yaml' resides
  # the configuration inside the yaml can be changed at will
  # and the trace system will reflect it
  # 
  # @deprecated Please use {#trace_setup} instead
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

  def thread_name
    (Thread.current[:name] || Thread.current.object_id.to_s(32)).to_s
  end

  # the actual method used to output a trace
  def trace(level, msg)
    thread_info = "[Thread:#{thread_name}] " if ENV['TRACE_SHOW_THREAD_NAME']
    msg = "#{thread_info}#{msg}"

    log = Logger['rcslogger']
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