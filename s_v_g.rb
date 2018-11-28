# = SVG Helper classes for generating svg content
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

module SVG
  SVG_VERSION = "1.1"
  SVG_NS = "http://www.w3.org/2000/svg"

  def options_as_str(options)
    s = ""
    options.each{|k,v| s << "#{k}=\"#{v}\" "}
    return (s)
  end

  # Leaf node
  class BaseEle
    attr_accessor :options
    def initialize(name, options)
      @name = name || raise("Name must be specified")
      self.options = options.nil? ?  {} : options.dup
    end
    def to_s
      s = "<#{@name} "
      self.options.each{|k,v| s << "#{k}=\"#{v}\" "}
      s << " />\n"
    end
  end

  class BaseContainer
    attr_accessor :name, :elements, :options
    def initialize(name, options = nil)
      @name = name || raise("Name must be specified")
      self.options = options.nil? ?  {} : options.dup
      self.elements = []
    end
    def add(ele)
      @elements << ele
    end
    def to_s
      s = "\n<#{@name} "
      @options.each{|k,v| s << "#{k}=\"#{v}\" "}
      s << ">\n"
      @elements.each{|ele| s << ele.to_s}
      s << "</#{@name}>\n"
    end
  end

  class Svg < BaseContainer
    def initialize(options = nil)
      super("svg", options)
      @options["version"] = SVG_VERSION unless @options["version"]
      @options["xmlns"] = SVG_NS unless @options["xmlns"]
    end
    #def to_s
      #s = "<?xml version=\"1.0\" standalone=\"no\"?>\n"
      #s << "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\"\n"
      #s << "  \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">"
      #s << super.to_s
    #end
  end

  class G < BaseContainer
    def initialize(options = nil)
      super("g", options)
    end
  end

  class Defs < BaseContainer
    def initialize(options = nil)
      super("defs", options)
    end
  end
  class Script
    def initialize(script)
      @script = script
    end
    def to_s
      s = "<script type=\"text/ecmascript\">\n"
      s << "<![CDATA[\n"
      s << @script
      s << "]]>\n</script>"
    end
  end
  class Style
    def initialize(style)
      @style = style
    end
    def to_s
      s = "<style type=\"text/css\">\n"
      s << @style
      s << "\n</style>\n"
    end
  end
  class LinearGradient < BaseContainer
    def initialize(id, options = nil)
      super("linearGradient", options)
      @options["id"] = id unless @options["id"]
    end
  end

  class Stop < BaseEle
    def initialize(options = nil)
      super("stop", options)
    end
  end

  class Rect < BaseEle
    def initialize(x, y, width, height, rx=nil, ry=nil, options = nil)
      super("rect", options)
      @options["x"] = x if x
      @options["y"] = y if y
      @options["width"] = width if width
      @options["height"] = height if height
      @options["rx"] = rx if rx
      @options["ry"] = ry if ry
      #pp @options
    end
  end

  class Circle < BaseEle
    def initialize(cx, cy, r, options = nil)
      super("circle", options)
      @options["cx"] = cx if cx
      @options["cy"] = cy if cy
      @options["r"] = r if r
    end
  end

  class Line < BaseEle
    def initialize(x1,y1,x2,y2, options = nil)
      super("line", options)
      @options["x1"] = x1 if x1
      @options["x2"] = x2 if x2
      @options["y1"] = y1 if y1
      @options["y2"] = y2 if y2
    end
  end

  class PolyLine < BaseEle
    def initialize(points, options = nil)
      super("polyline", options)
      @options["points"] = points if points     #FIXME
    end
  end

  class Text < BaseContainer
    def initialize(x,y, string=nil, opt = nil)
      super("text", opt)
      @options["x"] = x if x
      @options["y"] = y if y
      @options["fill"] = "black" unless @options["fill"]
      @options["font-family"] = "Verdana" unless @options["font-family"]
      @options["font-size"] = "10" unless @options["font-size"]
      add(string) if string
    end
  end
end

