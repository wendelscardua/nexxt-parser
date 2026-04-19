# frozen_string_literal: true

require 'strscan'

require_relative 'metasprite'
require_relative 'map'

module NEXXT
  module Parser
    class Session
      attr_reader :text, :flat_table, :table, :chr_main, :chr_copy, :metasprites_offset,
                  :metasprites

      def initialize(text)
        @text = text
        lines = text.lines(chomp: true).compact
        @flat_table = lines.grep(/=/).to_h { |line| line.split('=', 2) }
        @table = Session.parse_table(@flat_table)
        @chr_main = Session.decode_hex(@table.dig('CHR', 'Main'))
        @chr_copy = Session.decode_hex(@table.dig('CHR', 'Copy'))
        @chr_undo = Session.decode_hex(@table.dig('CHR', 'Undo'))
        @metasprites_offset = @table.dig('Var', 'Sprite', 'Grid').then do |grid|
          {
            x: grid['X'].to_i,
            y: grid['Y'].to_i
          }
        end
        @metasprites = Session.make_metasprites(
          names: Session.metasprite_names(@table.dig('Meta', 'Sprite')),
          bytes: Session.decode_hex(@table.dig('Meta', 'Sprites')),
          offset: @metasprites_offset
        )
      end

      def self.read(file)
        new(File.read(file))
      end

      def map
        @map ||= Session.build_map(@flat_table)
      end

      def palette
        @palette ||= Session.decode_hex(@flat_table['Palette']) || []
      end

      def export_png(path, **)
        require_relative 'png_exporter'
        PngExporter.export(self, path, **)
      end

      def self.build_map(flat_table)
        tiles = decode_hex(flat_table['NameTable'])
        attributes = decode_hex(flat_table['AttrTable']) || []
        return nil if tiles.nil? || tiles.empty?

        width = flat_table['VarNameW'].to_i
        height = flat_table['VarNameH'].to_i
        Map.new(tiles + attributes, width: width, height: height)
      end

      def self.parse_table(flat_table)
        table = {}
        flat_table.each do |key, value|
          path = decompose_key(key)
          path.reduce(table) do |a, e|
            a[e] = { '_root' => a[e] } unless a[e].nil? || a[e].is_a?(Hash)
            a[e] ||= {}
          end
          if path.size > 1
            table.dig(*path[..-2])[path[-1]] = value
          else
            table[path.first] = value
          end
        end
        table
      end

      def self.decompose_key(key)
        key.split(/(?<=[^A-Z0-9])(?=[A-Z0-9])|(?<=CHR)/).map { |part| part.delete('_') }
      end

      def self.decode_hex(string)
        return if string.nil? || string.empty?

        string = string['_root'] if string.is_a?(Hash)
        return if string.nil? || string.empty?

        scanner = StringScanner.new(string)
        values = []
        last = 0
        until scanner.eos?
          if (hex = scanner.scan(/[0-9a-f]{2}/))
            last = hex.to_i(16)
            values << last
          elsif scanner.scan(/\[([0-9a-f]+)\]/)
            values.concat(Array.new(scanner[1].to_i(16) - 1, last))
          else
            raise "Invalid string #{scanner.rest}"
          end
        end
        values
      end

      def self.metasprite_names(table)
        return {} if table.nil?

        table.select { |key, value| value.is_a?(String) && key =~ /\d/ }
             .to_h { |key, value| [value, key.to_i] }
      end

      def self.make_metasprites(names:, bytes:, offset:)
        return [] if bytes.nil? || bytes.empty?

        sprites = bytes.each_slice(256)
                       .to_a
                       .map do |meta_bytes|
          meta_bytes.each_slice(4)
                    .reject { |row| row[0] == 255 && row[2] == 255 && row[3] == 255 }
                    .map do |y, tile, attribute, x|
            raise "Invalid bytes #{bytes}" if y.nil? || tile.nil? || attribute.nil? || x.nil?

            Sprite.new(y: y - offset[:y], tile: tile, attribute: attribute, x: x - offset[:x])
          end
        end
        names.map do |name, index|
          Metasprite.new(name: name, sprites: sprites[index])
        end
      end
    end
  end
end
