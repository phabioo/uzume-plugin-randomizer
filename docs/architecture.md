# Architecture

At a glance: the plugin supplies data; Uzume 0.21 does the work. At load it calls `fb.variants.register` once (engine `randomizer`, three presets, the supported games) and then only shows a small status card in the game detail. Dialogs, variant list, builds, progress and the New run section are drawn by Uzume. The plugin never randomizes anything and never sees what was randomized.

## Modules (`src/`, bundled into `plugin/main.lua` by `tools/bundle.lua`)

- `main`: logs, registers presets and games (a failed call is logged, not fatal), subscribes to the host event `detail.game`.
- `presets`: settings strings keyed by settings version, preset order. Labels and hints come from `i18n/` at registration time.
- `games`: the supported-games table and the matcher.
- `card`: builds the `detail` tree (section, status badge, one line, slot note).

## Game code mapping (assumption)

Codes are the text identifiers that Uzume reads from the game file and sends as `code` in `detail.game` (server `internal/hub/gamecode.go`). The table follows the engine's supported ROM list (its `gen1` to `gen7` offset files) and maps each entry to that format:

- gb, gbc: the header title at 0x134, as Uzume reads it (11 characters when the CGB flag is set, else 16). Gen 1: `POKEMON RED`, `POKEMON BLUE`, `POKEMON GREEN`, and `POKEMON YEL*` for Yellow (CGB-flagged, so cut to 11 characters; listed for gb and gbc because the system Uzume files it under is not verified). Gen 2: `POKEMON_GLD`, `POKEMON_SLV`, `PM_CRYSTAL`. The Gen 2 titles are not in the engine files (it uses the 4-character code at 0x13F); they come from the well-known cartridge headers and need a check against a real dump.
- gba, nds: the 4-character game code, as in the engine files (all language versions).
- 3ds: the 16-digit program ID of the base game (NCCH header), as in the engine files.

Codes are matched like manifest globs (case-insensitive, `*`, `?`). The manifest lists the systems without codes so the detail card can also say "Not supported" for other games.
