# FEH Scrapper

Extract data from Fandom and Game8 and export it as JSONs

## TODO

### Features

1. automatic updates every night (https://jasonet.co/posts/scheduled-actions/)
1. unit tests
1. get all images from sprites

### QoL

1. handle "themes" ["Scion"](https://game8.co/games/fire-emblem-heroes/archives/341797) (s12! s! scion of twelve) and ["ferox"](https://game8.co/games/fire-emblem-heroes/archives/549583) (f!)

### Fixes

1. remove(?) "4.5", pass everything as BigDecimal ? (comparison to 4.5 (float) can be incorrect)

## Log levels

- `Logger::UNKNOWN` : not used
- `Logger::FATAL` : not used
- `Logger::ERROR` : logging which method is currently being run
- `Logger::WARN` : logging details about data being fetched from websites
- `Logger::INFO` : general information
- `Logger::DEBUG` : technical details
