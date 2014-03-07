require 'spec_helper'
require 'rcs-common/gridfs'

module RCS::Common::GridFS

  describe 'compatibility' do

    begin
      # Note: use the modified version of mongo-ruby-driver (with append support)
      # path = File.expand_path('~/.rvm/gems/ruby-2.0.0-p451@rcs-project/bundler/gems/mongo-ruby-driver-b1d59bfe1700/lib')
      # $LOAD_PATH << path if File.exist?(path)

      require 'mongo'
    rescue LoadError
      $mongo_gem_missing = true
    end

    break if $mongo_gem_missing

    let(:bucket) { Bucket.new }

    let(:db_name) { bucket.session.instance_variable_get('@current_database').name }

    let(:mongo_client_db) { Mongo::MongoClient.new[db_name] }

    let(:grid) { Mongo::Grid.new(mongo_client_db)}

    let(:grid_filesystem) { Mongo::GridFileSystem.new(mongo_client_db) }

    let(:chunk_size) { Bucket::DEFAULT_CHUNK_SIZE }

    it 'is compatibile with mongo grid#put' do
      data = 'foo bar'
      id = grid.put(data)
      expect(bucket.get(id.to_s).read).to eq(data)

      data = ('bar'*chunk_size)+'foo'
      id = grid.put(data)
      expect(bucket.get(id.to_s).read).to eq(data)
    end

    it 'is compatibile with mongo grid#get' do
      data = 'foo bar'
      id = bucket.put(data)
      id = ::BSON::ObjectId.from_string(id.to_s)
      expect(grid.get(id).read).to eq(data)

      data = ('bar'*chunk_size)+'foo'
      id = bucket.put(data)
      id = ::BSON::ObjectId.from_string(id.to_s)
      expect(grid.get(id).read).to eq(data)
    end

    it 'is compatibile with mongo file#read' do
      data = ('bar'*chunk_size*5)+'foo'

      id = grid.put(data)

      bucket_file = bucket.get(id.to_s)
      grid_file = grid.get(id)

      # NOTE: the difference here is that grid_file.read returns an empty string
      # when the file is finished while bucket_file.read returns nil
      loop do
        bytes = rand(0..1000)
        buff1 = grid_file.read(bytes)
        buff2 = bucket_file.read(bytes) || ''
        expect(buff1).to eq(buff2)
        break if buff1 == '' or buff2 == ''
      end
    end

    it 'is compatibile with mongo-ruby-driver append' do
      data = "foo"*chunk_size

      id = bucket.put('a')
      id2 = ::BSON::ObjectId.new
      fs = grid_filesystem.open(id2, 'w') { |f| f.write('a') }

      index, seek = 0, (chunk_size / 2 - 10)

      loop {
        cnt = data[index..index+seek-1]
        break if cnt.nil? or cnt.size == 0
        index += seek

        bucket.append(id, cnt)
        grid_filesystem.open(id2, 'a') { |f| f.write(cnt) }

        expect(bucket.content(id)).to eq('a'+data[0..index - 1])
        expect(grid_filesystem.open(id2, 'r') { |f| f.read }).to eq('a'+data[0..index - 1])
      }
    end
  end

  # Keep it at least >= 3 in these tests
  $chunk_size = 5

  describe File do

    before do
      Bucket.__send__(:remove_const, :DEFAULT_CHUNK_SIZE)
      Bucket.const_set(:DEFAULT_CHUNK_SIZE, $chunk_size)
    end

    let(:bucket) { Bucket.new }

    let(:content) { ('a'*$chunk_size)+'b' }

    describe '#read' do

      let(:file) { bucket.get(bucket.put(content)) }

      it 'reads the entire file without parameters' do
        expect(file.read).to eq(content)
      end

      it 'reads the file sequentially' do
        expect(file.read($chunk_size)).to eq('a'*$chunk_size)
        expect(file.read).to eq('b')

        file.rewind
        expect(file.read($chunk_size)).to eq('a'*$chunk_size)
        expect(file.read($chunk_size)).to eq('b')

        file.rewind
        expect(file.read($chunk_size-1)).to eq(('a'*($chunk_size-1)))
        expect(file.read).to eq('ab')
        expect(file.read).to be_nil

        file.rewind
        $chunk_size.times { expect(file.read(1)).to eq('a') }
        expect(file.read(1)).to eq('b')
        expect(file.read(1)).to be_nil

        file.rewind
        expect(file.read($chunk_size**2)).to eq(content)
      end
    end
  end

  describe Bucket do

    before do
      described_class.__send__(:remove_const, :DEFAULT_CHUNK_SIZE)
      described_class.const_set(:DEFAULT_CHUNK_SIZE, $chunk_size)
    end

    it "deal with different encodings" do
      bucket = Bucket.new

      non_utf8_string = "- Men\xFC -"
      expect(non_utf8_string.valid_encoding?).to be_false
      id = bucket.put non_utf8_string
      file = bucket.get(id)
      expect(file.read.encoding.to_s).to eq('ASCII-8BIT')

      utf8_string = "ciao"
      id = bucket.put utf8_string
      file = bucket.get(id)
      expect(file.read.encoding.to_s).to eq('UTF-8')
    end

    describe '#append' do

      let(:bucket) { Bucket.new }

      it 'appends the given data to the file' do
        content = 'a'*$chunk_size
        file_id = bucket.put(content)

        content << 'b'
        bucket.append(file_id, 'b')
        expect(bucket.content(file_id)).to eq(content)

        content << 'c'*$chunk_size
        bucket.append(file_id, 'c'*$chunk_size)
        expect(bucket.content(file_id)).to eq(content)

        content << 'd'*($chunk_size-1)
        bucket.append(file_id, 'd'*($chunk_size-1))
        expect(bucket.content(file_id)).to eq(content)
      end

      it 'updates the file length' do
        content = 'a'*$chunk_size
        file_id = bucket.put(content[1])
        expect(bucket.get(file_id).length).to eq(1)
        bucket.append(file_id, content[1..-1])
        expect(bucket.get(file_id).length).to eq(content.bytesize)

        content = 'a'*$chunk_size * 2
        file_id = bucket.put(content[0..$chunk_size-1])
        expect(bucket.get(file_id).length).to eq($chunk_size)
        bucket.append(file_id, content[$chunk_size..-1])
        expect(bucket.get(file_id).length).to eq($chunk_size * 2)
      end

      it 'updates the md5 (by default)' do
        content = 'a'*$chunk_size
        file_id = bucket.put(content[1])
        expect(bucket.get(file_id).md5).to eq(Digest::MD5.hexdigest('a'))
        bucket.append(file_id, content[1..-1])
        expect(bucket.get(file_id).md5).to eq(Digest::MD5.hexdigest(content))
      end

      context "when {md5: false} is given as options" do

        it 'sets the md5 attribute to nil' do
          content = 'a'*$chunk_size
          file_id = bucket.put(content[1])
          expect(bucket.get(file_id).md5).to eq(Digest::MD5.hexdigest('a'))
          bucket.append(file_id, content[1..-1], md5: false)
          expect(bucket.get(file_id).md5).to be_nil
        end
      end
    end

    describe '#delete' do

      let(:bucket) { Bucket.new }

      let(:content) { ('a'*$chunk_size)+'b' }

      it 'returns nil when the file exists' do
        id = bucket.put(content)
        expect(bucket.delete(id)).to be_nil
      end

      it 'returns nil when the file is missing' do
        id = Moped::BSON::ObjectId.new
        expect(bucket.delete(id)).to be_nil
      end

      it 'removes the file and its chunks' do
        id = bucket.put(content)
        expect(id).not_to be_nil
        bucket.delete(id)
        expect(bucket.get(id)).to be_nil
        expect(bucket.files_collection.find(_id: id).count).to be_zero
        expect(bucket.chunks_collection.find(files_id: id).count).to be_zero
      end

      it 'does not deletes other files' do
        id = bucket.put(content)
        id2 = bucket.put(content+'c')

        bucket.delete(id)

        expect(bucket.get(id)).to be_nil
        expect(bucket.get(id2).read).to eq(content+'c')
      end
    end

    describe '#drop' do

      it 'removes the collections' do
        bucket = Bucket.new(nil, lazy: false)
        bucket.drop
        expect(bucket.session.collections).to be_empty
      end

      context 'when the collections are missing' do

        let(:bucket) do
          bucket = Bucket.new
        end

        context '#get' do

          it 'returns nil (without errors)' do
            expect(bucket.get(Moped::BSON::ObjectId.new)).to be_nil
          end
        end

        context '#put' do

          it 'creates the collections and the indexes' do
            bucket.put 'foo bar'
            expect(bucket.session['fs.chunks'].indexes.count).to eq(2)
            expect(bucket.session['fs.files'].indexes.count).to eq(2)
          end
        end
      end
    end

    describe '#initialize' do

      it 'creates the requied collections with the default name' do
        session = Bucket.new(nil, lazy: false).session
        names = session.collections.map(&:name).sort
        expect(names).to eq(['fs.chunks', 'fs.files'])
      end

      it 'creates the requied collections with the given prefix' do
        session = Bucket.new('foo.bar', lazy: false).session
        names = session.collections.map(&:name).sort
        expect(names).to eq(['foo.bar.chunks', 'foo.bar.files'])
      end

      it 'creates the indexes' do
        session = Bucket.new(nil, lazy: false).session

        db_name = session.instance_variable_get('@current_database').name

        chunks_indexes = session['fs.chunks'].indexes
        files_indexes = session['fs.files'].indexes

        expect(chunks_indexes.count).to eq(2)
        expect(chunks_indexes.to_a[1]).to eq("v"=>1, "key"=>{"files_id"=>1, "n"=>1}, "unique"=>true, "ns"=>"#{db_name}.fs.chunks", "name"=>"files_id_1_n_1")

        expect(files_indexes.count).to eq(2)
        expect(files_indexes.to_a[1]).to eq("v"=>1, "key"=>{"filename"=>1}, "ns"=>"#{db_name}.fs.files", "background"=>true, "name"=>"filename_1")
      end

      context 'when nil is passed as name' do

        it 'creates the requied collections with the default name' do
          session = Bucket.new(nil, lazy: false).session
          names = session.collections.map(&:name).sort
          expect(names).to eq(['fs.chunks', 'fs.files'])
        end
      end

      context 'when a blank string is passed as name' do

        it 'creates the requied collections with the default name' do
          session = Bucket.new('  ', lazy: false).session
          names = session.collections.map(&:name).sort
          expect(names).to eq(['fs.chunks', 'fs.files'])
        end
      end

      context 'when lazy' do

        it 'does not create the collections' do
          session = Bucket.new('fs', lazy: true).session
          expect(session.collections).to be_empty
        end
      end
    end

    describe '#md5' do

      let(:bucket) { Bucket.new }

      let(:content) { "foo bar" }

      let(:md5) { Digest::MD5.hexdigest(content) }

      it 'gets the md5 of a stored file' do
        id = bucket.put(content)
        expect(bucket.md5(id)).to eq(md5)
      end

      it 'does not read the md5 attribute on the file document' do
        id = bucket.put(content)
        bucket.files_collection.find(_id: id).update('$set' => {md5: 'foo'})

        expect(bucket.md5(id)).to eq(md5)
        expect(bucket.get(id).md5).to eq('foo')
      end
    end

    describe '#get' do

      let(:bucket) { Bucket.new }

      let(:content) { "foo bar" }

      it 'retuns a object with a read method' do
         id = bucket.put(content)
         expect(bucket.get(id)).to respond_to(:read)
      end

      it 'returns nil when nothing is found' do
         id = Moped::BSON::ObjectId.new
         expect(bucket.get(id)).to be_nil
      end

      it 'works if the given id is a string' do
        id = bucket.put(content)
        expect(bucket.get(id.to_s)).not_to be_nil
      end

      it 'works if the given id is a (Moped::)BSON::ObjectId' do
        id = bucket.put(content)
        id = BSON ? BSON::ObjectId.from_string(id.to_s) : Moped::BSON::ObjectId.from_string(id.to_s)
        expect(bucket.get(id)).not_to be_nil
      end

      it 'does not works with filenames (raise an error)' do
        id = bucket.put(content, filename: 'foo.bar')
        expect{ bucket.get('foo.bar') }.to raise_error(/is not a valid object id/)
      end
    end

    describe '#put' do

      let(:bucket) { Bucket.new }

      let(:now) { Time.now.utc }

      context 'the file size is 7 bytes (< DEFAULT_CHUNK_SIZE)' do

        let(:content) { "foo bar" }

        it 'returns nil when nil (or empty string) is passed as content' do
          expect(bucket.put(nil)).to be_nil
          expect(bucket.files_collection.find.count).to be_zero
          expect(bucket.chunks_collection.find.count).to be_zero
        end

        it 'stores a file with the given (valid) attributes' do
          id = bucket.put(content, filename: 'prova.txt', upload_date: now, metadata: {a: 1})
          file = bucket.get(id)

          expect(file.read).to eq(content)
          expect(file.filename).to eq('prova.txt')
          expect(file.upload_date.to_i).to eq(now.to_i)
          expect(file.metadata).to eq({'a' => 1})
        end

        it 'ignores invalid attributes' do
          id = bucket.put(content, foo: 'bar', content_type: 'text')
          file = bucket.get(id)

          expect(file.foo).to be_nil
          expect(file.content_type).to eq('text')
        end

        it 'forces the aliases attribute to be an array' do
          id = bucket.put(content, aliases: 'bar')
          file = bucket.get(id)

          expect(file.aliases).to eq(['bar'])

          id = bucket.put(content, aliases: ['bar', 'foo'])
          file = bucket.get(id)

          expect(file.aliases).to eq(['bar', 'foo'])
        end


        it 'forces the metadata attribute to be an hash when its empty' do
          id = bucket.put(content, metadata: '')
          file = bucket.get(id)

          expect(file.metadata).to eq({})

          id = bucket.put(content, metadata: nil)
          file = bucket.get(id)

          expect(file.metadata).to eq({})
        end

        it 'does not overwrite calculated attributes' do
          id = bucket.put(content, md5: 'foo', chunk_size: 'foo', chunkSize: 'foo', length: 'foo')
          file = bucket.get(id)

          expect(file.md5).to eq(Digest::MD5.hexdigest(content))
          expect(file.length).to eq(content.bytesize)
          expect(file.chunk_size).to eq($chunk_size)
          expect(file.chunkSize).to eq($chunk_size)
        end

        it 'uses default values for some attributes' do
          id = bucket.put(content, filename: 'prova.txt')
          file = bucket.get(id)

          expect(file.content_type).to eq('application/octet-stream')
          expect(file.aliases).to eq([])
          expect(file.metadata).to eq({})
        end
      end

      context 'the file size is DEFAULT_CHUNK_SIZE bytes long' do

        let(:content) { 'a'*$chunk_size }

        it 'uses only a chunk' do
          id = bucket.put(content)
          expect(bucket.chunks_collection.find(files_id: id).count).to eq(1)
        end

        it 'the chunk number is zero' do
          id = bucket.put(content)
          expect(bucket.chunks_collection.find(files_id: id).first['n']).to eq(0)
        end

        it 'stores the files correctly' do
          id = bucket.put(content)
          file = bucket.get(id)

          expect(file.read).to eq(content)
          expect(file.md5).to eq(bucket.md5(id))
          expect(file.length).to eq($chunk_size)
        end
      end

      context 'the file size is DEFAULT_CHUNK_SIZE + 1 bytes long' do

        let(:content) { ('a'*$chunk_size)+'b' }

        it 'uses 2 chunks' do
          id = bucket.put(content)
          expect(bucket.chunks_collection.find(files_id: id).count).to eq(2)
        end

        it 'numbers the chunks correctly' do
          id = bucket.put(content)
          numbers = bucket.chunks_collection.find(files_id: id).map { |doc| doc['n'] }
          expect(numbers).to eq([0, 1])
        end

        it 'stores the files correctly' do
          id = bucket.put(content)
          file = bucket.get(id)

          expect(file.read).to eq(content)
          expect(file.md5).to eq(bucket.md5(id))
          expect(file.length).to eq($chunk_size + 1)
        end
      end


      context 'the file size is DEFAULT_CHUNK_SIZE * 2 bytes long' do

        let(:content) { 'a'*$chunk_size*2 }

        it 'uses 2 chunks' do
          id = bucket.put(content)
          expect(bucket.chunks_collection.find(files_id: id).count).to eq(2)
        end

        it 'numbers the chunks correctly' do
          id = bucket.put(content)
          numbers = bucket.chunks_collection.find(files_id: id).map { |doc| doc['n'] }
          expect(numbers).to eq([0, 1])
        end

        it 'stores the files correctly' do
          id = bucket.put(content)
          file = bucket.get(id)

          expect(file.read).to eq(content)
          expect(file.md5).to eq(bucket.md5(id))
          expect(file.length).to eq($chunk_size*2)
        end
      end
    end
  end
end
