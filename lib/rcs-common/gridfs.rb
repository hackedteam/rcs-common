require 'mongoid'
require 'digest/md5'

module RCS
  module Common
    module GridFS
      BSON = Moped::BSON if Mongoid::VERSION < '4.0.0'

      class ReadOnlyFile
        attr_reader :attributes, :bucket, :file_position

        def initialize(bucket, attributes)
          @attributes = attributes
          @bucket = bucket
          @last_chunk_num = (@attributes[:length].to_f / @attributes[:chunk_size]).ceil - 1
          rewind
        end

        def method_missing(name)
          raise NoMethodError.new(name.inspect) unless @attributes.has_key?(name)
          @attributes[name]
        end

        def read(bytes_to_read = nil)
          data = ''

          return data if @file_position >= @attributes[:length]
          return data if bytes_to_read and bytes_to_read <= 0

          if @current_chunk[:n]
            chunk_size = @attributes[:chunk_size]
            offset = @file_position % chunk_size
            offset = chunk_size if offset == 0
            data = @current_chunk[:data][offset..-1] || ''
          end

          if bytes_to_read.nil? or bytes_to_read > data.bytesize
            loop do
              break unless read_next_chunk
              data << @current_chunk[:data]

              break if bytes_to_read and bytes_to_read <= data.bytesize
            end
          end

          bytes_to_read = bytes_to_read ? bytes_to_read - 1 : -1
          data = data[0..bytes_to_read]
          @file_position += data.bytesize
          data
        end

        def rewind
          @current_chunk = {n: nil, data: nil}
          @file_position = 0
        end

        def eof?
          @file_position >= @attributes[:length]
        end

        def id
          @attributes[:_id]
        end

        def file_length
          @attributes[:length]
        end

        alias :content :read
        alias :tell :file_position
        alias :position :file_position
        alias :pos :file_position

        private

        def read_next_chunk
          chunk_num = @current_chunk[:n] ? @current_chunk[:n] + 1 : 0
          return nil if chunk_num == @last_chunk_num + 1

          chunk = bucket.chunks_collection.find(files_id: @attributes[:_id], n: chunk_num).first
          @current_chunk = {n: chunk['n'], data: chunk['data'].data}
        end
      end

      class Bucket
        attr_reader :session, :name, :files_collection, :chunks_collection

        DEFAULT_NAME          = 'fs'
        DEFAULT_CONTENT_TYPE  = 'application/octet-stream'
        DEFAULT_CHUNK_SIZE    =  262144
        BINARY_ENCODING       = 'BINARY'

        def initialize(name = DEFAULT_NAME, options = {})
          @name               = name.to_s.downcase.strip
          @name               = DEFAULT_NAME if @name.empty?
          @session            = options[:session] || Mongoid.default_session
          @files_collection   = @session[:"#{@name}.files"]
          @chunks_collection  = @session[:"#{@name}.chunks"]
          @setup_on_write     = options[:lazy].nil? ? true : options[:lazy]

          setup unless @setup_on_write
        end

        def put(content, attrs = {}, options = {})
          return if content.nil?

          file = {}

          file[:_id]         = BSON::ObjectId.new
          file[:length]      = content.bytesize
          file[:chunkSize]   = DEFAULT_CHUNK_SIZE

          return if file[:length].zero?

          file[:filename]    = attrs[:filename]
          file[:contentType] = attrs[:content_type] || attrs[:contentType] || DEFAULT_CONTENT_TYPE
          file[:aliases]     = attrs[:aliases] || []
          file[:aliases]     = [file[:aliases]].flatten
          file[:metadata]    = attrs[:metadata] || {}
          file[:metadata]    = {} if file[:metadata].blank?
          file[:uploadDate]  = attrs[:upload_date] || attrs[:uploadDate] || Time.now.utc

          file[:md5] = write(file[:_id], content, options)

          files_collection.insert(file)

          file[:_id]
        end

        def md5(file_id)
          doc = session.command(filemd5: file_id, root: name)
          doc['md5'] if doc.respond_to?(:[])
        end

        def append(file_id, data, options = {})
          file_id = objectid(file_id)
          attributes = files_collection.find(_id: file_id).first

          raise("File not found: #{file_id}") unless attributes

          attributes.symbolize_keys!

          length, chunk_size = attributes[:length], attributes[:chunkSize]

          chunk_offset = (length / chunk_size).to_i
          offset = length % chunk_size

          if offset > 0
            data = chunks_collection.find(files_id: file_id, n: chunk_offset).first['data'].data + data
          end

          chunkerize(data) do |chunk_data, chunk_num|
            chunks_collection.find(files_id: file_id, n: chunk_num + chunk_offset).upsert('$set' => {data: binary(chunk_data)})
          end

          new_md5 = md5(file_id) if options[:md5] != false
          new_length = length - offset + data.bytesize

          files_collection.find(_id: file_id).update('$set' => {length: new_length, md5: new_md5})

          new_length
        end

        # Equivalent to #get(id).read
        def content(file_id)
          file_id = objectid(file_id)

          chunks_collection.find(files_id: file_id, n: {'$gte' => 0}).inject("") do |data, chunk|
            data << chunk['data'].data
          end
        end

        def get(file_id, options = {})
          file_id = objectid(file_id)
          attributes = files_collection.find(_id: file_id).first

          return unless attributes

          attributes.symbolize_keys!
          attributes[:bucket] = self
          attributes[:chunk_size] = attributes[:chunkSize]
          attributes[:content_type] = attributes[:contentType]
          attributes[:upload_date] = attributes[:uploadDate]

          ReadOnlyFile.new(self, attributes)
        end

        def delete(file_id)
          file_id = objectid(file_id)

          files_collection.find(_id: file_id).remove
          chunks_collection.find(files_id: file_id).remove_all
        end

        def drop
          [files_collection, chunks_collection].map(&:drop)
          @setup_on_write = true
        end

        alias :remove :delete

        private

        def objectid(id)
          id.respond_to?(:generation_time) ? id : BSON::ObjectId.from_string(id.to_s)
        end

        def setup
          chunks_collection.indexes.create({files_id: 1, n: 1}, {unique: true})
          # This is an optional index (not required by the gridfs specs)
          files_collection.indexes.create({filename: 1}, {background: true})
          nil
        end

        def chunkerize(data)
          offset = 0
          chunk_num = 0

          loop do
            chunk_data = data.byteslice(offset..(offset + DEFAULT_CHUNK_SIZE - 1))
            break if chunk_data.nil?
            chunk_data_size = chunk_data.bytesize
            offset += chunk_data_size
            break if chunk_data_size == 0
            yield(chunk_data, chunk_num)
            break if chunk_data_size < DEFAULT_CHUNK_SIZE
            chunk_num += 1
          end
        end

        def write(file_id, data, options = {})
          @setup_on_write = setup if @setup_on_write

          md5 = Digest::MD5.new if options[:md5] != false

          chunkerize(data) do |chunk_data, chunk_num|
            chunks_collection.insert(files_id: file_id, n: chunk_num, data: binary(chunk_data))
            md5.update(chunk_data) if md5
          end

          md5.hexdigest if md5
        end

        def binary(data)
          data.force_encoding(BINARY_ENCODING) if data.respond_to?(:force_encoding)
          BSON::Binary.new(:generic, data)
        end
      end
    end
  end
end
