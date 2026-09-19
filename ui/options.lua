-- ui/options.lua -- the OPTION page.
--
-- A VIEW takeover of src.ui.OptionsMenu.  The engine's own object stays on the
-- stack, so every behaviour is untouched: the row descriptors built by the
-- engine (TEXT SPEED, BATTLE STYLE, GAME SPEED, RULESET, the shader/zoom rows,
-- the ui.options.rows hook a mod inserts through), LEFT/RIGHT stepping a value
-- with its writeOptions() persist, A activating a row, B/START leaving, and the
-- grouped view (a group row opens a page of its members).
--
-- The group PAGES are the interesting case: the engine builds them by calling
-- OptionsMenu.new(game, {rows = members}) DIRECTLY (`g.stack:push`, not
-- Screens.push), so the screen registry never sees them.  M.new therefore also
-- wraps the module's own .new -- a group page is decorated exactly like the top
-- page and the two read as one design.
--
-- The row model is the engine's: `self.scroll` is clamped to a four-row window
-- (src.ui.OptionRows.VISIBLE) so the cursor is always inside the top four of
-- whatever this draws, and the BACK line is the row AFTER the last one
-- (index == #rows + 1), so it is drawn as an ordinary row and can be selected.
return function(mod, ctx)
  local Theme, Backdrop, Shell = ctx.Theme, ctx.Backdrop, ctx.Shell
  local opt = ctx.opt

  local M = {}
  local Builtin = require("src.ui.OptionsMenu")
  local Strings = require("src.core.Strings")
  -- the engine's own constructor, captured before M wraps it below
  local baseNew = Builtin.new

  -- Gold arm: the Gen 2 module is required LAZILY so a Gen 1 boot never pulls
  -- a Gold screen in (and a Gold boot never builds the Gen 1 one).
  local Gen2 = ctx.gen == 2
  local G2Builtin
  local function builtin2()
    G2Builtin = G2Builtin or require("src.ui.gen2.OptionsMenu")
    return G2Builtin
  end

  local W, H = Shell.W, Shell.H
  local MARGIN = Shell.MARGIN
  local ROW = 30
  -- display only: the engine's clampScroll keeps the cursor inside a four-row
  -- window, so eight rows always include it -- and eight is exactly the seven
  -- rows of a default OPTION list plus the BACK line after them
  local VISIBLE = 8

  function M.uiSize() return W, H end
  M.isWideBattleLayout = Shell.wide
  function M.wantsFillScale(self) return Shell.wide(self) end
  function M.sgbPalettes() return {} end

  local function rowValue(game, row)
    if not row or not row.value then return nil end
    local ok, v = pcall(row.value, game)
    if not ok or v == nil then return nil end
    return tostring(v)
  end

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

  -- ------------------------------------------------------------------- draw
  function M.draw(self)
    local game = self.game
    local C = Theme.col
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    local data = self.view or self.rows or {}
    local total = #data
    local scroll = self.scroll or 0
    local backRow = total + 1

    local rows = {}
    for slot = 1, VISIBLE do
      local i = scroll + slot
      if i <= total then
        local row = data[i]
        rows[#rows + 1] = {
          text = row.label or row.id or "",
          right = rowValue(game, row),
          -- a group row opens a page rather than stepping a value
          marker = row.group and true or nil,
          dim = false,
        }
      elseif i == backRow then
        rows[#rows + 1] = { text = Strings("BACK"), dim = true }
      else
        break
      end
    end

    Shell.top(Theme, game, {
      title = Strings("OPTION"),
      right = self.sub and Strings("SETTINGS") or nil,
      caption = "Left / Right changes a setting.",
      money = self.sub and nil or Shell.money(game),
      embellish = embellish,
    })

    Shell.list(Theme, game, {
      rows = rows,
      index = self.index - scroll,
      scroll = 0,
      t = self.__t or 0,
      more = scroll + VISIBLE < backRow,
      x = MARGIN, y = Shell.CONTENT_Y, w = W - MARGIN * 2,
      row = ROW, labelPad = 44, rightPad = 20,
    })

    Shell.footer(Theme, game, {
      hints = {
        { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "CHANGE" },
        { key = "B", text = self.sub and "BACK" or "CLOSE" },
      },
    })

    Theme.set(C.white)
  end

  -- ============================================================== Gen 2 (Gold)
  -- Gold's OPTION screen is one flat row list on `self.view` (its own
  -- ensureVisible keeps the cursor inside a seven-row window).  A group row
  -- opens a page of its members, and that page is built by the engine's own
  -- pushGroup with `setmetatable({}, OptionsMenu)` -- NOT through the module's
  -- `.new` -- so the Gen 2 arm dresses the CLASS: the top page and every group
  -- page inherit the same suite drawing, and the engine's update keeps running
  -- (the wrapper below only ticks the animation counter).
  --
  -- The displayed value is read the way the engine's own drawPanel reads it --
  -- a `text(options)` reader, then a `values` ladder through its `display`
  -- map, then the Gen 1 `value(game)` reader -- so a port row that steps itself
  -- (its own `cycle`) still shows its live setting here.
  local G2_VISIBLE = 7
  local G2_ROW = 30

  local function g2value(self, row)
    if row.frame then
      return tostring((self.options and self.options.frame) or 1)
    end
    if row.text then
      local ok, v = pcall(row.text, self.options)
      if ok and v ~= nil then return Strings(tostring(v)) end
    end
    if row.values then
      local value = row.key and self.options and self.options[row.key]
      local text = row.display and row.display[value] or value
      if text ~= nil then return Strings(tostring(text)) end
    end
    if type(row.value) == "function" then
      local ok, v = pcall(row.value, self.game)
      if ok and v ~= nil then return tostring(v) end
    end
    return nil
  end

  function M.drawGen2(self)
    local game = self.game
    local C = Theme.col
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    local data = self:visible() or {}
    local total = #data
    local scroll = self.scroll or 0

    local rows = {}
    for slot = 1, G2_VISIBLE do
      local row = data[scroll + slot]
      if not row then break end
      rows[#rows + 1] = {
        text = Strings(row.label or row.id or ""),
        right = g2value(self, row),
        marker = row.group and true or nil,
        dim = (row.cancel or row.inert) and true or nil,
      }
    end

    Shell.top(Theme, game, {
      title = Strings("OPTION"),
      right = self.sub and Strings("SETTINGS") or nil,
      caption = "Left / Right changes a setting.",
      money = self.sub and nil or Shell.money(game),
      embellish = embellish,
    })

    Shell.list(Theme, game, {
      rows = rows,
      index = (self.index or 1) - scroll,
      scroll = 0,
      t = self.__t or 0,
      more = scroll + G2_VISIBLE < total,
      x = MARGIN, y = Shell.CONTENT_Y, w = W - MARGIN * 2,
      row = G2_ROW, labelPad = 44, rightPad = 20,
    })

    Shell.footer(Theme, game, {
      hints = {
        { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "CHANGE" },
        { key = "B", text = self.sub and "BACK" or "CLOSE" },
      },
    })

    Theme.set(C.white)
  end

  -- Dress the Gold class exactly once.  Everything installed here is DRAWING
  -- only: the engine's update is only wrapped for the animation tick.
  function M.installGen2()
    local B = builtin2()
    if B.__g9guiGen2 then return B end
    B.__g9guiGen2 = true
    B.drawsWidescreen = function() return true end
    B.wantsFillScale = function() return true end
    B.sgbPalettes = function() return {} end
    B.drawWidescreen = function(s, winW, winH)
      Shell.gen2Page(Theme, s, winW, winH, function(inner) M.drawGen2(inner) end)
    end
    local baseUpdate = B.update
    B.update = function(s, dt)
      s.__t = (s.__t or 0) + 1
      if baseUpdate then baseUpdate(s, dt) end
    end
    return B
  end

  -- ---------------------------------------------------------------- install
  function M.new(game, opts)
    if Gen2 then
      local inst = M.installGen2().new(game, opts)
      if type(inst) == "table" then inst.__g9gui = true end
      return inst
    end
    return M.decorate(baseNew(game, opts))
  end

  -- Group pages are pushed with a direct OptionsMenu.new call; wrap the
  -- module's own .new so they get the same page.  Only the DECORATION is
  -- added -- the engine's constructor still builds the object.  (Gold builds
  -- its group pages off the class instead, so installGen2 covers them.)
  if not Gen2 and type(baseNew) == "function" and not Builtin.__g9guiWrapped then
    Builtin.__g9guiWrapped = true
    Builtin.new = function(game, opts)
      return M.decorate(baseNew(game, opts))
    end
  end

  return M
end
