-- ui/national_dex.lua -- compatibility with the national_dex mod.
--
-- g9-gui replaces the POKeDEX listing (ui/pokedex.lua) and the species entry
-- page (ui/dex_entry.lua) with its own FFXII-shaped screens.  The national_dex
-- mod does not register those screens -- it PATCHES the engine's own classes
-- in memory (its src/dexscroll.lua wraps PokedexMenu.new, its src/dexpage.lua
-- patches DexEntryMenu.new/update/draw) -- so both edits land on the same
-- objects and neither mod has to know the other exists.
--
-- WHAT SURVIVES BY CONSTRUCTION.  This mod only ever replaces an INSTANCE's
-- draw and wraps its update, so national_dex's instance-level state and its
-- update wrapper keep running underneath: the 1025-row roster, the SELECT
-- view modes (num / A-Z / SEEN) that reorder self.items, START's search, the
-- entry page's DOWN/UP strip and its LEFT/RIGHT form cycling all work exactly
-- as they do without this mod.  The only thing that changes is the page the
-- player reads them on.
--
-- WHAT THIS FILE ADDS.  Two things the composite needs and neither mod can
-- supply alone:
--
--   * The DATA for the pages g9-gui draws.  national_dex publishes its
--     species/evolution/movelist payload on mod.exports, but that is the ONLY
--     way to reach it -- a peer's files are not readable (mod.find hands back
--     a handle with .exports, and mod:read is sandboxed to a mod's own dir).
--     Every reader here goes through those exports, memoised per id because
--     statsBySpecies deep-copies a whole record and its extras on every call.
--
--   * A page model for the entry screen.  national_dex reuses the engine's
--     `self.page` for its strip (1 = entry, 2 = STATS, 3+ = one section per
--     page) and drives it from DOWN/UP, while the engine's own update still
--     pages the DESCRIPTION with that same field on A/B.   On an entry whose
--     description has more than one page (every cart species keeps its
--     original `\f`-broken text -- the 874 this mod adds are re-wrapped to a
--     single page) the two meanings collide: A would show STATS as "page 2"
--     and the real description page 2 would be unreachable.  ui/dex_entry.lua
--     therefore keeps its OWN two page counters and, on the frame A/B/DOWN/UP
--     is pressed, masks those four keys from the inner update so the two
--     schemes cannot fight.  LEFT/RIGHT is never masked, so form cycling stays
--     national_dex's own.  This file carries the pure helpers that model
--     needs: the section/pagination builders, ported from
--     national_dex's src/dexpage.lua so a page's rows are identical to the ones
--     the GB page would have printed.
--
-- It is entirely optional.  With national_dex absent `installed` is false, the
-- entry screen keeps the vanilla description pager it has always had, and the
-- listing loses only the view-mode tag it never had.
return function(mod, ctx)
  local M = {}

  local Strings
  do
    local ok, value = pcall(require, "src.core.Strings")
    if ok and type(value) == "function" then Strings = value end
  end
  local TypeChart
  do
    local ok, value = pcall(require, "src.battle.TypeChart")
    if ok and type(value) == "table" then TypeChart = value end
  end

  -- The peer handle, exactly as the loader hands it over.  The exports table
  -- is the published read API (src/api.lua); statsBySpecies is the one entry
  -- point that matters here, because the ability rows, the movelist and the
  -- evolution chain all come out of its replies.
  local peer = mod.find and mod.find("national_dex") or nil
  local exports = type(peer) == "table" and type(peer.exports) == "table"
    and peer.exports or nil
  M.id = "national_dex"
  M.version = type(peer) == "table" and peer.version or nil
  M.installed = type(exports) == "table"
    and type(exports.statsBySpecies) == "function"
  M.exports = exports

  -- --------------------------------------------------------------- raw reads
  -- Memoised, `false` standing for "asked, the peer had nothing".  A lookup on
  -- the hot path (draw) must not deep-copy a species record per frame.
  local speciesCache = {}
  function M.species(id)
    if type(id) ~= "string" then return nil end
    local hit = speciesCache[id]
    if hit ~= nil then return hit or nil end
    local found = false
    if M.installed then
      local ok, reply = pcall(exports.statsBySpecies, id)
      if ok and type(reply) == "table" then found = reply end
    end
    speciesCache[id] = found
    return found or nil
  end

  local evolutionCache = {}
  function M.evolutions(id)
    if type(id) ~= "string" then return nil end
    local hit = evolutionCache[id]
    if hit ~= nil then return hit or nil end
    local found = false
    local ask = exports and exports.evolutionsOf
    if type(ask) == "function" then
      local ok, reply = pcall(ask, id)
      if ok and type(reply) == "table" then found = reply end
    end
    evolutionCache[id] = found
    return found or nil
  end

  -- The STATS option national_dex offers (gen1 | modern).  There is no
  -- cross-mod options read (mod.options:get only sees the calling mod's own
  -- bucket), so this comes out of the saved options tree, which is where the
  -- Mod Manager writes every mod's rows.  Guarded and memoised: a missing
  -- SaveData or an unreadable file simply means the peer's own default, gen1.
  local statsMode
  function M.statsMode()
    if statsMode ~= nil then return statsMode end
    statsMode = "gen1"
    local ok, SaveData = pcall(require, "src.core.SaveData")
    if ok and type(SaveData) == "table"
      and type(SaveData.loadOptions) == "function" then
      local ok2, opts = pcall(SaveData.loadOptions)
      if ok2 and type(opts) == "table" then
        local bucket = type(opts.modOptions) == "table"
          and opts.modOptions[M.id] or nil
        local v = type(bucket) == "table" and bucket.stats or nil
        if v == "modern" then statsMode = "modern" end
      end
    end
    return statsMode
  end

  -- ------------------------------------------------------------ pure shaping
  -- Ported from national_dex's src/dexpage.lua so a page this mod draws has
  -- exactly the rows the GB page behind it would have printed.  Kept local
  -- (not exported) because nothing outside this file should depend on their
  -- shape.

  if Strings then
    M.strings = Strings
  else
    M.strings = function(s) return s end
  end
  local translate = M.strings

  -- only a-z are folded: a name's accented and symbol glyphs are ones the deck
  -- page prints as themselves, and Saira has them.
  function M.caps(text)
    if type(text) ~= "string" then return "" end
    return (text:gsub("[a-z]", string.upper))
  end

  function M.prettyForm(form)
    if type(form) ~= "string" then return "" end
    return (form:gsub("_", " "))
  end

  M.TAG = {
    num = "SORT: NUM", alpha = "SORT: A-Z", seen = "SORT: SEEN",
  }

  -- Which view the listing is in, from the item array alone.  national_dex
  -- keeps its `mode` in a closure local and does not expose it, so it is read
  -- back off the shape: the numerical view is the constructor's own array (the
  -- numbers run 1,2,3...), the alphabetical view is sorted by name (with the
  -- still-unseen dash rows parked at the end), and anything else is the
  -- recorded view.  A one-row list reads as numerical, which is what a list
  -- opened in the default mode is.
  function M.listingMode(items)
    if type(items) ~= "table" or #items == 0 then return nil end
    local sequential = true
    for i = 1, #items do
      local num = tonumber(tostring(items[i].num or ""))
      if num ~= i then sequential = false break end
    end
    if sequential then return "num" end
    local previous, sorted = nil, true
    for i = 1, #items do
      local item = items[i]
      local name = type(item) == "table" and item.name or nil
      if type(name) == "string" and name ~= "----------" then
        local key = name:upper()
        if previous and key < previous then sorted = false break end
        previous = key
      end
    end
    if sorted then return "alpha" end
    return "seen"
  end

  -- Type display names come through the engine's chart so they read as the
  -- cart spells them (FIRE, not the mod's own id).
  function M.typeName(id)
    if TypeChart and type(TypeChart.displayName) == "function" then
      local ok, name = pcall(TypeChart.displayName, id)
      if ok and type(name) == "string" then return M.caps(name) end
    end
    return M.caps(id)
  end

  -- `record` -> { stats, hasSplit, total } under the mod's STATS option.
  -- "modern" needs BOTH split fields, exactly as the peer's own page does, so a
  -- record the split never reached degrades to the Gen 1 collapsed-SPC rows.
  local function statBase(record)
    return (type(record) == "table" and record.baseStats) or {}
  end
  local function num(v) return type(v) == "number" and v or 0 end

  function M.statRows(record, mode)
    local base = statBase(record)
    local spAttack, spDefense
    if type(record) == "table" then
      spAttack, spDefense = record.spAttack, record.spDefense
    end
    local split = mode == "modern" and type(spAttack) == "number"
      and type(spDefense) == "number"
    local rows
    if split then
      rows = {
        { "HP", num(base.hp) }, { "ATK", num(base.attack) },
        { "DEF", num(base.defense) }, { "SP. ATK", num(spAttack) },
        { "SP. DEF", num(spDefense) }, { "SPD", num(base.speed) },
      }
    else
      rows = {
        { "HP", num(base.hp) }, { "ATK", num(base.attack) },
        { "DEF", num(base.defense) }, { "SPD", num(base.speed) },
        { "SPC", num(base.special) },
      }
    end
    local total = 0
    for _, row in ipairs(rows) do total = total + row[2] end
    rows[#rows + 1] = { "TOTAL", total }
    return rows
  end

  -- Every ability the species CAN have, { name, hidden } in the peer's order
  -- (ordinary slots first, the hidden one last and flagged).  All of them: the
  -- slots are alternatives a species can turn up with, not a set an individual
  -- owns, which is exactly why the page names all three.
  M.ABILITY_ROWS = 3
  function M.abilityRows(abilities)
    if type(abilities) ~= "table" then return nil end
    local kept = {}
    for index, entry in ipairs(abilities) do
      if type(entry) == "table" and type(entry.name) == "string"
        and entry.name ~= "" then
        kept[#kept + 1] = {
          name = M.caps(entry.name), hidden = entry.hidden and true or false,
          slot = type(entry.slot) == "number" and entry.slot or math.huge,
          index = index,
        }
      end
    end
    if #kept == 0 then return nil end
    table.sort(kept, function(a, b)
      if a.hidden ~= b.hidden then return b.hidden end
      if a.slot ~= b.slot then return a.slot < b.slot end
      return a.index < b.index
    end)
    local rows = {}
    for _, entry in ipairs(kept) do
      if #rows >= M.ABILITY_ROWS then break end
      rows[#rows + 1] = { name = entry.name, hidden = entry.hidden }
    end
    return rows
  end

  -- What a level-0 learn entry prints: PokeAPI records a move a species gets
  -- the moment it EVOLVES as level 0, and "0" would name a level no player can
  -- reach.
  function M.levelText(level)
    if type(level) ~= "number" or level < 1 then return "EVO" end
    return tostring(math.floor(level))
  end

  -- A step in the evolution line, as the token the page prints beside the
  -- name.  Identical rules to the peer's src/dexpage.lua: the default method is
  -- the current way, precedence runs level, item, trade, held item, known move,
  -- time of day, friendship, steps, party, and a method carrying a condition
  -- the token cannot name gets a trailing "?".
  local ITEM_WORD = {
    ["water-stone"] = "WATER", ["fire-stone"] = "FIRE",
    ["thunder-stone"] = "THNDR", ["leaf-stone"] = "LEAF",
    ["moon-stone"] = "MOON", ["sun-stone"] = "SUN", ["ice-stone"] = "ICE",
    ["dusk-stone"] = "DUSK", ["dawn-stone"] = "DAWN",
    ["shiny-stone"] = "SHINY", ["black-augurite"] = "AUGUR",
    ["cracked-pot"] = "POT", ["metal-alloy"] = "ALLOY",
    ["peat-block"] = "PEAT", ["scroll-of-darkness"] = "DARK",
    ["scroll-of-waters"] = "WATER", ["sweet-apple"] = "SWEET",
    ["tart-apple"] = "TART", ["syrupy-apple"] = "SYRUP",
    ["auspicious-armor"] = "AUSPIC", ["malicious-armor"] = "MALIC",
    ["galarica-cuff"] = "CUFF", ["galarica-wreath"] = "WREATH",
    ["unremarkable-teacup"] = "TEACUP",
  }
  local MORE = "?"
  local UNSPOKEN_EXEMPT = {
    trigger = true, text = true, versionGroup = true, isDefault = true,
  }
  local LEVEL_UP = { ["level-up"] = true }
  local USE_ITEM = { ["use-item"] = true }
  local TRADE = { ["trade"] = true }
  local MOVE_TRIGGERS = { ["level-up"] = true, ["use-move"] = true }

  local function defaultMethod(group)
    local methods = type(group) == "table" and group.methods
    if type(methods) ~= "table" then return nil end
    for _, method in ipairs(methods) do
      if method.isDefault then return method end
    end
    return methods[1]
  end

  function M.triggerText(group)
    local method = defaultMethod(group)
    if not method then return nil end
    local token, word, spoken, triggers
    local level = tonumber(method.level)
    if level and level >= 1 then
      token, word = "L" .. math.floor(level), false
      spoken, triggers = { level = true }, LEVEL_UP
    elseif method.trigger == "use-item" and type(method.item) == "string" then
      token, word = ITEM_WORD[method.item] or "ITEM", true
      spoken, triggers = { item = true }, USE_ITEM
    elseif method.trigger == "trade" then
      token, word, spoken, triggers = "TRADE", true, {}, TRADE
    elseif method.heldItem then
      token, word = "HOLD", true
      spoken, triggers = { heldItem = true }, LEVEL_UP
    elseif method.knownMove or method.knownMoveType or method.usedMove then
      token, word = "MOVE", true
      spoken = { knownMove = true, knownMoveType = true, usedMove = true,
        minMoveCount = true }
      triggers = MOVE_TRIGGERS
    elseif type(method.timeOfDay) == "string" and method.timeOfDay ~= "" then
      token, word = method.timeOfDay:upper(), true
      spoken, triggers = { timeOfDay = true }, LEVEL_UP
    elseif method.minHappiness then
      token, word = "HAPPY", true
      spoken, triggers = { minHappiness = true }, LEVEL_UP
    elseif method.minSteps then
      token, word = "WALK", true
      spoken, triggers = { minSteps = true }, LEVEL_UP
    elseif method.partySpecies or method.partyType then
      token, word = "PARTY", true
      spoken, triggers = { partySpecies = true, partyType = true }, LEVEL_UP
    elseif method.trigger == "spin" then
      token, word, spoken, triggers = "SPIN", true, {}, { spin = true }
    else
      return MORE, true
    end
    if not triggers[method.trigger] then return token .. MORE, word end
    for field, value in pairs(method) do
      if value ~= nil and not UNSPOKEN_EXEMPT[field] and not spoken[field] then
        return token .. MORE, word
      end
    end
    return token, word
  end

  -- Every species in one record's family, depth-first under its real parents:
  -- { name, depth, current, trigger }.  `lookup` answers another member's own
  -- evolutionsOf record; a member it cannot answer for is still drawn, because
  -- the edge that reaches it carries the name.
  function M.evolutionLine(evo, lookup)
    local nodes = {}
    if type(evo) ~= "table" or type(evo.id) ~= "string" then return nodes end
    local selfId = evo.id
    local members, isMember = {}, {}
    local function member(id)
      if type(id) ~= "string" or isMember[id] then return end
      isMember[id] = true
      members[#members + 1] = id
    end
    if type(evo.chain) == "table" then
      for _, id in ipairs(evo.chain) do member(id) end
    end
    member(selfId)
    if type(evo.evolvesFrom) == "table" then member(evo.evolvesFrom.id) end
    if type(evo.evolvesInto) == "table" then
      for _, entry in ipairs(evo.evolvesInto) do
        if type(entry) == "table" then member(entry.id) end
      end
    end
    local records = { [selfId] = evo }
    if type(lookup) == "function" then
      for _, id in ipairs(members) do
        if records[id] == nil then
          local ok, found = pcall(lookup, id)
          records[id] = (ok and type(found) == "table") and found or false
        end
      end
    end
    local names, children, parentOf, stepInto = {}, {}, {}, {}
    local function note(id, name)
      if type(id) == "string" and type(name) == "string" and name ~= ""
        and names[id] == nil then names[id] = name end
    end
    local function edge(fromId, toId, name, step)
      if type(fromId) ~= "string" or type(toId) ~= "string" then return end
      note(toId, name)
      if parentOf[toId] ~= nil or fromId == toId then return end
      parentOf[toId] = fromId
      stepInto[toId] = step
      local kids = children[fromId]
      if not kids then kids = {}; children[fromId] = kids end
      kids[#kids + 1] = toId
    end
    for _, id in ipairs(members) do
      local record = records[id]
      if type(record) == "table" then
        note(id, record.name)
        local from = record.evolvesFrom
        if type(from) == "table" then
          note(from.id, from.name)
          edge(from.id, id, record.name, from)
        end
        if type(record.evolvesInto) == "table" then
          for _, entry in ipairs(record.evolvesInto) do
            if type(entry) == "table" then
              edge(id, entry.id, entry.name, entry)
            end
          end
        end
      end
    end
    local visited = {}
    local function visit(id, depth)
      if visited[id] then return end
      visited[id] = true
      local record = records[id]
      local raw = type(record) == "table" and record.name or nil
      if type(raw) ~= "string" or raw == "" then raw = names[id] or id end
      local trigger, word = M.triggerText(stepInto[id])
      nodes[#nodes + 1] = {
        name = M.caps(raw), depth = depth, current = id == selfId or nil,
        trigger = trigger, triggerWord = word or nil,
      }
      for _, kid in ipairs(children[id] or {}) do visit(kid, depth + 1) end
    end
    for _, id in ipairs(members) do
      if not visited[id] and parentOf[id] == nil then visit(id, 1) end
    end
    for _, id in ipairs(members) do
      if not visited[id] then visit(id, 1) end
    end
    return nodes
  end

  -- The row indent for a family's depth, in the suite's pixels.
  M.LINE_STEP = 22
  M.LINE_MAX_DEPTH = 4
  local function lineRows(nodes)
    local rows = {}
    for _, node in ipairs(nodes) do
      local depth = math.min(node.depth, M.LINE_MAX_DEPTH)
      rows[#rows + 1] = {
        text = node.name, right = node.trigger,
        indent = (depth - 1) * M.LINE_STEP, mark = node.current,
      }
    end
    return rows
  end

  -- The sections below the STATS page, in reading order: the family first
  -- (a short page a player walks to on purpose), the movelist after it (the
  -- long one).  A section with no rows produces no section at all.
  local METHOD_SECTIONS = {
    { key = "machine", title = "MACHINE" },
    { key = "egg", title = "EGG" },
    { key = "tutor", title = "TUTOR" },
    { key = "other", title = "OTHER" },
  }

  local function levelUpSection(shaped)
    if type(shaped) ~= "table" then return nil end
    local full = type(shaped.movesFull) == "table" and shaped.movesFull or {}
    local rows = {}
    for _, entry in ipairs(full) do
      if type(entry) == "table" and type(entry.name) == "string"
        and entry.name ~= "" then
        rows[#rows + 1] = {
          text = M.caps(entry.name), right = M.levelText(entry.level),
        }
      end
    end
    if #rows == 0 then return nil end
    return { title = "LEVEL UP", rows = rows }
  end

  function M.moveSections(shaped)
    local out = {}
    if type(shaped) ~= "table" then return out end
    local levelUp = levelUpSection(shaped)
    if levelUp then out[#out + 1] = levelUp end
    local byMethod = type(shaped.movesByMethod) == "table"
      and shaped.movesByMethod or {}
    for _, section in ipairs(METHOD_SECTIONS) do
      local list = type(byMethod[section.key]) == "table"
        and byMethod[section.key] or {}
      local rows = {}
      for _, entry in ipairs(list) do
        if type(entry) == "table" and type(entry.name) == "string"
          and entry.name ~= "" then
          rows[#rows + 1] = { text = M.caps(entry.name) }
        end
      end
      if #rows > 0 then
        out[#out + 1] = { title = section.title, rows = rows }
      end
    end
    return out
  end

  -- Gold's LVL view: the family, then the level-up list, and nothing else.
  --
  -- Deliberately NOT M.moveSections.  The Gen 1 strip shows every method --
  -- MACHINE, EGG, TUTOR and OTHER after the level-up list -- because its page
  -- is a walk-down strip a player deliberately opens.  The peer's Gen 2 LVL
  -- view is a bar slot, and its own page builder shows the evolution line and
  -- the level-up list only (gen2dexlist.lua's M.movePages), because those
  -- other four are 79 to 110 rows nobody walks a dex to read.  This mirrors
  -- that exactly so the two games' LVL views carry the same sections.
  --
  -- The sections come from the SAME builders the Gen 1 strip uses -- the peer
  -- hands src/dexpage.lua's evolutionSections/levelUpSection/paginate to its
  -- Gen 2 arm too -- so the rows are identical; only the page length differs
  -- (14 against 12).
  M.G2_ROWS_PER_PAGE = 14
  function M.g2MovePages(shaped, evo)
    local sections = {}
    if type(evo) == "table" then
      local ok, list = pcall(M.evolutionSections, evo, M.evolutions)
      if ok and type(list) == "table" then
        for _, section in ipairs(list) do sections[#sections + 1] = section end
      end
    end
    local levelUp = levelUpSection(shaped)
    if levelUp then sections[#sections + 1] = levelUp end
    return M.paginate(sections, M.G2_ROWS_PER_PAGE)
  end

  function M.evolutionSections(evo, lookup)
    local out = {}
    if type(evo) ~= "table" then return out end
    local nodes = M.evolutionLine(evo, lookup)
    if #nodes > 1 then
      out[#out + 1] = { title = "EVOLUTION", rows = lineRows(nodes) }
    end
    return out
  end

  -- The strip cut into pages.  ROWS must match national_dex's own
  -- ROWS_PER_PAGE (12): the peer's update clamps self.page against a last page
  -- it computes with ITS number, so a different page length here would strand
  -- the deepest pages of a long movelist -- DOWN would simply stop.
  --
  -- `rowsPerPage` is a parameter because the two generations do not share the
  -- number: Gen 1's page is 144 pixels and shows 12 rows, Gold's dex box is
  -- taller and the peer's Gen 2 arm cuts the SAME sections into 14
  -- (gen2dexlist.lua's PAGE_ROWS = 16-3+1).  Both callers still default to the
  -- Gen 1 count, so nothing below changes.
  M.ROWS_PER_PAGE = 12
  function M.paginate(sections, rowsPerPage)
    local perPage = tonumber(rowsPerPage) or M.ROWS_PER_PAGE
    local pages = {}
    for _, section in ipairs(sections or {}) do
      local rows = section.rows or {}
      local count = math.ceil(#rows / perPage)
      for index = 1, count do
        local page = { title = section.title, index = index, count = count,
          rows = {} }
        for offset = 1, perPage do
          local row = rows[(index - 1) * perPage + offset]
          if not row then break end
          page.rows[offset] = row
        end
        pages[#pages + 1] = page
      end
    end
    return pages
  end

  function M.buildPages(shaped, evo, lookup)
    local sections = M.evolutionSections(evo, lookup)
    for _, section in ipairs(M.moveSections(shaped)) do
      sections[#sections + 1] = section
    end
    return M.paginate(sections)
  end

  -- Everything the entry page needs about one record, built once per id: the
  -- ability rows, the strip's pages, and the counts.  The peer builds the same
  -- thing lazily from its own memo; doing it here means the g9-gui pages are
  -- the peer's pages row for row.
  local infoCache = {}
  local EMPTY = { abilities = false, pages = {}, lastPage = 2 }
  function M.info(record)
    local id = type(record) == "table" and record.id or nil
    if type(id) ~= "string" then return EMPTY end
    local hit = infoCache[id]
    if hit ~= nil then return hit or EMPTY end
    local shaped = M.species(id)
    local evo = M.evolutions(id)
    local info = { abilities = false, pages = {}, lastPage = 2 }
    if shaped then
      info.abilities = M.abilityRows(shaped.abilities) or false
      local ok, pages = pcall(M.buildPages, shaped, evo, M.evolutions)
      info.pages = ok and pages or {}
    end
    info.lastPage = 2 + #info.pages
    infoCache[id] = info
    return info
  end

  -- ------------------------------------------------------- Gen 2 (Gold) pages
  -- The peer's Gen 2 arm (src/gen2dexlist.lua) draws its STAT and LVL pages on
  -- Gold's own tile grid and patches Gold's PokedexMenu class rather than
  -- publishing a page model through mod.exports.  So this file builds the same
  -- two pages from the same published DATA (statsBySpecies / evolutionsOf) and
  -- the same pure builders above, so g9-gui can paint them on its own 540x360
  -- page instead of handing the player back to the cart's 160x144 screen.  The
  -- rows follow the peer's own (gen2dexlist.lua's M.statValues/M.statRows and
  -- M.movePages) because a second opinion about them is how the two screens
  -- would drift.

  -- Gold's records spell the split `baseStats.specialAttack` /
  -- `baseStats.specialDefense`; a Gen 1-shaped record carries a collapsed
  -- `special` with the real split beside it as `spAttack` / `spDefense`.  All
  -- are accepted, in that order, and a record with only the collapsed number
  -- shows it under both Special rows rather than a blank.  The six labels and
  -- the always-present TOTAL are the peer's own.
  M.G2_STAT_ROWS = {
    { "HP", "hp" }, { "ATTACK", "attack" }, { "DEFENSE", "defense" },
    { "SPCL.ATK", "spAttack" }, { "SPCL.DEF", "spDefense" },
    { "SPEED", "speed" },
  }
  function M.g2StatRows(record)
    local base = (type(record) == "table" and record.baseStats) or {}
    local special = base.special
    local top = type(record) == "table" and record or {}
    -- Walked with select rather than over a packed table: the first candidate
    -- is routinely nil (a Gold record has no `special`, a Gen 1 one no
    -- `specialAttack`) and ipairs stops dead on the first hole.
    local function pick(...)
      for index = 1, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "number" then return value end
      end
      return 0
    end
    local values = {
      hp = pick(base.hp), attack = pick(base.attack),
      defense = pick(base.defense), speed = pick(base.speed),
      spAttack = pick(base.specialAttack, top.spAttack, special),
      spDefense = pick(base.specialDefense, top.spDefense, special),
    }
    local rows, total = {}, 0
    for _, row in ipairs(M.G2_STAT_ROWS) do
      local value = values[row[2]] or 0
      rows[#rows + 1] = { row[1], value }
      total = total + value
    end
    rows[#rows + 1] = { "TOTAL", total }
    return rows
  end

  -- The two types the peer's STAT page prints, in the peer's own id->label map
  -- (gen2dexlist.lua's M.TYPE_NAMES): the ROM extractor spells two types
  -- around what the screen shows, and every other id is its own label.
  M.G2_TYPE_NAMES = { PSYCHIC_TYPE = "PSYCHIC", CURSE_TYPE = "???" }
  function M.g2TypeNames(record)
    local types = (type(record) == "table" and record.types) or {}
    local function name(id)
      if type(id) ~= "string" or id == "" then return nil end
      return M.G2_TYPE_NAMES[id] or M.caps(id)
    end
    local first, second = name(types[1]), name(types[2])
    -- PrintMonTypes' .hide_type_2: a single-typed mon carries the same type
    -- twice, and the second name is blanked rather than printed twice.
    if second == first then second = nil end
    return first, second
  end

  -- Everything a Gen 2 STAT or LVL page reads about one species or form, built
  -- once per id (statsBySpecies deep-copies a record and its extras per call,
  -- far too much to pay every frame).  `fallback` is the menu's own registered
  -- record, used when the peer's API has nothing for the id -- the base stats
  -- and typing still draw, only the ability rows and the LVL pages are lost,
  -- exactly the peer's own fallback rule.
  local g2Cache = {}
  local G2_EMPTY = { statRows = {}, abilities = false, movePages = {},
    lastPage = 2 }
  function M.g2Info(id, fallback)
    if type(id) ~= "string" then return G2_EMPTY end
    local hit = g2Cache[id]
    if hit ~= nil then return hit or G2_EMPTY end
    local shaped = M.species(id)
    local record = shaped
    if not record and type(fallback) == "table" then record = fallback end
    local info = { statRows = {}, abilities = false, movePages = {},
      lastPage = 2 }
    if record then
      info.statRows = M.g2StatRows(record)
      info.type1, info.type2 = M.g2TypeNames(record)
      if type(record.abilities) == "table" then
        info.abilities = M.abilityRows(record.abilities) or false
      end
      if shaped then
        local ok, pages = pcall(M.g2MovePages, shaped, M.evolutions(id))
        info.movePages = ok and pages or {}
      end
    end
    info.lastPage = 2 + #info.movePages
    g2Cache[id] = info
    return info
  end

  -- The peer's own formsOf export, memoised like the other reads.  The entry
  -- page offers its form hint from this: a species with one form gets no hint
  -- and the hint names the same list the UP/DOWN keys walk.
  local formsCache = {}
  function M.forms(id)
    if type(id) ~= "string" then return nil end
    local hit = formsCache[id]
    if hit ~= nil then return hit or nil end
    local found = false
    local ask = exports and exports.formsOf
    if type(ask) == "function" then
      local ok, reply = pcall(ask, id)
      if ok and type(reply) == "table" then found = reply end
    end
    formsCache[id] = found
    return found or nil
  end

  -- The action bar the peer's Gen 2 arm installs: the cart's own four words
  -- first, then the two it adds.  That order is load bearing rather than
  -- cosmetic -- the peer dispatches A off the slot index, so a bar listing them
  -- differently would fire the wrong action.  Present only while the peer is
  -- loaded, so an unpatched Gold dex keeps the cart's four.
  M.G2_ACTIONS = { "PAGE", "AREA", "CRY", "PRNT", "STAT", "LVL" }
  function M.g2Actions()
    if M.installed then return M.G2_ACTIONS end
    return nil
  end

  M.translate = translate
  return M
end
