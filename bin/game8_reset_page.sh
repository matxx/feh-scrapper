#!/usr/bin/env ruby

lib = File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'scrappers/game8'
require 'awesome_print'

id = ENV.fetch('PAGE_ID')

# g = Scrappers::Game8.new
g = Scrappers::Game8.new(level: Logger::INFO)
g.list_existing_files
g.delete_page_files(id)
