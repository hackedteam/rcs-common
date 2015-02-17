require 'base64'
require 'openssl/digest'
require 'json'

module RCS
  module Mongoid
    module Signature
      extend ActiveSupport::Concern

      included do
        cattr_accessor :signature_fields
        self.signature_fields = []

        field :signature, type: String
        set_callback :create, :before, :set_signature
        set_callback :update, :before, :set_signature
      end

      def set_signature
        now = Time.now.getutc.to_f

        #puts "SET: #{signature_fields} => #{concat_values(now, signature_fields)}"

        # save the version and the fields used to calculate the signature
        # this could help in the future if the signature_fields are changed
        hash = {version: 1,
                fields: signature_fields,
                timestamp: now,
                signature: calculate_signature(concat_values(now, signature_fields))}

        self.signature = Base64.strict_encode64(hash.to_json)
      end

      def check_signature
        # load the serialized signature
        hash = JSON.parse(Base64.decode64(self.signature)).with_indifferent_access

        #puts "CHECK: #{signature_fields} => #{concat_values(hash[:timestamp], hash[:fields])}"

        # calculate the signature based on the field used to create it (not the current list of fields)
        sig = calculate_signature(concat_values(hash[:timestamp], hash[:fields]))

        hash[:signature] == sig
      rescue Exception => e
        #puts e.message
        #puts e.backtrace.join("\n")
        false
      end

      def signature_fields
        self.class.signature_fields
      end

      private

      def calculate_signature(value)
        key = "ʎəʞ ʇəɹɔəs ɹədns əɥʇ sı sıɥʇ"
        Base64.strict_encode64(OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), key, value))
      end

      def concat_values(time, keys)
        # always include the id of the document to prevent cloning of document
        text = self[:_id].to_s

        # save the timestamp
        text << '|' + time.to_s

        # concatenate all the other fields
        keys.each do |key|
          # use json serialization here, since it works for strings, integers, complex arrays or hashes...
          text << '|' + self[key].to_json unless self[key].blank?
        end
        text << '|'
      end

      module ClassMethods
        def sign_options(options)
          self.signature_fields = options[:include] if options[:include]
        end
      end

    end
  end
end