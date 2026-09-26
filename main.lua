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
--   * EvolutionState / Gen2EvolutionAnim -> ui/evolution.lua  the evolution
--                    movie on BOTH generations: the engine's own animation
--                    (cry, flash, cancel, reveal, learn-move run) on this
--                    suite's page, with the creature drawn from the
--                    g9-battle-sprites pack's front battle sheets.
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
--   * every YES/NO (and labelled two-option) prompt -> ui/choice.lua  the
--                    engine's src.ui.ChoiceBox, which rides just above that
--                    card.  Since 2.6.7 it is modernised on BOTH generations,
--                    painted through the dialogue card's own window space.
--   * every PC page -> ui/pc.lua  the Pokecenter PC's own top menu, the
--                    player's ITEM storage menu and its WITHDRAW / DEPOSIT /
--                    TOSS lists, BILL's PC storage menu and its WITHDRAW /
--                    DEPOSIT / RELEASE lists, and the CHANGE BOX picker.
--                    The engine builds the real src.ui.Menu / ListMenu and
--                    keeps its cursor, keepOpen flow and every item / mon
--                    write; this skin swaps only the surface and the page.
--                    The lists and the picker are caught by the engine's own
--                    "pc_*" kind; the top menu has neither an id nor a kind
--                    and is pushed from a text box's callback, so
--                    OverworldState:openPC is wrapped to mark it.
--                    Since 2.7.0 every Gold PC screen is dressed too -- Gold's
--                    five PC classes are BESPOKE (not Menu/ListMenu), so they
--                    are recognised by the screenId their own push stamps and
--                    dressed at this same wrapper (G2_SCREENS in ui/pc.lua);
--                    the item PC's DEPOSIT phase hands the page to ui/bag.lua's
--                    own PACK painter, exactly as the engine's drawPanel drew
--                    the pack window inside the item PC.
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
--   ui_pc_row        ON/OFF  -- an extra PC row in the START rail (off)
--   color_protection ON/OFF  -- keep the native COLORS / COLOR mode off the
--                                modern pages on both generations (ON)
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
-- 2.6.4 closes the two places the POKeMON page could still drop to the cart:
-- the ITEM row's GIVE/TAKE menu (ui/held_item.lua, the Gen2HeldItemMenu id) and
-- the engine's shared YES/NO box (ui/choice.lua, dressed at the push wrapper
-- like the dialogue card).  It also stops a taken-over page's native :draw()
-- painting UNDER the modern page when Game2 runs its stack pass beneath a
-- pushed TextBox (ui/shell.lua gen2Surface).  2.6.7 brings the window-space
-- density to Gold (the dialogue card and the YES/NO skin read Game2's own
-- render.hud viewport payload and paint at native resolution, not into the
-- blitted 160x144 canvas), modernises the Gold SAVE flow through
-- ui/dialogs.lua, and answers LEFT/RIGHT directionally on the save and QUIT
-- confirms.
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

  -- The rows options.lua declares as a straight ON/OFF boolean choice.  Their
  -- stored value is "true"/"false" and every reader in this suite compares it
  -- textually ("~= \"false\"", `on`), so a boot that reports the same row as a
  -- boolean, a number or the choice's own LABEL ("ON"/"OFF") must still read as
  -- that same string.  The Android report that flipped g9-Battle-Scene's
  -- learner row is exactly this -- the platform handed the row back as "ON"
  -- rather than "on"/"true" -- so the whole suite reads its rows through this
  -- one normaliser rather than each screen's own exact compare.
  --
  -- The rows that are NOT booleans keep their own value spellings ("sprites",
  -- "icons", the HP guard's "catch"/"log"/"off") and must pass through
  -- untouched: "off" there is a real mode, not a synonym for "false".  Only a
  -- boolean or numeric SHAPE is coerced for those, never a string.
  local BOOLEAN_ROWS = {
    modern_ui = true,
    ui_background = true,
    ui_embellishment = true,
    ui_pc_row = true,
    color_protection = true,
    short_heal_chat = true,
    translation = true,
  }
  local function normalise(key, v)
    if v == true then return "true" end
    if v == false then return "false" end
    if type(v) == "number" then return v ~= 0 and "true" or "false" end
    if BOOLEAN_ROWS[key] and type(v) == "string" then
      local s = v:lower()
      if s == "on" or s == "true" or s == "yes" or s == "1" then return "true" end
      if s == "off" or s == "false" or s == "no" or s == "0" then return "false" end
    end
    return v
  end
  local function opt(key)
    return normalise(key, mod.options:get(key))
  end

  -- A boolean read.  `opt` has already normalised the row, so "true"/"false"
  -- are the usual cases; the wider spellings are kept as a belt-and-braces
  -- fallback (a value `normalise` did not recognise, or a row read straight
  -- from a manager that bypassed it).  A nil (row missing) or an unknown shape
  -- reads as ON, so a partial schema can never silently disable the mod.
  local function on(key)
    local v = opt(key)
    if v == true then return true end
    if v == false then return false end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
      local s = v:lower()
      if s == "off" or s == "false" or s == "no" or s == "0" or s == "" then
        return false
      end
    end
    return true
  end

  -- Published BEFORE the MODERN UI gate below, because g9-battle-engine reads
  -- it for the Pokecenter chat and must get an answer even when this mod's own
  -- screens are switched off. mod.options:get only ever sees the CALLING mod's
  -- own bucket, so the engine mod (a different mod) cannot read this row
  -- directly -- this export is the supported cross-mod route.
  mod.exports.shortHealChatEnabled = function()
    return on("short_heal_chat")
  end

  -- ------------------------------------------ modern-content translation
  -- (see ui/translation.lua.)  The translation-mod generator's output patches
  -- the game's Gen 1/2 names, but it cannot reach the expanded dex this suite's
  -- peer national_dex adds -- species 152+, and their moves, items and
  -- abilities -- so those stay English under a translated game.  This layer
  -- detects the translation mod, loads the matching modern-content catalog
  -- (Latin American Spanish ships today) and folds its names into the same
  -- content registries the translation mod uses, so EVERY consumer (this
  -- suite, the engine's own battle HUD and Pokedex, national_dex and the battle
  -- scene) reads a translated name without knowing this ran.
  --
  -- Ordering matters twice over: the patches must run BEFORE the content
  -- freeze (so they merge like any other contribution) and BEFORE
  -- display_names below, so a form record inherits its base species' translated
  -- name.  So it is installed HERE, before both, and -- like display_names --
  -- before the MODERN UI gate: the records are the game's, not one page's.
  --
  -- Fail-open at every step (unknown language, missing catalog, absent option):
  -- the lookup simply returns its input and the screens show English.
  local Translation = loadSibling("ui/translation.lua")
  if Translation then
    Translation = attempt("ui/translation.lua init", Translation, mod,
      { on = on, opt = opt, info = info })
  end
  if type(Translation) == "table"
      and type(Translation.install) == "function" then
    attempt("ui/translation.lua install", Translation.install)
  end
  -- Published for this suite's screens (ctx.Translation, below) and for peer
  -- g9 UI mods: `mod.find("g9-gui").exports.translation`.  Other mods use it
  -- for ability names (no registry) and for the symbol font fallback; see the
  -- module header.
  mod.exports.translation = Translation

  -- ------------------------------------------------- species display names
  -- Rewrite every alternate form's record `name` to the name the player should
  -- read (see ui/display_names.lua for the rule and why it is a record edit).
  -- Deliberately BEFORE the MODERN UI gate: the engine's own Pokedex entry
  -- page, party list and battle HUD read the same records, so this is the
  -- game's naming, not one page's, and it must hold even with the modern
  -- screens switched off.  national_dex ships priority 90 and this mod 100, so
  -- its records are already registered here; with national_dex absent the
  -- loop finds no forms and changes nothing.
  local DisplayNames = loadSibling("ui/display_names.lua")
  if DisplayNames and type(DisplayNames.apply) == "function" then
    local changed = attempt("ui/display_names.lua apply",
      DisplayNames.apply, mod)
    if type(changed) == "number" then
      info(("g9-gui: species display names -- %d form record%s renamed")
        :format(changed, changed == 1 and "" or "s"))
    end
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
  -- The party-HP sentinel (ui/hp_guard.lua).  Optional and fail-open: if it
  -- does not load the two menu pages simply browse without it, exactly as
  -- they did before it existed.
  local HPGuard = loadSibling("ui/hp_guard.lua")
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

  -- Give the shared Theme the full modern-content localizer (ui/translation.lua's
  -- M.line -- the `ui` lexicon, the engine's own `strings` for a label the ROM
  -- also carries, then the `messages` / `messageTemplates` sentences) so every
  -- string the modern screens draw -- footer hints, the header readouts, the
  -- START captions, the PC/box/storage page, the party-submenu rows peer mods
  -- append, a notice like "You can't leave while holding a POKéMON." -- localizes
  -- with the game.  A no-op whenever no translation mod is active or the
  -- TRANSLATION row is off (M.line falls straight through then).
  if Translation and type(Translation.line) == "function" then
    Theme.setLocalizer(function(text) return Translation.line(text) end)
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
    -- The modern-content translation layer (ui/translation.lua): the screens
    -- read ctx.Translation.ability(name) for ability strings, which -- unlike
    -- species/move/item names -- have no content registry to patch.
    Translation = Translation,
  }
  -- The COLOR PROTECTION toggle (ui/color_protection.lua).  It wraps the
  -- engine's render.zones seam so a modern page is blitted with the palette
  -- shader switched off, keeping gen1recomp's COLORS / COLOR option from
  -- repainting the suite on either generation.  Fail-open: without the hook
  -- API the screens simply keep their current (already colour-correct in the
  -- non-mono modes) behaviour; the row defaults ON.
  local ColorProtection = loadSibling("ui/color_protection.lua")
  ctx.ColorProtection = ColorProtection
    and attempt("ui/color_protection.lua init", ColorProtection, mod, ctx) or nil
  if ctx.ColorProtection then
    if not ctx.ColorProtection.install() then
      info("g9-gui: color protection unavailable -- the render.zones hook is "
        .. "not exposed by this engine")
    end
  end
  -- Build the HP sentinel and read its Mod Manager row.  Both fail open: no
  -- guard, or an unreadable option, only means the two menu pages browse
  -- without the net (see ui/hp_guard.lua).
  if HPGuard then
    ctx.HPGuard = attempt("ui/hp_guard.lua init", HPGuard, mod)
    if ctx.HPGuard then
      local mode = "catch"
      local okMode, value = pcall(opt, "ui_hp_guard")
      if okMode and type(value) == "string" then mode = value end
      ctx.HPGuard.setMode(mode)
    end
  end
  -- national_dex compatibility (ui/national_dex.lua).  Optional: it is what
  -- lets the POKeDEX draw the peer's roster in number order and the species
  -- entry page draw its STATS page and evolution/learnset strip on the suite's
  -- pages, and it is inert the moment national_dex is not installed -- every
  -- reader goes through the peer's published exports and there is nothing to
  -- reach without them.
  -- Put on ctx so both screen factories (and the entry page especially) can
  -- ask it what the peer offers.
  local NatDex = loadSibling("ui/national_dex.lua")
  ctx.NatDex = NatDex and attempt("ui/national_dex.lua init", NatDex, mod, ctx)
    or nil
  if ctx.NatDex and ctx.NatDex.installed then
    info(("g9-gui: national_dex %s found -- the POKeDEX listing draws its full "
      .. "roster in number order and its entry pages gain the STATS page and "
      .. "the species strip"):format(tostring(ctx.NatDex.version or "?")))
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

  -- ------------------------------------------------ bag capacity / pockets
  -- ui/bag_util.lua carries the bag's raised capacity (300 slots, x999 per
  -- item -- see the module header), its overflow guards and the six Gen 1
  -- pockets, adapted from the "Useful Bag" mod.  It stands down on its own if
  -- Useful Bag is installed, so the two never fight over one constant.  The
  -- install runs before the screens so the capacity is live the moment a bag
  -- can open; the sort keys (TAB / R3 / touch SELECT) are bound at game.ready.
  local BagUtil = loadSibling("ui/bag_util.lua")
  ctx.BagUtil = BagUtil and attempt("ui/bag_util.lua init", BagUtil, mod, ctx)
    or nil
  if ctx.BagUtil then
    local okB, enabled = pcall(ctx.BagUtil.install)
    if not okB then
      warn("g9-gui: bag capacity could not be installed: " .. tostring(enabled))
    elseif enabled then
      mod.events:on("game.ready", function()
        pcall(ctx.BagUtil.installInput)
      end)
    end
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
    -- the mart: Gold's own bespoke MartMenu, drawn as the same page (the sell
    -- phase's pack is the modern PACK above, via ctx.Bag.drawGen2)
    install("Gen2MartMenu", "ui/shop.lua")
    -- the held-item menu the party submenu's ITEM row opens.  It is not part of
    -- the START tree -- Gold pushes it over the POKeMON page -- so without this
    -- the ITEM row dropped to the cart's white GIVE/TAKE window (ui/held_item.lua)
    install("Gen2HeldItemMenu", "ui/held_item.lua")
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
    -- the evolution movie (engine/movie/evolution_animation.asm).  Gold pushes
    -- src.ui.gen2.EvolutionAnim under the Gen2EvolutionAnim id; the module
    -- keeps the engine's whole state machine (cry, flash rounds, the B-press
    -- cancel, the reveal and the learn-move run) and paints the suite's page
    -- through :drawWidescreen, with the creature drawn from g9-battle-sprites'
    -- own front sheets (ui/evolution.lua)
    install("Gen2EvolutionAnim", "ui/evolution.lua")
  else
    install("StartMenu", "ui/start_menu.lua")
    install("PartyMenu", "ui/party_menu.lua")
    install("SummaryMenu", "ui/summary.lua")
    -- The pages the START menu's other rows open.  Same page, same surface,
    -- same type -- so ITEM, POKeDEX, the player-name card and OPTION are all
    -- the same size as the START and POKeMON screens rather than falling back
    -- to the classic 160x144 letterbox.
    install("BagMenu", "ui/bag.lua")
    -- the mart: the engine's ShopMenu built and amended, and its pushed buy /
    -- sell lists dressed at the wrapper below (the sell list is drawn as the
    -- bag page, matching the Gen 2 arm)
    install("ShopMenu", "ui/shop.lua")
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

    -- The evolution movie (engine/movie/evolution.asm).  src.ui.EvolutionState
    -- is pushed on a level-up / stone / trade evolution; the module keeps the
    -- engine's whole state machine (loading, the cry, the accelerating flash,
    -- the B-press cancel and the post-evolution learn run) and only paints the
    -- suite's 540x360 page, with the creature drawn from g9-battle-sprites'
    -- own front sheets (ui/evolution.lua).
    install("EvolutionState", "ui/evolution.lua")
  end

  -- ------------------------------------------------------- the move learner
  -- The engine's own src.ui.MoveLearnMenu -- the "X is trying to learn Y! ...
  -- Delete an older move?" question and its four-move forget list -- on the
  -- suite's page (ui/move_learn.lua).  It is registered under the ENGINE's own
  -- id on BOTH generations, because the engine emits no Gen2 prefix for it
  -- (src/ui/Screens.lua's GEN2 list has no MoveLearn): Gold's move learning is
  -- handled inside Gen2BattleState, so only a peer mod that pushes the engine's
  -- screen (g9-Battle-Scene's in-battle learn pause) reaches it there, and it
  -- reaches it by this same id.  Registering it means EVERY caller gets the
  -- modern page -- the native battle queue, the bag's TM use, the evolution's
  -- learn run and the battle scene alike.
  --
  -- The id is also PUBLISHED as mod.exports.moveLearnScreenId, so a peer mod
  -- that pushes the learner can tell the modern screen is live and skip its own
  -- fallback chrome (see g9-Battle-Scene's FN.guiMoveLearnId).  Set only when
  -- the screen really registered -- a g9-gui with MODERN UI off, a failed
  -- sibling or a partial install leaves the export unset, which is how that
  -- peer knows to fall back to the engine's classic screen.
  if install("MoveLearnMenu", "ui/move_learn.lua") then
    mod.exports.moveLearnScreenId = "MoveLearnMenu"
  end

  -- ------------------------------------------------ the registry refresh
  -- The engine resolves a screen id through src.ui.Screens, which MEMOISES
  -- every factory it hands out (`resolve` keeps `cache[id]`, Screens.lua).  A
  -- mod's registration is NOT in `game.data.screens` while the entry chunks
  -- run: the loader folds every content registry's ops into the live data
  -- only AFTER every enabled mod has initialised (src/mods/Registry.lua, and
  -- the loader's freeze at the end of its pass).  So an id resolved during the
  -- load phase -- by an earlier-loading mod, or by a boot step whose order
  -- differs by platform -- memoises the ENGINE's builtin, and that stale entry
  -- then shadows this suite's record for the whole session: every later push of
  -- that id (the engine's own START screen, the native battle queue's move
  -- learner, the bag's TM use, the evolution's learn run) gets the classic
  -- screen instead of this mod's page.  A desktop boot that resolves nothing
  -- early works; a boot that does falls back -- exactly the "works fine on PC,
  -- falls to the native screen on Android" report (the same class of
  -- platform-shaped routing fault g9-Battle-Scene's FN.pushLearner already
  -- works around for its in-battle learner, and the reason the move learner is
  -- the screen a user notices: it is opened mid-battle, far from the menu).
  --
  -- The cure is one cache drop AFTER the merge.  `game.ready` fires once every
  -- service is up and every registry has been folded in (src/core/Game.lua),
  -- and just before the boot pushes its first screen, so clearing the cache
  -- there means the next resolve of EVERY id re-reads the live data -- this
  -- suite's records included -- instead of a builtin memoised too early.
  -- Dropping the cache is always safe: it holds factories, never state, and
  -- re-resolving simply re-reads `game.data.screens`.  Fail-open as everywhere
  -- else: an engine without Screens.invalidate, or a frozen require, leaves the
  -- cache exactly as it was before this block existed.
  local function refreshScreens()
    local ok, Screens = pcall(require, "src.ui.Screens")
    if not ok or type(Screens) ~= "table"
        or type(Screens.invalidate) ~= "function" then
      return false
    end
    return pcall(Screens.invalidate)
  end
  -- One drop now (harmless before the merge, and correct after a hot reload),
  -- then the one that matters, after every registry has been folded in.
  refreshScreens()
  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("game.ready", function(payload)
      refreshScreens()
      -- One diagnostic line, so a platform whose boot still cannot reach a
      -- modern screen is visible in the log rather than silent: is the
      -- learner's record really in the live data after the merge?
      local game = payload and payload.game
      local screens = game and game.data and game.data.screens
      local id = mod.exports.moveLearnScreenId
      if id and screens then
        if screens[id] then
          info(("g9-gui: screen registry refreshed after boot -- modern learner "
            .. "record '%s' is registered"):format(id))
        else
          warn(("g9-gui: screen registry refreshed after boot but the modern "
            .. "learner record '%s' is MISSING from the live screens data -- "
            .. "the classic learner will answer"):format(id))
        end
      end
    end)
  end

  -- ------------------------------------------- the Gold out-of-battle learner
  -- Gold has no learner SCREEN: every out-of-battle learn -- a TM used from the
  -- PACK (the party screen picks the mon first), a RARE CANDY's level moves, an
  -- evolution's new move, the move tutor's -- runs inside Game2:learnMoveOn,
  -- which draws the exchange as engine TextBoxes plus the native forget list.
  -- Registering MoveLearnMenu therefore does nothing for those flows on Gold
  -- (only g9-Battle-Scene's in-battle pause reaches the screen there), which is
  -- why the modern learner never appeared when a move was learned from the
  -- party flow.  ui/gold_learner.lua wraps that one entry point and routes the
  -- four-slots-full case through this suite's registered page, with the
  -- caller's own onDone threaded through so every continuation still runs.
  -- Gold only; Gen 1's engine already pushes the screen above.  Fail-open:
  -- without Game2, or with no mod-owned learner, the engine's own flow stays.
  if gen == 2 then
    local GoldLearner = loadSibling("ui/gold_learner.lua")
    if GoldLearner then
      GoldLearner = attempt("ui/gold_learner.lua init", GoldLearner, mod, ctx)
    end
    if type(GoldLearner) == "table"
        and type(GoldLearner.install) == "function" then
      local okG, installedG = pcall(GoldLearner.install)
      if okG and installedG then
        installed[#installed + 1] = "gold learner"
      elseif not okG then
        warn("g9-gui: the Gold out-of-battle learner could not be installed: "
          .. tostring(installedG))
      end
    end
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
  -- Shell.gen2Surface, and the dialogue card takes the WINDOW space off the
  -- render.hud viewport payload Game2 hands the hook (Game2 has no renderer
  -- with frameRects, but its letterbox is exactly gameX/gameY/scale -- see
  -- ui/textbox.lua), so both generations get the same native density.
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
  -- The dialogue card's WINDOW space, exposed so ui/choice.lua can paint the
  -- box riding above it through the very same origin/scale -- one derivation,
  -- so the pair can never disagree about where the UI pixels land.  Only the
  -- table is shared; the choice skin is still loaded and fails alone.
  if Textbox then ctx.Textbox = Textbox end
  -- ...and the engine's YES/NO box, which rides just above that card.  It is
  -- one shared class on both generations, and since 2.6.7 both generations
  -- modernise it: the box is painted through the dialogue card's own window
  -- space (ui/choice.lua's render.hud painter), so YES/NO and the labels are
  -- as sharp as the question above them.  Only a box over a conversation the
  -- suite already dressed is modernised (a battle's switch offer and a bare
  -- shop/PC prompt keep the engine's own drawing).
  local Choice = loadSibling("ui/choice.lua")
  if Choice then Choice = attempt("ui/choice.lua init", Choice, mod, ctx) end
  if type(Choice) == "table" and type(Choice.dress) == "function"
      and type(Choice.isChoiceBox) == "function" then
    takeovers[#takeovers + 1] = "CHOICE"
    takeovers.Choice = Choice
  end
  -- ...and the engine's "How many?" stepper, which the bag, the mart, the
  -- PLAYER's PC (withdraw / deposit / toss) and the MOD MANAGER all push.  On a
  -- classic screen it keeps the engine's own box; over one of this suite's own
  -- pages it becomes the same centred card the mon submenu and the YES/NO use.
  local Quantity = loadSibling("ui/quantity.lua")
  if Quantity then
    Quantity = attempt("ui/quantity.lua init", Quantity, mod, ctx)
  end
  if type(Quantity) == "table" and type(Quantity.dress) == "function"
      and type(Quantity.isQuantity) == "function"
      and type(Quantity.canDress) == "function" then
    takeovers[#takeovers + 1] = "QUANTITY"
    takeovers.Quantity = Quantity
  end
  -- ...and the PC pages: the Pokecenter PC's own top menu, the player's ITEM
  -- storage menu and its WITHDRAW / DEPOSIT / TOSS lists, BILL's PC storage
  -- menu and its WITHDRAW / DEPOSIT / RELEASE lists, and the CHANGE BOX
  -- picker.  All of them are Menu / ListMenu instances the engine builds and
  -- keeps driving -- only the top menu and the two storage menus carry any
  -- identity (two screen ids and the engine's own "pc_*" kind strings), so
  -- ui/pc.lua dresses them at this same push wrapper, and installOpenPc()
  -- wraps OverworldState:openPC to mark the one top menu it builds inline
  -- (it has neither an id nor a kind, and it is pushed later, from the
  -- "turned on the PC" text box's callback).
  local Pc = loadSibling("ui/pc.lua")
  if Pc then Pc = attempt("ui/pc.lua init", Pc, mod, ctx) end
  if type(Pc) == "table" and type(Pc.dress) == "function"
      and type(Pc.isPc) == "function" then
    takeovers[#takeovers + 1] = "PC"
    takeovers.Pc = Pc
  end
  -- ...and the mart's own buy / sell LISTs (Gen 1).  The engine builds them
  -- inside its own ShopMenu closures and pushes them itself, so they are caught
  -- here -- recognised by the engine's `dialogue` flag, which only a mart sets
  -- (the PC lists use `messageBox`).  The sell list is drawn as the bag page
  -- (ui/shop.lua's drawSell -> ui/bag.lua's drawPage), the same presentation
  -- the Gen 2 sell flow already reaches through the engine's own pack.
  local Shop = loadSibling("ui/shop.lua")
  if Shop then Shop = attempt("ui/shop.lua init", Shop, mod, ctx) end
  if type(Shop) == "table" and type(Shop.isShopList) == "function"
      and type(Shop.dressList) == "function" then
    takeovers[#takeovers + 1] = "SHOP"
    takeovers.Shop = Shop
    ctx.Shop = Shop
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
            -- a battle composing its own surface keeps the classic box: the
            -- box is then centred inside the wide canvas and a card drawn in
            -- that space would land wrong.  A page of THIS suite no longer
            -- counts as "wide" here (ui/textbox.lua's surfaceIsWide): the box
            -- is dressed and its message drawn as the suite's card in the
            -- PAGE's coordinates, so a PC prompt no longer floats mid-page as
            -- the cart's white window.
            takeovers.Textbox.dress(state)
          elseif takeovers.Choice
              and takeovers.Choice.isChoiceBox(state)
              and takeovers.Choice.canDress(self, state) then
            takeovers.Choice.dress(state)
          elseif takeovers.Quantity
              and takeovers.Quantity.isQuantity(state)
              and takeovers.Quantity.canDress(self, state) then
            takeovers.Quantity.dress(state)
          elseif takeovers.Pc and takeovers.Pc.isPc(state) then
            takeovers.Pc.dress(state)
          elseif takeovers.Shop and takeovers.Shop.isShopList(state) then
            takeovers.Shop.dressList(state)
          end
          -- Gold: a taken-over page is painted by :drawWidescreen, and the
          -- stack pass Game2 runs under a pushed TextBox must not also call
          -- that page's own classic :draw() (the native party list showing
          -- through the dialogue card -- see ui/shell.lua gen2Surface).
          -- gen2Surface already installs a no-op :draw on the screens that use
          -- it; this gives the same guarantee to any Gen 2 arm that declares
          -- :drawsWidescreen itself.
          if gen == 2 and state.__g9gui
              and type(state.drawsWidescreen) == "function"
              and state:drawsWidescreen() then
            state.draw = function() end
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

  -- ...and the YES/NO box's own window-space painter: it paints the box through
  -- the dialogue card's space (see ui/choice.lua), so it only ever helps when
  -- that space is available.  Fail-open the same way -- without the hook the box
  -- keeps the (chunkier) surface card.
  if takeovers.Choice and type(takeovers.Choice.installHook) == "function" then
    local okC, hooked = pcall(takeovers.Choice.installHook, mod)
    if okC and hooked then
      installed[#installed + 1] = "choice: window-space"
    elseif not okC then
      warn("g9-gui: window-space choice box unavailable, keeping the surface "
        .. "card: " .. tostring(hooked))
    end
  end

  -- ...and the PC top menu: OverworldState:openPC builds a plain Menu inline
  -- and pushes it later, from a text box's callback, so the only way to know
  -- it is ours is to mark it as openPC creates it (ui/pc.lua's installOpenPc).
  -- Fail-open: without the wrap the menu is simply left classic, like every
  -- other Menu this mod does not own.
  if takeovers.Pc and type(takeovers.Pc.installOpenPc) == "function" then
    local okP, wrapped = pcall(takeovers.Pc.installOpenPc, mod)
    if okP and wrapped then
      installed[#installed + 1] = "pc: top menu"
    elseif not okP then
      warn("g9-gui: the PC top menu could not be wrapped, keeping it classic: "
        .. tostring(wrapped))
    end
  end

  if #installed == 0 then
    warn("g9-gui: no screens were installed")
    return
  end

  info(("g9-gui: modern UI installed on Gen %d for %s (modals %s, "
    .. "background %s, embellishments %s, portraits %s, pc row %s, "
    .. "modern stats %s)")
    :format(
    gen, table.concat(installed, ", "),
    ctx.Dialogs and "on" or "CLASSIC",
    on("ui_background") and "on" or "off",
    on("ui_embellishment") and "on" or "off",
    opt("ui_portraits") or "sprites",
    on("ui_pc_row") and "on" or "off",
    (engine and engine.exports.ModernStats) and "on" or "off"))
end
