--[[
  rr_logger.lua  -  Live progress logger for Pokemon Radical Red (v4.1) on mGBA 0.10+
  ------------------------------------------------------------------------------------
  Radical Red is a FireRed (BPRE) hack built on CFRU + Dynamic Pokemon Expansion.
  This script polls RAM every few frames, diffs the state and writes:

    <OUT_DIR>/rr_events.jsonl    one JSON event per line (appended, flushed each write)
    <OUT_DIR>/rr_snapshot.json   current full state (overwritten)
    <OUT_DIR>/rr_rom_tables.json name tables plus the ROM raid encounter dump

  Load it in mGBA: Tools > Scripting... > File > Load script. Keep that window open.
  It only READS memory; it never writes to the game.
--]]

---------------------------------------------------------------------------
-- CONFIG (edit me)
---------------------------------------------------------------------------
local CONFIG = {
  OUT_DIR             = "D:/pokemon-adviser/rr-log/", -- "" = folder of this script
  POLL_FRAMES         = 30,    -- overworld: check state every N frames (60 frames = 1 s)
  POLL_FRAMES_BATTLE  = 10,    -- in battle: poll faster for a play-by-play
  SNAPSHOT_EVERY_POLLS= 4,     -- rewrite snapshot at most every N polls (and after events)
  LOG_MONEY           = true,  -- log money_change events
  LOG_BATTLE_DETAIL   = true,  -- log hp_change / move_used / switch events inside battles
  LOG_HELD_ITEMS      = true,  -- log held_item_change events
  RECENT_EVENTS_IN_SNAPSHOT = 25,
  SCAN_CHUNK          = 0x80000, -- bytes of ROM scanned per frame while looking for name tables
}

---------------------------------------------------------------------------
-- RAM addresses (FireRed US 1.0 / BPRE). Sources:
--  pokefirered.sym (pret, symbols branch) and CFRU BPRE.ld (Skeli789).
---------------------------------------------------------------------------
local A = {
  gPlayerPartyCount     = 0x02024029,
  gEnemyPartyCount      = 0x0202402A,
  gEnemyParty           = 0x0202402C,
  gPlayerParty          = 0x02024284,
  gBattleTypeFlags      = 0x02022B4C,
  gBattlersCount        = 0x02023BCC,
  gBattlerPartyIndexes  = 0x02023BCE, -- u16[4]
  gLastUsedMoves        = 0x02023D98, -- u16[4] (gLastMoves in pokefirered)
  gBattleOutcome        = 0x02023E8A,
  gMapHeader            = 0x02036DFC,
  gTrainerBattleOpponent_A = 0x020386AE,
  gMain                 = 0x030030F0,
  gSaveBlock1Ptr        = 0x03005008,
  gSaveBlock2Ptr        = 0x0300500C,
  -- CFRU pins the save blocks here (comments in CFRU include/global.h); used as fallback
  SB1_FIXED             = 0x0202552C,
  SB2_FIXED             = 0x02024588,
  -- CFRU include/new/ram_locs.h (verified: these literals exist in the RR 4.1 ROM)
  gExpandedFlags        = 0x0203B174, -- bitflags for ids 0x900..0x18FF (0x200 bytes)
  gRaidBattleSpecies    = 0x0203E04C, -- u16, written when a den is interacted with
  gRaidBattleStars      = 0x0203E04E, -- u8
  gRaidBattleLevel      = 0x0203E04F, -- u8
}
local MAIN_INBATTLE_OFF = 0x439      -- gMain.inBattle is bit 1 of this byte
local SB1_POS, SB1_LOC, SB1_MONEY, SB1_FLAGS = 0x0000, 0x0004, 0x0290, 0x0EE0
local SB2_NAME, SB2_GENDER, SB2_TID, SB2_PLAYTIME, SB2_KEY = 0x00, 0x08, 0x0A, 0x0E, 0xF20
local FLAG_BADGE01 = 0x820
local FLAG_DYNAMAX_BATTLE = 0x918
local FLAG_RAID_BATTLE    = 0x919
local FIRST_RAID_BATTLE_FLAG = 0x1800 -- + (mapsec - MAPSEC_DYNAMIC) = den already cleared
local MAPSEC_DYNAMIC = 0x57
local MON_SIZE = 100
local RAID_STRUCT_SIZE = 30
local RAID_STAR_COUNT = 7
local RAID_ROW_SIZE = RAID_STAR_COUNT * 8
local RAID_MAPSEC_COUNT = 0xC4 - MAPSEC_DYNAMIC
local HINT_RAID_TABLE = 0x1134C34          -- gRaidsByMapSection (verified RR 4.1)
local HINT_RAID_STARS_BY_BADGES = 0x1147640
local HINT_RAID_LEVEL_RANGES = 0x1147654    -- includes a {0,0} slot for 0 stars
local RAID_ABILITY = {[0]="hidden",[1]="ability_1",[2]="ability_2",[3]="random_1_2",[4]="random_all"}
local RAID_DROP_RATES = {100,80,80,50,50,30,30,25,25,5,4,1}

---------------------------------------------------------------------------
-- Static tables
---------------------------------------------------------------------------
local NATURES = {[0]="Hardy","Lonely","Brave","Adamant","Naughty","Bold","Docile","Relaxed",
  "Impish","Lax","Timid","Hasty","Serious","Jolly","Naive","Modest","Mild","Quiet","Bashful",
  "Rash","Calm","Gentle","Sassy","Careful","Quirky"}
local BADGES = {"Boulder","Cascade","Thunder","Rainbow","Soul","Marsh","Volcano","Earth"}
local TYPES = {[0]="Normal","Fighting","Flying","Poison","Ground","Rock","Bug","Ghost","Steel",
  "???","Fire","Water","Grass","Electric","Psychic","Ice","Dragon","Dark",[0x17]="Fairy"}
local OUTCOMES = {[0]="none",[1]="win",[2]="lose",[3]="draw",[4]="run",[5]="teleported",
  [6]="wild_fled",[7]="caught",[8]="no_safari_balls",[9]="forfeit",[10]="wild_teleported"}
-- Kanto map sections (CFRU include/constants/region_map_sections.h, non-Unbound branch)
local MAPSEC = {
 [0x58]="Pallet Town",[0x59]="Viridian City",[0x5A]="Pewter City",[0x5B]="Cerulean City",
 [0x5C]="Lavender Town",[0x5D]="Vermilion City",[0x5E]="Celadon City",[0x5F]="Fuchsia City",
 [0x60]="Cinnabar Island",[0x61]="Indigo Plateau",[0x62]="Saffron City",[0x63]="Route 4",
 [0x64]="Route 10",[0x7E]="Viridian Forest",[0x7F]="Mt. Moon",[0x80]="S.S. Anne",
 [0x81]="Underground Path",[0x82]="Underground Path",[0x83]="Diglett's Cave",
 [0x84]="Victory Road",[0x85]="Rocket Hideout",[0x86]="Silph Co.",[0x87]="Pokemon Mansion",
 [0x88]="Safari Zone",[0x89]="Pokemon League",[0x8A]="Rock Tunnel",[0x8B]="Seafoam Islands",
 [0x8C]="Pokemon Tower",[0x8D]="Cerulean Cave",[0x8E]="Power Plant",[0x8F]="One Island",
 [0x90]="Two Island",[0x91]="Three Island",[0x92]="Four Island",[0x93]="Five Island",
 [0x94]="Seven Island",[0x95]="Six Island",[0x96]="Kindle Road",[0x97]="Treasure Beach",
 [0x98]="Cape Brink",[0x99]="Bond Bridge",[0x9A]="Three Isle Port",[0x9B]="Sevii Isle 6",
 [0x9C]="Sevii Isle 7",[0x9D]="Sevii Isle 8",[0x9E]="Sevii Isle 9",[0x9F]="Resort Gorgeous",
 [0xA0]="Water Labyrinth",[0xA1]="Five Isle Meadow",[0xA2]="Memorial Pillar",
 [0xA3]="Outcast Island",[0xA4]="Green Path",[0xA5]="Water Path",[0xA6]="Ruin Valley",
 [0xA7]="Trainer Tower",[0xA8]="Canyon Entrance",[0xA9]="Sevault Canyon",[0xAA]="Tanoby Ruins",
 [0xAB]="Sevii Isle 22",[0xAC]="Sevii Isle 23",[0xAD]="Sevii Isle 24",[0xAE]="Navel Rock",
 [0xAF]="Mt. Ember",[0xB0]="Berry Forest",[0xB1]="Icefall Cave",[0xB2]="Rocket Warehouse",
 [0xB3]="Trainer Tower",[0xB4]="Dotted Hole",[0xB5]="Lost Cave",[0xB6]="Pattern Bush",
 [0xB7]="Altering Cave",[0xB8]="Tanoby Chambers",[0xB9]="Three Isle Path",[0xBA]="Tanoby Key",
 [0xBB]="Birth Island",[0xBC]="Monean Chamber",[0xBD]="Liptoo Chamber",[0xBE]="Weepth Chamber",
 [0xBF]="Dilford Chamber",[0xC0]="Scufib Chamber",[0xC1]="Rixy Chamber",
 [0xC2]="Viapois Chamber",[0xC3]="Ember Spa",[0xC4]="Celadon Dept.",
}
for i = 1, 25 do MAPSEC[0x64 + i] = "Route " .. i end

-- Gen 3 (international) character set -> UTF-8
local CHARS = {}
do
  CHARS[0x00] = " "
  for i = 0, 9 do CHARS[0xA1 + i] = tostring(i) end
  for i = 0, 25 do
    CHARS[0xBB + i] = string.char(65 + i)
    CHARS[0xD5 + i] = string.char(97 + i)
  end
  local extra = {[0xAB]="!",[0xAC]="?",[0xAD]=".",[0xAE]="-",[0xAF]="·",[0xB0]="…",
    [0xB1]="\"",[0xB2]="\"",[0xB3]="'",[0xB4]="'",[0xB5]="♂",[0xB6]="♀",[0xB7]="$",
    [0xB8]=",",[0xB9]="x",[0xBA]="/",[0xF0]=":",[0x1B]="é",[0x2D]="&",[0x5C]="(",[0x5D]=")",
    [0x35]="=",[0x36]=";",[0x2E]="+",[0x34]="Lv"}
  for k, v in pairs(extra) do CHARS[k] = v end
end
local ENC = {}
for k, v in pairs(CHARS) do if #v == 1 and ENC[v] == nil then ENC[v] = k end end
ENC["'"] = 0xB4

local function decodeText(s)
  local out = {}
  for i = 1, #s do
    local b = s:byte(i)
    if b == 0xFF then break end
    out[#out + 1] = CHARS[b] or "?"
  end
  return table.concat(out)
end

local function encodeText(str)
  local t = {}
  for i = 1, #str do t[i] = string.char(ENC[str:sub(i, i)] or 0) end
  return table.concat(t)
end

---------------------------------------------------------------------------
-- Tiny JSON encoder
---------------------------------------------------------------------------
local ARRAY_MT = {}
local function arr(t) return setmetatable(t or {}, ARRAY_MT) end
local json
do
  local esc = {['"']='\\"',['\\']='\\\\',['\b']='\\b',['\f']='\\f',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
  local function encStr(s)
    return '"' .. s:gsub('[%c"\\]', function(c)
      return esc[c] or string.format("\\u%04x", c:byte())
    end) .. '"'
  end
  local function isArray(t)
    local n = 0
    for k in pairs(t) do
      if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then return false end
      n = n + 1
    end
    for i = 1, n do if t[i] == nil then return false end end
    return true, n
  end
  local function enc(v)
    local tv = type(v)
    if v == nil then return "null"
    elseif tv == "boolean" then return v and "true" or "false"
    elseif tv == "number" then
      if v ~= v or v == math.huge or v == -math.huge then return "null" end
      if math.type(v) == "integer" then return tostring(v) end
      return string.format("%.4g", v)
    elseif tv == "string" then return encStr(v)
    elseif tv == "table" then
      local arr, n = isArray(v)
      if arr and n > 0 then
        local parts = {}
        for i = 1, n do parts[i] = enc(v[i]) end
        return "[" .. table.concat(parts, ",") .. "]"
      elseif arr then
        return (getmetatable(v) == ARRAY_MT) and "[]" or "{}"
      end
      local keys = {}
      for k in pairs(v) do keys[#keys + 1] = tostring(k) end
      table.sort(keys)
      local parts = {}
      for _, k in ipairs(keys) do
        local val = v[k]; if val == nil then val = v[tonumber(k)] end
        parts[#parts + 1] = encStr(k) .. ":" .. enc(val)
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
  end
  json = enc
end

---------------------------------------------------------------------------
-- Safe memory helpers
---------------------------------------------------------------------------
local function r8(a)  local ok, v = pcall(emu.read8,  emu, a) return ok and v or nil end
local function r16(a) local ok, v = pcall(emu.read16, emu, a) return ok and v or nil end
local function r32(a) local ok, v = pcall(emu.read32, emu, a) return ok and v or nil end
local function rr(a, n)
  local ok, v = pcall(emu.readRange, emu, a, n)
  if ok and type(v) == "string" and #v == n then return v end
  return nil
end
local function u8(s, off)  return s:byte(off + 1) end
local function u16(s, off) return string.unpack("<I2", s, off + 1) end
local function u32(s, off) return string.unpack("<I4", s, off + 1) end
local function hex(n) return n and string.format("0x%X", n) or nil end
local function isEwram(p) return p and p >= 0x02000000 and p < 0x02040000 end
local function isRom(p) return p and p >= 0x08000000 and p < 0x0A000000 end

-- Vanilla flags live in SaveBlock1; CFRU expanded flags 0x900+ are a 0x200-byte
-- bitfield at gExpandedFlags (covers 0x900..0x18FF, including raid-cleared flags).
local function flagGet(id, sb1)
  if not id or id == 0 then return false end
  local addr, bitoff
  if id >= 0x900 then
    local off = id - 0x900
    if off >= 0x1000 then return false end
    addr = A.gExpandedFlags + (off >> 3)
    bitoff = off & 7
  else
    if not sb1 then return false end
    addr = sb1 + SB1_FLAGS + (id >> 3)
    bitoff = id & 7
  end
  local b = r8(addr)
  if not b then return false end
  return ((b >> bitoff) & 1) == 1
end

---------------------------------------------------------------------------
-- Output files
---------------------------------------------------------------------------
local outDir, eventsFh
local frameNo = 0
local recentEvents = {}
local lastErrFrame = -100000

local function scriptDir()
  local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
  src = src:gsub("^@", ""):gsub("\\", "/")
  return src:match("^(.*/)") or "./"
end

local function canWrite(dir)
  local p = dir .. "rr_write_test.tmp"
  local fh = io.open(p, "w")
  if not fh then return false end
  fh:write("ok"); fh:close(); os.remove(p)
  return true
end

local function setupOutDir()
  local d = CONFIG.OUT_DIR or ""
  if d ~= "" then
    d = d:gsub("\\", "/"); if d:sub(-1) ~= "/" then d = d .. "/" end
    if not canWrite(d) and os and os.execute then
      pcall(os.execute, 'mkdir "' .. d:gsub("/", "\\"):gsub("\\$", "") .. '"')
    end
    if canWrite(d) then return d end
    console:log("[rr] Cannot write to " .. d .. " -> using the script folder")
  end
  return scriptDir()
end

local function now()
  return os.date("%Y-%m-%dT%H:%M:%S")
end

local function emit(kind, data)
  local ev = { t = now(), frame = frameNo, ev = kind }
  if data then for k, v in pairs(data) do ev[k] = v end end
  local line = json(ev)
  if eventsFh then
    pcall(function() eventsFh:write(line, "\n"); eventsFh:flush() end)
  end
  recentEvents[#recentEvents + 1] = ev
  while #recentEvents > CONFIG.RECENT_EVENTS_IN_SNAPSHOT do table.remove(recentEvents, 1) end
  console:log("[rr] " .. line)
  return ev
end

local function logError(where, err)
  if frameNo - lastErrFrame > 600 then
    lastErrFrame = frameNo
    console:error("[rr] error in " .. where .. ": " .. tostring(err))
    pcall(emit, "script_error", { where = where, msg = tostring(err) })
  end
end

---------------------------------------------------------------------------
-- ROM name/base-stat tables: found by scanning the ROM for known entries
-- (CFRU/DPE repoint these tables, so fixed addresses are not reliable).
---------------------------------------------------------------------------
local ROM = 0x08000000
local T = { species = nil, moves = nil, abilities = nil, items = nil, baseStats = nil,
            scanDone = false, scanFrom = 0, romSize = 0 }
local nameCache = {}

-- table specs: entries 1 and 2 are known; stride = bytes per entry
local SPECS = {
  { key = "species",   strides = {11},     n1 = "Bulbasaur",   n2 = "Ivysaur",     nameLen = 11 },
  { key = "moves",     strides = {13},     n1 = "Pound",       n2 = "Karate Chop", nameLen = 13 },
  { key = "abilities", strides = {17, 13}, n1 = "Stench",      n2 = "Drizzle",     nameLen = nil },
  { key = "items",     strides = {44},     n1 = "Master Ball", n2 = "Ultra Ball",  nameLen = 14 },
}
for _, s in ipairs(SPECS) do
  s.needles = {}
  for _, variant in ipairs({ s.n1, s.n1:upper() }) do
    local n2 = (variant == s.n1) and s.n2 or s.n2:upper()
    s.needles[#s.needles + 1] = { e1 = encodeText(variant) .. "\255", e2 = encodeText(n2) .. "\255" }
  end
end
local BS_NEEDLE  = string.char(45, 49, 49, 45, 65, 65, 12, 3)   -- Bulbasaur base stats + Grass/Poison
local BS_NEEDLE2 = string.char(60, 62, 63, 60, 80, 80, 12, 3)   -- Ivysaur
-- Known offsets from atendev/pokemon-memory-reader's Radical Red entry (one RR build) - tried first
local HINTS = { species = {0x14042CC}, baseStats = {0x17B98EC}, moves = {0x10EEEDC, 0x10EEEDC - 13} }

local function verifyNameTable(spec, base)
  for _, nd in ipairs(spec.needles) do
    for _, stride in ipairs(spec.strides) do
      local a = rr(ROM + base + stride, #nd.e1)
      local b = rr(ROM + base + 2 * stride, #nd.e2)
      if a == nd.e1 and b == nd.e2 then return stride end
    end
  end
  return nil
end

local function verifyBaseStats(base)
  local z = rr(ROM + base, 28)
  if not z or z ~= string.rep("\0", 28) then return false end
  return rr(ROM + base + 28, 8) == BS_NEEDLE and rr(ROM + base + 56, 8) == BS_NEEDLE2
end

-- Valid-name check: every byte before the 0xFF terminator must be a known glyph,
-- and the name must contain at least one non-space character.
local function validName(raw)
  if not raw then return nil end
  local out, nonSpace = {}, false
  for i = 1, #raw do
    local b = raw:byte(i)
    if b == 0xFF then break end
    local c = CHARS[b]
    if not c then return nil end
    if b ~= 0x00 then nonSpace = true end
    out[#out + 1] = c
  end
  if not nonSpace then return nil end
  return table.concat(out)
end

local function specByKey(key)
  for _, s in ipairs(SPECS) do if s.key == key then return s end end
end

-- How long is the table really? Walk entries 1..maxId and return the highest
-- index with a valid name, stopping after 16 invalid entries in a row.
-- The vanilla FireRed tables (78 abilities, 355 moves, 375 items) are still in
-- the ROM, so this is what lets us prefer the expanded CFRU/Radical Red table.
local SCORE_MAX = { species = 2047, moves = 2047, abilities = 1023, items = 2047 }
local function scoreTable(key, base, stride)
  local spec = specByKey(key)
  local len = spec.nameLen or stride
  local maxId = SCORE_MAX[key]
  local bytes = math.min((maxId + 1) * stride, T.romSize - base)
  local blob = rr(ROM + base, bytes)
  if not blob then return 0 end
  local last, gap = 0, 0
  for id = 1, maxId do
    local off = id * stride
    if off + len > #blob then break end
    if validName(blob:sub(off + 1, off + len)) then last, gap = id, 0
    else gap = gap + 1; if gap >= 16 then break end end
  end
  return last
end

T.candidates = { species = {}, moves = {}, abilities = {}, items = {} }
local function addCandidate(key, base, stride, via)
  local list = T.candidates[key]
  for _, c in ipairs(list) do if c.base == base and c.stride == stride then return end end
  list[#list + 1] = { base = base, stride = stride, via = via }
end

local function tryHints()
  for _, spec in ipairs(SPECS) do
    for _, base in ipairs(HINTS[spec.key] or {}) do
      local stride = verifyNameTable(spec, base)
      if stride then addCandidate(spec.key, base, stride, "hint") end
    end
  end
  for _, base in ipairs(HINTS.baseStats) do
    if verifyBaseStats(base) then T.baseStats = { base = base, via = "hint" } end
  end
end

-- After the full scan: pick, for every name table, the candidate with the most entries.
local function pickTables()
  for _, spec in ipairs(SPECS) do
    local best
    for _, c in ipairs(T.candidates[spec.key]) do
      c.entries = scoreTable(spec.key, c.base, c.stride)
      if not best or c.entries > best.entries then best = c end
    end
    T[spec.key] = best
  end
end

-- scans one chunk; returns true when the whole ROM was scanned.
-- Every matching table is collected (no early stop) so pickTables() can compare them.
local function scanStep()
  if T.scanDone then return true end
  local size = T.romSize
  local from = T.scanFrom
  if from >= size then pickTables() T.scanDone = true return true end
  local len = math.min(CONFIG.SCAN_CHUNK + 64, size - from)
  local chunk = rr(ROM + from, len)
  if chunk then
    for _, spec in ipairs(SPECS) do
      for _, nd in ipairs(spec.needles) do
        local init = 1
        while true do
          local p = string.find(chunk, nd.e1, init, true)
          if not p then break end
          local pos = from + p - 1
          for _, stride in ipairs(spec.strides) do
            local base = pos - stride
            if base >= 0 and verifyNameTable(spec, base) == stride then
              addCandidate(spec.key, base, stride, "scan")
            end
          end
          init = p + 1
        end
      end
    end
    if not T.baseStats then
      local init = 1
      while true do
        local p = string.find(chunk, BS_NEEDLE, init, true)
        if not p then break end
        local base = from + p - 1 - 28
        if base >= 0 and verifyBaseStats(base) then T.baseStats = { base = base, via = "scan" } break end
        init = p + 1
      end
    end
  end
  T.scanFrom = from + CONFIG.SCAN_CHUNK
  if T.scanFrom >= size then pickTables() T.scanDone = true end
  return T.scanDone
end

-- Returns the decoded name, or "#<id>" when the id is outside the table or the
-- bytes there do not decode to a clean name. Returns nil for id 0 (none).
local function tableName(key, id, maxId)
  if not id or id == 0 then return nil end
  local t = T[key]
  if not t then return nil end -- tables not found yet / at all: caller keeps the raw id
  local ck = key .. id
  if nameCache[ck] then return nameCache[ck] end
  local name
  if id <= maxId and (not t.entries or id <= t.entries) then
    local spec = specByKey(key)
    name = validName(rr(ROM + t.base + id * t.stride, spec.nameLen or t.stride))
  end
  name = name or ("#" .. id)
  nameCache[ck] = name
  return name
end
local function speciesName(id) return tableName("species", id, 2047) end
local function moveName(id)    return tableName("moves", id, 2047) end
local function abilityName(id) return tableName("abilities", id, 255) end
local function itemName(id)    return tableName("items", id, 2047) end

local function baseStats(species)
  if not T.baseStats or not species or species == 0 or species > 2047 then return nil end
  local s = rr(ROM + T.baseStats.base + species * 28, 28)
  if not s then return nil end
  return {
    hp = u8(s, 0), atk = u8(s, 1), def = u8(s, 2), spe = u8(s, 3), spa = u8(s, 4), spd = u8(s, 5),
    type1 = u8(s, 6), type2 = u8(s, 7),
    ability1 = u8(s, 0x16), ability2 = u8(s, 0x17), hiddenAbility = u8(s, 0x1A),
  }
end

local function typeName(id)
  return id and TYPES[id] or nil
end

-- Regional forms share a truncated 11-char ROM name with the base species.
-- Qualify them by type when a lower id already uses the same display name.
local function qualifySpecies(id)
  local n = speciesName(id)
  if not n then return nil end
  local bs = baseStats(id)
  if not bs then return n end
  local t1, t2 = typeName(bs.type1), typeName(bs.type2)
  local typ = t1
  if t2 and t2 ~= t1 then typ = t1 .. "/" .. t2 end
  -- Walk a few well-known aliases; otherwise append types on a name collision
  -- with a lower species id (checked cheaply against the cached first use).
  if not T.speciesFirstId then return n end
  local first = T.speciesFirstId[n]
  if not first or first == id then return n end
  if n == "Meowth" and t1 == "Steel" then return "Meowth-Galar" end
  if n == "Meowth" and t1 == "Dark" then return "Meowth-Alola" end
  if n == "Persian" and t1 == "Dark" then return "Persian-Alola" end
  if typ then return n .. " (" .. typ .. ")" end
  return n
end

local function speciesTypes(id)
  local bs = baseStats(id)
  if not bs then return arr() end
  local t = arr()
  t[1] = typeName(bs.type1)
  if bs.type2 and bs.type2 ~= bs.type1 then t[2] = typeName(bs.type2) end
  return t
end

local function buildSpeciesFirstIds()
  T.speciesFirstId = {}
  if not T.species or not T.species.entries then return end
  for id = 1, T.species.entries do
    local n = speciesName(id)
    if n and not n:match("^#") and T.speciesFirstId[n] == nil then
      T.speciesFirstId[n] = id
    end
  end
end

local function parseRaidEntry(off)
  local blob = rr(ROM + off, RAID_STRUCT_SIZE)
  if not blob then return nil end
  local sid, item, ability = string.unpack("<I2I2I1", blob, 1)
  if not sid or sid == 0 or sid > 1375 then return nil end
  local drops = arr()
  for i = 0, 11 do
    local did = u16(blob, 6 + i * 2)
    if did and did ~= 0 then
      drops[#drops + 1] = { item_id = did, item = itemName(did), rate_percent = RAID_DROP_RATES[i + 1] }
    end
  end
  return {
    species_id = sid,
    species = qualifySpecies(sid) or speciesName(sid),
    types = speciesTypes(sid),
    held_item_id = (item ~= 0) and item or nil,
    held_item = (item ~= 0) and itemName(item) or nil,
    ability = RAID_ABILITY[ability] or tostring(ability),
    ability_code = ability,
    drops = drops,
  }
end

local function loadRaidTables()
  local base = HINT_RAID_TABLE
  -- Verify Route 3 (mapsec 0x67, index 16) 1-star: 5 mons, first is Galarian Meowth.
  local slot = base + (0x67 - MAPSEC_DYNAMIC) * RAID_ROW_SIZE + 8
  local ptr, amount = r32(ROM + slot), r16(ROM + slot + 4)
  local off = isRom(ptr) and (ptr - ROM) or nil
  local first = off and r16(ROM + off) or nil
  local ok = (amount == 5 and first == 1208)
  if not ok then
    T.raids = { found = false, reason = "Route 3 1-star signature mismatch",
      hint = hex(base), amount = amount, first_species = first }
    return false
  end
  local dens = arr()
  for i = 0, RAID_MAPSEC_COUNT - 1 do
    local mapsec = MAPSEC_DYNAMIC + i
    local stars, ptrs, nstars = {}, {}, 0
    local uniquePtr = nil
    local shared = true
    for star = 1, RAID_STAR_COUNT - 1 do
      local eoff = base + i * RAID_ROW_SIZE + star * 8
      local p, amt = r32(ROM + eoff), r16(ROM + eoff + 4)
      local roff = isRom(p) and (p - ROM) or nil
      if roff and amt and amt > 0 and amt <= 40 then
        local raids = arr()
        for n = 0, amt - 1 do
          local rec = parseRaidEntry(roff + n * RAID_STRUCT_SIZE)
          if not rec then break end
          raids[#raids + 1] = rec
        end
        if #raids > 0 then
          stars[tostring(star)] = raids
          nstars = nstars + 1
          if uniquePtr == nil then uniquePtr = roff
          elseif uniquePtr ~= roff then shared = false end
        end
      end
    end
    if nstars > 0 then
      dens[#dens + 1] = {
        mapsec = mapsec, mapsec_hex = hex(mapsec), name = MAPSEC[mapsec],
        stars = stars, shared_pool_across_stars = shared,
      }
    end
  end
  local starsByBadges, levelRanges = {}, {}
  local sb = rr(ROM + HINT_RAID_STARS_BY_BADGES, 20)
  if sb then
    for b = 0, 9 do
      starsByBadges[tostring(b)] = arr({ u8(sb, b * 2), u8(sb, b * 2 + 1) })
    end
  end
  local lr = rr(ROM + HINT_RAID_LEVEL_RANGES, 14)
  if lr then
    for s = 1, 6 do
      levelRanges[tostring(s)] = arr({ u8(lr, s * 2), u8(lr, s * 2 + 1) })
    end
  end
  T.raids = {
    found = true, via = "hint+route3-verify", rom_offset = hex(base),
    den_count = #dens, dens = dens, stars_by_badge_count = starsByBadges,
    level_ranges_by_stars = levelRanges,
    ram = { species = hex(A.gRaidBattleSpecies), stars = hex(A.gRaidBattleStars),
            level = hex(A.gRaidBattleLevel) },
  }
  -- index by mapsec for snapshot / events
  T.raidsByMapsec = {}
  for _, d in ipairs(dens) do T.raidsByMapsec[d.mapsec] = d end
  return true
end

local function denPool(mapsec)
  return T.raidsByMapsec and T.raidsByMapsec[mapsec] or nil
end

local function raidMonFromRam(s)
  local sid = s.raid_species
  if not sid or sid == 0 then return nil end
  local rec = { species_id = sid, species = qualifySpecies(sid) or speciesName(sid),
    types = speciesTypes(sid), stars = s.raid_stars, level = s.raid_level }
  local pool = denPool(s.mapsec)
  local starKey = s.raid_stars and tostring(s.raid_stars) or nil
  local list = pool and starKey and pool.stars and pool.stars[starKey]
  if list then
    for _, e in ipairs(list) do
      if e.species_id == sid then
        rec.ability = e.ability
        rec.ability_code = e.ability_code
        rec.held_item = e.held_item
        rec.drops = e.drops
        break
      end
    end
  end
  return rec
end

---------------------------------------------------------------------------
-- Pokemon parsing. CFRU stores party data UNENCRYPTED in fixed order
-- (Growth, Attacks, EVs, Misc) - see CFRU include/pokemon.h struct Pokemon.
-- Vanilla Gen 3 encryption (PID^OTID, order PID%24, checksum) is supported
-- as an automatic fallback, in case a build re-enables it.
---------------------------------------------------------------------------
local ORDERS = { -- index into {G,A,E,M} positions: ORDERS[pid%24] = "GAEM" order string
  "GAEM","GAME","GEAM","GEMA","GMAE","GMEA","AGEM","AGME","AEGM","AEMG","AMGE","AMEG",
  "EGAM","EGMA","EAGM","EAMG","EMGA","EMAG","MGAE","MGEA","MAGE","MAEG","MEGA","MEAG" }

local function decryptData(raw, pid, otid)
  local key = pid ~ otid
  local words = {}
  local sum = 0
  for i = 0, 11 do
    local w = (u32(raw, 0x20 + i * 4) ~ key) & 0xFFFFFFFF
    words[i + 1] = string.pack("<I4", w)
    sum = sum + (w & 0xFFFF) + (w >> 16)
  end
  local dec = table.concat(words)
  local order = ORDERS[(pid % 24) + 1]
  local sub = {}
  for i = 1, 4 do sub[order:sub(i, i)] = dec:sub((i - 1) * 12 + 1, i * 12) end
  local ordered = sub.G .. sub.A .. sub.E .. sub.M
  return ordered, (sum & 0xFFFF) == u16(raw, 0x1C)
end

local function plausible(species, moves, level)
  if not species or species == 0 or species > 2047 then return false end
  for i = 1, 4 do if moves[i] > 2047 then return false end end
  if level and (level < 1 or level > 100) then return false end
  return true
end

local cryptMode = nil -- "cfru_plain" | "vanilla_encrypted"

local function parseMon(raw, isParty)
  if not raw or #raw < MON_SIZE then return nil end
  local pid, otid = u32(raw, 0), u32(raw, 4)
  if pid == 0 and otid == 0 then return nil end
  local level = isParty and u8(raw, 0x54) or nil

  local function fields(d) -- d = 48 bytes Growth..Misc, offset 0
    return {
      species = u16(d, 0), item = u16(d, 2), exp = u32(d, 4), ppBonuses = u8(d, 8),
      friendship = u8(d, 9), ball = u8(d, 10),
      moves = { u16(d, 12), u16(d, 14), u16(d, 16), u16(d, 18) },
      pp = { u8(d, 20), u8(d, 21), u8(d, 22), u8(d, 23) },
      evs = { u8(d, 24), u8(d, 25), u8(d, 26), u8(d, 27), u8(d, 28), u8(d, 29) },
      metLocation = u8(d, 37), origins = u16(d, 38), ivword = u32(d, 40),
    }
  end

  local plainF = fields(raw:sub(0x21, 0x50))
  local decData, csOk = decryptData(raw, pid, otid)
  local decF = fields(decData)
  local f, mode
  if csOk and plausible(decF.species, decF.moves, level) then
    f, mode = decF, "vanilla_encrypted"
  elseif plausible(plainF.species, plainF.moves, level) then
    f, mode = plainF, "cfru_plain"
  else
    return nil
  end
  cryptMode = cryptMode or mode

  local iv = f.ivword
  local isEgg = ((iv >> 30) & 1) == 1 or ((u8(raw, 0x13) >> 2) & 1) == 1
  local hiddenBit = ((iv >> 31) & 1) == 1
  local mon = {
    pid = pid, otid = otid,
    nickname = decodeText(raw:sub(9, 18)),
    species = f.species, species_name = speciesName(f.species),
    item = f.item, item_name = itemName(f.item),
    exp = f.exp, friendship = f.friendship, ball = f.ball,
    moves = arr(), is_egg = isEgg,
    nature = NATURES[pid % 25],
    shiny = (((otid & 0xFFFF) ~ (otid >> 16) ~ (pid & 0xFFFF) ~ (pid >> 16)) < 8),
    ivs = { hp = iv & 31, atk = (iv >> 5) & 31, def = (iv >> 10) & 31, spe = (iv >> 15) & 31,
            spa = (iv >> 20) & 31, spd = (iv >> 25) & 31 },
    evs = { hp = f.evs[1], atk = f.evs[2], def = f.evs[3], spe = f.evs[4], spa = f.evs[5], spd = f.evs[6] },
    met_location = f.metLocation, met_level = f.origins & 0x7F,
    hidden_ability_flag = hiddenBit,
    _mode = mode,
  }
  for i = 1, 4 do
    if f.moves[i] ~= 0 then
      mon.moves[#mon.moves + 1] = { id = f.moves[i], name = moveName(f.moves[i]), pp = f.pp[i] }
    end
  end
  -- Ability (CFRU GetMonAbility: hidden flag -> hiddenAbility; else PID bit0 picks slot 2 if it exists)
  local bs = baseStats(f.species)
  if bs then
    local ab
    if mode == "cfru_plain" then
      if hiddenBit and bs.hiddenAbility ~= 0 then ab = bs.hiddenAbility
      elseif (pid & 1) == 1 and bs.ability2 ~= 0 then ab = bs.ability2
      else ab = bs.ability1 end
    else
      ab = (hiddenBit and bs.ability2 ~= 0) and bs.ability2 or bs.ability1
    end
    mon.ability = ab; mon.ability_name = abilityName(ab)
    mon.types = { TYPES[bs.type1] or bs.type1 }
    if bs.type2 ~= bs.type1 then mon.types[2] = TYPES[bs.type2] or bs.type2 end
  end
  if isParty then
    local st = u32(raw, 0x50)
    local status = "ok"
    if st & 7 ~= 0 then status = "sleep" elseif st & 0x80 ~= 0 then status = "toxic"
    elseif st & 0x08 ~= 0 then status = "poison" elseif st & 0x10 ~= 0 then status = "burn"
    elseif st & 0x20 ~= 0 then status = "freeze" elseif st & 0x40 ~= 0 then status = "paralysis" end
    mon.level = level; mon.status = status
    mon.hp = u16(raw, 0x56); mon.max_hp = u16(raw, 0x58)
    mon.stats = { atk = u16(raw, 0x5A), def = u16(raw, 0x5C), spe = u16(raw, 0x5E),
                  spa = u16(raw, 0x60), spd = u16(raw, 0x62) }
  end
  return mon
end

local function readParty(addr, count)
  local blob = rr(addr, MON_SIZE * 6)
  local list = {}
  if not blob then return list end
  for i = 0, (count or 6) - 1 do
    local m = parseMon(blob:sub(i * MON_SIZE + 1, (i + 1) * MON_SIZE), true)
    if m then m.slot = i + 1; list[#list + 1] = m end
  end
  return list
end

---------------------------------------------------------------------------
-- State reading
---------------------------------------------------------------------------
local function readState()
  local s = {}
  local sb1 = r32(A.gSaveBlock1Ptr); if not isEwram(sb1) then sb1 = A.SB1_FIXED end
  local sb2 = r32(A.gSaveBlock2Ptr); if not isEwram(sb2) then sb2 = A.SB2_FIXED end
  s.sb1, s.sb2 = sb1, sb2

  local pc = r8(A.gPlayerPartyCount) or 0
  if pc > 6 then pc = 0 end
  s.party = readParty(A.gPlayerParty, pc)
  s.ready = #s.party > 0

  local mainFlags = r8(A.gMain + MAIN_INBATTLE_OFF) or 0
  s.in_battle = ((mainFlags >> 1) & 1) == 1
  s.callback2 = r32(A.gMain + 4)

  -- location
  local loc = rr(sb1 + SB1_POS, 12)
  if loc then
    s.x, s.y = string.unpack("<i2", loc, 1), string.unpack("<i2", loc, 3)
    s.map_group, s.map_num = string.unpack("<i1", loc, 5), string.unpack("<i1", loc, 6)
  end
  s.mapsec = r8(A.gMapHeader + 0x14)
  s.map_name = s.mapsec and MAPSEC[s.mapsec] or nil

  -- badges
  local fb = r8(sb1 + SB1_FLAGS + (FLAG_BADGE01 >> 3)) or 0
  s.badge_bits = fb
  s.badges = arr()
  for i = 0, 7 do if (fb >> i) & 1 == 1 then s.badges[#s.badges + 1] = BADGES[i + 1] end end

  -- money (XOR with SaveBlock2 encryptionKey)
  local m, key = r32(sb1 + SB1_MONEY), r32(sb2 + SB2_KEY)
  if m and key then
    local v = m ~ key
    if v > 9999999 and m <= 9999999 then v = m end
    s.money = v
  end

  -- player & play time
  local p2 = rr(sb2, 0x14)
  if p2 then
    s.player_name = decodeText(p2:sub(1, 8))
    s.player_gender = (u8(p2, SB2_GENDER) == 1) and "female" or "male"
    s.trainer_id = u16(p2, SB2_TID)
    s.play_h, s.play_m, s.play_s = u16(p2, SB2_PLAYTIME), u8(p2, 0x10), u8(p2, 0x11)
    s.play_seconds = s.play_h * 3600 + s.play_m * 60 + s.play_s
    s.play_time = string.format("%d:%02d:%02d", s.play_h, s.play_m, s.play_s)
  end

  -- battle
  if s.in_battle then
    s.battle_flags = r32(A.gBattleTypeFlags) or 0
    s.is_trainer = (s.battle_flags & 0x8) ~= 0
    s.is_double = (s.battle_flags & 0x1) ~= 0
    s.opponent_trainer = s.is_trainer and r16(A.gTrainerBattleOpponent_A) or nil
    s.enemy = readParty(A.gEnemyParty, 6)
    s.outcome = r8(A.gBattleOutcome) or 0
    s.battlers = r8(A.gBattlersCount) or 2
    local idx = rr(A.gBattlerPartyIndexes, 8)
    local lm = rr(A.gLastUsedMoves, 8)
    s.active, s.last_moves = {}, {}
    for b = 0, 3 do
      s.active[b] = idx and u16(idx, b * 2) or nil
      s.last_moves[b] = lm and u16(lm, b * 2) or nil
    end
  else
    s.outcome = r8(A.gBattleOutcome) or 0
  end

  -- Raid den (CFRU). Species/stars/level are set when the den script runs
  -- (Special 0x115+), and stay until the next den or a new calculation.
  s.raid_species = r16(A.gRaidBattleSpecies) or 0
  s.raid_stars   = r8(A.gRaidBattleStars) or 0
  s.raid_level   = r8(A.gRaidBattleLevel) or 0
  s.raid_battle_flag = flagGet(FLAG_RAID_BATTLE, sb1)
  s.dynamax_flag     = flagGet(FLAG_DYNAMAX_BATTLE, sb1)
  if s.mapsec and s.mapsec >= MAPSEC_DYNAMIC then
    s.raid_cleared = flagGet(FIRST_RAID_BATTLE_FLAG + (s.mapsec - MAPSEC_DYNAMIC), sb1)
  end
  s.is_raid = s.in_battle and s.raid_battle_flag and not s.is_trainer
  return s
end

---------------------------------------------------------------------------
-- Summaries for events
---------------------------------------------------------------------------
local function monBrief(m)
  if not m then return nil end
  return { slot = m.slot, species = m.species, name = m.species_name, nickname = m.nickname,
           level = m.level, hp = m.hp, max_hp = m.max_hp }
end
local function partyBrief(list)
  local t = arr()
  for i, m in ipairs(list or {}) do t[i] = monBrief(m) end
  return t
end
local function locBrief(s)
  return { group = s.map_group, num = s.map_num, mapsec = s.mapsec, name = s.map_name, x = s.x, y = s.y }
end
local function moveSet(m)
  local set = {}
  for _, mv in ipairs(m.moves) do set[mv.id] = mv end
  return set
end
local function enemyBrief(list)
  local t = arr()
  for i, m in ipairs(list or {}) do
    t[i] = { slot = m.slot, species = m.species, name = m.species_name, level = m.level,
             hp = m.hp, max_hp = m.max_hp, ability = m.ability_name, ability_id = m.ability,
             item = m.item_name, item_id = (m.item ~= 0) and m.item or nil }
  end
  return t
end

---------------------------------------------------------------------------
-- Diff engine
---------------------------------------------------------------------------
local prev = nil
local battle = nil        -- info about the battle in progress
local lastOutcomeInBattle = 0
local pendingCatch = nil

local function byPid(list)
  local t = {}
  for _, m in ipairs(list or {}) do t[m.pid] = m end
  return t
end

local function partyKey(list)
  local k = {}
  for _, m in ipairs(list or {}) do k[#k + 1] = string.format("%08x", m.pid) end
  return table.concat(k, ",")
end

local function diffBattleDetail(p, s)
  if not CONFIG.LOG_BATTLE_DETAIL or not battle then return end
  -- HP changes on both sides
  local function hpDiff(side, old, new)
    local o = byPid(old)
    for _, m in ipairs(new) do
      local om = o[m.pid]
      if om and om.hp and m.hp and om.hp ~= m.hp then
        emit("hp_change", { side = side, slot = m.slot, species = m.species, name = m.species_name,
          hp = m.hp, max_hp = m.max_hp, delta = m.hp - om.hp })
        if m.hp == 0 and om.hp > 0 then
          emit("fainted", { side = side, slot = m.slot, species = m.species, name = m.species_name,
            level = m.level })
        end
      end
    end
  end
  hpDiff("player", p.party, s.party)
  if p.enemy then hpDiff("enemy", p.enemy, s.enemy) end
  -- switches & moves used (battler 0/2 = player, 1/3 = enemy)
  if p.active and s.active then
    for b = 0, math.min((s.battlers or 2), 4) - 1 do
      local side = (b % 2 == 0) and "player" or "enemy"
      local list = (side == "player") and s.party or s.enemy
      local function monAtSlot(slot)
        for _, m in ipairs(list or {}) do if m.slot == slot + 1 then return m end end
      end
      if s.active[b] ~= p.active[b] and s.active[b] then
        local m = monAtSlot(s.active[b])
        emit("switch_in", { side = side, battler = b, slot = s.active[b] + 1,
          species = m and m.species, name = m and m.species_name, level = m and m.level })
      end
      if s.last_moves[b] and s.last_moves[b] ~= p.last_moves[b] and s.last_moves[b] ~= 0
         and s.last_moves[b] ~= 0xFFFF then
        local m = monAtSlot(s.active[b] or 0)
        emit("move_used", { side = side, battler = b, move = s.last_moves[b],
          move_name = moveName(s.last_moves[b]), by = m and m.species_name, by_species = m and m.species })
      end
    end
  end
end

local function diffParty(p, s)
  local oldBy = byPid(p.party)
  local newBy = byPid(s.party)
  for _, m in ipairs(s.party) do
    local o = oldBy[m.pid]
    if not o then
      local via = "other"
      if pendingCatch and pendingCatch.species == m.species then via = "caught" end
      emit("party_add", { via = via, mon = monBrief(m), nature = m.nature, ability = m.ability_name,
        ability_id = m.ability, item = m.item_name, item_id = (m.item ~= 0) and m.item or nil,
        location = locBrief(s) })
      if via == "caught" then
        pendingCatch = nil
        if battle then battle.catchAdded = true end
      end
    else
      if o.is_egg and not m.is_egg then
        emit("egg_hatched", { mon = monBrief(m), location = locBrief(s) })
      elseif o.species ~= m.species then
        emit((s.in_battle or p.in_battle) and "form_change" or "evolution", {
          from = o.species, from_name = o.species_name, to = m.species, to_name = m.species_name,
          nickname = m.nickname, level = m.level, slot = m.slot })
      end
      if m.level and o.level and m.level > o.level then
        emit("level_up", { slot = m.slot, species = m.species, name = m.species_name,
          nickname = m.nickname, from = o.level, to = m.level, in_battle = s.in_battle })
      end
      local om, nm = moveSet(o), moveSet(m)
      local learned, forgot = arr(), arr()
      for id, mv in pairs(nm) do if not om[id] then learned[#learned + 1] = { id = id, name = mv.name } end end
      for id, mv in pairs(om) do if not nm[id] then forgot[#forgot + 1] = { id = id, name = mv.name } end end
      if #learned > 0 or #forgot > 0 then
        local movesNow = arr()
        for i, mv in ipairs(m.moves) do movesNow[i] = mv.name or mv.id end
        emit("moves_changed", { slot = m.slot, species = m.species, name = m.species_name,
          learned = learned, forgot = forgot, moves = movesNow, in_battle = s.in_battle })
      end
      if CONFIG.LOG_HELD_ITEMS and o.item ~= m.item then
        emit("held_item_change", { slot = m.slot, name = m.species_name, from = o.item_name or o.item,
          to = m.item_name or m.item, from_id = o.item, to_id = m.item, in_battle = s.in_battle })
      end
    end
  end
  for _, o in ipairs(p.party) do
    if not newBy[o.pid] then
      emit("party_remove", { mon = monBrief(o), location = locBrief(s) })
    end
  end
  if partyKey(p.party) ~= partyKey(s.party) then
    emit("party_changed", { party = partyBrief(s.party) })
  end
end

local function battleKind(s, rec)
  if (s and s.is_raid) or (rec and rec.raid) then return "raid" end
  if (s and s.is_trainer) or (rec and rec.trainer) then return "trainer" end
  return "wild"
end

local function raidEventPayload(s)
  local ev = {
    species_id = (s.raid_species ~= 0) and s.raid_species or nil,
    species = nil,
    types = nil,
    stars = (s.raid_stars ~= 0) and s.raid_stars or nil,
    level = (s.raid_level ~= 0) and s.raid_level or nil,
    cleared = s.raid_cleared,
    location = locBrief(s),
  }
  local mon = raidMonFromRam(s)
  if mon then
    ev.species = mon.species
    ev.types = mon.types
    ev.ability = mon.ability
    ev.ability_code = mon.ability_code
    ev.held_item = mon.held_item
    ev.drops = mon.drops
  end
  local pool = denPool(s.mapsec)
  if pool then
    ev.den = pool.name or ev.location and ev.location.name
    ev.shared_pool_across_stars = pool.shared_pool_across_stars
    -- Names/types/ability only (no drop lists) so snapshots stay small.
    local possible = {}
    for star, raids in pairs(pool.stars) do
      local list = arr()
      for i, e in ipairs(raids) do
        list[i] = { species_id = e.species_id, species = e.species, types = e.types, ability = e.ability }
      end
      possible[star] = list
    end
    ev.possible = possible
  end
  return ev
end

local function maybeEmitRaidDen(p, s, reason)
  local cur = s.raid_species or 0
  if cur == 0 and s.raid_stars == 0 and s.raid_level == 0 then return end
  if p and p.raid_species == s.raid_species and p.raid_stars == s.raid_stars
     and p.raid_level == s.raid_level then
    return
  end
  local ev = raidEventPayload(s)
  ev.reason = reason or "den_updated"
  emit("raid_den", ev)
end

local function onBattleStart(s)
  battle = { start_frame = frameNo, trainer = s.is_trainer, double = s.is_double,
             opponent_trainer = s.opponent_trainer, flags = s.battle_flags, raid = s.is_raid }
  lastOutcomeInBattle = 0
  local ev = {
    kind = battleKind(s), double = s.is_double,
    battle_flags = hex(s.battle_flags), trainer_id = s.opponent_trainer,
    opponents = enemyBrief(s.enemy), party = partyBrief(s.party), location = locBrief(s) }
  if s.is_raid or (s.raid_species or 0) ~= 0 then
    ev.raid = raidEventPayload(s)
  end
  emit("battle_start", ev)
end

local function onBattleEnd(p, s)
  local oc = (s.outcome ~= 0) and s.outcome or lastOutcomeInBattle
  local name = OUTCOMES[oc & 0x7F] or tostring(oc)
  local ev = { outcome = name, outcome_code = oc, kind = battleKind(s, battle),
               trainer_id = battle and battle.opponent_trainer,
               seconds = battle and math.floor((frameNo - battle.start_frame) / 59.7275) or nil,
               opponents = enemyBrief(p.enemy), party = partyBrief(s.party) }
  emit("battle_end", ev)
  if oc == 7 then
    local c = battle and battle.catch
    if not c then
      local e = p.enemy and p.enemy[1]
      for _, m in ipairs(p.enemy or {}) do if (m.hp or 0) > 0 then e = m break end end
      if e then c = { species = e.species, name = e.species_name, level = e.level } end
    end
    if c then
      emit("pokemon_caught", { species = c.species, name = c.name, level = c.level,
        location = locBrief(s), added_to_party = (battle and battle.catchAdded) or false,
        note = not (battle and battle.catchAdded) and "not seen joining the party (sent to PC if party full)" or nil })
    end
    pendingCatch = nil
  elseif oc == 2 or oc == 3 then
    emit("whiteout", { location_before = locBrief(p), party = partyBrief(s.party) })
  end
  battle = nil
end

local function diff(p, s)
  -- map change
  if p.map_group ~= s.map_group or p.map_num ~= s.map_num then
    emit("map_change", { from = locBrief(p), to = locBrief(s) })
  end
  maybeEmitRaidDen(p, s, "den_updated")
  -- battle transitions
  if s.in_battle and not p.in_battle then onBattleStart(s) end
  if s.in_battle and s.outcome and s.outcome ~= 0 then
    lastOutcomeInBattle = s.outcome
    if s.outcome == 7 and battle and not battle.catch then
      -- ball succeeded: remember the wild mon (the one with HP left in doubles)
      local e = s.enemy and s.enemy[1]
      for _, m in ipairs(s.enemy or {}) do if (m.hp or 0) > 0 then e = m break end end
      if e then
        battle.catch = { species = e.species, name = e.species_name, level = e.level }
        pendingCatch = { species = e.species }
      end
    end
  end
  if s.in_battle and p.in_battle then diffBattleDetail(p, s) end
  -- party (before battle_end so a capture can be matched after the battle)
  diffParty(p, s)
  if p.in_battle and not s.in_battle then onBattleEnd(p, s) end
  -- badges
  local nb = s.badge_bits & ~p.badge_bits
  for i = 0, 7 do
    if (nb >> i) & 1 == 1 then
      emit("badge_obtained", { badge = BADGES[i + 1], number = i + 1, total = #s.badges,
        location = locBrief(s) })
    end
  end
  -- money
  if CONFIG.LOG_MONEY and p.money and s.money and p.money ~= s.money then
    emit("money_change", { from = p.money, to = s.money, delta = s.money - p.money, in_battle = s.in_battle })
  end
end

---------------------------------------------------------------------------
-- Snapshot
---------------------------------------------------------------------------
local lastSnapshotText = nil
local function writeSnapshot(s, force)
  local party = arr()
  for i, m in ipairs(s.party or {}) do
    local c = {}
    for k, v in pairs(m) do if k:sub(1, 1) ~= "_" then c[k] = v end end
    party[i] = c
  end
  local snap = {
    updated = now(), frame = frameNo, script = "rr_logger.lua v2",
    game = { title = emu:getGameTitle(), code = emu:getGameCode() },
    ready = s.ready, player = s.player_name, gender = s.player_gender, trainer_id = s.trainer_id,
    play_time = s.play_time, money = s.money,
    badges = s.badges, badge_count = #(s.badges or {}),
    location = locBrief(s),
    in_battle = s.in_battle,
    party = party,
    data_mode = cryptMode,
    names_ready = T.scanDone, 
    recent_events = recentEvents,
  }
  if s.in_battle then
    snap.battle = { kind = battleKind(s), double = s.is_double,
      trainer_id = s.opponent_trainer, flags = hex(s.battle_flags), enemy = enemyBrief(s.enemy) }
    if s.is_raid or (s.raid_species or 0) ~= 0 then
      snap.battle.raid = raidEventPayload(s)
    end
  end
  do
    local raid = raidEventPayload(s)
    -- Always include current RAM + the pool for this map, even if the den
    -- hasn't been opened yet (so the adviser can see what it can contain).
    snap.raid = raid
  end
  local text = json(snap)
  -- skip rewrite if only timestamp/frame changed
  local cmp = text:gsub('"frame":%d+', ""):gsub('"updated":"[^"]*"', "")
  if not force and cmp == lastSnapshotText then return end
  lastSnapshotText = cmp
  local fh = io.open(outDir .. "rr_snapshot.json", "w")
  if fh then fh:write(text); fh:flush(); fh:close() end
end

local function writeTablesInfo()
  local info = {}
  for _, k in ipairs({ "species", "moves", "abilities", "items", "baseStats" }) do
    local t = T[k]
    info[k] = t and { rom_offset = hex(t.base), stride = t.stride, via = t.via, entries = t.entries } or "NOT FOUND"
  end
  info.candidates = {}
  for k, list in pairs(T.candidates) do
    local l = arr()
    for i, c in ipairs(list) do l[i] = { rom_offset = hex(c.base), stride = c.stride, via = c.via, entries = c.entries } end
    info.candidates[k] = l
  end
  info.rom_size = T.romSize
  info.sample = { species_1 = speciesName(1), species_4 = speciesName(4), move_1 = moveName(1),
                  ability_1 = abilityName(1), ability_200 = abilityName(200), move_500 = moveName(500),
                  item_1 = itemName(1), item_500 = itemName(500) }
  if T.raids then
    info.raids = T.raids
  end
  local fh = io.open(outDir .. "rr_rom_tables.json", "w")
  if fh then fh:write(json(info)); fh:close() end
  return info
end

---------------------------------------------------------------------------
-- Main loop
---------------------------------------------------------------------------
local initialized = false
local pollsSinceSnap = 0
local nextPoll = 0

local function init()
  outDir = setupOutDir()
  eventsFh = io.open(outDir .. "rr_events.jsonl", "a")
  if eventsFh then eventsFh:setvbuf("no") end
  local ok, sz = pcall(emu.romSize, emu)
  T.romSize = (ok and sz) or 0x2000000
  tryHints()
  initialized = true
  emit("script_start", { out_dir = outDir, game_title = emu:getGameTitle(), game_code = emu:getGameCode(),
                         rom_size = T.romSize })
  console:log("[rr] Writing logs to: " .. outDir)
end

local function poll()
  local s = readState()
  if not s.ready then
    if prev then emit("game_unloaded", { reason = "party empty (title screen / reset?)" }) end
    prev = nil
    return s
  end
  if not prev then
    emit("game_loaded", { player = s.player_name, play_time = s.play_time, badges = s.badges,
      money = s.money, location = locBrief(s), party = partyBrief(s.party), data_mode = cryptMode })
    maybeEmitRaidDen(nil, s, "script_loaded")
    if s.in_battle then onBattleStart(s) end
  elseif s.play_seconds and prev.play_seconds and
         (s.play_seconds < prev.play_seconds or s.play_seconds - prev.play_seconds > 120) then
    emit("state_jump", { from_play_time = prev.play_time, to_play_time = s.play_time,
      note = "save state loaded or time skip; re-baselined", party = partyBrief(s.party),
      location = locBrief(s) })
    battle = nil
    if s.in_battle then onBattleStart(s) end
  else
    diff(prev, s)
  end
  prev = s
  return s
end

local function onFrame()
  frameNo = frameNo + 1
  if not emu then return end
  if not initialized then
    local ok, err = pcall(init)
    if not ok then logError("init", err) return end
  end
  if not T.scanDone then
    local ok, err = pcall(scanStep)
    if not ok then T.scanDone = true logError("scan", err) end
    if T.scanDone then
      nameCache = {}
      pcall(buildSpeciesFirstIds)
      pcall(loadRaidTables)
      local ok2, info = pcall(writeTablesInfo)
      if ok2 then emit("rom_tables", { found = info and info.raids and info.raids.found,
        den_count = info and info.raids and info.raids.den_count,
        raids_offset = info and info.raids and info.raids.rom_offset,
        species = info and info.species, moves = info and info.moves,
        abilities = info and info.abilities, items = info and info.items }) end
    end
  end
  if frameNo < nextPoll then return end
  local ok, res = pcall(poll)
  if not ok then
    logError("poll", res)
    nextPoll = frameNo + CONFIG.POLL_FRAMES
    return
  end
  local s = res
  nextPoll = frameNo + ((s and s.in_battle) and CONFIG.POLL_FRAMES_BATTLE or CONFIG.POLL_FRAMES)
  pollsSinceSnap = pollsSinceSnap + 1
  if pollsSinceSnap >= CONFIG.SNAPSHOT_EVERY_POLLS then
    pollsSinceSnap = 0
    local ok2, err = pcall(writeSnapshot, s, false)
    if not ok2 then logError("snapshot", err) end
  end
end

local function onReset()
  if initialized then pcall(emit, "emulator_reset", nil) end
  prev = nil; battle = nil; pendingCatch = nil
end

if rrLoggerCallbacks then -- reloading the script: drop old callbacks
  for _, id in ipairs(rrLoggerCallbacks) do pcall(callbacks.remove, callbacks, id) end
end
rrLoggerCallbacks = {
  callbacks:add("frame", onFrame),
  callbacks:add("reset", onReset),
  callbacks:add("shutdown", function()
    if eventsFh then pcall(emit, "emulator_shutdown", nil); pcall(eventsFh.close, eventsFh); eventsFh = nil end
    initialized = false; prev = nil; T.scanDone = false; T.scanFrom = 0
    for _, k in ipairs({ "species", "moves", "abilities", "items", "baseStats", "raids", "raidsByMapsec", "speciesFirstId" }) do T[k] = nil end
    T.candidates = { species = {}, moves = {}, abilities = {}, items = {} }
    nameCache = {}
  end),
}
console:log("[rr] rr_logger.lua loaded. Waiting for the game to run...")
