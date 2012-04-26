#
# runtime patching for SQLite3
#

require 'sqlite3'

module SQLite3

class Database

  def self.safe_escape(*strings)
    strings.each do |s|
      s.replace SQLite3::Database.quote(s) if s.class == String
    end
  end

end

end