# frozen_string_literal: true

# require 'open-uri'
require 'mediawiki_api'

client = MediawikiApi::Client.new 'https://feheroes.fandom.com/api.php'
# client.log_in ENV['WIKI_BOT_USERNAME'], ENV['WIKI_BOT_PASSWORD']
# https://feheroes.fandom.com/wiki/Hall_of_Forms

LAST_HALL_NUMBER = 59

halls = {}
errors = {
  missing: [],
  mismatch: [],
  miscount: [],
}
(1..LAST_HALL_NUMBER).each do |i|
  title = "Hall_of_Forms_#{i}"

  # retrieve page text
  text = ''
  res = client.query titles: title, prop: :revisions, rvprop: :content
  begin
    page_id_as_str = res.data['pages'].keys.first
    text = res.data['pages'][page_id_as_str]['revisions'].first['*']
  rescue StandardError
    errors[:missing] << title
    next
  end

  m = text.match(/\|forma=(.*?)\|/m)
  if m.nil?
    errors[:mismatch] << title
    next
  end

  names = m[1].split(';').map(&:strip)
  errors[:miscount] << title unless names.size == 4

  halls[i] = names
end

FileUtils.mkdir_p 'data/fandom'
File.write('data/fandom/halls.json', JSON.pretty_generate(halls))
