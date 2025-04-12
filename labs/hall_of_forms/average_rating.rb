# frozen_string_literal: true

require 'awesome_print'
require 'bigdecimal'
require 'json'

hall  = JSON.parse(open('data/fandom/halls.json').read)
units = JSON.parse(open('data/game8/json/detailed/units.json').read)

# https://stackoverflow.com/a/50891978
def lev(string1, string2, memo={})
  return memo[[string1, string2]] if memo[[string1, string2]]
  return string2.size if string1.empty?
  return string1.size if string2.empty?

  min = [
    lev(string1.chop, string2, memo) + 1,
    lev(string1, string2.chop, memo) + 1,
    lev(string1.chop, string2.chop, memo) + (string1[-1] == string2[-1] ? 0 : 1),
  ].min
  memo[[string1, string2]] = min
  min
end

errors = {
  no_alts: [],
  approximations: [],
  not_found: [],
}
unit_and_ratings = {}
hall.each do |number, us|
  unit_and_ratings[number] =
    us.map do |u|
      name, title = u.split(':').map(&:strip)
      alts = units.select { |unit| unit['name'] == name }
      if alts.nil?
        errors[:no_alts] << u
        next
      end

      uu = alts.find { |unit| unit['title'] == title }
      if uu.nil?
        uu, distance = alts.map { |unit| [unit, lev(unit['title'], title)] }.min_by(&:last)
        if distance < 5
          errors[:approximations] << [u, "#{uu['name']}: #{uu['title']}"]
        else
          errors[:not_found] << [u, alts.map { |unit| unit['title'] }]
          next
        end
      end

      [u, uu['game8_rating']]
    end
end

unit_cnt_by_rating = {}
unit_and_ratings.map do |number, us|
  res = ['9.9', '9.5', '9.0'].map do |rating|
    [rating, us.count { |u| u[1] == rating }]
  end
  res << ['< 9', us.count { |u| BigDecimal(u[1]) < 9 }]
  unit_cnt_by_rating[number] = res
end

# ap unit_cnt_by_rating

avg_unit_cnt_by_rating = Hash.new(0)
count = unit_cnt_by_rating.size
unit_cnt_by_rating.map do |_number, cnt_by_ratings|
  cnt_by_ratings.each do |rating, cnt|
    avg_unit_cnt_by_rating[rating] += cnt
  end
end
ap avg_unit_cnt_by_rating
avg_unit_cnt_by_rating.transform_values! { |v| BigDecimal(v) / count }

# propability of appearance for each rating by hall of forms
ap avg_unit_cnt_by_rating
# {
#   "9.9" => 0.0,
#   "9.5" => 0.15,
#   "9.0" => 1.54,
#   "< 9" => 2.30
# }

# average rating in a hall of forms
total = unit_and_ratings.sum do |_number, us|
  us.sum { |u| BigDecimal(u[1]) }
end
ap(total / count / 4)
# => 8.5
