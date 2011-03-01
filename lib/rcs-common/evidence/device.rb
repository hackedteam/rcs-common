require 'rcs-common/evidence/common'

module RCS

class DeviceEvidence < Common::GenericEvidence

  def type_id
    0x0240
  end
  
  def content
    "The time is #{Time.now} ;)".to_utf16le_binary
  end
    
  def decode_content(chunks)
    chunks.shift.force_encoding('UTF-16LE').encode('UTF-8')
  end
end

end # RCS::
