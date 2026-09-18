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

  -- ---------------------------------------------------------------- install
  function M.new(game, opts)
    return M.decorate(baseNew(game, opts))
  end

  -- Group pages are pushed with a direct OptionsMenu.new call; wrap the
  -- module's own .new so they get the same page.  Only the DECORATION is
  -- added -- the engine's constructor still builds the object.
  if type(baseNew) == "function" and not Builtin.__g9guiWrapped then
    Builtin.__g9guiWrapped = true
    Builtin.new = function(game, opts)
      return M.decorate(baseNew(game, opts))
    end
  end

  return M
end
