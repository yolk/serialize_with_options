$LOAD_PATH.unshift 'lib'

Gem::Specification.new do |s|
  s.name = "serialize_with_options"
  s.version = '0.0.5.yolk'
  s.date = Time.now.strftime('%Y-%m-%d')
  s.summary = "Enhanced serialize options for rails, forked from serialize_with_options"
  s.homepage = "http://github.com/yolk/serialize_with_options"
  s.email = "sebastian@yo.lk"
  s.authors = [ "Sebastian Munz" ]
  s.has_rdoc = false

  s.files = %w( init.rb README.markdown Rakefile MIT-LICENSE )
  s.files += Dir.glob("lib/**/*.rb")
  s.files += Dir.glob("test/**/*.rb")
  s.files += Dir.glob("rails/**/*.rb")

  s.description = "A fork of serializer_with_options enabling optional methods and other features"
end