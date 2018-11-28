#!/usr/bin/ruby

class Dtracer
  attr_reader :process_map

  class ProcessCallTree
    attr_reader   :name

    def initialize(name)
      @name = name
      @root = Node.new("root_node", 0)
      @last_height = 0  # height excluding root node
    end


    def append_block(sample)
      node = @root
      bound = [@last_height, sample.stackframes.size].min
      i = 0
      frames = sample.stackframes.reverse

      while i < bound
        if node.children.last.name != frames[i]
          break
        end
        node = node.children.last
        node.end_time = sample.timestamp + 1 # Should be node.end_time, but we didn't create the new node(s) yet.
        i += 1
      end

      while i < sample.stackframes.size
        node.children << Node.new(frames[i], sample.timestamp)
        node = node.children.last
        i += 1
      end

      @last_height = sample.stackframes.size
    end

    def to_s
      @root.to_s
    end
  end

  class Node
    attr_reader   :name
    attr_accessor :start_time, :end_time
    attr_accessor :children

    def initialize(name, start_time)
      @name = name
      @start_time = start_time
      @end_time = start_time + 1
      @children = []
    end

    def to_s()
      s = "CPU FUNCTION\n"
      # Strip out "root_node".
      @children.each do |child|
        s += child.stringify_(0)
      end
      return s
    end

    def stringify_(height)
      indent = "  0 " + " " * (2*height)
      s = indent + "-> #{@name} #{@start_time}\n"
      @children.each do |child|
        s += child.stringify_(height+1)
      end
      s += indent + "<- #{@name} #{@end_time}\n"
      return s
    end
  end


  # A sample looks like this in the processed perf output:
  #
  # master@127.0.1.1:5050 14784 182029.119460:       5000 cycles:uh:
  #         7fa4938a5480 _ZNK7process5OwnedINS_8SequenceEE3getEv@plt+0x0 (/home/bevers/src/mesos/worktrees/state-benchmarking/build-alexr/src/.libs/libmesos-1.8.0.so)
  #         7fa494ccd332 _ZN7process14ProcessManager6resumeEPNS_11ProcessBaseE+0x492 (/home/bevers/src/mesos/worktrees/state-benchmarking/build-alexr/src/.libs/libmesos-1.8.0.so)
  #         7fa494cd3606 _ZNSt6thread11_State_implINS_8_InvokerISt5tupleIJZN7process14ProcessManager12init_threadsEvEUlvE_EEEEE6_M_runEv+0x46 (/home/bevers/src/mesos/worktrees/state-benchmarking/build-alexr/src/.libs/libmesos-1.8.0.so)
  #         7fa491e43733 [unknown] (/usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.25)
  #
  # We're only interested in the comm[andline] (first line, first field),
  # timestamp (first line, third field) and function names in the stack
  # trace (second fields in all subsequent lines)
  class Sample
    attr_reader :comm, :timestamp
    attr_accessor :stackframes

    def initialize(comm, timestamp)
      @comm = comm
      @timestamp = timestamp
      @stackframes = []
    end
  end

  class PerfParser
    def self.each_sample(filename)
      File.open(filename, "r") do |file|
        sample = nil
        file.each_line do |line|
          next if line[0] == "#"
          tokens = line.split
          if sample.nil?
            next if tokens.empty?
            processname, _tid, timestamp, _counter_value, _countername = tokens
            timestamp = timestamp.chop.sub(".", "") # 'chop' to remove the trailing ':' and remove decimal point.
            sample = Sample.new(processname, timestamp.to_i)
          else
            if tokens.empty? # block end
              yield sample
              sample = nil
              next
            end
            _addr, symbol, _dso = tokens
            symbol = symbol.sub(/\+0x[0-9a-f]+/, "")
            sample.stackframes.push(symbol)
          end
        end
      end
    end
  end

  def initialize(filename)
    @process_map = Hash.new {|hash, key| hash[key] = ProcessCallTree.new(key) }
    PerfParser.each_sample(filename) do |block|
      @process_map[block.comm].append_block(block)
    end

    @process_map.each do |key, value|
      File.open(key, "w") do |file|
        file << value
      end
    end
  end

end

def usage
  puts("Usage: ./script.rb inputfiles...")
  exit(1)
end

def main
  usage if ARGV.length < 1
  dtracer = Dtracer.new(ARGV[0])
end

main
