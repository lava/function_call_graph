require 'pry-nav'

class Dtracer

  attr_reader :process_map

  class TraceProcess
    attr_reader   :name
    attr_accessor :root_entry

    def initialize(name)
      @name = name
      @root_entry = Entry.new("root_entry")
    end

    def append_block(symbols)
      current_entry = @root_entry
      known_symbols = true
      symbols.reverse.each do |symbol|
        if known_symbols && current_entry.has_children? && current_entry.last_entry.name == symbol
          current_entry = current_entry.last_entry
          known_symbols = false
          next
        end
        new_entry = Entry.new(symbol)
        current_entry.last_entry.sub_entries << new_entry
        current_entry = new_entry
      end
    end

  end

  class Entry
    attr_reader   :name
    attr_accessor :timestamp
    attr_accessor :sub_entries

    def initialize(name)
      @name = name
      @sub_entries = []
    end

    def last_entry
      @sub_entries.last
    end

    def has_children?
      !@sub_entries.empty?
    end
  end

  def initialize(filename)
    @process_map = {}
    File.open(filename, "r") do |file|
      in_block = false
      block = []
      t_process = nil
      file.each_line do |line|
        next if line[0] == "#"
        tokens = line.split
        if not in_block
          next if tokens.empty?
          processname, _tid, timestamp, _counter_value, _countername = tokens
          t_process = @process_map.fetch(processname, TraceProcess.new(processname))
          @process_map[processname] = t_process
          in_block = true
        else
          if tokens.empty? # block end
            t_process.append_block(block)
            block = []
            in_block = false
            next
          end
          _addr, symbol, _dso = tokens
          block.push(symbol)
        end
      end
    end
  end

end

dtracer = Dtracer.new("./libprocess.stacks")
require 'pry'; binding.pry
