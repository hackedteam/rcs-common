require 'yajl/json_gem'
require 'net/http'
require 'uri'
require 'timeout'
require 'digest/md5'

require_relative "../trace.rb"
require_relative "shared_key"
require_relative "tmp_dir"

module RCS
  module Updater
    class Client
      include RCS::Tracer
      include TmpDir

      attr_reader :address, :port, :instdir
      attr_accessor :max_retries, :retry_interval, :open_timeout
      attr_accessor :pwd

      def initialize(address, port: 6677)
        @address = address
        @port = port
        @shared_key = SharedKey.new
        @instdir = "C:/RCS"

        self.max_retries = 3
        self.retry_interval = 4 # sec
        self.open_timeout = 8 # sec

        yield(self) if block_given?
      end

      def request(payload, options = {}, retry_count = self.max_retries)
        msg = options[:store] ? [] : [payload]
        msg = ["#{payload.size} B", options.inspect]
        trace(:debug, "REQ #{msg.join(' | ')}")

        http = Net::HTTP.new(address, port)
        http.open_timeout = self.open_timeout

        # Encrypt x-options hash with a shared key
        # Add a timestamp to prevent a reply attack, and the md5 of the payload to prevent payload modification
        options.merge!(tm: Time.now.to_f, md5: Digest::MD5.hexdigest(payload))

        req = Net::HTTP::Post.new('/', initheader = {'Content-Type' =>'application/json'})
        req['x-options'] = @shared_key.encrypt_hash(options)
        raise("x-options header is too long") if req['x-options'].size > 4_096
        req.body = payload
        res = http.request(req)

        status_code = res.code.to_i

        trace :debug, "REP #{res.code} | #{res.body}"

        raise("Internal server error") if res.code.to_i != 200

        hash = JSON.parse(res.body)
        hash.keys.each { |key| hash[key.to_sym] = hash.delete(key) }

        return hash
      rescue Exception => ex
        trace(:error, "[#{ex.class}] #{ex.message}")

        if retry_count > 0
          trace(:warn, "Retrying in #{retry_interval} seconds, #{retry_count} attempt(s) left")
          sleep(self.retry_interval)
          return request(payload, options, retry_count-1)
        else
          return nil
        end
      end


      # Helpers

      def store_file(path, remote_path = nil)
        path = File.expand_path(path)
        payload = File.open(path, 'rb') { |f| f.read }
        path = store(payload, filename: File.basename(path))

        if remote_path
          return move(path, remote_path)
        else
          return path
        end
      end

      def store(payload, filename: nil)
        resp = request(payload, filename: filename, store: 1)
        return (resp and resp[:stored]) ? resp[:path] : false
      end

      def grant_users_access(path)
        request("icacls #{winpath(path)} /grant Users:(OI)(CI)", exec: 1)
      end

      def store_folder(local_path, remote_path)
        Dir["#{local_path}/**/*"].each do |path|
          relative_path = path[local_path.size+1..-1]
          remote_abs_path = "#{remote_path}/#{relative_path}"

          if File.directory?(path)
            mkdir_p(remote_abs_path)
          else
            store_file(path, remote_abs_path) || raise("Unable to store #{path} into #{remote_abs_path}")
          end
        end
      end

      def start(payload)
        path = store(payload+"\nexit", filename: 'start.bat')
        request("start #{path}", {spawn: 1}, retry_count = 0)
      end

      def start_service(name)
        resp = request("NET START #{name}", exec: 1)
        resp && resp[:return_code] == 0
      end

      def stop_service(name)
        resp = request("NET STOP #{name}", exec: 1)
        resp && resp[:return_code] == 0
      end

      def service_status(name)
        resp = request("SC QUERY #{name} | find \"STATE\"", exec: 1)
        return false if !resp or resp[:return_code] != 0
        resp[:output][0].scan(/\:\s+\d+\s+(.+)/).flatten.first.downcase.to_sym rescue false
      end

      def service_exists?(name)
        resp = request("SC QUERY #{name} | find \"STATE\"", exec: 1)
        return resp && resp[:output].any?
      end

      def rm_f(path)
        resp = request("ruby -e 'require \"fileutils\"; FileUtils.rm_f(\"#{winpath(path)}\");'", exec: 1)
        resp && resp[:return_code] == 0
      end

      def rm_rf(path)
        resp = request("ruby -e 'require \"fileutils\"; FileUtils.rm_rf(\"#{winpath(path)}\");'", exec: 1)
        resp && resp[:return_code] == 0
      end

      def md(path)
        resp = request("md winpath(path)", exec: 1)
        resp && resp[:return_code] == 0
      end

      def copy(from, to)
        resp = request("copy #{winpath(from)} #{winpath(to)}", exec: 1)
        resp && resp[:return_code] == 0
      end

      def move(from, to)
        resp = request("move #{winpath(from)} #{winpath(to)}", exec: 1)
        resp && resp[:return_code] == 0
      end

      def mkdir_p(path)
        resp = request("ruby -e 'require \"fileutils\"; FileUtils.mkdir_p(\"#{unixpath(path)}\");", exec: 1)
        resp && resp[:return_code] == 0
      end

      def winpath(path)
        path = "#{self.pwd}\\#{path}" if self.pwd and path !~ /\A[a-z]\:/i
        path.gsub("/", "\\")
      end

      def unixpath(path)
        path = "#{self.pwd}/#{path}" if self.pwd and path !~ /\A[a-z]\:/i
        path.gsub("\\", "/")
      end

      def connected?
        !!request("", {}, retry_count = 0)
      end
    end
  end
end

