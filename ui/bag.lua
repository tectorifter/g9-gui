-- ui/bag.lua -- the ITEM (bag) page.
--
-- Another VIEW takeover: the engine's own BagMenu is still the object on the
-- stack.  It returns a ListMenu whose `update` (via src.ui.MenuRepeat) owns the
-- cursor, the key-repeat, the SELECT reorder and the scroll/cursor arithmetic
-- BagMenu rewrites into game.bagListScrollOffset/game.bagSavedMenuItem; the
-- USE/TOSS option box, the QuantityBox, the YES/NO and every item effect stay
-- exactly as shipped.  Only draw and the surface are replaced, with the same
-- 540x360 page the START and POKeMON screens use (ui/shell.lua).
--
-- The classic bag is a LIST_MENU_BOX that floats over the map with the START
-- menu still visible around it, and it shows four rows.  This page is the
-- whole screen instead -- the list fills the content band -- but the ROW
-- MODEL is untouched: `self.scroll` still advances in the engine's own units
-- (BagMenu stores index - scroll - 1 and reopens on it), so the page draws the
-- rows from the engine's scroll and marks the engine's cursor.  It simply
-- reveals more of them at once.
return function(mod, ctx)
  local Theme, Backdrop, Shell = ctx.Theme, ctx.Backdrop, ctx.Shell
  local opt = ctx.opt

  local M = {}
  local Builtin = require("src.ui.BagMenu")
  local Strings = require("src.core.Strings")

  local W, H = Shell.W, Shell.H
  local MARGIN = Shell.MARGIN

  -- Rows visible at once.  The engine's own cursor window is three rows
  -- (wMaxMenuItem + the look-ahead row), so the cursor is always in the top
  -- three of whatever this draws -- seven is display only.
  local VISIBLE = 7

  function M.uiSize() return W, H end
  M.isWideBattleLayout = Shell.wide
  function M.wantsFillScale(self) return Shell.wide(self) end
  function M.sgbPalettes() return {} end

  -- Strings.source("ITEMS") is a source object, not a plain string; render it
  -- the way the engine's ListMenu does, with a literal fallback.
  local function titleText(title)
    local ok, s = pcall(Strings, title)
    if ok and type(s) == "string" and s ~= "" then return s end
    if type(title) == "string" and title ~= "" then return title end
    return "ITEMS"
  end

  -- ---------------------------------------------------------------- decorate
  -- Set the surface and replace the drawing on the INSTANCE the engine built.
  -- Returns the list untouched when the bag was opened mid-battle: the wide
  -- battle owns the surface there (see ui/shell.lua's S.inBattle).
  function M.decorate(list, game)
    if type(list) ~= "table" then return list end
    if Shell.inBattle(game) then return list end
    list.__g9gui = true
    list.isOpaque = true
    list.letterboxWhite = true
    list.__t = 0
    list.uiSize = M.uiSize
    list.isWideBattleLayout = M.isWideBattleLayout
    list.wantsFillScale = M.wantsFillScale
    list.sgbPalettes = M.sgbPalettes
    local baseUpdate = list.update
    list.update = function(self, dt)
      self.__t = (self.__t or 0) + 1
      baseUpdate(self, dt)
    end
    list.draw = function(self) M.draw(self) end
    return list
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
    local n = #items
    -- the CANCEL row is a terminator, not an item: it is not counted
    local held = n - (items[n] and items[n].cancel and 1 or 0)

    local rows = {}
    for slot = 1, VISIBLE do
      local i = scroll + slot
      local item = items[i]
      if not item then break end
      rows[#rows + 1] = {
        text = item.cancel and Strings("CANCEL") or (item.label or ""),
        right = (not item.cancel) and item.count
          and ("\xc3\x97%d"):format(item.count) or nil,
        dim = item.cancel and true or false,
        -- SELECT marks the item being reordered
        marker = self.swapIndex == i,
      }
    end

    Shell.top(Theme, game, {
      title = titleText(self.title),
      right = ("%d HELD"):format(math.max(0, held)),
      caption = self.swapIndex
        and "Choose another item to swap with."
        or "Use or toss an item.",
      money = Shell.money(game),
      embellish = embellish,
    })

    Shell.list(Theme, game, {
      rows = rows,
      index = self.index - scroll,
      scroll = 0,
      t = self.__t or 0,
      more = scroll + VISIBLE < n,
      x = MARGIN, y = Shell.CONTENT_Y, w = W - MARGIN * 2,
      row = 34, labelPad = 44, rightPad = 20,
    })

    Shell.footer(Theme, game, {
      hints = {
        { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
        { key = "A", text = "USE" },
        { key = "SELECT", text = "SWAP" },
        { key = "B", text = "BACK" },
      },
    })

    Theme.set(C.white)
  end

  -- ---------------------------------------------------------------- install
  -- The registry entry covers Screens.push("BagMenu"); the same decorate also
  -- wraps Builtin.new... no: BagMenu is only ever built through the registry
  -- (Screens.push in StartMenu and BattleState), so registering is enough.
  function M.new(game, opts)
    return M.decorate(Builtin.new(game, opts), game)
  end

  return M
end
