# Architecture

At a glance: the plugin supplies data; Uzume 0.21 does the work. At load it calls `uz.variants.register` once (engine `randomizer`, the three built-in presets plus the person's own, the supported games), shows a small status card in the game detail and offers an options editor on the `screen` slot. Dialogs, variant list, builds, progress and the New run section are drawn by Uzume. The plugin never randomizes anything and never sees what was randomized.

## Modules (`src/`, bundled into `plugin/main.lua` by `tools/bundle.lua`)

- `main`: logs, loads the own presets, registers presets and games (a failed call is logged, not fatal), routes UI actions, subscribes to `detail.game`, `reloaded` and the app events `store.changed` / `store.conflict`.
- `editor`: the options editor. Builds the `screen` tree from the schema `fvx_settings.groups` and the editor state; changes the state for an action (`set:<option id>`, pasted string). Pure: no `uz` calls.
- `own_presets`: the person's own presets in `uz.store` and the registration with Uzume.
- `fvx_settings`: codec and option schema of the settings string (`docs/settings-format.md`).
- `presets`: settings strings keyed by settings version, preset order. Labels and hints come from `i18n/` at registration time.
- `games`: the supported-games table and the matcher.
- `card`: builds the `detail` tree (section, status badge, one line, slot note; for supported games also the engine line from `uz.variants.engine()` and a list of the user's variants from `uz.variants.list()`: name and state only, at most 5, never seeds, settings, presets or slots; both calls are optional and guarded). `main` refreshes the card on the host event `variants.state`.

## Options editor (screen slot)

Opened by the button "Edit options…" on the detail card (`uz.ui.open("screen")`) or from Settings › Plugins. Top to bottom: a "Start from" select (default settings, the built-in presets, own presets), one tab per schema group (only the selected tab's options are in the tree, the other pages are empty columns), the settings string in a mono textarea, the name field with "Save as preset" (plus "Save changes" and "Delete" while an own preset is edited) and the list of own presets.

- Controls: bool = toggle; enum = segmented (2 to 3 choices, no `requires`) or select; int = select (percent and level options in steps of 5, base stat total limits in steps of 50 with "No limit"; the current value is always offered); the custom starter numbers are a textfield. An option whose `requires` is not met is disabled. Options that only apply to some generations carry "Only Gen n" below them; the engine ignores options a game does not have.
- The textarea always shows `encode(state)`. Editing it and pausing decodes the text: valid replaces all options, invalid shows the decode error and leaves the options alone.
- Texts: `group_<id>` (tab), `sec_<name>` (small headings, see `editor.SECTIONS`), `opt_<id>` (label), `opt_<id>_<choice>` or the shared `choice_<choice>` (enum choices; starter type: `type_<name>`). State lives only while the plugin runs; saved presets are the only thing kept.

## Own presets (store key `presets`)

`uz.store` key `presets` holds an array of `{ id = "own-<n>", name, settings }` (settings = the `428...` string), at most 29, so with the three built-ins Uzume's limit of 32 is met. Writes carry the revision that was read. On `conflict` the store is read again, the editor state stays and a toast says the presets changed on another PC (the attempted version stays as a conflict copy in the store; the next save replaces it). `too_large` and `quota_exceeded` give a toast. The app events `store.changed` and `store.conflict` (source `app`) reload and register again. After every change `uz.variants.register` runs again with the built-ins and the own presets (label = name, hint = "Your own preset"), so Randomize and New run list them. Without `uz.store` (older apps) saving is hidden and the editor only builds and copies the string.

## Game code mapping (assumption)

Codes are the text identifiers that Uzume reads from the game file and sends as `code` in `detail.game` (server `internal/hub/gamecode.go`). The table follows the engine's supported ROM list (its `gen1` to `gen7` offset files) and maps each entry to that format:

- gb, gbc: the header title at 0x134, as Uzume reads it (11 characters when the CGB flag is set, else 16). Gen 1: `POKEMON RED`, `POKEMON BLUE`, `POKEMON GREEN`, and `POKEMON YEL*` for Yellow (CGB-flagged, so cut to 11 characters; listed for gb and gbc because the system Uzume files it under is not verified). Gen 2: `POKEMON_GLD`, `POKEMON_SLV`, `PM_CRYSTAL`. The Gen 2 titles are not in the engine files (it uses the 4-character code at 0x13F); they come from the well-known cartridge headers and need a check against a real dump.
- gba, nds: the 4-character game code, as in the engine files (all language versions).
- 3ds: the 16-digit program ID of the base game (NCCH header), as in the engine files.

Codes are matched like manifest globs (case-insensitive, `*`, `?`). The manifest lists the systems without codes so the detail card can also say "Not supported" for other games.
