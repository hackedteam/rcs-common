
require 'rcs-common/evidence/common'

module RCS

module InfoEvidence
  def content
    "(ruby) Backdoor started.".to_utf16le_binary
  end
  
  def generate_content
    [ content ]
  end

  def decode_content
    @info[:content] = @info[:content].force_encoding('UTF-16LE').encode('UTF-8')
  end
end

end # RCS::