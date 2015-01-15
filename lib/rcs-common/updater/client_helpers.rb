module RCS
  module Updater
    module ClientHelpers
      def store(path)
        path = File.expand_path(path)
        payload = File.open(path, 'rb') { |f| f.read }
        resp = request(payload, filename: File.basename(path), store: 1)
        (resp and resp[:stored]) ? resp[:path] : false
      end

      def start_service(name)
        resp = request("NET START #{name}", exec: 1)
        resp && resp[:return_code] == 0
      end

      def stop_service(name)
        resp = request("NET STOP #{name}", exec: 1)
        resp && resp[:return_code] == 0
      end

      def service_state(name)
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

      def copy(from, to)
        resp = request("copy #{winpath(from)} #{winpath(to)}", exec: 1)
        resp && resp[:return_code] == 0
      end

      def winpath(path)
        path = "#{self.pwd}/#{path}" if self.pwd and path !~ /\A[a-z]\:/i
        path.gsub("\\", "/")
      end

      def connected?
        !!request("", {}, retry_count = 0)
      end

      private :winpath
    end
  end
end
