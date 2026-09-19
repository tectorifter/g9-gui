-- ui/roster.lua -- the party roster table: the right-hand column of BOTH the
-- START screen and the POKeMON screen, so the two read as one layout.
--
-- One row per party slot (up to six), top to bottom:
--
--      *  [ portrait ]  BULBASAUR  210/210        Lv 63
--         [  head    ]  #########HP####  ******EXP**
--
-- The portrait is a wide band (56x34), not a square tile: the pack's art is a
-- full-body frame, and a band cropped to its head is the one shape that reads
-- as a portrait at this size (ui/portraits.lua does the crop).  The name, the
-- HP/MAX figures and the level share ONE line, with the HP and EXP gauges on
-- the band under it.  Six rows of 40px fill the roster column.
--
-- There is no header row: at body 22 a heading row would push the sixth slot
-- past the footer rule, and the gold level / "30/38" figures do not need column
-- titles to be read.
--
-- MONEY is deliberately NOT a column here: it is a single readout on the
-- header's second line (ui/shell.lua), directly under the BADGES/DEX readout.
--
-- Columns (offsets from the area's left edge; the area is 348 wide).  Every
-- one of them is a MEASURED budget, not a character count: Saira is
-- proportional, so a name is truncated by Theme.fit against the pixels that
-- actually remain before the HP figures.
--   chevron       2 ..  20   (18px cursor, centred in the row)
--   portrait     24 ..  80   (56 wide, 34 tall)
--   name         88 (left-aligned, cut to the pixels the HP figures leave)
--   HP/MAX       right-aligned at 282 (secondary size) -- beside the name
--   LEVEL        right-aligned at 348 (gold, SemiBold, a tiny "Lv" prefix)
--   HP gauge     88 .. 254   (row bottom, 11 tall)
--   EXP bar     264 .. 348   (row bottom, 11 tall)
return function(mod)
  local R = {}

  local Growth = require("src.pokemon.Growth")

  R.ROW_H = 40
  R.HEADER_H = 0

  local CHEV_X, CHEV_S = 2, 18
  -- The card is 56x34 (1.65:1), not a 96px band: a wider card forced a bigger
  -- head-crop zoom and the top of the frame alone filled it.  The crop takes
  -- the card's own 56x34 of the trimmed frame, anchored to the creature's head
  -- and drawn at the pack's OWN 1:1 pixels (see ui/portraits.lua), so every
  -- species keeps the size the pack gives it -- a Weedle beside an Amoonguss.
  local CARD_X, CARD_W, CARD_YO, CARD_H = 24, 56, 3, 34
  local NAME_X = 88
  -- Round 200 swapped the two right-hand columns: the HP/MAX figures sit next
  -- to the name (where the level used to be) and the level moved out to the
  -- row's right edge with a tiny "Lv" ahead of it.
  local HP_R, LV_R = 282, 348
  local HPG_X, HPG_W, HPG_H = 88, 166, 11
  local EXP_X, EXP_W, EXP_H = 264, 84, 11
  -- every y below is an INK top (Theme.text's y), so a 15px line occupies
  -- [y, y+15): the row's text sits at 4, the gauges in the band under it.
  local LINE_Y, BARS_Y = 4, 26
  local NAME_MAX_PX = 154

  local function defOf(game, mon)
    return game.data.pokemon and game.data.pokemon[mon.species]
  end

  function R.name(mon, def)
    return mon.nickname or (def and def.name) or tostring(mon.species or "?")
  end

  -- Gold keeps the max on the record itself (Mon.refreshStats writes mon.maxHp);
  -- Gen 1 reads it off the derived stat block.  Both are checked so one reader
  -- serves either generation.
  function R.maxHp(mon)
    return mon.maxHp or (mon.stats and mon.stats.hp) or 0
  end

  function R.hpFrac(mon)
    local max = R.maxHp(mon)
    if max <= 0 then return 0 end
    local f = (mon.hp or 0) / max
    if f < 0 then f = 0 elseif f > 1 then f = 1 end
    return f
  end

  -- the experience needed to reach `lvl` on the def's curve.  Gen 1 has the
  -- whole table in src.pokemon.Growth; Gold keeps its curves on the data
  -- (data.pokemon.growthRates) and answers through src.battle.gen2.Mon, so the
  -- two are tried in that order and a missing curve degrades to 0, not an error.
  local function expAt(game, def, lvl, gen)
    if gen == 2 then
      local ok, Mon = pcall(require, "src.battle.gen2.Mon")
      if ok and Mon and Mon.growthFor and Mon.experienceForLevel then
        local growth = Mon.growthFor(game and game.data, def.growthRate)
        if growth then return Mon.experienceForLevel(growth, lvl) end
      end
      return nil
    end
    return Growth.expForLevel(def.growthRate, lvl)
  end

  -- fraction of the way from this level's floor to the next level's floor
  function R.expFrac(mon, def, gen, game)
    if not def or not def.growthRate then return 0 end
    local lvl = mon.level or 1
    if lvl >= 100 then return 1 end
    local cur = expAt(game, def, lvl, gen)
    local nxt = expAt(game, def, lvl + 1, gen)
    if not (cur and nxt) then return 0 end
    if nxt <= cur then return 1 end
    -- Gold keeps the running total on `experience`, Gen 1 (and the suite's own
    -- fixtures) on `exp`; read whichever is there.
    local f = (((mon.exp or mon.experience) or 0) - cur) / (nxt - cur)
    if f < 0 then f = 0 elseif f > 1 then f = 1 end
    return f
  end

  -- the status chip's label and palette key, or nil.  Gold keeps its status
  -- registry on data.gen2Statuses and spells the status as a lowercase effect
  -- id (burn/sleep/...), which the shared src.battle.Status maps through
  -- GEN2_ID_ALIASES; Gen 1 answers straight off data.statuses.
  function R.status(game, mon)
    if (mon.hp or 0) <= 0 then return "FNT", "bad" end
    if not mon.status then return nil end
    local label
    local ok, Status = pcall(require, "src.battle.Status")
    if ok and Status.hudLabelFor then
      local data = game and game.data or {}
      if data.statuses then
        label = Status.hudLabelFor(data.statuses, mon.status)
      elseif data.gen2Statuses then
        local key = tostring(mon.status):lower()
        label = Status.hudLabelFor(data.gen2Statuses,
          Status.GEN2_ID_ALIASES and (Status.GEN2_ID_ALIASES[key] or key) or key)
      end
    end
    if not label or label == "" then return nil end
    local s = tostring(label):upper()
    local key = "warn"
    if s == "PSN" or s == "TOX" then key = "bad"
    elseif s == "SLP" or s == "FRZ" then key = "accent" end
    return label, key
  end

  local function rowH(opts) return opts.rowH or R.ROW_H end
  local function headerH(opts) return opts.headerH or R.HEADER_H end

  function R.rowTop(opts, i)
    return opts.y + (opts.header and headerH(opts) or 0)
      + (i - 1) * rowH(opts)
  end

  -- The row's full rect, for the POKeMON screen's options popup.
  function R.rowRect(opts, i)
    return opts.x, R.rowTop(opts, i), opts.w or 372, rowH(opts)
  end

  -- Kept for API compatibility: no screen draws a heading row now (at 30px it
  -- would not fit above a six-slot roster), but a caller that asks for one
  -- still gets correctly-placed, secondary-size column titles.
  function R.drawHeader(Theme, game, opts)
    local x, y = opts.x, opts.y
    local f = Theme.fonts(game).small
    local C = Theme.col
    Theme.text("HP/MAX", x + HP_R, y + 2, f, "right", C.inkFaint)
    Theme.text("LEVEL", x + LV_R, y + 2, f, "right", C.inkFaint)
    Theme.text("EXP", x + EXP_X, y + 2, f, "left", C.inkFaint)
    if opts.embellish ~= false then
      Theme.rule(x, y + headerH(opts) - 5, opts.w or 348, C.border)
    end
  end

  -- opts = {
  --   x, y, w        area (the shell's roster column)
  --   rowH, headerH  the shell's row metrics
  --   party          array of mon
  --   index          highlighted slot (1-based) or nil
  --   focus          draw the selection band + chevrons
  --   t              animation counter
  --   mode           "sprites" | "icons"
  --   header         draw column headings
  --   embellish      false to skip the header rule and row highlights
  --   logic          optional engine PartyMenu logic (tmhm/evoStone/heal)
  --   portraits      the portraits module
  --   gen            1 or 2 (which exp-curve reader to use); defaults to 1
  -- }
  function R.draw(Theme, game, opts)
    local Portraits = opts.portraits
    local C = Theme.col
    local F = Theme.fonts(game)
    local x = opts.x
    local w = opts.w or 372
    local rh = rowH(opts)
    local party = opts.party or {}
    local logic = opts.logic
    local t = opts.t or 0
    local embellish = opts.embellish ~= false

    if opts.header then R.drawHeader(Theme, game, opts) end

    if #party == 0 then
      Theme.text("No POK\xc3\xa9MON.", x + 60, opts.y + 40, F.body, "left",
        C.inkFaint)
      return
    end

    local count = #party
    local scroll = opts.scroll or 0
    local visible = opts.visibleRows or count
    local last = math.min(count, scroll + visible)

    for slot = scroll + 1, last do
      local mon = party[slot]
      local def = defOf(game, mon)
      local y = R.rowTop(opts, slot - scroll)
      local selected = opts.focus and opts.index == slot

      if selected then
        Theme.set(C.rowLit)
        Theme.rect("fill", x, y, w, rh, 6)
        -- the cursor is the double chevron alone, centred in the row -- a
        -- vertical accent bar used to sit to its left and read as a stray line
        Theme.chevrons(x + CHEV_X, y + (rh - CHEV_S) * 0.5, CHEV_S, C.accent,
          0.5 + 0.5 * math.sin(t * 0.18))
      end

      -- portrait card: a wide head-space band filled by the pack's own art.
      -- The FULL card goes to the portraits module (edge to edge) and the
      -- border is drawn over the art afterwards.
      local cx, cy = x + CARD_X, y + CARD_YO
      Theme.set(C.black, 0.45)
      Theme.rect("fill", cx + 1, cy + 1, CARD_W, CARD_H, 5)
      Theme.set(C.card)
      Theme.rect("fill", cx, cy, CARD_W, CARD_H, 5)
      Portraits.draw(Theme, game, mon, cx, cy, CARD_W, CARD_H,
        opts.mode or "sprites")
      Theme.set(C.cardEdge)
      Theme.rect("line", cx + 0.5, cy + 0.5, CARD_W - 1, CARD_H - 1, 5)

      -- The figures in the HP column -- or the teaching verdict that replaces
      -- them -- are measured BEFORE the name is drawn, so a long name stops in
      -- front of them instead of running underneath: Saira is proportional and
      -- "210/210" is much wider than "63/63".
      local teaching = logic and (logic.tmhm or logic.evoStone)
      local can = false
      if teaching then
        if logic.tmhm and logic.tmhm.move then
          for _, m in ipairs((def and def.tmhm) or {}) do
            if m == logic.tmhm.move then can = true break end
          end
        else
          for _, evo in ipairs((def and def.evolutions) or {}) do
            if evo.method == "ITEM" and evo.item == logic.evoStone then
              can = true break
            end
          end
        end
      end
      local shown = mon.hp or 0
      local heal = logic and logic.heal
      if heal and heal.mon == mon then shown = math.floor(heal.shown) end
      local hpText = teaching and (can and "ABLE" or "NOT ABLE")
        or ("%d/%d"):format(shown, R.maxHp(mon))
      local nameMax = math.min(NAME_MAX_PX,
        HP_R - Theme.w(hpText, F.small) - 10 - NAME_X)
      if nameMax < 48 then nameMax = 48 end

      -- name, beside the card
      local name = Theme.fit(R.name(mon, def), F.body, nameMax)
      Theme.text(name, x + NAME_X, y + LINE_Y, F.body, "left", C.white)

      -- level, in the row's OUTER column now (round 200 swapped it with
      -- HP/MAX): gold and SemiBold the way the reference weights its numbers,
      -- with a tiny "Lv" sitting on the digits' own baseline ahead of them
      local lvFont = F.tiny or F.small
      local lvNum = tostring(mon.level or 0)
      local lvX = x + LV_R
        - (Theme.w("Lv", lvFont) + 4 + Theme.w(lvNum, F.bold))
      Theme.text("Lv", lvX,
        y + LINE_Y + Theme.capOf(F.bold) - Theme.capOf(lvFont),
        lvFont, "left", C.inkFaint)
      Theme.text(lvNum, x + LV_R, y + LINE_Y, F.bold, "right", C.gold)

      if teaching then
        -- the engine's teaching / evolution-stone views replace the HP figures
        Theme.text(hpText, x + HP_R, y + LINE_Y, F.small, "right",
          can and C.good or C.inkFaint)
      else
        Theme.text(hpText, x + HP_R, y + LINE_Y, F.small, "right", C.ink)
        local max = R.maxHp(mon)
        local frac = max > 0 and (shown / max) or 0
        if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
        Theme.bar(x + HPG_X, y + BARS_Y, HPG_W, HPG_H, frac,
          Theme.hpColor(frac), { bg = C.panelDeep, border = C.border })

        -- EXP bar, its own column after HP/MAX, with no numbers on it
        Theme.set(C.panelDeep, 0.9)
        Theme.rect("fill", x + EXP_X, y + BARS_Y, EXP_W, EXP_H, 3)
        local ef = R.expFrac(mon, def, opts.gen, game)
        if ef > 0 then
          local col = ((mon.level or 1) >= 100) and C.gold or C.accent
          Theme.set(col, 0.9)
          Theme.rect("fill", x + EXP_X, y + BARS_Y,
            math.max(1, EXP_W * ef), EXP_H, 3)
        end
      end

      -- Status flag: a small chip in the portrait card's top-right corner.  It
      -- used to be a coloured stripe down the card's left edge, which read as a
      -- stray vertical line right beside the cursor; a chip says the same thing
      -- and cannot be mistaken for one.
      local label, key = R.status(game, mon)
      if label then
        local lw = Theme.w(label, F.small) + 8
        local chx, chy = cx + CARD_W - lw - 2, cy + 2
        Theme.set(C[key or "warn"], 0.92)
        Theme.rect("fill", chx, chy, lw, 15, 4)
        Theme.text(label, chx + lw * 0.5, chy + 2, F.small, "center",
          key == "warn" and C.void or C.white)
      end

      -- a fainted mon's row is washed dark
      if (mon.hp or 0) <= 0 then
        Theme.set(C.black, 0.34)
        Theme.rect("fill", x, y, w, rh, 6)
      end
    end

    -- scroll markers when the roster is windowed
    if scroll > 0 then
      Theme.set(C.accent)
      love.graphics.polygon("fill", x + w - 16, opts.y + headerH(opts) + 4,
        x + w - 6, opts.y + headerH(opts) + 4, x + w - 11, opts.y + headerH(opts) - 2)
    end
    if scroll + visible < count then
      Theme.set(C.accent)
      local by = opts.y + headerH(opts) + visible * rh - 2
      love.graphics.polygon("fill", x + w - 16, by - 8,
        x + w - 6, by - 8, x + w - 11, by)
    end
  end

  return R
end
