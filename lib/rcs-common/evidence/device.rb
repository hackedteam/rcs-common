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
    @info[:content] = @info[:content].from_utf16le
  end
end

end # RCS::
