require 'openssl'
require 'base64'

module RCS
  module Updater
    class SharedKey

      def initialize
        # Search for the signature file in some places
        [File.expand_path(Dir.pwd), "C:/RCS/DB", "C:/RCS/Collector"].each do |root|
          ["#{root}/config/rcs-updater.sig", "#{root}/config/certs/rcs-updater.sig"].each do |path|
            @path = path if File.exists?(path)
          end
        end
      end

      def read_key_from_file
        return ENV['SIGNATURE'] if ENV['SIGNATURE']

        if @path
          key = File.read(@path)
          return key.empty? ? nil : key
        else
          return nil
        end
      end

      def key_file_exists?
        @path && File.exists?(@path)
      end

      def prepare_cipher(mode)
        @cipher = OpenSSL::Cipher::AES.new(256, :CBC)
        mode == :encrypt ? @cipher.encrypt : @cipher.decrypt
        @cipher.padding = 1
        @cipher.key = read_key_from_file || raise("Missing or empty signature file")
        @cipher.iv = "\xBA\xF0\xC0Z\xD7\xE8~[TP\xFE\x88rW\xC8\xF4"
      end

      def encrypt(data)
        prepare_cipher(:encrypt)
        return @cipher.update(data) + @cipher.final
      end

      def decrypt(data)
        prepare_cipher(:decrypt)
        return @cipher.update(data) + @cipher.final
      end

      def encrypt_hash(hash)
        Base64.urlsafe_encode64(encrypt(hash.to_json))
      end

      def decrypt_hash(data)
        JSON.parse(decrypt(Base64.urlsafe_decode64(data)))
      end
    end
  end
end
