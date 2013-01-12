require 'test/unit'
require 'wieldymarkup'

class CompilerTest < Test::Unit::TestCase
  
  def test_remove_grouped_text
    c = Compiler.new
    sample = "The cat ran 'into the big 'home!"
    expected = "The cat ran home!"
    assert_equal expected, c.class.remove_grouped_text(sample, "'")
    
    c = Compiler.new
    sample = "The cat ran 'into the big home!"
    expected = "The cat ran "
    assert_equal expected, c.class.remove_grouped_text(sample, "'")
    
    c = Compiler.new
    sample = "The cat ran `into the big `home!"
    expected = "The cat ran home!"
    assert_equal expected, c.class.remove_grouped_text(sample, "`")
  end
  
  def test_get_selector_from_line
    line = "div.class#id data-val=val data-val2=<%= val2 %> <Content <i>haya!</i> goes here>"
    assert_equal "div.class#id", Compiler.get_selector_from_line(line)
    
    line = "div"
    assert_equal "div", Compiler.get_selector_from_line(line)
    
    line = ".class#id.class2 val=val1"
    assert_equal ".class#id.class2", Compiler.get_selector_from_line(line)
  end
  
  def test_get_tag_nest_level
    text = "  <div>"
    assert_equal 0, Compiler.get_tag_nest_level(text)
    
    text = "  <div <la;sdfajsd;f> dfajsl;fadfl   >"
    assert_equal 0, Compiler.get_tag_nest_level(text)
    
    text = "  <div <la;sdfajsd;f dfajsl;fadfl   >"
    assert_equal 1, Compiler.get_tag_nest_level(text)
    
    text = "  <div la;sdfajsd;f> dfajsl;fadfl   >"
    assert_equal -1, Compiler.get_tag_nest_level(text)
    
    text = "  {{div {{la;sdfajsd;f}} dfajsl;fadfl   }}"
    assert_equal 0, Compiler.get_tag_nest_level(text, :open_string => '{{', :close_string => '}}')
  end
  
  def test_get_leading_whitespace_from_text
    line = "    `<div class='class' id='id'>Content goes here</div>"
    assert_equal "    ", Compiler.get_leading_whitespace_from_text(line)
    
    line = "\t\tdiv.class#id data-val=val data-val2=<%= val2 %> <Content <i>haya!</i> goes here>"
    assert_equal "\t\t", Compiler.get_leading_whitespace_from_text(line)
    
    line = "\n  div.class#id data-val=val data-val2=<%= val2 %> <Content <i>haya!</i> goes here>"
    assert_equal "", Compiler.get_leading_whitespace_from_text(line)
  end
  
  def test_init_values
    c = Compiler.new
    comparison_values = [
      ['output', ''],
      ['open_tags', []],
      ['indent_token', ''],
      ['current_level', 0],
      ['previous_level', nil],
      ['text', ''],
      ['line_number', 0],
      ['compress', false],
    ]
    
    for cv in comparison_values do
      assert_equal cv[1], c.instance_variable_get("@#{cv[0]}")
    end
  end
  
  def test_process_current_level
    c = Compiler.new
    c.text = "    div"
    c.process_current_level
    assert_equal 0, c.previous_level
    assert_equal 1, c.current_level
    assert_equal "    ", c.indent_token
    
    c = Compiler.new
    c.text = "    div"
    c.indent_token = "  "
    c.process_current_level
    assert_equal 0, c.previous_level
    assert_equal 2, c.current_level
    assert_equal "  ", c.indent_token
    
    c = Compiler.new
    c.text = "\t\tdiv"
    c.indent_token = "\t"
    c.process_current_level
    assert_equal 0, c.previous_level
    assert_equal 2, c.current_level
    assert_equal "\t", c.indent_token
  end
    
  def test_close_tag
    c = Compiler.new
    c.indent_token = "  "
    c.open_tags = [[0, "div"]]
    c.close_tag
    assert_equal "</div>\n", c.output
    assert_equal [], c.open_tags
    
    c = Compiler.new(:text => '', :compress => true)
    c.indent_token = "  "
    c.open_tags = [[0, "div"]]
    c.close_tag
    assert_equal "</div>", c.output
    assert_equal [], c.open_tags
  end
  
  def test_close_lower_level_tags
    c = Compiler.new
    c.current_level = 0
    c.previous_level = 2
    c.indent_token = "  "
    c.open_tags = [
      [0, "div"],
      [1, "div"],
      [2, "span"],
    ]
    c.close_lower_level_tags
    assert_equal "    </span>\n  </div>\n</div>\n", c.output
    
    c = Compiler.new(:text => '', :compress => true)
    c.current_level = 0
    c.previous_level = 2
    c.indent_token = "  "
    c.open_tags = [
      [0, "div"],
      [1, "div"],
      [2, "span"],
    ]
    c.close_lower_level_tags
    assert_equal "</span></div></div>", c.output
  end
  
  def test_process_embedded_line
    c = Compiler.new
    c.current_level = 2
    c.indent_token = "  "
    c.process_embedded_line "`<div>"
    assert_equal "    <div>\n", c.output
    
    c = Compiler.new
    c.current_level = 3
    c.indent_token = "\t"
    c.process_embedded_line "`<div>"
    assert_equal "\t\t\t<div>\n", c.output
    
    c = Compiler.new(:text => '', :compress => true)
    c.current_level = 3
    c.indent_token = "\t"
    c.process_embedded_line "`<div>"
    assert_equal "<div>", c.output
  end
  
  def test_process_selector
    c = Compiler.new
    c.process_selector "div"
    assert_equal "div", c.tag
    assert_equal nil, c.tag_id
    assert_equal [], c.tag_classes
    
    c = Compiler.new
    c.process_selector "span.class1#id.class2"
    assert_equal "span", c.tag
    assert_equal "id", c.tag_id
    assert_equal ["class1", "class2"], c.tag_classes
    
    c = Compiler.new
    c.process_selector "#id.class"
    assert_equal "div", c.tag
    assert_equal "id", c.tag_id
    assert_equal ["class"], c.tag_classes
  end
  
  def test_process_attributes
    c = Compiler.new
    rest_of_line = c.process_attributes ""
    assert_equal [], c.tag_attributes
    assert_equal "", rest_of_line
    
    c = Compiler.new
    rest_of_line = c.process_attributes "href=# target=_blank"
    assert_equal [' href="#"', ' target="_blank"'], c.tag_attributes
    assert_equal "", rest_of_line
    
    c = Compiler.new
    rest_of_line = c.process_attributes "href=# <asdf>"
    assert_equal [' href="#"'], c.tag_attributes
    assert_equal "<asdf>", rest_of_line
    
    c = Compiler.new
    rest_of_line = c.process_attributes "val1=val1 data-val2=<%= val2 %> <asdf>"
    assert_equal [' val1="val1"', ' data-val2="<%= val2 %>"'], c.tag_attributes
    assert_equal "<asdf>", rest_of_line
    
    c = Compiler.new
    rest_of_line = c.process_attributes "val1=val1 data-val2=<%= val2 %> <asdf <%= val3 %>>"
    assert_equal [' val1="val1"', ' data-val2="<%= val2 %>"'], c.tag_attributes
    assert_equal "<asdf <%= val3 %>>", rest_of_line
  end
  
  def test_process_next_line
    c = Compiler.new
    c.text = "div\ndiv"
    c.process_next_line
    assert_equal nil, c.inner_text
    
    c = Compiler.new
    c.text = "div <asdf>\ndiv"
    c.process_next_line
    assert_equal "asdf", c.inner_text
    
    c = Compiler.new
    c.text = "div <<%= val %> asdf>\ndiv"
    c.process_next_line
    assert_equal "<%= val %> asdf", c.inner_text
    
    c = Compiler.new
    c.text = "div href=# <asdf \n asdf ;lkj <%= val %>>\ndiv"
    c.process_next_line
    assert_equal "asdf asdf ;lkj <%= val %>", c.inner_text
    
    c = Compiler.new
    c.indent_token = "  "
    c.text = "div \\-\\ a href=# <asdf>"
    c.process_next_line
    assert_equal %Q(<div>\n  <a href="#">asdf</a>\n), c.output
  
    c = Compiler.new
    c.indent_token = "  "
    c.text = "div \\-\\ a href=# target=_blank \\-\\ span <asdf>"
    c.process_next_line
    assert_equal %Q(<div>\n  <a href="#" target="_blank">\n    <span>asdf</span>\n), c.output
  end
  
  def test_add_html_to_output
    c = Compiler.new
    c.line_starts_with_tick = true
    c.add_html_to_output
    assert_equal '', c.output
    
    c = Compiler.new
    c.line_starts_with_tick = false
    c.tag = 'input'
    c.tag_id = 'name-input'
    c.tag_classes = ['class1', 'class2']
    c.tag_attributes = [
      ' type="text"',
      ' value="Value"'
    ]
    c.self_closing = true
    c.add_html_to_output
    assert_equal %Q(<input id="name-input" class="class1 class2" type="text" value="Value" />\n), c.output
    
    c = Compiler.new
    c.line_starts_with_tick = false
    c.compress = true
    c.tag = 'span'
    c.tag_id = nil
    c.tag_classes = []
    c.tag_attributes = []
    c.self_closing = false
    c.inner_text = "<%= val1 %>"
    c.add_html_to_output
    assert_equal %Q(<span><%= val1 %></span>), c.output
  end
  
end