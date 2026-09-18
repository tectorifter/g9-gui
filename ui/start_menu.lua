-- ui/start_menu.lua -- the START screen.
--
-- This is a VIEW takeover, not a reimplementation: main.lua still builds the
-- engine's own start menu (src.ui.StartMenu), so every behaviour stays exactly
-- as shipped -- which rows exist and when (POKeDEX only after Oak's gift,
-- the player-name/trainer-card row, SAVE with its panel and prompt, OPTION,
-- MODS, QUIT), each row's own onSelect, the cursor that survives closing, the
-- ui.start_menu.items hook other mods insert rows through, and the same
-- Input-driven Menu update.  Only the drawing is replaced, with a full-screen
-- 540x360 composition (ui/shell.lua owns the geometry, so the POKeMON screen
-- is laid out identically):
--
--   [ *  RED's menu ............................. badges / time / dex ]
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
  local Builtin = require("src.ui.StartMenu")
  local Strings = require("src.core.Strings")

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

  local function owned(game)
    local n = 0
    for _ in pairs((game.save.pokedex and game.save.pokedex.owned) or {}) do
      n = n + 1
    end
    return n
  end

  local function clock(game)
    local t = math.floor(game.save.playTime or 0)
    return ("%d:%02d"):format(math.floor(t / 3600), math.floor(t / 60) % 60)
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

  function M.new(game)
    local menu = Builtin.new(game)
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
      title = (game.save.player and game.save.player.name or "RED")
        .. "'s menu",
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
