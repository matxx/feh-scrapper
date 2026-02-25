# FEH Scrapper

Extract data from Fandom and Game8 and export it as JSON files.

## TODO

### Features

1. export BVIDs (https://feheroes.fandom.com/wiki/Special:CargoTables/HeroBVIDs)

1. automatic updates every night (https://jasonet.co/posts/scheduled-actions/)
1. unit tests
1. get all images from sprites

1. reverse engineer FEH exchanges ? (<https://www.reddit.com/r/FireEmblemHeroes/comments/6oqm74/network_decoding_of_feheroes_data/>)

### QoL

### Fixes

1. refactor rarities with BigDecimal ? (comparison to 4.5 (float) can be incorrect)

## Log levels

- `Logger::UNKNOWN` : not used
- `Logger::FATAL` : not used
- `Logger::ERROR` : logging which method is currently being run
- `Logger::WARN` : logging details about data being fetched from websites
- `Logger::INFO` : general information
- `Logger::DEBUG` : technical details
