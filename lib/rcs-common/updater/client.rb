require 'yajl/json_gem'
require 'net/http'
require 'uri'
require 'timeout'
require 'digest/md5'
require 'base64'

require_relative "../trace.rb"
require_relative "shared_key"
require_relative "tmp_dir"
require_relative "../winfirewall"
require_relative "payload"

module RCS
  module Updater
    class Client
      include RCS::Tracer
      include TmpDir
      extend Resolver

      attr_reader :address, :port
      attr_accessor :max_retries, :retry_interval, :open_timeout
      attr_accessor :pwd

      def initialize(address, port: 6677)
        @address = address
        @port = port
        @shared_key = SharedKey.new

        self.max_retries = 3
        self.retry_interval = 4 # sec
        self.open_timeout = 10 # sec
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
          raise(ex)
        end
      end

      def local_command(cmd, options = {})
        payload = Payload.new(cmd, options.merge('exec' => true))
        payload.store if payload.storable?
        payload.run if payload.runnable?
        return payload
      end


      # Helpers

      def self.resolve_to_localhost?(name)
        return true if name == 'localhost'
        addr = resolve_dns(name, use_cache: true) rescue nil
        return addr == '127.0.0.1'
      end

      def localhost?
        self.class.resolve_to_localhost?(@address)
      end

      def store_file(path, remote_path = nil)
        path = unixpath(File.expand_path(path))
        payload = File.open(path, 'rb') { |f| f.read }
        return store(payload, filename: File.basename(path))
      end

      def store(payload, filename: nil)
        raise("Missing filename") unless filename

        if localhost?
          path = unixpath("#{tmpdir}/#{filename}")
          File.open(path, 'wb') { |f| f.write(payload) }
          return path
        else
          return request(payload, filename: filename, store: 1)[:path]
        end
      end

      def start(payload)
        path = store(payload+"\nexit", filename: 'start.bat')

        begin
          if localhost?
            resp = local_command("start #{path}", 'spawn' => 1)
          else
            resp = request("start #{path}", {spawn: 1}, retry_count = 0)
          end
        rescue Exception => ex
          trace :error, "#start: #{ex.message}"
        end

        return nil
      end

      alias :detached :start

      def restart_service(name)
        stop_service(name)
        start_service(name)
      end

      def start_service(name)
        cmd = "NET START #{name}"
        return localhost? ? local_command(cmd) : request(cmd, exec: 1)
      end

      def stop_service(name)
        cmd = "NET STOP #{name}"
        return localhost? ? local_command(cmd) : request(cmd, exec: 1)
      end

      def service_exists?(name)
        !!execute("SC QUERY #{name}")
      end

      def registry_add(key_path, value_name, value_data)
        value_type = if value_data.kind_of?(Fixnum)
          :REG_DWORD
        else
          :REG_SZ
        end

        cmd = "reg add #{winpath(key_path)} /f /t #{value_type} /v #{value_name} /d #{value_data}"
        return localhost? ? local_command(cmd) : request(cmd, exec: 1)
      end

      def write_file(path, content)
        if localhost?
          File.open(unixpath(path), 'wb') { |file| file.write(content) }
        else
          # todo
        end
      end

      def read_file(path)
        # This has only the "localhost" version
        File.read(unixpath(path))
      end

      def delete_service(service_name)
        cmd = "sc delete #{service_name}"
        return localhost? ? local_command(cmd) : request(cmd, exec: 1)
      end

      def add_firewall_rule(rule_name, params = {})
        if localhost?
          WinFirewall.del_rule(rule_name)
          WinFirewall.add_rule(params.merge(name: rule_name))
        else
          # todo
        end
      end

      def service_config(service_name, param_name, param_value)
        param_name = param_name.to_s
        cmd = ""

        if %w[type start error binPath group tag depend obj DisplayName password].include?(param_name)
          cmd = "sc config #{service_name} #{param_name}= \"#{param_value}\""
        elsif %[description].include?(param_name)
          cmd = "sc description #{service_name} \"#{param_value}\""
        else
          raise "Invalid parameter #{param_name}"
        end

        return localhost? ? local_command(cmd) : request(cmd, exec: 1)
      end

      def service_failure(service_name, reset = 0, action1 = "restart/60000", action2 = "restart/60000", action3 = "restart/60000")
        cmd = "sc failure #{service_name} reset= #{reset.to_i} actions= "+[action1, action2, action3].compact.join("/")
        return localhost? ? local_command(cmd) : request(cmd, exec: 1)
      end

      def execute(cmd)
        resp = localhost? ? local_command(cmd) : request(cmd, exec: 1)

        if resp[:return_code] != 0
          return nil
        else
          return resp[:output]
        end
      end

      def database_exists?(name, mongo: nil)
        eval = "f=null; db.adminCommand({listDatabases: 1})['databases'].forEach(function(e){ if (e.name == '#{name}') { f = true } }); if (!f) { throw('not found') }"
        cmd = "#{winpath(mongo)} 127.0.0.1 --eval \"#{eval}\""
        return execute(cmd)
      end

      def rm_rf(path, allow: [], check: true)
        if localhost?
          FileUtils.rm_rf(unixpath(path))
        else
          request("ruby -e 'require \"fileutils\"; FileUtils.rm_rf(\"#{unixpath(path)}\");'", exec: 1)
        end

        if check
          ls(unixpath(path)+"/*").each do |p|
            raise("rm_rf command failed on folder #{path}") unless allow.find { |regexp| p =~ /#{regexp}/i }
          end
        end

        return true
      end

      def rm_f(path)
        if localhost?
          FileUtils.rm_f(unixpath(path))
        else
          request("ruby -e 'require \"fileutils\"; FileUtils.rm_f(\"#{unixpath(path)}\");'", exec: 1)
        end

        if ls(path).any?
          raise("rm_f command failed on file #{path}")
        else
          return true
        end
      end

      def add_to_hosts_file(hash)
        ip, name = *hash.to_a.first
        line = "\r\n#{ip}\t#{name}\r\n"
        path = "C:\\Windows\\System32\\Drivers\\etc\\hosts"

        if localhost?
          File.open(path, 'ab') { |file| file.write(line) } unless File.read(path).include?(line.strip)
        else
          # TODO
        end
      end

      def extract_sfx(sfx_path, destination_path)
        mkdir_p(destination_path)

        if localhost?
          local_command("\"#{winpath(sfx_path)}\" -y -o\"#{winpath(destination_path)}\"")
        else
          remote_path = store_file(sfx_path)
          request("\"#{winpath(remote_path)}\" -y -o\"#{winpath(destination_path)}\"", exec: 1)
          rm_f(remote_path)
        end
      end

      # TODO: ensure no duplication
      def add_to_path(*paths)
        list = [paths].flatten.map{ |p| winpath(p) }.join(";")

        if localhost?
          ENV['PATH'] += ";#{list}" unless ENV['path'].include?(list)
          return local_command("setx path \"%path%;#{list}\" /M && set PATH=\"%PATH%;#{list}\"")
        else
          return request("setx path \"%path%;#{list}\"", exec: 1)
        end
      end

      def mkdir_p(path)
        if localhost?
          FileUtils.mkdir_p(winpath(path))
        else
          request("ruby -e 'require \"fileutils\"; FileUtils.mkdir_p(\"#{unixpath(path)}\");", exec: 1)
        end
      end

      def cp(from, to)
        if localhost?
          FileUtils.cp(unixpath(from), unixpath(to))
        else
          request("ruby -e 'require \"fileutils\"; FileUtils.cp(\"#{unixpath(from)}\", \"#{unixpath(to)}\");", exec: 1)
        end
      end

      def cp_r(from, to)
        if localhost?
          FileUtils.cp_r(unixpath(from), unixpath(to))
        else
          request("ruby -e 'require \"fileutils\"; FileUtils.cp_r(\"#{unixpath(from)}\", \"#{unixpath(to)}\");", exec: 1)
        end
      end

      def mv(from, to)
        if localhost?
          FileUtils.mv(unixpath(from), unixpath(to))
        else
          request("ruby -e 'require \"fileutils\"; FileUtils.mv(\"#{unixpath(from)}\", \"#{unixpath(to)}\");", exec: 1)
        end
      end

      def ls(glob)
        if localhost?
          return Dir[unixpath(glob)]
        else
          resp = request('ruby -e \'require "base64"; require "json"; puts Base64.urlsafe_encode64(Dir["'+unixpath(glob)+'"].to_json)\'', exec: 1)
          return JSON.parse(Base64.urlsafe_decode64(resp[:output].strip))
        end
      end

      def file_exists?(path)
        ls(path).any?
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
        if localhost?
          return true
        else
          return !!(request("", {}, retry_count = 0) rescue false)
        end
      end
    end
  end
end
