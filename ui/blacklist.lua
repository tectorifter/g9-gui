-- ui/blacklist.lua -- the modern BLACKLIST window.
--
-- A DRAW-ONLY takeover of the BLACKLIST screen g9-battle-sample pushes from its
-- OPTIONS row (main.lua's installBlacklist, screenId "G9Blacklist").  The
-- sample's own object stays on the stack and keeps running unchanged: it still
-- owns the generation/letter filters, the cursor, the gen-grid selection and
-- every write -- blacklistToggle / blacklistGenToggle / blacklistReset, whose
-- persisted set the randomizer actually consults.  g9-gui only replaces the
-- INSTANCE's draw (and the surface), so the delisting rules, the persistence
-- and the "a delisted base hides its forms" behaviour are the shipped ones.
--
-- WHY A DRAW TAKEOVER: g9-battle-sample must stay whole -- the user asked for
-- the sample's own BLACKLIST to be replaced only while g9-gui is installed.
-- The sample does not export its blacklist accessors, so this module READS the
-- persisted set directly (mod.save is backed by game.save.modData[modId]; see
-- src/mods/Loader.lua's save API) and rebuilds the same gen-complete
-- computation over game.data.pokemon.  It never writes: every toggle still
-- goes through the engine screen's own update path.
--
-- Reads from the sample's Screen (main.lua installBlacklist):
--   gen 1..9, letter 1..26, focus "list"|"grid", listIndex, listScroll,
--   filtered ({id,name,base,form,dex,gen}), gridRow 1..4 (4 = RESET), gridCol,
--   status.  Everything is read defensively.
--
-- BOTH GENERATIONS (since 2.5.5).  The sample declares games = gen1/gen2 and
-- its Screen already publishes Gen 2's own panel contract (drawsWidescreen /
-- panelSize for its native 320x180 window), so the takeover only has to choose
-- the right surface seam per generation: Gen 1 :uiSize, Gold
-- Shell.gen2Surface (see `dress`).  The sample's own updates, cursor, filters
-- and blacklist writes are untouched on both.
return function(mod, ctx)
  local Theme, Backdrop, Shell = ctx.Theme, ctx.Backdrop, ctx.Shell
  local opt = ctx.opt
  -- Which generation is booting -- the surface seam differs (see `dress`).
  local Gen2 = ctx.gen == 2

  local M = {}
  local W, H = Shell.W, Shell.H
  local MARGIN = Shell.MARGIN
  local C = Theme.col

  -- The sample mod's manifest id.  If a fork ever changes it, readSet scans
  -- every bucket for one that carries a "blacklist" array.
  local SAMPLE_ID = "g9-battle-sample"

  -- National-dex ranges -> generation, copied from the sample so the grid cells
  -- and its own toggle agree.  A form is placed by its BASE species' dex.
  local GEN_RANGES = {
    { 1, 1, 151 }, { 2, 152, 251 }, { 3, 252, 386 }, { 4, 387, 493 },
    { 5, 494, 649 }, { 6, 650, 721 }, { 7, 722, 809 }, { 8, 810, 905 },
    { 9, 906, 1025 },
  }
  local GEN_COUNT = 9

  -- Geometry on the 540x360 page.  A 9-row name list down the left, the 3x3
  -- generation grid and the RESET bar down the right, then a short legend.
  local LIST_X, LIST_Y, LIST_W = MARGIN, Shell.CONTENT_Y, 292
  local LIST_ROW, LIST_VISIBLE = 26, 9
  local GRID_X0, GRID_Y0, GRID_W, GRID_H, GRID_GAP = 338, 88, 56, 32, 8
  local GRID_ROWS = { 88, 126, 164 }
  local RESET_X, RESET_Y, RESET_W, RESET_H = 338, 204, 184, 32

  -- ------------------------------------------------------------------ reads
  local function readSet(game)
    local set = {}
    local save = game and game.save
    local modData = save and save.modData
    local list
    if type(modData) == "table" then
      local bucket = modData[SAMPLE_ID]
      if type(bucket) == "table" and type(bucket.blacklist) == "table" then
        list = bucket.blacklist
      else
        for _, b in pairs(modData) do
          if type(b) == "table" and type(b.blacklist) == "table" then
            list = b.blacklist
            break
          end
        end
      end
    end
    if type(list) == "table" then
      for _, id in ipairs(list) do
        if type(id) == "string" then set[id] = true end
      end
    end
    return set
  end

  local function generationOfDex(dex)
    dex = tonumber(dex)
    if not dex then return nil end
    for _, range in ipairs(GEN_RANGES) do
      if dex >= range[2] and dex <= range[3] then return range[1] end
    end
    return nil
  end

  -- Every displayable species/form, for the gen-complete computation.  Same
  -- base-dex resolution the sample uses, so a cell's "complete" mark matches
  -- what its own toggle would write.
  local function buildIndex(game)
    local src = game and game.data and game.data.pokemon
    if type(src) ~= "table" then return {} end
    local out = {}
    for id, rec in pairs(src) do
      if type(id) == "string" and type(rec) == "table" then
        local base = type(rec.baseSpecies) == "string" and rec.baseSpecies or nil
        if base == "" then base = nil end
        local dex = rec.baseDex
        if type(dex) ~= "number" and base then
          local parent = src[base]
          if type(parent) == "table" and type(parent.dex) == "number" then
            dex = parent.dex
          end
        end
        if type(dex) ~= "number" then dex = rec.dex end
        out[#out + 1] = { id = id, base = base,
          gen = generationOfDex(dex) }
      end
    end
    return out
  end

  local function indexOf(self, game)
    if self.__g9index then return self.__g9index end
    self.__g9index = buildIndex(game)
    return self.__g9index
  end

  local function genComplete(index, set, gen)
    local any = false
    for i = 1, #index do
      local e = index[i]
      if e.gen == gen then
        any = true
        if not (set[e.id] or (e.base and set[e.base])) then return false end
      end
    end
    return any
  end

  local function heldCount(index, set)
    local n = 0
    for i = 1, #index do
      if set[index[i].id] then n = n + 1 end
    end
    return n
  end

  -- ---------------------------------------------------------------- surfaces
  function M.uiSize() return W, H end
  function M.isWideBattleLayout(self) return Shell.wide(self) end
  function M.wantsFillScale(self) return Shell.wide(self) end
  function M.sgbPalettes() return {} end

  -- ------------------------------------------------------------------ helpers
  local function centerY(y, h, font)
    return y + math.floor((h - Theme.capOf(font)) * 0.5 + 0.5)
  end

  -- The gen grid / RESET cells: a framed glass tile, lit with the accent when
  -- it holds the cursor.  A completed generation gets a small check at its
  -- right edge (the sample's own "X" mark, modernised).
  local function cell(game, x, y, w, h, label, state, complete)
    local F = Theme.fonts(game).body
    local fill, border, ink
    if state == "focus" then
      fill, border, ink = C.panelLit, C.borderLit, C.accent
    elseif state == "on" then
      fill, border, ink = C.rowLit, C.borderLit, C.accent
    else
      fill, border, ink = C.panel, C.border, C.ink
    end
    Theme.panel(x, y, w, h, { radius = 5, color = fill, border = border,
      shadow = state == "focus" and 2 or nil })
    Theme.text(label, x + w * 0.5, centerY(y, h, F), F, "center", ink)
    if complete then
      Theme.set(C.good)
      love.graphics.line(x + w - 16, y + h * 0.5, x + w - 12, y + h * 0.5 + 4,
        x + w - 6, y + h * 0.5 - 6)
    end
  end

  -- -------------------------------------------------------------------- draw
  local function drawList(self, game, set)
    local rows = {}
    for i = 1, #self.filtered do
      local entry = self.filtered[i]
      local held = set[entry.id] == true
        or (entry.base and set[entry.base] == true) or false
      rows[i] = {
        text = entry.name or entry.id or "----",
        right = held and "HELD" or nil,
      }
    end
    if #rows == 0 then
      Theme.panel(LIST_X, LIST_Y, LIST_W, LIST_VISIBLE * LIST_ROW + 4,
        { radius = 6, shadow = 2 })
      Theme.text("NO MATCHES FOR THIS FILTER", LIST_X + 20, LIST_Y + 24,
        Theme.fonts(game).body, "left", C.inkFaint)
      return
    end
    Shell.list(Theme, game, {
      rows = rows,
      index = self.listIndex,
      scroll = math.max(0, (self.listScroll or 1) - 1),
      maxVisible = LIST_VISIBLE,
      more = (self.listScroll or 1) - 1 + LIST_VISIBLE < #rows,
      x = LIST_X, y = LIST_Y, w = LIST_W, row = LIST_ROW,
      labelPad = 44, rightPad = 20,
    })
  end

  local function drawGrid(self, game, set, index)
    local F = Theme.fonts(game)
    Theme.text("GENERATION", GRID_X0, Shell.CONTENT_Y, F.small, "left",
      C.inkFaint)
    for g = 1, GEN_COUNT do
      local row = math.floor((g - 1) / 3) + 1
      local col = ((g - 1) % 3) + 1
      local x = GRID_X0 + (col - 1) * (GRID_W + GRID_GAP)
      local y = GRID_ROWS[row]
      local on = (self.focus == "grid" and self.gridRow == row
        and self.gridCol == col)
      cell(game, x, y, GRID_W, GRID_H, "G" .. g, on and "focus" or nil,
        genComplete(index, set, g))
    end
    local resetOn = (self.focus == "grid" and (self.gridRow or 0) >= 4)
    cell(game, RESET_X, RESET_Y, RESET_W, RESET_H, "RESET ALL",
      resetOn and "focus" or nil, false)

    -- short legend under the grid, in the small face
    Theme.panel(GRID_X0, 248, 184, 56, { radius = 6, shadow = 2 })
    local lines = {
      "A: TOGGLE ROW OR CELL",
      "START/SELECT: FILTER",
      "HELD = SKIPPED",
    }
    for i = 1, #lines do
      Theme.text(Theme.fit(lines[i], F.small, 160), GRID_X0 + 14,
        256 + (i - 1) * 16, F.small, "left", C.inkFaint)
    end
  end

  function M.draw(self)
    local game = self.game
    if type(game) ~= "table" then return end
    if self.broken then return end
    local background = opt("ui_background") ~= "false"
    local embellish = opt("ui_embellishment") ~= "false"

    Backdrop.draw(Theme, { w = W, h = H, t = self.__t or 0,
      background = background, embellishment = embellish })

    local set = readSet(game)
    local index = indexOf(self, game)
    local letter = string.char(64 + (self.letter or 1))
    local shown = #(self.filtered or {})

    Shell.top(Theme, game, {
      title = "BLACKLIST",
      right = ("GEN %d"):format(self.gen or 1),
      caption = ("LETTER %s  /  %d SHOWN"):format(letter, shown),
      money = ("%d HELD"):format(heldCount(index, set)),
      embellish = embellish,
    })

    drawList(self, game, set)
    drawGrid(self, game, set, index)

    Shell.footer(Theme, game, {
      hints = {
        { key = "A", text = "TOGGLE" },
        { key = "START/SELECT", text = "FILTER" },
        { key = "B", text = "BACK" },
      },
      right = (self.status ~= "" and self.status) or nil,
    })

    Theme.set(C.white)
  end

  -- ------------------------------------------------------------------ dress
  -- Amend a G9Blacklist instance in place: draw and surface only, so the
  -- sample's own update -- filters, cursor and every write -- keeps running.
  function M.dress(state)
    if type(state) ~= "table" or state.__g9gui then return state end
    state.__g9gui = true
    state.isOpaque = true
    state.letterboxWhite = true
    state.__t = state.__t or 0
    state.sgbPalettes = M.sgbPalettes
    if Gen2 then
      -- Gold: the sample's own Screen already answers Gen 2's panel contract
      -- for its native 320x180 window (panelSize/battlePanelScale/panelScale/
      -- drawsWidescreen/drawWidescreen), so its drawWidescreen would blit this
      -- 540x360 page at the 320x180 scale.  Swap the surface trio for the
      -- suite's page (Shell.gen2Surface); the sample's update, filters, cursor
      -- and every blacklist write keep running untouched.
      Shell.gen2Surface(Theme, state, function(s) M.draw(s) end)
    else
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

  M.screenId = "G9Blacklist"
  return M
end
