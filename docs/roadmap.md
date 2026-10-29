# Roadmap

Status: v0.2.0 (status card with engine state and variants of the game); v0.1.1 (API namespace `uz`, falls back to `fb` on older apps); v0.1.0 is implemented against the Uzume 0.21 API contract (`uz.variants.register`, permission `variants.build`) and a fake `uz`; not yet tried in a real Uzume 0.21. Part of Uzume milestone 0.21 "Randomizer" ([Uzume roadmap](https://github.com/phabioo/uzume/blob/main/docs/roadmap.md), [ADR 0031](https://github.com/phabioo/uzume/blob/main/docs/adr/0031-game-variants-and-randomizer.md)).

## Open work

Open work is tracked as issues: [issues](https://github.com/phabioo/uzume-plugin-randomizer/issues) and the [milestones](https://github.com/phabioo/uzume-plugin-randomizer/milestones).

## Before this plugin

These come first in Uzume and are not built here:

- Spike: determinism of the engine per system and a 3DS LayeredFS folder in the slot's Azahar dir.
- Game variants with their own save slots, the tools catalog (the server offers the engine like cores), 3DS updates, and the variant build permission for signed official plugins.

## v0.1 (done, against the contract)

- Manifest with the permissions `ui` and `variants.build`, detail slot, no run settings (Uzume draws the run section).
- Presets as settings strings per settings version: Nuzlocke friendly, Classic, Chaos (FVX 1.6.2, settings version 428; Custom is added by Uzume); supported games Gen 1 to 7 ([docs/presets.md](presets.md), [docs/architecture.md](architecture.md)).
- Status card in the game detail ("Supported" or "Not supported", "<title> can't be randomized.", slot note).
- i18n English and German; tests with synthetic data and a fake `uz`.

## Next

- Labels are translated at load time; check how Uzume picks the language in the shell context (no issue yet).

## Later

Direction: SoulLink integration lives in the SoulLink repositories (show the variant in the run, read encounters from the variant).
