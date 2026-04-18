# frozen_string_literal: true

require_relative 'lib/nexxt/parser/version'

Gem::Specification.new do |spec|
  spec.name = 'nexxt-parser'
  spec.version = NEXXT::Parser::VERSION
  spec.authors = ['Wendel Scardua']
  spec.email = ['wendelscardua@gmail.com']

  spec.summary = 'Parser for NEXXT session files'
  spec.description = 'A Ruby gem to parse NEXXT Studio (NES graphics editor) session files'
  spec.license = 'MIT'
  spec.homepage = 'https://github.com/wendelscardua/nexxt-parser'

  spec.files = Dir.glob('lib/**/*.rb')
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.4'

  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.0'
  spec.add_development_dependency 'rubocop-rspec', '~> 3.0'
end
