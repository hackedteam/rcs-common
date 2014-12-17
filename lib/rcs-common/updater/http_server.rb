require 'yajl/json_gem'
require 'em-http-server'
require_relative "payload"
require_relative "../trace.rb"

module RCS
  module Updater
    class HTTPServer < EM::HttpServer::Server
      include RCS::Tracer

      def x_options
        @x_options ||= @http[:x_options] ? JSON.parse(@http[:x_options]) : Hash.new
      end

      def process_http_request
        EM.defer do
          begin
            trace :info, "[#{@http[:host]}] REQ #{@http_protocol} #{@http_request_method} #{@http_content.size} bytes"

            raise "Invalid http method" if @http_request_method != "POST"
            raise "No content" unless @http_content

            set_comm_inactivity_timeout (x_options['inactivity_timeout'] || 3600).to_i

            payload = Payload.new(@http_content, x_options)
            payload.store
            payload.run if payload.runnable?

            send_response(200, err: payload.return_code, out: payload.output)
          rescue Exception => ex
            print_exception(ex)
            send_response(500)
          end
        end
      end

      def http_request_errback(ex)
        print_exception(ex)
      end

      def print_exception(ex)
        text = "[#{ex.class}] #{ex.message}"
        text << "\n\t#{ex.backtrace.join("\n\t")}" if ex.backtrace
        trace :error, text
      end

      def send_response(status_code, content = nil)
        response = EM::DelegatedHttpResponse.new(self)
        response.status = status_code
        response.content_type('application/json')
        response.content = content.to_json if content
        response.send_response
        trace :info, "[#{@http[:host]}] REP #{status_code} #{response.content.size} bytes"
      end
    end
  end
end
