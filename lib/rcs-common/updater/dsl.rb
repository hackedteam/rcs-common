require_relative 'client'
require 'ostruct'

class SafeOpenStruct < OpenStruct
  def method_missing(meth, *args)
    n = meth.to_s

    if n.end_with?("?")
      n = n[0..-2]
      return @table[n] || @table[n.to_sym]
    elsif !n.end_with?("=")
      raise(NoMethodError, "no `#{meth}' member set yet")
    end

    super
  end
end

module RCS
  module Updater
    module DSL
      @@settings = SafeOpenStruct.new
      @@tasks = {}

      def set(name, value)
        @@settings[name] = value
      end

      # Access to settings defined using [ set ]
      def settings
        @@settings
      end

      # Define a task or alias an existing task
      #
      # @example
      #   task :task1 do
      #     rm_rf("/tmp/my_file")
      #     start_service("RCSDB")
      #   end
      #   # Aliasing task1
      #   task :task3 => :task1
      def task(name, &block)
        if name.kind_of?(Hash)
          name.each do |alias_name, task_name|
            raise("Undefined task `#{task_name}'") unless @@tasks[task_name.to_s]
            @@tasks[alias_name.to_s] = @@tasks[task_name.to_s]
          end
        else
          raise("Task `#{name}' is defined more than once") if @@tasks[name.to_s]
          @@tasks[name.to_s] = block
        end
      end

      # @example
      #   invoke :task1 => 'localhost'
      #
      #   task :task2 do
      #     invoke(:task3)
      #     rm_rf("/tmp/my_file")
      #   end
      def invoke(args)
        if self.respond_to?(:address) and ([String, Symbol].include?(args.class))
          task_name, address = args, self.address
        elsif !self.respond_to?(:address) and args.kind_of?(Hash)
          task_name, address =  *args.to_a.flatten
        else
          raise("Invalid use of `invoke'")
        end

        # begin debug part
        log("[task] #{task_name} => #{address}")
        # end debug part

        client = Client.new(address)
        raise("Undefined task `#{task_name}'") unless @@tasks[task_name.to_s]
        client.instance_eval(&@@tasks[task_name.to_s])
      end

      # @example
      #   on('172.20.20.152') do
      #     invoke(:task1)
      #     rm_rf("/tmp/my_file")
      #   end
      def on(address, &block)
        raise("You cannot call `on' in this context") if self.respond_to?(:address)
        client = Client.new(address)
        client.instance_eval(&block)
      end

      def log(string)
        puts string
      end

      # Access to parameters passed via command line.
      #
      # @example Script is called with --first-param "test" --param2
      #   params.first_param #=> "test"
      #   params.param2      #=> true
      #   params.param3      #=> An exception is raised!
      #   params.param3?     #=> nil
      def params
        return @@params if defined?(@@params)
        @@params = SafeOpenStruct.new
        i = 0

        loop do
          s1, s2 = ARGV[i], ARGV[i+1]
          break unless s1
          if s1[0] == '-'
            s2 = (s2 and s2[0] != '-') ? s2 : true
            @@params[s1.gsub(/^\-{1,2}/, '').gsub('-', '_')] = s2 unless s2.to_s.strip.empty?
          end
          i += 1
        end

        @@params
      end
    end
  end
end


RCS::Updater::Client.__send__(:include, RCS::Updater::DSL)
extend RCS::Updater::DSL
