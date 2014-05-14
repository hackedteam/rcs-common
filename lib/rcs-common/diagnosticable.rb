require 'sys/filesystem'
require 'rcs-common/fixnum'

module RCS
  module Diagnosticable
    def execution_directory
      File.expand_path(Dir.pwd)
    end

    def log_path
      File.expand_path("./log", execution_directory)
    end

    def logs
      Dir["#{log_path}/*"]
    end

    def grouped_logs(deepness: 2)
      groups = Hash.new { |h, k| h[k] = [] }
      regexp = /(rcs\-.+)\_\d{4}-\d{2}-\d{2}\.log|(mongo..log)/

      logs.each do |path|
        filename = File.basename(path)
        group_name = filename.scan(regexp).flatten.compact.first
        groups[group_name] << path if group_name
      end

      groups.keys.each do |group_name|
        groups[group_name].sort! { |p1, p2| File.mtime(p2).to_i <=> File.mtime(p1).to_i }
        groups[group_name] = groups[group_name][0..deepness - 1]
      end

      groups
    end

    def huge_log?(path)
      File.size(path) > 52428800 # 50 megabytes
    end

    def hide_addresses(string)
      mask = "###.###.###.###"
      string.gsub!(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/, mask)
      string.gsub!(/([a-zA-Z0-9\-\.]+)\:(4444|443|80|2701\d)/, mask+':\2')
      string
    end

    def relevant_logs
      grouped_logs.values.flatten
    end
  end
end
