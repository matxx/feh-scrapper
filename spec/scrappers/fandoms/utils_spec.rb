# frozen_string_literal: true

require 'scrappers/fandoms/utils'

RSpec.describe Scrappers::Fandoms::Utils do
  subject(:host) { Object.new.extend(described_class) }

  describe '#escape_url_part' do
    it 'replaces spaces with underscores' do
      expect(host.escape_url_part('Brave Ike')).to eq('Brave_Ike')
    end

    it 'percent-encodes reserved characters' do
      expect(host.escape_url_part('Light & Shadow: Part 2 (Notification)?'))
        .to eq('Light_%26_Shadow%3A_Part_2_%28Notification%29%3F')
    end

    it 'percent-encodes apostrophes and non-ASCII characters' do
      expect(host.escape_url_part("Father's Seiðr")).to eq('Father%27s_Sei%C3%B0r')
    end

    it 'returns nil for nil' do
      expect(host.escape_url_part(nil)).to be_nil
    end
  end
end
