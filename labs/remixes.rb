# frozen_string_literal: true

require 'uri'
require 'open-uri'
require 'nokogiri'
require 'mediawiki_api'
require 'diffy'

# url = 'https://fire-emblem-heroes.com/en/topics/'
url = 'https://fire-emblem-heroes.com/en/include/topics_detail.html'
html = URI.parse(url).open.read
dom = Nokogiri::HTML.parse(html)

def text_containing(str)
  <<~XPATH.strip
    text()[
      contains(
        translate(., 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'),
        '#{str.downcase}'
      )
    ]
  XPATH
end

arr = dom.xpath("//div[@class='article']/#{text_containing('○ New skills')}")

errors = Hash.new { |h, k| h[k] = [] }
results = []
arr.each do |el|
  article = el.parent
  next (errors[:parent_not_article] << el) unless article.attr('class') == 'article'

  m = article.css('.date').text.match(%r{(?<month>\d+)/(?<day>\d+)/(?<year>\d+)})
  next (errors[:no_date_match] << el) if m.nil?

  date = "#{m[:year].rjust(4, '0')}-#{m[:month].rjust(2, '0')}-#{m[:day].rjust(2, '0')}"

  m = article.css('.heading').text.match(/What's in Store for the ([0-9.]+) Update/i)
  next (errors[:no_version_match] << el) if m.nil?

  version = m[1]

  paras = article.xpath(".//#{text_containing('■ New skills')}")
  next (errors[:paras_not_unique] << el) unless paras.size == 1

  para = paras.first.ancestors.find { |node| node.name == 'p' }
  next (errors[:no_para] << el) if para.nil?

  span1 = para.next_element
  next (errors[:not_span1] << el) unless span1.name == 'span'

  span2 = span1.next_element
  next (errors[:not_span2] << el) unless span2.name == 'span'

  units = [span1.text, span2.text]

  texts = []
  texts += article.xpath(".//#{text_containing('・Assist Skill')}")
  texts += article.xpath(".//#{text_containing('・Special Skill')}")
  texts += article.xpath(".//#{text_containing('・A Skill')}")
  texts += article.xpath(".//#{text_containing('・B Skill')}")
  texts += article.xpath(".//#{text_containing('・C Skill')}")
  texts += article.xpath(".//#{text_containing('・ Assist Skill')}")
  texts += article.xpath(".//#{text_containing('・ Special Skill')}")
  texts += article.xpath(".//#{text_containing('・ A Skill')}")
  texts += article.xpath(".//#{text_containing('・ B Skill')}")
  texts += article.xpath(".//#{text_containing('・ C Skill')}")
  next (errors[:not_four_txts] << el) unless texts.size == 4

  skills = []
  texts.each do |text|
    # image 1 can be the exclamation point (optional)
    img1 = text.next_element
    img1 = img1.next_element until img1.name == 'img' || img1.nil?
    next (errors[:skill_without_img1] << text) if img1.nil?

    # image 2 is the skill icon
    img2 = img1.next_element

    txt = (img2.name == 'img' ? img2 : img1).next_sibling
    next (errors[:skill_not_text] << text) unless txt.name == 'text'

    skills << txt.text.strip
  end

  next (errors[:skills_with_dupe] << el) unless skills.size == skills.uniq.size

  results << {
    date:,
    version:,
    units:,
    skills:,
  }
end

unless errors.empty?
  ap errors
  raise 'some errors need fixing'
end

# el = errors[:skill_without_img2].first
# el = errors[:not_four_txts].first
# article = el.ancestors.find { |node| node.attr('class') == 'article' }

errors = Hash.new { |h, k| h[k] = [] }

client = MediawikiApi::Client.new 'https://feheroes.fandom.com/api.php'
username = ENV.fetch('WIKIBOT_USERNAME', nil)
password = ENV.fetch('WIKIBOT_PASSWORD', nil)
token = res.data['tokens']['logintoken']
# without login token, edits are not tagged with username, but only with IP
client.log_in(username, password, token)
# res = client.query meta: :tokens, type: :login
# client.action(:login, lgname: username, lgpassword: password, lgtoken: token)

titles = results.flat_map { |r| r[:units] }
response = client.query titles:, prop: :revisions, rvprop: :content

unless titles.size == response.data['pages'].size
  missing = titles - response.data['pages'].map(&:last).map { |h| h['title'] }
  errors[:missin_pages] = missing
end

pages = {}
response.data['pages'].each_value do |data|
  title = data['title']
  text = data['revisions'][0]['*']
  pages[title] = text
end

diffs = []
hdiif = {}
editions = {}
results.each do |result|
  result[:units].each do |unit|
    page = pages[unit]
    next (errors[:missin_unit_page] << unit) if page.nil?

    lines = page.split("\n")

    skills_already_done = 0
    lines_to_add = []
    cnt = 0
    result[:skills].each do |skill|
      ls = lines.map.with_index.select { |l, _| l.include?(skill) }
      next if ls.empty?
      next (errors[:multiple_lines_for_skill] << [unit, skill]) if ls.size > 1

      cnt += 1
      line, idx = ls.first
      prefix = nil
      if (m = line.match(/\A\|assist(\d)=/))
        prefix = "|assist#{m[1]}Addition="
      elsif (m = line.match(/\A\|special(\d)=/))
        prefix = "|special#{m[1]}Addition="
      elsif (m = line.match(/\A\|passive([A-C]\d)=/))
        prefix = "|passive#{m[1]}Addition="
      else
        next (errors[:skill_without_match] << [unit, skill])
      end

      line_to_add = {
        line: "#{prefix}#{result[:date]}",
        index: idx + 1,
      }
      if lines.any? { |l| l.include?(prefix) }
        skills_already_done += 1
      else
        lines_to_add << line_to_add
      end
    end
    next (errors[:missin_unit_skills] << unit) unless cnt == 2
    next if skills_already_done == 2

    new_lines = lines.dup
    lines_to_add.sort_by { |x| x[:index] }.reverse.each do |line_to_add|
      new_lines.insert(line_to_add[:index], line_to_add[:line])
    end
    new_page = new_lines.join("\n")

    diff = Diffy::Diff.new(page, new_page)
    diffs << diff
    hdiif[unit] = diff
    editions[unit] = new_page
  end
end

# errors[:missin_unit_skills].size

unless errors.empty?
  ap errors
  raise 'some errors need fixing'
end

puts diffs.map(&:to_s).join("\n\n\n-----------------------------\n\n\n")

line_size = 80
puts(hdiif.map do |unit, diff|
  space_before = (line_size - unit.size - 1) / 2
  space_after = line_size - unit.size - 2 - space_before
  [
    '*' * line_size,
    "*#{' ' * space_before}#{unit}#{' ' * space_after}*",
    '*' * line_size,
    diff.to_s,
    "\n\n\n",
  ].join("\n")
end)

# can not be automated, its impossible to handle downgrade of skills

# editions.each do |title, text|
#   client.edit(
#     title:,
#     text:,
#     summary: 'add remix dates',
#     bot: true,
#     token:,
#     tags: 'automated',
#     watchlist: 'nochange',
#   )

#   sleep(1)
# end
