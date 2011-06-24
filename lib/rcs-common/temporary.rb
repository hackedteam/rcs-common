
module RCS

class Temporary
  def self.file(dir, filename)
    Dir.mkdir(dir) unless Dir.exists? dir
    tempfilename = File.join(dir, filename)
    f = File.new(tempfilename, 'wb+')
    return f
   end
end

end # ::RCS
