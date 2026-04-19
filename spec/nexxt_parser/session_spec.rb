# frozen_string_literal: true

RSpec.describe NEXXT::Parser::Session do
  describe '.read' do
    it 'reads a session file' do
      session = described_class.read(fixture_path('session_with_map.nss'))
      expect(session.text).to include('NSTssTXT')
    end
  end

  describe '#flat_table' do
    it 'parses key=value pairs' do
      session = described_class.read(fixture_path('session_with_map.nss'))
      expect(session.flat_table['VarNullTile']).to eq('96')
    end
  end

  describe '#table' do
    it 'parses nested keys' do
      session = described_class.read(fixture_path('session_with_map.nss'))
      grid = session.table.dig('Var', 'Sprite', 'Grid')
      expect(grid['X']).to eq('64')
      expect(grid['Y']).to eq('64')
    end
  end

  describe '#chr_main' do
    it 'decodes hex data' do
      session = described_class.read(fixture_path('session_with_map.nss'))
      expect(session.chr_main).to be_an(Array)
      expect(session.chr_main.first).to eq(0)
    end
  end

  describe '#metasprites' do
    it 'parses metasprites from session with map (empty)' do
      session = described_class.read(fixture_path('session_with_map.nss'))
      expect(session.metasprites).to be_empty
    end

    it 'parses metasprites from session with metasprites' do
      session = described_class.read(fixture_path('session_with_metasprites.nss'))
      expect(session.metasprites).not_to be_empty
      expect(session.metasprites.first.name).to eq('PuzzleCursor')
    end
  end

  describe '#map' do
    it 'returns a MapFile sized from VarNameW/VarNameH' do
      session = described_class.read(fixture_path('session_with_map.nss'))
      map = session.map
      expect(map).to be_a(NEXXT::Parser::MapFile)
      expect([map.width, map.height]).to eq([16, 16])
      expect(map.tiles[0][0]).to eq(0xeb)
      expect(map.attributes.first).to eq(0x55)
    end

    it 'returns a MapFile for a 32x32 nametable' do
      session = described_class.read(fixture_path('session_with_metasprites.nss'))
      map = session.map
      expect([map.width, map.height]).to eq([32, 32])
      expect(map.tiles.length).to eq(32)
      expect(map.tiles.first.length).to eq(32)
    end

    it 'memoizes the result' do
      session = described_class.read(fixture_path('session_with_map.nss'))
      expect(session.map).to equal(session.map)
    end
  end

  describe '#palette' do
    it 'decodes the session palette bytes' do
      session = described_class.read(fixture_path('session_with_map.nss'))
      expect(session.palette.length).to eq(64)
      expect(session.palette[0, 4]).to eq([0x0a, 0x3c, 0x28, 0x17])
    end
  end

  describe '.decode_hex' do
    it 'parses literal hex bytes' do
      result = described_class.decode_hex('010203')
      expect(result).to eq([1, 2, 3])
    end

    it 'parses RLE runs' do
      result = described_class.decode_hex('ff[03]')
      expect(result).to eq([255, 255, 255])
    end

    it 'handles mixed literal and RLE' do
      result = described_class.decode_hex('01ff[02]03')
      expect(result).to eq([1, 255, 255, 3])
    end

    it 'returns nil for empty string' do
      expect(described_class.decode_hex('')).to be_nil
    end

    it 'returns nil for nil' do
      expect(described_class.decode_hex(nil)).to be_nil
    end

    it 'raises on invalid string' do
      expect { described_class.decode_hex('invalid') }.to raise_error(/Invalid string/)
    end
  end

  describe '.decompose_key' do
    it 'splits camelCase keys' do
      result = described_class.decompose_key('VarSpriteGridX')
      expect(result).to eq(%w[Var Sprite Grid X])
    end

    it 'preserves CHR segments' do
      result = described_class.decompose_key('CHRMain')
      expect(result).to eq(%w[CHR Main])
    end
  end

  describe '.parse_table' do
    it 'creates nested hash from flat key=value' do
      flat = { 'VarSpriteGridX' => '64' }
      result = described_class.parse_table(flat)
      expect(result.dig('Var', 'Sprite', 'Grid', 'X')).to eq('64')
    end
  end
end
