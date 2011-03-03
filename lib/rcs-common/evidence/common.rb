module RCS
module Common

EVIDENCE_TYPES = { 0 => :GENERIC, 0x0240 => :DEVICE, 0x0140 => :CALL, 0x0241 => :INFO }

class GenericEvidence
  
  attr_reader :info
  
  def initialize
    @info = {}
  end

  def type_id
    nil
  end
  
  def content
    ''
  end

  def binary
    [ content ]
  end

  def additional_header
    ''
  end

  def decode_additional_header(data)
    return 0
  end

  def decode_variable_additional_data(data)
    return 0
  end

  def decode_content(chunks)
  end
end

end # Common::
end # RCS::