-- ui/summary.lua -- the POKeMON summary, rebuilt as an ADV.STATS panel.
--
-- Two presentations out of one layout:
--
--   * OVER the POKeMON screen (the normal case): the state below is one of
--     ours, so this screen is NON-opaque -- StateStack:visibleBase() then
--     stops at the party menu and Game:draw draws BOTH states -- and it dims
--     that menu, then floats a 486x324 panel (90% of the 540x360 surface on
--     both axes -- the page's type grew to 30px, so the panel grew with it) in
--     the middle.  The menu stays visible around and behind it.
--   * OVER anything else (a battle, Bill's PC): opaque, with the same panel on
--     this mod's backdrop, so nothing that was never designed for this surface
--     is left half-drawn underneath.
--
-- Four pages, left/right (or A) to turn, B to close:
--   1 STATS  the six real combat stats with bars, plus identity/mechanics
--   2 EVS    the EV spread, each bar against the real 252-per-stat cap
--   3 IVS    the IV spread, each bar against 0-31
--   4 MOVES  the four moves with category and PP, plus the EXP situation
--
-- The stat block itself comes from the engine's own Stats.ensure; the modern
-- split / ability / nature / Tera / Dynamax fields come from g9-battle-engine's
-- exported ModernStats and accessors when that mod is installed.  Every read
-- is guarded, so the panel still shows a correct vanilla stat block (with
-- blank modern rows) when it is not.
--
-- GEN 2: Gold's SummaryMenu is a different screen -- three pages (stats /
-- moves / trainer data), the move manager and the egg page all in one, with
-- its own party-walking navigation.  The Gen 2 arm therefore builds Gold's own
-- src.ui.gen2.SummaryMenu (so all of that keeps running) and paints the suite
-- panel through :drawWidescreen -- see the Gen 2 arm at the end.
return function(mod, ctx)
  local Theme, Backdrop = ctx.Theme, ctx.Backdrop
  local opt = ctx.opt
  local MS, MoveCategory = ctx.ModernStats, ctx.MoveCategory
  -- the engine mod's handle, for the accessors g9-gui does not own
  local engine = ctx.engine
  -- the shared roster/status reader (ui/roster.lua), for the Gen 2 identity
  -- column's status chip
  local Roster = ctx.Roster
  local Gen2 = ctx.gen == 2
  -- the shared page (surface fit/scale), used by the Gen 2 widescreen arm only
  local Shell = ctx.Shell

  local M = {}
  local Stats = require("src.pokemon.Stats")

  local W, H = 540, 360
  local PW, PH = 486, 324          -- 90% of the surface, both axes
  local OX = math.floor((W - PW) * 0.5)   -- 27
  local OY = math.floor((H - PH) * 0.5)   -- 18

  local ORDER = { "hp", "atk", "def", "spa", "spd", "spe" }
  local LABEL = { hp = "HP", atk = "ATK", def = "DEF", spa = "SP.ATK",
                  spd = "SP.DEF", spe = "SPEED" }
  local NONE = "----"
  local PAGES = { "STATS", "EVS", "IVS", "MOVES" }

  -- panel-local layout (the panel's own 486x324, not the screen).  Type is
  -- Saira at body 22 / secondary 13 (ui/theme.lua), so every column here is a
  -- measured budget: the stat LABEL column is 76px ("SP.ATK") and a 3-digit
  -- value right-aligned at 142 still clears it, which leaves the bar its 106.
  local TAB_Y, TAB_H = 48, 26
  local ROW_TOP, ROW_STEP = 92, 27
  local BODY_X, VAL_R, BAR_X, BAR_W, BAR_H = 20, 142, 152, 106, 13
  local ID_X, ID_R = 296, 466
  local MV_TOP, MV_STEP = 106, 27
  local MV_CAT_X, MV_PP_R = 320, 466

  if MS and MS.ORDER then ORDER = MS.ORDER end

  local drawStatRows, drawIdentity, drawMovePage, panelTitle, pageTotal

  local function safeText(v)
    if v == nil or tostring(v) == "" then return NONE end
    return tostring(v)
  end

  local function statOf(mon, key)
    local s = mon.stats or {}
    -- Gen 1 writes the derived block as spa/spd/spe (or a single `special`);
    -- Gold's Stats.calc writes attack/defense/specialAttack/specialDefense/
    -- speed.  Both spellings are read here so one stat row serves either game.
    if key == "spa" then return s.spa or s.specialAttack or s.special or s.spAtk or 0 end
    if key == "spd" then return s.spd or s.specialDefense or s.special or s.spDef or 0 end
    if key == "spe" then return s.spe or s.speed or 0 end
    if key == "atk" then return s.atk or s.attack or 0 end
    if key == "def" then return s.def or s.defense or 0 end
    if key == "hp" then return s.hp or 0 end
    return s[key] or 0
  end

  -- The engine's stats accessor plus the engine mod's modern split.  All of it
  -- is pcall-guarded: a vanilla-only boot (or a mon handed in by another mod)
  -- must still open the panel.
  local function ensure(mon, def)
    pcall(function() Stats.ensure(def, mon) end)
    if MS and MS.ensure then pcall(function() MS.ensure(def, mon) end) end
    if MS and MS.generateAbility then
      local nd = mod.find and mod.find("national_dex")
      pcall(function()
        MS.generateAbility(mon, MS.resolveAbilities
          and MS.resolveAbilities(mon.species, nd and nd.exports))
      end)
    end
    if MS and MS.generateNature then pcall(function() MS.generateNature(mon) end) end
  end

  local function engineAccessor(name, ...)
    if not (engine and engine.exports) then return nil end
    local fn = engine.exports[name]
    if not fn then return nil end
    local ok, v = pcall(fn, ...)
    return ok and v or nil
  end

  local function moveData(game, mon, i)
    local mv = mon.moves and mon.moves[i]
    if not mv then return nil end
    local mdef = game.data.moves and game.data.moves[mv.id]
    local pp = (mdef and mdef.pp) or 0
    local maxPP = pp + (mv.ppUps or 0) * math.floor(pp / 5)
    local cat
    if MoveCategory and mdef then cat = MoveCategory.of(mdef) end
    if not cat and mdef then cat = mdef.category end
    return mv, mdef, maxPP, cat
  end

  -- ---------------------------------------------------------------- surfaces

  function M.uiSize() return W, H end
  function M.isWideBattleLayout() return true end
  -- The panel is a 540x360 page like the menu it floats over, so it fills the
  -- window at the same scale (see ui/start_menu.lua for the full reasoning).
  function M.wantsFillScale() return true end
  function M.sgbPalettes() return {} end

  function M.new(game, a)
    if Gen2 then return M.newGen2(game, a) end
    local mon = a
    local top = game.stack and game.stack.top and game.stack:top()
    -- overlay only when the screen underneath is one of ours and is actually
    -- going to draw (isOpaque on the party menu is what keeps it the base)
    local overlay = (top and top.__g9gui and top.isOpaque) and true or false
    local def = game.data.pokemon and game.data.pokemon[mon.species]
    ensure(mon, def)
    local self = {
      game = game, mon = mon, def = def, page = 1, overlay = overlay,
      isOpaque = not overlay, letterboxWhite = true, screenId = "SummaryMenu",
      __g9gui = true, __t = 0,
    }
    setmetatable(self, { __index = M })
    pcall(function()
      require("src.core.Sound").playCry(game.data, mon.species)
    end)
    return self
  end

  function M:update(dt)
    if self.closing then return end
    self.__t = (self.__t or 0) + 1
    local input = self.game.input
    if input:wasPressed("right") then
      self.page = self.page % #PAGES + 1
    elseif input:wasPressed("left") then
      self.page = (self.page - 2) % #PAGES + 1
    elseif input:wasPressed("a") then
      self.page = self.page % #PAGES + 1
    elseif input:wasPressed("b") then
      self.closing = true
      self.game.stack:pop()
    end
  end

  -- ---------------------------------------------------------------- rendering

  function panelTitle(mon, def, font)
    local name = mon.nickname or (def and def.name) or tostring(mon.species)
    -- the title bar's right half is PW - BODY_X - (ADV.STATS + gap) wide; the
    -- "  Lv100" suffix is ~80px at body 22, so the name gets 225 of it
    return (Theme.fit(name or "?", font, 225) or "?")
      .. ("  Lv%d"):format(mon.level or 0)
  end

  function pageTotal(mon, page)
    if page == 2 and mon.evs then
      local sum = 0
      for _, k in ipairs(ORDER) do sum = sum + (mon.evs[k] or 0) end
      return ("EV TOTAL %d/510"):format(sum)
    end
    if page == 3 and mon.ivs then
      local sum = 0
      for _, k in ipairs(ORDER) do sum = sum + (mon.ivs[k] or 0) end
      return ("IV TOTAL %d/186"):format(sum)
    end
    return nil
  end

  function drawStatRows(self, t, bar, mon, mode)
    local C = Theme.col
    local maxStat = 0
    if mode == "stat" then
      for _, k in ipairs(ORDER) do
        local v = statOf(mon, k)
        if v > maxStat then maxStat = v end
      end
    end
    local y = ROW_TOP
    for _, key in ipairs(ORDER) do
      local value, ref
      if mode == "ev" then
        value, ref = (mon.evs and mon.evs[key]) or 0, 252
      elseif mode == "iv" then
        value, ref = (mon.ivs and mon.ivs[key]) or 0, 31
      else
        value, ref = statOf(mon, key), maxStat
      end
      local frac = value / math.max(1, ref)
      if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
      t(LABEL[key] or key, BODY_X, y, "left", C.inkDim)
      t(tostring(value), VAL_R, y, "right", C.ink, Theme.fonts(self.game).bold)
      bar(BAR_X, y + 4, BAR_W, BAR_H, frac,
        (mode == "iv") and C.gold or C.accent, { bg = C.panelDeep, border = C.border })
      y = y + ROW_STEP
    end
  end

  function drawIdentity(self, t, mon, def)
    local C = Theme.col
    local TypeChart = require("src.battle.TypeChart")
    local tl = {}
    local types = (def and def.types) or {}
    for i = 1, #types do
      local ok, d = pcall(TypeChart.displayName, types[i])
      tl[i] = (ok and d) or tostring(types[i])
    end
    local rows = {
      { "ABIL", safeText(mon.ability) },
      { "NAT", safeText(mon.nature) },
      { "TYPE", #tl > 0 and table.concat(tl, " / ") or NONE },
      { "ITEM", safeText(mon.item) },
      { "TERA", safeText(engineAccessor("getTeraType", mon)) },
      { "DMAX", safeText(engineAccessor("getDynamaxLevel")) },
    }
    -- secondary size: the identity block is the panel's metadata column, and
    -- at body 22 a "GRASS / POISON" value would not fit the space beside the
    -- stat rows (189px against 170).  Each value is then cut to the pixels its
    -- own label leaves, so a long item or ability name can never run into it.
    local small = Theme.fonts(self.game).small
    local y = ROW_TOP
    for _, r in ipairs(rows) do
      t(r[1], ID_X, y + 7, "left", C.inkFaint, small)
      local budget = (ID_R - ID_X) - Theme.w(r[1], small) - 12
      t(Theme.fit(r[2], small, budget), ID_R, y + 7, "right", C.ink, small)
      y = y + ROW_STEP
    end
  end

  function drawMovePage(self, t, game, mon, def)
    local C = Theme.col
    local F = Theme.fonts(game).body
    local y = MV_TOP - MV_STEP + 2
    t("MOVE", BODY_X, y, "left", C.inkFaint)
    t("CAT", MV_CAT_X, y, "left", C.inkFaint)
    t("PP", MV_PP_R, y, "right", C.inkFaint)
    y = MV_TOP
    for i = 1, 4 do
      local mv, mdef, maxPP, cat = moveData(game, mon, i)
      if mv then
        local name = (mdef and mdef.name) or tostring(mv.id)
        name = Theme.fit(name, F, MV_CAT_X - BODY_X - 16)
        t(name, BODY_X, y, "left", C.ink)
        local catText, catCol = "---", C.inkFaint
        if cat == "Physical" or cat == "PHYSICAL" then catText, catCol = "PHY", C.bad
        elseif cat == "Special" or cat == "SPECIAL" then catText, catCol = "SPE", C.accent
        elseif cat == "Status" or cat == "STATUS" then catText, catCol = "STA", C.inkDim end
        t(catText, MV_CAT_X, y, "left", catCol)
        t(("%d/%d"):format(mv.pp or 0, maxPP), MV_PP_R, y, "right",
          (mv.pp or 0) > 0 and C.ink or C.bad)
      else
        t("-", BODY_X, y, "left", C.inkFaint)
        t("---", MV_CAT_X, y, "left", C.inkFaint)
        t("--/--", MV_PP_R, y, "right", C.inkFaint)
      end
      y = y + MV_STEP
    end
    y = y + 8
    Theme.set(C.border)
    local lx, ly = OX + BODY_X, OY + y
    Theme.rect("fill", lx, ly, PW - BODY_X * 2, 1, 0)
    t(("EXP %d"):format(mon.exp or 0), BODY_X, y + 8, "left", C.inkDim)
    if def and def.growthRate and (mon.level or 1) < 100 then
      local Growth = require("src.pokemon.Growth")
      local ok, need = pcall(function()
        return Growth.expForLevel(def.growthRate, mon.level + 1) - (mon.exp or 0)
      end)
      t(("NEXT LV %d"):format(math.max(0, ok and need or 0)), PW - BODY_X, y + 8,
        "right", C.gold)
    end
  end

  function M:draw()
    local game = self.game
    local mon = self.mon
    local C = Theme.col
    local F = Theme.fonts(game)
    local def = self.def or (game.data.pokemon and game.data.pokemon[mon.species])
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"

    if self.overlay then
      -- the party menu is still drawn beneath this state: dim it, keep it
      -- visible around the panel
      Theme.set(C.black, 0.62)
      Theme.rect("fill", 0, 0, W, H, 0)
    else
      Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
        background = background, embellishment = embellish })
    end

    -- the 75% panel
    Theme.panel(OX, OY, PW, PH, { radius = 8, shadow = 5,
      color = C.panelLit, border = C.borderLit })
    if embellish then
      Theme.brackets(OX + 5, OY + 5, PW - 10, PH - 10, 20, C.accentDim)
    end

    -- panel-local origin: every page body below is written in panel
    -- coordinates through these two closures
    local function P(x, y) return OX + x, OY + y end
    local function t(str, x, y, align, col, font)
      local px, py = P(x, y)
      Theme.text(str, px, py, font or F.body, align, col)
    end
    local function bar(x, y, w, h, frac, col, opts)
      local px, py = P(x, y)
      Theme.bar(px, py, w, h, frac, col, opts)
    end

    -- title bar
    Theme.set(C.panelDeep, 0.95)
    Theme.rect("fill", OX + 1, OY + 1, PW - 2, 40, 7)
    Theme.set(C.accent, 0.35)
    Theme.rect("fill", OX + 1, OY + 41, PW - 2, 1, 0)
    t("ADV.STATS", BODY_X, 8, "left", C.accent)
    t(panelTitle(mon, def, Theme.fonts(game).body), PW - BODY_X, 8, "right", C.ink)

    -- page tabs
    do
      local x = BODY_X
      local y = TAB_Y
      for i, name in ipairs(PAGES) do
        local w = Theme.w(name, F.body) + 20
        local on = i == self.page
        Theme.set(on and C.accentDim or C.panelDeep, on and 1 or 0.7)
        local px, py = P(x, y)
        Theme.rect("fill", px, py, w, TAB_H, 4)
        if on then
          Theme.set(C.accent)
          Theme.rect("fill", px, py + TAB_H - 1, w, 1, 0)
        end
        t(name, x + w * 0.5, y + 4, "center", on and C.accent or C.inkFaint)
        x = x + w + 6
      end
    end

    if self.page == 1 then
      drawStatRows(self, t, bar, mon, "stat")
      drawIdentity(self, t, mon, def)
    elseif self.page == 2 then
      drawStatRows(self, t, bar, mon, "ev")
    elseif self.page == 3 then
      drawStatRows(self, t, bar, mon, "iv")
    else
      drawMovePage(self, t, game, mon, def)
    end

    -- footer
    Theme.set(C.border)
    local fx, fy = P(BODY_X, PH - 36)
    Theme.rect("fill", fx, fy, PW - BODY_X * 2, 1, 0)
    t("L/R  PAGE", BODY_X, PH - 30, "left", C.inkFaint)
    local total = pageTotal(mon, self.page)
    if total then t(total, PW - 90, PH - 30, "right", C.gold) end
    t(("%d/%d"):format(self.page, #PAGES), PW - BODY_X, PH - 30, "right", C.inkDim)

    Theme.set(C.white)
  end

  -- ============================================================= Gen 2 (Gold)
  -- Gold's SummaryMenu is ONE screen for three jobs: the three stats pages,
  -- the move manager (opened by the party list's MOVE row OR by SELECT on the
  -- MOVES page) and the egg page.  It owns its own navigation -- up/down walk
  -- the party, left/right turn PINK/GREEN/BLUE, A falls through to the next
  -- page and quits from BLUE, SELECT opens the move detail -- so, exactly like
  -- every other screen, this arm builds that engine object
  -- (src.ui.gen2.SummaryMenu) and swaps only :drawWidescreen.  What it draws is
  -- Gold's own information set, laid out in the suite's panel: a STATS page of
  -- the six derived stats, a MOVES page of the held item and the four moves, an
  -- INFO page of the OT / ID / dex number, the move manager, and the egg page.
  --
  -- The panel floats over the party page exactly as the Gen 1 panel does: the
  -- party screen beneath (one of ours) re-draws its own page for us, and the
  -- dim is then applied, so Gold reads as the same lift.

  local G2_TABS = { "STATS", "MOVES", "INFO" }

  -- pcall a method and take its first answer (or nil).  The engine object may
  -- be a bare stub and a missing accessor must not blank the page.
  local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    return ok and v or nil
  end

  local function g2def(self)
    return safe(self.speciesDef, self)
      or (self.pokemon and self.mon and self.pokemon[self.mon.species])
  end

  local function g2moves(self)
    return safe(self.moveList, self) or (self.mon and self.mon.moves) or {}
  end

  local function g2moveName(self, entry)
    if not entry then return nil end
    return safe(self.moveName, self, entry) or tostring(entry.id or "?")
  end

  -- Word-wrap a paragraph to a measured pixel budget (Saira is proportional,
  -- so there is no cell count to snap to).  The move manager's description
  -- plaque has room for two lines, so a one-line `Theme.fit` used to cut most
  -- of Gold's move text off mid-sentence.
  local function g2wrap(text, font, maxW)
    local out, line = {}, ""
    for word in tostring(text):gmatch("%S+") do
      local trial = (line == "" and word) or (line .. " " .. word)
      if line ~= "" and Theme.w(trial, font) > maxW then
        out[#out + 1] = line
        line = word
      else
        line = trial
      end
    end
    if line ~= "" then out[#out + 1] = line end
    return out
  end

  -- the party page beneath the summary (Gold's PartyMenu), if it is one of ours
  local function partyPageUnder(self)
    local states = self.game and self.game.stack and self.game.stack.states
    for i = #(states or {}), 1, -1 do
      local s = states[i]
      if s ~= self and s.__g9gui and type(s.__g9guiPage) == "function" then
        return s
      end
    end
    return nil
  end

  local function g2typeName(self, id)
    if not id then return NONE end
    local ok, TC = pcall(require, "src.battle.TypeChart")
    if ok and TC and TC.displayName then
      local ok2, n = pcall(TC.displayName, id, self.game and self.game.data)
      if ok2 and n then return n end
    end
    return tostring(id)
  end

  local function g2Title(self, egg, font)
    local mon = self.mon or {}
    if egg then return "EGG" end
    local def = g2def(self)
    local name = mon.nickname or mon.name or (def and def.name)
      or mon.species or "?"
    return (Theme.fit(name, font, 225) or "?")
      .. ("  Lv%d"):format(mon.level or 0)
  end

  function M.newGen2(game, opts)
    local Summary2 = require("src.ui.gen2.SummaryMenu")
    local self = Summary2.new(game, opts)
    self.__g9gui = true
    self.__t = 0
    -- tick an animation counter; the engine's own update (pages, party walk,
    -- the move manager, the cry) is otherwise untouched.
    local baseUpdate = self.update
    self.update = function(s, dt)
      s.__t = (s.__t or 0) + 1
      if baseUpdate then baseUpdate(s, dt) end
    end
    Shell.gen2Surface(Theme, self, function(s) M.drawGen2(s) end)
    return self
  end

  local function drawTabs2(self, t, C, F)
    local x = BODY_X
    for i, name in ipairs(G2_TABS) do
      local w = Theme.w(name, F.body) + 20
      local on = i == self.page
      Theme.set(on and C.accentDim or C.panelDeep, on and 1 or 0.7)
      Theme.rect("fill", OX + x, OY + TAB_Y, w, TAB_H, 4)
      if on then
        Theme.set(C.accent)
        Theme.rect("fill", OX + x, OY + TAB_Y + TAB_H - 1, w, 1, 0)
      end
      t(name, x + w * 0.5, TAB_Y + 4, "center", on and C.accent or C.inkFaint)
      x = x + w + 6
    end
  end

  -- PINK page: the six derived stats with bars on the left, the identity /
  -- HP / status / type / exp block on the right.
  local function drawStats2(self, t, bar, C, F)
    local mon = self.mon or {}
    drawStatRows(self, t, bar, mon, "stat")
    local small = Theme.fonts(self.game).small
    local maxHp = mon.maxHp or (mon.stats and mon.stats.hp) or 0
    local slabel
    if Roster and Roster.status then slabel = (Roster.status(self.game, mon)) end
    local okT, t1, t2 = pcall(function() return self:typeNames() end)
    if not okT then t1, t2 = nil, nil end
    local typeStr = t1 or NONE
    if t2 and t2 ~= t1 then typeStr = typeStr .. " / " .. t2 end
    local rows = {
      { "HP", ("%d/%d"):format(mon.hp or 0, maxHp) },
      { "STATUS", slabel or "OK" },
      { "TYPE", typeStr },
      { "ITEM", safe(self.itemName, self) or NONE },
      { "EXP", tostring(mon.experience or 0) },
      { "NEXT", tostring(safe(self.expToNext, self) or 0) },
    }
    local y = ROW_TOP
    for _, r in ipairs(rows) do
      t(r[1], ID_X, y + 7, "left", C.inkFaint, small)
      local budget = (ID_R - ID_X) - Theme.w(r[1], small) - 12
      t(Theme.fit(r[2], small, budget), ID_R, y + 7, "right", C.ink, small)
      y = y + ROW_STEP
    end
  end

  -- GREEN page: the held item and the four moves with their PP.
  local function drawMoves2(self, t, C, F)
    -- the tab row occupies TAB_Y..TAB_Y+TAB_H, so the first line starts clear
    -- of it (a row at ROW_TOP - ROW_STEP would run under the tabs)
    local y = TAB_Y + TAB_H + 12
    t("ITEM", BODY_X, y, "left", C.inkFaint)
    t(safe(self.itemName, self) or "---", BODY_X + 80, y, "left", C.ink)
    y = y + ROW_STEP
    t("MOVE", BODY_X, y, "left", C.inkFaint)
    t("PP", MV_PP_R, y, "right", C.inkFaint)
    y = y + MV_STEP - 4
    local moves = g2moves(self)
    for i = 1, 4 do
      local entry = moves[i]
      if entry then
        t(Theme.fit(g2moveName(self, entry) or "-", F.body,
          MV_CAT_X - BODY_X - 16), BODY_X, y, "left", C.ink)
        t(("%d/%d"):format(entry.pp or 0, entry.maxPp or entry.pp or 0),
          MV_PP_R, y, "right", (entry.pp or 0) > 0 and C.ink or C.bad)
      else
        t("-", BODY_X, y, "left", C.inkFaint)
        t("--/--", MV_PP_R, y, "right", C.inkFaint)
      end
      y = y + MV_STEP
    end
    Theme.set(C.border)
    Theme.rect("fill", OX + BODY_X, OY + y + 4, PW - BODY_X * 2, 1, 0)
    t("SELECT  MOVE MANAGER", BODY_X, y + 12, "left", C.gold)
  end

  -- BLUE page: the trainer data (ID / OT / dex number) beside the stats.
  local function drawInfo2(self, t, bar, C, F)
    local mon = self.mon or {}
    local small = Theme.fonts(self.game).small
    local def = g2def(self)
    local rows = {
      { "ID", tostring(safe(self.otId, self) or 0) },
      { "OT", tostring(safe(self.otName, self) or "?") },
      { "DEX", ("No.%03d"):format((def and def.dex) or 0) },
    }
    local y = ROW_TOP
    for _, r in ipairs(rows) do
      t(r[1], BODY_X, y, "left", C.inkFaint, small)
      t(r[2], BODY_X + 70, y, "left", C.ink)
      y = y + ROW_STEP
    end
    local y2 = ROW_TOP
    for _, k in ipairs(ORDER) do
      t(LABEL[k] or k, ID_X, y2 + 7, "left", C.inkFaint, small)
      t(tostring(statOf(mon, k)), ID_R, y2 + 7, "right", C.ink, small)
      y2 = y2 + ROW_STEP
    end
  end

  local function drawEgg2(self, t, C, F)
    local mon = self.mon or {}
    t("EGG", BODY_X, ROW_TOP, "left", C.accent)
    t("ID   ?????", BODY_X, ROW_TOP + ROW_STEP, "left", C.inkDim)
    t("OT   ?????", BODY_X, ROW_TOP + ROW_STEP * 2, "left", C.inkDim)
    local steps = mon.eggSteps or 0
    local flavor = steps < 6
      and "It's making sounds inside.  It's going to hatch soon!"
      or steps < 11 and "It moves around inside sometimes."
      or steps < 41 and "Wonder what's inside?  It needs more time."
      or "This EGG needs a lot more time to hatch."
    local ly = ROW_TOP + ROW_STEP * 3 + 6
    Theme.set(C.border)
    Theme.rect("fill", OX + BODY_X, OY + ly, PW - BODY_X * 2, 1, 0)
    t(Theme.fit(flavor, F.body, PW - BODY_X * 2), BODY_X, ly + 12, "left",
      C.inkDim)
  end

  -- The move manager: the four slots with a cursor, and either the held-move
  -- "Where?" prompt or the selected move's type / attack power / description.
  local function drawMoveDetail2(self, t, bar, C, F)
    local moves = g2moves(self)
    local y = ROW_TOP - 12
    for i = 1, 4 do
      local entry = moves[i]
      local held = i == self.swapFrom
      local sel = i == self.moveIndex
      if sel or held then
        Theme.set(sel and C.rowLit or C.accentDim, sel and 0.55 or 0.28)
        Theme.rect("fill", OX + BODY_X - 8, OY + y - 5,
          PW - (BODY_X - 8) * 2, MV_STEP - 4, 5)
      end
      if sel then
        Theme.chevrons(OX + BODY_X - 4, OY + y + 2, 16, C.accent,
          0.5 + 0.5 * math.sin((self.__t or 0) * 0.2))
      end
      t(entry and (g2moveName(self, entry) or "-") or "-", BODY_X + 16, y,
        "left", sel and C.accent or C.ink)
      if entry then
        t(("%d/%d"):format(entry.pp or 0, entry.maxPp or entry.pp or 0),
          PW - BODY_X, y, "right", (entry.pp or 0) > 0 and C.ink or C.bad)
      else
        t("--/--", PW - BODY_X, y, "right", C.inkFaint)
      end
      y = y + MV_STEP
    end
    y = y + 6
    Theme.set(C.border)
    Theme.rect("fill", OX + BODY_X, OY + y, PW - BODY_X * 2, 1, 0)
    if self.swapFrom then
      t("Where?", BODY_X, y + 10, "left", C.gold)
      return
    end
    local entry = moves[self.moveIndex]
    local def = entry and safe(self.moveDef, self, entry.id)
    local power = (def and def.power) or 0
    t("TYPE", BODY_X, y + 10, "left", C.inkFaint)
    t(g2typeName(self, def and def.type), BODY_X + 60, y + 10, "left", C.ink)
    t("ATTK/", BODY_X + 210, y + 10, "left", C.inkFaint)
    t(power >= 2 and tostring(power) or "---", BODY_X + 280, y + 10, "left",
      C.ink)
    local desc = (def and def.description) or ""
    desc = tostring(desc):gsub("<NEXT>", "  ")
    local budget = PW - BODY_X * 2
    local lines = g2wrap(desc, F.body, budget)
    if lines[1] then
      t(lines[1], BODY_X, y + 10 + ROW_STEP, "left", C.inkDim)
    end
    if lines[2] then
      -- everything from the second line on, re-fitted to one line so a longer
      -- description ends in an ellipsis instead of being silently dropped
      local rest = table.concat(lines, " ", 2)
      t(Theme.fit(rest, F.body, budget), BODY_X, y + 10 + ROW_STEP * 2,
        "left", C.inkDim)
    end
  end

  function M.drawGen2(self)
    local game = self.game
    local C = Theme.col
    local F = Theme.fonts(game)
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"

    -- the party page under the panel (Gold's PartyMenu draws its own page for
    -- us), so the summary reads as the same lift it is on Gen 1
    local under = partyPageUnder(self)
    if under then
      under.__g9guiPage(under)
    else
      Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
        background = background, embellishment = embellish })
    end
    Theme.set(C.black, 0.62)
    Theme.rect("fill", 0, 0, W, H, 0)

    Theme.panel(OX, OY, PW, PH, { radius = 8, shadow = 5,
      color = C.panelLit, border = C.borderLit })
    if embellish then
      Theme.brackets(OX + 5, OY + 5, PW - 10, PH - 10, 20, C.accentDim)
    end

    local function P(x, y) return OX + x, OY + y end
    local function t(str, x, y, align, col, font)
      local px, py = P(x, y)
      Theme.text(str, px, py, font or F.body, align, col)
    end
    local function bar(x, y, w, h, frac, col, o)
      local px, py = P(x, y)
      Theme.bar(px, py, w, h, frac, col, o)
    end

    local egg = self.mon and self.mon.isEgg
    local moveMode = self.moveScreen or self.moveDetail

    Theme.set(C.panelDeep, 0.95)
    Theme.rect("fill", OX + 1, OY + 1, PW - 2, 40, 7)
    Theme.set(C.accent, 0.35)
    Theme.rect("fill", OX + 1, OY + 41, PW - 2, 1, 0)
    t(moveMode and "MOVE MANAGER" or "ADV.STATS", BODY_X, 8, "left", C.accent)
    t(g2Title(self, egg, F.body), PW - BODY_X, 8, "right", C.ink)

    if egg then
      drawEgg2(self, t, C, F)
    elseif moveMode then
      drawMoveDetail2(self, t, bar, C, F)
    else
      drawTabs2(self, t, C, F)
      if self.page == 2 then drawMoves2(self, t, C, F)
      elseif self.page == 3 then drawInfo2(self, t, bar, C, F)
      else drawStats2(self, t, bar, C, F) end
    end

    Theme.set(C.border)
    Theme.rect("fill", OX + BODY_X, OY + PH - 36, PW - BODY_X * 2, 1, 0)
    if moveMode then
      t("A  PICK/PLACE", BODY_X, PH - 30, "left", C.inkFaint)
      t("L/R  POK\xc3\xa9MON", PW * 0.5, PH - 30, "center", C.inkFaint)
      t("B  BACK", PW - BODY_X, PH - 30, "right", C.inkFaint)
    else
      t("L/R  PAGE", BODY_X, PH - 30, "left", C.inkFaint)
      t(G2_TABS[self.page] or "", PW - BODY_X, PH - 30, "right", C.inkDim)
    end

    Theme.set(C.white)
  end

  return M
end
