require 'timeout'
require 'fileutils'
require 'open3'
require_relative "../trace.rb"

module RCS
  module Updater
    class Payload
      include RCS::Tracer

      attr_reader :options, :payload, :file, :output, :return_code, :stored

      def initialize(payload, options = {})
        @options = options
        @payload = payload
        @file = "#{temp_path}/" + (@options['filename'] || Time.now.to_f.to_s.gsub(".", ""))
      end

      def runnable?
        options['exec'] and stored
      end

      def timeout
        options['exec_timeout'] ? options['exec_timeout'] : 3600
      end

      def run
        @return_code, @output = 1, []

        Timeout::timeout(timeout) do
          Open3.popen2e("ruby #{file}") do |stdin, std_out_err, wait_thr|
              while line = std_out_err.gets
                line.strip!
                trace :debug, "[std_out_err] #{line}"
                @output << line.strip
              end
            @return_code = 0 if wait_thr.value.success?
          end
        end

        @return_code
      end

      def windows?
        @windows ||= (RbConfig::CONFIG['host_os'] =~ /mingw/)
      end

      def temp_path
        windows? ? "C:/RCS/DB/temp" : "#{Dir.pwd}/temp"
      end

      def store
        FileUtils.mkdir_p(temp_path)
        File.open(file, "wb") { |f| f.write(payload) }
        @stored = true
      end
    end
  end
end
