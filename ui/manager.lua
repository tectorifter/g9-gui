-- ui/manager.lua -- the MODS (mod manager) page.
--
-- A VIEW takeover of src.mods.ManagerState.  That state is a whole little app
-- -- MODS / PROFILES / ERRORS tabs, a mod detail page, a permissions list, the
-- error log, the pending-changes screen, per-mod option pages and a
-- confirm/notice overlay -- all driven by its own `update` over one flat row
-- list with a header row per category.  None of that changes here: the same
-- object stays on the stack and keeps its navigation, its staged toggle
-- resolution, safe mode, profiles and the apply/restart flow.  Only the page
-- is redrawn at the suite's 540x360 surface.
--
-- The rows come straight from ManagerState:rowsForScreen(), so a screen this
-- page has no special case for still renders its rows rather than nothing.
return function(mod, ctx)
  local Theme, Backdrop, Shell = ctx.Theme, ctx.Backdrop, ctx.Shell
  local opt = ctx.opt

  local M = {}
  local Builtin = require("src.mods.ManagerState")
  local Strings = require("src.core.Strings")

  local W, H = Shell.W, Shell.H
  local MARGIN = Shell.MARGIN
  local ROW = 30
  -- display only: this page computes its own scroll from the cursor (the
  -- engine's own 11-row window is left alone), so eight rows always show it
  local VISIBLE = 8

  local TABS = { "MODS", "PROFILES", "ERRORS" }

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

  function M.new(game)
    return M.decorate(Builtin.new(game))
  end

  -- ---------------------------------------------------------------- helpers
  local function rowsOf(self)
    local ok, rows = pcall(self.rowsForScreen, self)
    if ok and type(rows) == "table" then return rows end
    return {}
  end

  -- Keep the cursor on screen while still showing the section headers around
  -- it.  The engine's own `self.scroll` is a row index for its 11-row classic
  -- window; this page has eight 30px rows, so it derives its own.
  local function window(rows, cursor, visible)
    local n = #rows
    if n <= visible then return 1 end
    local top = (cursor or 1) - math.floor(visible / 2)
    if top < 1 then top = 1 end
    if top > n - visible + 1 then top = n - visible + 1 end
    return top
  end

  -- The row models carry a status glyph in the classic gutter; here it is
  -- prefixed to the label instead.
  local function rowText(row)
    local label = row.label or row.id or ""
    local glyph = row.glyph
    if glyph and glyph ~= " " and glyph ~= "" then
      return glyph .. "  " .. label
    end
    return label
  end

  -- The trailing column: a mod row shows its version (or ON/OFF when it has
  -- none).  Everything else is label-only.
  local function rowRight(row)
    local m = row.mod
    if m then return m.version or (m.enabled and "ON" or "OFF") end
    return nil
  end

  local function tabs(Theme, game, x, y, active)
    local C = Theme.col
    local F = Theme.fonts(game).body
    local pen = x
    for i = 1, #TABS do
      local name = Strings(TABS[i])
      local w = Theme.w(name, F) + 24
      local on = i == active
      Theme.set(on and C.accentDim or C.panel)
      Theme.rect("fill", pen, y - 5, w, 24, 6)
      if on then
        Theme.set(C.borderLit)
        Theme.rect("line", pen + 0.5, y - 4.5, w - 1, 23, 5)
      end
      Theme.text(name, pen + 12, y, F, "left", on and C.ink or C.inkFaint)
      pen = pen + w + 10
    end
  end

  -- --------------------------------------------------------------- overlay
  local function drawOverlay(self, game)
    local C = Theme.col
    local F = Theme.fonts(game).body
    local overlay = self.overlay or {}
    local lines = overlay.lines or {}
    local isConfirm = overlay.kind == "confirm"
    local w = 380
    local h = 24 + #lines * 30 + (isConfirm and 84 or 54)
    local x = (W - w) * 0.5
    local y = math.max(Shell.CONTENT_Y, (H - h) * 0.5 - 10)

    Theme.set(C.black, 0.62)
    Theme.rect("fill", 0, 0, W, H, 0)
    Theme.panel(x, y, w, h, { radius = 8, shadow = 4,
      color = C.panelLit, border = C.borderLit })

    local ty = y + 16
    for i = 1, #lines do
      Theme.text(Theme.fit(lines[i], F, w - 32), x + 16, ty, F, "left", C.ink)
      ty = ty + 30
    end
    ty = ty + 6
    if isConfirm then
      local labels = { Strings("YES"), Strings("NO") }
      for i = 1, 2 do
        local ry = ty + (i - 1) * 36
        local on = overlay.index == i
        if on then
          Theme.set(C.rowLit, 0.55)
          Theme.rect("fill", x + 12, ry - 4, w - 24, 30, 5)
          Theme.chevrons(x + 20, ry + 2, 18, C.accent,
            0.5 + 0.5 * math.sin((self.__t or 0) * 0.18))
        end
        Theme.text(labels[i], x + 48, ry, F, "left", on and C.accent or C.ink)
      end
    else
      Theme.chevrons(x + 20, ty + 2, 18, C.accent,
        0.5 + 0.5 * math.sin((self.__t or 0) * 0.18))
      Theme.text(Strings("A:OK"), x + 48, ty, F, "left", C.inkDim)
    end
  end

  -- ------------------------------------------------------------------- draw
  function M.draw(self)
    local game = self.game
    local C = Theme.col
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    local screen = self.screen or "list"
    local cursor = self.cursor or 1

    local title = self.banner or Strings("MOD MANAGER")
    local caption, right
    if screen == "list" then
      caption = nil -- the tab strip takes the second header line
    elseif screen == "detail" then
      local m = self.currentMod
      title = m and (m.name or m.id) or title
      right = m and m.version or nil
      caption = m and (((m.enabled and Strings("ENABLED") or Strings("DISABLED"))
        .. "   " .. (m.category or "OTHER") .. " / "
        .. (m.profile or "content"))) or ""
    elseif screen == "permissions" then
      caption = "What this mod declared it does."
    elseif screen == "errors" then
      caption = "Load and runtime errors."
    elseif screen == "apply" then
      caption = "A: apply now, then restart."
    elseif screen == "options" then
      caption = "Left / Right changes a setting."
    end

    Shell.top(Theme, game, {
      title = title,
      -- A transient notice (an applied change, a reload) and the restart
      -- banner share the header's gold readout: the footer already carries
      -- four hint chips, so a long notice there would be cut to nothing.
      right = self.notice
        or (self.restartPending and Strings("RESTART TO APPLY"))
        or right,
      caption = caption,
      embellish = embellish,
    })
    if screen == "list" then
      tabs(Theme, game, 44, Shell.CAP_Y, self.tab or 1)
    end

    -- rows: the manager's own flat list (its BACK row is the last entry), or
    -- the option rows of a per-mod options page
    local pool
    local index
    local view = {}
    if screen == "options" then
      pool = self.optionRows or {}
      local scroll = self.scroll or 0
      index = cursor - scroll
      for slot = 1, VISIBLE do
        local row = pool[scroll + slot]
        if not row then break end
        local value
        if row.value then
          local ok, v = pcall(row.value, game)
          if ok and v ~= nil then value = tostring(v) end
        end
        view[#view + 1] = { text = row.label or row.id or "", right = value }
      end
    else
      pool = rowsOf(self)
      local top = window(pool, cursor, VISIBLE)
      index = cursor - top + 1
      for slot = 1, VISIBLE do
        local row = pool[top + slot - 1]
        if not row then break end
        view[#view + 1] = {
          text = rowText(row),
          right = rowRight(row),
          header = row.header and true or false,
          dim = row.inert and true or false,
        }
      end
    end

    Shell.list(Theme, game, {
      rows = view,
      index = index,
      scroll = 0,
      t = self.__t or 0,
      more = #pool > VISIBLE,
      x = MARGIN, y = Shell.CONTENT_Y, w = W - MARGIN * 2,
      row = ROW, labelPad = 46, rightPad = 20,
    })

    -- the manager's transient notice rides the header readout (see Shell.top
    -- above), so the footer is just the key hints
    Shell.footer(Theme, game, {
      hints = {
        { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "TAB" },
        { key = "A", text = "OPEN" },
        { key = "B", text = "BACK" },
      },
    })

    if self.overlay then drawOverlay(self, game) end

    Theme.set(C.white)
  end

  return M
end
