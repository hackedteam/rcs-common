require 'yajl/json_gem'
require 'em-http-server'
require_relative "payload"
require_relative "signature_file"
require_relative "../trace.rb"

module RCS
  module Updater
    class AuthError < Exception; end

    class Server < EM::HttpServer::Server
      include RCS::Tracer
      extend RCS::Tracer

      def initialize(*args)
        @x_signature = SignatureFile.read
        super
      end

      def x_options
        @x_options ||= @http[:x_options] ? JSON.parse(@http[:x_options]) : Hash.new
      end

      def remote_addr
        ary = get_peername[2,6].unpack("nC4")
        ary[1..-1].join(".")
      end

      def private_ipv4?
        a,b,c,d = remote_addr.split(".").map(&:to_i)
        return true if a==127 && b==0 && c==0 && d==1 # localhost
        return true if a==192 && b==168 && c.between?(0,255) && d.between?(0,255) # 192.168.0.0/16
        return true if a==172 && b.between?(16,31) && c.between?(0,255) && d.between?(0,255) # 172.16.0.0/12
        return true if a==10 && b.between?(0,255) && c.between?(0,255) && d.between?(0,255)  # 10.0.0.0/8
        return false
      end

      def process_http_request
        EM.defer do
          begin
            trace(:info, "[#{@http[:host]}] REQ #{@http_protocol} #{@http_request_method} #{@http_content.size} bytes from #{remote_addr}")

            raise AuthError.new("Invalid http method") if @http_request_method != "POST"
            raise AuthError.new("No content") unless @http_content
            raise AuthError.new("Invalid signature") if @x_signature != @http[:x_signature]
            raise AuthError.new("remote_addr is not private") unless private_ipv4?

            payload = Payload.new(@http_content, x_options)

            set_comm_inactivity_timeout(payload.timeout + 30)

            payload.store if payload.storable?
            payload.run if payload.runnable?

            send_response(200, payload_to_hash(payload))
          rescue AuthError => ex
            print_exception(ex, backtrace: false)
            close_connection
          rescue Exception => ex
            print_exception(ex)
            send_response(500, payload_to_hash(payload))
          end
        end
      end

      def payload_to_hash(payload)
        {path: payload.filepath, output: payload.output, return_code: payload.return_code, stored: payload.stored} if payload
      end

      def http_request_errback(ex)
        print_exception(ex)
      end

      def print_exception(ex, backtrace: true)
        text = "[#{ex.class}] #{ex.message}"
        text << "\n\t#{ex.backtrace.join("\n\t")}" if ex.backtrace and backtrace
        trace(:error, text)
      end

      def send_response(status_code, content = nil)
        response = EM::DelegatedHttpResponse.new(self)
        response.status = status_code
        response.content_type('application/json')
        response.content = content.to_json if content
        response.send_response
        trace(:info, "[#{@http[:host]}] REP #{status_code} #{response.content.size} bytes")
      end

      def self.start(port: 6677, address: "0.0.0.0")
        EM::run do
          trace_setup rescue $stderr.puts("trace_setup failed - logging only to stdout")

          trace(:info, "Starting RCS Updater server on #{address}:#{port}")
          EM::start_server(address, port, self)
        end
      rescue Interrupt
        trace(:fatal, "Interrupted by the user")
      end
    end
  end
end

if __FILE__ == $0
  RCS::Updater::Server.start
end
