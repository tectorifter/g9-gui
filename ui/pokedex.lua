-- ui/pokedex.lua -- the POKeDEX CONTENTS page.
--
-- A VIEW takeover of src.ui.PokedexMenu: the engine's own object stays on the
-- stack and keeps every behaviour -- the SEEN/OWN tallies, the list that stops
-- at the highest number seen, the seven-row window with its own syncScroll and
-- pageScroll (LEFT/RIGHT page the list, exactly as the original), the DATA /
-- CRY / AREA / PRNT / QUIT side menu and the DexEntry page behind it.  Only
-- the drawing and the surface change.
--
-- Like the START, POKeMON and bag pages this one is the whole 540x360 screen
-- (ui/shell.lua), so the POKeDEX is the same size and the same type as every
-- other menu the START row opens.
return function(mod, ctx)
  local Theme, Backdrop, Shell = ctx.Theme, ctx.Backdrop, ctx.Shell
  local opt = ctx.opt

  local M = {}
  local Builtin = require("src.ui.PokedexMenu")
  local Strings = require("src.core.Strings")

  local W, H = Shell.W, Shell.H
  local MARGIN = Shell.MARGIN
  local ROW = 30

  function M.uiSize() return W, H end
  M.isWideBattleLayout = Shell.wide
  function M.wantsFillScale(self) return Shell.wide(self) end
  function M.sgbPalettes() return {} end

  function M.decorate(self)
    if type(self) ~= "table" then return self end
    self.__g9gui = true
    self.isOpaque = true
    self.letterboxWhite = true
    self.__t = 0
    self.uiSize = M.uiSize
    self.isWideBattleLayout = M.isWideBattleLayout
    self.wantsFillScale = M.wantsFillScale
    self.sgbPalettes = M.sgbPalettes
    local baseUpdate = self.update
    self.update = function(s, dt)
      s.__t = (s.__t or 0) + 1
      baseUpdate(s, dt)
    end
    self.draw = function(s) M.draw(s) end
    return self
  end

  function M.new(game, opts)
    return M.decorate(Builtin.new(game, opts))
  end

  -- ------------------------------------------------------------------- draw
  function M.draw(self)
    local game = self.game
    local C = Theme.col
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    local items = self.items or {}
    local scroll = self.scroll or 0
    local total = #items
    -- the engine's own visible count: its syncScroll/pageScroll are written
    -- against exactly this many rows
    local visible = math.min(7, total)
    if self.rows then
      local ok, n = pcall(self.rows, self)
      if ok and type(n) == "number" and n > 0 then visible = math.min(n, total) end
    end

    local rows = {}
    for slot = 1, visible do
      local item = items[scroll + slot]
      if not item then break end
      rows[#rows + 1] = {
        text = ("%s  %s"):format(item.num or "", item.name or ""),
        marker = item.ball and true or false,
        dim = item.value == nil,
      }
    end

    Shell.top(Theme, game, {
      title = Strings("POK\xc3\xa9DEX"),
      right = ("SEEN %d  OWN %d"):format(self.seenCount or 0,
        self.ownedCount or 0),
      caption = "Choose an entry to examine.",
      money = Shell.money(game),
      embellish = embellish,
    })

    Shell.list(Theme, game, {
      rows = rows,
      index = self.index - scroll,
      scroll = 0,
      t = self.__t or 0,
      more = scroll + visible < total,
      x = MARGIN, y = Shell.CONTENT_Y, w = W - MARGIN * 2,
      row = ROW, labelPad = 44, rightPad = 16,
    })

    Shell.footer(Theme, game, {
      hints = {
        { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "PAGE" },
        { key = "A", text = "VIEW" },
        { key = "B", text = "BACK" },
      },
    })

    Theme.set(C.white)
  end

  return M
end
