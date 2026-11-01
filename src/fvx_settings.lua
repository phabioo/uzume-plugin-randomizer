-- Codec for the settings string of the Universal Pokemon Randomizer FVX 1.6.2 (settings version 428).
-- Own implementation from the documented byte layout (docs/settings-format.md); no engine code is used.
--
-- M.groups   ordered option schema, one list per tab of the engine GUI (data-driven, a UI can be generated from it)
-- M.defaults() fresh options table with every default
-- M.encode(opts) -> "428<base64>"        (missing keys are filled with defaults, ints clamped, bad choices defaulted)
-- M.decode(str)  -> opts | nil, code      (codes: bad_input, bad_version, bad_base64, bad_length, bad_checksum, bad_value)
--
-- Option fields: id, kind ("bool" | "enum" | "int"), default, choices (enum ids, in engine order),
-- min/max (what the string can hold), ui_min/ui_max (narrower range the engine GUI offers), gens (generations the
-- option applies to, nil = all), requires ({option_id = value}: only relevant when that option has that value),
-- at (wire location inside the 69 data bytes; not meant for UIs).
local M = {}

M.VERSION = "428"
M.DATA_LENGTH = 69

local DEFAULT_EXP_CURVE = "medium_fast" -- engine leaves it unset until a ROM is loaded; byte 0 is the neutral value
local TYPES = { "normal", "fighting", "flying", "grass", "water", "fire", "rock", "ground", "psychic", "bug",
  "dragon", "electric", "ghost", "poison", "ice", "steel", "dark", "fairy" }

-- ---------------------------------------------------------------- schema builders

local function merge(o, extra)
  if extra then for k, v in pairs(extra) do o[k] = v end end
  return o
end

local function bool(id, byte, bit, extra)
  return merge({ id = id, kind = "bool", default = false, at = { byte = byte, bit = bit } }, extra)
end

-- bits[i] is the bit of `byte` that marks choices[i]
local function enum(id, choices, byte, bits, extra)
  return merge({ id = id, kind = "enum", choices = choices, default = choices[1],
    at = { byte = byte, bits = bits } }, extra)
end

-- at: byte, shift (default 0), bits (default 8), bias (value = raw + bias), signed, size (2 = 16 bit little endian)
local function int(id, min, max, default, at, extra)
  return merge({ id = id, kind = "int", min = min, max = max, default = default, step = 1, at = at }, extra)
end

local function pct(id, byte, extra) -- force-good-damaging percentage, 7 bits
  return int(id, 0, 127, 0, { byte = byte, bits = 7 }, merge({ ui_max = 100 }, extra))
end

local function level(id, byte, extra)
  return int(id, -100, 155, 0, { byte = byte, bias = 28, signed = true }, extra)
end

local function on(default) return { default = default } end

local G3_7 = { 3, 4, 5, 6, 7 }
local G6_7 = { 6, 7 }

-- ---------------------------------------------------------------- groups

local pokemon_traits = {
  enum("base_stats_mod", { "unchanged", "shuffle", "random" }, 1, { 3, 2, 1 }),
  bool("base_stats_follow_evolutions", 1, 0, { requires = { base_stats_mod = "random" } }),
  bool("base_stats_follow_mega_evolutions", 1, 6, { gens = G6_7 }),
  bool("assign_evo_stats_randomly", 1, 7),
  bool("update_base_stats", 1, 5),
  int("update_base_stats_generation", 0, 255, 0, { byte = 46 }, { ui_min = 6, ui_max = 9, requires = { update_base_stats = true } }),
  bool("standardize_exp_curves", 1, 4),
  enum("exp_curve_mod", { "legendaries", "strong_legendaries", "all" }, 41, { 0, 1, 2 },
    { requires = { standardize_exp_curves = true } }),
  -- written as a lookup byte, not as bit flags (see decode/encode)
  { id = "selected_exp_curve", kind = "enum", default = DEFAULT_EXP_CURVE,
    choices = { "medium_fast", "erratic", "fluctuating", "medium_slow", "fast", "slow" },
    at = { byte = 48, lookup = true }, requires = { standardize_exp_curves = true } },

  enum("bst_mod", { "unchanged", "random_buff_nerf", "shuffle", "random" }, 67, { 0, 1, 2, 3 }),
  bool("bst_follow_evolutions", 67, 4),
  bool("bst_shuffle_swap_legendaries", 67, 5, { requires = { bst_mod = "shuffle" } }),
  int("bst_buff_nerf_max_percentage", 0, 255, 0, { byte = 68 }, { ui_max = 50, requires = { bst_mod = "random_buff_nerf" } }),

  enum("species_types_mod", { "unchanged", "random_follow_evolutions", "completely_random" }, 2, { 2, 0, 1 }),
  bool("types_follow_mega_evolutions", 2, 6, { gens = G6_7 }),
  bool("dual_type_only", 2, 7),

  enum("abilities_mod", { "unchanged", "randomize" }, 3, { 0, 1 }, { gens = G3_7 }),
  bool("allow_wonder_guard", 3, 2, { default = true, gens = G3_7, requires = { abilities_mod = "randomize" } }),
  bool("abilities_follow_evolutions", 3, 3, { gens = G3_7 }),
  bool("abilities_follow_mega_evolutions", 3, 7, { gens = G6_7 }),
  bool("ban_trapping_abilities", 3, 4, { gens = G3_7 }),
  bool("ban_negative_abilities", 3, 5, { gens = G3_7 }),
  bool("ban_bad_abilities", 3, 6, { gens = G3_7 }),
  bool("weigh_duplicate_abilities_together", 42, 7, { gens = G3_7 }),
  bool("ensure_two_abilities", 50, 6, { gens = G3_7 }),

  enum("evolutions_mod", { "unchanged", "random", "random_every_level" }, 28, { 0, 1, 7 }),
  bool("evos_similar_strength", 28, 2, { requires = { evolutions_mod = "random" } }),
  bool("evos_same_typing", 28, 3, { requires = { evolutions_mod = "random" } }),
  bool("evos_max_three_stages", 28, 4, { requires = { evolutions_mod = "random" } }),
  bool("evos_force_change", 28, 5, { requires = { evolutions_mod = "random" } }),
  bool("evos_allow_alt_formes", 28, 6, { gens = G6_7 }),
  bool("evos_force_growth", 57, 0),
  bool("evos_no_convergence", 57, 1),
  bool("adjust_evolution_levels", 57, 2),
  bool("change_impossible_evolutions", 0, 0),
  bool("remove_time_based_evolutions", 0, 6),
  bool("make_evolutions_easier", 0, 5),
  int("make_evolutions_easier_level", 0, 127, 40, { byte = 66, bits = 7 },
    { ui_min = 1, ui_max = 55, requires = { make_evolutions_easier = true } }),
  bool("estimate_level_for_evolution_improvements", 0, 7),

  enum("pokemon_palettes_mod", { "unchanged", "random" }, 55, { 0, 1 }, { gens = { 6, 7 } }),
  bool("pokemon_palettes_follow_types", 55, 2, { requires = { pokemon_palettes_mod = "random" } }),
  bool("pokemon_palettes_follow_evolutions", 55, 3, { requires = { pokemon_palettes_mod = "random" } }),
  bool("pokemon_palettes_shiny_from_normal", 55, 4, { requires = { pokemon_palettes_mod = "random" } }),

  enum("type_effectiveness_mod", { "unchanged", "random", "random_balanced", "keep_identities", "inverse" }, 56,
    { 0, 1, 2, 3, 4 }),
  bool("inverse_types_random_immunities", 56, 5, { requires = { type_effectiveness_mod = "inverse" } }),
  bool("update_type_effectiveness", 56, 6),
}

local starters_statics_trades = {
  enum("starters_mod", { "unchanged", "custom", "completely_random", "random_with_two_evolutions", "random_basic" },
    4, { 2, 0, 1, 3, 7 }),
  -- raw index values as stored (index into the game's Pokemon list); the meaning depends on the game
  int("custom_starter_1", 0, 65535, 0, { byte = 5, size = 2 }, { requires = { starters_mod = "custom" } }),
  int("custom_starter_2", 0, 65535, 0, { byte = 7, size = 2 }, { requires = { starters_mod = "custom" } }),
  int("custom_starter_3", 0, 65535, 0, { byte = 9, size = 2 }, { requires = { starters_mod = "custom" } }),
  bool("randomize_starters_held_items", 4, 4),
  bool("ban_bad_random_starter_held_items", 4, 5, { requires = { randomize_starters_held_items = true } }),
  bool("allow_starter_alt_formes", 4, 6, { gens = G6_7 }),
  enum("starters_type_mod", { "none", "fire_water_grass", "triangle", "unique", "single_type" }, 53, { 0, 1, 2, 3, 4 }),
  { id = "starters_single_type", kind = "enum", default = "none", choices = { "none", table.unpack(TYPES) },
    at = { byte = 54, lookup = true }, requires = { starters_type_mod = "single_type" } },
  bool("starters_no_legendaries", 53, 6),
  bool("starters_no_dual_types", 53, 7),
  -- 0 = no limit; 12 bits each
  int("starters_bst_minimum", 0, 4095, 0, { special = "bst_min" }),
  int("starters_bst_maximum", 0, 4095, 0, { special = "bst_max" }),

  enum("static_pokemon_mod", { "unchanged", "random_matching", "completely_random", "similar_strength" }, 19, { 0, 1, 2, 3 }),
  bool("allow_static_alt_formes", 19, 6, { gens = G6_7 }),
  bool("swap_static_mega_evos", 19, 7, { gens = G6_7 }),
  bool("static_level_modified", 63, 5),
  level("static_level_modifier", 49, { requires = { static_level_modified = true } }),
  bool("correct_static_music", 27, 5),

  enum("totem_pokemon_mod", { "unchanged", "random", "similar_strength" }, 44, { 0, 1, 2 }, { gens = { 7 } }),
  enum("ally_pokemon_mod", { "unchanged", "random", "similar_strength" }, 44, { 3, 4, 5 }, { gens = { 7 } }),
  enum("aura_mod", { "unchanged", "random", "same_strength" }, 43, { 3, 4, 5 }, { gens = { 7 } }),
  bool("randomize_totem_held_items", 44, 6, { gens = { 7 } }),
  bool("allow_totem_alt_formes", 44, 7, { gens = { 7 } }),
  bool("totem_levels_modified", 63, 4, { gens = { 7 } }),
  level("totem_level_modifier", 45, { gens = { 7 }, requires = { totem_levels_modified = true } }),

  enum("in_game_trades_mod", { "unchanged", "randomize_given", "randomize_given_and_requested" }, 25, { 6, 1, 0 }),
  bool("randomize_in_game_trades_items", 25, 2),
  bool("randomize_in_game_trades_ivs", 25, 3),
  bool("randomize_in_game_trades_nicknames", 25, 4),
  bool("randomize_in_game_trades_ots", 25, 5),
}

local moves_movesets = {
  bool("randomize_move_powers", 27, 0),
  bool("randomize_move_accuracies", 27, 1),
  bool("randomize_move_pps", 27, 2),
  bool("randomize_move_types", 27, 3),
  bool("randomize_move_category", 27, 4),
  bool("randomize_move_names", 27, 6),
  bool("update_moves", 0, 1),
  int("update_moves_generation", 0, 255, 0, { byte = 47 }, { ui_min = 2, ui_max = 9, requires = { update_moves = true } }),
  bool("update_moves_legacy", 0, 2, { requires = { update_moves = true } }),

  enum("movesets_mod", { "unchanged", "random_prefer_same_type", "completely_random", "metronome_only" }, 11,
    { 2, 1, 0, 3 }),
  bool("start_with_guaranteed_moves", 11, 4),
  int("guaranteed_move_count", 2, 5, 2, { byte = 11, shift = 6, bits = 2, bias = 2 },
    { ui_max = 4, requires = { start_with_guaranteed_moves = true } }),
  bool("reorder_damaging_moves", 11, 5),
  bool("movesets_force_good_damaging", 12, 7),
  pct("movesets_good_damaging_percent", 12, { requires = { movesets_force_good_damaging = true } }),
  bool("block_broken_moveset_moves", 41, 3),
  bool("evolution_moves_for_all", 43, 6),
}

local trainers = {
  enum("trainers_mod", { "unchanged", "random", "distributed", "mainplaythrough", "type_themed",
    "type_themed_elite4_gyms", "keep_themed", "keep_theme_or_primary" }, 13, { 0, 1, 2, 3, 4, 5, 6, 7 }),
  bool("trainers_use_pokemon_of_similar_strength", 29, 0),
  bool("rival_carries_starter_throughout", 29, 1),
  bool("trainers_match_typing_distribution", 29, 2),
  bool("trainers_block_legendaries", 29, 3, on(true)),
  bool("trainers_block_early_wonder_guard", 29, 4, merge(on(true), { gens = G3_7 })),
  bool("swap_trainer_mega_evos", 29, 5, { gens = G6_7 }),
  bool("shiny_chance", 29, 6),
  bool("trainers_avoid_duplicates", 29, 7),
  bool("trainers_use_local_pokemon", 50, 7),
  bool("randomize_trainer_names", 0, 3),
  bool("randomize_trainer_class_names", 0, 4),
  bool("trainers_evolve_their_pokemon", 63, 0),
  level("trainers_evolution_level_modifier", 14, { requires = { trainers_evolve_their_pokemon = true } }),
  bool("trainers_level_modified", 63, 2),
  level("trainers_level_modifier", 38, { requires = { trainers_level_modified = true } }),
  int("elite_four_unique_pokemon_number", 0, 7, 0, { byte = 52, bits = 3 }, { ui_max = 2 }),
  bool("allow_trainer_alt_formes", 41, 6, { gens = G6_7 }),
  int("additional_boss_trainer_pokemon", 0, 7, 0, { byte = 42, shift = 1, bits = 3 }, { ui_max = 5 }),
  int("additional_important_trainer_pokemon", 0, 7, 0, { byte = 42, shift = 4, bits = 3 }, { ui_max = 5 }),
  int("additional_regular_trainer_pokemon", 0, 7, 0, { byte = 43, bits = 3 }, { ui_max = 5 }),
  bool("randomize_held_items_for_boss_trainer_pokemon", 50, 0),
  bool("randomize_held_items_for_important_trainer_pokemon", 50, 1),
  bool("randomize_held_items_for_regular_trainer_pokemon", 50, 2),
  bool("consumable_items_only_for_trainer_pokemon", 50, 3),
  bool("sensible_items_only_for_trainer_pokemon", 50, 4),
  bool("highest_level_only_gets_items_for_trainer_pokemon", 50, 5),
  bool("diverse_types_for_boss_trainers", 61, 0),
  bool("diverse_types_for_important_trainers", 61, 1),
  bool("diverse_types_for_regular_trainers", 61, 2),
  bool("better_boss_trainer_movesets", 61, 3),
  bool("better_important_trainer_movesets", 61, 4),
  bool("better_regular_trainer_movesets", 61, 5),
  enum("battle_style_mod", { "unchanged", "random", "single_style" }, 62, { 0, 1, 2 }),
  enum("battle_style", { "single", "double", "triple", "rotation" }, 62, { 3, 4, 5, 6 },
    { requires = { battle_style_mod = "single_style" } }),
}

local wild = {
  { id = "randomize_wild_pokemon", kind = "bool", default = false, at = { byte = 15, bit = 0, invert = true } },
  enum("wild_zone_mod", { "none", "encounter_set", "map", "named_location", "game" }, 15, { 1, 2, 6, 5, 3 },
    { default = "game", requires = { randomize_wild_pokemon = true } }),
  bool("split_wild_zone_by_encounter_types", 15, 7),
  bool("keep_wild_evolution_families", 15, 4),
  bool("similar_strength_encounters", 16, 1),
  bool("catch_em_all_encounters", 16, 2),
  enum("wild_type_mod", { "none", "random_themes", "keep_primary" }, 17, { 0, 2, 1 }),
  bool("keep_wild_type_themes", 17, 3),
  enum("wild_evolution_mod", { "none", "basic_only", "keep_stage" }, 17, { 4, 5, 6 }),
  bool("use_time_based_encounters", 18, 0, { gens = { 2, 3, 4, 5 } }),
  bool("use_minimum_catch_rate", 18, 1),
  int("minimum_catch_rate_level", 1, 8, 1, { byte = 52, shift = 3, bits = 3, bias = 1 },
    { ui_max = 5, requires = { use_minimum_catch_rate = true } }),
  bool("block_wild_legendaries", 18, 2, on(true)),
  bool("randomize_wild_pokemon_held_items", 18, 3),
  bool("ban_bad_random_wild_pokemon_held_items", 18, 4, { requires = { randomize_wild_pokemon_held_items = true } }),
  bool("balance_shaking_grass", 18, 5, { gens = { 5 } }),
  bool("wild_levels_modified", 63, 3),
  level("wild_level_modifier", 40, { requires = { wild_levels_modified = true } }),
  bool("allow_wild_alt_formes", 41, 7, { gens = G6_7 }),
}

local tms_tutors = {
  enum("tms_mod", { "unchanged", "random" }, 20, { 4, 3 }),
  bool("tm_level_up_move_sanity", 20, 5),
  bool("keep_field_move_tms", 20, 6),
  bool("tms_force_good_damaging", 22, 7),
  pct("tms_good_damaging_percent", 22, { requires = { tms_force_good_damaging = true } }),
  bool("block_broken_tm_moves", 41, 4),
  bool("tms_follow_evolutions", 21, 1),
  enum("tms_hms_compatibility_mod", { "unchanged", "random_prefer_type", "completely_random", "full" }, 20,
    { 2, 1, 0, 7 }),
  bool("full_hm_compat", 21, 0),

  enum("move_tutor_moves_mod", { "unchanged", "random" }, 23, { 4, 3 }, { gens = { 4, 5 } }),
  bool("tutor_level_up_move_sanity", 23, 5, { gens = { 4, 5 } }),
  bool("keep_field_move_tutors", 23, 6, { gens = { 4, 5 } }),
  bool("tutors_force_good_damaging", 24, 7, { gens = { 4, 5 } }),
  pct("tutors_good_damaging_percent", 24, { gens = { 4, 5 }, requires = { tutors_force_good_damaging = true } }),
  bool("block_broken_tutor_moves", 41, 5, { gens = { 4, 5 } }),
  bool("tutor_follow_evolutions", 21, 2, { gens = { 4, 5 } }),
  enum("move_tutors_compatibility_mod", { "unchanged", "random_prefer_type", "completely_random", "full" }, 23,
    { 2, 1, 0, 7 }, { gens = { 4, 5 } }),
}

local items = {
  enum("field_items_mod", { "unchanged", "shuffle", "random", "random_even" }, 26, { 2, 1, 0, 4 }),
  bool("ban_bad_random_field_items", 26, 3),
  enum("shop_items_mod", { "unchanged", "shuffle", "random" }, 39, { 2, 1, 0 }),
  bool("ban_bad_random_shop_items", 39, 3),
  bool("ban_regular_shop_items", 39, 4),
  bool("ban_op_shop_items", 39, 5),
  bool("guarantee_evolution_items", 39, 7),
  bool("guarantee_x_items", 43, 7),
  bool("balance_shop_prices", 64, 0),
  bool("add_cheap_rare_candies_to_shops", 64, 1),
  enum("pickup_items_mod", { "unchanged", "random" }, 51, { 1, 0 }, { gens = G3_7 }),
  bool("ban_bad_random_pickup_items", 51, 2, { gens = G3_7 }),
}

-- Misc tweaks: one flag per tweak. Stored as a big-endian 32-bit value at bytes 34-37, bit n of the value.
-- { id, bit, generations }
local TWEAKS = {
  { "bw_exp_patch", 0, { 1, 2 } }, { "nerf_x_accuracy", 1, { 1 } }, { "fix_crit_rate", 2, { 1 } },
  { "fastest_text", 3, { 1, 2, 3, 4, 5, 6, 7 } }, { "running_shoes_indoors", 4, { 3 } },
  { "randomize_pc_potion", 5, { 1, 3 } }, { "allow_pikachu_evolution", 6, { 1 } },
  { "national_dex_at_start", 7, { 3, 4, 5, 6 } }, { "fast_egg_hatching", 8, { 2, 3, 4, 5, 6, 7 } },
  { "force_challenge_mode", 9, { 5 } }, { "lower_case_pokemon_names", 10, { 1, 2, 3, 4 } },
  { "randomize_catching_tutorial", 11, { 1, 2, 3, 4 } }, { "ban_lucky_egg", 12, { 2, 3, 4, 5, 6, 7 } },
  { "no_free_lucky_egg", 13, { 5 } }, { "ban_big_maniac_items", 14, { 5 } }, { "sos_battles_for_all", 15, { 7 } },
  { "balance_static_levels", 16, { 3, 5 } }, { "retain_alt_formes", 17, { 6, 7 } },
  { "run_without_running_shoes", 18, { 3, 4, 5 } }, { "faster_hp_and_exp_bars", 19, { 4 } },
  { "fast_distortion_world", 20, { 4 } }, { "update_rotom_forme_typing", 21, { 4 } },
  { "disable_low_hp_music", 22, { 5 } }, { "reusable_tms", 23, { 1, 2, 3, 4 } },
  { "forgettable_hms", 24, { 1, 2, 3, 4, 5 } }, { "no_ev_yields", 25, { 3, 4, 5, 6, 7 } },
}

local misc = {
  bool("randomize_intro_mon", 65, 0),
  bool("race_mode", 65, 1),
  bool("ban_irregular_alt_formes", 51, 3, { gens = G6_7 }),
}
for _, t in ipairs(TWEAKS) do
  -- bit n of the big-endian value at bytes 34-37 sits in byte 37 - n // 8
  misc[#misc + 1] = bool("tweak_" .. t[1], 37 - t[2] // 8, t[2] % 8, { gens = t[3] })
end

-- Pokemon limit: GenRestrictions as a little-endian 32-bit value at bytes 30-33. Only bits 0-7 are used.
local limits = {
  bool("limit_pokemon", 65, 3),
  bool("allow_evolutionary_relatives", 30, 0, { default = true, requires = { limit_pokemon = true } }),
}
for gen = 1, 7 do
  limits[#limits + 1] = bool("allow_gen_" .. gen, 30, gen, { default = true, requires = { limit_pokemon = true } })
end
limits[#limits + 1] = bool("ban_premature_evos", 63, 1)
limits[#limits + 1] = bool("limit_main_game_legendaries", 19, 4)
limits[#limits + 1] = bool("limit_600", 19, 5)

M.groups = {
  { id = "pokemon_traits", options = pokemon_traits },
  { id = "starters_statics_trades", options = starters_statics_trades },
  { id = "moves_movesets", options = moves_movesets },
  { id = "trainers", options = trainers },
  { id = "wild", options = wild },
  { id = "tms_tutors", options = tms_tutors },
  { id = "items", options = items },
  { id = "misc", options = misc },
  { id = "limits", options = limits },
}

-- Values the string carries that the GUI has no control for; kept so decode -> encode does not lose them.
-- misc_tweaks_other: bits 26-31 of the misc tweak value (unknown tweaks of newer engines).
local HIDDEN = {
  int("misc_tweaks_other", 0, 63, 0, { byte = 34, shift = 2, bits = 6 }),
}

M.hidden = HIDDEN

local ALL, BY_ID = {}, {}
for _, g in ipairs(M.groups) do
  for _, o in ipairs(g.options) do
    assert(not BY_ID[o.id], "duplicate option " .. o.id)
    BY_ID[o.id] = o
    ALL[#ALL + 1] = o
  end
end
for _, o in ipairs(HIDDEN) do ALL[#ALL + 1] = o end
M.by_id = BY_ID

-- ---------------------------------------------------------------- defaults

function M.defaults()
  local d = { rom_name = "" } -- rom_name: kept from a decoded string, we always write an empty one
  for _, o in ipairs(ALL) do d[o.id] = o.default end
  return d
end

-- ---------------------------------------------------------------- crc32 and base64

local CRC = {}
for i = 0, 255 do
  local c = i
  for _ = 1, 8 do
    if c & 1 == 1 then c = 0xEDB88320 ~ (c >> 1) else c = c >> 1 end
  end
  CRC[i] = c
end

local function crc32(bytes, n)
  local c = 0xFFFFFFFF
  for i = 1, n do c = CRC[(c ~ bytes[i]) & 0xFF] ~ (c >> 8) end
  return c ~ 0xFFFFFFFF
end
M._crc32 = crc32

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_INV = {}
for i = 1, #B64 do B64_INV[B64:byte(i)] = i - 1 end

local function b64_encode(bytes)
  local out, n = {}, #bytes
  for i = 1, n, 3 do
    local a, b, c = bytes[i], bytes[i + 1], bytes[i + 2]
    local v = (a << 16) | ((b or 0) << 8) | (c or 0)
    local c1, c2, c3, c4 = (v >> 18) & 63, (v >> 12) & 63, (v >> 6) & 63, v & 63
    out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
      .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
  end
  return table.concat(out)
end

-- strict standard base64 with padding; nil on any irregularity
local function b64_decode(s)
  if #s == 0 or #s % 4 ~= 0 then return nil end
  local bytes = {}
  for i = 1, #s, 4 do
    local last = i + 3 == #s
    local v, pad = 0, 0
    for j = 0, 3 do
      local ch = s:byte(i + j)
      local x = B64_INV[ch]
      if x then
        if pad > 0 then return nil end
        v = (v << 6) | x
      elseif ch == 61 and last and j >= 2 then
        pad = pad + 1
        v = v << 6
      else
        return nil
      end
    end
    bytes[#bytes + 1] = (v >> 16) & 0xFF
    if pad < 2 then bytes[#bytes + 1] = (v >> 8) & 0xFF end
    if pad < 1 then bytes[#bytes + 1] = v & 0xFF end
  end
  return bytes
end
M._b64_encode, M._b64_decode = b64_encode, b64_decode

-- ---------------------------------------------------------------- encode

local function clamp(v, lo, hi)
  v = math.tointeger(v) or math.tointeger(math.floor(tonumber(v) or 0)) or 0
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function index_of(list, v)
  for i, x in ipairs(list) do if x == v then return i end end
end

-- value of option o in opts, normalised (missing or invalid -> default)
local function value_of(o, opts)
  local v = opts[o.id]
  if o.kind == "bool" then
    if v == nil then return o.default end
    return v and true or false
  elseif o.kind == "enum" then
    if index_of(o.choices, v) then return v end
    return o.default
  else
    if v == nil then return o.default end
    return clamp(v, o.min, o.max)
  end
end

function M.encode(opts)
  opts = opts or {}
  local d = {}
  for i = 1, M.DATA_LENGTH do d[i] = 0 end
  local function put(byte, v) d[byte + 1] = d[byte + 1] | v end

  for _, o in ipairs(ALL) do
    local at, v = o.at, value_of(o, opts)
    if o.kind == "bool" then
      if at.invert then v = not v end
      if v then put(at.byte, 1 << at.bit) end
    elseif o.kind == "enum" then
      local i = index_of(o.choices, v)
      if at.lookup then
        put(at.byte, i - 1)
      else
        put(at.byte, 1 << at.bits[i])
      end
    elseif at.special == "bst_min" then
      put(58, (v >> 8) & 0x0F)
      put(59, v & 0xFF)
    elseif at.special == "bst_max" then
      put(58, (v >> 4) & 0xF0)
      put(60, v & 0xFF)
    elseif at.size == 2 then
      put(at.byte, v & 0xFF)
      put(at.byte + 1, (v >> 8) & 0xFF)
    else
      local raw = v - (at.bias or 0)
      local mask = (1 << (at.bits or 8)) - 1
      put(at.byte, (raw & mask) << (at.shift or 0))
    end
  end

  local name = tostring(opts.rom_name or ""):gsub("[^\32-\126]", "?"):sub(1, 255)
  d[#d + 1] = #name
  for i = 1, #name do d[#d + 1] = name:byte(i) end
  local crc = crc32(d, #d)
  d[#d + 1] = (crc >> 24) & 0xFF
  d[#d + 1] = (crc >> 16) & 0xFF
  d[#d + 1] = (crc >> 8) & 0xFF
  d[#d + 1] = crc & 0xFF
  for _ = 1, 4 do d[#d + 1] = 0 end
  return M.VERSION .. b64_encode(d)
end

-- ---------------------------------------------------------------- decode

function M.decode(str)
  if type(str) ~= "string" then return nil, "bad_input" end
  if str:sub(1, 3) ~= M.VERSION then return nil, "bad_version" end
  local d = b64_decode(str:sub(4))
  if not d then return nil, "bad_base64" end
  local len = #d
  -- 69 data bytes, name length, name, 4 checksum, 4 padding
  if len < M.DATA_LENGTH + 1 + 8 then return nil, "bad_length" end
  local name_len = d[M.DATA_LENGTH + 1]
  if len ~= M.DATA_LENGTH + 1 + name_len + 8 then return nil, "bad_length" end
  local body = len - 8
  local crc = (d[body + 1] << 24) | (d[body + 2] << 16) | (d[body + 3] << 8) | d[body + 4]
  if crc32(d, body) ~= crc then return nil, "bad_checksum" end

  local function byte(i) return d[i + 1] end
  local opts = { rom_name = "" }
  for i = 1, name_len do
    local c = d[M.DATA_LENGTH + 1 + i]
    opts.rom_name = opts.rom_name .. string.char(c)
  end

  for _, o in ipairs(ALL) do
    local at = o.at
    if o.kind == "bool" then
      local v = (byte(at.byte) >> at.bit) & 1 == 1
      if at.invert then v = not v end
      opts[o.id] = v
    elseif o.kind == "enum" then
      if at.lookup then
        local b = byte(at.byte)
        if o.id == "starters_single_type" then
          b = b & 0x1F
          opts[o.id] = (b >= 1 and b <= #TYPES) and o.choices[b + 1] or "none"
        else
          if b + 1 > #o.choices then return nil, "bad_value" end
          opts[o.id] = o.choices[b + 1]
        end
      else
        -- like the engine: the first set bit in choice order wins; none set -> first choice
        local pick, set = 1, 0
        for i, bit in ipairs(at.bits) do
          if (byte(at.byte) >> bit) & 1 == 1 then
            set = set + 1
            if set == 1 then pick = i end
          end
        end
        if set > 1 then return nil, "bad_value" end -- the engine refuses "more than one value chosen"
        opts[o.id] = o.choices[pick]
      end
    elseif at.special == "bst_min" then
      opts[o.id] = ((byte(58) & 0x0F) << 8) + byte(59)
    elseif at.special == "bst_max" then
      opts[o.id] = ((byte(58) & 0xF0) << 4) + byte(60)
    elseif at.size == 2 then
      opts[o.id] = byte(at.byte) | (byte(at.byte + 1) << 8)
    else
      local raw = (byte(at.byte) >> (at.shift or 0)) & ((1 << (at.bits or 8)) - 1)
      if at.signed and raw >= 128 then raw = raw - 256 end
      opts[o.id] = raw + (at.bias or 0)
    end
  end
  return opts
end

return M
