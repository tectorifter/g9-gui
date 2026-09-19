-- ui/pokedex.lua -- the POKeDEX CONTENTS page.
--
-- A VIEW takeover of src.ui.PokedexMenu: the engine's own object stays on the
-- stack and keeps every behaviour -- the SEEN/OWN tallies, the list that stops
-- at the highest number seen, the seven-row window with its own syncScroll and
-- pageScroll (LEFT/RIGHT page the list, exactly as the original) and the
-- DexEntry page A now opens.  Only the drawing and the surface change.
--
-- A IS ONE CONFIRM.  The engine's own chooser (PokedexMenu.onChoose) is the
-- DATA / CRY / AREA / PRNT / QUIT side menu, so reading a species took two
-- presses -- A for the menu, then A again on DATA -- over a GB popup that this
-- page never drew.  The footer has always said A VIEW, so the instance's
-- chooser is replaced with the first row of the engine's own side menu: A
-- pushes the very DexEntryMenu the engine's DATA pushed, and an unseen row
-- (which carries no species id) still answers nothing at all.  CRY, AREA and
-- PRNT are the three actions that menu had and this one does not need: the
-- cry already plays on the entry's own opening beat, and B is the QUIT row's
-- close.  See "the side menu A replaces" below.
--
-- Like the START, POKeMON and bag pages this one is the whole 540x360 screen
-- (ui/shell.lua), so the POKeDEX is the same size and the same type as every
-- other menu the START row opens.
return function(mod, ctx)
  local Theme, Backdrop, Shell = ctx.Theme, ctx.Backdrop, ctx.Shell
  local opt = ctx.opt
  local NatDex = ctx.NatDex

  local M = {}
  local Builtin = require("src.ui.PokedexMenu")
  local Strings = require("src.core.Strings")
  local Screens = require("src.ui.Screens")

  -- Gen 2 (Gold) is a different engine screen (src.ui.gen2.PokedexMenu): its
  -- listing and its species entry live in ONE object, dispatched on `self.view`
  -- ("list" / "entry" / "area" / "option" / "search" / "unown"), and it paints
  -- its own widescreen layer.  Required lazily, so a Gen 1 boot never pulls a
  -- Gold module in.
  local Gen2 = ctx.gen == 2
  local G2Builtin
  local function builtin2()
    G2Builtin = G2Builtin or require("src.ui.gen2.PokedexMenu")
    return G2Builtin
  end

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
    -- the side menu A replaces: A pushes DexEntryMenu directly (the DATA row
    -- of the engine's own menu), so a species is one confirm away.  Set on the
    -- INSTANCE, never on PokedexMenu itself: the engine's class keeps its own
    -- chooser for any other screen that shares it.  A row with no species id
    -- is one the player has never seen -- the engine's chooser answers those
    -- with nothing, and so does this.
    self.onChoose = function(item, list)
      local game = (type(list) == "table" and list.game) or self.game
      if not (type(item) == "table" and item.value and game) then return end
      Screens.push(game, "DexEntryMenu", item.value)
    end
    self.draw = function(s) M.draw(s) end
    return self
  end

  function M.new(game, opts)
    if Gen2 then return M.newGen2(game, opts) end
    return M.decorate(Builtin.new(game, opts))
  end

  -- ------------------------------------------------------------------- draw
  function M.draw(self)
    local game = self.game
    local C = Theme.col
    local F = Theme.fonts(game)
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

    -- national_dex's view modes (SELECT) reorder the very array the engine
    -- built, and it names the mode on the title row of its own GB screen.  It
    -- does not expose which mode is current -- the value lives in a closure --
    -- so it is read back off the row shape (ui/national_dex.lua).  Nil when
    -- the peer is absent, and the header is then exactly what it always was.
    local mode = NatDex and NatDex.installed
      and NatDex.listingMode(items) or nil
    local tag = mode and NatDex.TAG[mode] or nil

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

    local right = ("SEEN %d  OWN %d"):format(self.seenCount or 0,
      self.ownedCount or 0)
    if tag then right = right .. "   " .. tag end

    Shell.top(Theme, game, {
      title = Strings("POK\xc3\xa9DEX"),
      right = right,
      caption = tag and "SELECT: SORT  START: SEARCH"
        or "Choose an entry to examine.",
      captionFont = tag and F.small or nil,
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

  -- ========================================================= Gen 2 (Gold dex)
  -- Gold's PokedexMenu is a widescreen screen whose listing and species entry
  -- are the same object (`self.view`).  This arm draws the LISTING and the
  -- ENTRY on the suite page, the OPTION (sort mode) as a suite list, and
  -- delegates the AREA map, the SEARCH screen and UNOWN MODE to the engine's
  -- own widescreen drawing -- those three are heavy bespoke cart screens and
  -- stay exactly as Gold ships them.  Everything the engine owns keeps
  -- running: the modes, the SEEN/OWN tallies, the cursor, the cry, PRNT, the
  -- search, the nest map and `save.lastDexMode`.
  local G2_ROW = 30
  local G2_VISIBLE = 7
  local G2_MODE = { NEW = "NEW", OLD = "OLD", ["A-Z"] = "A-Z" }

  local function g2safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    return ok and v or nil
  end

  local function g2text(v)
    if v == nil then return nil end
    local ok, s = pcall(Strings, v)
    if ok and type(s) == "string" and s ~= "" then return s end
    s = tostring(v)
    if s == "" or s:find("^Source:") then return nil end
    return s
  end

  local function g2name(self, species)
    local n = g2safe(self.monName, self, species)
    if type(n) == "string" and n ~= "" then return n end
    local def = self.pokemon and self.pokemon[species]
    return (def and def.name) or tostring(species)
  end

  local function g2entry(self, species)
    return self.dex and self.dex.entries and self.dex.entries[species]
  end

  local function g2no(n) return ("%03d"):format(tonumber(n) or 0) end

  local function g2header(self, F, extra)
    local seen, caught = 0, 0
    local ok, s, c = pcall(self.totals, self)
    if ok then seen, caught = s or 0, c or 0 end
    local mode = g2safe(self.mode, self) or "NEW"
    local right = ("SEEN %d  OWN %d   SORT %s"):format(seen, caught,
      G2_MODE[mode] or mode)
    Shell.top(Theme, self.game, {
      title = Strings("POK\xc3\xa9DEX"),
      right = right,
      caption = extra or "SELECT: SORT  START: SEARCH",
      captionFont = F.small,
      money = Shell.money(self.game),
      embellish = opt("ui_embellishment") ~= "false",
    })
  end

  local function g2page(self)
    local game = self.game
    local C = Theme.col
    local F = Theme.fonts(game)
    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = opt("ui_background") ~= "false",
      embellishment = opt("ui_embellishment") ~= "false" })
    return game, C, F
  end

  function M.newGen2(game, opts)
    local self = builtin2().new(game, opts)
    self.__g9gui = true
    self.__t = 0
    local baseUpdate = self.update
    self.update = function(s, dt)
      s.__t = (s.__t or 0) + 1
      if baseUpdate then baseUpdate(s, dt) end
    end
    self.__g9origWS = self.drawWidescreen
    self.drawsWidescreen = function() return true end
    self.wantsFillScale = function() return true end
    self.drawWidescreen = function(s, winW, winH)
      s.__g2winW, s.__g2winH = winW, winH
      Shell.gen2Page(Theme, s, winW, winH, function(ss) M.drawGen2(ss) end)
    end
    return self
  end

  function M.drawGen2(self)
    local v = self.view or "list"
    if v == "entry" then return M.drawEntry2(self) end
    if v == "option" then return M.drawOption2(self) end
    if v == "list" or v == "results" then return M.drawList2(self) end
    -- national_dex's own two extra views: drawn on the suite page from the
    -- peer's published data.  A failure falls through to the engine's drawing
    -- (which the peer patches), so a page that cannot be built costs the STYLE,
    -- never the screen.
    if NatDex and NatDex.installed and v == "nationalDexStats" then
      if pcall(M.drawStats2, self) then return end
    elseif NatDex and NatDex.installed and v == "nationalDexMoves" then
      if pcall(M.drawMoves2, self) then return end
    end
    -- area / search / unown: the engine's own widescreen drawing, untouched
    if self.__g9origWS then
      return self.__g9origWS(self, self.__g2winW or W, self.__g2winH or H)
    end
    return M.drawList2(self)
  end

  function M.drawList2(self)
    local game, C, F = g2page(self)
    local rows = self.rows or {}
    local scroll = self.scroll or 0
    local total = #rows
    local view = {}
    for slot = 1, G2_VISIBLE do
      local item = rows[scroll + slot]
      if not item then break end
      view[#view + 1] = {
        text = g2no(item.dex) .. "  " .. g2name(self, item.species),
        marker = item.caught and true or false,
        dim = not item.seen,
      }
    end

    g2header(self, F)

    Shell.list(Theme, game, {
      rows = view,
      index = self.index - scroll,
      scroll = 0,
      maxVisible = G2_VISIBLE,
      t = self.__t or 0,
      more = scroll + G2_VISIBLE < total,
      x = MARGIN, y = Shell.CONTENT_Y, w = W - MARGIN * 2,
      row = G2_ROW, labelPad = 44, rightPad = 16,
    })

    Shell.footer(Theme, game, {
      hints = {
        { key = "\xe2\x86\x91\xe2\x86\x93", text = "MOVE" },
        { key = "A", text = "VIEW" },
        { key = "B", text = "BACK" },
      },
    })

    Theme.set(C.white)
  end

  function M.drawOption2(self)
    local game, C, F = g2page(self)
    local opts = g2safe(self.optionRows, self) or {}
    local view = {}
    for _, r in ipairs(opts) do
      view[#view + 1] = {
        text = g2text(r.label) or r.mode or "?",
        marker = r.mode == (g2safe(self.mode, self) or "NEW"),
      }
    end
    g2header(self, F, "Choose how the POK\xc3\xa9DEX lists species.")
    Shell.list(Theme, game, {
      rows = view,
      index = self.optionIndex or 1,
      scroll = 0,
      maxVisible = #view,
      t = self.__t or 0,
      x = MARGIN, y = Shell.CONTENT_Y, w = W - MARGIN * 2,
      row = G2_ROW, labelPad = 44, rightPad = 16,
    })
    Shell.footer(Theme, game, {
      hints = {
        { key = "\xe2\x86\x91\xe2\x86\x93", text = "MOVE" },
        { key = "A", text = "SELECT" },
        { key = "B", text = "BACK" },
      },
    })
    Theme.set(C.white)
  end

  -- the mon's own GBC palette layer (src.world.gen2.Palettes +
  -- src.render.GbcPalette), required lazily and cached; nil when the engine
  -- predates it, in which case the pic is drawn raw either way
  local G2Pal
  local function g2ports(self)
    if G2Pal == nil then
      local okP, Palettes = pcall(require, "src.world.gen2.Palettes")
      local okG, Gbc = pcall(require, "src.render.GbcPalette")
      G2Pal = (okP and okG) and { P = Palettes, G = Gbc } or false
    end
    return G2Pal or nil
  end

  -- the species portrait: the engine's own pic (or its question mark) drawn
  -- into the panel at a whole multiple.  picFor's SECOND return value is the
  -- engine's trueColor flag -- true when a sprites mod hands over its own
  -- baked, true-colour frame (g9-battle-sprites' gen2 picFor hook) -- and such
  -- a frame is drawn RAW: running it through the mon's GBC 4-shade palette
  -- (right for the game's own pic) would quantise the pack's colours away.
  -- That is the engine's own drawPic rule, and it is why the pack's art can
  -- reach this page at all.
  local function g2pic(self, row, x, y, w, h)
    local img, trueColor
    if row and row.seen then
      local ok, a, b = pcall(self.picFor, self, row.species)
      if ok then img, trueColor = a, b end
      -- a sprites-mod frame that is still baking answers (nil, false): leave
      -- the panel blank for those frames rather than flashing the game's art
      if ok and not img then return end
    else
      img = g2safe(self.questionMark, self)
    end
    if not (img and img.getDimensions) then
      Theme.diamond(x + w * 0.5, y + h * 0.5, 10, Theme.col.accentDim)
      return
    end
    local iw, ih = img:getDimensions()
    local scale = math.floor(math.min((w - 16) / iw, (h - 16) / ih))
    if scale < 1 then scale = 1 end
    local dw, dh = iw * scale, ih * scale
    local dx, dy = x + (w - dw) * 0.5, y + (h - dh) * 0.5
    local function body()
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(img, dx, dy, 0, scale, scale)
    end
    if trueColor then
      body()
      return
    end
    local pal = g2ports(self)
    local colors
    if pal then
      local ok, cols = pcall(pal.P.monColors, self.palettes,
        row and row.species)
      if ok then colors = cols end
    end
    if colors and pal.G.available and pal.G.available() then
      pal.G.with(colors, body)
    else
      body()
    end
  end

  -- ======================================================= national_dex (Gen 2)
  -- The peer patches Gold's PokedexMenu class: the listing grows past 251
  -- (self.rows, already flowing through the LISTING arm above), the entry
  -- screen browses a species' alternate forms on UP/DOWN, and its action bar
  -- gains STAT and LVL.  Its own STAT/LVL pages are drawn on Gold's tile grid,
  -- which this arm paints over -- so the two pages are rebuilt here from the
  -- peer's published data (ui/national_dex.lua's Gen 2 helpers) and drawn on
  -- the suite page.  Its forms, its view state and its own update keep running
  -- untouched: pressing UP/DOWN or A still runs the peer's code, and this arm
  -- only reads the state it leaves behind (self.formId/formBase/formList,
  -- self.movePage, self.entryAction, self.view).
  local function nd2()
    return (NatDex and NatDex.installed) and true or false
  end

  -- The record a form selection is actually showing: the browsed form while
  -- one is selected, the row's own species otherwise.  The peer's own
  -- shownSpecies rule, restated so the portrait, the numbers and the label can
  -- never disagree about what is on screen.
  local function g2shown(self, species)
    local formId = self.formId
    if formId and formId ~= species and self.formBase == species then
      return formId
    end
    return species
  end

  -- The browsed form's prettied name, or nil when the base species is shown.
  local function g2form(self, species)
    local formId = self.formId
    if not (formId and species and formId ~= species
      and self.formBase == species) then
      return nil
    end
    local record = self.pokemon and self.pokemon[formId]
    local label = type(record) == "table" and record.form or nil
    if type(label) ~= "string" or label == "" then return nil end
    return (label:gsub("_", " "))
  end

  -- "<form>  i/n" while one is selected, "" otherwise.  The position counts the
  -- peer's own list (base species first), so it is the same list the UP/DOWN
  -- keys walk.
  local function g2formTag(self, species)
    local form = g2form(self, species)
    if not form then return "" end
    local list = type(self.formList) == "table" and self.formList or nil
    if list and #list > 1 then
      return form .. "  " .. tostring(self.formIndex or 1)
        .. "/" .. tostring(#list)
    end
    return form
  end

  -- Whether the species has alternate forms to browse, from the peer's own
  -- formsOf export (memoised in ui/national_dex.lua).  The hint is offered
  -- from the same list the UP/DOWN keys walk.
  local function g2hasForms(self, species)
    if not nd2() then return false end
    if type(self.formList) == "table" and #self.formList > 1 then return true end
    local forms = NatDex.forms and NatDex.forms(species) or nil
    return type(forms) == "table" and #forms > 0
  end

  -- The entry screen's ACTION bar: the cart's PAGE/AREA/CRY/PRNT, plus the
  -- peer's STAT/LVL when national_dex is loaded.  Six slots are wider than the
  -- column, so the bar shows a WINDOW of them and slides it to keep the
  -- selection visible -- the peer's own rule for its tile-grid bar
  -- (gen2dexlist.lua's M.barWindow), here measured in pixels rather than cells
  -- because Saira is proportional.  `maxW` is the space the bar may use.
  local function g2btnW(name, F)
    return Theme.w(name, F.small) + 22
  end

  local function g2actionBar(self, F, C, x, y, maxW)
    local acts = (nd2() and NatDex.g2Actions and NatDex.g2Actions())
      or { "PAGE", "AREA", "CRY", "PRNT" }
    local sel = tonumber(self.entryAction) or 1
    if sel < 1 or sel > #acts then sel = 1 end
    local gap = 6
    local win = #acts
    while win > 1 do
      local widest = 0
      for start = 1, #acts - win + 1 do
        local sum = 0
        for k = start, start + win - 1 do
          sum = sum + g2btnW(acts[k], F) + gap
        end
        sum = sum - gap
        if sum > widest then widest = sum end
      end
      if widest <= maxW then break end
      win = win - 1
    end
    local first = 1
    if #acts > win then
      if sel <= win then first = 1
      elseif sel > #acts - win + 1 then first = #acts - win + 1
      else first = sel - math.floor(win / 2) end
      first = math.max(1, math.min(first, #acts - win + 1))
    end
    local ax = x
    for i = first, first + win - 1 do
      local name = acts[i]
      local on = i == sel
      local wA = g2btnW(name, F)
      Theme.set(on and C.accentDim or C.panelDeep, on and 1 or 0.7)
      Theme.rect("fill", ax, y, wA, 24, 4)
      if on then
        Theme.set(C.accent)
        Theme.rect("fill", ax, y + 23, wA, 1, 0)
      end
      Theme.text(name, ax + wA * 0.5, y + 3, F.small, "center",
        on and C.accent or C.inkFaint)
      ax = ax + wA + gap
    end
    -- A window that is not the whole bar says so, so a hidden slot is never a
    -- slot the player cannot find.
    if win < #acts then
      Theme.text("\xe2\x80\xb9", x - 12, y + 3, F.small, "center", C.inkFaint)
      Theme.text("\xe2\x80\xba", ax - gap + 4, y + 3, F.small, "center",
        C.inkFaint)
    end
    return first, win, #acts
  end

  -- The base-stat panel: one row per stat with a bar over its fraction of 255,
  -- TOTAL last and gold.  The same furniture the Gen 1 entry's stats page
  -- uses, on the peer's six modern rows.
  local function g2statPanel(rows, x, y, w, h, C, F)
    local n = #rows
    if n == 0 then return end
    local titleH, titleY, pad = 24, 8, 6
    local rowH = math.floor((h - titleH - pad) / n)
    if rowH < 16 then
      titleH, titleY, pad = 16, 4, 4
      rowH = math.floor((h - titleH - pad) / n)
    end
    rowH = math.max(8, math.min(34, rowH))
    Theme.panel(x, y, w, h, { radius = 6, shadow = 3 })
    Theme.text("BASE STATS", x + 12, y + titleY, F.small, "left", C.inkFaint)
    local barX0, barX1 = x + 104, x + w - 58
    local capH = Theme.capOf(F.small)
    local ty = math.max(2, math.min(5, rowH - capH - 3))
    local ry = y + titleH
    for _, row in ipairs(rows) do
      local isTotal = row[1] == "TOTAL"
      Theme.text(row[1], x + 12, ry + ty, F.small, "left",
        isTotal and C.gold or C.inkDim)
      Theme.text(tostring(row[2]), x + w - 14, ry + ty, F.smallBold, "right",
        isTotal and C.gold or C.ink)
      if not isTotal and barX1 > barX0 then
        local frac = math.max(0, math.min(1, (row[2] or 0) / 255))
        local bh = math.max(5, math.min(11, rowH - 12))
        Theme.bar(barX0, ry + (rowH - bh) * 0.5, barX1 - barX0, bh, frac,
          C.accent, { bg = C.border, radius = 3 })
      end
      ry = ry + rowH
    end
    Theme.set(C.white)
  end

  function M.drawEntry2(self)
    local game, C, F = g2page(self)
    local row = g2safe(self.current, self)
    if not row then return M.drawList2(self) end
    local entry = g2entry(self, row.species) or {}
    local caught = row.caught and true or false

    local SPR_X, SPR_Y = MARGIN, Shell.CONTENT_Y
    local SPR_W = 190
    local SPR_H = Shell.FOOT_RULE_Y - 8 - SPR_Y
    local COL_X = SPR_X + SPR_W + 12
    local COL_W = (W - MARGIN) - COL_X

    local caption = g2text(entry.kind) or ""
    local formTag = g2formTag(self, row.species)
    if formTag ~= "" then
      caption = (caption == "") and formTag
        or (caption .. "  \xc2\xb7  " .. formTag)
    end
    g2header(self, F, caption)

    Theme.panel(SPR_X, SPR_Y, SPR_W, SPR_H, { radius = 6, shadow = 3 })
    g2pic(self, row, SPR_X, SPR_Y, SPR_W, SPR_H)

    -- No. + kind, then the figures.  The cart reveals the height and weight
    -- only once the mon is CAUGHT; before that both read "?".
    Theme.text("No." .. g2no(entry.dex or row.dex), COL_X, SPR_Y, F.body,
      "left", C.accent)
    local kind = g2text(entry.kind)
    if kind and kind ~= "" then
      Theme.text(Theme.fit(kind, F.small, COL_W), COL_X + 92, SPR_Y + 4, F.small,
        "left", C.inkFaint)
    end

    local hStr, wStr = "?", "?"
    if caught then
      local h = tonumber(entry.height) or 0
      hStr = ("%d'%02d\""):format(math.floor(h / 100), h % 100)
      wStr = ("%.1f lb"):format((tonumber(entry.weight) or 0) / 10)
    end
    Shell.list(Theme, game, {
      rows = {
        { text = "HEIGHT", right = hStr },
        { text = "WEIGHT", right = wStr },
      },
      x = COL_X, y = SPR_Y + 34, w = COL_W, row = G2_ROW,
      labelPad = 44, rightPad = 16,
    })

    -- the description: page 2 of the entry is `entry.text2`, page 1 `text`,
    -- both with the extractor's <NEXT> line joins
    local ACTION_H = 40
    local descY = SPR_Y + 34 + G2_ROW * 2 + 12
    local descH = Shell.FOOT_RULE_Y - ACTION_H - 8 - descY
    if descH < 40 then descH = 40 end
    Theme.panel(COL_X, descY, COL_W, descH, { radius = 6, shadow = 3 })
    if caught then
      local text = (self.page == 2) and entry.text2 or entry.text
      local joined = tostring(text or ""):gsub("<NEXT>", " "):gsub("[\r\n]+", " ")
      local wrapped = {}
      local line = ""
      for word in joined:gmatch("%S+") do
        local trial = (line == "" and word) or (line .. " " .. word)
        if line ~= "" and Theme.w(trial, F.small) > COL_W - 24 then
          wrapped[#wrapped + 1] = line
          line = word
        else
          line = trial
        end
      end
      if line ~= "" then wrapped[#wrapped + 1] = line end
      local maxLines = math.max(1, math.floor((descH - 16) / 20))
      local ty = descY + 9
      for i = 1, math.min(#wrapped, maxLines) do
        Theme.text(wrapped[i], COL_X + 12, ty, F.small, "left", C.inkDim)
        ty = ty + 20
      end
    else
      Theme.text("Catch this POK\xc3\xa9MON to read its entry.", COL_X + 12,
        descY + 12, F.small, "left", C.inkFaint)
    end

    -- the cart's PAGE / AREA / CRY / PRNT action bar -- with the peer's STAT /
    -- LVL slots when national_dex is loaded -- and the engine's own selected
    -- action lit.  newEntry (the two-page first-catch view) has no bar.
    if not self.newEntry then
      local ay = Shell.FOOT_RULE_Y - 8 - 26
      g2actionBar(self, F, C, COL_X, ay, COL_W - 64)
      local pg = (self.page == 2) and 2 or 1
      Theme.text(("PAGE %d/2"):format(pg), W - MARGIN, ay + 3, F.small,
        "right", C.inkDim)
    end

    local hints = { { key = "\xe2\x86\x90\xe2\x86\x92", text = "ACTION" } }
    if g2hasForms(self, row.species) then
      hints[#hints + 1] = { key = "\xe2\x86\x91\xe2\x86\x93", text = "FORM" }
    end
    hints[#hints + 1] = { key = "A", text = self.newEntry and "NEXT" or "SELECT" }
    hints[#hints + 1] = { key = "B", text = "BACK" }
    Shell.footer(Theme, game, { hints = hints })

    Theme.set(C.white)
  end

  -- ---- national_dex's Gen 2 STAT page, on the suite page
  --
  -- The peer draws this on Gold's tile grid (gen2dexlist.lua's drawStats); the
  -- data is the same (ui/national_dex.lua's g2Info, off statsBySpecies and
  -- evolutionsOf) and the layout is the suite's: portrait and types on the
  -- left, the abilities and the base-stat block on the right.  Reached only
  -- when the peer's STAT slot is selected and A pressed -- the peer's own
  -- update sets self.view, this arm only reads it.
  function M.drawStats2(self)
    local game, C, F = g2page(self)
    local row = g2safe(self.current, self)
    if not row then return M.drawList2(self) end
    local entry = g2entry(self, row.species) or {}
    local species = g2shown(self, row.species)
    local info = NatDex.g2Info(species, self.pokemon and self.pokemon[species])
    local SPR_W, SPR_H = 190, 150
    local SPR_X, SPR_Y = MARGIN, Shell.CONTENT_Y
    local TYPE_Y = SPR_Y + SPR_H + 8
    local COL_X = SPR_X + SPR_W + 12
    local COL_W = (W - MARGIN) - COL_X

    local caption = g2text(entry.kind) or ""
    local formTag = g2formTag(self, row.species)
    if formTag ~= "" then
      caption = (caption == "") and formTag
        or (caption .. "  \xc2\xb7  " .. formTag)
    end
    g2header(self, F, caption)

    Theme.panel(SPR_X, SPR_Y, SPR_W, SPR_H, { radius = 6, shadow = 3 })
    g2pic(self, row, SPR_X, SPR_Y, SPR_W, SPR_H)

    local typeRows = {}
    if info.type1 and info.type2 then
      typeRows = {
        { text = "TYPE 1", right = info.type1 },
        { text = "TYPE 2", right = info.type2 },
      }
    elseif info.type1 then
      typeRows = { { text = "TYPE", right = info.type1 } }
    end
    if #typeRows > 0 then
      Shell.list(Theme, game, {
        rows = typeRows, x = SPR_X, y = TYPE_Y, w = SPR_W, row = 28,
        labelPad = 14, rightPad = 14, font = F.small, t = self.__t or 0,
      })
    end

    local y = SPR_Y
    local abilities = info.abilities or nil
    if abilities then
      local rows = { { header = true, text = "ABILITIES" } }
      for _, r in ipairs(abilities) do
        rows[#rows + 1] = { text = r.name,
          right = r.hidden and "HIDDEN" or nil }
      end
      Shell.list(Theme, game, {
        rows = rows, x = COL_X, y = y, w = COL_W, row = 26,
        labelPad = 22, rightPad = 16, t = self.__t or 0,
      })
      y = y + (#rows * 26 + 4) + 10
    end
    g2statPanel(info.statRows, COL_X, y, COL_W,
      Shell.FOOT_RULE_Y - 8 - y, C, F)

    local hints = {}
    if g2hasForms(self, row.species) then
      hints[#hints + 1] = { key = "\xe2\x86\x91\xe2\x86\x93", text = "FORM" }
    end
    hints[#hints + 1] = { key = "A/B", text = "BACK" }
    Shell.footer(Theme, game, {
      hints = hints,
      right = ("%d/%d"):format(2, info.lastPage or 2),
    })

    Theme.set(C.white)
  end

  -- ---- national_dex's Gen 2 LVL view, on the suite page
  --
  -- The peer's sixth bar slot: the species' evolution line, then its level-up
  -- list, paged.  The sections come from ui/national_dex.lua's g2MovePages (the
  -- same builders the Gen 1 strip uses, at Gold's 14 rows a page) and the page
  -- index is the peer's own self.movePage, so UP/DOWN and LEFT/RIGHT keep
  -- working exactly as the peer wired them -- this arm only reads the state.
  function M.drawMoves2(self)
    local game, C, F = g2page(self)
    local row = g2safe(self.current, self)
    if not row then return M.drawList2(self) end
    local species = g2shown(self, row.species)
    local info = NatDex.g2Info(species, self.pokemon and self.pokemon[species])
    local pages = info.movePages or {}
    local count = #pages
    local index = 1
    if count > 0 then
      index = tonumber(self.movePage) or 1
      if index < 1 then index = 1
      elseif index > count then index = count end
    end
    local page = pages[index]

    local caption = page and page.title or ""
    local formTag = g2formTag(self, row.species)
    if formTag ~= "" then
      caption = (caption == "") and formTag
        or (caption .. "  \xc2\xb7  " .. formTag)
    end
    g2header(self, F, caption)

    local rows = {}
    for _, r in ipairs(page and page.rows or {}) do
      rows[#rows + 1] = {
        text = r.text, right = r.right, indent = r.indent, marker = r.mark,
      }
    end
    if #rows > 0 then
      Shell.list(Theme, game, {
        rows = rows, x = MARGIN, y = Shell.CONTENT_Y, w = W - MARGIN * 2,
        row = 20, labelPad = 24, rightPad = 16, font = F.small,
        t = self.__t or 0,
      })
    else
      Theme.panel(MARGIN, Shell.CONTENT_Y, W - MARGIN * 2, 90,
        { radius = 6, shadow = 3 })
      Theme.text("NO DATA", W * 0.5, Shell.CONTENT_Y + 36, F.body, "center",
        C.inkFaint)
    end

    local hints = { { key = "\xe2\x86\x91\xe2\x86\x93", text = "PAGE" } }
    if g2hasForms(self, row.species) then
      hints[#hints + 1] = { key = "\xe2\x86\x90\xe2\x86\x92", text = "FORM" }
    end
    hints[#hints + 1] = { key = "A/B", text = "BACK" }
    Shell.footer(Theme, game, {
      hints = hints,
      right = count > 1 and ("%d/%d"):format(index, count) or nil,
    })

    Theme.set(C.white)
  end

  return M
end
