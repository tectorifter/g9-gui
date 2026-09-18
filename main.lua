-- =============================================================================
-- g9-gui -- "modern UI & stats"
--
-- A full-screen modern menu suite for Gen 1 (Red / Blue / Yellow) on the
-- gen1recomp engine.  Three engine screens are REPLACED by this mod:
--
--   * StartMenu    -> ui/start_menu.lua  the FF12-shaped START screen: the
--                    vanilla rows in a word-list column on the left, the live
--                    party roster (portrait card, name, level, HP and an EXP
--                    bar) on the right.
--   * PartyMenu    -> ui/party_menu.lua  the POKeMON screen: the SAME page --
--                    same surface, same header, same left rail, same roster --
--                    with the engine's own submenu as a modern popup.
--   * SummaryMenu  -> ui/summary.lua     Adv.Stats in a 486x324 panel (90% of
--                    the 540x360 surface) floated OVER the POKeMON screen, so
--                    the menu stays visible around it.
--
-- ui/shell.lua owns the page both menu screens are laid out in (its size, its
-- header, its footer and its left rail), so the two cannot drift apart.
--
-- DESIGN: every screen is a VIEW TAKEOVER, not a reimplementation.  main.lua
-- still asks the engine's own module for the object (`require("src.ui.…")`),
-- so all behaviour is the shipped behaviour -- field moves, battle switching,
-- the save panel, item targeting, the cursor that survives closing, the
-- ui.start_menu.items / ui.party.submenu hooks other mods insert through, the
-- medicine HP-fill and swap animations, TM/HM and evolution-stone ABLE views.
-- Only the INSTANCE is amended: draw, the surface size, the palette list and
-- the opacity flag move onto the instance, and the engine's own update keeps
-- running (wrapped only to tick an animation counter).
--
-- WHY THE SURFACE GROWS: each screen answers :uiSize() with the shell's size.
-- Game:draw calls Renderer:setUISize with the top wide state's size and
-- centres classic states in the extra width (classicOffset), so 160x144 art
-- still lands in the middle of the bigger canvas horizontally -- though with a
-- taller-than-classic page the vertical centring the engine does not do is
-- visible (see ui/shell.lua's KNOWN LIMIT note).  Nothing here ever calls
-- Renderer:setUISize or love.graphics.setCanvas itself: doing that from inside
-- a state's draw is the documented silent-crash hazard.
--
-- The page is 540x360: 3:2, which is the one shape that divides 1080x720
-- evenly (a 1080x720 window blits it at a whole 2x with no letterbox).  The
-- engine refuses a surface over 640x576 (Renderer.MAX_UI_WIDTH/HEIGHT), so
-- 1080x720 itself is not a legal :uiSize(); 540x360 is the largest 3:2 page
-- that is.  Type and surface were designed together: the body is SAIRA at 22
-- (a 15px cap -- 30 screen pixels once the page blits 2x) with a 13px
-- secondary size, and the portrait cards are large rectangles instead of the
-- old 54x19 slivers.
--
-- TEXT is the one thing that needs shipped assets.  ui/theme.lua builds its
-- own love Font objects from two static instances of SAIRA (SIL OFL 1.1 --
-- assets/fonts/OFL.txt ships beside them, and the licence has no reserved font
-- name, so nothing is renamed): assets/fonts/Saira-Regular.ttf and
-- Saira-SemiBold.ttf.  They are read through mod:read into a FileData first
-- (which works even when the mod directory is not mounted into
-- love.filesystem) and through mod.assets:path second; if neither opens, the
-- engine's own Plain Pixel TTF is used and the identical layout still holds.
-- Saira is chosen to match the FINAL FANTASY XII: THE ZODIAC AGE menu face --
-- mixed case, wide, low contrast, flat terminals, heavy figures -- because the
-- real font is not redistributable.  It is proportional, so no layout in this
-- mod counts character cells: measure with Theme.w / Theme.fit.
--
-- Empty :sgbPalettes() keeps the engine's SGB shade-remap shader off these
-- surfaces, so the palette below reaches the screen unchanged.
--
-- Options (options.lua, mirrored by manifest.options_schema so the Mod Manager
-- can draw the rows before this chunk runs):
--   modern_ui        ON/OFF  -- the master switch; OFF installs nothing
--   ui_background    ON/OFF  -- the layered backdrop vs a flat dark field
--   ui_embellishment ON/OFF  -- corner brackets, rules, header emblem, pulse
--   ui_portraits     sprites/icons -- portrait band art per roster row
--
-- Gen 2 is deliberately untouched: Gold's screens are registered under their
-- own Gen2* ids by the engine, this design is built around the Gen 1 party /
-- summary data, and the manifest declares games = ["gen1"] so the loader skips
-- this mod entirely on a Gold boot.
-- =============================================================================
return function(mod)
  -- ------------------------------------------------------------------ helpers
  -- mod.log passes its message through string.format ("[%s] " .. fmt), so a
  -- literal % in a file path or errno string has to be doubled or the logger
  -- itself throws while reporting a failure.
  local function esc(s)
    return (tostring(s):gsub("%%", "%%%%"))
  end

  local function warn(msg)
    mod.log:warn(esc(msg))
  end

  local function info(msg)
    mod.log:info(esc(msg))
  end

  -- Sibling files ship beside this one and are compiled from the mod's own
  -- byte source (mod:read), the same mechanism the engine mod uses.  Every
  -- call site below passes a LITERAL path so the studio's dependency scan can
  -- see the whole file set from the entry chunk alone.
  local function loadSibling(file)
    local body = mod:read(file)
    if not body then
      warn("g9-gui: missing sibling file " .. file)
      return nil
    end
    local compile = loadstring or load
    local chunk, err = compile(body, "@" .. file)
    if not chunk then
      warn("g9-gui: " .. file .. " failed to compile: " .. tostring(err))
      return nil
    end
    local ok, value = pcall(chunk)
    if not ok then
      warn("g9-gui: " .. file .. " failed to run: " .. tostring(value))
      return nil
    end
    return value
  end

  -- ------------------------------------------------------------------ options
  -- Same schema the manifest points at, so the manager can render the rows
  -- before this chunk has run (Reference: the manifest options_schema field).
  local schema = loadSibling("options.lua")
  if type(schema) == "table" then
    local ok, err = pcall(function() mod.options:define(schema) end)
    if not ok then warn("g9-gui: options schema rejected: " .. tostring(err)) end
  else
    warn("g9-gui: options.lua did not return a schema table")
  end

  local function opt(key)
    return mod.options:get(key)
  end

  -- choice rows carry their value as a STRING ("true"/"false"/"icons"/
  -- "sprites"); a nil (row missing) reads as ON so a partial schema cannot
  -- silently disable the mod.
  local function on(key)
    local v = opt(key)
    return not (v == "false" or v == false)
  end

  -- ------------------------------------------------------------- gen 1 gate
  local gen = 1
  do
    local ok, value = pcall(function()
      local GameVersion = require("src.core.GameVersion")
      return GameVersion.generation(GameVersion.get())
    end)
    if ok and value then gen = value end
  end
  if gen == 2 then
    info("g9-gui: Gen 2 boot -- the modern UI is Gen 1 only, nothing installed")
    return
  end

  if not on("modern_ui") then
    info("g9-gui: MODERN UI is OFF -- every screen is left exactly as the "
      .. "engine drew it")
    return
  end

  -- ------------------------------------------------------------- dependencies
  -- g9-battle-engine is optional: its ModernStats / MoveCategory exports give
  -- the summary panel the split stats, abilities and natures.  Without it the
  -- panel falls back to the engine's own stat block.
  local engine = mod.find and mod.find("g9-battle-engine") or nil

  -- --------------------------------------------------------------- ui modules
  local Theme = loadSibling("ui/theme.lua")
  local Backdrop = loadSibling("ui/backdrop.lua")
  local Shell = loadSibling("ui/shell.lua")
  local Portraits = loadSibling("ui/portraits.lua")
  local Roster = loadSibling("ui/roster.lua")
  if not (Theme and Backdrop and Shell and Portraits and Roster) then
    warn("g9-gui: shared ui modules failed to load -- no screens installed")
    return
  end
  Theme = Theme(mod)
  Backdrop = Backdrop(mod)
  Shell = Shell(mod)
  Portraits = Portraits(mod)
  Roster = Roster(mod)

  local ctx = {
    mod = mod,
    opt = opt,
    on = on,
    Theme = Theme,
    Backdrop = Backdrop,
    Shell = Shell,
    Portraits = Portraits,
    Roster = Roster,
    engine = engine,
    ModernStats = engine and engine.exports.ModernStats or nil,
    MoveCategory = engine and engine.exports.MoveCategory or nil,
  }

  -- --------------------------------------------------------------- screens
  -- Each factory answers (mod, ctx) -> screen module with .new.  A module that
  -- failed to load is simply not installed, so the engine's builtin screen
  -- stays in place for that id instead of the game losing a screen.
  local installed = {}
  local function install(id, file)
    local factory = loadSibling(file)
    if not factory then return false end
    local screen = factory(mod, ctx)
    if type(screen) ~= "table" or type(screen.new) ~= "function" then
      warn("g9-gui: " .. file .. " did not return a screen module")
      return false
    end
    local ok, err = pcall(function()
      mod.content.screens:register(id, { new = screen.new })
    end)
    if not ok then
      warn("g9-gui: could not register the " .. id .. " screen: " .. tostring(err))
      return false
    end
    installed[#installed + 1] = id
    return true
  end

  install("StartMenu", "ui/start_menu.lua")
  install("PartyMenu", "ui/party_menu.lua")
  install("SummaryMenu", "ui/summary.lua")
  -- The pages the START menu's other rows open.  Same page, same surface, same
  -- type -- so ITEM, POKeDEX, the player-name card and OPTION are all the same
  -- size as the START and POKeMON screens rather than falling back to the
  -- classic 160x144 letterbox.
  install("BagMenu", "ui/bag.lua")
  install("PokedexMenu", "ui/pokedex.lua")
  install("OptionsMenu", "ui/options.lua")
  install("TrainerCard", "ui/trainer_card.lua")
  install("ManagerState", "ui/manager.lua")
  -- ...and the leaf page POKeDEX opens on a species (its own A), so the whole
  -- START menu tree is the one design rather than dropping back to the
  -- classic 160x144 entry page two levels down.
  install("DexEntryMenu", "ui/dex_entry.lua")

  if #installed == 0 then
    warn("g9-gui: no screens were installed")
    return
  end

  info(("g9-gui: modern UI installed for %s (background %s, embellishments %s, "
    .. "portraits %s, modern stats %s)"):format(
    table.concat(installed, ", "),
    on("ui_background") and "on" or "off",
    on("ui_embellishment") and "on" or "off",
    opt("ui_portraits") or "sprites",
    (engine and engine.exports.ModernStats) and "on" or "off"))
end
