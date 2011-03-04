
require 'ffi'
require 'stringio'

module RCS

EVIDENCE_TYPES = { 0x0240 => :DEVICE, 0x0140 => :CALL, 0x0241 => :INFO }

class AdditionalHeaderError < StandardError
end

end # RCS::