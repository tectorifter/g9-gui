-- ui/dex_entry.lua -- the Pokédex ENTRY page (START -> POKeDEX -> a species).
--
-- Another view takeover of an engine screen (src.ui.DexEntryMenu): the engine
-- object stays on the stack and keeps its own update -- the 36-frame beat
-- before the cry, the page-at-a-time A/B advance, the pop and its onDone --
-- so the page still behaves exactly as shipped.  Only the drawing and the
-- surface change, to the suite's 540x360 page.
--
-- The field data is the engine's: def.dexEntry (kind, height, weight, the
-- text key), data.text for the description, data.constants.dexDigits for the
-- number width, and the same owned/forceOwned gate the engine uses -- so the
-- description and the height/weight figures stay hidden until the mon is
-- actually owned, exactly as the GB page does.  The description is re-wrapped
-- to the panel's measured pixel width (the GB page's own line breaks are for
-- a 160px screen) and paged with the engine's own self.page/self.pageCount.
return function(mod, ctx)
  local Theme, Backdrop, Shell = ctx.Theme, ctx.Backdrop, ctx.Shell
  local opt = ctx.opt

  local M = {}
  local Builtin = require("src.ui.DexEntryMenu")

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
      if baseUpdate then baseUpdate(s, dt) end
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
    local F = Theme.fonts(game)
    local def = self.def or {}
    local e = def.dexEntry or {}
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    local waiting = (self.picDelay or 0) > 0
    local crying = self.crying and self:crying() or false

    Shell.top(Theme, game, {
      title = def.name or "?",
      right = numberText(game, def),
      caption = e.kind,
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
    local descY = SPR_Y + DESC_N * 30 + 14
    local descH = Shell.FOOT_RULE_Y - descY - 6
    Theme.panel(COL_X, descY, COL_W, descH, { radius = 6, shadow = 3 })
    if ready then
      local pages = descPages(game, def, self.forceOwned)
      if pages then
        local lines = pages[self.page or 1] or pages[#pages]
        local wrapped = wrap(table.concat(lines, " "), F.small, COL_W - 24)
        local ty = descY + 9
        local maxLines = math.max(1, math.floor((descH - 14) / DESC_PITCH))
        for i = 1, math.min(#wrapped, maxLines) do
          Theme.text(wrapped[i], COL_X + 12, ty, F.small, "left", C.inkDim)
          ty = ty + DESC_PITCH
        end
      end
    end

    local page = self.page or 1
    local count = self.pageCount or 1
    local hints = { { key = "A", text = page < count and "NEXT" or "OK" },
      { key = "B", text = "BACK" } }
    Shell.footer(Theme, game, {
      hints = hints,
      right = count > 1 and ("PAGE %d/%d"):format(page, count) or nil,
    })

    Theme.set(C.white)
  end

  return M
end
