# Settings string format (FVX 1.6.2, settings version 428)

The Randomizer engine describes all its options in one settings string: the version `428` followed by standard
base64 of a fixed byte layout. `src/fvx_settings.lua` encodes and decodes it in plain Lua (option schema,
`defaults()`, `encode`, `decode`); the three presets in `src/presets.lua` round-trip byte-identically.
The codec is written from the layout only and contains no engine code.

## Byte layout

| Bytes | Content |
| --- | --- |
| 0-68 | 69 option bytes (below) |
| 69 | Length `n` of the ROM name (we always write 0) |
| 70..70+n-1 | ROM name, ASCII (kept on decode, empty on encode by default) |
| next 4 | CRC32 (IEEE) of everything before it, big-endian |
| last 4 | Zero padding |

Option bytes: most options are single bits; an enum is one bit per choice (exactly one set; decode takes the
first set bit in engine order, refuses two, and picks the first choice when none is set). Exceptions:

| Bytes | Content |
| --- | --- |
| 5-10 | Three custom starters, 16 bit little-endian each |
| 11, 42, 43, 52 | Small counters packed beside flags (guaranteed moves minus 2 in bits 6-7, additional trainer Pokemon 3 bits each, Elite Four count 3 bits, minimum catch rate level minus 1 in bits 3-5) |
| 12, 22, 24 | Bit 7 force-good-damaging flag, bits 0-6 percentage |
| 14, 38, 40, 45, 49 | Level modifiers, stored minus 28 as a signed byte (range -100 to 155) |
| 30-33 | Pokemon limit: bit 0 allow evolutionary relatives, bits 1-7 generations 1-7 (little-endian, only byte 30 is used) |
| 34-37 | Misc tweaks, one bit per tweak, big-endian (bit n sits in byte 37 - n/8) |
| 46, 47 | Generation to update base stats / moves to |
| 48 | Selected exp curve: 0 medium fast, 1 erratic, 2 fluctuating, 3 medium slow, 4 fast, 5 slow |
| 54 | Single starter type: 0 none, otherwise type index + 1 (normal = 1 .. fairy = 18) |
| 58-60 | Starter BST limits, 12 bits each (byte 58 holds the high nibbles) |
| 66 | "Make evolutions easier" level (7 bits) |
| 68 | Random buff/nerf maximum percentage |

Wild randomisation is stored inverted (bit 0 of byte 15 set = off). Unknown misc tweak bits (26-31) are kept as
`misc_tweaks_other` so decode followed by encode does not lose them. The schema in `M.groups` carries the
byte/bit location of every option (`at`), the defaults, ranges, generations and dependencies (`requires`).

A fresh engine `Settings` has no exp curve and no ROM name until a ROM is loaded, so `encode(defaults())` uses
medium fast and an empty name; everything else follows the field initialisers.
