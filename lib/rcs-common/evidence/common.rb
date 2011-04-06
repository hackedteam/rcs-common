
require 'ffi'
require 'stringio'

module RCS

EVIDENCE_TYPES = { 0x0240 => :DEVICE, 0x0140 => :CALL, 0x0241 => :INFO, 0xb9b9 => :SNAPSHOT }

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