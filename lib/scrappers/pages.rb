# frozen_string_literal: true

require 'uri'
require 'open-uri'
require 'nokogiri'

module Scrappers
  class Pages < Base
    attr_reader(
      :now,
      :errors,
      :logger,

      :all_guides,
      :all_guides_by_names,
      :all_respls,
      :all_respls_by_names,
      :all_versions,
    )

    def initialize(level: Logger::ERROR)
      @now = Time.now

      @logger = Logger.new($stdout)
      logger.level = level

      boot

      super
    end

    def reset!
      boot
    end

    def handle_everything
      log_and_launch(:scrap_everything)

      nil
    end

    def scrap_everything
      log_and_launch(:scrap_guides)
      log_and_launch(:scrap_respls)
      log_and_launch(:scrap_versions)

      nil
    end

    def scrap_guides
      return if all_guides

      page = 'https://guide.fire-emblem-heroes.com/en-US/category/character/'
      response = HTTP.get(page)
      html = response.body.to_s

      # MONKEY PATCH: all <li> are wrongfully self closed...
      fixed = html.gsub(%r{(<li [^/>]+)/>}, '\1>')

      dom = Nokogiri::HTML.parse(fixed)
      @all_guides = []
      dom.css('.character_ul li').each do |li|
        link = li.at('a').attr('href')

        all_guides << {
          id: link.split('/').last,
          name: li.at('.character_name').text.strip,
          title: li.at('.character_nick').text.strip,
        }
      end

      @all_guides_by_names = all_guides.index_by { |x| [x[:name], x[:title]] }

      guides_with_same_names = all_guides.group_by { |x| [x[:name], x[:title]] }.select { |_, v| v.size > 1 }
      errors[:guides_with_same_names] = guides_with_same_names.keys if guides_with_same_names.any?

      nil
    end

    def reset_all_guides!
      @all_guides = nil
      @all_guides_by_names = nil
    end

    def scrap_respls
      return if all_respls

      page = 'https://fehpass.fire-emblem-heroes.com/en-US/'
      response = HTTP.get(page)
      html = response.body.to_s
      dom = Nokogiri::HTML.parse(html)
      @all_respls = []
      (dom.css('.cahra_list li') + dom.css('section.next') + dom.css('section.new')).each do |li|
        link = li.at('a').attr('href')

        all_respls << {
          id: link.split('/').first,
          name:  li.at('.chara_txt > dd').text.strip,
          title: li.at('.chara_txt > dt').text.strip,
        }
      end

      @all_respls_by_names = all_respls.index_by { |x| [x[:name], x[:title]] }

      respls_with_same_names = all_respls.group_by { |x| [x[:name], x[:title]] }.select { |_, v| v.size > 1 }
      errors[:respls_with_same_names] = respls_with_same_names.keys if respls_with_same_names.any?

      nil
    end

    def reset_all_respls!
      @all_respls = nil
      @all_respls_by_names = nil
    end

    def scrap_versions
      return if all_versions

      # url = 'https://fire-emblem-heroes.com/en/topics/'
      url = 'https://fire-emblem-heroes.com/en/include/topics_detail.html'
      # contains all versions >= 7

      html = URI.parse(url).open.read
      dom = Nokogiri::HTML.parse(html)

      @all_versions = []
      dom.xpath("//p[@class='heading']/#{xpath_text_containing('Update')}").each do |header|
        m1 = header.text.match(/\AWhat's in Store for the (\d+)\.(\d+)\.(\d+) Update\Z/i)
        next (errors[:v_header_not_matching] = el.text.strip) if m1.nil?

        article = header.ancestors.find { |el| el.classes.include?('article') }
        next (errors[:v_no_article_ancestor] = el.text.strip) if article.nil?

        m2 = article.attr('id').match(/\Adetail-(\d{4})(\d{2})(\d{2})\Z/i)
        next (errors[:v_article_date_not_matching] = el.text.strip) if m2.nil?

        all_versions << {
          version: "#{m1[1]}.#{m1[2]}.#{m1[3]}",
          version_short: "#{m1[1]}.#{m1[2]}",
          date_str: "#{m2[1]}-#{m2[2]}-#{m2[3]}",
          date: Date.new(m2[1].to_i, m2[2].to_i, m2[3].to_i),
        }
      end

      all_versions.sort_by! { |v| v[:date_str] }
      all_versions.reverse!

      nil
    end

    def xpath_text_containing(str)
      <<~XPATH.strip
        text()[
          contains(
            translate(., 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'),
            '#{str.downcase}'
          )
        ]
      XPATH
    end

    def reset_all_versions!
      @all_versions = nil
    end

    def inspect
      "<#{self.class} @now=#{now}>"
    end

    private

    def boot
      @errors = empty_errors
    end

    def empty_errors
      Hash.new { |h, k| h[k] = [] }
    end
  end
end
