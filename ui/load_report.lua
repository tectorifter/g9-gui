-- ui/load_report.lua -- the LOAD REPORT (QuarantineReport), modernised.
--
-- Game:restoreSave pushes this screen once, before the overworld, when the
-- validation pass moved, removed or remapped something in the save
-- ("This save was made with 7 mods; 1 changed version").  The engine draws it
-- as a classic 160x144 white box: LOAD REPORT, 13 rows and A:CONTINUE.
--
-- Same state, same data, same keys (up/down scroll, A/B/START continue), same
-- `lines` -- only the page is the suite's 540x360 one.  The engine's own
-- 13-row window is left alone too; this page shows as many rows as its panel
-- holds and overrides :maxOffset() to match, so the last line is always
-- reachable.  A line ending in ":" is one of the report's section headings and
-- is drawn as one, blank lines become gaps, and the more-below marker rides
-- the panel edge while there is more to scroll.
return function(mod, ctx)
  local Theme, Backdrop, Shell = ctx.Theme, ctx.Backdrop, ctx.Shell
  local opt = ctx.opt

  local M = {}
  local Builtin = require("src.ui.QuarantineReport")
  local Strings = require("src.core.Strings")

  local C = Theme.col
  local W, H = Shell.W, Shell.H

  local X, Y = Shell.MARGIN, Shell.CONTENT_Y
  local WIDTH = W - Shell.MARGIN * 2
  local PANEL_H = (Shell.FOOT_RULE_Y - 8) - Y
  local ROW, TOP_PAD, BOT_PAD = 18, 10, 24
  local VISIBLE = math.floor((PANEL_H - TOP_PAD - BOT_PAD) / ROW)   -- 11

  function M.uiSize() return W, H end
  function M.isWideBattleLayout(self) return Shell.wide(self) end
  function M.wantsFillScale(self) return Shell.wide(self) end
  function M.sgbPalettes() return {} end

  function M.new(game, report)
    local self = Builtin.new(game, report)
    self.__g9gui = true
    self.isOpaque = true
    self.letterboxWhite = true
    self.__t = 0
    self.uiSize = M.uiSize
    self.isWideBattleLayout = M.isWideBattleLayout
    self.wantsFillScale = M.wantsFillScale
    self.sgbPalettes = M.sgbPalettes
    -- the page's own window: the engine's maxOffset() counts its 13-row box
    self.maxOffset = function(s)
      return math.max(0, #(s.lines or {}) - VISIBLE)
    end
    local baseUpdate = self.update
    self.update = function(s, dt)
      s.__t = (s.__t or 0) + 1
      baseUpdate(s, dt)
    end
    self.draw = function(s) M.draw(s) end
    return self
  end

  function M.draw(self)
    local game = self.game
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"
    local F = Theme.fonts(game)
    local lines = self.lines or {}
    local offset = self.offset or 0
    local maxOffset = self:maxOffset()

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    Shell.top(Theme, game, {
      title = Strings("LOAD REPORT"),
      caption = "What changed when this save was read.",
      right = ("%d LINES"):format(#lines),
      embellish = embellish,
    })

    Theme.panel(X, Y, WIDTH, PANEL_H, { radius = 6, shadow = 2 })

    local y = Y + TOP_PAD
    for row = 1, VISIBLE do
      local line = lines[offset + row]
      if line == nil then break end
      if line == "" then
        y = y + math.floor(ROW * 0.55)
      elseif line:sub(-1) == ":" then
        Theme.diamond(X + 18, y + 6, 3, C.accent)
        Theme.text(Theme.fit(line, F.small, WIDTH - 44), X + 30, y + 1,
          F.small, "left", C.inkFaint)
        y = y + ROW
      else
        local body = line:gsub("^%s+", "")
        Theme.text(Theme.fit(body, F.body, WIDTH - 40), X + 30, y, F.body,
          "left", C.ink)
        y = y + ROW
      end
    end

    if offset < maxOffset then
      local bx = X + WIDTH - 22
      Theme.set(C.accent, 0.9)
      love.graphics.polygon("fill", bx - 7, y + 1, bx + 1, y + 1, bx - 3, y + 8)
    elseif offset > 0 then
      Theme.text(Strings("END"), X + WIDTH - 18, Y + 8, F.small, "right",
        C.inkFaint)
    end

    Shell.footer(Theme, game, {
      hints = {
        { key = "\xe2\x86\x91\xe2\x86\x93", text = Strings("SCROLL") },
        { key = "A", text = Strings("CONTINUE") },
      },
      right = ("%d/%d"):format(offset + 1, maxOffset + 1),
    })
    Theme.set(C.white)
  end

  return M
end
