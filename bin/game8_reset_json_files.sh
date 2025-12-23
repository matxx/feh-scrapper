#!/usr/bin/env ruby

lib = File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'scrappers/game8'
require 'awesome_print'

# g = Scrappers::Game8.new
g = Scrappers::Game8.new(level: Logger::INFO)
g.reset_json_files
