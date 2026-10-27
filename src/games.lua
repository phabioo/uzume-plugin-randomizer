-- Games the engine supports (main games of Gen 1 to 7), as the text identifiers Uzume reads from the game file
-- (hub gamecode.go): gb/gbc = header title, gba/nds = 4-character game code, 3ds = 16-digit program ID.
-- Codes follow the manifest rule: globs, `*` any run, `?` one character, case-insensitive.
local M = {}

M.games = {
  -- Gen 1: header title at 0x134 (Red, Blue, Green in all language versions; Yellow is CGB-flagged, so Uzume
  -- keeps only 11 characters of its title, hence the glob).
  { system = "gb", codes = { "POKEMON RED", "POKEMON BLUE", "POKEMON GREEN", "POKEMON YEL*" } },
  -- Gen 2: header titles (11 characters, CGB-flagged). Yellow is listed again because Uzume may file it as gbc.
  { system = "gbc", codes = { "POKEMON_GLD", "POKEMON_SLV", "PM_CRYSTAL", "POKEMON YEL*" } },
  -- Gen 3: Ruby, Sapphire, Emerald, FireRed, LeafGreen (all language versions).
  { system = "gba", codes = {
    "AXVD", "AXVE", "AXVF", "AXVI", "AXVJ", "AXVS",
    "AXPD", "AXPE", "AXPF", "AXPI", "AXPJ", "AXPS",
    "BPED", "BPEE", "BPEF", "BPEI", "BPEJ", "BPES", "BPET",
    "BPRD", "BPRE", "BPRF", "BPRI", "BPRJ", "BPRS",
    "BPGD", "BPGE", "BPGF", "BPGI", "BPGJ", "BPGS",
  } },
  -- Gen 4 and 5: Diamond, Pearl, Platinum, HeartGold, SoulSilver, Black, White, Black 2, White 2.
  { system = "nds", codes = {
    "ADAD", "ADAE", "ADAF", "ADAI", "ADAJ", "ADAK", "ADAS",
    "APAD", "APAE", "APAF", "APAI", "APAJ", "APAK", "APAS",
    "CPUD", "CPUE", "CPUF", "CPUI", "CPUJ", "CPUK", "CPUS",
    "IPKD", "IPKE", "IPKF", "IPKI", "IPKJ", "IPKK", "IPKS",
    "IPGD", "IPGE", "IPGF", "IPGI", "IPGJ", "IPGK", "IPGS",
    "IRBD", "IRBF", "IRBI", "IRBJ", "IRBK", "IRBO", "IRBS",
    "IRAD", "IRAF", "IRAI", "IRAJ", "IRAK", "IRAO", "IRAS",
    "IRED", "IREF", "IREI", "IREJ", "IREK", "IREO", "IRES",
    "IRDD", "IRDF", "IRDI", "IRDJ", "IRDK", "IRDO", "IRDS",
  } },
  -- Gen 6 and 7: program ID of the base game (X, Y, Omega Ruby, Alpha Sapphire, Sun, Moon, Ultra Sun, Ultra Moon).
  { system = "3ds", codes = {
    "0004000000055D00", "0004000000055E00", "000400000011C400", "000400000011C500",
    "0004000000164800", "0004000000175E00", "00040000001B5000", "00040000001B5100",
  } },
}

local function glob_match(pattern, text)
  local lua = pattern:upper():gsub("[%^%$%(%)%%%.%[%]%+%-]", "%%%0"):gsub("%*", ".*"):gsub("%?", ".")
  return text:upper():match("^" .. lua .. "$") ~= nil
end

--- True when the game (system, code as in the host event detail.game) is on the list.
function M.supported(system, code)
  if type(system) ~= "string" or type(code) ~= "string" or code == "" then return false end
  for _, entry in ipairs(M.games) do
    if entry.system == system then
      for _, c in ipairs(entry.codes) do
        if glob_match(c, code) then return true end
      end
    end
  end
  return false
end

return M
