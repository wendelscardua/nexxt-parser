# frozen_string_literal: true

RSpec.describe NEXXT::Parser::Map do
  describe '.read' do
    it 'requires a binary file path' do
      expect { described_class.read('nonexistent.map') }.to raise_error(Errno::ENOENT)
    end
  end

  describe '.extract_dimensions' do
    it 'extracts 32x30 from 1024-byte nam file' do
      bytes = [0] * 1024
      expect(described_class.extract_dimensions(bytes)).to eq([32, 30])
    end

    it 'extracts dimensions from header' do
      bytes = [0] * 1000
      bytes[-4] = 16  # width low
      bytes[-3] = 0   # width high
      bytes[-2] = 16  # height low
      bytes[-1] = 0   # height high
      expect(described_class.extract_dimensions(bytes)).to eq([16, 16])
    end

    it 'raises on insufficient bytes' do
      bytes = [1, 2, 3]
      expect { described_class.extract_dimensions(bytes) }.to raise_error('Invalid sizes')
    end
  end

  describe '.organize_in_tiles' do
    it 'creates 2D array of tiles' do
      bytes = (0..15).to_a
      tiles = described_class.organize_in_tiles(bytes, 4, 4)
      expect(tiles.length).to eq(4)
      expect(tiles[0]).to eq([0, 1, 2, 3])
      expect(tiles[3]).to eq([12, 13, 14, 15])
    end
  end

  describe '.extract_attribute' do
    let(:attributes) { [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15] }

    it 'extracts attribute for top-left metatile' do
      attr_val = described_class.extract_attribute(attributes, 32, 0, 0)
      expect(attr_val).to eq(0)
    end

    it 'shifts for odd rows' do
      attr_val = described_class.extract_attribute(attributes, 32, 1, 0)
      expect(attr_val).to eq(0)
    end

    it 'shifts for odd columns' do
      attr_val = described_class.extract_attribute(attributes, 32, 0, 1)
      expect(attr_val).to eq(0)
    end
  end

  describe 'Metatile#to_a' do
    it 'returns array of tile indices and attribute' do
      metatile = described_class::Metatile.new(0, 1, 2, 3, 2)
      expect(metatile.to_a).to eq([0, 1, 2, 3, 2])
    end
  end
end
