-- ui/dex_entry.lua -- the Pokédex ENTRY page (START -> POKeDEX -> a species).
--
-- Another view takeover of an engine screen (src.ui.DexEntryMenu): the engine
-- object stays on the stack and keeps its own update -- the 36-frame beat
-- before the cry, the page-at-a-time advance, the pop and its onDone -- so the
-- page still behaves exactly as shipped.  Only the drawing and the surface
-- change, to the suite's 540x360 page.
--
-- The field data is the engine's: def.dexEntry (kind, height, weight, the
-- text key), data.text for the description, data.constants.dexDigits for the
-- number width, and the same owned/forceOwned gate the engine uses -- so the
-- description and the height/weight figures stay hidden until the mon is
-- actually owned, exactly as the GB page does.  The description is re-wrapped
-- to the panel's measured pixel width (the GB page's own line breaks are for
-- a 160px screen) and paged with the engine's own self.page/self.pageCount.
--
-- NATIONAL DEX MODE.  With national_dex installed the object carries more than
-- the engine built: the mod patches DexEntryMenu's class, so `self.forms` (the
-- species' ordered alternate-form ids), `self.formRecord` (the record the
-- selected form's art and numbers come from) and `self.formIndex`/`self.formLabel`
-- all exist, and the same class patch adds DOWN/UP paging to a STATS page and
-- the evolution/learnset strip behind it, with LEFT/RIGHT cycling forms.
--
-- That mod reuses the engine's `self.page` for its strip, and the engine's own
-- update pages the DESCRIPTION with that same field.  On an entry whose
-- description runs to more than one cart page (the original 151 keep their
-- `\f`-broken text; the species this mod adds are re-wrapped to one page) the
-- two meanings collide.  So in national-dex mode this file keeps TWO counters
-- of its own (`__g9strip` and `__g9desc`) and, on a frame A/B/UP/DOWN is
-- pressed, hands the inner updates an input that reports those four keys as
-- unpressed (see decorate).  The composite then reads exactly like the design:
-- UP/DOWN walk the strip, A/B page the description and then close, and
-- LEFT/RIGHT is left completely alone so form cycling stays national_dex's own.
-- With national_dex absent none of this runs and the page is the vanilla
-- description pager it has always been.
return function(mod, ctx)
  local Theme, Backdrop, Shell = ctx.Theme, ctx.Backdrop, ctx.Shell
  local opt = ctx.opt
  local NatDex = ctx.NatDex

  local M = {}
  local Builtin = require("src.ui.DexEntryMenu")

  -- A national-dex page that throws must cost that page, not the screen: the
  -- drawers run under pcall and a failure falls back to the description page
  -- (which always draws).  Said out loud once, because a page that quietly
  -- refuses to appear is the kind of thing this project has paid days for.
  local reported = {}
  local function report(what, err)
    if reported[what] then return end
    reported[what] = true
    if mod and mod.log and type(mod.log.warn) == "function" then
      local msg = tostring(err):gsub("%%", "%%%%")
      mod.log:warn(("g9-gui: the Pokédex entry's %s page failed (%s) -- "
        .. "falling back to the description page"):format(what, msg))
    end
  end

  local W, H = Shell.W, Shell.H
  local MARGIN = Shell.MARGIN

  -- left: the portrait panel; right: a small figures panel over a description
  -- panel.  The portrait panel runs the full content band, so a tall or wide
  -- frame has room to scale up.
  local SPR_X, SPR_Y = MARGIN, Shell.CONTENT_Y
  local SPR_W = 190
  local SPR_H = Shell.FOOT_RULE_Y - 8 - SPR_Y
  local COL_X = SPR_X + SPR_W + 12
  local COL_W = (W - MARGIN) - COL_X

  local DESC_PITCH = 20  -- a small-13 line plus leading
  local DESC_N = 2       -- HEIGHT / WEIGHT rows

  -- national_dex STATS page: the portrait keeps the same panel width but only
  -- the top of the band, and the type rows sit under it.
  local PORTRAIT_H = 150
  local TYPE_Y = SPR_Y + PORTRAIT_H + 8
  local STRIP_ROW = 20
  local STRIP_PAD = 24

  function M.uiSize() return W, H end
  M.isWideBattleLayout = Shell.wide
  function M.wantsFillScale(self) return Shell.wide(self) end
  function M.sgbPalettes() return {} end

  -- ---------------------------------------------------------------- data
  -- The engine's own ownership gate (its local ownedFor): forceOwned mirrors
  -- pret's StarterDex ball preview around Oak's lab.
  local function ownedFor(game, def, forceOwned)
    return forceOwned
      or (game.save.pokedex and game.save.pokedex.owned
        and game.save.pokedex.owned[def.id]) or false
  end

  -- The engine's local descPages, re-derived here so this page can rewrap the
  -- text: split on the page break \f, then on the line break (\v or newline),
  -- drop a page's trailing blanks, and give the last line its full stop.
  local function descPages(game, def, forceOwned)
    local e = def.dexEntry or {}
    local text = ownedFor(game, def, forceOwned)
      and e.text and game.data.text and game.data.text[e.text] or nil
    if not text then return nil end
    local pages = {}
    for chunk in (text .. "\f"):gmatch("(.-)\f") do
      local lines = {}
      for line in (chunk:gsub("\v", "\n") .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
      end
      while #lines > 0 and lines[#lines] == "" do table.remove(lines) end
      if #lines > 0 then pages[#pages + 1] = lines end
    end
    if #pages == 0 then return nil end
    local last = pages[#pages]
    last[#last] = last[#last] .. "."
    return pages
  end

  local function numberText(game, def)
    local digits = (game.data.constants or {}).dexDigits or 3
    return "No." .. ("%0" .. digits .. "d"):format(def.dex or 0)
  end

  -- Metric when the entry carries it (the localised set), imperial otherwise,
  -- matching the engine's two branches.
  local function measures(e)
    if e.heightM ~= nil then
      return ("%.1f m"):format(e.heightM or 0),
        ("%.1f kg"):format(e.weightKg or 0)
    end
    return ("%d'%02d\""):format(e.heightFt or 0, e.heightIn or 0),
      ("%.1f lb"):format((e.weight or 0) / 10)
  end

  -- Word-wrap a paragraph to a measured pixel budget (Saira is proportional,
  -- so there is no cell count to use).
  local function wrap(text, font, maxW)
    local out = {}
    local line = ""
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

  -- ------------------------------------------------------- national_dex mode
  local function nationalDex(self)
    return NatDex and NatDex.installed and type(self.forms) == "table"
  end

  local function formLabel(self)
    if type(self.formLabel) ~= "string" or self.formLabel == "" then return nil end
    return NatDex.prettyForm(self.formLabel)
  end

  local function formCount(self)
    return type(self.forms) == "table" and #self.forms or 0
  end

  -- The header's right readout: the dex number, then the form position when
  -- there is more than one to cycle.
  local function headerRight(self, game, def, nd)
    local text = numberText(game, def)
    if nd and formCount(self) > 1 then
      text = text .. "   FORM " .. tostring(self.formIndex or 1)
        .. "/" .. formCount(self)
    end
    return text
  end

  -- The caption line: the kind, plus the selected form's own name.  The form
  -- label is the ONE thing a form changes about the page's identity -- name,
  -- No., height/weight and the description stay the base species' own -- so it
  -- rides the caption rather than the title.
  local function caption(self, e, form)
    local kind = e.kind
    if form and kind then return kind .. "  \xc2\xb7  " .. form end
    return form or kind
  end

  -- Masks the named buttons for the length of one inner update, forwarding
  -- everything else (isDown, the other buttons, the field reads) untouched.
  -- `next` is the rest of the original arguments the same way src/mods/Hooks
  -- passes them, so a caller that reads another key still sees the truth.
  local function maskedInput(input, mask)
    return setmetatable({}, { __index = function(_, key)
      if key == "wasPressed" then
        return function(_, button)
          if mask[button] then return false end
          return input:wasPressed(button)
        end
      end
      local value = input[key]
      if type(value) == "function" then
        return function(_, ...) return value(input, ...) end
      end
      return value
    end })
  end

  -- ------------------------------------------------------------------ install
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
      -- national_dex mode only: route this frame's paging keys away from the
      -- inner updates so this file owns both counters.  The mask exists only
      -- on a frame one of the four is actually pressed.
      local input = nationalDex(s) and s.game and s.game.input or nil
      local mask
      if type(input) == "table" and type(input.wasPressed) == "function" then
        local a, b = input:wasPressed("a"), input:wasPressed("b")
        local up, down = input:wasPressed("up"), input:wasPressed("down")
        if a or b or up or down then
          mask = { a = a, b = b, up = up, down = down }
        end
      end
      if mask then s.game.input = maskedInput(input, mask) end
      local ok, err = pcall(baseUpdate, s, dt)
      if mask then s.game.input = input end
      if not ok then error(err, 0) end
      if not mask then return end
      -- Page only once the opening beat and the cry are done, exactly like the
      -- engine's own A/B handling: the beat is watched, not skipped.
      local waiting = (s.picDelay or 0) > 0
      local crying = s.crying and s:crying() or false
      if waiting or crying then return end

      local info = NatDex.info(s.formRecord or s.def)
      local lastPage = info.lastPage or 2
      local strip = s.__g9strip or 1
      if mask.down then
        if strip < lastPage then strip = strip + 1 end
      elseif mask.up then
        if strip > 1 then strip = strip - 1 end
      elseif mask.a or mask.b then
        if strip == 1 then
          -- the description is the engine's and still pages first: A/B walk
          -- it, and only the last page closes the entry.
          local pages = descPages(s.game, s.def, s.forceOwned)
          local count = pages and #pages or 1
          local desc = s.__g9desc or 1
          if desc < count then
            s.__g9desc = desc + 1
          else
            s.game.stack:pop()
            if s.onDone then s.onDone() end
          end
        else
          s.game.stack:pop()
          if s.onDone then s.onDone() end
        end
      end
      if strip > lastPage then strip = lastPage end
      s.__g9strip = strip
      -- a form change can shorten the strip (a form with no learnset of its
      -- own), and the selection must not be left past its end.
      local newInfo = NatDex.info(s.formRecord or s.def)
      local newLast = newInfo.lastPage or 2
      if (s.__g9strip or 1) > newLast then s.__g9strip = newLast end
    end
    self.draw = function(s) M.draw(s) end
    return self
  end

  function M.new(game, speciesOrOpts, onDone)
    return M.decorate(Builtin.new(game, speciesOrOpts, onDone))
  end

  -- ------------------------------------------------------------------- draw
  function M.draw(self)
    local game = self.game
    local C = Theme.col
    local def = self.def or {}
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    if nationalDex(self) then
      local info = NatDex.info(self.formRecord or def)
      local strip = self.__g9strip or 1
      local pages = info.pages or {}
      if strip == 2 then
        local ok, err = pcall(M.statsPage, self, game, def, info, C, embellish)
        if ok then return end
        report("stats", err)
      elseif strip >= 3 and pages[strip - 2] then
        local ok, err = pcall(M.stripPage, self, game, def, info, pages, strip,
          C, embellish)
        if ok then return end
        report("strip", err)
      end
      -- page 1 (and any fallback) is the description below
    end

    M.entryPage(self, game, def, C, embellish)
  end

  -- Page 1: the portrait, the figures and the description.
  function M.entryPage(self, game, def, C, embellish)
    local F = Theme.fonts(game)
    local e = def.dexEntry or {}
    local nd = nationalDex(self)
    local form = nd and formLabel(self) or nil

    local waiting = (self.picDelay or 0) > 0
    local crying = self.crying and self:crying() or false

    Shell.top(Theme, game, {
      title = def.name or "?",
      right = headerRight(self, game, def, nd),
      caption = caption(self, e, form),
      embellish = embellish,
    })

    -- the portrait.  Empty (a quiet marker) while the entry's opening beat
    -- runs or the art has not resolved; a whole multiple of the frame, so
    -- the pixels stay square.
    Theme.panel(SPR_X, SPR_Y, SPR_W, SPR_H, { radius = 6, shadow = 3 })
    local sprite = (not waiting) and self.sprite or nil
    if sprite and sprite.getDimensions then
      local sw, sh = sprite:getDimensions()
      local scale = math.floor(math.min((SPR_W - 20) / sw, (SPR_H - 20) / sh))
      if scale < 1 then scale = 1 end
      local dw, dh = sw * scale, sh * scale
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(sprite, SPR_X + (SPR_W - dw) * 0.5,
        SPR_Y + (SPR_H - dh) * 0.5, 0, scale, scale)
    else
      Theme.diamond(SPR_X + SPR_W * 0.5, SPR_Y + SPR_H * 0.5, 10, C.accentDim)
    end

    -- the figures.  The GB page reveals the height and weight only once the
    -- cry has finished AND the species is owned (or forceOwned) -- so a
    -- not-owned entry reads '?', exactly as the cart does.
    local owned = ownedFor(game, def, self.forceOwned)
    local ready = owned and not (waiting or crying)
    local hStr, wStr = measures(e)
    Shell.list(Theme, game, {
      rows = {
        { text = "HEIGHT", right = ready and hStr or "?" },
        { text = "WEIGHT", right = ready and wStr or "?" },
      },
      x = COL_X, y = SPR_Y, w = COL_W, row = 30,
      labelPad = 34, rightPad = 16,
    })

    -- the description, re-wrapped to the panel
    local pages = descPages(game, def, self.forceOwned)
    local descCount = pages and #pages or 1
    local desc = nd and (self.__g9desc or 1) or (self.page or 1)
    if desc > descCount then desc = descCount end
    local descY = SPR_Y + DESC_N * 30 + 14
    local descH = Shell.FOOT_RULE_Y - descY - 6
    Theme.panel(COL_X, descY, COL_W, descH, { radius = 6, shadow = 3 })
    if ready and pages then
      local lines = pages[desc] or pages[descCount]
      local wrapped = wrap(table.concat(lines, " "), F.small, COL_W - 24)
      local ty = descY + 9
      local maxLines = math.max(1, math.floor((descH - 14) / DESC_PITCH))
      for i = 1, math.min(#wrapped, maxLines) do
        Theme.text(wrapped[i], COL_X + 12, ty, F.small, "left", C.inkDim)
        ty = ty + DESC_PITCH
      end
    end

    -- national_dex mode carries one hint more than the page has room for: PAGE
    -- and FORM (its own two), then the description's own advance.  A and B do
    -- the SAME thing to that description in the engine's update (either pages
    -- it or closes the entry), so the two are shown as one A/B chip -- three
    -- chips leave the "PAGE d/D" readout its whole width, where four would cut
    -- it down to a bare "P".
    local hints = {}
    if nd then
      hints[#hints + 1] = { key = "\xe2\x86\x91\xe2\x86\x93", text = "PAGE" }
      if formCount(self) > 1 then
        hints[#hints + 1] = { key = "\xe2\x86\x90\xe2\x86\x92", text = "FORM" }
      end
      hints[#hints + 1] = { key = "A/B",
        text = (desc < descCount) and "MORE" or "BACK" }
    else
      hints[#hints + 1] = { key = "A",
        text = desc < descCount and "NEXT" or "OK" }
      hints[#hints + 1] = { key = "B", text = "BACK" }
    end
    Shell.footer(Theme, game, {
      hints = hints,
      right = descCount > 1 and ("PAGE %d/%d"):format(desc, descCount) or nil,
    })

    Theme.set(C.white)
  end

  -- Page 2: types, abilities and base stats, with the portrait kept on screen.
  function M.statsPage(self, game, def, info, C, embellish)
    local F = Theme.fonts(game)
    local e = def.dexEntry or {}
    local record = self.formRecord or def
    local nd = nationalDex(self)
    local form = nd and formLabel(self) or nil
    local waiting = (self.picDelay or 0) > 0

    Shell.top(Theme, game, {
      title = def.name or "?",
      right = headerRight(self, game, def, nd),
      caption = caption(self, e, form),
      embellish = embellish,
    })

    -- left: the portrait (the SELECTED form's art) over its type rows
    Theme.panel(SPR_X, SPR_Y, SPR_W, PORTRAIT_H, { radius = 6, shadow = 3 })
    local sprite = (not waiting) and self.sprite or nil
    if sprite and sprite.getDimensions then
      local sw, sh = sprite:getDimensions()
      local scale = math.floor(math.min((SPR_W - 24) / sw,
        (PORTRAIT_H - 24) / sh))
      if scale < 1 then scale = 1 end
      local dw, dh = sw * scale, sh * scale
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(sprite, SPR_X + (SPR_W - dw) * 0.5,
        SPR_Y + (PORTRAIT_H - dh) * 0.5, 0, scale, scale)
    else
      Theme.diamond(SPR_X + SPR_W * 0.5, SPR_Y + PORTRAIT_H * 0.5, 10,
        C.accentDim)
    end

    local types = type(record) == "table" and record.types or {}
    local typeRows = {}
    if types[1] and types[2] then
      typeRows = {
        { text = "TYPE 1", right = NatDex.typeName(types[1]) },
        { text = "TYPE 2", right = NatDex.typeName(types[2]) },
      }
    elseif types[1] then
      typeRows = { { text = "TYPE", right = NatDex.typeName(types[1]) } }
    end
    if #typeRows > 0 then
      Shell.list(Theme, game, {
        rows = typeRows, x = SPR_X, y = TYPE_Y, w = SPR_W, row = 28,
        labelPad = 14, rightPad = 14, font = F.small, t = self.__t or 0,
      })
    end

    -- right: abilities over the base-stat panel, both sized to what the
    -- column actually holds
    local abilities = info.abilities or nil
    local y = SPR_Y
    if abilities then
      local rows = { { header = true, text = NatDex.translate("ABILITIES") } }
      for _, row in ipairs(abilities) do
        rows[#rows + 1] = { text = row.name,
          right = row.hidden and "HIDDEN" or nil }
      end
      Shell.list(Theme, game, {
        rows = rows, x = COL_X, y = y, w = COL_W, row = 26,
        labelPad = 22, rightPad = 16, t = self.__t or 0,
      })
      y = y + (#rows * 26 + 4) + 10
    end
    M.statPanel(self, record, COL_X, y, COL_W,
      Shell.FOOT_RULE_Y - 8 - y, C, F)

    local nd2 = nd
    local hints = {
      { key = "\xe2\x86\x91\xe2\x86\x93", text = "PAGE" },
      { key = "\xe2\x86\x90\xe2\x86\x92", text = "FORM" },
      { key = "A/B", text = "BACK" },
    }
    if not nd2 or formCount(self) <= 1 then
      table.remove(hints, 2)
    end
    Shell.footer(Theme, game, {
      hints = hints,
      right = ("%d/%d"):format(2, info.lastPage or 2),
    })

    Theme.set(C.white)
  end

  -- The base-stat panel: one row per stat with a bar, TOTAL last.  The row
  -- height follows the space: a species with no abilities gives the stats the
  -- whole column and the rows breathe; three abilities leave a tighter box.
  --
  -- THE PANEL IS A HARD BUDGET: the rows must always end inside it.  A fixed
  -- row-height FLOOR of 16 was the bug -- a species with three abilities AND
  -- the modern split special stats has seven rows in about 122px, and
  -- 7x16 + title + pad ran the TOTAL row through the foot rule.  Now the row
  -- height is whatever fits, the 34px ceiling is only a taste limit, and when
  -- the space is tight the title band gives up its padding first.  The text y
  -- also tucks up on a short row so a label's ink can never reach into the
  -- next row's bar.
  function M.statPanel(self, record, x, y, w, h, C, F)
    local rows = NatDex.statRows(record, NatDex.statsMode())
    local n = #rows
    local titleH, titleY, pad = 24, 8, 6
    local rowH = math.floor((h - titleH - pad) / n)
    if rowH < 16 then
      titleH, titleY, pad = 16, 4, 4
      rowH = math.floor((h - titleH - pad) / n)
    end
    rowH = math.max(8, math.min(34, rowH))
    Theme.panel(x, y, w, h, { radius = 6, shadow = 3 })
    Theme.text(NatDex.translate("BASE STATS"), x + 12, y + titleY, F.small,
      "left", C.inkFaint)
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

  -- Pages 3 and up: one section of the strip -- the family tree or a
  -- movelist -- under the species' name.
  function M.stripPage(self, game, def, info, pages, strip, C, embellish)
    local F = Theme.fonts(game)
    local e = def.dexEntry or {}
    local page = pages[strip - 2]
    local nd = nationalDex(self)
    local form = nd and formLabel(self) or nil

    local rows = {}
    for _, row in ipairs(page.rows or {}) do
      rows[#rows + 1] = {
        text = row.text, right = row.right, indent = row.indent,
        marker = row.mark,
      }
    end

    -- The header names the position in the WHOLE entry (page 2 is the stats
    -- page, 3+ the strip), because a section is usually one page and its own
    -- "1/1" says nothing.  A section long enough to run to a second page
    -- carries that index in the footer instead (below).
    Shell.top(Theme, game, {
      title = def.name or "?",
      right = ("PAGE %d/%d"):format(strip, info.lastPage or strip),
      caption = caption(self, { kind = NatDex.translate(page.title or "") },
        form),
      embellish = embellish,
    })

    Shell.list(Theme, game, {
      rows = rows, x = MARGIN, y = Shell.CONTENT_Y, w = W - MARGIN * 2,
      row = STRIP_ROW, labelPad = STRIP_PAD, rightPad = 16,
      font = F.small, t = self.__t or 0,
    })

    local hints = { { key = "\xe2\x86\x91\xe2\x86\x93", text = "PAGE" } }
    if formCount(self) > 1 then
      hints[#hints + 1] = { key = "\xe2\x86\x90\xe2\x86\x92", text = "FORM" }
    end
    hints[#hints + 1] = { key = "A/B", text = "BACK" }
    Shell.footer(Theme, game, {
      hints = hints,
      -- only a section that spills onto a second page shows an index here; a
      -- one-page section's "1/1" would just be noise beside the header's own
      -- position in the entry
      right = (page.count or 1) > 1
        and ("%d/%d"):format(page.index or 1, page.count) or nil,
    })

    Theme.set(C.white)
  end

  return M
end
