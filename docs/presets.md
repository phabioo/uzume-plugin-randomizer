# Presets

At a glance: the three presets of the plugin are settings strings of the Universal Pokémon Randomizer FVX (GPL-3.0), engine version 1.6.2, settings version 428. They live in `src/presets.lua`, keyed by settings version. Uzume adds the fourth entry, "Custom" (paste a string), itself.

## How the strings were made

Each string is the output of the engine's own `Settings#toString()`: the three-digit settings version followed by base64 data. A throwaway program (not part of this repository) set the options below on a fresh `Settings` object, printed the string, and checked that `Settings.fromString(s).toString()` returns the same string. No engine code or binary is in this repository. When the engine gets a new settings version, new strings are generated the same way and added under the new version key; older versions stay, because a variant pins the engine version it was built with.

All presets leave the generation limits, base stats (except Chaos), experience curves, palettes, type effectiveness, shop prices, the trainer and move names, and the misc tweaks at the engine defaults. They are not tied to one game, so the engine applies them to whichever generation it is given and ignores options the game does not have.

## Nuzlocke friendly

"Fair start, game stays finishable." Starters are random basic Pokémon with two evolutions, no legendaries, with a base stat total of at most 400. Wild Pokémon are random, one replacement per named location, of similar strength, with no wild legendaries. Static encounters are replaced by Pokémon of similar strength and main-game legendaries stay limited. Trainers are random with Pokémon of similar strength, no legendaries, no early Wonder Guard, no evolved forms before their time; the rival keeps the starter line. Impossible evolutions become possible (including estimated levels for evolutions that need an item or trade), and time-based evolutions are removed. In-game trades give random Pokémon. Items, moves, abilities, base stats and types are not changed.

## Classic

"Creatures and items shuffled." Starters are random Pokémon with two evolutions. Wild Pokémon are random per encounter set, no wild legendaries. Static encounters are replaced by matching Pokémon. Trainers are random without legendaries or early Wonder Guard; the rival keeps the starter line. Impossible evolutions become possible. In-game trades give random Pokémon. Field items are shuffled and pickup items are random without bad items. Base stats, types, moves and abilities are unchanged.

## Chaos

"Everything that can change." Types are completely random, base stats are random, abilities are randomized, evolutions are random with adjusted evolution levels, and impossible evolutions become possible. Starters are completely random (alternate forms allowed, random held items without bad ones). Wild Pokémon are random per encounter set with alternate forms and random held items. Static encounters are completely random. Trainers are random, with alternate forms, legendaries allowed and sensible random held items. Movesets are completely random with two guaranteed moves at the start; move power, accuracy, PP and type are randomized. TMs and tutor moves are random (field-move TMs and tutors are kept), compatibility is completely random and every Pokémon can learn the HMs. In-game trades randomize given and requested Pokémon. Field, shop and pickup items are random without bad items, and evolution items are guaranteed in the shops.

## Engine version

FVX 1.6.2 (`Version.LATEST`), settings version 428 (`Settings.VERSION`), read from the engine clone at commit a3cf6f5. Strings of a different settings version are not valid for this engine.
