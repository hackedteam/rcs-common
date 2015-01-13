require 'timeout'
require 'fileutils'
require 'open3'
require 'tmpdir'
require_relative "../trace.rb"

module RCS
  module Updater
    class Payload
      include RCS::Tracer

      attr_reader :options, :payload, :timeout
      attr_reader :filepath, :output, :return_code, :stored

      DEFAULT_TIMEOUT = 180

      def initialize(payload, options = {})
        @options = options
        @payload = payload

        @timeout = options['timeout'].to_i
        @timeout = DEFAULT_TIMEOUT if @timeout <= 0
      end

      def runnable?
        options['exec'] or ruby?
      end

      def ruby?
        options['ruby']
      end

      def storable?
        options['store']
      end

      def run
        @return_code, @output = nil, []

        # todo: keep or remove?
        # @payload.gsub!('$INSTDIR', 'C:\\RCS') if @payload =~ /\$INSTDIR/

        Timeout::timeout(@timeout) do
          cmd = "#{'ruby ' if ruby?}#{storable? ? filepath : payload}"

          trace(:debug, "Timeout has been set to #{@timeout} sec") if @timeout != DEFAULT_TIMEOUT
          trace(:debug, "[popen] #{cmd}")

          Open3.popen2e(cmd) do |stdin, std_out_err, wait_thr|
              while line = std_out_err.gets
                line.strip!
                trace(:debug, "[std_out_err] #{line}")
                @output << line.strip
              end
            @return_code = 0 if wait_thr.value.success?
          end
        end

        return @return_code
      ensure
        FileUtils.rm_f(filepath) if storable?
      end

      def store
        @filepath = "#{temp_path}/" + (@options['filename'] || Time.now.to_f.to_s.gsub(".", ""))
        FileUtils.mkdir_p(temp_path)
        trace(:debug, "Storing payload into #{filepath}")
        File.open(filepath, "wb") { |f| f.write(payload) }
        @stored = true
      end

      private

      def windows?
        @windows ||= (RbConfig::CONFIG['host_os'] =~ /mingw/)
      end

      def temp_path
        windows? ? "#{File.expand_path(Dir.tmpdir)}/rcs.temp/updater" : "/tmp/rcs_updater"
      end
    end
  end
end
