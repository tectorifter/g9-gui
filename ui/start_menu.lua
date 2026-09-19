-- ui/start_menu.lua -- the START screen.
--
-- This is a VIEW takeover, not a reimplementation: main.lua still builds the
-- engine's own start menu (src.ui.StartMenu), so every behaviour stays exactly
-- as shipped -- which rows exist and when (POKeDEX only after Oak's gift,
-- the player-name/trainer-card row, SAVE and QUIT, OPTION, MODS), each row's
-- own onSelect, the cursor that survives closing, the ui.start_menu.items hook
-- other mods insert rows through, and the same Input-driven Menu update.
-- (Two rows are re-pointed at this mod's own modals, ui/dialogs.lua: SAVE and
-- its confirmation, and QUIT's, were the last classic white boxes here.  The
-- rows, their keepOpen and their flow are unchanged.)  Only the drawing is
-- replaced, with a full-screen
-- 540x360 composition (ui/shell.lua owns the geometry, so the POKeMON screen
-- is laid out identically):
--
--   [ *  MENU ................................. badges / time / dex ]
--   [    caption .......................................... MONEY: 2244 ]
--   [ word-list  ]  [ portrait ] BULBASAUR      12   30/38
--   [ POKeDEX    ]  [  head    ] ##HP##          ****EXP**
--   [ ITEM       ]  ...
--   [ hints ........................................... party 3/6 ]
--
-- THE POKeMON ROW IS NOT DRAWN.  This screen is the first page of a two-page
-- spread: the party is always on the right, and LEFT/RIGHT pages straight to
-- the POKeMON screen (which is otherwise this same page), so a rail row that
-- only re-showed what the right column is already showing was redundant.  The
-- row's own item stays on the built-in menu object -- the mod only removes it
-- from the DRAWN list -- and its onSelect is exactly what LEFT/RIGHT fires, so
-- Oak's gift gate, the ui.start_menu.items hook and other mods' overrides all
-- still behave.
--
-- The party roster on the right is the same roster the POKeMON screen draws
-- (ui/roster.lua), drawn here as a read-only preview (focus = false).
return function(mod, ctx)
  local Theme, Backdrop, Roster, Portraits = ctx.Theme, ctx.Backdrop,
    ctx.Roster, ctx.Portraits
  local Shell = ctx.Shell
  local opt = ctx.opt

  local M = {}
  local Gen2 = ctx.gen == 2
  local Strings = require("src.core.Strings")

  -- The engine's own start menu for this boot: Gen 1's src.ui.StartMenu, or
  -- Gold's src.ui.gen2.StartMenu.  Required lazily so a Gen 1 boot never pulls
  -- a Gold module (and its Font/GbcPalette stack) in, and vice versa.
  local function builtin()
    if Gen2 then return require("src.ui.gen2.StartMenu") end
    return require("src.ui.StartMenu")
  end

  local W, H = Shell.W, Shell.H

  -- captions for the header bar, keyed by the engine's own row labels
  local CAPTION = {
    [Strings("POK\xc3\xa9DEX")] = "Browse your POK\xc3\xa9DEX.",
    [Strings("POK\xc3\xa9MON")] = "Assign members to the party.",
    [Strings("ITEM")] = "Check your bag.",
    [Strings("SAVE")] = "Save your progress.",
    [Strings("OPTION")] = "Adjust game settings.",
    [Strings("MODS")] = "Manage installed mods.",
    [Strings("QUIT")] = "Return to the main menu.",
  }

  local function badges(game)
    local ok, n = pcall(function()
      return require("src.inventory.Badges").count(game.data, game.save)
    end)
    return ok and n or 0
  end

  -- Dex total.  Gen 1 keeps owned species under save.pokedex.owned, Gold under
  -- save.pokedex.caught, so either set answers one counter.
  local function owned(game)
    local dex = (game and game.save and game.save.pokedex) or {}
    local set = dex.owned or dex.caught or {}
    local n = 0
    for _ in pairs(set) do n = n + 1 end
    return n
  end

  -- Play time.  Gen 1 stores a seconds float; Gold stores a
  -- { hours, minutes, seconds, frames } table (src/save_convert/Gen2Save.lua).
  local function clock(game)
    local t = game and game.save and game.save.playTime
    if type(t) == "table" then
      local mins = (tonumber(t.hours) or 0) * 60 + (tonumber(t.minutes) or 0)
      return ("%d:%02d"):format(math.floor(mins / 60), mins % 60)
    end
    local secs = math.floor(tonumber(t) or 0)
    return ("%d:%02d"):format(math.floor(secs / 3600),
      math.floor(secs / 60) % 60)
  end

  -- Badge total.  Gen 1 stores badges as inventory keys; Gold carries two
  -- boolean sets on the player (Johto + Kanto).  Both are counted so one header
  -- readout serves either boot.
  local function badges2(game)
    local p = game and game.save and game.save.player
    if not p or not (p.badges or p.kantoBadges) then
      local ok, n = pcall(function()
        return require("src.inventory.Badges").count(game.data, game.save)
      end)
      return ok and n or 0
    end
    local n = 0
    for _, v in pairs(p.badges or {}) do if v then n = n + 1 end end
    for _, v in pairs(p.kantoBadges or {}) do if v then n = n + 1 end end
    return n
  end

  -- ---------------------------------------------------------------- surfaces

  function M.uiSize() return W, H end

  -- The shared whole-stack walk (ui/shell.lua): wide unless an OPAQUE classic
  -- screen this mod has not modernised sits above us.  A non-opaque prompt
  -- (the SAVE panel, a TextBox) keeps this surface and gets centred by the
  -- engine's classic-offset path; the BAG, POKeDEX, OPTION and MODS pages
  -- answer for themselves now (each is a wide page of its own).
  M.isWideBattleLayout = Shell.wide

  -- Blit this page at the WINDOW-FILL scale rather than the classic integer
  -- letterbox (Renderer.uiFill, read off the whole stack by Game:draw).  The
  -- POKeMON screen has always been drawn that way -- the engine's PartyMenu
  -- class carries a wantsFillScale from g9-battle-sprites, which this mod's
  -- party instance inherits -- so without the same declaration here the START
  -- screen alone sat in a small box at the fixed scale while its sibling
  -- filled the window.  Both pages are the same 540x360 surface, so the same
  -- request makes them the same physical size at any window size -- which is
  -- what "the START menu should be the size of the POKeMON screen" means in
  -- pixels.  Every modernised screen in this mod declares it for the same
  -- reason (see ui/shell.lua's S.wide).
  function M.wantsFillScale(self)
    return Shell.wide(self)
  end

  -- g9-gui paints its own colours; an empty zone list keeps the engine's
  -- shade-remap shader off this surface.
  function M.sgbPalettes() return {} end

  -- ------------------------------------------------------------------- install

  function M.new(game, opts)
    if Gen2 then return M.newGen2(game, opts) end
    local menu = builtin().new(game)
    menu.__g9gui = true
    menu.isOpaque = true
    menu.letterboxWhite = true
    menu.__t = 0
    menu.uiSize = M.uiSize
    menu.isWideBattleLayout = M.isWideBattleLayout
    menu.wantsFillScale = M.wantsFillScale
    menu.sgbPalettes = M.sgbPalettes

    -- The POKeMON row is REMOVED from the rail.  The POKeMON page is a PAGE of
    -- this menu now, reached with LEFT/RIGHT (below), so a second, redundant
    -- way in would only split the cursor model.  The engine's own row object
    -- is kept: its onSelect is what pushes the party menu with an onCancel
    -- that reopens this menu, so the arrow key reuses the shipped navigation
    -- instead of re-implementing it.
    local partyLabel = Strings("POK\xc3\xa9MON")
    local items = menu.items or {}
    local partyRow
    for i, item in ipairs(items) do
      if item.label == partyLabel then partyRow = i break end
    end
    local fullRow = {}
    if partyRow then
      menu.__partyItem = table.remove(items, partyRow)
      -- game.startMenuIndex counts the FULL row list -- the engine's own
      -- wrapper wrote it, and its StartMenu.new has already used it to place
      -- the cursor -- so map it onto the reduced list (keeping the cursor on
      -- the row it was actually on) and keep the inverse map to write back.
      for i = 1, #items + 1 do
        fullRow[i] = i >= partyRow and i + 1 or i
      end
      local full = game.startMenuIndex
      if type(full) == "number" then
        if full > partyRow then full = full - 1
        elseif full == partyRow then full = math.min(partyRow, #items) end
        menu.index = math.max(1, math.min(full, math.max(1, #items)))
      end
      if menu.clampScroll then pcall(menu.clampScroll, menu) end
    end
    menu.__fullRow = fullRow
    menu.__partyRow = nil

    -- SAVE and its confirmation, and QUIT's, are the last two classic white
    -- boxes in this menu's tree: re-point them at ui/dialogs.lua's modern
    -- modals (see M.startSave / M.startQuit below).
    M.wrapItems(game, menu)

    local baseUpdate = menu.update
    menu.update = function(self, dt)
      self.__t = (self.__t or 0) + 1
      -- LEFT/RIGHT page between this menu and the POKeMON screen.  They are
      -- free keys here: the engine's Menu update reads only up/down/a/b/start,
      -- and the START menu's own pad mask has no direction but UP/DOWN.
      if M.pageToParty(self) then return end
      baseUpdate(self, dt)
      -- write the cursor back in FULL-row units, so the next StartMenu.new
      -- finds it where the player left it even though a row is hidden
      local map = self.__fullRow
      if map and map[self.index] then game.startMenuIndex = map[self.index] end
    end

    menu.draw = function(self) M.draw(self) end
    return menu
  end

  -- ==================================================================== Gen 2
  -- Gold's arm.  Game2 has no :uiSize(): a screen paints a widescreen layer in
  -- :drawWidescreen(winW, winH), and when it is the top of the stack the engine
  -- blits nothing under it (src/core/Game2.lua:drawScene).  So this keeps the
  -- engine's own StartMenu object -- its rows (including POKEGEAR, which Gen 1
  -- never had), its row-unlock flags, its remembered cursor, the
  -- ui.start_menu.items hook and its NO-defaults QUIT confirmation all still
  -- run -- and swaps ONLY the drawing for the suite's 540x360 page, scaled into
  -- the window by Shell.gen2Surface.  LEFT/RIGHT pages to the POKeMON page and
  -- back through the engine's own POKeMON row path (see M.pageToParty2), and
  -- the cart's white menu fade is dropped entirely (installNoFade) -- without
  -- it the swap flashed the engine's own START screen under a white sheet.

  -- captions keyed by the engine's stable row ids (Gen 2 rows carry a `value`;
  -- Gen 1's are matched by label).
  local CAPTION2 = {
    pokedex = "Browse your POK\xc3\xa9DEX.",
    pokemon = "Assign members to the party.",
    pack = "Check your bag.",
    pokegear = "Your trainer's key device.",
    status = "Your trainer profile.",
    save = "Save your progress.",
    option = "Adjust game settings.",
    mods = "Manage installed mods.",
    quit = "Return to the main menu.",
    quitContest = "Quit and be judged.",
  }

  -- A TRUE OVERRIDE of the START menu's own transitions.  Gold runs every
  -- start-menu item through Game2:openStartMenuItem, which pushes a
  -- Gen2MenuFade -- the cart's white ramp -- before the page, and
  -- Game2:closeStartMenuItem pushes the mirror ramp on the way back.  That fade
  -- is incompatible with a skinned page: its compositor (MenuFade:drawWidescreen)
  -- redraws every state BENEATH it with the state's NATIVE :draw(), and this
  -- suite only replaces :drawWidescreen -- so the swap between START and
  -- POKeMON flashed the engine's own START screen under a white sheet for the
  -- whole ramp.  Our pages paint the whole window themselves, so they need no
  -- fade and cannot be composited by one.  This answers both of Game2's
  -- start-menu entry points with the engine's own push/pop and no fade, scoped
  -- to those two methods (the fade is used NOWHERE else -- only the start menu
  -- opens items) and installed once, when the first START screen is built.
  local function installNoFade(game)
    if not game or game.__g9guiNoFade then return end
    if type(game.pushStartMenuItem) ~= "function" then return end
    game.__g9guiNoFade = true
    local pushItem = game.pushStartMenuItem
    game.openStartMenuItem = function(g, id)
      return pushItem(g, id)
    end
    game.closeStartMenuItem = function(g, id)
      local stack = g.stack
      if stack and stack.pop then stack:pop() end
    end
  end

  function M.newGen2(game, opts)
    local menu = builtin().new(game, opts)
    menu.__g9gui = true
    menu.__t = 0
    -- claim the menu's transitions: no cart menu fade over our page
    installNoFade(game)
    -- tick an animation counter and add LEFT/RIGHT paging; the engine's own
    -- update (cursor, scroll, the QUIT confirm, row unlocks) is otherwise
    -- untouched.
    local baseUpdate = menu.update
    menu.update = function(self, dt)
      self.__t = (self.__t or 0) + 1
      if M.pageToParty2(self) then return end
      baseUpdate(self, dt)
    end
    Shell.gen2Surface(Theme, menu, function(self) M.drawGen2(self) end)
    return menu
  end

  -- LEFT/RIGHT opens the POKeMON page exactly as the engine's own POKeMON row
  -- does: the engine's `choose` pushes Gold's PartyMenu (onCancel = back) with
  -- the click SFX and StartMenu.lastIndex bookkeeping kept.  installNoFade has
  -- already replaced the cart's white menu fade with that plain push.  Unlike
  -- Gen 1, this path leaves THIS menu on the stack beneath the party screen, so
  -- backing out (B, or LEFT/RIGHT on that screen -- see ui/party_menu.lua)
  -- returns straight to the rail.  A party-less save and the QUIT confirm
  -- (which owns the pad) are left alone.
  function M.pageToParty2(self)
    local game = self.game
    local input = game and game.input
    local party = game and game.save and game.save.party
    if not (input and party and #party > 0) then return false end
    if self.phase then return false end
    if not (input:wasPressed("left") or input:wasPressed("right")) then
      return false
    end
    if game.stack:top() ~= self then return false end
    -- find the engine's POKeMON row by its stable id, never by position: a mod
    -- may have hidden or reordered the rows.
    local at
    for i, item in ipairs(self.items or {}) do
      if item.value == "pokemon" then at = i break end
    end
    if not at then return false end
    self:choose("pokemon", at)
    return true
  end

  -- the rail as Shell.rows wants it: the engine's items already carry a
  -- translated `label`, and the Chrome.List owns index/scroll/rows.
  local function railState(menu)
    local list = menu.list
    return {
      items = menu.items,
      index = (list and list.index) or 1,
      scroll = (list and list.scroll) or 0,
      maxVisible = (list and list.rows) or 8,
    }
  end

  function M.drawGen2(self)
    local game = self.game
    local C = Theme.col
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    local rail = railState(self)
    local cur = (rail.items or {})[rail.index]
    local caption = cur and (CAPTION2[cur.value] or CAPTION2[cur.label])
    local right = ("BADGES %d  %s  DEX %d"):format(badges2(game), clock(game),
      owned(game))
    Shell.top(Theme, game, {
      title = Strings("MENU"),
      right = right,
      caption = caption,
      money = Shell.money(game),
      embellish = embellish,
    })

    -- Gold's rail carries one row Gen 1's does not -- POKeGEAR, 115px at the
    -- body size against the Gen 1 rail's 112px label budget -- so the Gen 2
    -- rail is a few pixels wider with a tighter chevron gutter, and it still
    -- stops short of the roster's card column (ROSTER_X + CARD_X).
    Shell.rows(Theme, game, {
      items = rail.items, index = rail.index, scroll = rail.scroll,
      maxVisible = rail.maxVisible, t = self.__t or 0,
      w = 158, labelPad = 32,
    })

    local party = (game.save and game.save.party) or {}
    Roster.draw(Theme, game, {
      x = Shell.ROSTER_X, y = Shell.ROSTER_Y, w = Shell.ROSTER_W,
      rowH = Shell.ROW_H, headerH = Shell.HEADER_H,
      party = party,
      focus = false,
      t = self.__t or 0,
      gen = 2,
      mode = opt("ui_portraits"),
      embellish = embellish,
      portraits = Portraits,
    })

    Shell.footer(Theme, game, {
      hints = {
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "POK\xc3\xa9MON" },
        { key = "A", text = "OK" },
        { key = "B", text = "CLOSE" },
      },
      right = ("PARTY %d/%d"):format(#party, 6),
    })

    if self.phase == "confirm" or self.phase == "confirmContest" then
      M.drawConfirm(self)
    end

    Theme.set(C.white)
  end

  -- Gold's own QUIT / contest confirm runs in the engine (self.phase,
  -- self.confirmChoice, up/down/a/b -- src/ui/gen2/StartMenu.lua); this only
  -- draws the box on the suite's page, dimming the menu behind it.
  function M.drawConfirm(self)
    local C = Theme.col
    local F = Theme.fonts(self.game)
    Theme.set(C.black, 0.55)
    Theme.rect("fill", 0, 0, W, H, 0)
    local pw, ph = 336, 148
    local px, py = (W - pw) * 0.5, (H - ph) * 0.5
    Theme.panel(px, py, pw, ph, { radius = 8, shadow = 6 })
    Theme.text(self.phase == "confirmContest" and "End the Contest?"
      or "RETURN TO MAIN MENU?", W * 0.5, py + 30, F.body, "center", C.ink)
    local yes = self.confirmChoice == 1
    local bw, by = 96, py + ph - 46
    local labels = { Strings("YES"), Strings("NO") }
    for i = 1, 2 do
      local bx = px + (pw - (bw * 2 + 16)) * 0.5 + (i - 1) * (bw + 16)
      local sel = (i == 1) == yes
      Theme.set(sel and C.accentDim or C.panelDeep, sel and 0.9 or 0.7)
      Theme.rect("fill", bx, by, bw, 30, 5)
      Theme.text(labels[i], bx + bw * 0.5, by + 7, F.body, "center",
        sel and C.white or C.inkDim)
    end
  end

  -- LEFT/RIGHT on the START menu opens the POKeMON page, exactly as the
  -- removed POKeMON row did (the START menu closes, then the row's own
  -- onSelect pushes the party menu with an onCancel that reopens this menu).
  -- Returns true when the key was consumed, so the caller skips the base
  -- update for that frame.  A mod that inserted its own row can still be
  -- reached with UP/DOWN; nothing else on this menu uses LEFT/RIGHT.
  function M.pageToParty(self)
    local game = self.game
    local party = game and game.save and game.save.party
    local input = game and game.input
    if not (input and party and #party > 0) then return false end
    if not (input:wasPressed("left") or input:wasPressed("right")) then
      return false
    end
    local item = self.__partyItem
    if not (item and item.onSelect) then return false end
    if game.stack:top() == self then game.stack:pop() end
    -- the party page reads this to know LEFT/RIGHT belongs to this menu
    game.__g9guiPartyFromStart = true
    local ok, err = pcall(item.onSelect)
    if not ok then
      game.__g9guiPartyFromStart = nil
      game.stack:push(self)
      if mod and mod.log then
        mod.log:warn("g9-gui: could not open the POKeMON page: "
          .. tostring(err):gsub("%%", "%%%%"))
      end
    end
    return true
  end

  -- ------------------------------------------------------------- save & quit

  -- pop every g9 dialog above this menu, then the kept-open menu itself.
  -- The cart's SaveMenu returns into HoldTextDisplayOpen rather than
  -- RedisplayStartMenu (start_sub_menus.asm:645-647), so a finished or
  -- cancelled SAVE leaves the overworld, not the START menu.
  local function closeFrom(game, menu)
    local stack = game and game.stack
    if not stack then return end
    while true do
      local top = stack:top()
      if top and top ~= menu and top.__g9gui then stack:pop() else break end
    end
    if menu and stack:top() == menu then stack:pop() end
  end

  -- Re-point SAVE and QUIT at ui/dialogs.lua.  Both rows keep everything else
  -- about their shipped behaviour: SAVE's item carries keepOpen (so this menu
  -- stays up behind the panel and goes down with it), QUIT's does not (the
  -- generic Menu has already popped the menu by the time its onSelect runs),
  -- and QUIT still calls game:returnToTitle() on YES.
  function M.wrapItems(game, menu)
    local Dialogs = ctx.Dialogs
    if not Dialogs then return end
    for _, item in ipairs(menu.items or {}) do
      if item.label == Strings("SAVE") then
        item.onSelect = function() M.startSave(game, menu) end
      elseif item.label == Strings("QUIT") then
        item.onSelect = function() M.startQuit(game) end
      end
    end
  end

  function M.startSave(game, menu)
    local Dialogs = ctx.Dialogs
    local name = (game.save.player and game.save.player.name) or "RED"
    local function close() closeFrom(game, menu) end
    local function ask()
      game.stack:push(Dialogs.confirm(game, {
        message = Strings("Would you like to\nSAVE the game?"),
        onChoose = function(yes)
          if not yes then close() return end
          -- SaveMenu .save: "Now saving..." is a bare hold (120 frames, not a
          -- prompt), and only THEN does the write happen; GameSavedText then
          -- plays SFX_SAVE and holds 30 more frames.
          game.stack:push(Dialogs.notice(game, {
            message = Strings("Now saving..."),
            auto = 120,
            progress = true,
            onDone = function()
              local ok = pcall(function() game:writeSave() end)
              if not ok then
                mod.log:warn("g9-gui: could not write the save file")
                game.stack:push(Dialogs.notice(game, {
                  message = Strings("SAVE FAILED"),
                  tone = "bad", icon = "warn", auto = 150, onDone = close,
                }))
                return
              end
              game.stack:push(Dialogs.notice(game, {
                message = Strings("%s saved\nthe game!", name),
                tone = "good", icon = "check", sound = "Save",
                auto = 30, onDone = close,
              }))
            end,
          }))
        end,
      }))
    end
    game.stack:push(Dialogs.card(game, {
      title = Strings("SAVE DATA"),
      rows = Dialogs.saveRows(game),
      -- the cart holds the PrintSaveScreenText panel for 30 frames
      -- (main_menu.asm:404-405) before the prompt comes up
      pause = 30,
      onAdvance = ask,
      onCancel = close,
    }))
  end

  function M.startQuit(game)
    game.stack:push(ctx.Dialogs.confirm(game, {
      message = Strings("RETURN TO MAIN\nMENU?"),
      defaultNo = true,
      onChoose = function(yes)
        if yes then game:returnToTitle() end
      end,
    }))
  end

  -- ---------------------------------------------------------------- rendering

  function M.draw(self)
    local game = self.game
    local C = Theme.col
    local F = Theme.fonts(game)
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    -- header: title, the badge/time/dex readout, the selected row's caption
    -- and the wallet on the line under it
    local cur = (self.items or {})[self.index]
    local caption = cur and CAPTION[cur.label] or nil
    if not caption and cur then
      caption = (cur.label == (game.save.player and game.save.player.name))
        and "Your trainer profile." or "Main menu."
    end
    local right = ("BADGES %d  %s  DEX %d"):format(badges(game), clock(game),
      owned(game))
    -- Safari Zone: the remaining steps and BALL count ride the same readout
    local ow = game.overworld
    if game.save.safari and ow and ow.map and ow.inSafariStepZone then
      local ok, res = pcall(function() return ow:inSafariStepZone() end)
      if ok and res then
        local s = game.save.safari
        right = ("%s   SAFARI %d/500  BALL\xc3\x97%d"):format(right,
          math.floor(s.steps or 0), math.floor(s.balls or 0))
      end
    end
    Shell.top(Theme, game, {
      title = Strings("MENU"),
      right = right,
      caption = caption,
      money = Shell.money(game),
      embellish = embellish,
    })

    -- the START menu's own rows, in the shared left rail
    Shell.rows(Theme, game, {
      items = self.items,
      index = self.index,
      scroll = self.scroll,
      maxVisible = self.maxVisible,
      t = self.__t or 0,
    })

    -- roster -- never focused: the POKeMON row is gone from the rail, so this
    -- page has no party cursor to follow (the POKeMON page owns it)
    local party = (game.save and game.save.party) or {}
    Roster.draw(Theme, game, {
      x = Shell.ROSTER_X, y = Shell.ROSTER_Y, w = Shell.ROSTER_W,
      rowH = Shell.ROW_H, headerH = Shell.HEADER_H,
      party = party,
      focus = false,
      t = self.__t or 0,
      mode = opt("ui_portraits"),
      embellish = embellish,
      portraits = Portraits,
    })

    Shell.footer(Theme, game, {
      hints = {
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "POK\xc3\xa9MON" },
        { key = "A", text = "OK" },
        { key = "B", text = "CLOSE" },
      },
      right = ("PARTY %d/%d"):format(#party, 6),
    })

    Theme.set(C.white)
  end

  return M
end
