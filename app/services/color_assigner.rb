class ColorAssigner
  PALETTE = %w[
    #e6194b #3cb44b #ffe119 #4363d8 #f58231
    #911eb4 #42d4f4 #f032e6 #bfef45 #fabed4
    #469990 #dcbeff #9a6324 #fffac8 #800000
    #aaffc3 #808000 #ffd8b1 #000075 #a9a9a9
    #e6beff #fff9c4 #bcf60c #cc79a7
  ].freeze

  def self.next_color_for(existing:)
    used = existing.compact
    (PALETTE - used).first || deterministic_color(used.size)
  end

  def self.deterministic_color(index)
    hue = (index * 137.508) % 360
    "hsl(#{hue.round}, 65%, 55%)"
  end
end
