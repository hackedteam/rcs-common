require 'cgi'

module RCS

class URI
  def self.encode_query(hash)
    return "?" + hash.map{|k,v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"}.join("&")
  end
end

end # ::RCS