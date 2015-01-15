module RCS
  module Updater
    class SignatureFile
      attr_reader :path

      def initialize
        # Search for the signature file in some places
        [File.expand_path(Dir.pwd), "C:/RCS/DB", "C:/RCS/Collector"].each do |root|
          ["#{root}/config/rcs-updater.sig", "#{root}/config/certs/rcs-updater.sig"].each do |path|
            @path = path if File.exists?(path)
          end
        end
      end

      def read
        if ENV['SIGNATURE']
          return ENV['SIGNATURE']
        elsif path
          string = File.read(path)
          return string unless string.empty?
        else
          return nil
        end
      end

      def self.read
        new.read
      end
    end
  end
end
