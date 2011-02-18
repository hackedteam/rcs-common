module RCS

class DeviceEvidence
  def type_id
    0x0240
  end

  def data
    [ "The time is #{Time.now}, and forcing to BINARY works ;)".to_utf16le ]
  end

  def additional_header
    ''
  end

  # TODO: implement decoding of evidence
  def decode
  end
end

end # RCS::
