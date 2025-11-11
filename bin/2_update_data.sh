#!/usr/bin/env ruby

require 'date'

hash = ENV.fetch('COMMIT_HASH')

file = 'lib/scrappers/s3.rb'
File.write(
  file,
  File.read(file).gsub(/COMMIT = '([^']+?)'/, "COMMIT = '#{hash}'")
)

`git commit #{file} -m "chore: #{Date.today.strftime('%Y-%m-%d')} update"`
`git push origin`
