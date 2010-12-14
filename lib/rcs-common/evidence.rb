#
# Evidence factory (backdoor logs)
#

require 'securerandom'

module RCS
  
class Evidence
  attr_reader :size
  attr_reader :content
  attr_reader :name
  attr_reader :timestamp
  
  # factory to create a random evidence
  def initialize
    @name =  SecureRandom.hex(16)
    @timestamp = Time.new
    
    @content = 'prova log'
    @size = @content.length
    
  end
      
end

end # RCS::

if __FILE__ == $0
  # TODO Generated stub
end