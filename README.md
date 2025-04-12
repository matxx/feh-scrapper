# FEH Scrapper

Extract data from Fandom and Game8 and export it as JSONs

## TODO

### Features

1. automatic updates every night for fandom
1. trigger game8 update on website
1. unit tests
1. get all images from sprites

### Fixes

1. populate refined weapon with game8 IDs of the same weapon name
1. game8 IDs for T3 skills & seals are mixed up (ex: A/R Push 3)
1. remove(?) "4.5", pass everything as BigDecimal ? (comparison to 4.5 (float) can be incorrect)

## Log levels

- `Logger::UNKNOWN` : not used
- `Logger::FATAL` : not used
- `Logger::ERROR` : logging which method is currently being run
- `Logger::WARN` : logging details about data being fetched from websites
- `Logger::INFO` : general information
- `Logger::DEBUG` : technical details
