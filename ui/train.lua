-- ui/train.lua -- the modern TRAIN screen.
--
-- A DRAW-ONLY takeover of the TRAIN screen g9-battle-engine pushes from the
-- party submenu (stats/train_screen.lua, screenId "G9Train").  The engine's own
-- object stays on the stack and keeps running unchanged: it still owns the
-- working copy of the IVs / EVs / nature / gender / ability / move pool, the
-- staged-vs-committed diff, the fee arithmetic, the ModernStats commit and the
-- move-teaching rules.  g9-gui only replaces the INSTANCE's draw (and the
-- surface it is laid out on), so every behaviour the engine shipped -- the
-- nudge buttons, the APPLY charge, the ability-slot and hidden-ability swaps,
-- the HM refusal, the egg/battle guards -- is exactly the shipped behaviour.
--
-- WHY A DRAW TAKEOVER, NOT A REIMPLEMENTATION: the engine's TRAIN screen is
-- the authority on the modern-stat model (ModernStats.recalcAll and its
-- move-availability gate live inside that mod), and the user asked for the
-- engine's TRAIN to stay whole -- g9-gui "just replaces it when installed".
-- Nothing in g9-battle-engine is edited; this module decorates whatever G9Train
-- state the engine pushes (see main.lua's StateStack.push wrapper).
--
-- The original is a native 320x180 tile-font window with a horizontal tab
-- strip, a nudge row, a six-row IV/EV/CUR table, an ability info column and a
-- COST/APPLY strip.  This module rebuilds that SAME information on the g9-gui
-- 540x360 page: the shared header, the Saira type scale, the glass panels and
-- the pulsing chevron cursor.  The tab strip stays horizontal (the summary
-- panel already uses that shape), the table keeps its STAT/IV/EV/CUR columns,
-- and the ability column becomes the page's right-hand info panel.
--
-- Field/方法 contract read from the engine's Screen (stats/train_screen.lua):
--   mode "stats"|"moves"; page 1..7 (IV,EV,NAT,GENDER,MOVES,ABILITY,HIDDEN);
--   focus "tabs"|"rows"|"apply"; row (stat), col (nudge button); ivs/evs keyed
--   by STAT_ORDER; nature, gender; category 1..3, moveIndex, moveList,
--   moveHint; pending {entry,slot}; pickingSlot, slotIndex; abilityConfirm
--   "regular"|"hidden"; status; mon, def; methods abilitySlot, preview,
--   pendingCost, abilitySwapInfo.  Everything is read defensively, so a future
--   engine tweak degrades to a blank row instead of a broken page.
--
-- BOTH GENERATIONS (since 2.5.5).  The owner screen is generation-aware --
-- g9-battle-engine's stats/train_screen.lua answers Gen 1's :uiSize() AND Gen
-- 2's drawsWidescreen/panelSize for its native 320x180 page -- and so is this
-- takeover: `dress` keeps the same instance and the same engine-driven update,
-- and swaps only the SURFACE SEAM (Gen 1 :uiSize, Gold Shell.gen2Surface) so
-- THIS module's page is what both generations blit.  No Gen2* screen id is
-- needed -- the takeover rides main.lua's StateStack.push wrapper on both.
return function(mod, ctx)
  local Theme, Backdrop, Shell = ctx.Theme, ctx.Backdrop, ctx.Shell
  local opt = ctx.opt
  local MS = ctx.ModernStats
  -- Which generation is booting.  The takeover is the same work either way --
  -- amend the pushed instance's draw and surface, leave its update alone -- but
  -- the SURFACE seam is per-generation (ui/shell.lua): Gen 1 answers :uiSize()
  -- with the 540x360 page, Gold swaps the instance's :drawWidescreen for the
  -- suite's page, because Game2 never reads uiSize (see `dress`).
  local Gen2 = ctx.gen == 2

  local M = {}
  local W, H = Shell.W, Shell.H
  local MARGIN = Shell.MARGIN
  local C = Theme.col

  -- STAT_ORDER comes from the engine mod's own ModernStats export so the rows
  -- are the exact keys the engine's ivs/evs tables use.  The literal fallback
  -- is only reachable in a harness that has no engine handle.
  local ORDER = (MS and MS.ORDER) or { "hp", "atk", "def", "spa", "spd", "spe" }
  local LABEL = { hp = "HP", atk = "ATK", def = "DEF", spa = "SP.ATK",
    spd = "SP.DEF", spe = "SPEED" }

  -- Page indices, identical to the engine's TAB_IV..TAB_HIDDEN.
  local TAB_IV, TAB_EV, TAB_NAT, TAB_GENDER, TAB_MOVES = 1, 2, 3, 4, 5
  local TAB_ABILITY, TAB_HIDDEN = 6, 7
  local TABS = {
    { page = TAB_IV, label = "IV" },
    { page = TAB_EV, label = "EV" },
    { page = TAB_NAT, label = "NAT" },
    { page = TAB_GENDER, label = "GENDER" },
    { page = TAB_MOVES, label = "MOVES" },
    { page = TAB_ABILITY, label = "ABILITY" },
    { page = TAB_HIDDEN, label = "HIDDEN" },
  }

  -- The nudge rows are the engine's own button sets, in order: `col` indexes
  -- this list.  Keep them named so a mislabelled button can be spotted -- the
  -- engine's update reads ITS copy, and a divergent label here would show the
  -- wrong operation.
  local BUTTONS = {
    [TAB_IV] = { pad = 18, gap = 8, buttons = { "+", "-", "0", "31" } },
    [TAB_EV] = { pad = 12, gap = 6, buttons = { "4", "-4", "+12", "-12",
      "+128", "-128", "0" } },
  }
  local MOVE_CATEGORIES = { "RELEARN", "EGG", "TUTOR" }
  -- Display-only copies of the engine's fees: the staged total is shown from
  -- the engine's own :pendingCost(), and the two ability prices from
  -- :abilitySwapInfo(), so these constants only cover a method that failed.
  local MOVE_COST, ABILITY_COST, HIDDEN_COST = 5000, 5000, 7000
  -- Moves the native deleter refuses to forget (engine/pokemon/learn.asm).
  local HM_MOVES = {
    CUT = true, FLY = true, SURF = true, STRENGTH = true, FLASH = true,
    WHIRLPOOL = true, WATERFALL = true, DIVE = true,
  }

  -- Stats-page geometry (ink coordinates, so a body-22 line's ink top is y).
  local TAB_Y, TAB_H = Shell.CONTENT_Y, 30          -- 66 .. 96
  local NUDGE_Y, NUDGE_H = 102, 30                  -- 102 .. 132
  local TABLE_HDR_Y = 142
  local ROW_TOP, ROW_STEP, ROW_H = 156, 20, 19
  local TABLE_X, TABLE_W = MARGIN, 292
  local COL_LABEL = TABLE_X + 10
  local COL_IV, COL_EV, COL_CUR = TABLE_X + 164, TABLE_X + 210, TABLE_X + 284
  local APPLY_Y, APPLY_H = 282, 24
  -- Right-hand info panel: the ability block, aligned with the table beside it.
  local PANEL_X, PANEL_W = 324, 200

  -- Moves-page geometry: category tabs, then a list panel and a detail panel.
  local MOVE_LIST_X, MOVE_LIST_Y, MOVE_LIST_W = MARGIN, 106, 292
  local MOVE_ROW = 24
  local MOVE_VISIBLE = 8
  local MOVE_DETAIL_X = 324

  -- ------------------------------------------------------------------ helpers
  local function safe(fn, ...)
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil
  end

  local function monName(mon, def)
    if type(mon) ~= "table" then return "?" end
    return mon.nickname or (def and def.name) or tostring(mon.species or "?")
  end

  local function ivOf(mon, key) return (mon.ivs and mon.ivs[key]) or 0 end
  local function evOf(mon, key) return (mon.evs and mon.evs[key]) or 0 end

  -- The pulsing chevron beat every g9-gui cursor shares.
  local function pulse(self)
    return 0.5 + 0.5 * math.sin((self.__t or 0) * 0.18)
  end

  -- Centre a cap-height ink line inside a box of height h.
  local function centerY(y, h, font)
    return y + math.floor((h - Theme.capOf(font)) * 0.5 + 0.5)
  end

  -- One framed option: the same glass pill the rest of the suite uses.  `state`
  -- is "focus" (the cursor), "on" (the current page, not the cursor), "dim"
  -- (a disabled entry) or nil.
  local function pill(x, y, w, h, label, font, state)
    local fill, border, ink
    if state == "focus" then
      fill, border, ink = C.panelLit, C.borderLit, C.accent
    elseif state == "on" then
      fill, border, ink = C.rowLit, C.borderLit, C.accent
    elseif state == "dim" then
      fill, border, ink = C.panelDeep, C.border, C.inkFaint
    else
      fill, border, ink = C.panel, C.border, C.ink
    end
    Theme.panel(x, y, w, h, { radius = 5, color = fill, border = border,
      shadow = state == "focus" and 2 or nil })
    Theme.text(label, x + (w - Theme.w(label, font)) * 0.5,
      centerY(y, h, font), font, "left", ink)
    return w
  end

  -- Lay a row of labels out left-to-right from x0, sized by measured text.
  -- Returns the per-button x and width.  Padding is reduced if the row would
  -- otherwise run past `right`, so a long label set can never overflow.
  local function layoutRow(labels, font, x0, right, gap, pad)
    gap = gap or 6
    pad = pad or 14
    local widths = {}
    local function total(px)
      local t = 0
      for i = 1, #labels do
        widths[i] = Theme.w(labels[i], font) + px * 2
        t = t + widths[i] + (i > 1 and gap or 0)
      end
      return t
    end
    if total(pad) > right - x0 then
      local over = total(pad) - (right - x0)
      pad = math.max(3, pad - math.ceil(over / (2 * #labels)))
      total(pad)
    end
    local xs = {}
    local x = x0
    for i = 1, #labels do
      xs[i] = x
      x = x + widths[i] + gap
    end
    return xs, widths
  end

  -- ---------------------------------------------------------------- surfaces
  function M.uiSize() return W, H end
  -- Same whole-stack gate every g9-gui screen answers (ui/shell.lua S.wide):
  -- true unless an OPAQUE state that is not ours sits above.
  function M.isWideBattleLayout(self) return Shell.wide(self) end
  function M.wantsFillScale(self) return Shell.wide(self) end
  function M.sgbPalettes() return {} end

  -- ------------------------------------------------------------------- tabs
  local function drawTabs(self, game)
    local F = Theme.fonts(game).body
    local labels = {}
    for i, tab in ipairs(TABS) do labels[i] = tab.label end
    local xs, ws = layoutRow(labels, F, MARGIN, W - MARGIN, 6, 14)
    for i, tab in ipairs(TABS) do
      local state
      if self.focus == "tabs" then
        state = (self.page == tab.page) and "focus" or nil
      else
        state = (self.page == tab.page) and "on" or nil
      end
      pill(xs[i], TAB_Y, ws[i], TAB_H, tab.label, F, state)
    end
  end

  -- ------------------------------------------------------------- nudge row
  local function drawNudge(self, game)
    local F = Theme.fonts(game).body
    local page = self.page
    local set = BUTTONS[page]
    if set then
      local xs, ws = layoutRow(set.buttons, F, MARGIN,
        TABLE_X + TABLE_W, set.gap, set.pad)
      for i, label in ipairs(set.buttons) do
        local state
        if self.focus == "rows" then
          state = (self.col == i) and "focus" or nil
        else
          state = (self.col == i) and "on" or nil
        end
        pill(xs[i], NUDGE_Y, ws[i], NUDGE_H, label, F, state)
      end
    elseif page == TAB_NAT then
      local label = tostring(self.nature or "----")
      local w = Theme.w(label, F) + 44
      pill(MARGIN, NUDGE_Y, w, NUDGE_H, label, F,
        (self.focus == "rows") and "focus" or "on")
    elseif page == TAB_GENDER then
      local label = (self.gender == "female") and "FEMALE" or "MALE"
      local w = Theme.w(label, F) + 44
      pill(MARGIN, NUDGE_Y, w, NUDGE_H, label, F,
        (self.focus == "rows") and "focus" or "on")
    else
      -- MOVES / ABILITY / HIDDEN are one-shot actions, not editors: A runs
      -- them, so the strip explains what the press would do.
      local message = (page == TAB_MOVES)
        and "Press A to open the move editor."
        or (page == TAB_ABILITY)
        and ("Press A to swap the ability slot (" .. ABILITY_COST .. ").")
        or ("Press A to toggle the hidden ability (" .. HIDDEN_COST .. ").")
      Theme.text(Theme.fit(message, F, TABLE_W),
        MARGIN, centerY(NUDGE_Y, NUDGE_H, F), F, "left", C.inkDim)
    end
  end

  -- --------------------------------------------------------------- stat table
  local function drawTable(self, game)
    local F = Theme.fonts(game)
    local edit = (self.page == TAB_IV or self.page == TAB_EV)
    Theme.text("STAT", COL_LABEL, TABLE_HDR_Y, F.small, "left", C.inkFaint)
    Theme.text("IV", COL_IV, TABLE_HDR_Y, F.small, "right", C.inkFaint)
    Theme.text("EV", COL_EV, TABLE_HDR_Y, F.small, "right", C.inkFaint)
    Theme.text("CUR", COL_CUR, TABLE_HDR_Y, F.small, "right", C.inkFaint)
    local mon = self.mon or {}
    local preview = safe(self.preview, self)
    for i, key in ipairs(ORDER) do
      local y = ROW_TOP + (i - 1) * ROW_STEP
      local current = self.focus == "rows" and self.row == i
      local band = edit and current
      if band then
        Theme.set(C.rowLit, 0.52)
        Theme.rect("fill", TABLE_X, y - 2, TABLE_W, ROW_H, 4)
      elseif current then
        Theme.set(C.row, 0.45)
        Theme.rect("fill", TABLE_X, y - 2, TABLE_W, ROW_H, 4)
      end
      Theme.text(LABEL[key] or key, COL_LABEL, y, F.body, "left",
        band and C.accent or C.ink)
      Theme.text(("%2d"):format(ivOf(mon, key)), COL_IV, y, F.bold, "right",
        C.ink)
      Theme.text(("%3d"):format(evOf(mon, key)), COL_EV, y, F.bold, "right",
        C.ink)
      local cur = preview and preview[key]
      Theme.text(cur and ("%3d"):format(cur) or "---", COL_CUR, y, F.bold,
        "right", C.gold)
    end
  end

  -- ------------------------------------------------------------- ability panel
  local function drawAbility(self, game)
    local F = Theme.fonts(game)
    local mon = self.mon or {}
    local top, hgt = 138, 148
    Theme.panel(PANEL_X, top, PANEL_W, hgt,
      { radius = 6, shadow = 2 })
    Theme.text("ABILITY", PANEL_X + 14, TABLE_HDR_Y, F.small, "left",
      C.inkFaint)
    Theme.text(Theme.fit(tostring(mon.ability or "----"), F.body, PANEL_W - 28),
      PANEL_X + 14, 160, F.body, "left", C.accent)

    local slot = safe(self.abilitySlot, self)
    local slotLabel = (slot == 3) and "HIDDEN"
      or (slot and ("SLOT " .. tostring(slot)) or "----")
    Theme.text("SLOT", PANEL_X + 14, 188, F.small, "left", C.inkFaint)
    Theme.text(slotLabel, PANEL_X + PANEL_W - 14, 188, F.small, "right",
      C.inkDim)

    Theme.text("PREV", PANEL_X + 14, 210, F.small, "left", C.inkFaint)
    Theme.text(Theme.fit(tostring(mon.g9PrevAbility or "----"), F.small, 116),
      PANEL_X + PANEL_W - 14, 210, F.small, "right", C.inkDim)

    Theme.rule(PANEL_X + 14, 230, PANEL_W - 28, C.border)

    local infoReg = safe(self.abilitySwapInfo, self, "regular")
    local infoHid = safe(self.abilitySwapInfo, self, "hidden")
    local regCost = (infoReg and infoReg.cost) or ABILITY_COST
    local hidCost = (infoHid and infoHid.cost) or HIDDEN_COST
    Theme.text("SWAP SLOT", PANEL_X + 14, 240, F.small, "left", C.inkFaint)
    Theme.text(tostring(regCost), PANEL_X + PANEL_W - 14, 238, F.bold, "right",
      C.gold)
    Theme.text("HIDDEN", PANEL_X + 14, 264, F.small, "left", C.inkFaint)
    Theme.text(tostring(hidCost), PANEL_X + PANEL_W - 14, 262, F.bold, "right",
      C.gold)
  end

  -- ----------------------------------------------------------- cost + APPLY
  local function drawApply(self, game)
    local F = Theme.fonts(game).body
    local cost = safe(self.pendingCost, self) or 0
    local label = "APPLY"
    local w = Theme.w(label, F) + 44
    local bx = TABLE_X + TABLE_W - w
    -- the staged total sits immediately left of the button, so the two read as
    -- one action bar rather than a label at one edge and a button at the other
    Theme.text(("COST  %d"):format(cost), bx - 18,
      centerY(APPLY_Y, APPLY_H, F), F, "right",
      cost > 0 and C.gold or C.inkFaint)
    pill(bx, APPLY_Y, w, APPLY_H, label, F,
      (self.focus == "apply") and "focus" or "on")
  end

  -- ------------------------------------------------------------- stats page
  local function drawStats(self, game)
    drawTabs(self, game)
    drawNudge(self, game)
    drawTable(self, game)
    drawAbility(self, game)
    drawApply(self, game)
  end

  -- ------------------------------------------------------------- moves page
  local function moveName(game, move)
    if not move then return nil end
    local def = game and game.data and game.data.moves
      and game.data.moves[move.id]
    return (def and def.name) or tostring(move.id or "----")
  end

  local function drawMoves(self, game)
    local F = Theme.fonts(game)
    local labels = MOVE_CATEGORIES
    local xs, ws = layoutRow(labels, F.body, MARGIN, W - MARGIN, 8, 16)
    for i, label in ipairs(labels) do
      pill(xs[i], TAB_Y, ws[i], TAB_H, label, F.body,
        (self.category == i) and "on" or nil)
    end

    local list = self.moveList or {}
    local scroll = 0
    if #list > MOVE_VISIBLE then
      scroll = math.max(1, math.min(self.moveIndex - math.floor(MOVE_VISIBLE / 2),
        #list - MOVE_VISIBLE + 1))
    end

    if #list == 0 then
      Theme.panel(MOVE_LIST_X, MOVE_LIST_Y, MOVE_LIST_W, MOVE_VISIBLE * MOVE_ROW + 4,
        { radius = 6, shadow = 2 })
      Theme.text(self.moveHint or "NONE TO LEARN", MOVE_LIST_X + 20,
        MOVE_LIST_Y + 24, F.body, "left", C.inkFaint)
    else
      local rows = {}
      for i = 1, #list do rows[i] = { text = list[i].name or "----" } end
      Shell.list(Theme, game, {
        rows = rows, index = self.moveIndex, scroll = scroll,
        maxVisible = MOVE_VISIBLE, more = #list > MOVE_VISIBLE,
        x = MOVE_LIST_X, y = MOVE_LIST_Y, w = MOVE_LIST_W, row = MOVE_ROW,
        labelPad = 44, rightPad = 20,
      })
    end

    -- right-hand detail: the highlighted move, its learn fee and, as context,
    -- the move set it would join.
    local dTop, dH = MOVE_LIST_Y, MOVE_VISIBLE * MOVE_ROW + 4
    Theme.panel(MOVE_DETAIL_X, dTop, PANEL_W, dH,
      { radius = 6, shadow = 2 })
    Theme.text("SELECTED", MOVE_DETAIL_X + 14, dTop + 12, F.small, "left",
      C.inkFaint)
    local entry = list[self.moveIndex]
    Theme.text(Theme.fit(entry and (entry.name or "----") or "----", F.body,
      PANEL_W - 28), MOVE_DETAIL_X + 14, dTop + 30, F.body, "left", C.accent)
    Theme.text("CATEGORY", MOVE_DETAIL_X + 14, dTop + 60, F.small, "left",
      C.inkFaint)
    Theme.text(MOVE_CATEGORIES[self.category] or "----",
      MOVE_DETAIL_X + PANEL_W - 14, dTop + 60, F.small, "right", C.inkDim)
    Theme.text("LEARN", MOVE_DETAIL_X + 14, dTop + 84, F.small, "left",
      C.inkFaint)
    Theme.text(tostring(MOVE_COST), MOVE_DETAIL_X + PANEL_W - 14, dTop + 82,
      F.bold, "right", C.gold)

    Theme.rule(MOVE_DETAIL_X + 14, dTop + 106, PANEL_W - 28, C.border)
    Theme.text("CURRENT MOVES", MOVE_DETAIL_X + 14, dTop + 114, F.small,
      "left", C.inkFaint)
    local moves = (self.mon and self.mon.moves) or {}
    for i = 1, 4 do
      local y = dTop + 134 + (i - 1) * 18
      local move = moves[i]
      local label = moveName(game, move)
      if label and HM_MOVES[move.id] then label = label .. " (HM)" end
      Theme.text(label and Theme.fit(label, F.small, PANEL_W - 28) or "----",
        MOVE_DETAIL_X + 14, y, F.small, "left",
        label and C.inkDim or C.inkFaint)
    end
  end

  -- ------------------------------------------------------------------ modals
  local function embellished() return opt("ui_embellishment") ~= "false" end

  local function modalFrame(game, w, h)
    local x = math.floor((W - w) * 0.5)
    local y = math.floor((H - h) * 0.5) - 6
    Theme.set(C.black, 0.62)
    Theme.rect("fill", 0, 0, W, H, 0)
    Theme.panel(x, y, w, h, { radius = 8, shadow = 5, color = C.panelLit,
      border = C.borderLit })
    if embellished() then
      Theme.brackets(x + 5, y + 5, w - 10, h - 10, 18, C.accentDim)
    end
    return x, y
  end

  local function modalTitle(game, x, y, w, title)
    local F = Theme.fonts(game).body
    Theme.text(Theme.fit(title, F, w - 40), x + 20, y + 14, F.body, "left",
      C.accent)
    Theme.rule(x + 20, y + 40, w - 40, C.border)
  end

  local function modalHints(game, x, y, w, hints)
    Theme.hints(hints, x + 20, y, Theme.fonts(game).body, { gap = 20 })
  end

  local function drawAbilityModal(self, game)
    local kind = self.abilityConfirm
    local info, why = safe(self.abilitySwapInfo, self, kind)
    local w, h = 420, 190
    local x, y = modalFrame(game, w, h)
    modalTitle(game, x, y, w, kind == "hidden"
      and "TOGGLE HIDDEN ABILITY" or "SWAP ABILITY SLOT")
    local F = Theme.fonts(game)
    if info then
      Theme.text("SET ABILITY TO", x + 20, y + 58, F.small, "left", C.inkFaint)
      Theme.text(Theme.fit(tostring(info.to), F.body, w - 40), x + 20, y + 76,
        F.body, "left", C.ink)
      Theme.text("FOR", x + 20, y + 112, F.small, "left", C.inkFaint)
      Theme.text(tostring(info.cost), x + w - 20, y + 108, F.bold, "right",
        C.gold)
    else
      Theme.text(Theme.fit(why or "NOT AVAILABLE", F.body, w - 40), x + 20,
        y + 74, F.body, "left", C.bad)
    end
    modalHints(game, x, y + h - 30, w,
      { { key = "A", text = "YES" }, { key = "B", text = "NO" } })
  end

  local function drawSlotModal(self, game)
    local moves = (self.mon and self.mon.moves) or {}
    local n = math.max(1, #moves)
    local row = 30
    local w = 420
    local h = 58 + n * row + 44
    local x, y = modalFrame(game, w, h)
    modalTitle(game, x, y, w, "FORGET WHICH MOVE?")
    local F = Theme.fonts(game)
    for i = 1, n do
      local ry = y + 54 + (i - 1) * row
      local on = (i == self.slotIndex)
      if on then
        Theme.set(C.rowLit, 0.55)
        Theme.rect("fill", x + 14, ry - 5, w - 28, row - 4, 5)
        Theme.chevrons(x + 24, ry + 3, 18, C.accent, pulse(self))
      end
      local move = moves[i]
      local label = moveName(game, move)
      if label and move and HM_MOVES[move.id] then label = label .. " (HM)" end
      Theme.text(label and Theme.fit(label, F.body, w - 90) or "----",
        x + 56, ry + 3, F.body, "left", on and C.accent or C.ink)
    end
    modalHints(game, x, y + h - 30, w,
      { { key = "A", text = "OK" }, { key = "B", text = "BACK" } })
  end

  local function drawLearnModal(self, game)
    local entry = self.pending and self.pending.entry
    local w, h = 420, 180
    local x, y = modalFrame(game, w, h)
    modalTitle(game, x, y, w, "LEARN MOVE")
    local F = Theme.fonts(game)
    Theme.text("TEACH", x + 20, y + 58, F.small, "left", C.inkFaint)
    Theme.text(Theme.fit(entry and (entry.name or "----") or "----", F.body,
      w - 40), x + 20, y + 76, F.body, "left", C.ink)
    Theme.text("FOR", x + 20, y + 110, F.small, "left", C.inkFaint)
    Theme.text(tostring(MOVE_COST), x + w - 20, y + 106, F.bold, "right",
      C.gold)
    modalHints(game, x, y + h - 30, w,
      { { key = "A", text = "YES" }, { key = "B", text = "NO" } })
  end

  local function drawModal(self, game)
    if self.abilityConfirm then
      drawAbilityModal(self, game)
    elseif self.pickingSlot then
      drawSlotModal(self, game)
    elseif self.pending then
      drawLearnModal(self, game)
    end
  end

  -- --------------------------------------------------------------- the page
  local function footerHints(self)
    if self.mode == "moves" then
      return {
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "CAT" },
        { key = "A", text = "TEACH" },
        { key = "B", text = "BACK" },
      }
    end
    if self.focus == "tabs" then
      return {
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "TAB" },
        { key = "A", text = "OPEN" },
        { key = "B", text = "BACK" },
      }
    end
    if self.focus == "apply" then
      return {
        { key = "A", text = "APPLY" },
        { key = "\xe2\x86\x91\xe2\x86\x93", text = "TABS" },
        { key = "B", text = "BACK" },
      }
    end
    if self.page == TAB_IV or self.page == TAB_EV then
      return {
        { key = "\xe2\x86\x91\xe2\x86\x93", text = "STAT" },
        { key = "\xe2\x86\x90\xe2\x86\x92", text = "VALUE" },
        { key = "A", text = "SET" },
        { key = "B", text = "BACK" },
      }
    end
    return {
      { key = "\xe2\x86\x90\xe2\x86\x92", text = "CHANGE" },
      { key = "A", text = "OK" },
      { key = "B", text = "BACK" },
    }
  end

  function M.draw(self)
    local game = self.game
    if type(game) ~= "table" then return end
    if self.broken then return end
    local background = opt("ui_background") ~= "false"
    local embellish = embellished()

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    local name = monName(self.mon, self.def)
    Shell.top(Theme, game, {
      title = "TRAIN",
      right = (self.mode == "moves") and "MOVES" or "STATS",
      caption = ("%s  Lv%d"):format(name, (self.mon and self.mon.level) or 0),
      money = Shell.money(game),
      embellish = embellish,
    })

    if self.mode == "moves" then
      drawMoves(self, game)
    else
      drawStats(self, game)
    end
    drawModal(self, game)

    Shell.footer(Theme, game, {
      hints = footerHints(self),
      right = (self.status ~= "" and self.status) or nil,
    })

    Theme.set(C.white)
  end

  -- ------------------------------------------------------------------ dress
  -- Amend a G9Train instance IN PLACE.  The engine's own update, state machine
  -- and ModernStats commit keep running untouched; only draw and the surface
  -- move onto the g9-gui page.  Idempotent, so a re-push or a second wrap can
  -- never double-decorate.
  function M.dress(state)
    if type(state) ~= "table" or state.__g9gui then return state end
    state.__g9gui = true
    state.isOpaque = true
    state.letterboxWhite = true
    state.__t = state.__t or 0
    state.sgbPalettes = M.sgbPalettes
    if Gen2 then
      -- Gold: the owner (g9-battle-engine's stats/train_screen.lua) already
      -- publishes Gen 2's own panel contract for its native 320x180 page, so
      -- leaving its :drawWidescreen in place would blit the suite's 540x360
      -- page at the 320x180 scale -- clipped on every edge.  Swap the surface
      -- trio for the suite's page instead (Shell.gen2Surface): :drawWidescreen
      -- runs M.draw under a transform built for the 540x360 page, and Game2's
      -- own drawsWidescreen/wantsFillScale dispatch finds it.  The engine's
      -- update, state machine and ModernStats commit keep running untouched.
      Shell.gen2Surface(Theme, state, function(s) M.draw(s) end)
    else
      -- Gen 1: answer :uiSize() with the page so Game:draw sizes the surface
      -- to it (and centres the classic 160x144 UI in the extra width).
      state.uiSize = M.uiSize
      state.isWideBattleLayout = M.isWideBattleLayout
      state.wantsFillScale = M.wantsFillScale
    end
    local baseUpdate = state.update
    if type(baseUpdate) == "function" then
      state.update = function(s, dt)
        s.__t = (s.__t or 0) + 1
        baseUpdate(s, dt)
      end
    end
    state.draw = function(s) M.draw(s) end
    return state
  end

  M.screenId = "G9Train"
  return M
end
