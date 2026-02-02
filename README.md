# nbaz

NBA API wrapper written in Zig.

I've already been using my own NBA API wrapper (written in Go) that
powers the backend of [rthoops.net](https://rthoops.net) for awhile now, but i wanted to release the
core functionality as a CLI tool and decided to do it in Zig for
fun and learning purposes.

## Requirements

- Zig 0.15.x (tested with 0.15.2)

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/eexwhyzee/nbaz/main/install.sh | bash
```

## Usage

```sh
nbaz <command> [options]
```

## Commands

- `scoreboard --date YYYYMMDD`
- `boxscore --game-id GAME_ID`
- `playbyplay --game-id GAME_ID`
- `shotchart --game-id GAME_ID`
- `refs --game-id GAME_ID`

## Output Formats

- JSON (default)
- Table (supported for `scoreboard`)

Use: `--format json|table`

## Examples

```sh
# Daily scoreboard
nbaz scoreboard --date 20260201

# Scoreboard as a table
nbaz --format table scoreboard --date 20260201

# Boxscore for a game
nbaz boxscore --game-id 0022500703

# Play-by-play for a game
nbaz playbyplay --game-id 0022500703

# Shot chart
nbaz shotchart --game-id 0022500703

# Ref stats
nbaz refs --game-id 0022500703

```

## License

MIT. See `LICENSE`.

## Development

```sh
# Build locally
zig build

# Run tests
zig build test
```
