require 'rcs-common/evidence/common'

module RCS

module CalllistEvidence
  
  def content
    
  end
  
  def generate_content
    
  end
  
  def decode_content(common_info, chunks)
    stream = StringIO.new chunks.join
    
    info = Hash[common_info]
    info[:data] = Hash.new if info[:data].nil?
    
    until stream.eof?
      size, version, ft_start_low, ft_start_high, ft_end_low, ft_end_high, props = binary.read(28).unpack('I*')
    
      start_time = Time.from_filetime(ft_start_high, ft_start_low)
      end_time = Time.from_filetime(ft_end_high, ft_end_low)
      info[:duration] = end_time - start_time
    end
    
    yield info if block_given?
    :delete_raw
  end
  
end

end # ::RCS