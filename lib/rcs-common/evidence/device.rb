require 'rcs-common/evidence/common'

module RCS

module DeviceEvidence
  def content
    "The time is #{Time.now} ;)".to_utf16le_binary
  end

  def generate_content
    [ content ]
  end

  def decode_content
    @info[:data][:content] = @info[:chunks].join.utf16le_to_utf8
    return [self]
  end
end

end # RCS::
