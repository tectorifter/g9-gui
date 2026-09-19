-- =============================================================================
-- g9-gui -- "modern UI & stats"
--
-- A full-screen modern menu suite for Gen 1 (Red / Blue / Yellow) on the
-- gen1recomp engine.  These engine screens are REPLACED by this mod:
--
--   * StartMenu    -> ui/start_menu.lua  the FF12-shaped START screen: the
--                    vanilla rows in a word-list column on the left, the live
--                    party roster (portrait card, name, level, HP and an EXP
--                    bar) on the right.  SAVE and QUIT open this mod's own
--                    modals (ui/dialogs.lua) instead of the classic boxes.
--   * PartyMenu    -> ui/party_menu.lua  the POKeMON screen: the SAME page --
--                    same surface, same header, same left rail, same roster --
--                    with the engine's own submenu as a modern popup.
--   * SummaryMenu  -> ui/summary.lua     Adv.Stats in a 486x324 panel (90% of
--                    the 540x360 surface) floated OVER the POKeMON screen, so
--                    the menu stays visible around it.
--   * TitleState   -> ui/title.lua       the boot title screen, kept whole
--                    (logo, cycling mon, copyright, cinematic) except its
--                    CONTINUE / NEW GAME / OPTION / EXIT GAME menu and the
--                    CONTINUE save-data window, which become this mod's page
--                    and card.
--   * QuarantineReport -> ui/load_report.lua  the one-shot LOAD REPORT shown
--                    after a save is read and something in it changed.
--
-- Two screens this mod does NOT own are re-skinned IN PLACE when another mod
-- pushes them -- their own mods stay whole and are never outdated:
--   * G9Train   -> ui/train.lua     g9-battle-engine's party-submenu TRAIN
--                    editor (IV/EV/NAT/gender/ability/moves).  The engine's
--                    state, its ModernStats commit and its fee arithmetic keep
--                    running; only the page it draws on changes.
--   * G9Blacklist -> ui/blacklist.lua  g9-battle-sample's OPTIONS BLACKLIST
--                    window.  The sample's filters, cursor and every write keep
--                    running; only the drawn page changes.
--   * every dialogue window -> ui/textbox.lua  the engine's src.render.TextBox
--                    -- the box every conversation, sign and battle message
--                    prints through.  It is not a screen and has no id: it
--                    identifies itself with isTextBox, and the same wrapper
--                    dresses it.  The engine keeps paginating, typing and
--                    waiting for A; only the drawn window changes.  Unlike
--                    every screen above it, the box's surface is NOT grown --
--                    doing that would pull Renderer:fitScale down and zoom the
--                    world out.  Instead the card is painted in WINDOW space
--                    through the engine's render.hud hook, so the panel and
--                    its type are rasterised at the window's own resolution
--                    while the box stays exactly the 20x6 tiles it always was.
-- All of them are caught at the one choke point every state goes through, a
-- StateStack.push wrapper (main.lua), so they need no cooperation from the
-- mods that own them (and none from the engine's own TextBox either).
--
-- ui/dialogs.lua carries the modals every tree shares: the save-data card,
-- the YES/NO confirmation and the auto-advancing notice (the SAVE flow's
-- "Now saving..." and "RED saved the game!").
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
-- GEN 2: Gold/Silver/Crystal are ported phase by phase (src/g9-gui/GEN2-PORT.md).
-- Gold registers its screens under Gen2* ids and paints a widescreen layer
-- instead of answering :uiSize(), so a Gen 2 arm of a screen builds the SAME
-- engine object, keeps every behaviour, and swaps only :drawWidescreen -- the
-- 540x360 page scaled into the window.  Since 2.5.0 the manifest loads on both
-- games -- START was the first Gen 2 takeover, joined by POKeMON and the
-- summary in 2.5.1, the PACK and the POKeDEX in 2.5.2, OPTION, the trainer
-- card and the mod manager in 2.5.3, and the boot MAIN MENU in 2.5.4.  Gen 2 is
-- now COMPLETE: 2.5.5 adds the three skins (TRAIN, BLACKLIST and the shared
-- dialogue card), which are draw-only takeovers of states other mods push, so
-- they need no Gen2* id -- the same push wrapper dresses them on Gold.  A
-- screen with no Gen 2 arm keeps the engine's native screen on a Gold boot.
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

  -- Everything below that BUILDS something from a sibling file runs through
  -- this.  An error anywhere in the entry chunk makes the loader roll back
  -- every registration this mod made, so one broken or missing sibling used to
  -- take the ENTIRE suite down with it -- every screen reverting to the
  -- classic UI with only a log line to say why.  A failure here is logged and
  -- that one piece is skipped instead, so the rest of the mod still installs.
  local function attempt(label, fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if not ok then
      warn("g9-gui: " .. label .. " failed: " .. tostring(a))
      return nil
    end
    return a, b, c
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

  -- ------------------------------------------------------- generation gate
  -- Which generation is booting.  This used to be a hard gate that bailed on
  -- Gen 2; it now only decides WHICH screen ids get installed (Gold prefixes
  -- its ids with Gen2, src/ui/Screens.lua) and which arm of each screen module
  -- runs.  Everything below is generation-aware, and a screen with no Gen 2 arm
  -- yet is simply not installed on Gold, so its native screen stays in place.
  local gen = 1
  do
    local ok, value = pcall(function()
      local GameVersion = require("src.core.GameVersion")
      return GameVersion.generation(GameVersion.get())
    end)
    if ok and value then gen = value end
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
  -- theme/backdrop/shell/portraits/roster are the modules EVERY screen needs,
  -- so they stay a hard requirement: without them there is no page to draw.
  -- dialogs/title/load_report are loaded per-screen below and may fail alone.
  local Theme = loadSibling("ui/theme.lua")
  local Backdrop = loadSibling("ui/backdrop.lua")
  local Shell = loadSibling("ui/shell.lua")
  local Portraits = loadSibling("ui/portraits.lua")
  local Roster = loadSibling("ui/roster.lua")
  if not (Theme and Backdrop and Shell and Portraits and Roster) then
    warn("g9-gui: shared ui modules failed to load -- no screens installed")
    return
  end
  Theme = attempt("ui/theme.lua init", Theme, mod)
  Backdrop = attempt("ui/backdrop.lua init", Backdrop, mod)
  Shell = attempt("ui/shell.lua init", Shell, mod)
  Portraits = attempt("ui/portraits.lua init", Portraits, mod)
  Roster = attempt("ui/roster.lua init", Roster, mod)
  if not (Theme and Backdrop and Shell and Portraits and Roster) then
    warn("g9-gui: shared ui modules failed to initialise -- no screens installed")
    return
  end

  local ctx = {
    mod = mod,
    gen = gen,
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
  -- national_dex compatibility (ui/national_dex.lua).  Optional: it is what
  -- lets the POKeDEX and the species entry page draw the mod's own view modes,
  -- STATS page and evolution/learnset strip on the suite's pages, and it is
  -- inert the moment national_dex is not installed -- every reader goes through
  -- the peer's published exports and there is nothing to reach without them.
  -- Put on ctx so both screen factories (and the entry page especially) can
  -- ask it what the peer offers.
  local NatDex = loadSibling("ui/national_dex.lua")
  ctx.NatDex = NatDex and attempt("ui/national_dex.lua init", NatDex, mod, ctx)
    or nil
  if ctx.NatDex and ctx.NatDex.installed then
    info(("g9-gui: national_dex %s found -- the POKeDEX listing and entry "
      .. "pages will draw its view modes, STATS page and species strip")
      :format(tostring(ctx.NatDex.version or "?")))
  end

  -- the modern modals (SAVE / QUIT / notices) the START screen and the title
  -- menu share; built from the same ctx the screen factories get.  If this one
  -- file fails, the screens that do NOT need it still install and SAVE/QUIT
  -- simply keep the engine's classic boxes (see ui/start_menu.lua / title.lua).
  local Dialogs = loadSibling("ui/dialogs.lua")
  ctx.Dialogs = Dialogs and attempt("ui/dialogs.lua init", Dialogs, mod, ctx)
    or nil
  if not ctx.Dialogs then
    warn("g9-gui: the modal dialogs failed to load -- SAVE and QUIT keep the "
      .. "engine's classic prompts (see ui/dialogs.lua)")
  end

  -- --------------------------------------------------------------- screens
  -- Each factory answers (mod, ctx) -> screen module with .new.  A module that
  -- failed to load is simply not installed, so the engine's builtin screen
  -- stays in place for that id instead of the game losing a screen.
  local installed = {}
  local function install(id, file)
    local factory = loadSibling(file)
    if not factory then return false end
    local screen = attempt(file .. " (screen factory)", factory, mod, ctx)
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

  if gen == 2 then
    -- ------------------------------------------------------ Gen 2 (Gold) ids
    -- The Gen 2 port ships in phases (src/g9-gui/GEN2-PORT.md).  Each entry
    -- here is a screen whose module has a Gen 2 arm behind ctx.gen; Gold's
    -- registry names them with the Gen2 prefix (src/ui/Screens.lua), so the
    -- same module answers both ids depending on the boot.  A screen not listed
    -- here keeps the engine's native Gen 2 screen -- never a broken page.
    install("Gen2StartMenu", "ui/start_menu.lua")
    install("Gen2PartyMenu", "ui/party_menu.lua")
    install("Gen2SummaryMenu", "ui/summary.lua")
    install("Gen2PackMenu", "ui/bag.lua")
    install("Gen2PokedexMenu", "ui/pokedex.lua")
    install("Gen2OptionsMenu", "ui/options.lua")
    install("Gen2TrainerCard", "ui/trainer_card.lua")
    -- the boot menu: Gold's own Gen2TitleState keeps its engine cinematic, and
    -- its A/START only pushes Gen2MainMenu, which is the screen taken over here
    -- (the CONTINUE / NEW GAME / OPTION / EXIT GAME list and its CONTINUE save
    -- panel) -- see ui/title.lua's gen 2 arm
    install("Gen2MainMenu", "ui/title.lua")
    -- the mod manager keeps its id on both generations (src/ui/Screens.lua's
    -- BUILTIN table), so Gold's push reaches this same takeover
    install("ManagerState", "ui/manager.lua")
  else
    install("StartMenu", "ui/start_menu.lua")
    install("PartyMenu", "ui/party_menu.lua")
    install("SummaryMenu", "ui/summary.lua")
    -- The pages the START menu's other rows open.  Same page, same surface,
    -- same type -- so ITEM, POKeDEX, the player-name card and OPTION are all
    -- the same size as the START and POKeMON screens rather than falling back
    -- to the classic 160x144 letterbox.
    install("BagMenu", "ui/bag.lua")
    install("PokedexMenu", "ui/pokedex.lua")
    install("OptionsMenu", "ui/options.lua")
    install("TrainerCard", "ui/trainer_card.lua")
    install("ManagerState", "ui/manager.lua")
    -- ...and the leaf page POKeDEX opens on a species (its own A), so the
    -- whole START menu tree is the one design rather than dropping back to
    -- the classic 160x144 entry page two levels down.
    install("DexEntryMenu", "ui/dex_entry.lua")

    -- The title / boot screen's own main menu (CONTINUE / NEW GAME / OPTION /
    -- EXIT GAME) and its CONTINUE save-data window, and the one-shot LOAD
    -- REPORT the validation pass shows before the overworld.  Both takeovers
    -- keep the engine state whole (the whole title cinematic in the first
    -- case) and only redecorate the boxed menus.
    install("TitleState", "ui/title.lua")
    install("QuarantineReport", "ui/load_report.lua")
  end

  -- --------------------------------------------------- TRAIN / BLACKLIST skins
  -- g9-battle-engine's TRAIN screen (screenId "G9Train", pushed from the party
  -- submenu) and g9-battle-sample's BLACKLIST window (screenId "G9Blacklist",
  -- pushed from the OPTIONS row) are NOT registered here -- they belong to
  -- those mods and stay whole.  g9-gui only DRESSES the instance when it is
  -- pushed: a StateStack.push wrapper swaps the surface and the draw of a
  -- G9Train / G9Blacklist state, whose own update, state machine and data
  -- writes keep running untouched.  So the engine's TRAIN and the sample's
  -- BLACKLIST are never outdated -- they are only re-skinned while this mod is
  -- installed.  Each skin fails independently, like every other piece.
  local takeovers = {}
  -- Gen 2 arm (G6): the three skins now install on BOTH generations.  Each
  -- peer runs on Gold -- g9-battle-engine and g9-battle-sample both declare
  -- games = gen1/gen2, and each owner screen already publishes its own Gen 2
  -- wide-panel contract (drawsWidescreen / drawWidescreen / panelSize) -- and
  -- src.render.TextBox is the ONE shared dialogue class on both generations.
  -- So each skin is generation-aware: on Gold, ui/train.lua and ui/blacklist.lua
  -- swap the instance's surface trio for the suite's 540x360 page through
  -- Shell.gen2Surface, and the dialogue card simply takes the surface space
  -- because Game2 has no renderer with frameRects, so the window-space path
  -- never activates (ui/textbox.lua -- window-space density stays Gen 1 only).
  local Train = loadSibling("ui/train.lua")
  if Train then Train = attempt("ui/train.lua init", Train, mod, ctx) end
  if type(Train) == "table" and type(Train.dress) == "function" then
    takeovers[#takeovers + 1] = "TRAIN"
    takeovers.Train = Train
  end
  local Blacklist = loadSibling("ui/blacklist.lua")
  if Blacklist then
    Blacklist = attempt("ui/blacklist.lua init", Blacklist, mod, ctx)
  end
  if type(Blacklist) == "table" and type(Blacklist.dress) == "function" then
    takeovers[#takeovers + 1] = "BLACKLIST"
    takeovers.Blacklist = Blacklist
  end
  -- ...and the one state EVERY conversation in the game goes through: the
  -- engine's src.render.TextBox, dressed into the modern card (ui/textbox.lua).
  -- There is no screen id to register -- a TextBox identifies itself with
  -- isTextBox -- so it is caught here by the same wrapper.
  local Textbox = loadSibling("ui/textbox.lua")
  if Textbox then Textbox = attempt("ui/textbox.lua init", Textbox, mod, ctx) end
  if type(Textbox) == "table" and type(Textbox.dress) == "function" then
    takeovers[#takeovers + 1] = "DIALOGUE"
    takeovers.Textbox = Textbox
  end
  if #takeovers > 0 then
    local okS, StateStack = pcall(require, "src.core.StateStack")
    if okS and type(StateStack) == "table"
        and type(StateStack.push) == "function"
        and not StateStack.__g9guiTakeover then
      StateStack.__g9guiTakeover = true
      local vanillaPush = StateStack.push
      StateStack.push = function(self, state, ...)
        vanillaPush(self, state, ...)
        if type(state) ~= "table" then return end
        local ok, err = pcall(function()
          if state.screenId == "G9Train" and takeovers.Train then
            takeovers.Train.dress(state)
          elseif state.screenId == "G9Blacklist" and takeovers.Blacklist then
            takeovers.Blacklist.dress(state)
          elseif state.isTextBox and takeovers.Textbox
              and not takeovers.Textbox.surfaceIsWide(state) then
            -- a battle (or one of this mod's own wide pages) composing its own
            -- surface keeps the classic box: the box is then centred inside
            -- the wide canvas and a card drawn in that space would land wrong
            takeovers.Textbox.dress(state)
          end
        end)
        if not ok then
          warn("g9-gui: could not modernise a pushed screen: "
            .. tostring(err))
        end
      end
    end
    installed[#installed + 1] = "skins: " .. table.concat(takeovers, ", ")
  end

  -- ------------------------------------------------------- window-space dialogue
  -- The dialogue card's density half: ui/textbox.lua paints the box at native
  -- window resolution through the engine's render.hud hook (see its header for
  -- why the surface must NOT grow).  This is the one place the mod subscribes
  -- a frame hook, and it is deliberately fail-open -- without it the skin
  -- draws the same card in the classic 160x144 surface, so a hook failure
  -- costs sharpness and nothing else.
  if takeovers.Textbox and type(takeovers.Textbox.installHook) == "function" then
    local okH, hooked = pcall(takeovers.Textbox.installHook, mod)
    if okH and hooked then
      installed[#installed + 1] = "dialogue: window-space"
    elseif not okH then
      warn("g9-gui: window-space dialogue unavailable, keeping the surface "
        .. "card: " .. tostring(hooked))
    end
  end

  -- The re-flow: paging the box's text at the dialogue font's own width, so a
  -- smaller `box` genuinely fits more glyphs per line (ui/textbox.lua has the
  -- why).  Load-time and fail-open, like the hook above -- without it the card
  -- still draws, just with the engine's 18-glyph lines and (at 10) more empty
  -- space at the right.
  if takeovers.Textbox and type(takeovers.Textbox.installWrap) == "function" then
    local okW, wrapped = pcall(takeovers.Textbox.installWrap)
    if okW and wrapped then
      installed[#installed + 1] = "dialogue: reflow"
    elseif not okW then
      warn("g9-gui: dialogue re-flow unavailable, keeping the engine pages: "
        .. tostring(wrapped))
    end
  end

  if #installed == 0 then
    warn("g9-gui: no screens were installed")
    return
  end

  info(("g9-gui: modern UI installed on Gen %d for %s (modals %s, "
    .. "background %s, embellishments %s, portraits %s, modern stats %s)")
    :format(
    gen, table.concat(installed, ", "),
    ctx.Dialogs and "on" or "CLASSIC",
    on("ui_background") and "on" or "off",
    on("ui_embellishment") and "on" or "off",
    opt("ui_portraits") or "sprites",
    (engine and engine.exports.ModernStats) and "on" or "off"))
end
