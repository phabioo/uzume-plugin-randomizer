# Roadmap

Status: planned, nothing implemented. Part of Uzume milestone 0.22 "Randomizer" ([Uzume roadmap](https://github.com/phabioo/uzume/blob/main/docs/roadmap.md), [ADR 0031](https://github.com/phabioo/uzume/blob/main/docs/adr/0031-game-variants-and-randomizer.md)).

## Before this plugin

These come first in Uzume and are not built here:

- Spike: determinism of the engine per system and a 3DS LayeredFS folder in the slot's Azahar dir.
- Game variants with their own save slots, the tools catalog (the server offers the engine like cores), 3DS updates, and the variant build permission for signed official plugins.

## v0.1

- Manifest with the variant build permission (name open until Uzume defines it).
- Presets as settings strings per engine version: Nuzlocke friendly, Classic, Chaos, Custom (paste a string); all generations from Gen 1 to 7.
- Randomize dialog (10b) and the variant list on the game page (10a), build progress and states (10c, 10d), from the plugin's building blocks where Uzume does not draw them itself.
- Run setting in New run (10e): Off, each person gets their own, same world for everyone; preset; allow own variants.
- Spoiler log only on request (10a-3f, 10f-5f).
- i18n English and German; tests with synthetic data only.

## Later

- SoulLink integration lives in the SoulLink repositories (show the variant in the run, read encounters from the variant).
