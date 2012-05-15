#
# Class to keep statistics by minute, hour, day, week and so on...
# to be subclassed and customized
#

module RCS

class Stats

  def initialize
    @stats = {}

    # the template can be provided by the subclass
    @template ||= Hash.new(0)

    # total statistics ever
    @stats[:total] = @template.dup

    # remember the time when the total count was started
    @stats[:total][:start] = Time.now.getutc

    # sections to keep stats for
    # the values are the tipping point
    @sections ||= {:minutes => 0, :hours => 60, :days => 24, :weeks => 7}

    # create the templates for each section
    @sections.each_key do |section|
      @stats[section] = {}
      @stats[section][:last] = Array.new(5) { @template.dup }
      @stats[section][:average] = @template.dup
      @stats[section][:average][:samples] = 0
    end

  end

  def stats(section = nil)
    section ? @stats[section] : @stats
  end

  def add(hash)
    # for each key sum up the counters in the total and in the current minute
    hash.each_pair do |k, v|
      @stats[:total][k] += v
      @sections.keys.each do |section|
        add_to_section section, k, v
      end
    end
  end

  def add_to_section(section, k, v)
    @stats[section][:last][0][k] += v
  end

  def calculate
    calculate_section @sections.keys.first

    # each value in the @sections is the number of element of the previous section
    # needed to form the current section
    @sections.keys.each_with_index do |section, index|
      calculate_section(section) if sample_limit(index)
    end
  end

  def calculate_section(section)
    # calculate the average for this section
    @stats[section][:last].first.each_pair do |k, v|
      @stats[section][:average][k] = ((@stats[section][:average][k].to_f * @stats[section][:average][:samples] + v) / (@stats[section][:average][:samples] + 1)).round(2)
    end
    @stats[section][:average][:samples] += 1
    # initialize a new element for the current section
    @stats[section][:last].insert(0, @template.dup)
    # remove the last one
    @stats[section][:last].pop
  end

  def sample_limit(index)
    # tipping point of 0 means never tip
    return false if @sections[@sections.keys[index]] == 0

    # all the previous must be on the tipping point
    values = []
    index.downto(1) do |i|
      prev = @sections.keys[i - 1]
      values[i] = @stats[prev][:average][:samples] != 0 && @stats[prev][:average][:samples] % @sections[@sections.keys[i]] == 0
    end

    values.compact.inject(:&)
  end

end

end #RCS