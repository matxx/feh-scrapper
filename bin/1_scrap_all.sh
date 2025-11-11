#!/usr/bin/env ruby

lib = File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'scrappers/all'
require 'awesome_print'

# a = Scrappers::All.new
a = Scrappers::All.new(level: Logger::INFO)
a.game8.log_and_launch(:reset_index_files)
# a.game8.log_and_launch(:reset_html_files) # this line will force downloading of all pages again
# a.game8.log_and_launch(:reset_json_files) # this line will force parsing of all pages again
a.handle_everything
