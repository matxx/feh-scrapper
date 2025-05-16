# frozen_string_literal: true

require 'awesome_print'

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'scrappers/all'

a = Scrappers::All.new
# a = Scrappers::All.new(game8: { force_extraction: true })
# a = Scrappers::All.new(level: Logger::UNKNOWN)
# a = Scrappers::All.new(level: Logger::FATAL)
# a = Scrappers::All.new(level: Logger::ERROR)
# a = Scrappers::All.new(level: Logger::WARN)
# a = Scrappers::All.new(level: Logger::INFO)
# a = Scrappers::All.new(level: Logger::DEBUG)
# a.game8.reset_index_files
# a.game8.reset_json_files
a.handle_everything

# 3.2.2 :024 > a.fandom.errors[:skills_with_same_name]
#  => ["Falchion", "Missiletainn", "Rallying Cry", "Umbra Burst"]

# after code update

Dir['lib/scrappers/**/*.rb'].each { |file| load(file) }
# a = Scrappers::All.new
a.reset!
a.handle_everything

a.errors.keys

a.errors[:skill_approximations].size
ap a.errors[:skill_approximations].to_h

a.errors[:skill_not_found].size
a.errors[:skill_not_found]

a.errors[:unit_approximations].size
ap a.errors[:unit_approximations].to_h
a.errors[:fandom_unit_not_found].reject { |x| x['WikiName'].include?('ENEMY') }.size

a.errors[:fandom_unit_not_found].size
a.fandom.all_units.size

a.errors[:fandom_skill_not_found].size
a.fandom.all_skills.size

a.errors[:game8_unit_not_found].size
a.errors[:game8_unit_not_found].map { |x| x['Page'] }

a.errors[:game8_skill_not_found].size
a.errors[:game8_skill_not_found].map { |x| x['Name'] }

a.fandom.all_skills.select { |x| x['Scategory'] == 'sacredseal' }.count
# => 292

a.game8.all_skills.select { |x| x['category'] == 'skills_s' && !x['game8_name'].include?('Squad') }.size
# => 243
a.fandom.all_skills.select { |x| x['Scategory'] == 'sacredseal' && !x['Name'].include?('Squad') }.size
# => 56
