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
return function(mod, ctx)
  local Theme, Backdrop = ctx.Theme, ctx.Backdrop
  local opt = ctx.opt
  local MS, MoveCategory = ctx.ModernStats, ctx.MoveCategory
  -- the engine mod's handle, for the accessors g9-gui does not own
  local engine = ctx.engine

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
    if key == "spa" then return s.spa or s.special or s.spAtk or 0 end
    if key == "spd" then return s.spd or s.special or s.spDef or 0 end
    if key == "spe" then return s.spe or s.speed or 0 end
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

  function M.new(game, mon)
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

  return M
end
