-- ui/title.lua -- the boot / title menu (and its CONTINUE window).
--
-- src.ui.TitleState is the game's title screen: the logo, the cycling
-- Pokemon, Red and the copyright line, then -- on START or A -- the
-- CONTINUE / NEW GAME / OPTION / EXIT GAME menu the engine pushes as a
-- classic `Menu` box (and, under CONTINUE, the `ContinueInfo` save-data
-- window).  Its cinematic is engine art the mod has no business redrawing,
-- so this takeover keeps the whole state and redecorates ONLY the two
-- screens the classic white boxes draw:
--
--   * `openMenu` still builds the engine's own item list (so hasSave()'s
--     CONTINUE gate, each row's own onSelect, the ui.title_menu.items hook
--     and OPTION's push of OptionsMenu -- which is already a g9-gui page --
--     all behave exactly as shipped); the `Menu` it pushes is then given the
--     suite's 540x360 page, its own draw, and an OPAQUE surface, so the
--     title art behind it is replaced by the mod's backdrop exactly the way
--     MainMenu's ClearScreen replaces it on the cart.
--   * CONTINUE's `ContinueInfo` window is kept (the same state, the same A
--     continues / B returns keys, and the same "the file could not be read"
--     fall-through) and only its draw is replaced, by the SAVE card the
--     START menu's own SAVE flow uses -- so the player / badges / dex / time
--     panel is one design in both places.
--
-- Nothing here touches the title's update, its boot sequence, its music or
-- its draw: the instance is the engine's own object and only openMenu is
-- wrapped.
--
-- GEN 2 (Gold/Silver/Crystal) splits what Gen 1 keeps in one object:
-- src.ui.gen2.TitleState is ONLY the boot cinematic -- its A/START calls
-- onContinue, nothing more -- and the CONTINUE / NEW GAME / OPTION / EXIT
-- GAME list its onContinue opens lives in a SEPARATE screen,
-- src.ui.gen2.MainMenu, together with the CONTINUE save panel its `phase ==
-- "confirm"` state shows.  So the Gen 2 takeover is MainMenu (the `Gen2MainMenu`
-- id): `M.drawGen2` draws the SAME rail + SAVE DATA emblem page the Gen 1 menu
-- draws, and the confirm phase becomes the same SAVE card the Gen 1 CONTINUE
-- window is, so the save readout is one design on both generations.  The title
-- cinematic itself stays the engine's -- it is engine art this mod has no
-- business redrawing -- so `Gen2TitleState` is deliberately NOT registered;
-- its only output is pushing MainMenu, which is ours.
return function(mod, ctx)
  local Theme, Backdrop, Shell, Dialogs = ctx.Theme, ctx.Backdrop, ctx.Shell,
    ctx.Dialogs
  local opt = ctx.opt

  local M = {}
  local Strings = require("src.core.Strings")
  -- Gen 2 is a different shape: Gold splits the ONE object Gen 1 keeps in two
  -- (see the gen 2 arm at the foot of this file), so the Gen 1 builtin is only
  -- asked for on a Gen 1 boot -- a lazy require keeps a Gold boot from ever
  -- pulling the Gen 1 title module in.
  local Gen2 = ctx.gen == 2
  local Builtin
  if not Gen2 then Builtin = require("src.ui.TitleState") end

  local C = Theme.col
  local W, H = Shell.W, Shell.H
  local CONTINUE = Strings("CONTINUE")
  -- The title page has no roster beside the rail, so the rail takes the width
  -- a longer row label needs (NEW GAME / EXIT GAME at body 22 do not fit the
  -- START screen's 152px) and the emblem panel fills the rest.
  local RAIL_W, EMB_X = 196, 220
  local EMB_W = W - EMB_X - Shell.MARGIN

  local CAPTION = {
    [CONTINUE] = "Load your saved journey.",
    [Strings("NEW GAME")] = "Start a brand new adventure.",
    [Strings("OPTION")] = "Adjust game settings.",
    [Strings("EXIT GAME")] = "Leave the game.",
  }

  -- ---------------------------------------------------------------- surfaces
  function M.uiSize() return W, H end
  function M.isWideBattleLayout(self) return Shell.wide(self) end
  function M.wantsFillScale(self) return Shell.wide(self) end
  function M.sgbPalettes() return {} end

  local function versionName()
    local name = "POK\xc3\xa9MON"
    pcall(function()
      local GV = require("src.core.GameVersion")
      if GV.isYellow and GV.isYellow() then name = "POK\xc3\xa9MON YELLOW"
      elseif GV.isBlue and GV.isBlue() then name = "POK\xc3\xa9MON BLUE"
      else name = "POK\xc3\xa9MON RED" end
    end)
    return name
  end

  local function hasSaveRow(menu)
    for _, item in ipairs((menu and menu.items) or {}) do
      if item.label == CONTINUE then return true end
    end
    return false
  end

  -- ------------------------------------------------------------------- draw
  -- The right-hand column: the shipped logo art (when it can be read), the
  -- version, and the two facts a boot menu is actually asked for.  The block
  -- is anchored at fixed rows -- version at y+106, rows at y+146/y+178, the
  -- foot rule at y+h-44 -- so the layout is identical whether or not the logo
  -- opened, and the text can never collide with the foot line.
  function M.emblem(game, menu, embellish)
    local F = Theme.fonts(game)
    local x, y = EMB_X, Shell.ROSTER_Y
    local w = EMB_W
    local h = (Shell.FOOT_RULE_Y - 8) - y
    Theme.panel(x, y, w, h, { radius = 6, shadow = 2 })
    local mid = x + w * 0.5

    local logo = menu and menu.__logo
    if logo and logo.getDimensions then
      local ok, iw, ih = pcall(logo.getDimensions, logo)
      if ok and type(iw) == "number" and iw > 0
          and type(ih) == "number" and ih > 0 then
        local band = 62                                  -- y+30 .. y+92
        local s = math.min((w - 72) / iw, band / ih)
        Theme.set(C.white)
        love.graphics.draw(logo, mid - iw * s * 0.5,
          (y + 30) + (band - ih * s) * 0.5, 0, s, s)
      end
    end

    Theme.text(versionName(), mid, y + 106, F.bold, "center", C.ink)
    Theme.rule(x + 24, y + 130, w - 48, C.border)

    local save = game.save or {}
    local party = save.party or {}
    local has = hasSaveRow(menu)
    local clock = ("%d:%02d"):format(math.floor((save.playTime or 0) / 3600),
      math.floor((save.playTime or 0) / 60) % 60)
    local rows = {
      { Strings("SAVE DATA"), has and Strings("FOUND") or Strings("EMPTY"),
        has and C.gold or C.inkFaint },
      { Strings("PARTY"), ("%d/6"):format(#party), C.inkDim },
      { Strings("TIME"), has and clock or "----", C.inkDim },
    }
    local ry = y + 142
    for _, r in ipairs(rows) do
      Theme.text(r[1], x + 26, ry, F.body, "left", C.inkFaint)
      Theme.text(r[2], x + w - 26, ry, F.bold, "right", r[3])
      ry = ry + 32
    end
  end

  function M.drawMenu(game, menu)
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"
    local items = menu.items or {}
    local cur = items[menu.index or 1]
    local caption = cur and CAPTION[cur.label] or nil

    Backdrop.draw(Theme, { w = W, h = H, t = menu.__t or 0,
      background = background, embellishment = embellish })

    Shell.top(Theme, game, {
      title = Strings("MAIN MENU"),
      caption = caption or "Choose an option.",
      embellish = embellish,
    })
    Shell.rows(Theme, game, {
      items = items,
      index = menu.index or 1,
      scroll = menu.scroll or 0,
      maxVisible = menu.maxVisible,
      x = Shell.LIST_X,
      w = RAIL_W,
      t = menu.__t or 0,
    })
    M.emblem(game, menu, embellish)
    Shell.footer(Theme, game, {
      hints = {
        { key = "\xe2\x86\x91\xe2\x86\x93", text = Strings("SELECT") },
        { key = "A", text = Strings("OK") },
        { key = "B", text = Strings("TITLE") },
      },
    })
    Theme.set(C.white)
  end

  -- --------------------------------------------------------------- the card
  -- The engine's ContinueInfo instance, kept whole and only reskinned.
  function M.dressCard(owner, card)
    -- with the modal module missing there is no card to draw; leaving the
    -- engine's own ContinueInfo alone is better than replacing its draw with
    -- one that cannot run
    if not Dialogs then return card end
    local game = owner.game
    card.__g9gui = true
    card.isOpaque = false
    card.letterboxWhite = true
    card.__t = 0
    card.uiSize = M.uiSize
    card.isWideBattleLayout = M.isWideBattleLayout
    card.wantsFillScale = M.wantsFillScale
    card.sgbPalettes = M.sgbPalettes
    local baseUpdate = card.update
    if baseUpdate then
      card.update = function(self, dt)
        self.__t = (self.__t or 0) + 1
        baseUpdate(self, dt)
      end
    end
    card.__title = Strings("SAVE DATA")
    card.__rows = Dialogs and Dialogs.saveRows(game)
    card.draw = function(self)
      Dialogs.paintCard(self, game, {
        title = self.__title,
        rows = self.__rows,
        hints = {
          { key = "A", text = Strings("CONTINUE") },
          { key = "B", text = Strings("BACK") },
        },
      })
    end
    return card
  end

  -- ------------------------------------------------------------- the menu
  function M.dressMenu(owner, menu)
    local game = owner.game
    menu.__g9gui = true
    menu.isOpaque = true
    menu.letterboxWhite = true
    menu.__t = 0
    menu.__logo = owner.logo
    menu.uiSize = M.uiSize
    menu.isWideBattleLayout = M.isWideBattleLayout
    menu.wantsFillScale = M.wantsFillScale
    menu.sgbPalettes = M.sgbPalettes
    local baseUpdate = menu.update
    menu.update = function(self, dt)
      self.__t = (self.__t or 0) + 1
      baseUpdate(self, dt)
    end
    menu.draw = function(self) M.drawMenu(game, self) end

    for _, item in ipairs(menu.items or {}) do
      if item.label == CONTINUE and item.onSelect then
        local baseSelect = item.onSelect
        item.onSelect = function(...)
          baseSelect(...)
          local top = game.stack and game.stack:top()
          if top and top ~= menu and top.title == owner and top.titleUiBox then
            M.dressCard(owner, top)
          end
        end
      end
    end
    return menu
  end

  function M.new(game, opts)
    if Gen2 then return M.newGen2(game, opts) end
    local self = Builtin.new(game, opts)
    local baseOpen = self.openMenu
    self.openMenu = function(s)
      if baseOpen then baseOpen(s) end
      local menu = s.game and s.game.stack and s.game.stack:top()
      if menu and menu ~= s and menu.items then M.dressMenu(s, menu) end
    end
    return self
  end

  -- ---------------------------------------------------------------- gen 2 arm
  -- Gold's main menu is its own screen: src.ui.gen2.MainMenu owns the list
  -- (Chrome.List, so the rows are { label, value } not { label, onSelect }),
  -- the ui.title_menu.items hook and the `phase` split between the menu and
  -- the CONTINUE save panel.  This arm keeps every one of those -- the engine's
  -- own update is only wrapped to tick an animation counter -- and draws the
  -- page.  No Gen2TitleState id is registered: its cinematic is engine art and
  -- its only output is pushing this screen.
  local function versionName2()
    local name = "POK\xc3\xa9MON"
    pcall(function()
      local GV = require("src.core.GameVersion")
      local info = GV.info and GV.info(GV.get())
      local label = info and info.label
      if label then name = "POK\xc3\xa9MON " .. label:upper() end
    end)
    return name
  end

  -- The emblem panel: the same fixed-row block as the Gen 1 page (a band, the
  -- version, then SAVE DATA / PARTY / TIME reading Gold's save shape -- its
  -- party table and its { hours, minutes, ... } clock), with MainMenu's own
  -- hasSave flag, which is the engine's wSaveFileExists read.  Gold has no logo
  -- art for this mod to draw, so the band the Gen 1 page fills with the shipped
  -- logo holds the version alone.
  function M.emblemGen2(game, menu)
    local F = Theme.fonts(game)
    local x, y = EMB_X, Shell.ROSTER_Y
    local w = EMB_W
    local h = (Shell.FOOT_RULE_Y - 8) - y
    Theme.panel(x, y, w, h, { radius = 6, shadow = 2 })
    local mid = x + w * 0.5

    Theme.text(versionName2(), mid, y + 106, F.bold, "center", C.ink)
    Theme.rule(x + 24, y + 130, w - 48, C.border)

    local save = game.save or {}
    local party = save.party or {}
    local time = save.playTime or {}
    local has = menu.hasSave
    local clock = ("%d:%02d"):format(time.hours or 0, time.minutes or 0)
    local rows = {
      { Strings("SAVE DATA"), has and Strings("FOUND") or Strings("EMPTY"),
        has and C.gold or C.inkFaint },
      { Strings("PARTY"), ("%d/6"):format(#party), C.inkDim },
      { Strings("TIME"), has and clock or "----", C.inkDim },
    }
    local ry = y + 142
    for _, r in ipairs(rows) do
      Theme.text(r[1], x + 26, ry, F.body, "left", C.inkFaint)
      Theme.text(r[2], x + w - 26, ry, F.bold, "right", r[3])
      ry = ry + 32
    end
  end

  -- The CONTINUE confirm card: Gold's own Save.summary is the read the cart's
  -- DisplaySaveInfoOnContinue makes -- its `badges` counts BOTH the Johto and
  -- the Kanto sets and its `caught` counts the dex -- so the figure here is the
  -- same one the engine prints, through the same module.
  local function saveRows2(game, save)
    local rows = {
      { Strings("PLAYER"), (save.player and save.player.name) or "GOLD", "ink" },
      { Strings("BADGES"), " 0", "gold" },
      { Strings("POK\xc3\xa9DEX"), "  0", "gold" },
      { Strings("TIME"), "0:00", "gold" },
    }
    local ok, summary = pcall(function()
      return require("src.core.gen2.Save").summary(save)
    end)
    if ok and summary then
      rows[2][2] = ("%2d"):format(summary.badges or 0)
      rows[3][2] = ("%3d"):format(summary.caught or 0)
      rows[4][2] = ("%d:%02d"):format(summary.hours or 0, summary.minutes or 0)
    end
    return rows
  end

  function M.drawCardGen2(self, game)
    if not Dialogs then return end
    Dialogs.paintCard(self, game, {
      title = Strings("SAVE DATA"),
      rows = saveRows2(game, self.save or (game and game.save) or {}),
      hints = {
        { key = "A", text = Strings("CONTINUE") },
        { key = "B", text = Strings("BACK") },
      },
    })
  end

  function M.drawGen2(self)
    local game = self.game
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"
    if self.phase == "confirm" then
      return M.drawCardGen2(self, game)
    end
    local list = self.list or {}
    local items = list.items or {}
    local cur = items[list.index or 1]
    local caption = cur and CAPTION[cur.label] or nil

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    Shell.top(Theme, game, {
      title = Strings("MAIN MENU"),
      caption = caption or "Choose an option.",
      embellish = embellish,
    })
    Shell.rows(Theme, game, {
      items = items,
      index = list.index or 1,
      scroll = list.scroll or 0,
      maxVisible = list.rows,
      x = Shell.LIST_X,
      w = RAIL_W,
      t = self.__t or 0,
    })
    M.emblemGen2(game, self)
    Shell.footer(Theme, game, {
      hints = {
        { key = "\xe2\x86\x91\xe2\x86\x93", text = Strings("SELECT") },
        { key = "A", text = Strings("OK") },
      },
    })
    Theme.set(C.white)
  end

  function M.newGen2(game, opts)
    local Gold = require("src.ui.gen2.MainMenu")
    local self = Gold.new(game, opts)
    self.__g9gui = true
    self.__t = 0
    local baseUpdate = self.update
    self.update = function(s, dt)
      s.__t = (s.__t or 0) + 1
      return baseUpdate(s, dt)
    end
    self.drawsWidescreen = function() return true end
    self.wantsFillScale = function() return true end
    self.drawWidescreen = function(s, winW, winH)
      Shell.gen2Page(Theme, s, winW, winH, function() M.drawGen2(s) end)
    end
    return self
  end

  return M
end
