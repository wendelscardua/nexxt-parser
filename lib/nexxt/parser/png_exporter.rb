# frozen_string_literal: true

require 'zlib'
require_relative 'map'

module NEXXT
  module Parser
    class PngExporter
      # 2C02 NES RGB palette (FCEUX-style), one RGB triple per palette index (0x00-0x3F).
      NES_PALETTE = [
        [0x7C, 0x7C, 0x7C], [0x00, 0x00, 0xFC], [0x00, 0x00, 0xBC], [0x44, 0x28, 0xBC],
        [0x94, 0x00, 0x84], [0xA8, 0x00, 0x20], [0xA8, 0x10, 0x00], [0x88, 0x14, 0x00],
        [0x50, 0x30, 0x00], [0x00, 0x78, 0x00], [0x00, 0x68, 0x00], [0x00, 0x58, 0x00],
        [0x00, 0x40, 0x58], [0x00, 0x00, 0x00], [0x00, 0x00, 0x00], [0x00, 0x00, 0x00],
        [0xBC, 0xBC, 0xBC], [0x00, 0x78, 0xF8], [0x00, 0x58, 0xF8], [0x68, 0x44, 0xFC],
        [0xD8, 0x00, 0xCC], [0xE4, 0x00, 0x58], [0xF8, 0x38, 0x00], [0xE4, 0x5C, 0x10],
        [0xAC, 0x7C, 0x00], [0x00, 0xB8, 0x00], [0x00, 0xA8, 0x00], [0x00, 0xA8, 0x44],
        [0x00, 0x88, 0x88], [0x00, 0x00, 0x00], [0x00, 0x00, 0x00], [0x00, 0x00, 0x00],
        [0xF8, 0xF8, 0xF8], [0x3C, 0xBC, 0xFC], [0x68, 0x88, 0xFC], [0x98, 0x78, 0xF8],
        [0xF8, 0x78, 0xF8], [0xF8, 0x58, 0x98], [0xF8, 0x78, 0x58], [0xFC, 0xA0, 0x44],
        [0xF8, 0xB8, 0x00], [0xB8, 0xF8, 0x18], [0x58, 0xD8, 0x54], [0x58, 0xF8, 0x98],
        [0x00, 0xE8, 0xD8], [0x78, 0x78, 0x78], [0x00, 0x00, 0x00], [0x00, 0x00, 0x00],
        [0xFC, 0xFC, 0xFC], [0xA4, 0xE4, 0xFC], [0xB8, 0xB8, 0xF8], [0xD8, 0xB8, 0xF8],
        [0xF8, 0xB8, 0xF8], [0xF8, 0xA4, 0xC0], [0xF0, 0xD0, 0xB0], [0xFC, 0xE0, 0xA8],
        [0xF8, 0xD8, 0x78], [0xD8, 0xF8, 0x78], [0xB8, 0xF8, 0xB8], [0xB8, 0xF8, 0xD8],
        [0x00, 0xFC, 0xFC], [0xF8, 0xD8, 0xF8], [0x00, 0x00, 0x00], [0x00, 0x00, 0x00]
      ].freeze

      TILE_SIZE = 8
      BYTES_PER_TILE = 16
      CHR_BANK_SIZE = 4096
      PALETTE_BANK_SIZE = 16
      PNG_MAGIC = "\x89PNG\r\n\x1A\n".b.freeze

      def self.export(session, path, **)
        new(session, **).write(path)
      end

      def initialize(session, chr_bank: nil, palette_bank: nil, nes_palette: NES_PALETTE)
        @session = session
        @map = session.map or raise Error, 'Session has no nametable data'
        @chr_bank = chr_bank || session.flat_table['VarBankActive'].to_i
        @palette_bank = palette_bank || session.flat_table['VarPalBank'].to_i
        @nes_palette = nes_palette
        @palette = session.palette
      end

      def write(path)
        File.binwrite(path, to_png)
      end

      def to_png
        encode_png(pixels)
      end

      def pixels
        height_px = @map.height * TILE_SIZE
        width_px = @map.width * TILE_SIZE
        matrix = Array.new(height_px) { Array.new(width_px) }
        (0...@map.height).each do |tile_row|
          (0...@map.width).each { |tile_col| render_tile(matrix, tile_row, tile_col) }
        end
        matrix
      end

      private

      def render_tile(matrix, tile_row, tile_col)
        tile_index = @map.tiles[tile_row][tile_col]
        attr = Map.extract_attribute(@map.attributes, @map.width, tile_row / 2, tile_col / 2)
        chr_offset = (@chr_bank * CHR_BANK_SIZE) + (tile_index * BYTES_PER_TILE)
        pal_offset = (@palette_bank * PALETTE_BANK_SIZE) + (attr * 4)
        (0...TILE_SIZE).each do |y|
          plane_lo = @session.chr_main[chr_offset + y].to_i
          plane_hi = @session.chr_main[chr_offset + TILE_SIZE + y].to_i
          paint_row(matrix[(tile_row * TILE_SIZE) + y], tile_col * TILE_SIZE,
                    plane_lo, plane_hi, pal_offset)
        end
      end

      def paint_row(target, base_x, plane_lo, plane_hi, pal_offset)
        (0...TILE_SIZE).each do |x|
          bit = 7 - x
          color_idx = ((plane_lo >> bit) & 1) | (((plane_hi >> bit) & 1) << 1)
          nes_color = @palette[pal_offset + color_idx].to_i & 0x3F
          target[base_x + x] = @nes_palette[nes_color]
        end
      end

      def encode_png(matrix)
        height = matrix.size
        width = matrix.first.size
        ihdr = [width, height, 8, 2, 0, 0, 0].pack('NNCCCCC')
        idat = Zlib::Deflate.deflate(scanlines(matrix), Zlib::BEST_COMPRESSION)
        String.new(encoding: Encoding::BINARY)
              .concat(PNG_MAGIC, chunk('IHDR', ihdr), chunk('IDAT', idat), chunk('IEND', ''.b))
      end

      def scanlines(matrix)
        raw = String.new(encoding: Encoding::BINARY)
        matrix.each do |row|
          raw << "\x00".b
          raw << row.flatten.pack('C*')
        end
        raw
      end

      def chunk(type, data)
        type_b = type.b
        data_b = data.b
        String.new(encoding: Encoding::BINARY)
              .concat([data_b.bytesize].pack('N'),
                      type_b,
                      data_b,
                      [Zlib.crc32(type_b + data_b)].pack('N'))
      end
    end
  end
end
