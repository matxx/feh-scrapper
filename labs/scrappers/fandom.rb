# frozen_string_literal: true

require 'awesome_print'

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'scrappers/fandom'

x = Scrappers::Fandom.new
# x = Scrappers::Fandom.new(level: Logger::DEBUG)
x.handle_everything

# after code update

Dir['lib/scrappers/**/*.rb'].each { |file| load(file) }
# x = Scrappers::Fandom.new(level: Logger::DEBUG)
x.reset!
x.handle_everything

# misc

load 'scrappers/fandom.rb'
x = Scrappers::Fandom.new(level: Logger::DEBUG)

x.reset_all_units!
x.scrap_units

load 'scrappers/fandom/summon_pool.rb'
x.reset_generic_summon_pool!
x.scrap_generic_summon_pool

load 'scrappers/fandom/summon_pool.rb'
x.reset_special_summon_pool!
x.scrap_special_summon_pool

load 'scrappers/fandom/divine_codes.rb'
x.reset_divine_codes!
x.scrap_divine_codes

load 'scrappers/fandom/units.rb'
x.fill_units_with_availabilities
x.errors.keys
x.errors[:units_in_special_pool_without_property_special].size
ap x.errors[:units_in_special_pool_without_property_special][0..10]

x.reset!

ap(x.all_units_by_wikiname.keys.select { |k| k.include?('Kiria') })
ap(x.current_generic_pool_by_unit_pagename.keys.select { |k| k.include?('Kiria') })
ap(x.current_generic_pool_by_unit_wikiname.keys.select { |k| k.include?('Kiria') })

_units_with_same_wikiname = x.all_units.group_by { |u| u['Page'] }.select { |_, v| v.size > 1 }

load 'scrappers/fandom/skills.rb'
x.reset_all_skills!
x.scrap_skills
x.reset_all_unit_skills!
x.scrap_unit_skills

x.all_skills.size
x.all_unit_skills.size

x.fill_skills_with_genealogy
x.fill_skills_with_availabilities

ap x.all_units_by_wikiname['Dagr Sunny Bloom']
ap x.all_skills_by_wikiname['Reposition Gait']

ap x.all_skills_by_wikiname['SpdRes Rein 3']

# TODO: Lyn is 4.5
ap x.all_units_by_wikiname.keys.select { |k| k.include?('Lyn') }.sort
ap x.all_units_by_wikiname['Lyn Ninja-Friend Duo']

_unit = x.all_units_by_wikiname['Timerra Desert Warrior']

y = x.all_units.group_by { |u| u[:max_score] }
y[nil].reject { |z| z['Properties']&.include?('enemy') }.size
# => must be 0

# data on summon pool

generic_summon_pool = x.all_units.reject { |u| u['Properties']&.include?('special') }.to_h do |unit|
  [unit['Page'], x.current_generic_pool_by_unit_pagename[unit['Page']]]
end

ap(generic_summon_pool.reject { |_, v| v })

_xs = x.all_units.reject { |u| u['Properties']&.include?('special') }

title = 'Zelot: Avowed Groom'
title = 'Rhys: Gentle Basker'
title = 'Zephiel: The Liberator'
title = 'Sharena: Princess of Askr'
title = 'Arlen: Mage of Khadein'
unit = x.all_units.find { |u| u['Page'] == title }
ap unit

# https://feheroes.fandom.com/wiki/Summonable_Heroes
x.count { |_,v| v.include?('5') }
# 22+21+17+18
x.count { |_,v| v&.include?('4') }
# 47+49+38+53
x.count { |_,v| v&.include?('4SR') }
# 77+58+48+38
