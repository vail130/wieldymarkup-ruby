Gem::Specification.new do |s|
  s.name        = 'wieldymarkup'
  s.version     = '0.2.0'
  s.date        = '2013-01-11'
  s.summary     = "WieldyMarkup HTML Abstraction Markup Language Compiler"
  s.author      = "Vail Gold"
  s.email       = 'vail@vailgold.com'
  s.files       = ["lib/wieldymarkup.rb"]
  s.homepage    = 'http://www.github.com/vail130/wieldymarkup-ruby'
  s.description = <<-EOF
    The WieldyMarkup compiler allows you to write more concise HTML templates
    for your modern web applications. It works with other templating engines
    as well, like Underscore, Mustache, et cetera.
    See http://www.github.com/vail130/wieldymarkup-ruby for more information.
  EOF
  
  s.executables << 'wieldymarkup'
  
end