require_relative "updater/http_server"
require_relative "trace.rb"

module RCS
  module Updater
    extend RCS::Tracer

    def self.start(port: 6677, address: "0.0.0.0")
      EM::run do
        trace(:info, "Starting RCS Updater server on port #{port} for #{address}")
        EM::start_server(address, port, HTTPServer)
      end
    rescue Interrupt
      trace(:fatal, "Interrupted by the user")
    end
  end
end

if __FILE__ == $0 and ENV['DEVELOPMENT']
  RCS::Updater.start
end
