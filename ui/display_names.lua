-- ui/display_names.lua -- the name a Pokemon is shown as.
--
-- national_dex gives every mechanically/sprite-distinct form its own species
-- record, and spells each one as a slug ("ponyta-galar", "charizard-mega-x").
-- Those slugs are IDENTIFIERS, and they stay that way: the engine, the sprite
-- pack and this suite all key on the record's `id` to tell two forms apart.
-- They are not, however, what the games CALL the Pokemon.  Ponyta-Galar is
-- "Ponyta" to the player; so is Alolan Raichu ("Raichu"), Hisuian Sneasel
-- ("Sneasel"), Paldean Tauros ("Tauros"), a Gigantamax ("Charizard") and every
-- other form whose difference is a regional or battle descriptor.  The player's
-- view names the SPECIES.
--
-- The only exceptions are the forms whose own descriptor is part of the
-- Pokemon's name: MEGA forms ("Mega Charizard X"), Zygarde's forms ("Zygarde
-- 10%", "Zygarde Complete") and White/Black Kyurem.  Everything else shows the
-- base species' name.
--
-- HOW IT IS APPLIED.  Rather than teach every screen a lookup, this module
-- rewrites the `name` ON THE RECORD, once, at load -- leaving `id` untouched.
-- national_dex has already registered its records by the time this mod loads
-- (national_dex ships priority 90, this mod 100), and every consumer -- the
-- engine's own Pokedex entry page, party list and battle HUD (which draw
-- `def.name` directly), national_dex's own pages, this suite's screens, and
-- the battle scene -- reads the record, so the correction lands everywhere
-- without a single one of them knowing this file exists.
--
-- The descriptions the pages print for a form under its name (national_dex's
-- own form caption, read off `record.form`) are NOT touched: only `name`
-- changes, so a Galarian Ponyta reads "PONYTA" with its "GALAR" form tag,
-- exactly the pair the games show.
--
-- Safe to run with national_dex absent: with no form records there is nothing
-- to rename and the loop simply finds none.

local M = {}

-- "MEGA_X" -> "MEGA X", "10_POWER_CONSTRUCT" -> "10 POWER CONSTRUCT": the
-- record keeps its slug in `form`, the player reads words.
local function words(form)
  return (form:gsub("_", " "))
end

-- Mega forms: the descriptor is part of the name, and the games put it in
-- front ("Mega Charizard X").  The base species' name goes in right after the
-- MEGA token wherever it sits, so MEGA_X / MALE_MEGA / ORIGINAL_MEGA all read
-- as one family: "MEGA CHARIZARD X", "MALE MEGA MEOWSTIC", ...
local function megaName(form, base)
  local out, placed = {}, false
  for part in form:gmatch("[^_]+") do
    out[#out + 1] = part
    if part == "MEGA" and not placed then
      out[#out + 1] = base
      placed = true
    end
  end
  if not placed then out[#out + 1] = base end
  return table.concat(out, " ")
end

-- Zygarde's forms keep the form word AND the percent sign the games print:
-- "Zygarde 10%", "Zygarde 50%", "Zygarde Complete", "Zygarde 10% Power
-- Construct".  The base name stays first, unlike a Mega's.
local function zygardeName(form, base)
  local text = words(form)
  text = text:gsub("^10", "10%%")
  text = text:gsub("^50", "50%%")
  return base .. " " .. text
end

-- The player-facing name for one form record, or nil to keep the record's own.
--   id           the record's id (the system identifier, never changed)
--   form         the record's `form` slug (e.g. "GALAR", "MEGA_X")
--   baseSpecies  the record's `baseSpecies` id
--   baseName     that base record's own name (already the display spelling)
function M.formName(id, form, baseSpecies, baseName)
  if type(form) ~= "string" or form == "" then return nil end
  if type(baseName) ~= "string" or baseName == "" then return nil end
  -- Zygarde first: its transform forms are the ONE family whose slug may carry
  -- a MEGA token, and they belong to the Zygarde family ("Zygarde Mega"), not
  -- to the Mega-naming rule.
  if baseSpecies == "ZYGARDE" then return zygardeName(form, baseName) end
  if baseSpecies == "KYUREM" and (form == "BLACK" or form == "WHITE") then
    return words(form) .. " " .. baseName
  end
  if form:find("MEGA", 1, true) then return megaName(form, baseName) end
  return baseName
end

-- Resolve one id the way the records will read after apply(): the patched name
-- when it is a form, else the record's own name, else the id itself.  A reader
-- that wants the player-facing name of a species it only has an id for calls
-- this instead of indexing a record directly.
function M.nameFor(mod, id)
  if type(id) ~= "string" or id == "" then return nil end
  local reg = mod and mod.content and mod.content.pokemon
  if not (reg and type(reg.get) == "function") then return nil end
  local ok, def = pcall(reg.get, reg, id)
  if not (ok and type(def) == "table") then return nil end
  if type(def.form) == "string" and def.form ~= ""
      and type(def.baseSpecies) == "string" and def.baseSpecies ~= "" then
    local baseOk, base = pcall(reg.get, reg, def.baseSpecies)
    local baseName = baseOk and type(base) == "table" and base.name or nil
    local shown = M.formName(id, def.form, def.baseSpecies, baseName)
    if shown then return shown end
  end
  if type(def.name) == "string" and def.name ~= "" then return def.name end
  return id
end

-- Rewrite every form record's `name` to its player-facing name.  Returns the
-- number of records changed (0 when there are none to change, e.g. without
-- national_dex).  Runs before the content freeze, from the entry chunk, so the
-- merge picks the corrected names up like any other contribution.
function M.apply(mod)
  local reg = mod and mod.content and mod.content.pokemon
  if not (reg and type(reg.each) == "function" and type(reg.get) == "function"
      and type(reg.patch) == "function") then
    return 0
  end
  -- Collect first, patch after: patching while walking the registry's own
  -- iterator would mutate the table being walked.
  local wanted = {}
  local ok = pcall(function()
    for id, def in reg:each() do
      if type(id) == "string" and type(def) == "table"
          and type(def.form) == "string" and def.form ~= ""
          and type(def.baseSpecies) == "string" and def.baseSpecies ~= "" then
        local baseOk, base = pcall(reg.get, reg, def.baseSpecies)
        local baseName = baseOk and type(base) == "table" and base.name or nil
        local shown = M.formName(id, def.form, def.baseSpecies, baseName)
        if shown and shown ~= def.name then
          wanted[#wanted + 1] = { id = id, name = shown }
        end
      end
    end
  end)
  if not ok then return 0 end
  local changed = 0
  for _, row in ipairs(wanted) do
    if pcall(reg.patch, reg, row.id, { name = row.name }) then
      changed = changed + 1
    end
  end
  return changed
end

return M
