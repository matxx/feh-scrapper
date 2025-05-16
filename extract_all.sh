#!/usr/bin/env ruby

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'scrappers/all'

a = Scrappers::All.new
a.game8.log_and_launch(:reset_index_files)
# a.game8.log_and_launch(:reset_json_files) # comment this to not parse again pages already parsed
a.handle_everything
