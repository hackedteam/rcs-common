require 'yajl/json_gem'
require 'net/http'
require 'uri'
require 'timeout'

require_relative "../trace.rb"
require_relative "client_helpers"
require_relative "signature_file"

module RCS
  module Updater
    class Client
      include RCS::Tracer

      attr_reader :address, :port
      attr_accessor :max_retries, :retry_interval, :open_timeout
      attr_accessor :pwd

      def initialize(address, port: 6677)
        @address = address
        @port = port
        @signature = SignatureFile.read

        self.max_retries = 3
        self.retry_interval = 4 # sec
        self.open_timeout = 8 # sec

        yield(self) if block_given?
      end

      def request(payload, options = {}, retry_count = self.max_retries)
        http = Net::HTTP.new(address, port)
        req = Net::HTTP::Post.new('/', initheader = {'Content-Type' =>'application/json'})
        req['x-options'] = options.to_json
        req['x-signature'] = @signature
        req.body = payload

        msg = options[:store] ? [] : [payload]
        msg = ["#{payload.size} B", options.inspect]
        trace(:debug, "REQ #{msg.join(' | ')}")

        http.open_timeout = self.open_timeout
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

      include ClientHelpers
    end
  end
end
