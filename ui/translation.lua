-- ui/translation.lua -- the modern-content translation layer.
--
-- WHAT IT IS FOR.  The translation-mod generator
-- (github.com/thibautbus/gen1recomp-translation-mod-generator) emits a normal
-- gen1recomp mod -- id `translation-<lang>` for Red/Blue/Yellow,
-- `translation-<lang>-gen2` for Gold/Silver/Crystal -- that patches the game's
-- own content registries with the ROM's localized text: dialogue, UI strings,
-- and the names of every Gen 1/2 Pokemon, move, item, trainer and status.  It
-- knows nothing about the EXPANDED dex this suite's peer mod national_dex adds
-- (species 152+, and the moves/items/abilities those mons bring).  So a player
-- running the Spanish translation sees Spanish everywhere except the modern
-- content, which stays English -- the seam this module closes.
--
-- WHAT IT DOES.  At load, before the content registries freeze, it
--   1. detects which translation mod (if any) is installed and its language,
--   2. loads the matching modern-content catalog (data/lang/<code>.lua; French,
--      German, both Spanish regions, Italian, Japanese kana and Korean ship),
--   3. patches the `pokemon` registry (national dex 152+) and the `moves` and
--      `items` registries with the catalog's names,
--   4. rewrites the `strings` entries the engine's own field-move submenu reads
--      (`Strings("SURF")` &c), which the translation mod leaves English, and
--      the learner narration a Gen 2 boot falls back to Gen 1 literals for,
--   5. publishes a lookup other mods (and this suite's own screens) use for
--      ABILITIES -- which have no content registry: their display names live
--      inside pokemon records and g9-battle-engine / national_dex exports
--      (`mon.ability`, `abilityById`) -- and M.ui, the modern UI's own lexicon
--      (footer hints, header readouts, START captions, Mod Manager option
--      labels), which the translation mod never sees.  M.line covers the
--      other half of that seam: the full BATTLE/FIELD sentences our own mods
--      send (the battle scene's refusals and outcome lines, the trainer-
--      rematch question), exact or with a name spliced in.
--
-- It NEVER overrides work the translation mod already did.  The catalogs are
-- keyed by the FOLDED ENGLISH name (see fold below: lowercased with the
-- punctuation the engine drops removed) and a record is only rewritten when
-- its current, folded name still matches a key AND the translated value
-- actually differs.  A Gen 1 move the translation mod renamed to "Absorcion"
-- no longer folds to "absorb", so it is left exactly as the ROM rendered it;
-- only the modern content the mod cannot reach is filled in.
--
-- DETECTION.  There is no public mod-list API, so the known ids are probed
-- directly with mod.find (which answers only for an ACTIVE mod whose entry
-- chunk has already run).  g9-gui declares every `translation-*` id in its
-- manifest's optional_dependencies purely to get the ordering edge -- that
-- guarantees the translation mods initialise FIRST, so their patches are in
-- place when this module reads the records (and so display_names can copy an
-- already-translated base name onto every form).  An absent optional
-- dependency is not an error; without one the probe simply finds nothing and
-- modern names stay English.
--
-- TWO FAMILIES.  Besides the generator's `translation-<lang>[-gen2|-gen3]`
-- ids, a second, independent family ships Brazilian Portuguese: the community
-- mods `gen1_pt-br_mod` (Red/Blue/Yellow), `versaodourada` (Gold/Silver) and
-- `versaocristal` (Crystal).  They are not built by the generator, so no id
-- can be synthesised for them -- they are hand-listed in LANGUAGE_MODS.  They
-- are the same kind of mod (they patch the content registries and the engine
-- `strings` catalog and keep the English species names), so PT-BR rides the
-- same machinery: a `pt-br` catalog carries the suite's own UI/message
-- lexicon and the eight learner literals.  Their own Gen 1/2 move and item
-- names are left exactly as they set them (folded mismatch), and their engine
-- `strings` reach M.engineString unchanged.
--
-- FONT.  The Latin-script catalogs use only characters Saira already carries;
-- what it lacks lives in assets/fonts/g9-symbols.ttf -- the symbols a name can
-- use (U+2640 FEMALE SIGN, U+2642 MALE SIGN, U+2605 BLACK STAR), the kana a
-- Japanese catalog uses and the Hangul a Korean one uses.  It is built from
-- Noto Sans Symbols 2, Noto Sans JP and Noto Sans KR (all SIL OFL) and is
-- attached to every baked font as a LOVE Font:setFallbacks fallback -- see
-- ui/theme.lua, and M.symbolBytes / M.symbolFont below for the copy other g9
-- UI mods use.
--
-- OPTION.  The Mod Manager row `translation` (options.lua) gates the whole
-- feature: OFF means no detection, no patches, no lookups.  `translation_spanish`
-- (LATAM / ESPAÑA) picks which Spanish catalog is loaded.  The font fallback is
-- NOT gated -- it only adds glyphs and never changes a name.
--
-- REBUILDING THE CATALOGS.  See src/README.md; in short, take PokeAPI's
-- pokemon_species_names / move_names / item_names / ability_names CSVs
-- (local_language_id 9 = English, 5 = fr, 6 = de, 7 = es, 14 = es-419,
-- 8 = it, 1 = ja-hrkt, 3 = ko), fold the English name and emit the localized
-- value; `species` is keyed by dex, the rest by the folded English name.  The
-- `ui` lexicon is authored and hand-checked.  Keys stay byte-identical to
-- fold().

return function(mod, opts)
  opts = opts or {}
  local M = {}

  local function info(msg)
    if type(opts.info) == "function" then pcall(opts.info, msg) end
  end

  -- ------------------------------------------------------------------ fold
  -- The one normalization both the catalog keys and the runtime lookups use:
  -- lowercase, then drop everything the display layer treats as noise --
  -- whitespace and - ' . : ! ? , and the curly right single quote.  It is what
  -- makes the engine's "Double Edge" find PokeAPI's "Double-Edge" and
  -- "King's Shield" find "Kings Shield", while leaving the accented and
  -- symbol glyphs (Nidoran FEMALE, the star) intact.
  function M.fold(text)
    if type(text) ~= "string" then return "" end
    local s = text:lower()
    s = s:gsub("\226\128\153", "'") -- U+2019 -> '
    s = s:gsub("[%s%-'%.:!?,]", "")
    return s
  end

  -- ------------------------------------------------------------- detection
  -- The generator's canonical languages (its README) and the suffixes it puts
  -- on a generation's mod id.  The empty suffix is Red/Blue/Yellow.
  local LANGUAGES = { "fr", "de", "es", "it", "ja-hrkt", "ko" }
  local SUFFIXES = { "", "-gen2", "-gen3" }
  -- Which languages this build carries a modern-content catalog for.  A
  -- detected language with no entry here is still reported (M.language), it
  -- just does not rewrite anything -- the seam can only be closed for a
  -- language whose data actually ships.  Spanish ships TWO regional variants
  -- (Latin American es-419, Spain es), picked by the Mod Manager's
  -- `translation_spanish` row; `la` is the fallback when the row is absent.
  local SPANISH_VARIANTS = {
    la = "data/lang/es-419.lua",
    esp = "data/lang/es.lua",
  }
  local CATALOGS = {
    es = true, -- resolved through SPANISH_VARIANTS
    fr = "data/lang/fr.lua",
    de = "data/lang/de.lua",
    it = "data/lang/it.lua",
    ["ja-hrkt"] = "data/lang/ja-hrkt.lua",
    ko = "data/lang/ko.lua",
    ["pt-br"] = "data/lang/pt-br.lua",
  }
  -- The Brazilian translation-mod family (see the DETECTION note above): ids
  -- that are NOT built by the generator, so they cannot be synthesised.  Each
  -- maps to the language its catalog ships under; the order is the probe order.
  -- The three are mutually exclusive in practice (one game, one translation),
  -- so the first that `mod.find` answers wins.
  local LANGUAGE_MODS = {
    { id = "gen1_pt-br_mod", lang = "pt-br" }, -- Red/Blue/Yellow
    { id = "versaodourada",  lang = "pt-br" }, -- Gold/Silver
    { id = "versaocristal",  lang = "pt-br" }, -- Crystal
  }
  -- The catalog file for (lang, region).  `region` only matters for Spanish.
  local function catalogPath(lang, region)
    if lang ~= "es" then return CATALOGS[lang] end
    return SPANISH_VARIANTS[region] or SPANISH_VARIANTS.la
  end
  local function countKeys(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
  end

  function M.detect()
    if type(mod.find) ~= "function" then return nil end
    for _, lang in ipairs(LANGUAGES) do
      for _, suffix in ipairs(SUFFIXES) do
        local id = "translation-" .. lang .. suffix
        local ok, peer = pcall(mod.find, mod, id)
        if ok and type(peer) == "table" then return id, lang, peer end
      end
    end
    -- The Brazilian family: real ids, hand-listed.
    for _, entry in ipairs(LANGUAGE_MODS) do
      local ok, peer = pcall(mod.find, mod, entry.id)
      if ok and type(peer) == "table" then
        return entry.id, entry.lang, peer
      end
    end
    return nil
  end

  -- ---------------------------------------------------------------- lookups
  -- A catalog table read straight off the mod's own byte source.  A missing or
  -- broken file is a logged no-op, never a load failure.
  local function readCatalog(rel)
    local ok, body = pcall(mod.read, mod, rel)
    if not (ok and type(body) == "string" and #body > 0) then return nil end
    local compile = loadstring or load
    if type(compile) ~= "function" then return nil end
    local chunk, err = compile(body, "@" .. rel)
    if not chunk then
      info("g9-gui: " .. rel .. " failed to compile: " .. tostring(err))
      return nil
    end
    local ran, value = pcall(chunk)
    if not ran or type(value) ~= "table" then
      info("g9-gui: " .. rel .. " did not return a catalog table")
      return nil
    end
    return value
  end

  -- The translated name of `text` in the named catalog set ("moves", "items",
  -- "abilities"), or `text` unchanged.  Public: the screens call M.ability,
  -- and other g9 UI mods read this off mod.exports.translation.
  function M.name(kind, text)
    if not M.enabled or type(text) ~= "string" then return text end
    local set = M.catalog and M.catalog[kind]
    if type(set) ~= "table" then return text end
    return set[M.fold(text)] or text
  end

  -- Ability display names.  Abilities have no content registry: a record
  -- carries them as inline names (national_dex) or as indices into an
  -- abilityNames table (the engine's own stats), and g9-battle-engine's
  -- `mon.ability` is already a display string.  So they are translated at the
  -- point of display instead of by patch.
  function M.ability(text)
    return M.name("abilities", text)
  end

  -- The modern UI's OWN lexicon: the English chrome strings this suite draws
  -- (footer hints, the header's MONEY/BADGES/DEX readouts, the START-screen
  -- captions, the party-submenu rows peer mods append, the Mod Manager option
  -- labels), keyed by the English source string.  The translation mod never
  -- translates these -- they are ours, not the ROM's -- so this is the only
  -- source for them.  Only a string the lexicon knows is touched: an arbitrary
  -- name (a Pokemon, a move, a dialogue line) falls straight through.  For a
  -- key the lexicon DOES carry, the engine's own value wins when it exists (an
  -- official menu word beats our paraphrase); the lexicon is the fallback.
  -- The engine's own `strings` catalog (the ROM's text plus the translation
  -- mod's engine overrides, both keyed by the very English source).  Many of
  -- this suite's own labels ARE engine strings -- BILL's PC, CHANGE BOX,
  -- WITHDRAW ITEM, SEE YA!, TURN OFF ... -- so looking here first translates
  -- them with the ROM's own official wording, with no lexicon entry of their
  -- own.  Memoised: this runs for every string the modern UI draws.
  local engineCache = {}
  local function engineString(text)
    if not M.enabled then return nil end
    local hit = engineCache[text]
    if hit ~= nil then return hit or nil end
    local strings = mod.content and mod.content.strings
    if not (strings and type(strings.get) == "function") then
      engineCache[text] = false
      return nil
    end
    local ok, v = pcall(strings.get, strings, text)
    local out = (ok and type(v) == "string" and v ~= "" and v ~= text)
      and v or false
    engineCache[text] = out
    return out or nil
  end
  M.engineString = engineString

  function M.ui(text)
    if not M.enabled or type(text) ~= "string" or text == "" then return text end
    local dict = M.catalog and M.catalog.ui
    local known = type(dict) == "table" and dict[text] ~= nil
    -- the engine's own word wins for a key BOTH carry (official beats a
    -- paraphrase); for a key only the engine carries it is the only source
    local official = engineString(text)
    if official then return official end
    if known then return dict[text] end
    return text
  end

  -- The modern BATTLE/FIELD message lexicon: the sentences this suite's OWN
  -- mods send to the screen -- the battle scene's refusals and outcome lines,
  -- the trainer-rematch question, the gimmick labels -- which the translation
  -- mod never sees (they are ours, not the ROM's).  `messages` is an exact
  -- English->localized table; `messageTemplates` holds the same for a sentence
  -- with a mon/trainer NAME spliced in, keyed by the English form with %1/%2
  -- where the names go.  Only a string the catalog knows is touched, so an
  -- arbitrary line falls through.  Peers reach this as
  -- mod.exports.translation.line (g9-Battle-Scene's message box and
  -- g9-battle-sample's rematch question call it).
  local function templatePattern(key)
    -- Mark the %1..%9 slots, escape whatever Lua-pattern magic remains, then
    -- turn each mark into a lazy capture.  Anchored, so only a WHOLE-string
    -- match counts.
    local marked = key:gsub("%%([1-9])", "\1")
    marked = marked:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    return "^" .. marked:gsub("\1", "(.-)") .. "$"
  end

  function M.line(text)
    if not M.enabled or type(text) ~= "string" or text == "" then return text end
    local cat = M.catalog
    if type(cat) ~= "table" then return text end
    local messages = cat.messages
    if type(messages) == "table" then
      local hit = messages[text]
      if hit ~= nil then return hit end
    end
    -- A short label the `ui` lexicon carries (TERA, DYNAMAX ...).  The engine's
    -- own word still wins when it has one, exactly as M.ui.
    local ui = cat.ui
    if type(ui) == "table" and ui[text] ~= nil then
      -- the engine's own word still wins when it has one, exactly as M.ui --
      -- through the memoised lookup rather than a fresh `strings.get` per draw
      local official = engineString(text)
      if official then return official end
      return ui[text]
    end
    -- A sentence with a name spliced in: match the whole string against the
    -- compiled templates and fill the value's slots from the captures.
    local templates = cat.messageTemplates
    if type(templates) == "table" then
      if M.compiled == nil then
        local list = {}
        for key, value in pairs(templates) do
          list[#list + 1] = { pat = templatePattern(key), value = value,
            n = #key }
        end
        -- MOST SPECIFIC FIRST: a slot is a lazy, unconstrained capture, so a
        -- shorter template would happily swallow the tail of a longer match
        -- ("SEEN 37  OWN 12" matches "SEEN 37  OWN 12   SORT OLD" with %2 =
        -- "12   SORT OLD").  Sorting by key length makes the longer template
        -- win the string it was written for.
        table.sort(list, function(a, b) return a.n > b.n end)
        M.compiled = list
      end
      for i = 1, #M.compiled do
        local caps = { text:match(M.compiled[i].pat) }
        if caps[1] ~= nil then
          return (M.compiled[i].value:gsub("%%([1-9])", function(n)
            return tostring(caps[tonumber(n)] or "")
          end))
        end
      end
    end
    -- An engine string the catalog did not carry (the ROM's own wording).
    return engineString(text) or text
  end

  -- A national-dex species name by dex number, or nil.
  function M.species(dex)
    if not M.enabled or type(dex) ~= "number" then return nil end
    local set = M.catalog and M.catalog.species
    if type(set) ~= "table" then return nil end
    return set[dex]
  end

  -- --------------------------------------------------------------- patches
  -- Rewrite the `name` of every record the catalog knows and whose current
  -- name still folds to an English key.  Collect first, patch after -- patching
  -- while walking the registry's own iterator would mutate the table being
  -- walked (the same discipline ui/display_names.lua uses).
  local function patchRegistry(regName, set)
    if type(set) ~= "table" then return 0 end
    local reg = mod.content and mod.content[regName]
    if not (reg and type(reg.each) == "function"
        and type(reg.patch) == "function") then return 0 end
    local wanted = {}
    local ok = pcall(function()
      for id, def in reg:each() do
        if type(id) == "string" and type(def) == "table"
            and type(def.name) == "string" then
          local t = set[M.fold(def.name)]
          if t and t ~= def.name then wanted[#wanted + 1] = { id, t } end
        end
      end
    end)
    if not ok then return 0 end
    local changed = 0
    for i = 1, #wanted do
      if pcall(reg.patch, reg, wanted[i][1], { name = wanted[i][2] }) then
        changed = changed + 1
      end
    end
    return changed
  end

  -- Modern species only: the translation mod owns national dex 1..151 (Gen 1)
  -- and its ROM names for them, and national_dex's expanded records start at
  -- 152.  Keyed by DEX, so a name mismatch between the engine's record and
  -- PokeAPI's English spelling cannot matter, and forms (which carry
  -- baseSpecies and are named from their base record by ui/display_names.lua)
  -- are skipped -- only the base record is rewritten here.
  local function patchSpecies(set)
    if type(set) ~= "table" then return 0 end
    local reg = mod.content and mod.content.pokemon
    if not (reg and type(reg.each) == "function"
        and type(reg.patch) == "function") then return 0 end
    local wanted = {}
    local ok = pcall(function()
      for id, def in reg:each() do
        if type(id) == "string" and type(def) == "table"
            and type(def.dex) == "number" and def.dex > 151
            and (def.form == nil or def.form == "")
            and type(def.name) == "string" then
          local t = set[def.dex]
          if t and t ~= def.name then wanted[#wanted + 1] = { id, t } end
        end
      end
    end)
    if not ok then return 0 end
    local changed = 0
    for i = 1, #wanted do
      if pcall(reg.patch, reg, wanted[i][1], { name = wanted[i][2] }) then
        changed = changed + 1
      end
    end
    return changed
  end

  -- The engine's own field-move submenu builds its rows from `Strings(<move
  -- id>)` (src/ui/PartyMenu.lua: "SURF", "CUT", "FLY" ...), NOT from the moves
  -- registry patched above -- so an HM row stayed English under a translation
  -- mod that carries no such string key.  Rewrite those `strings` entries too,
  -- keyed by the record's own id and taken from the same catalog, only when the
  -- catalog's name differs from the record's.  An override for a key nothing
  -- reads is a harmless addition.
  local function patchMoveStrings(set)
    if type(set) ~= "table" then return 0 end
    local strings = mod.content and mod.content.strings
    if not (strings and type(strings.override) == "function") then return 0 end
    local reg = mod.content and mod.content.moves
    if not (reg and type(reg.each) == "function") then return 0 end
    local changed = 0
    pcall(function()
      for id, def in reg:each() do
        if type(id) == "string" and type(def) == "table"
            and type(def.name) == "string" then
          local t = set[M.fold(def.name)]
          if t and t ~= def.name then
            -- Only fill a key nothing has translated yet: an existing value
            -- that is neither empty nor the English key itself is the
            -- translation mod's own word and is left alone.
            local current
            local okCur, v = pcall(strings.get, strings, id)
            if okCur then current = v end
            if current == nil or current == id then
              if pcall(strings.override, strings, id, t) then
                changed = changed + 1
              end
            end
          end
        end
      end
    end)
    return changed
  end

  -- The engine's own MOVE-LEARNER narration, on a game whose ROM text has no
  -- such label.  src.ui.MoveLearnMenu reads its lines through
  -- `romText(data, "_TryingToLearnText", "<Gen 1 literal>", ...)`: on Red/Blue/
  -- Yellow the pokered label exists and carries the localized text the
  -- translation mod extracted, so the literal is never reached -- but on
  -- Gold/Silver/Crystal those labels are not in `data.text`, so romText falls
  -- through to `Strings(<literal>, ...)`, and the GSC catalog has no entry for
  -- a Gen 1 source string.  The catalog's `engineLearner` table carries those
  -- exact literals (byte-for-byte, `\n`/`\v`/`\f` included) so the narration
  -- the learner shows -- in battle (the queue's own mid-fight learn pause) and
  -- out of it (a TM, the post-evolution sweep) -- is translated there too.
  -- Only a source nothing has translated yet is filled, so a translation that
  -- DOES cover one of these lines keeps its own wording.
  local function patchEngineStrings(set)
    if type(set) ~= "table" then return 0 end
    local strings = mod.content and mod.content.strings
    if not (strings and type(strings.override) == "function") then return 0 end
    local changed = 0
    for source, value in pairs(set) do
      if type(source) == "string" and type(value) == "string" and value ~= "" then
        local current
        local ok, v = pcall(strings.get, strings, source)
        if ok then current = v end
        if current == nil or current == "" or current == source then
          if pcall(strings.override, strings, source, value) then
            changed = changed + 1
          end
        end
      end
    end
    return changed
  end

  -- ------------------------------------------------------------------ font
  -- The character supplement the Saira faces lack: the symbols a translated
  -- name uses (U+2640 / U+2642 / U+2605), the kana a Japanese catalog uses and
  -- the Hangul a Korean one uses.  Built from Noto Sans JP/KR and Noto Sans
  -- Symbols 2 (all SIL OFL) into assets/fonts/g9-symbols.ttf.
  -- Bytes are cached; the Font is built lazily, per size, by whoever needs it
  -- (ui/theme.lua here, and any peer mod that reads mod.exports.translation).
  local SYMBOLS = "assets/fonts/g9-symbols.ttf"
  local symbolBytes, symbolFonts = nil, {}

  function M.symbolBytes()
    if symbolBytes == nil then
      local ok, body = pcall(mod.read, mod, SYMBOLS)
      symbolBytes = (ok and type(body) == "string" and #body > 0) and body or false
    end
    return symbolBytes or nil
  end

  function M.symbolFont(size)
    if type(size) ~= "number" or size <= 0 then return nil end
    local hit = symbolFonts[size]
    if hit ~= nil then return hit or nil end
    local bytes = M.symbolBytes()
    if not bytes then symbolFonts[size] = false return nil end
    local fn = (love.data and love.data.newFileData)
      or (love.filesystem and love.filesystem.newFileData)
    local font
    if fn then
      local ok, fd = pcall(fn, bytes, "g9-symbols.ttf")
      if ok and fd then
        local ok2, f = pcall(love.graphics.newFont, fd, size)
        if ok2 and f and f.getWidth then font = f end
      end
    end
    symbolFonts[size] = font or false
    return font
  end

  -- Attach the supplement to a baked font as a fallback.  LOVE 11.3+ only; an
  -- engine without Font:setFallbacks silently keeps the old behaviour (the
  -- three glyphs simply do not render).  Returns the same font, so it can wrap
  -- a builder expression.
  function M.attach(font, size)
    if not (font and type(size) == "number" and font.setFallbacks) then
      return font
    end
    local sym = M.symbolFont(size)
    if sym then pcall(font.setFallbacks, font, sym) end
    return font
  end

  -- ---------------------------------------------------------------- install
  -- Called once, from the entry chunk, BEFORE the content registries freeze
  -- and before ui/display_names.lua runs (so a form inherits a translated base
  -- name).  Idempotent.
  function M.install()
    if M.installed then return M end
    M.installed = true

    -- Option gate: OFF means the whole layer stands down.
    if type(opts.on) == "function" then
      local ok, enabled = pcall(opts.on, "translation")
      if ok and enabled == false then
        info("g9-gui: translation adaptation is OFF -- modern names stay "
          .. "exactly as national_dex spells them")
        return M
      end
    end

    local id, lang, peer = M.detect()
    if not id then
      info("g9-gui: no translation mod detected -- modern names stay English")
      return M
    end
    M.detected = true
    M.modId = id
    M.language = lang
    M.version = type(peer) == "table" and peer.version or nil

    -- Spanish picks a region: the Mod Manager's `translation_spanish` row
    -- ("la" = Latin America, "esp" = Spain).  An unknown value is ignored.
    if lang == "es" then
      if type(opts.opt) == "function" then
        local ok, value = pcall(opts.opt, "translation_spanish")
        if ok and type(value) == "string" and SPANISH_VARIANTS[value] then
          M.region = value
        end
      end
      M.region = M.region or "la"
    end

    local rel = catalogPath(lang, M.region)
    if not rel then
      info(("g9-gui: translation mod '%s' detected, but no modern-content "
        .. "catalog ships for language '%s' -- modern names stay English")
        :format(id, lang))
      return M
    end

    local catalog = readCatalog(rel)
    if not catalog then
      info(("g9-gui: translation mod '%s' detected but its catalog %s could "
        .. "not be read -- modern names stay English"):format(id, rel))
      return M
    end
    M.catalog = catalog
    M.code = catalog.code or lang
    M.enabled = true

    local species = patchSpecies(catalog.species)
    -- Field-move `strings` BEFORE the moves registry is renamed: it keys off
    -- the records' ENGLISH names, which the registry patch below overwrites.
    local hms = patchMoveStrings(catalog.moves)
    -- The engine learner's own narration (a Gen 2 boot reads it from the Gen 1
    -- module, whose pokered labels Gold's data lacks -- see patchEngineStrings).
    local learner = patchEngineStrings(catalog.engineLearner)
    local moves = patchRegistry("moves", catalog.moves)
    local items = patchRegistry("items", catalog.items)
    info(("g9-gui: %s translation detected (%s) -- translated %d species, "
      .. "%d moves, %d items and %d field-move labels; %d learner strings, "
      .. "%d ability names and the %d-key UI lexicon resolve at draw time")
      :format(lang, M.code, species, moves, items, hms, learner,
        countKeys(catalog.abilities), countKeys(catalog.ui)))
    return M
  end

  return M
end
