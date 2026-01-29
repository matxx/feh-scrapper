# FEH Scrapper

Extract data from Fandom and Game8 and export it as JSON files.

## TODO

### Features

1. export BVIDs (https://feheroes.fandom.com/wiki/Special:CargoTables/HeroBVIDs)

1. automatic updates every night (https://jasonet.co/posts/scheduled-actions/)
1. unit tests
1. get all images from sprites
1. (?) replace `game8_id` with `game8_link`
1. (?) replace `skill#group_name` with `fandom_link` and use `unit#full_name` for `fandom_link`

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
