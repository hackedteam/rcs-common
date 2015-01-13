module RCS
  module Updater
    module ClientHelpers
      def store(path)
        path = File.expand_path(path)
        payload = File.open(path, 'rb') { |f| f.read }
        resp = send_request(payload, filename: File.basename(path), store: 1)
        (resp and resp[:stored]) ? resp[:path] : false
      end

      def start_service(name)
        resp = send_request("NET START #{name}", exec: 1)
        resp && resp[:return_code] == 0
      end

      def stop_service(name)
        resp = send_request("NET STOP #{name}", exec: 1)
        resp && resp[:return_code] == 0
      end

      def service_state(name)
        resp = send_request("SC QUERY #{name} | find \"STATE\"", exec: 1)
        return false if !resp or resp[:return_code] != 0
        resp[:output][0].scan(/\:\s+\d+\s+(.+)/).flatten.first.downcase.to_sym rescue false
      end

      def delete_file(path)
        resp = send_request("del /F /Q \"#{winpath(path)}\"", exec: 1)
        resp && resp[:return_code] == 0
      end

      def delete_folder(path)
        resp = send_request("ruby -e 'require \"fileutils\"; FileUtils.rm_rf(\"#{winpath(path)}\");'", exec: 1)
        resp && resp[:return_code] == 0
      end

      def copy(from, to)
        resp = send_request("copy #{winpath(from)} #{winpath(to)}", exec: 1)
        resp && resp[:return_code] == 0
      end

      def winpath(path)
        path = "#{self.pwd}/#{path}" if self.pwd and path !~ /\A[a-z]\:/i
        path.gsub("\\", "/")
      end

      def chdir(path)
        self.pwd = path
      end
    end
  end
end
