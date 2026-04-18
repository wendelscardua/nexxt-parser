# frozen_string_literal: true

module NEXXT
  module Parser
    class Sprite < Data.define(:x, :y, :tile, :attribute)
    end

    class Metasprite < Data.define(:name, :sprites)
    end
  end
end