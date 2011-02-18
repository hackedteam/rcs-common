module RCS

class DeviceEvidence
  TYPE_ID = 0x0240
  
  def type_id
    TYPE_ID
  end

  def content
    "The time is #{Time.now} ;)".to_utf16le_binary
  end

  def binary
    [ content ]
  end

  def additional_header
    ''
  end
  
  # TODO: implement decoding of evidence
  def decode_additional_header(data)
    
  end
  
  def decode_content(chunks)
    chunks.shift.force_encoding('UTF-16LE').encode('UTF-8')
  end
end

end # RCS::
