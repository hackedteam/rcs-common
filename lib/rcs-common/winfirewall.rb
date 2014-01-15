require 'rcs-common/trace'

module RCS
  module Common
    module WinFirewall

      # Represent a Windows Firewall rule.
      class Rule
        ATTRIBUTES = %i[direction action local_ip remote_ip local_port remote_port name protocol profiles enabled grouping edge_traversal]

        RULE_GROUP = 'RCS Firewall Rules'

        attr_reader :attributes

        def initialize(attributes = {})
          # Default attribute values
          @attributes = {
            grouping: RULE_GROUP,
            protocol: :tcp
          }

          # Merge default attributes with the given ones
          # and remove invalid attributes
          attributes.symbolize_keys! if attributes.respond_to?(:symbolize_keys!)
          attributes.reject! { |key| !ATTRIBUTES.include?(key) }
          @attributes.merge!(attributes)

          # Define getters and setters
          ATTRIBUTES.each do |name|
            define_singleton_method(name) { @attributes[name] }
            define_singleton_method("#{name}=") { |value| @attributes[name] = value }
          end
        end

        def save
          command = "firewall add rule #{stringify_attributes}"

          raise "Unable to save firewall rule" unless Advfirewall.call(command).ok?
        end

        def del
          only = %i[dir profile program service localip remoteip localport remoteport protocol name]

          response = Advfirewall.call("firewall delete rule #{stringify_attributes(only)}")

          if response.no_match?
            0
          elsif response.ok?
            response.scan(/Deleted (\d+) rule/)[0][0].to_i
          else
            raise("Unable to delete firewall rule")
          end
        end

        private

        def stringify_attributes(only = [])
          attrs = {
            name:       name,
            dir:        direction,
            action:     action,
            enable:     enabled,
            protocol:   protocol,
            profile:    profiles,
            remoteip:   remote_ip,
            localip:    local_ip,
            localport:  local_port,
            remoteport: remote_port
          }

          string = ""

          attrs.each do |key, value|
            next if only.any? and !only.include?(key)
            next if value.to_s.strip.empty?
            next if value == :any
            value = value.respond_to?(:join) ? value.map(&:to_s).join(',') : "\"#{value}\""
            string << "#{key}=#{value} "
          end

          string
        end
      end


      # Parse the response of the netsh advfirewall command
      class AdvfirewallResponse < String
        def parse(block_separator_regexp: nil)
          blocks = nil

          self.each_line do |line|
            if line =~ block_separator_regexp
              blocks ||= []
              blocks << Hash.new
            end

            if blocks
              key, value = *line.strip.scan(/^(.+)\s{2,100}(.+)$/)[0]

              next unless key

              key.strip!
              key = key[0..-2] if key.end_with?(':')
              value.strip!

              blocks.last[key] = value
            end
          end

          blocks || []
        end

        def self.normalize(string, method: :underscore)
          if string.respond_to?(:map)
            string.map { |v| normalize(v, method: method) }
          else
            if method == :numeric
              string.to_i
            else
              return nil if string.blank?
              string.underscore.gsub(' ', '_').to_sym
            end
          end
        end

        def ok?
          self.strip =~ /Ok\.\z/
        end

        def no_match?
          self =~ /No rules match the specified criteria/i
        end
      end


      class Advfirewall
        extend RCS::Tracer

        # Return true if the current os is Windows
        def self.exists?
          @firewall_exists ||= (RbConfig::CONFIG['host_os'] =~ /mingw/i)
        end

        def self.call(command)
          command = "netsh advfirewall #{command.strip}"

          unless exists?
            raise "The Windows Firewall is missing. You cannot call the command #{command.inspect} on this OS."
          end

          trace(:debug, "[Advfirewall] #{command}")
          AdvfirewallResponse.new(`#{command}`)
        end
      end


      extend self


      # Return :on or :off depending of the firewall state
      #
      # Note that the files test/fixtures/advfirewall/show_currentprofile_state_on and
      # test/fixtures/advfirewall/show_currentprofile_state_off contains an example of the command output
      def status
        list = Advfirewall.call("show currentprofile state").parse(block_separator_regexp: /^Public Profile Settings:.+$/)
        list[0]['State'] == 'ON' ? :on : :off
      end

      # Enable or the disable the firewall. The netsh command requires elevation to succeed
      # Accpeted values are :on or :off
      def status=(state)
        raise "Invalid state" unless %w[on off].include?(state.to_s)
        response = Advfirewall.call("set currentprofile state #{state}")
        raise "Unable to change firewall state: #{response}" unless response.ok?
      end

      # Delegate
      def exists?
        Advfirewall.exists?
      end

      # Returns and array of #Rule
      #
      # Note that the files test/fixtures/advfirewall/firewall_show_rule_name_all
      # contains an example of the command output
      def rules
        list = Advfirewall.call("firewall show rule name=all").parse(block_separator_regexp: /^Rule Name:.+$/)

        list.map do |hash|
          hash.keys.each do |key|
            new_key, new_value = normalize(key), hash.delete(key)

            new_value = new_value.split(",").map(&:strip) if new_value.include?(",")

            hash[new_key] = if new_value == 'Any'
               normalize(new_value)
            elsif %i[local_ip remote_ip name grouping rule_name].include?(new_key)
              new_value
            elsif %i[local_port remote_port].include?(new_key)
              normalize(new_value, method: :numeric)
            else
              normalize(new_value)
            end
          end

          hash[:name] = hash.delete(:rule_name)

          Rule.new(hash)
        end
      end

      def add_rule(attributes)
        Rule.new(attributes).save
      end

      def del_rule(name)
        deleted = 0

        rules.each do |rule|
          if (name.kind_of?(Regexp) and rule.name =~ name) or (rule.name == name)
            deleted += rule.del
          end
        end

        deleted
      end

      private

      def normalize(string, **attributes)
        AdvfirewallResponse.normalize(string, attributes)
      end
    end
  end
end

WinFirewall = RCS::Common::WinFirewall
