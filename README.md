# Uzume Plugin: Randomizer

Official Uzume plugin that randomizes Pokémon games from Gen 1 to 7 (GB, GBC, GBA, NDS, 3DS) as game variants: Randomize… on the game page and a Randomizer section in New run, where each person gets their own randomized game or everyone plays the same world.

Status: **planned, nothing implemented.** Plan: [docs/roadmap.md](docs/roadmap.md).

Requires Uzume 0.22 (game variants, tools catalog, variant build permission; [ADR 0031](https://github.com/phabioo/uzume/blob/main/docs/adr/0031-game-variants-and-randomizer.md)). Design: sheet 5 "Randomizer" ([`docs/design/uzume/randomizer.md`](https://github.com/phabioo/uzume/blob/main/docs/design/uzume/randomizer.md) in the Uzume repository). The randomizing itself is done by the Universal Pokémon Randomizer FVX (GPL-3.0), which the Uzume server offers to apps as a tool; it is not part of this repository.

Every PR description needs a `## Changelog` section (see `.github/pull_request_template.md`); CI checks it with `tools/changelog.py`, and releases should build their notes from these sections.

License: GPL-3.0-or-later, see [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md). Contributions under the [CLA](CLA.md).

Pokémon and Nintendo are trademarks of their owners. This project is not affiliated with them and contains no game content.
