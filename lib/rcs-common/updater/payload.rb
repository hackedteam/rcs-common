require 'timeout'
require 'fileutils'
require 'open3'
require_relative "tmp_dir"
require_relative "../trace.rb"

module RCS
  module Updater
    class Payload
      include RCS::Tracer
      include TmpDir

      attr_reader :options, :payload, :timeout
      attr_reader :filepath, :output, :return_code, :stored

      DEFAULT_TIMEOUT = 180

      def initialize(payload, options = {})
        @options = options
        @payload = payload

        @timeout = options['timeout'].to_i
        @timeout = DEFAULT_TIMEOUT if @timeout <= 0
      end

      def ruby?; options['ruby']; end

      def storable?; options['store']; end

      def spawn?; options['spawn']; end

      def runnable?
        options['exec'] or ruby? or spawn?
      end

      def [](name)
        instance_variable_get("@#{name}")
      end

      def run
        @return_code = nil
        @output = ""

        cmd = "#{'ruby ' if ruby?}#{storable? ? filepath : payload}"

        if spawn?
          trace(:debug, "[spawn] #{cmd}")
          return spawn(cmd)
        end

        Timeout::timeout(@timeout) do
          trace(:debug, "Timeout has been set to #{@timeout} sec") if @timeout != DEFAULT_TIMEOUT

          trace(:debug, "[popen] #{cmd}")

          Open3.popen2e(cmd) do |stdin, std_out_err, wait_thr|
              while line = std_out_err.gets
                trace(:debug, "[std_out_err] #{line.strip}")
                @output << line
              end
            @return_code = wait_thr.value.exitstatus
          end
        end

        return @return_code
      ensure
        FileUtils.rm_f(filepath) if stored
      end

      def store
        @filepath = "#{tmpdir}/" + (@options['filename'] || Time.now.to_f.to_s.gsub(".", ""))
        FileUtils.mkdir_p(tmpdir)
        trace(:debug, "Storing payload into #{filepath}")
        File.open(filepath, "wb") { |f| f.write(payload) }
        @stored = true
      end
    end
  end
end
