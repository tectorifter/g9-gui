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

  -- Gen 2 (Gold) builds src.ui.gen2.PackMenu instead: four pockets and its own
  -- widescreen layer.  The Gen 2 engine module is only required on a Gold boot
  -- (lazily), so a Gen 1 boot never pulls it in.
  local Gen2 = ctx.gen == 2
  local G2Builtin
  local function builtin()
    if not Gen2 then return Builtin end
    G2Builtin = G2Builtin or require("src.ui.gen2.PackMenu")
    return G2Builtin
  end

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
  -- The six-pocket strip, drawn only on a pocketed Gen 1 bag (ui/bag_util.lua).
  -- Same language as the Gen 2 PACK's own tabs below: one chip per pocket, the
  -- active one lit with a gold underline.  Short captions, because six full
  -- pocket names ("POKe BALLS", "BATTLE ITEMS") do not fit the 540px page.
  local G1_TAB_H = 24
  local function tabStrip(captions, activeIdx, F, C)
    local x = MARGIN
    for i = 1, #captions do
      local name = captions[i]
      local w = Theme.w(name, F.small) + 22
      local on = i == (activeIdx or 1)
      Theme.set(on and C.accentDim or C.panelDeep, on and 1 or 0.7)
      Theme.rect("fill", x, Shell.CONTENT_Y, w, G1_TAB_H, 4)
      if on then
        Theme.set(C.accent)
        Theme.rect("fill", x, Shell.CONTENT_Y + G1_TAB_H - 1, w, 1, 0)
      end
      Theme.text(name, x + w * 0.5, Shell.CONTENT_Y + 4, F.small, "center",
        on and C.accent or C.inkFaint)
      x = x + w + 6
    end
    return x
  end

  -- `o` overrides the page's own labels, so the same painter can serve a
  -- DIFFERENT owner of a bag-shaped list.  The mart's SELL list is the bag (the
  -- engine hands it the bag's own rows and SELECT-swap), and on Gold the sell
  -- flow already opens the modern PACK -- see ui/shop.lua.  Defaults are
  -- exactly what this page always drew, so the bag itself is unchanged.
  --   o = { title, right, caption, swapCaption, aHint }
  function M.drawPage(self, o)
    o = o or {}
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

    -- A pocketed bag (Gen 1, ui/bag_util.lua) gets the six-pocket strip; the
    -- rows step from 34 to 30 so seven of them still clear the footer rule.
    local pocketed = self.__g9bag and ctx.BagUtil
    local sortOpen = pocketed and self.__g9sort or nil
    local listY, listRow = Shell.CONTENT_Y, 34
    if pocketed then
      tabStrip(ctx.BagUtil.tabCaptions(), self.__g9pocket,
        Theme.fonts(game), C)
      listY, listRow = Shell.CONTENT_Y + G1_TAB_H + 8, 30
    end

    local caption
    if sortOpen then
      caption = "Sort the bag by name or by count."
    elseif self.swapIndex then
      caption = o.swapCaption or "Choose another item to swap with."
    else
      caption = o.caption or "Use or toss an item."
    end

    Shell.top(Theme, game, {
      title = o.title or titleText(self.title),
      right = o.right or ("%d HELD"):format(math.max(0, held)),
      caption = caption,
      money = Shell.money(game),
      embellish = embellish,
    })

    Shell.list(Theme, game, {
      rows = rows,
      index = self.index - scroll,
      scroll = 0,
      t = self.__t or 0,
      more = scroll + VISIBLE < n,
      x = MARGIN, y = listY, w = W - MARGIN * 2,
      row = listRow, labelPad = 44, rightPad = 20,
    })

    -- the sort prompt rides over the page as the suite's own card, so it reads
    -- as part of the design instead of pushing the engine's classic menu
    if sortOpen then
      local rowsOut = {}
      for i, label in ipairs(ctx.BagUtil.SORT_LABELS) do
        rowsOut[i] = { text = label }
      end
      local pocket = ctx.BagUtil.POCKETS[self.__g9pocket]
      Shell.card(Theme, game, {
        w = 340,
        title = "SORT THE BAG",
        right = pocket and pocket.label or nil,
        rows = rowsOut,
        index = sortOpen.index,
        t = self.__t or 0,
        hints = {
          { key = "\xe2\x86\x91\xe2\x86\x93", text = "CHOOSE" },
          { key = "A", text = "SORT" },
          { key = "B", text = "BACK" },
        },
      })
    end

    Shell.footer(Theme, game, {
      hints = o.hints or (pocketed and {
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "POCKET" },
        { key = "A", text = o.aHint or "USE" },
        { key = "SELECT", text = "SWAP" },
        { key = "TAB", text = "SORT" },
        { key = "B", text = "BACK" },
      } or {
        { key = "\xe2\x86\x91\xe2\x86\x93", text = "SELECT" },
        { key = "A", text = o.aHint or "USE" },
        { key = "SELECT", text = "SWAP" },
        { key = "B", text = "BACK" },
      }),
      gap = o.gap or 24,
    })

    Theme.set(C.white)
  end

  function M.draw(self) return M.drawPage(self) end

  -- ---------------------------------------------------------------- install
  -- The registry entry covers Screens.push("BagMenu"); the same decorate also
  -- wraps Builtin.new... no: BagMenu is only ever built through the registry
  -- (Screens.push in StartMenu and BattleState), so registering is enough.
  function M.new(game, opts)
    if Gen2 then return M.newGen2(game, opts) end
    local list = Builtin.new(game, opts)
    -- Gen 1 gets the six auto-sorted pockets (ui/bag_util.lua).  A bag opened
    -- over a battle is left alone: the wide battle owns the surface there, so
    -- the engine's classic bag keeps its flat rows.
    local BagUtil = ctx.BagUtil
    if BagUtil and BagUtil.enabled and not Shell.inBattle(game) then
      list = BagUtil.decorateBagList(list, game, opts)
    end
    return M.decorate(list, game)
  end

  -- ============================================================ Gen 2 (PACK)
  -- Gold's PACK is src.ui.gen2.PackMenu: four pockets (ITEM / BALL / KEY ITEM /
  -- TM/HM), its own widescreen layer, and -- unlike Gen 1 -- its submenu, its
  -- toss quantity and its YES/NO prompt are FIELDS on the instance rather than
  -- separate pushed states.  So this arm draws them too, as the suite's own
  -- popups.  Only drawing changes: the engine's own update keeps the cursor,
  -- the pocket switch and its remembered cursors, USE / GIVE / TOSS / SEL, the
  -- item effects, the SELECT shuffle and the battle arm exactly as shipped.
  local G2_VISIBLE = 7
  local G2_TAB_H = 24
  local G2_ROW = 30
  local G2_SUBMENU = {
    use = "USE", give = "GIVE", toss = "TOSS", sel = "SEL", quit = "QUIT",
  }

  -- a Strings source or a plain string, as text; nil when it resolves to
  -- nothing (so a missing label degrades to the row's id rather than "Source:")
  local function g2text(v)
    if v == nil then return nil end
    local ok, s = pcall(Strings, v)
    if ok and type(s) == "string" and s ~= "" then return s end
    s = tostring(v)
    if s == "" or s:find("^Source:") then return nil end
    return s
  end

  local function g2pocketName(self)
    local p = self:pocket()
    return g2text(p and p.label) or (p and p.id) or "ITEMS"
  end

  -- the four pockets as a tab strip, the active one lit -- the same tab
  -- language the summary panel uses, so the suite reads as one design
  local function g2tabs(self, F, C)
    local pockets = self.POCKETS or {}
    local active = self:pocket()
    local x = MARGIN
    for _, p in ipairs(pockets) do
      local name = g2text(p.label) or p.id or "?"
      local w = Theme.w(name, F.small) + 22
      local on = active and p.id == active.id
      Theme.set(on and C.accentDim or C.panelDeep, on and 1 or 0.7)
      Theme.rect("fill", x, Shell.CONTENT_Y, w, G2_TAB_H, 4)
      if on then
        Theme.set(C.accent)
        Theme.rect("fill", x, Shell.CONTENT_Y + G2_TAB_H - 1, w, 1, 0)
      end
      Theme.text(name, x + w * 0.5, Shell.CONTENT_Y + 4, F.small, "center",
        on and C.accent or C.inkFaint)
      x = x + w + 6
    end
  end

  -- the engine's row model as view rows: the TM/HM pocket prints the MOVE's
  -- name with the TM's own number in front (PackMenu:drawList), everything
  -- else the item's name, and the count only where the pocket shows one
  local function g2rows(self)
    local rows = self.rows or {}
    local out = {}
    for slot = 1, G2_VISIBLE do
      local i = self.scroll + slot
      local entry = rows[i]
      if entry then
        local label = entry.tmhmLabel
          and (entry.tmhmLabel .. "  " .. (entry.teaches or entry.name or ""))
          or (entry.name or "")
        out[#out + 1] = {
          text = label,
          right = (entry.showCount and entry.count)
            and ("\xc3\x97%d"):format(entry.count) or nil,
          marker = self.switching == i,
        }
      elseif i == self:total() then
        out[#out + 1] = { text = "CANCEL", dim = true }
      else
        break
      end
    end
    return out
  end

  local function g2listY() return Shell.CONTENT_Y + G2_TAB_H + 8 end

  -- a small centred modal: a title, some body lines, and an optional row list
  local function g2modal(self, F, C, opts)
    local lines = opts.lines or {}
    local rows = opts.rows
    local w = opts.w or 300
    local h = opts.h or 120
    local x, y = (W - w) * 0.5, (H - h) * 0.5
    Theme.panel(x, y, w, h, { radius = 8, shadow = 8,
      color = C.panelLit, border = C.borderLit })
    if opts.title then
      Theme.text(opts.title, x + w * 0.5, y + 10, F.body, "center", C.accent)
    end
    local ly = y + (opts.title and 40 or 18)
    for _, line in ipairs(lines) do
      -- a prompt longer than the card wraps instead of being cut
      for _, sub in ipairs(Theme.wrap(line, F.small, w - 28)) do
        Theme.text(sub, x + w * 0.5, ly, F.small, "center", C.ink)
        ly = ly + 22
      end
    end
    if rows then
      ly = ly + 4
      for i, row in ipairs(rows) do
        local on = i == (opts.index or 1)
        if on then
          Theme.set(C.rowLit, 0.5)
          Theme.rect("fill", x + 10, ly - 2, w - 20, 26, 4)
        end
        Theme.text(Theme.fit(row, F.body, w - 44), x + 24, ly, F.body, "left",
          on and C.accent or C.ink)
        ly = ly + 30
      end
    end
  end

  function M.newGen2(game, opts)
    local self = builtin().new(game, opts)
    self.__g9gui = true
    self.__t = 0
    local baseUpdate = self.update
    self.update = function(s, dt)
      s.__t = (s.__t or 0) + 1
      if baseUpdate then baseUpdate(s, dt) end
    end
    Shell.gen2Surface(Theme, self, function(s) M.drawGen2(s) end)
    return self
  end

  -- `o` overrides the header caption / title and the A hint, so the SAME page
  -- can be painted for a different owner of a pack: the Gold mart's SELL phase
  -- holds the modern pack and draws it here (see ui/shop.lua), exactly as the
  -- item PC's DEPOSIT phase does.  Defaults are what this page always drew.
  --   o = { title, caption, aHint }
  function M.drawGen2(self, o)
    o = o or {}
    local game = self.game
    local C = Theme.col
    local F = Theme.fonts(game)
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    local total = self:total()
    local rows = self.rows or {}
    local n = #rows

    local desc
    if self.switching then
      desc = "Where should this be moved to?"
    else
      local ok, d = pcall(self.description, self)
      if ok and type(d) == "string" and d ~= "" then
        desc = (d:gsub("<NEXT>", "  "):gsub("[\r\n]+", " "))
      end
    end

    Shell.top(Theme, game, {
      title = o.title or g2pocketName(self),
      right = ("%d ITEMS"):format(n),
      caption = o.caption or desc or "Use or toss an item.",
      money = Shell.money(game),
      embellish = embellish,
    })

    g2tabs(self, F, C)

    Shell.list(Theme, game, {
      rows = g2rows(self),
      index = self.index - self.scroll,
      scroll = 0,
      maxVisible = G2_VISIBLE,
      t = self.__t or 0,
      more = self.scroll + G2_VISIBLE < total,
      x = MARGIN, y = g2listY(), w = W - MARGIN * 2,
      row = G2_ROW, labelPad = 44, rightPad = 20,
    })

    Shell.footer(Theme, game, {
      hints = {
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "POCKET" },
        { key = "A", text = o.aHint or "USE" },
        { key = "SELECT", text = "MOVE" },
        { key = "B", text = "BACK" },
      },
      gap = o.gap or 24,
    })

    -- the engine's own overlays, drawn as this suite's popups: a message holds
    -- the PACK, the toss quantity rides on top of it, a YES/NO is its own box,
    -- and the item submenu floats beside the active row
    if self.message then
      local pages
      local ok, p = pcall(self.pagesFor, self, self.message)
      if ok then pages = p end
      local lines = pages and pages[self.messagePage or 1] or {}
      g2modal(self, F, C, { title = nil, lines = lines, w = 360, h = 120 })
    end
    if self.qtyState then
      local q = self.qtyState
      g2modal(self, F, C, {
        title = "HOW MANY?", w = 240, h = 148,
        lines = { ("\xc3\x97%d"):format(q.qty or 1),
          "\xe2\x86\x91\xe2\x86\x93 CHANGE", "A OK   B BACK" },
      })
    end
    if self.confirm then
      local choice = self.confirm.choice
      local w, h = 300, 128
      local x, y = (W - w) * 0.5, (H - h) * 0.5
      Theme.panel(x, y, w, h, { radius = 8, shadow = 8,
        color = C.panelLit, border = C.borderLit })
      Theme.text("ARE YOU SURE?", x + w * 0.5, y + 12, F.body, "center",
        C.accent)
      local ly = y + 46
      for i, lab in ipairs({ "YES", "NO" }) do
        if choice == i then
          Theme.set(C.rowLit, 0.5)
          Theme.rect("fill", x + 40, ly - 2, w - 80, 26, 4)
        end
        Theme.text(lab, x + w * 0.5, ly, F.body, "center",
          (choice == i) and C.gold or C.inkFaint)
        ly = ly + 30
      end
    end
    if self.submenu then
      local menu = self.submenu
      local labels = {}
      for i, id in ipairs(menu.rows or {}) do
        labels[i] = g2text(G2_SUBMENU[id]) or id
      end
      local lw = 150
      local lh = #labels * G2_ROW + 12
      local lx = W - MARGIN - lw
      local slot = math.max(0, math.min(self.index - self.scroll - 1,
        G2_VISIBLE - 1))
      local ly = g2listY() + slot * G2_ROW
      if ly + lh > Shell.FOOT_RULE_Y - 6 then
        ly = Shell.FOOT_RULE_Y - 6 - lh
      end
      if ly < Shell.CONTENT_Y + G2_TAB_H + 10 then
        ly = Shell.CONTENT_Y + G2_TAB_H + 10
      end
      Theme.panel(lx, ly, lw, lh, { radius = 6, shadow = 6,
        color = C.panelLit, border = C.borderLit })
      local y = ly + 6
      for i, label in ipairs(labels) do
        local on = i == (menu.index or 1)
        if on then
          Theme.set(C.rowLit, 0.5)
          Theme.rect("fill", lx + 4, y - 2, lw - 8, G2_ROW - 4, 4)
        end
        Theme.text(Theme.fit(label, F.body, lw - 28), lx + 14, y, F.body,
          "left", on and C.accent or C.ink)
        y = y + G2_ROW
      end
    end

    Theme.set(C.white)
  end

  -- The item PC's DEPOSIT phase holds a Gen2PackMenu instance and draws it
  -- INSIDE its own page (src/ui/gen2/ItemPcMenu.lua's drawPanel did the same
  -- with the engine's pack panel), so the Gen 2 page painter is published on
  -- the shared ctx for ui/pc.lua.  Read lazily there, so load order is free.
  ctx.Bag = M

  return M
end
