# frozen_string_literal: true

module NEXXT
  module Parser
    class MapFile
      attr_reader :raw_bytes,
                  :width,
                  :height,
                  :tiles,
                  :attributes,
                  :metatiles

      def initialize(raw_bytes)
        @raw_bytes = raw_bytes.dup
        @width, @height = MapFile.extract_dimensions(@raw_bytes)
        @tiles = MapFile.organize_in_tiles(@raw_bytes, @width, @height)
        @attributes = @raw_bytes[(@width * @height)..]

        @metatiles = MapFile.organize_in_metatiles(@tiles, @attributes, @width, @height)
      end

      def self.read(file)
        new(File.read(file).unpack('C*'))
      end

      def self.extract_dimensions(bytes)
        if bytes.size == 1024
          [32, 30]
        else
          width_l, width_h, height_l, height_h = bytes.pop(4)
          raise 'Invalid sizes' if width_l.nil? ||
                                   width_h.nil? ||
                                   height_l.nil? ||
                                   height_h.nil?

          [(width_h * 256) + width_l, (height_h * 256) + height_l]
        end
      end

      def self.organize_in_tiles(bytes, width, height)
        Array.new(height) do |row|
          Array.new(width) do |column|
            bytes[(row * width) + column]
          end
        end
      end

      def self.extract_attribute(attributes, width, meta_row, meta_column)
        attribute = attributes[((meta_row / 2) * (width / 4)) + (meta_column / 2)]
        attribute >>= 4 if meta_row.odd?
        attribute >>= 2 if meta_column.odd?
        attribute & 0b11
      end

      def self.extract_metatile_tiles(tiles, meta_row, meta_column)
        upper = meta_row * 2
        left = meta_column * 2
        lower = upper + 1
        right = left + 1
        [
          tiles[upper][left],
          tiles[upper][right],
          tiles[lower][left],
          tiles[lower][right]
        ]
      end

      def self.organize_in_metatiles(tiles, attributes, width, height)
        Array.new(height / 2) do |meta_row|
          Array.new(width / 2) do |meta_column|
            meta_tiles = MapFile.extract_metatile_tiles(tiles, meta_row, meta_column)
            Metatile.new(
              meta_tiles[0], meta_tiles[1], meta_tiles[2], meta_tiles[3],
              MapFile.extract_attribute(attributes, width, meta_row, meta_column)
            )
          end
        end.flatten
      end

      class Metatile
        attr_reader :upper_left, :upper_right, :lower_left, :lower_right, :attribute

        def initialize(upper_left, upper_right, lower_left, lower_right, attribute)
          @upper_left = upper_left
          @upper_right = upper_right
          @lower_left = lower_left
          @lower_right = lower_right
          @attribute = attribute
        end

        def to_a
          [
            upper_left,
            upper_right,
            lower_left,
            lower_right,
            attribute
          ]
        end
      end
    end
  end
end
