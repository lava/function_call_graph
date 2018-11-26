# 
# function_call_graph.rb
# 
# Created on Oct 4, 2007, 4:52:14 PM
# 
# Classes should be self-explainatory
# 
# == License
# CDDL HEADER START
# 
#  The contents of this file are subject to the terms of the
#  Common Development and Distribution License (the "License").
#  You may not use this file except in compliance with the License.
# 
#  You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
#  or http://www.opensolaris.org/os/licensing.
#  See the License for the specific language governing permissions
#  and limitations under the License.
# 
#  When distributing Covered Code, include this CDDL HEADER in each
#  file and include the License file at usr/src/OPENSOLARIS.LICENSE.
#  If applicable, add the following below this CDDL HEADER, with the
#  fields enclosed by brackets "[]" replaced with your own identifying
#  information: Portions Copyright [yyyy] [name of copyright owner]
# 
# CDDL HEADER END
#
# Comments/Feedback/Bugs to neelatsundotcom or 
# Check http://blogs.sun.com/realneel for updates

require 'pp'
require 's_v_g'

# This is a basic node. Nothing special here, moveon
class Node 
  attr_reader :children, :name, :level, :etime, :stime
  attr_writer :etime
  def initialize(name, level = 0, startime = 0)
    @name = name.chomp
    @level = level
    @children = []    
    @stime = startime
    @etime = 0
  end
end

# This class process the allfrom.d output
# This currently only works reliably for async function calls
class FunctionCallGraph  
  include Enumerable
  attr_reader :etime
  def initialize(file)
    @file = file
    @root_func = Node.new("root")       
    @etime = 0
    @max_levels = 0
    @name = "Unknown"
    grok
  end
  
  def grok    
    functions = []
    curr_func = @root_func    
    IO.readlines(@file).each do |line|       
      next if line =~ /CPU |^$/            
      f = line.chomp.split 
      # Better to die with an exception than produce wrong results
      #break if curr_func.nil? 
      if f[1] == "->" or f[1] == "=>" then
        newfunc = Node.new(f[2], functions.length + 1, f[3].to_i)               
        curr_func.children << newfunc
        functions.push(curr_func)
        curr_func = newfunc        
        next
      end
      if f[1] == "<-"  or f[1] == "<=" then        
        next if curr_func.nil?
        curr_func.etime = f[3].to_i        
        curr_func = functions.pop
        next
      end
    end
    @etime = self.max{|a,b| a.etime <=> b.etime}.etime    
    each {|c| c.etime = @etime if c.etime == 0}        
  end
  
  # The root node
  def root
    @root_func.children[0]
  end
  
  # Traverse the tree breadth first
  def each
    todo = [@root_func]  
    while (node = todo.shift) do      
      node.children.each do |child| 
        yield(child)        
        todo.push(child)
      end      
    end      
  end        
end

class FunctionCallGraphSVG
  FUNCTION_HEIGHT = 15    # Height of each block
  TEXT_PADDING_LEFT = 3   # Left Text padding inside each block
  TEXT_PADDING_RIGHT = 3  # Right Text padding inside each block
  TEXT_PADDING_TOP = 1    # Top text padding inside each block
  TEXT_PADDING_BOTTOM = 1 # Bottom text padding inside each block
  
  FONT_SIZE = FUNCTION_HEIGHT - TEXT_PADDING_TOP - TEXT_PADDING_BOTTOM
  BLOCK_PADDING_TOP = 2  # Interblock padding
  BG_START_COLOR = "#C5D5A9"    # Background start color
  BG_END_COLOR = "#eeeeee"      # Background end color
  PADDING_TOP = 40              # Padding on the top
  PADDING_BOTTOM = 60           # Padding at the bottom
  PADDING_LEFT = 10
  PADDING_RIGHT = 20
  RATIO = 0.6              # Magic ratio to figure out if funcname fits in block
  MIN_CHARS_TO_DISPLAY = 5 # Minimum numbers of a func to display
  DOTS = ".."              # Suffix for displaying partial names
  AXIS_FONT_SIZE = 10      # Font size for the axis labels
  AXIS_FONT_PADDING = 2
  FUNCTION_NAME_FONT = "monaco"
  DECORATION_FONT = "Verdana"
  
  def initialize(file, width, height = 0)
    @fg = FunctionCallGraph.new(file)     
    @width = width
    # if height is not specified, we auto size it
    if height == 0 then
      max_levels = @fg.inject(0) { |max, n| max > n.level ? max : n.level}
      @height = FUNCTION_HEIGHT * (max_levels + 1) + PADDING_TOP + PADDING_BOTTOM
    else
      @height = height
    end
    # Colors are chosen randomly except for few
    @colors = Hash.new{|h, k| h[k] ="rgb(#{rand(255)},#{rand(255)},#{rand(255)})" }
    default_colors()
    @svg = SVG::Svg.new("width" => width, 
      "height"  => @height,
      "viewBox" => "0 0 #{@width} #{@height}",
      "onload"  => "init(evt)"
    )
    @defs = SVG::Defs.new
    @svg.add(@defs)
    @bg = SVG::LinearGradient.new("background")    
    @bg.add(SVG::Stop.new("offset" => "5%", "stop-color"=>BG_START_COLOR))
    @bg.add(SVG::Stop.new("offset" => "95%", "stop-color"=>BG_END_COLOR))
    @defs.add(@bg)
    @svg.add(SVG::Rect.new(0, 0, @width, @height, 0,0, "fill" => "url(#background)"))
    @svg.add(SVG::Style.new(style))
    @svg.add(SVG::Script.new(js))
    srand
  end
  
  def fy(y)
    @height - PADDING_BOTTOM - y
  end
  
  def pretty(num) 
    suffix= ['ns', 'us', 'ms', 's']
    i = 0;
    fnum = 1.0*num
    while (fnum > 1000 && i < suffix.length-1)
      fnum /= 1000.0
      i += 1
    end
    return sprintf("%.2f%s", fnum, suffix[i])
  end

  def js
    "var funcele;
function init(evt) {funcele = document.getElementById(\"funcname\").firstChild;}
function showfunc(func) {funcele.nodeValue = func;}
function clearfunc() {funcele.nodeValue = ' ';}
    "
  end
  
  def style
    "rect[isfunc]:hover {stroke:black; stroke-width:1; fill-opacity:0.5;}"
  end
  
  # Use some default colors for functions taking the most time
  def default_colors
    a = @fg.to_a.sort{|x, y| (y.etime - y.stime) <=> (x.etime - x.stime)}
    
    c = %w(#5382A1 #E76F00 #B2BC00 #C06600 #FFFF88 #CDEB8B #FF1A00 #4096EE #B02B2C)
    c.each_with_index {|c, i| @colors[a[i].name] = c;}
  end
  
  def draw    
    xscale = 1.0 * (@width - PADDING_LEFT - PADDING_RIGHT)/@fg.etime        
    g = SVG::G.new("transform" => "translate(0, 0)")    
    @svg.add(g)
    
    @fg.each do |node|
      x1 = node.stime*xscale + PADDING_LEFT
      y1 = (FUNCTION_HEIGHT + BLOCK_PADDING_TOP) * node.level       
      w = (node.etime - node.stime ) * xscale        
      next if w < 0.5     # No need to display if width is less than 1/2 pixels
      
      # For every function, we display 1 or 3 elements
      # The third element is displayed if the block is large enough to hold
      # the full function name, or a majority of the name
      # Element 1 is a Rect and is the background block
      # Element 2 is the text element
      # Element 3 is a transparent rect over the previous two to handle mouse hovers
      
      str_sz = RATIO * node.name.length * FONT_SIZE + TEXT_PADDING_LEFT + TEXT_PADDING_RIGHT     
      text_to_display = nil
      
      if (w > str_sz) then  
        text_to_display = node.name        
      elsif (node.name.length > MIN_CHARS_TO_DISPLAY) then
        disp_sz = w - TEXT_PADDING_LEFT - TEXT_PADDING_RIGHT
        str_sz = disp_sz/(RATIO * FONT_SIZE) - DOTS.length
        if (str_sz.to_i >= MIN_CHARS_TO_DISPLAY) then
          text_to_display = node.name[0..str_sz.to_i] + DOTS
        end        
      end
      tooltip = node.name + "  (#{pretty(node.etime - node.stime)})"      
      
      options = {"fill" => @colors[node.name]}
      extended_options = {"isfunc"       => "1",
        "onmouseover"  => "showfunc('#{tooltip}')",
        "onmouseout"   => "clearfunc()"}
            
      element1 = SVG::Rect.new(x1, fy(y1), w, FUNCTION_HEIGHT, 2,2, options)      
      if text_to_display.nil? then
        # We are not displaying text, can with only 1 elements
        element1.options.merge!(extended_options)        
      else
        # Need 3 elements
        text_options = {"font-size" => FONT_SIZE, "font-family" => FUNCTION_NAME_FONT}
        text_element = SVG::Text.new(x1 + TEXT_PADDING_LEFT, fy(y1) + FONT_SIZE - 2,       
          text_to_display, text_options)
        element3 = SVG::Rect.new(x1, fy(y1), w, FUNCTION_HEIGHT, 2,2,options)
        element3.options.merge!(extended_options)
        element3.options["fill-opacity"] = 0        
      end
      g.add(element1)
      g.add(text_element) unless text_to_display.nil?
      g.add(element3)     unless text_to_display.nil?
    end
    draw_decorations    
  end
  
  def draw_decorations
    bo = {"font-size" => 18, "font-family" => "Verdana"}
    t = SVG::Text.new(@width/2, PADDING_TOP/2, 
      "Call Graph for #{@fg.root.name}", 
      bo.merge({"text-anchor" => "middle"})) 
    @svg.add(t)
    tooltip = @fg.root.name + "  (#{pretty(@fg.root.etime - @fg.root.stime)})"      

    @svg.add(SVG::Text.new(5, @height - 25 , "Function:", bo))           
    @svg.add(SVG::Text.new(85, @height - 25 ,  tooltip, bo.merge({"id" => "funcname"})))
    
    #draw axis  
    y = @height - PADDING_BOTTOM + 3
    o = {"fill" => "black", "stroke" => "black", "stroke-width"=> "1"} 
    to = {"font-size" => AXIS_FONT_SIZE, "font-family" => "Verdana", "text-anchor" => "middle"}
    @svg.add(SVG::Line.new(PADDING_LEFT, y, @width - PADDING_RIGHT, y, o))
    @svg.add(SVG::Line.new(PADDING_LEFT, y - 4, PADDING_LEFT, y + 4, o))
    @svg.add(SVG::Line.new(@width - PADDING_RIGHT, y - 4, @width - PADDING_RIGHT, y + 4, o))
    
    y = @height - PADDING_BOTTOM + 3 + AXIS_FONT_SIZE + AXIS_FONT_PADDING    
    @svg.add(SVG::Text.new(PADDING_LEFT, y, "0", to))    
    str = "#{pretty(@fg.root.etime - @fg.root.stime)}"
    @svg.add(SVG::Text.new(@width - PADDING_RIGHT, y, str, to))
  end
  
  def to_s
    @svg.to_s
  end
end

def usage
  puts("Usage: scrip.rb inputfile")
  exit(1)
end
def main
  usage if ARGV.length != 1  
  f = FunctionCallGraphSVG.new(ARGV[0], 600)
  f.draw
  puts f.to_s
end

main
