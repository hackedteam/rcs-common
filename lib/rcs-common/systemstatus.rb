require 'sys/filesystem'
require 'sys/cpu'

include Sys

module RCS
  module SystemStatusCodes
    OK = "OK"
    WARN = "WARN"
    ERROR = "ERROR"
  end

  module SystemStatusMixin
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def change_status(*args); SystemStatus.set(*args); end
    end

    def change_status(*args); SystemStatus.set(*args); end
  end

  # Status of the process and system
  class SystemStatus
    include SystemStatusCodes

    DEFAULT = {status: OK, message: "Idle"}

    @@prev_cpu = {}
    @@prev_time = {}
    @@current = DEFAULT

    def self.reset
      @@current = DEFAULT
    end

    def self.set(status, message)
      @@current = {status: status.to_s.upcase, message: message}
    end

    def self.status
      @@current[:status]
    end

    def self.message
      @@current[:message]
    end

    # returns the percentage of free space
    def self.disk_free
      # check the filesystem containing the current dir
      path = Dir.pwd
      # windows just want the drive letter, won't work with full path
      path = path.slice(0..2) if RUBY_PLATFORM.downcase.include?("mingw")
      stat = Filesystem.stat(path)
      # get the free and total blocks
      free = stat.blocks_free.to_f
      total = stat.blocks.to_f
      # return the percentage (pessimistic)
      return (free / total * 100).floor
    end

    # returns an indicator of the CPU usage in the last minute
    # not exactly the CPU usage percentage, but very close to it
    def self.cpu_load
      # cpu load in the last minute
      avg = CPU.load_avg
      if avg.is_a? Array
        # under unix like, there are 3 values (1, 15 and 15 minutes)
        load_last_minute = avg.first
        # default values for systems where the number is not reported (linux)
        num_cpu = 1
        num_cpu = CPU.num_cpu if CPU.num_cpu
        # on multi core systems we have to divide by the number of CPUs
        percentage = (load_last_minute / num_cpu * 100).floor
      else
        # under windows there is only one value that is the percentage
        percentage = avg
        # sometimes it returns nil under windows
        percentage ||= 0
      end

      return percentage
    end

    # returns the CPU usage of the current process
    def self.my_cpu_load(me)

      # the first call to it, keep track of different thread calling the method
      @@prev_cpu[me] ||= Process.times
      @@prev_time[me] ||= Time.now

      # calculate the current cpu time
      current_cpu = Process.times

      # diff them and divide by the call interval
      cpu_time = (current_cpu.utime + current_cpu.stime) - (@@prev_cpu[me].utime + @@prev_cpu[me].stime)
      time_diff = Time.now - @@prev_time[me]
      # prevent division by zero on low res systems
      time_diff = (time_diff == 0) ? 1 : time_diff
      # calculate the percentage
      cpu_percent = cpu_time / time_diff

      # remember it for the next iteration
      @@prev_cpu[me] = Process.times
      @@prev_time[me] = Time.now

      return cpu_percent.ceil
    end
  end
end
