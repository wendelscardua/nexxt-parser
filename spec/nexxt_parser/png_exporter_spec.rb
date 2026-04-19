# frozen_string_literal: true

require 'tmpdir'

RSpec.describe NEXXT::Parser::PngExporter do
  let(:session) { NEXXT::Parser::Session.read(fixture_path('session_with_map.nss')) }

  describe '#to_png' do
    it 'emits a valid PNG signature' do
      png = described_class.new(session).to_png
      expect(png.byteslice(0, 8)).to eq("\x89PNG\r\n\x1A\n".b)
    end

    it 'writes IHDR with image dimensions in pixels' do
      png = described_class.new(session).to_png
      width = png.byteslice(16, 4).unpack1('N')
      height = png.byteslice(20, 4).unpack1('N')
      expect([width, height]).to eq([16 * 8, 16 * 8])
    end

    it 'writes IHDR with 8-bit RGB truecolor' do
      png = described_class.new(session).to_png
      bit_depth = png.getbyte(24)
      color_type = png.getbyte(25)
      expect([bit_depth, color_type]).to eq([8, 2])
    end
  end

  describe '.export' do
    it 'writes a PNG file to disk' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'map.png')
        described_class.export(session, path)
        expect(File.binread(path, 8)).to eq("\x89PNG\r\n\x1A\n".b)
      end
    end
  end

  describe 'Session#export_png' do
    it 'delegates to PngExporter' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'nt.png')
        session.export_png(path)
        expect(File.size(path)).to be > 100
      end
    end
  end

  describe 'rendering a known pixel' do
    it 'maps color-index 0 to the sub-palette universal BG' do
      matrix = described_class.new(session).pixels
      universal_bg = session.palette[0] & 0x3F
      expect(matrix.first.first).to eq(described_class::NES_PALETTE[universal_bg])
    end
  end
end
