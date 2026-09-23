-- ui/shop.lua -- the POKeMART page.
--
-- The mart was the last screen the START menu's world still drew with the
-- cart's own little white windows: BUY / SELL / QUIT in one box, the clerk's
-- line in another, an item list in a third.  This module takes it over as the
-- same 540x360 page every other screen here uses -- one header, one left rail,
-- one list band, one footer -- on BOTH generations.
--
-- It is a VIEW TAKEOVER, not a reimplementation, exactly like ui/bag.lua:
--
--   * Gen 1: `Screens.push(game, "ShopMenu", stock, onQuit)` resolves this
--     module's `new`, which builds the engine's own `src.ui.ShopMenu` and
--     amends the INSTANCE.  The engine still owns the whole flow -- the
--     BUY/SELL/QUIT loop, the unsellable-item rule, the quantity selector, the
--     YES/NO price confirm, every `Bag.add` / `Bag.remove` and the farewell --
--     and only the page it draws on changes.
--     The engine builds the buy and sell LISTS *inside* its own local `buy` /
--     `sell` closures and pushes them itself; there is no hook to catch them at
--     construction, so they are dressed at the same StateStack.push choke point
--     the PC lists and the dialogue card use (main.lua), recognised by the
--     engine's own `dialogue` flag -- only a mart ever sets it.
--     The sell list is drawn as **this suite's bag page** (ui/bag.lua's
--     `drawPage`), which is the note this round came from: on Gold the sell
--     flow already opens the modern PACK (`MartMenu:enterSell` builds
--     `Gen2PackMenu` through Screens.build, which is this suite's bag), so the
--     Gen 1 arm is made to match rather than left classic.
--
--   * Gen 2: the mart is one bespoke screen (`src.ui.gen2.MartMenu`), not a
--     Menu/ListMenu pair, so its own state machine drives everything and this
--     module only swaps the surface/draw.  Its messages, quantity stepper and
--     YES/NO are FIELDS on the instance rather than pushed states, so they are
--     drawn from here as the suite's cards too.
--
-- The quantity stepper and the YES/NO the engine PUSHES (Gen 1) need no work
-- here: ui/quantity.lua and ui/choice.lua already dress them, and both detect a
-- page of this suite under themselves (the `__g9gui` marker) -- so a "How many?"
-- or a price confirm over this page is the same card every other screen gets.
return function(mod, ctx)
  local Theme, Backdrop, Shell = ctx.Theme, ctx.Backdrop, ctx.Shell
  local opt = ctx.opt
  local M = {}
  local W, H = Shell.W, Shell.H
  local MARGIN = Shell.MARGIN
  local Gen2 = ctx.gen == 2

  local Strings
  do
    local ok, v = pcall(require, "src.core.Strings")
    Strings = ok and v or function(s) return s end
  end

  -- Rows the list band shows at once.  The engine's own cursor window is three
  -- rows for a shop list, so the cursor is always in the top three of these;
  -- seven is display only, the same choice ui/bag.lua makes.
  local VISIBLE = 7

  local CURSOR_KEYS = "\xe2\x86\x91\xe2\x86\x93"       -- up down
  local MART_TITLE = "POK\xc3\xa9 MART"

  -- A Strings source (or a plain string) as text; nil when it resolves to
  -- nothing, so a missing label degrades instead of printing "Source:".
  local function stext(v)
    if v == nil then return nil end
    local ok, s = pcall(Strings, v)
    if ok and type(s) == "string" and s ~= "" then return s end
    s = tostring(v)
    if s == "" or s:find("^Source:") then return nil end
    return s
  end

  -- One line from a possibly multi-line engine string (the cart's box prints
  -- two rows of 18 cells; the suite's caption is a single line).
  local function flat(s)
    if type(s) ~= "string" then return nil end
    s = s:gsub("[\r\n\v\f]+", " "):gsub("%s+$", ""):gsub("^%s+", "")
    if s == "" then return nil end
    return s
  end

  local function linesOf(s)
    if type(s) ~= "string" or s == "" then return {} end
    local out = {}
    for part in (s .. "\n"):gmatch("(.-)\n") do out[#out + 1] = part end
    return out
  end

  -- The item description the buy list shows under the selected row.  A TM
  -- teaches a move and the cart prints the MOVE's description (PrintItem-
  -- Description branches at TM01), which is the same rule the PACK follows.
  local function itemDescription(game, def)
    if type(def) ~= "table" then return nil end
    local d = def.description
    if type(d) ~= "string" or d == "" then
      local moves = game and game.data and game.data.moves
      local move = moves and def.teaches and moves[def.teaches]
      d = move and move.description
    end
    if type(d) ~= "string" then return nil end
    return flat(d:gsub("<NEXT>", " "))
  end

  -- `¥200`: the suite's own currency glyph, not the cart's floating PrintNum.
  local function yen(n)
    return ("\xc2\xa5%d"):format(math.floor(tonumber(n) or 0))
  end

  -- --------------------------------------------------------------- surface
  function M.uiSize() return W, H end
  M.isWideBattleLayout = Shell.wide
  function M.wantsFillScale(self) return Shell.wide(self) end
  function M.sgbPalettes() return {} end

  -- ------------------------------------------------------------- page bits
  local function background()
    return opt("ui_background") ~= "false"
  end
  local function embellish()
    return opt("ui_embellishment") ~= "false"
  end

  local function paintBackdrop(t)
    Backdrop.draw(Theme, { w = W, h = H, t = t or 0,
      background = background(), embellishment = embellish() })
  end

  -- The clerk's spoken line, as an inline card in the rail's own column: the
  -- mart's dialogue, in the place the POKeMON page puts its roster.  Purely
  -- decorative -- the same text is the header caption, which is what a long
  -- line is cut down to -- so it may clip to the panel rather than overflow.
  local function speechCard(game, x, y, w, h, lines, t)
    local C = Theme.col
    local F = Theme.fonts(game)
    Theme.panel(x, y, w, h, { radius = 8, shadow = 6,
      color = C.panelLit, border = C.borderLit })
    if embellish() then
      Theme.brackets(x + 5, y + 5, w - 10, h - 10, 16, C.accentDim)
    end
    Theme.set(C.accent, 0.42)
    Theme.rect("fill", x + 4, y + 1, w - 8, 1, 0)
    local ly = y + 16
    for _, line in ipairs(lines) do
      if ly + 20 > y + h then break end
      Theme.text(line, x + 18, ly, F.body, "left", C.ink)
      ly = ly + 26
    end
  end

  -- Wrap the clerk's line to the speech panel's own width.
  local function wrappedSpeech(game, x, w, text)
    local F = Theme.fonts(game)
    local out = {}
    for _, line in ipairs(linesOf(text)) do
      if line == "" then
        out[#out + 1] = ""
      else
        for _, sub in ipairs(Theme.wrap(line, F.body, w - 36)) do
          out[#out + 1] = sub
        end
      end
    end
    return out
  end

  local function railHeight(n)
    return n * Shell.LIST_ROW + 4
  end

  -- ============================================================ Gen 1 (mart)
  -- The engine's src.ui.ShopMenu: a `Menu` whose own :draw draws the classic
  -- clerk box, plus the buy / sell ListMenus its rows push.
  local ShopMenuEngine
  if not Gen2 then
    ShopMenuEngine = require("src.ui.ShopMenu")
  end

  -- The phase of the row whose onSelect is running, so the list that row pushes
  -- (built and pushed synchronously inside the engine's own closure) is
  -- classified without inspecting its contents.  Only one shop is ever up.
  M.__phase = nil

  local function wrapSelect(item, phase)
    if type(item) ~= "table" or type(item.onSelect) ~= "function" then return end
    if item.__g9shopSelect then return end
    local base = item.onSelect
    item.__g9shopSelect = true
    item.onSelect = function(...)
      local prev = M.__phase
      M.__phase = phase
      local ok, err = pcall(base, ...)
      M.__phase = prev
      if not ok then error(err, 0) end
    end
  end

  function M.decorate(menu, game)
    if type(menu) ~= "table" or menu.__g9gui then return menu end
    menu.__g9gui = true
    menu.isOpaque = true
    menu.letterboxWhite = true
    menu.__t = 0
    menu.uiSize = M.uiSize
    menu.isWideBattleLayout = M.isWideBattleLayout
    menu.wantsFillScale = M.wantsFillScale
    menu.sgbPalettes = M.sgbPalettes
    local baseUpdate = menu.update
    if type(baseUpdate) == "function" then
      menu.update = function(self, dt)
        self.__t = (self.__t or 0) + 1
        return baseUpdate(self, dt)
      end
    end
    menu.draw = function(self) M.drawTop(self) end
    -- tag the BUY / SELL rows so the list each one pushes is recognised at the
    -- push wrapper (their labels are the engine's own BUY / SELL)
    for _, it in ipairs(menu.items or {}) do
      local label = stext(it.label)
      if label == "BUY" then wrapSelect(it, "buy")
      elseif label == "SELL" then wrapSelect(it, "sell") end
    end
    return menu
  end

  -- ------------------------------------------------------ Gen 1: top menu
  function M.drawTop(self)
    local game = self.game
    paintBackdrop(self.__t)
    Shell.top(Theme, game, {
      title = MART_TITLE,
      caption = "Buy or sell items.",
      money = Shell.money(game),
      embellish = embellish(),
    })
    local labels = {}
    for i, it in ipairs(self.items or {}) do
      labels[i] = stext(it.label) or ("?" .. i)
    end
    Shell.rows(Theme, game, { items = labels, index = self.index or 1,
      t = self.__t or 0 })
    local h = math.max(railHeight(#labels), 96)
    speechCard(game, Shell.ROSTER_X, Shell.CONTENT_Y, Shell.ROSTER_W, h,
      wrappedSpeech(game, Shell.ROSTER_X, Shell.ROSTER_W, self.footer),
      self.__t)
    Shell.footer(Theme, game, { hints = {
      { key = CURSOR_KEYS, text = "SELECT" },
      { key = "A", text = "OK" },
      { key = "B", text = "LEAVE" },
    } })
    Theme.set(Theme.col.white)
  end

  -- ------------------------------------------------- a shop list page (shared)
  -- `o` = { title, right, caption, aHint, price (fn(item) -> right text) }
  -- Used by the buy list directly, and as the sell list's fail-open fallback
  -- (the sell list's first choice is the real bag page -- see M.drawSell).
  local function drawList(list, o)
    local game = list.game
    local items = list.items or {}
    local n = #items
    local count = n - (items[n] and items[n].cancel and 1 or 0)
    paintBackdrop(list.__t)
    local rows = {}
    for slot = 1, VISIBLE do
      local i = (list.scroll or 0) + slot
      local it = items[i]
      if not it then break end
      rows[#rows + 1] = {
        text = it.cancel and "CANCEL" or (it.label or ""),
        right = (not it.cancel) and o.price and o.price(it) or nil,
        dim = it.cancel and true or false,
        marker = list.swapIndex == i,
      }
    end
    Shell.top(Theme, game, {
      title = o.title,
      right = o.right or ("%d ITEMS"):format(math.max(0, count)),
      caption = o.caption or "",
      money = Shell.money(game),
      embellish = embellish(),
    })
    Shell.list(Theme, game, {
      rows = rows,
      index = (list.index or 1) - (list.scroll or 0),
      scroll = 0,
      t = list.__t or 0,
      more = (list.scroll or 0) + VISIBLE < n,
      x = MARGIN, y = Shell.CONTENT_Y, w = W - MARGIN * 2,
      row = 34, labelPad = 44, rightPad = 20,
    })
    Shell.footer(Theme, game, { hints = {
      { key = CURSOR_KEYS, text = "SELECT" },
      { key = "A", text = o.aHint or "OK" },
      { key = "SELECT", text = "MOVE" },
      { key = "B", text = "BACK" },
    } })
    Theme.set(Theme.col.white)
  end

  function M.drawBuy(list)
    local game = list.game
    local items = list.items or {}
    local sel = items[list.index]
    local desc
    if sel and not sel.cancel then
      local def = game and game.data and game.data.items
        and game.data.items[sel.value]
      desc = itemDescription(game, def) or sel.description
    end
    desc = desc or flat(list.footer)
    drawList(list, {
      title = MART_TITLE,
      caption = desc or "",
      aHint = "BUY",
      price = function(it) return it.price end,
    })
  end

  -- The sell list IS the bag, so it is drawn as this suite's bag page -- the
  -- same painter the Gen 2 sell flow reaches through the engine's own pack.
  function M.drawSell(list)
    local Bag = ctx.Bag
    if Bag and type(Bag.drawPage) == "function" then
      Bag.drawPage(list, {
        title = "ITEMS",
        caption = flat(list.footer) or "What would you like to sell?",
        aHint = "SELL",
        gap = 16,
      })
      return
    end
    -- fail-open: the same mart list page, showing the stack counts
    drawList(list, {
      title = "ITEMS",
      caption = flat(list.footer) or "What would you like to sell?",
      aHint = "SELL",
      price = function(it) return it.count and ("\xc3\x97%d"):format(it.count) end,
    })
  end

  -- ------------------------------------------------------ Gen 1: list dressing
  -- Only a mart's lists ever carry `dialogue` (the PC lists use `messageBox`),
  -- so that plus `itemBox` is the identity.
  function M.isShopList(state)
    if type(state) ~= "table" then return false end
    if state.dialogue ~= true or state.itemBox ~= true then return false end
    if type(state.items) ~= "table" then return false end
    return not state.__g9gui
  end

  local function looksLikeSell(list)
    local first = list.items and list.items[1]
    return type(first) == "table" and first.price == nil
  end

  function M.dressList(list, phase)
    if type(list) ~= "table" or list.__g9gui then return list end
    list.__g9gui = true
    list.isOpaque = true
    list.letterboxWhite = true
    list.__t = 0
    list.uiSize = M.uiSize
    list.isWideBattleLayout = M.isWideBattleLayout
    list.wantsFillScale = M.wantsFillScale
    list.sgbPalettes = M.sgbPalettes
    local baseUpdate = list.update
    if type(baseUpdate) == "function" then
      list.update = function(self, dt)
        self.__t = (self.__t or 0) + 1
        return baseUpdate(self, dt)
      end
    end
    phase = phase or M.__phase
    if phase == nil then phase = looksLikeSell(list) and "sell" or "buy" end
    if phase == "sell" then
      list.__g9sell = true
      list.draw = function(self) M.drawSell(self) end
    else
      list.draw = function(self) M.drawBuy(self) end
    end
    return list
  end

  -- ============================================================ Gen 2 (Gold)
  -- Gold's mart is ONE screen (src.ui.gen2.MartMenu) with a phase machine, and
  -- its overlays are fields, so this arm draws every phase itself.
  local Gen2MartEngine
  local function g2engine()
    Gen2MartEngine = Gen2MartEngine or require("src.ui.gen2.MartMenu")
    return Gen2MartEngine
  end

  local G2_TOP_LABELS = { "BUY", "SELL", "QUIT" }

  function M.newGen2(game, opts)
    local self = g2engine().new(game, opts)
    if type(self) ~= "table" or self.__g9gui then return self end
    self.__g9gui = true
    self.__t = 0
    local baseUpdate = self.update
    if type(baseUpdate) == "function" then
      self.update = function(s, dt)
        s.__t = (s.__t or 0) + 1
        return baseUpdate(s, dt)
      end
    end
    Shell.gen2Surface(Theme, self, function(s) M.drawGen2(s) end)
    return self
  end

  -- The lines the Typer is showing this frame, or the page's own lines before
  -- typing starts.
  local function typedLines(self, page)
    local typer = self.typer
    if typer and type(typer.lines) == "function" then
      local ok, lines = pcall(typer.lines, typer)
      if ok and type(lines) == "table" then return lines end
    end
    if type(page) == "string" then return { page } end
    return page or {}
  end

  local function pageLines(list)
    local out = {}
    for _, l in ipairs(list or {}) do
      if l ~= "" then out[#out + 1] = l end
    end
    if #out == 0 then out[1] = "" end
    return out
  end

  local function g2Top(self)
    local cap = flat(table.concat(self.topLines or {}, " "))
    paintBackdrop(self.__t)
    Shell.top(Theme, self.game, {
      title = MART_TITLE,
      caption = "Buy or sell items.",
      money = Shell.money(self.game),
      embellish = embellish(),
    })
    Shell.rows(Theme, self.game, { items = G2_TOP_LABELS,
      index = self.topIndex or 1, t = self.__t or 0 })
    local h = math.max(railHeight(#G2_TOP_LABELS), 96)
    speechCard(self.game, Shell.ROSTER_X, Shell.CONTENT_Y, Shell.ROSTER_W, h,
      wrappedSpeech(self.game, Shell.ROSTER_X, Shell.ROSTER_W, cap), self.__t)
    Shell.footer(Theme, self.game, { hints = {
      { key = CURSOR_KEYS, text = "SELECT" },
      { key = "A", text = "OK" },
      { key = "B", text = "LEAVE" },
    } })
  end

  local function g2Buy(self)
    local game = self.game
    local entries = self.entries or {}
    local total = #entries + 1
    local rows = {}
    for slot = 1, VISIBLE do
      local i = (self.scroll or 0) + slot
      local e = entries[i]
      if e then
        rows[#rows + 1] = { text = e.name, right = yen(e.price),
          dim = e.soldOut or nil }
      elseif i == total then
        rows[#rows + 1] = { text = "CANCEL", dim = true }
      else
        break
      end
    end
    local desc
    local ok, d = pcall(self.description, self)
    if ok and type(d) == "string" then desc = flat(d) end
    paintBackdrop(self.__t)
    Shell.top(Theme, game, {
      title = MART_TITLE,
      right = ("%d ITEMS"):format(#entries),
      caption = desc or "",
      money = Shell.money(game),
      embellish = embellish(),
    })
    Shell.list(Theme, game, {
      rows = rows,
      index = (self.index or 1) - (self.scroll or 0),
      scroll = 0,
      t = self.__t or 0,
      more = (self.scroll or 0) + VISIBLE < total,
      x = MARGIN, y = Shell.CONTENT_Y, w = W - MARGIN * 2,
      row = 34, labelPad = 44, rightPad = 20,
    })
    Shell.footer(Theme, game, { hints = {
      { key = CURSOR_KEYS, text = "SELECT" },
      { key = "A", text = "BUY" },
      { key = "B", text = "BACK" },
    } })
  end

  local function g2Sell(self)
    local pack = self.pack
    local Bag = ctx.Bag
    if pack and Bag and type(Bag.drawGen2) == "function" then
      Bag.drawGen2(pack, {
        title = "ITEMS",
        caption = "What would you like to sell?",
        aHint = "SELL",
        gap = 16,
      })
      return
    end
    paintBackdrop(self.__t)
    Shell.top(Theme, self.game, { title = "ITEMS", caption = "", money = nil,
      embellish = embellish() })
  end

  local function g2Message(self)
    local msg = self.message
    local lines = typedLines(self, msg.pages and msg.pages[msg.page or 1])
    local more = (msg.page or 1) < #(msg.pages or {})
    if more and self.typer and type(self.typer.done) == "function" then
      local ok, done = pcall(self.typer.done, self.typer)
      more = ok and done or false
    end
    if more and ((self.arrowBlink or 0) % 32) >= 16 then more = false end
    Shell.card(Theme, self.game, {
      lines = pageLines(lines), w = 420, more = more,
      hints = { { key = "A", text = "OK" } },
      t = self.__t or 0,
    })
  end

  local function g2Confirm(self)
    local conf = self.confirm
    local lines = pageLines(typedLines(self, conf.pages and conf.pages[conf.page or 1]))
    local yesno
    if type(self.yesNoVisible) == "function" then
      local ok, v = pcall(self.yesNoVisible, self)
      if ok and v then yesno = conf.choice or 1 end
    end
    Shell.card(Theme, self.game, {
      lines = lines, w = 420,
      yesno = yesno, yesnoLabels = { "YES", "NO" },
      hints = {
        { key = CURSOR_KEYS, text = "SELECT" },
        { key = "A", text = "OK" },
      },
      t = self.__t or 0,
    })
  end

  local function g2Qty(self, kind)
    local item = self.qtyItem or {}
    local qty = self.qty or 1
    local unit = item.price or 0
    local total = (kind == "sell")
      and math.floor(unit * qty / 2) or (unit * qty)
    Shell.card(Theme, self.game, {
      title = "HOW MANY?",
      right = self.qtyMax and ("MAX %d"):format(self.qtyMax) or nil,
      w = 340,
      lines = item.name and { stext(item.name) or "" } or nil,
      stepper = { value = ("\xc3\x97%02d"):format(qty), right = yen(total) },
      hints = {
        { key = CURSOR_KEYS, text = "CHANGE" },
        { key = "A", text = "OK" },
        { key = "B", text = "BACK" },
      },
      t = self.__t or 0,
    })
  end

  function M.drawGen2(self)
    paintBackdrop(self.__t)
    local phase = self.phase
    if phase == "top" then
      g2Top(self)
    elseif phase == "buy" or phase == "buyQuantity" then
      g2Buy(self)
    elseif phase == "sell" or phase == "sellQuantity" then
      g2Sell(self)
    else
      -- intro / outro (the herb, bargain and pharmacy clerks): the header, and
      -- the clerk's card drawn below
      Shell.top(Theme, self.game, { title = MART_TITLE, caption = "",
        money = Shell.money(self.game), embellish = embellish() })
    end
    -- the engine's own overlays, as this suite's cards
    if self.message then
      g2Message(self)
    elseif self.confirm then
      g2Confirm(self)
    elseif phase == "buyQuantity" then
      g2Qty(self, "buy")
    elseif phase == "sellQuantity" then
      g2Qty(self, "sell")
    end
    Theme.set(Theme.col.white)
  end

  -- ==================================================================== entry
  function M.new(game, a, b)
    if Gen2 then return M.newGen2(game, a) end
    return M.decorate(ShopMenuEngine.new(game, a, b), game)
  end

  return M
end
