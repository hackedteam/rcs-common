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
        @auth_signature = SignatureFile.read
        puts @auth_signature
        super
      end

      def x_options
        @x_options ||= @http[:x_options] ? JSON.parse(@http[:x_options]) : Hash.new
      end

      def process_http_request
        EM.defer do
          begin
            trace(:info, "[#{@http[:host]}] REQ #{@http_protocol} #{@http_request_method} #{@http_content.size} bytes")

            raise AuthError.new("Invalid http method") if @http_request_method != "POST"
            raise AuthError.new("No content") unless @http_content
            raise AuthError.new("Invalid signature") if @auth_signature != @http[:x_signature]

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
