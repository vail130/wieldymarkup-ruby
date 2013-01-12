# Raises semantic errors in parsing markup.
class CompilerException < Exception; end

# Compiles WieldyMarkup HTML abstraction language into HTML, with each tag
#   indented on its own line or without any whitespace between tags.
# 
# @author Vail Gold
class Compiler
  
  # Only available for unit tests.
  attr_accessor :line_starts_with_tick,
    :current_level, :tag, :indent_token, :inner_text, :open_tags,
    :previous_level, :tag_id, :tag_classes, :tag_attributes, :self_closing
  attr_reader :line_number
  
  # @!attribute [rw] text
  #   @return [String] The text to parse and compile
  attr_accessor :text
  
  # @!attribute [rw] compress
  #   @return [Boolean] Whether or not the compiler should leave whitespace
  #     between output HTML tags
  attr_accessor :compress
  
  # @!attribute [rw] embedding_token
  #   @return [String] The character used to identify embedded HTML lines
  attr_accessor :embedding_token
  
  # @!attribute [r] output
  #   @return [String] The compiled HTML
  attr_reader :output
  
  class << self
    # Removes all substrings surrounded by a grouping substring, including
    #   grouping substring on both sides.
    #
    # @param [String] text The string from which to remove grouped substrings
    # @param [String] z The grouping substring
    # @return [String] The string with substrings removed
    def remove_grouped_text(text, z)
      output = ""
      text_copy = text * 1
      status = true
      while text_copy != '' do
        grouper_index = text_copy.index z
        if grouper_index == nil
          if status
            output << (text_copy * 1)
          end
          text_copy = ''
        
        else
          if status
            output << text_copy[0..grouper_index-1]
          end
          
          if text_copy[grouper_index+1]
            text_copy = text_copy[grouper_index+1..-1]
          else
            text_copy = ''
          end
        end
        
        status = !status
      end
      
      output
    end
    
    # Gets the selector from the line of markup
    #
    # @param [String] line The string from which to get the selector
    # @return [String] The substring from the beginning of the line until the
    #   first whitespace character
    def get_selector_from_line(line)
      first_whitespace_index = nil
      line_copy = line.strip * 1
      i = 0
      while line_copy[i] != nil do
        if " \t"[line_copy[i]] != nil
          first_whitespace_index = i
          break
        end
        i += 1
      end
      
      if first_whitespace_index == nil
        return line
      else
        return line[0..first_whitespace_index-1]
      end
    end
    
    # Determines the level of nesting in a string
    #
    # @param [String] text The string in which to determine the nest level
    # @param [Hash] delimiters The delimiters for determining nest level
    # @option delimiters [String] :open_string
    #   The substring that denotes an increase in nesting level.
    # @option delimiters [String] :close_string
    #   The substring that denotes a decrase in nesting level.
    # @return [String] The substring from the beginning of the line until the
    #   first whitespace character
    def get_tag_nest_level(text, delimiters={:open_string => '<', :close_string => '>'})
      d = delimiters[0]
      open_string = (d != nil and d[:open_string] != nil) ? d[:open_string] : '<'
      close_string = (d != nil and d[:close_string] != nil) ? d[:close_string] : '>'
      
      text = text * 1
      nest_level = 0
      while true do
        open_string_index = text.index(open_string)
        close_string_index = text.index(close_string)
        open_string_first = false
        close_string_first = false
        
        # Only same if both nil
        if open_string_index == close_string_index
          break
        elsif open_string_index != nil
          open_string_first = true
        elsif close_string_index != nil
          close_string_first = true
        else
          if open_string_index < close_string_index
            open_string_first = true
          else
            close_string_first = true
          end
        end
        
        if open_string_first
          nest_level += 1
          if text.length == open_string_index + open_string.length
            break
          else
            text = text[open_string_index + open_string.length..-1]
          end
        elsif close_string_first
          nest_level -= 1
          if text.length == close_string_index + close_string.length
            break
          else
            text = text[close_string_index + close_string.length..-1]
          end
        end
      end
      
      nest_level
    end
    
    # Gets the string of leading spaces and tabs in some text.
    #
    # @param [String] text The string from which to get the leading whitespace
    # @return [String] The leading whitespace in the string
    def get_leading_whitespace_from_text(text)
      leading_whitespace = ""
      text_copy = text * 1
      i = 0
      while text_copy[i] != nil do
        if " \t"[text_copy[i]] == nil
          if i > 0
            leading_whitespace = text[0..i-1]
          end
          break
        end
        
        i += 1
      end
      
      leading_whitespace
    end
  
  end
  
  # Instantiate a new Compiler instance. Automatically compiles text if passed
  #   in via parameters.
  #
  # @param [Hash] options The options for compiling the input text
  # @option options [String] :text
  #   The input text to compile
  # @option options [String] :compress
  #   Whether to leave whitespace between HTML tags or not
  def initialize(options={:text => "", :compress => false})
    @text = (options != nil and options[:text] != nil) ? options[:text] : ''
    @compress = (options != nil and [true, false].index(options[:compress]) != nil) ? !!options[:compress] : false
    
    @output = ""
    @open_tags = []
    @indent_token = ""
    @current_level = 0
    @previous_level = nil
    @line_number = 0
    @embedding_token = '`'
    
    if @text != ""
      self.compile
    end
  end
  
  # Compiles input markup into HTML.
  #
  # @param [Hash] options The options for compiling the input text
  # @option options [String] :text
  #   The input text to compile
  # @option options [String] :compress
  #   Whether to leave whitespace between HTML tags or not
  # @return [String] The compiled HTML
  def compile(options={:text => nil, :compress => nil})
    @text = options[:text] if options[:text] != nil
    @compress = !!options[:compress] if options[:compress] != nil
    
    while @text != "" do
      self.process_current_level
      self.close_lower_level_tags
      self.process_next_line
    end
      
    self.close_tag while @open_tags.length > 0
    
    @output
  end
  
  # Determines current nesting level for HTML output.
  #
  # @return [Object] The reference to this instance object.
  def process_current_level
    @previous_level = @current_level * 1
    leading_whitespace = self.class.get_leading_whitespace_from_text @text
    if leading_whitespace == ""
      @current_level = 0
    
    # If there is leading whitespace but indent_token is still empty string
    elsif @indent_token == ""
      @indent_token = leading_whitespace
      @current_level = 1
    
    # Else, set current_level to number of repetitions of index_token in leading_whitespace
    else
      i = 0
      while leading_whitespace.index(@indent_token) == 0 do
        leading_whitespace = leading_whitespace[@indent_token.length..-1]
        i += 1
      end
      @current_level = i
    end
    
    self
  end
  
  # Iterates through nesting levels that have been closed.
  #
  # @return [Object] The reference to this instance object.
  def close_lower_level_tags
    # If indentation level is less than or equal to previous level
    if @current_level <= @previous_level
      # Close all indentations greater than or equal to indentation level of this line
      while @open_tags.length > 0 and @open_tags[@open_tags.length - 1][0] >= @current_level do
        self.close_tag
      end
    end
    self
  end
  
  # Adds closing HTML tags to output and removes entry from @open_tags.
  #
  # @return [Object] The reference to this instance object.
  def close_tag
    closing_tag_array = @open_tags.pop
    if !@compress
      @output << (@indent_token * closing_tag_array[0])
    end
    @output << "</" << closing_tag_array[1] << ">"
    if !@compress
      @output << "\n"
    end
    self
  end
  
  # Gets the next line of text, splits it into relevant pieces, and sends them
  #   to respective methods for parsing.
  # 
  # @return [Object] The reference to this instance object.
  def process_next_line
    @line_starts_with_tick = false
    @self_closing = false
    @inner_text = nil
    
    line = ""
    
    if @text["\n"] != nil
      line_break_index = @text.index "\n"
      line = @text[0..line_break_index].strip
      @text = @text[line_break_index+1..-1]
    else
      line = @text.strip()
      @text = ""
    end
    
    @line_number += 1
    if line.length == 0
      return self
    end
    
    # Whole line embedded HTML, starting with back ticks:
    if line[0] == @embedding_token
      self.process_embedded_line line
    
    else
      # Support multiple tags on one line via "\-\" delimiter
      while true do
        line_split_list = line.split '\\-\\'
        lines = [line_split_list[0]]
        
        if line_split_list.length == 1
          line = line_split_list[0].strip
          break
        else
          lines << line_split_list[1..-1].join('\\-\\')
        end
        
        lines[0] = lines[0].strip
        selector = self.class.get_selector_from_line lines[0]
        self.process_selector((selector*1))
        rest_of_line = lines[0][selector.length..-1].strip
        rest_of_line = self.process_attributes rest_of_line
        self.add_html_to_output
        
        @tag = nil
        @tag_id = nil
        @tag_classes = []
        @tag_attributes = []
        @previous_level = @current_level * 1
        @current_level += 1
        line = lines[1..-1].join '\\-\\'
      end
      
      selector = self.class.get_selector_from_line line
      self.process_selector((selector*1))
      rest_of_line = line[selector.length..-1].strip
      rest_of_line = self.process_attributes rest_of_line
      
      if rest_of_line.index('<') == 0
        @inner_text = rest_of_line
        if self.class.get_tag_nest_level(@inner_text) < 0
          raise CompilerException, "Too many '>' found on line #{@line_number}"
        end
        
        while self.class.get_tag_nest_level(@inner_text) > 0 do
          if @text == ""
            raise CompilerException, "Unmatched '<' found on line #{@line_number}"
          
          elsif @text["\n"] != nil
            line_break_index = @text.index "\n"
            # Guarantee only one space between text between lines.
            @inner_text << ' ' + @text[0..line_break_index].strip
            if @text.length == line_break_index + 1
              @text = ""
            else
              @text = @text[line_break_index+1..-1]
            end
          
          else
            @inner_text << @text
            @text = ""
          end
        end
        
        @inner_text = @inner_text.strip()[1..-2]
      
      elsif rest_of_line.index('/') == 0
        if rest_of_line.length > 0 and rest_of_line[-1] == '/'
          @self_closing = true
        end
      end
      
      self.add_html_to_output
    end
    
    self
  end
  
  # Adds an embedded line to output, removing @embedding_token
  #   and not compiling.
  #
  # @param [String] line
  #   The line of text with @embedding_token
  # @return [Object] The reference to this instance object.
  def process_embedded_line(line)
    @line_starts_with_tick = true
    if !@compress
      @output << (@indent_token * @current_level)
    end
    @output << line[1..-1]
    if !@compress
      @output << "\n"
    end
    self
  end
  
  # Parses a selector into tag, ID, and classes.
  #
  # @param [String] selector
  #   The unparsed selector string
  # @return [Object] The reference to this instance object.
  def process_selector(selector)
    # Parse the first piece as a selector, defaulting to DIV tag if none is specified
    if selector.length > 0 and   ['#', '.'].count(selector[0]) > 0
      @tag = 'div'
    else
      delimiter_index = nil
      i = 0
      for char in selector.split("") do
        if ['#', '.'].count(char) > 0
          delimiter_index = i
          break
        end
        i += 1
      end
      
      if delimiter_index == nil
        @tag = selector * 1
        selector = ""
      else
        @tag = selector[0..delimiter_index-1]
        selector = selector[@tag.length..-1]
      end
    end
    
    @tag_id = nil
    @tag_classes = []
    while true do
      next_delimiter_index = nil
      if selector == ""
        break
      
      else
        i = 0
        for char in selector.split("") do
          if i > 0 and ['#', '.'].count(char) > 0
            next_delimiter_index = i
            break
          end
          i += 1
        end
        
        if next_delimiter_index == nil
          if selector[0] == '#'
            @tag_id = selector[1..-1]
          elsif selector[0] == "."
            @tag_classes << selector[1..-1]
          end
          
          selector = ""
        
        else
          if selector[0] == '#'
            @tag_id = selector[1..next_delimiter_index-1]
          elsif selector[0] == "."
            @tag_classes << selector[1..next_delimiter_index-1]
          end
          
          selector = selector[next_delimiter_index..-1]
        end
      end
    end
    
    self
  end
    
  # Parses attribute string off of the beginning of a line of text after
  #   the selector was removed, and returns everything after the attribute
  #   string.
  #
  # @param [String] rest_of_line
  #   The line of text after leading whitespace and selector have been removed
  # @return [String] The input text after all attributes have been removed
  def process_attributes(rest_of_line)
    @tag_attributes = []
    while rest_of_line != "" do
      # If '=' doesn't exist, empty attribute string and break from loop
      if rest_of_line.index('=') == nil
        break
      elsif rest_of_line.index('=') != nil and rest_of_line.index('<') != nil and rest_of_line.index('<') < rest_of_line.index('=')
        break
      end
      
      first_equals_index = rest_of_line.index '='
      embedded_attribute = false
      
      if rest_of_line[first_equals_index+1..first_equals_index+2] == '{{'
        embedded_attribute = true
        close_index = rest_of_line.index '}}'
        if close_index == nil
          raise CompilerException, "Unmatched '{{' found in line #{@line_number}"
        end
      elsif rest_of_line[first_equals_index+1..first_equals_index+2] == '<%'
        embedded_attribute = true
        close_index = rest_of_line.index '%>'
        if close_index == nil
          raise CompilerException, "Unmatched '<%' found in line #{@line_number}"
        end
      end
      
      if embedded_attribute
        current_attribute = rest_of_line[0..close_index+1]
        if rest_of_line.length == close_index + 2
          rest_of_line = ""
        else
          rest_of_line = rest_of_line[close_index+2..-1]
        end
      
      elsif rest_of_line.length == first_equals_index
        current_attribute = rest_of_line.strip
        rest_of_line = ""
      
      elsif rest_of_line[first_equals_index + 1..-1].index('=') == nil
        open_inner_text_index = rest_of_line.index('<')
        if open_inner_text_index != nil
          current_attribute = rest_of_line[0..open_inner_text_index-1].strip
          rest_of_line = rest_of_line[open_inner_text_index..-1]
        else
          current_attribute = rest_of_line * 1
          rest_of_line = ""
        end
      
      else
        second_equals_index = rest_of_line[first_equals_index + 1..-1].index '='
        reversed_letters_between_equals = rest_of_line[first_equals_index+1..first_equals_index + 1 + second_equals_index - 1].split("").reverse
        
        whitespace_index = nil
        i = 0
        for char in reversed_letters_between_equals do
          if " \t".index(char) != nil
            whitespace_index = first_equals_index + 1 + second_equals_index - i
            break
          end
          i += 1
        end
        
        if whitespace_index == nil
          # TODO: Do some error reporting here
          break
        end
        
        current_attribute = rest_of_line[0..whitespace_index-1].strip
        rest_of_line = rest_of_line[whitespace_index..-1]
      end
      
      if current_attribute != nil
        equals_index = current_attribute.index '='
        @tag_attributes << ' ' + current_attribute[0..equals_index-1] + '="' + current_attribute[equals_index+1..-1] + '"'
      end
    end
    
    rest_of_line.strip
  end

  # Adds HTML to output for a given line.
  #
  # @return [Object] The reference to this instance object.
  def add_html_to_output
    if !@line_starts_with_tick
      tag_html = "<" << @tag
      
      if @tag_id != nil
        tag_html << ' id="' << @tag_id << '"'
      end
      
      if @tag_classes.length > 0
        tag_html << ' class="' << @tag_classes.join(' ') << '"'
      end
      
      if @tag_attributes.length > 0
        tag_html << @tag_attributes.join('')
      end
      
      if @self_closing
        tag_html << " />"
        if !@compress
          @output << (@indent_token * @current_level)
        end
        @output << tag_html
        if !@compress
          @output << "\n"
        end
      
      else
        tag_html << ">"
        
        if @inner_text != nil
          tag_html << @inner_text
        end
        
        if !@compress
          @output << (@indent_token * @current_level)
        end
        
        @output << tag_html
        
        if @inner_text == nil
          if !@compress
            @output << "\n"
          end
          # Add tag data to open_tags list
          @open_tags << [@current_level, @tag]
        
        else
          @output <<"</" << @tag << ">"
          if !@compress
            @output << "\n"
          end
        end
      end
    end
    
    self
  end

end
