# NEXXT

Parser for NEXXT Studio (NES graphics editor) session files.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'nexxt-parser'
```

And then execute:

```bash
bundle install
```

## Usage

### Parse a session file

```ruby
require 'nexxt-parser'

session = NEXXT::Parser::Session.read('path/to/file.nss')

# Access CHR data
session.chr_main  # => Array of integers
session.chr_copy # => Array of integers

# Access metasprites
session.metasprites.each do |metasprite|
  puts metasprite.name
  metasprite.sprites.each do |sprite|
    puts "  x: #{sprite.x}, y: #{sprite.y}, tile: #{sprite.tile}"
  end
end
```

### Parse a map file

```ruby
map = NEXXT::Parser::MapFile.read('path/to/file.map')

map.width   # => Integer
map.height  # => Integer
map.tiles   # => 2D array of tile indices
map.metatiles # => Array of Metatile objects
```

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rspec` to run the tests.

Run `bundle exec rubocop` for linting.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wendelscardua/nexxt-parser.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).