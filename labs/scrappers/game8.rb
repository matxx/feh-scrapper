# frozen_string_literal: true

require 'awesome_print'

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'scrappers/game8'

y = Scrappers::Game8.new
# y = Scrappers::Game8.new(level: Logger::DEBUG)
y.handle_everything

# after code update

Dir['lib/scrappers/**/*.rb'].each { |file| load(file) }
# y = Scrappers::Game8.new(level: Logger::DEBUG)
y.reset!
y.handle_everything

# scrap test

url = 'https://game8.co/games/fire-emblem-heroes/archives/505100'
html = URI.parse(url).open.read
dom = Nokogiri::HTML.parse(html)
th = dom.at('th:contains("Overall Rating")')
_rating = th.next_element.at('span').text
